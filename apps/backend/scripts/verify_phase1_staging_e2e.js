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

async function verifyStagingPostgresE2E() {
  console.log('================================================================');
  console.log('PHASE 1 — SUPABASE STAGING POSTGRESQL E2E VERIFICATION');
  console.log('================================================================\n');

  await stagingPrisma.$connect();
  console.log('[PASS] Connected to Supabase Staging PostgreSQL.');

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

  // Record baseline counts on staging
  const initialCustomerCount = await stagingPrisma.customer.count();
  const initialFollowUpCount = await stagingPrisma.crmFollowUp.count();
  const initialActivityCount = await stagingPrisma.crmActivity.count();
  const initialAttachmentCount = await stagingPrisma.crmAttachment.count();
  console.log(`Baseline staging counts: customers=${initialCustomerCount}, followUps=${initialFollowUpCount}, activities=${initialActivityCount}, attachments=${initialAttachmentCount}`);

  // 1. Get an existing staff on staging
  const staff = await stagingPrisma.staff.findFirst();
  assert(staff, 'Staff must exist on staging');
  const user = await stagingPrisma.user.findFirst();

  const testUser = {
    id: user ? user.id : staff.id,
    userId: user ? user.id : staff.id,
    roles: ['ROLE_ADMIN'],
    staffId: staff.id,
    fullName: 'Staging E2E Admin',
  };

  // 2. Create isolated test customer on staging
  const testCustomer = await stagingPrisma.customer.create({
    data: {
      customerCode: `CUST-STG-${Date.now()}`,
      companyName: `Staging E2E Test Company ${Date.now()}`,
      contactPerson: 'Suresh Patil',
      email: `staging.test.${Date.now()}@example.com`,
      phone: '9822001122',
      address: 'MIDC Chakan Phase 2',
      state: 'Maharashtra',
      district: 'Pune',
      city: 'Pune',
      pincode: '410501',
      assignedStaffId: staff.id,
      status: 'ACTIVE',
      customerType: 'DIRECT_CLIENT',
    }
  });
  console.log(`[PASS] Created staging customer: ${testCustomer.id}`);

  // 3. Create isolated pending follow-up on staging
  const followUp = await stagingPrisma.crmFollowUp.create({
    data: {
      title: 'Staging Discovery Call',
      activityType: 'CALL',
      customerId: testCustomer.id,
      assignedStaffId: staff.id,
      followUpNumber: 1,
      status: 'PENDING',
      priority: 'HIGH',
      notes: 'Testing atomic resolve on Supabase PostgreSQL',
    }
  });
  console.log(`[PASS] Created staging follow-up: ${followUp.id}`);

  // 4. Create an attachment on staging
  const attachment = await stagingPrisma.crmAttachment.create({
    data: {
      customerId: testCustomer.id,
      followUpId: followUp.id,
      fileName: 'staging_pump_spec.pdf',
      storagePath: `documents/crm/${testCustomer.id}/staging_pump_spec.pdf`,
      fileUrl: `/api/v1/crm/attachments/download/staging_pump_spec.pdf`,
      mimeType: 'application/pdf',
      fileSizeBytes: 2048,
      mediaClass: 'DOCUMENT',
      sourceCategory: 'REQUIREMENT_DOC',
      description: 'Technical pump specification sheet',
      uploadedById: staff.id,
      uploadedByName: 'Suresh P',
    }
  });
  console.log(`[PASS] Created staging attachment: ${attachment.id}`);

  // 5. Atomically resolve follow-up on staging PostgreSQL
  const nextDate = new Date();
  nextDate.setDate(nextDate.getDate() + 2);
  nextDate.setHours(11, 0, 0, 0);

  const resolveRes = await crmService.resolveFollowUp(
    followUp.id,
    {
      activityType: 'CALL',
      subject: 'Staging Verification Call',
      discussion: 'Discussed high volume pump requirements with engineer',
      outcome: 'CONNECTED',
      callDurationSec: 180,
      callOutcome: 'CONNECTED',
      customerRequirements: '50HP VFD dual panel',
      productsDiscussed: ['VFD_PANEL'],
      scheduleNext: true,
      nextActivityType: 'SITE_VISIT',
      nextScheduledDate: nextDate.toISOString(),
      nextSubject: 'Engineering site visit to Chakan plant',
      nextPriority: 'HIGH',
      attachmentIds: [attachment.id],
      idempotencyKey: `stg-idemp-${Date.now()}`,
    },
    testUser
  );

  assert(resolveRes.followUp.status === 'COMPLETED', 'Staging follow-up must be COMPLETED');
  assert(resolveRes.followUp.completedActivityId, 'completedActivityId must be linked');
  assert(resolveRes.nextFollowUp, 'Next site visit follow-up must be scheduled');
  assert.strictEqual(resolveRes.nextFollowUp.parentFollowUpId, followUp.id, 'parentFollowUpId must match');
  console.log(`[PASS] Atomically resolved follow-up on Supabase PostgreSQL. Activity: ${resolveRes.activity.id}, Next Follow-up: ${resolveRes.nextFollowUp.id}`);

  // 6. Test timeline consolidation on staging
  const timeline = await crmService.getCompanyTimeline(testCustomer.id, testUser);
  assert(timeline.length >= 3, `Timeline must contain activity, follow-up, and attachment (got ${timeline.length})`);
  console.log(`[PASS] Staging timeline successfully consolidated ${timeline.length} events.`);

  // 7. Cleanup test data from staging PostgreSQL
  await stagingPrisma.customer.delete({ where: { id: testCustomer.id } });
  console.log(`[PASS] Cleaned up staging customer and cascade records.`);

  // 8. Verify post-cleanup counts match baseline
  const postCustomerCount = await stagingPrisma.customer.count();
  const postFollowUpCount = await stagingPrisma.crmFollowUp.count();
  const postActivityCount = await stagingPrisma.crmActivity.count();
  const postAttachmentCount = await stagingPrisma.crmAttachment.count();

  assert.strictEqual(postCustomerCount, initialCustomerCount, 'Customer count must return to baseline');
  assert.strictEqual(postFollowUpCount, initialFollowUpCount, 'Follow-up count must return to baseline');
  assert.strictEqual(postActivityCount, initialActivityCount, 'Activity count must return to baseline');
  assert.strictEqual(postAttachmentCount, initialAttachmentCount, 'Attachment count must return to baseline');
  console.log(`[PASS] Post-test counts exactly match baseline: customers=${postCustomerCount}, followUps=${postFollowUpCount}, activities=${postActivityCount}, attachments=${postAttachmentCount}`);

  await stagingPrisma.$disconnect();
  console.log('\n================================================================');
  console.log('SUPABASE STAGING POSTGRESQL E2E VERIFICATION: ALL PASSED!');
  console.log('================================================================');
}

verifyStagingPostgresE2E().catch(e => {
  console.error('[FAIL] Staging E2E verification failed:', e);
  process.exit(1);
});
