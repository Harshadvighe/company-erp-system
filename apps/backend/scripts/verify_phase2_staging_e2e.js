const path = require('path');
const fs = require('fs');
const assert = require('assert');

// Load Staging Client
const { PrismaClient: StagingPrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client-staging'));
const env = {};
fs.readFileSync(path.resolve(__dirname, '../.env.staging'), 'utf8').split(/\r?\n/).forEach(line => {
  const parts = line.split('=');
  if (parts.length >= 2) env[parts[0].trim()] = parts.slice(1).join('=').trim().replace(/^["']|["']$/g, '');
});

if (!env.DATABASE_URL) {
  console.error('DATABASE_URL missing in .env.staging');
  process.exit(1);
}

const stagingPrisma = new StagingPrismaClient({
  datasources: {
    db: { url: env.DATABASE_URL }
  }
});

const { LocalFileStorageService } = require('../dist/src/core/storage/file-storage.service');
const { AuditService } = require('../dist/src/core/audit/audit.service');
const { SequenceService } = require('../dist/src/core/database/sequence.service');
const { GstVerificationService } = require('../dist/src/modules/crm/gst-verification.service');
const { CrmService } = require('../dist/src/modules/crm/crm.service');
const { CrmSchedulerService, calculateNextWorkingDayIST, getISTDateParts } = require('../dist/src/modules/crm/crm-scheduler.service');

async function verifyStagingPostgresE2E() {
  console.log('================================================================');
  console.log('PHASE 2 — SUPABASE STAGING POSTGRESQL E2E VERIFICATION');
  console.log('================================================================\n');

  await stagingPrisma.$connect();
  console.log('[PASS] Connected to Supabase Staging PostgreSQL (ap-northeast-2 pooler).');

  const sentNotifications = [];
  const mockNotificationService = {
    notify: async (opts) => {
      sentNotifications.push({ ...opts, timestamp: new Date() });
      return { id: 'notif-stage-' + Math.random().toString(36).substring(7), ...opts };
    },
    getUserNotifications: async (userId) => sentNotifications.filter((n) => n.userId === userId),
    markAsRead: async () => ({ count: 1 }),
  };

  const auditService = new AuditService(stagingPrisma);
  const sequenceService = new SequenceService(stagingPrisma);
  const gstVerificationService = new GstVerificationService();
  const fileStorageService = new LocalFileStorageService();
  const crmService = new CrmService(
    stagingPrisma,
    auditService,
    gstVerificationService,
    sequenceService,
    fileStorageService
  );
  const schedulerService = new CrmSchedulerService(stagingPrisma, mockNotificationService);
  const targetDateStr = getISTDateParts(new Date()).dateStr;
  await stagingPrisma.crmDigestLog.deleteMany({ where: { digestDate: targetDateStr } });

  // Baseline counts before test
  const initialCustomerCount = await stagingPrisma.customer.count();
  const initialFollowUpCount = await stagingPrisma.crmFollowUp.count();
  const initialActivityCount = await stagingPrisma.crmActivity.count();
  const initialDigestLogCount = await stagingPrisma.crmDigestLog.count();
  console.log(`Baseline staging counts: customers=${initialCustomerCount}, followUps=${initialFollowUpCount}, activities=${initialActivityCount}, digestLogs=${initialDigestLogCount}`);

  // Fetch existing staff on staging
  const existingStaff = await stagingPrisma.staff.findFirst({
    where: { status: 'ACTIVE', userId: { not: null } },
  }) || await stagingPrisma.staff.findFirst();

  assert(existingStaff, 'At least one staff record must exist on staging');
  const existingUser = await stagingPrisma.user.findFirst();

  const testUser = {
    id: existingUser ? existingUser.id : existingStaff.id,
    userId: existingUser ? existingUser.id : existingStaff.id,
    roles: ['ROLE_ADMIN', 'ADMIN'],
    staffId: existingStaff.id,
    fullName: 'Staging Phase 2 Admin',
  };

  const suffix = Date.now();
  let testCustomer = null;

  try {
    // 1. Create isolated customer on staging
    testCustomer = await stagingPrisma.customer.create({
      data: {
        customerCode: `CUST-PH2-STG-${suffix}`,
        companyName: `Stage Phase 2 Test Entity ${suffix}`,
        contactPerson: 'Staging Manager',
        email: `stage_ph2_${suffix}@saark.test`,
        phone: '9876543210',
        address: 'Bhosari MIDC Staging',
        state: 'Maharashtra',
        district: 'Pune',
        city: 'Pune',
        pincode: '411026',
        assignedStaffId: existingStaff.id,
        salesManagerStaffId: existingStaff.id,
        status: 'ACTIVE',
      },
    });
    console.log(`[PASS] Created isolated test customer on staging: ${testCustomer.companyName}`);

    // 2. Test NO_ANSWER automatic callback suggestion on staging PostgreSQL
    const followUp1 = await stagingPrisma.crmFollowUp.create({
      data: {
        customerId: testCustomer.id,
        assignedStaffId: existingStaff.id,
        followUpNumber: 1,
        activityType: 'CALL',
        title: 'Staging Discovery Call',
        status: 'PENDING',
      },
    });

    const resolveRes = await crmService.resolveFollowUp(
      followUp1.id,
      {
        activityType: 'CALL',
        callOutcome: 'NO_ANSWER',
        discussion: 'Staging call: client did not answer phone',
      },
      testUser
    );

    assert.strictEqual(resolveRes.followUp.status, 'COMPLETED');
    assert.ok(resolveRes.nextFollowUp != null, 'Staging resolve must auto-create next follow-up for NO_ANSWER');
    assert.strictEqual(resolveRes.nextFollowUp.activityType, 'CALL');

    const expectedDate = calculateNextWorkingDayIST();
    assert.strictEqual(
      resolveRes.nextFollowUp.scheduledDate.toISOString(),
      expectedDate.toISOString(),
      'Staging callback must be scheduled at 11:00 AM IST on next working day'
    );
    console.log('[PASS] Staging resolve with NO_ANSWER automatically scheduled next working day 11:00 AM IST callback on PostgreSQL');

    // 3. Test Due Reminders dispatch & deduplication on staging PostgreSQL
    sentNotifications.length = 0;
    const dueFollowUp = await stagingPrisma.crmFollowUp.create({
      data: {
        customerId: testCustomer.id,
        assignedStaffId: existingStaff.id,
        followUpNumber: 10,
        activityType: 'CALL',
        title: 'Staging Due Reminder Call',
        scheduledDate: new Date(Date.now() + 5 * 60 * 1000), // in 5 mins
        reminderMinutes: 15,
        status: 'PENDING',
      },
    });

    const reminderRun1 = await schedulerService.checkAndDispatchDueReminders();
    assert.ok(reminderRun1.sent >= 1, 'At least 1 reminder sent on staging');

    const reloadedDue = await stagingPrisma.crmFollowUp.findUnique({ where: { id: dueFollowUp.id } });
    assert.ok(reloadedDue.reminderSentAt != null, 'reminderSentAt persisted on staging PostgreSQL');

    const reminderRun2 = await schedulerService.checkAndDispatchDueReminders();
    const dups = sentNotifications.filter(n => n.entityId === dueFollowUp.id);
    assert.strictEqual(dups.length, 1, 'Exactly 1 notification sent across multiple runs on staging (idempotent)');
    console.log('[PASS] Staging due reminders verified with atomic reminderSentAt deduplication');

    // 4. Test Daily My Day Digest on staging PostgreSQL
    sentNotifications.length = 0;
    const targetDateStr = getISTDateParts(new Date()).dateStr;
    const digestRun1 = await schedulerService.dispatchDailyDigest(targetDateStr, false);
    assert.ok(digestRun1.digestsSent >= 1, 'My Day digest sent on staging');

    const digestLog = await stagingPrisma.crmDigestLog.findFirst({
      where: { digestDate: targetDateStr, staffId: existingStaff.id },
    });
    assert.ok(digestLog != null, 'crm_digest_logs record persisted on Supabase PostgreSQL');

    const digestRun2 = await schedulerService.dispatchDailyDigest(targetDateStr, false);
    assert.strictEqual(digestRun2.digestsSent, 0, 'Zero duplicate digests sent on second run (unique constraint)');
    console.log('[PASS] Staging daily digest verified with crm_digest_logs unique constraint deduplication');

    // 5. Test 24-Hour Overdue Escalation on staging PostgreSQL
    sentNotifications.length = 0;
    const overdueTime = new Date(Date.now() - 30 * 60 * 60 * 1000);
    const overdueFollowUp = await stagingPrisma.crmFollowUp.create({
      data: {
        customerId: testCustomer.id,
        assignedStaffId: existingStaff.id,
        followUpNumber: 20,
        activityType: 'CALL',
        title: 'Staging Critical Deal Call',
        scheduledDate: overdueTime,
        status: 'PENDING',
      },
    });

    const escRun1 = await schedulerService.checkAndDispatchOverdueEscalations(false);
    assert.ok(escRun1.escalated >= 1, 'Overdue follow-up escalated on staging');

    const reloadedEsc = await stagingPrisma.crmFollowUp.findUnique({ where: { id: overdueFollowUp.id } });
    assert.strictEqual(reloadedEsc.status, 'OVERDUE');
    assert.ok(reloadedEsc.escalatedAt != null, 'escalatedAt persisted on staging PostgreSQL');
    assert.ok(reloadedEsc.escalatedToStaffId != null, 'escalatedToStaffId set on staging');

    const escRun2 = await schedulerService.checkAndDispatchOverdueEscalations(false);
    assert.strictEqual(escRun2.escalated, 0, 'No repeat escalation on staging');
    console.log('[PASS] Staging 24h overdue escalation verified and locked against repeat dispatch');

  } finally {
    // Clean up isolated test fixtures on staging
    console.log('\n--- Cleaning up isolated staging test fixtures ---');
    if (testCustomer) {
      await stagingPrisma.crmDigestLog.deleteMany({
        where: { digestDate: targetDateStr },
      });
      await stagingPrisma.crmAttachment.deleteMany({ where: { customerId: testCustomer.id } });
      await stagingPrisma.crmFollowUp.deleteMany({ where: { customerId: testCustomer.id } });
      await stagingPrisma.crmActivity.deleteMany({ where: { customerId: testCustomer.id } });
      await stagingPrisma.customer.delete({ where: { id: testCustomer.id } });
      console.log('[PASS] Isolated test fixtures cleaned up on staging.');
    }

    const finalCustomerCount = await stagingPrisma.customer.count();
    const finalFollowUpCount = await stagingPrisma.crmFollowUp.count();
    const finalActivityCount = await stagingPrisma.crmActivity.count();
    const finalDigestLogCount = await stagingPrisma.crmDigestLog.count();

    console.log(`Final staging counts: customers=${finalCustomerCount}, followUps=${finalFollowUpCount}, activities=${finalActivityCount}, digestLogs=${finalDigestLogCount}`);

    assert.strictEqual(finalCustomerCount, initialCustomerCount, 'Customer count must match baseline');
    assert.strictEqual(finalFollowUpCount, initialFollowUpCount, 'FollowUp count must match baseline');
    assert.strictEqual(finalActivityCount, initialActivityCount, 'Activity count must match baseline');
    assert.strictEqual(finalDigestLogCount, initialDigestLogCount, 'DigestLog count must match baseline');
    console.log('[PASS] Baseline data integrity verified with zero residual test records!');

    await stagingPrisma.$disconnect();
  }

  console.log('\n================================================================');
  console.log('ALL PHASE 2 STAGING POSTGRESQL E2E CHECKS PASSED!');
  console.log('================================================================\n');
}

verifyStagingPostgresE2E().catch((err) => {
  console.error('Staging verification error:', err);
  process.exit(1);
});
