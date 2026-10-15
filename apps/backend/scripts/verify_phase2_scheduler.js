/**
 * SAARK ERP Phase 2 Automated Verification Suite:
 * Automatic Scheduling, Reminders, Digest, and Overdue Escalations
 */
const { PrismaClient } = require('@prisma/client');
const assert = require('assert');
const path = require('path');

// Ensure correct local DB URL
process.env.DATABASE_URL = 'file:../../storage/saark_erp.db';
const prisma = new PrismaClient({
  datasources: { db: { url: 'file:../../storage/saark_erp.db' } },
});

// Import compiled or source scheduler functions
const {
  calculateNextWorkingDayIST,
  getISTDateParts,
  formatISTTime,
  CrmSchedulerService,
} = require('../dist/src/modules/crm/crm-scheduler.service');

const { CrmService } = require('../dist/src/modules/crm/crm.service');

async function main() {
  console.log('========================================================================');
  console.log('   SAARK ERP PHASE 2 VERIFICATION SUITE — SCHEDULER & REMINDERS');
  console.log('========================================================================\n');

  let testsPassed = 0;
  let testsFailed = 0;

  function pass(msg) {
    testsPassed++;
    console.log(`[PASS] ${msg}`);
  }

  function fail(msg, err) {
    testsFailed++;
    console.error(`[FAIL] ${msg}`, err);
  }

  // Mock NotificationService tracking
  const sentNotifications = [];
  const mockNotificationService = {
    notify: async (opts) => {
      sentNotifications.push({ ...opts, timestamp: new Date() });
      return { id: 'notif-' + Math.random().toString(36).substring(7), ...opts };
    },
    getUserNotifications: async (userId) => sentNotifications.filter((n) => n.userId === userId),
    markAsRead: async () => ({ count: 1 }),
  };

  const schedulerService = new CrmSchedulerService(prisma, mockNotificationService);

  // Mock services for CrmService
  const mockAuditService = { recordAction: async () => ({}) };
  const mockGstService = {};
  const mockSeqService = { getNextSequence: async () => 'SEQ-001' };
  const mockFileStorage = { deleteFile: async () => {} };
  const crmService = new CrmService(
    prisma,
    mockAuditService,
    mockGstService,
    mockSeqService,
    mockFileStorage,
  );

  let testCustomer = null;
  let testStaffSales = null;
  let testStaffManager = null;
  let testUserSales = null;
  let testUserManager = null;

  try {
    // -------------------------------------------------------------------------
    // TEST 1: Next-Working-Day Callback Calculation & Timezone Boundaries (IST)
    // -------------------------------------------------------------------------
    console.log('--- Test 1: Next-Working-Day Calculation & IST Boundaries ---');
    try {
      // 1.1 Wednesday afternoon -> Thursday 11:00 AM IST (05:30 UTC)
      // 2026-10-14 14:00 IST is 2026-10-14T08:30:00Z
      const wednesday = new Date('2026-10-14T08:30:00.000Z');
      const thursResult = calculateNextWorkingDayIST(wednesday);
      const thursParts = getISTDateParts(thursResult);
      assert.strictEqual(thursParts.dayOfWeek, 4, 'Target should be Thursday (4)');
      assert.strictEqual(thursParts.hours, 11, 'Target hour must be 11 AM IST');
      assert.strictEqual(thursParts.minutes, 0, 'Target minute must be 00');
      assert.strictEqual(thursResult.toISOString(), '2026-10-15T05:30:00.000Z', 'UTC equivalent must be 05:30:00Z');

      // 1.2 Friday evening -> Next Monday 11:00 AM IST (skips Sat & Sun)
      // 2026-10-16 18:00 IST is 2026-10-16T12:30:00Z
      const friday = new Date('2026-10-16T12:30:00.000Z');
      const monResult = calculateNextWorkingDayIST(friday);
      const monParts = getISTDateParts(monResult);
      assert.strictEqual(monParts.dayOfWeek, 1, 'Friday must roll over to Monday (1)');
      assert.strictEqual(monParts.hours, 11, 'Target hour must be 11 AM IST');
      assert.strictEqual(monResult.toISOString(), '2026-10-19T05:30:00.000Z', 'UTC equivalent must be Monday 05:30:00Z');

      // 1.3 Saturday morning -> Next Monday 11:00 AM IST
      const saturday = new Date('2026-10-17T05:00:00.000Z');
      const satToMon = calculateNextWorkingDayIST(saturday);
      assert.strictEqual(getISTDateParts(satToMon).dayOfWeek, 1, 'Saturday rolls over to Monday');

      // 1.4 Sunday noon -> Next Monday 11:00 AM IST
      const sunday = new Date('2026-10-18T06:30:00.000Z');
      const sunToMon = calculateNextWorkingDayIST(sunday);
      assert.strictEqual(getISTDateParts(sunToMon).dayOfWeek, 1, 'Sunday rolls over to Monday');

      pass('Next-working-day calculation correctly handles Mon-Thu and skips weekends to Monday at 11:00 AM IST');
    } catch (e) {
      fail('Next-working-day calculation failed', e);
    }

    // -------------------------------------------------------------------------
    // SETUP FIXTURES: Users, Staff, Customer
    // -------------------------------------------------------------------------
    console.log('\n--- Setting up test fixtures ---');
    const suffix = Math.floor(Math.random() * 900000 + 100000);

    // Sales Executive User & Staff
    testUserSales = await prisma.user.create({
      data: {
        username: `sales_exec_${suffix}`,
        email: `sales_exec_${suffix}@saark.test`,
        passwordHash: 'dummyhash',
        fullName: `Sales Exec ${suffix}`,
        status: 'ACTIVE',
      },
    });

    const dept = await prisma.department.findFirst() || await prisma.department.create({
      data: { name: 'Sales', code: 'SALES' },
    });
    const desigSales = await prisma.designation.findFirst() || await prisma.designation.create({
      data: { name: 'Sales Engineer', code: 'SE' },
    });
    const desigMgr = await prisma.designation.create({
      data: { name: `Sales Manager ${suffix}`, code: `SM_${suffix}` },
    });

    // Manager User & Staff
    testUserManager = await prisma.user.create({
      data: {
        username: `sales_mgr_${suffix}`,
        email: `sales_mgr_${suffix}@saark.test`,
        passwordHash: 'dummyhash',
        fullName: `Sales Manager ${suffix}`,
        status: 'ACTIVE',
      },
    });

    testStaffManager = await prisma.staff.create({
      data: {
        employeeId: `EMP_MGR_${suffix}`,
        fullName: `Manager ${suffix}`,
        email: `mgr_${suffix}@saark.test`,
        departmentId: dept.id,
        designationId: desigMgr.id,
        userId: testUserManager.id,
        status: 'ACTIVE',
      },
    });

    testStaffSales = await prisma.staff.create({
      data: {
        employeeId: `EMP_SALES_${suffix}`,
        fullName: `Executive ${suffix}`,
        email: `exec_${suffix}@saark.test`,
        departmentId: dept.id,
        designationId: desigSales.id,
        userId: testUserSales.id,
        reportingManagerId: testStaffManager.id,
        status: 'ACTIVE',
      },
    });

    // Customer
    testCustomer = await prisma.customer.create({
      data: {
        customerCode: `CUST-PH2-${suffix}`,
        companyName: `Phase 2 Test Enterprise ${suffix}`,
        contactPerson: 'Director Test',
        email: `contact_${suffix}@enterprise.test`,
        phone: '9876543210',
        address: 'Bhosari MIDC',
        state: 'Maharashtra',
        district: 'Pune',
        city: 'Pune',
        pincode: '411026',
        assignedStaffId: testStaffSales.id,
        salesManagerStaffId: testStaffManager.id,
        status: 'ACTIVE',
      },
    });

    pass('Test fixtures (users, staff, manager, customer) created successfully');

    // -------------------------------------------------------------------------
    // TEST 2: NO_ANSWER & BUSY Call Outcome Auto-Prefill
    // -------------------------------------------------------------------------
    console.log('\n--- Test 2: NO_ANSWER / BUSY Automatic Callback Suggestion ---');
    try {
      // Create initial follow-up
      const followUp1 = await prisma.crmFollowUp.create({
        data: {
          customerId: testCustomer.id,
          assignedStaffId: testStaffSales.id,
          followUpNumber: 1,
          activityType: 'CALL',
          title: 'Initial Discovery Call',
          status: 'PENDING',
        },
      });

      // 2.1 Resolve with NO_ANSWER without passing scheduleNext/nextScheduledDate
      const res1 = await crmService.resolveFollowUp(
        followUp1.id,
        {
          activityType: 'CALL',
          callOutcome: 'NO_ANSWER',
          discussion: 'Client did not answer phone on first dial',
        },
        { id: testUserSales.id, staffId: testStaffSales.id, roles: ['ROLE_SALES_EXEC'] },
      );

      assert.strictEqual(res1.followUp.status, 'COMPLETED');
      assert.ok(res1.nextFollowUp, 'Automatic next follow-up must be scheduled for NO_ANSWER');
      assert.strictEqual(res1.nextFollowUp.activityType, 'CALL');
      assert.ok(res1.nextFollowUp.subject.includes('NO_ANSWER'), 'Subject includes NO_ANSWER');

      // Verify nextScheduledDate matches 11:00 AM IST next working day
      const expectedCallback = calculateNextWorkingDayIST();
      assert.strictEqual(
        res1.nextFollowUp.scheduledDate.toISOString(),
        expectedCallback.toISOString(),
        'Next callback must be scheduled for next working day at 11:00 AM Asia/Kolkata',
      );
      pass('NO_ANSWER automatically schedules callback on next working day at 11:00 AM IST');

      // 2.2 Resolve with BUSY and custom date override (kept editable)
      const followUp2 = await prisma.crmFollowUp.create({
        data: {
          customerId: testCustomer.id,
          assignedStaffId: testStaffSales.id,
          followUpNumber: 3,
          activityType: 'CALL',
          title: 'Second Call',
          status: 'PENDING',
        },
      });

      const customFutureDate = new Date(Date.now() + 4 * 24 * 60 * 60 * 1000);
      const res2 = await crmService.resolveFollowUp(
        followUp2.id,
        {
          activityType: 'CALL',
          callOutcome: 'BUSY',
          discussion: 'Line busy, client asked via SMS to call on custom date',
          scheduleNext: true,
          nextScheduledDate: customFutureDate.toISOString(),
          nextSubject: 'Custom Rescheduled Call',
        },
        { id: testUserSales.id, staffId: testStaffSales.id, roles: ['ROLE_SALES_EXEC'] },
      );

      assert.strictEqual(res2.followUp.status, 'COMPLETED');
      assert.ok(res2.nextFollowUp);
      assert.strictEqual(
        res2.nextFollowUp.scheduledDate.toISOString(),
        customFutureDate.toISOString(),
        'Custom nextScheduledDate is preserved and editable',
      );
      assert.strictEqual(res2.nextFollowUp.subject, 'Custom Rescheduled Call');
      pass('BUSY outcome respects custom date override when provided');

      // 2.3 Resolve with NO_ANSWER with scheduleNext: false (explicit opt-out)
      const followUp3 = await prisma.crmFollowUp.create({
        data: {
          customerId: testCustomer.id,
          assignedStaffId: testStaffSales.id,
          followUpNumber: 5,
          activityType: 'CALL',
          title: 'Third Call',
          status: 'PENDING',
        },
      });

      const res3 = await crmService.resolveFollowUp(
        followUp3.id,
        {
          activityType: 'CALL',
          callOutcome: 'NO_ANSWER',
          discussion: 'Third no answer, closing pursuit without callback',
          scheduleNext: false,
        },
        { id: testUserSales.id, staffId: testStaffSales.id, roles: ['ROLE_SALES_EXEC'] },
      );

      assert.strictEqual(res3.followUp.status, 'COMPLETED');
      assert.strictEqual(res3.nextFollowUp, null, 'No next follow-up created when scheduleNext is false');
      pass('NO_ANSWER respects explicit opt-out (scheduleNext: false)');
    } catch (e) {
      fail('NO_ANSWER / BUSY callback suggestion failed', e);
    }

    // -------------------------------------------------------------------------
    // TEST 3: Due Reminders Dispatch & Deduplication
    // -------------------------------------------------------------------------
    console.log('\n--- Test 3: Due Reminders Dispatch & Deduplication ---');
    try {
      sentNotifications.length = 0; // reset notification tracker

      // Create a follow-up due in 5 minutes with reminderMinutes = 15
      const dueFollowUp = await prisma.crmFollowUp.create({
        data: {
          customerId: testCustomer.id,
          assignedStaffId: testStaffSales.id,
          followUpNumber: 10,
          activityType: 'CALL',
          title: 'Due Reminder Test Call',
          scheduledDate: new Date(Date.now() + 5 * 60 * 1000), // in 5 mins
          reminderMinutes: 15,
          status: 'PENDING',
        },
      });

      // Run reminder check
      const result1 = await schedulerService.checkAndDispatchDueReminders();
      assert.ok(result1.sent >= 1, 'At least 1 reminder should be sent');

      // Verify follow-up updated with reminderSentAt
      const reloaded = await prisma.crmFollowUp.findUnique({ where: { id: dueFollowUp.id } });
      assert.ok(reloaded.reminderSentAt != null, 'reminderSentAt must be populated');

      // Verify notification sent to staff's userId
      const notif = sentNotifications.find((n) => n.entityId === dueFollowUp.id);
      assert.ok(notif, 'Notification must be recorded');
      assert.strictEqual(notif.userId, testUserSales.id);
      assert.ok(notif.title.includes('Reminder'));

      // Run reminder check AGAIN (simulate server restart or concurrent worker)
      const initialCount = sentNotifications.length;
      const result2 = await schedulerService.checkAndDispatchDueReminders();
      assert.strictEqual(
        sentNotifications.length,
        initialCount,
        'Zero additional notifications sent on re-run (idempotent)',
      );

      pass('Due reminders dispatched accurately and deduplicated via reminderSentAt');
    } catch (e) {
      fail('Due reminders dispatch failed', e);
    }

    // -------------------------------------------------------------------------
    // TEST 4: Daily My Day Digest at 09:00 AM Asia/Kolkata
    // -------------------------------------------------------------------------
    console.log('\n--- Test 4: Daily My Day Digest at 09:00 AM IST ---');
    try {
      sentNotifications.length = 0;
      const todayDateStr = getISTDateParts(new Date()).dateStr;

      // Ensure staff has a pending item for today
      await prisma.crmFollowUp.create({
        data: {
          customerId: testCustomer.id,
          assignedStaffId: testStaffSales.id,
          followUpNumber: 20,
          activityType: 'MEETING',
          title: 'Today 14:00 Midday Meeting',
          scheduledDate: new Date(),
          status: 'PENDING',
        },
      });

      // Dispatch digest for today
      const digestResult1 = await schedulerService.dispatchDailyDigest(todayDateStr, false);
      assert.ok(digestResult1.digestsSent >= 1, 'At least 1 staff digest sent');

      // Check crm_digest_logs table
      const log = await prisma.crmDigestLog.findUnique({
        where: {
          digestDate_staffId: {
            digestDate: todayDateStr,
            staffId: testStaffSales.id,
          },
        },
      });
      assert.ok(log != null, 'CrmDigestLog must record digestDate and staffId');
      assert.strictEqual(log.userId, testUserSales.id);

      // Verify notification content
      const digestNotif = sentNotifications.find(
        (n) => n.userId === testUserSales.id && n.title.includes('My Day Digest'),
      );
      assert.ok(digestNotif != null, 'My Day digest notification dispatched');
      assert.ok(digestNotif.message.includes('Good morning'));

      // Dispatch AGAIN for the same day (simulate another worker or restart)
      const prevNotifCount = sentNotifications.length;
      const digestResult2 = await schedulerService.dispatchDailyDigest(todayDateStr, false);
      assert.strictEqual(
        sentNotifications.length,
        prevNotifCount,
        'Zero duplicate digests sent on subsequent check (unique constraint)',
      );

      pass('My Day digest correctly summarizes activity and prevents duplicate dispatch per staff/day');
    } catch (e) {
      fail('Daily My Day digest failed', e);
    }

    // -------------------------------------------------------------------------
    // TEST 5: 24-Hour Overdue Escalation to Sales Manager
    // -------------------------------------------------------------------------
    console.log('\n--- Test 5: 24-Hour Overdue Escalation to Sales Manager ---');
    try {
      sentNotifications.length = 0;

      // Create a follow-up scheduled 30 hours ago (overdue > 24h)
      const overdueTime = new Date(Date.now() - 30 * 60 * 60 * 1000);
      const overdueFollowUp = await prisma.crmFollowUp.create({
        data: {
          customerId: testCustomer.id,
          assignedStaffId: testStaffSales.id,
          followUpNumber: 30,
          activityType: 'CALL',
          title: 'Crucial Negotiation Call',
          scheduledDate: overdueTime,
          status: 'PENDING',
        },
      });

      // Run overdue escalation check
      const escResult1 = await schedulerService.checkAndDispatchOverdueEscalations(false);
      assert.ok(escResult1.escalated >= 1, 'At least 1 follow-up escalated');

      // Verify followUp updated
      const reloadedEsc = await prisma.crmFollowUp.findUnique({ where: { id: overdueFollowUp.id } });
      assert.strictEqual(reloadedEsc.status, 'OVERDUE');
      assert.ok(reloadedEsc.escalatedAt != null, 'escalatedAt must be recorded');
      assert.strictEqual(reloadedEsc.escalatedToStaffId, testStaffManager.id, 'Escalated to customer Sales Manager');

      // Verify notification sent to Manager's userId
      const escNotif = sentNotifications.find((n) => n.entityId === overdueFollowUp.id);
      assert.ok(escNotif, 'Escalation notification recorded');
      assert.strictEqual(escNotif.userId, testUserManager.id, 'Recipient must be Sales Manager');
      assert.ok(escNotif.title.includes('CRM Escalation'));
      assert.ok(escNotif.message.includes('overdue by more than 24 hours'));

      // Run escalation AGAIN: must not re-escalate
      const countBefore = sentNotifications.length;
      const escResult2 = await schedulerService.checkAndDispatchOverdueEscalations(false);
      assert.strictEqual(escResult2.escalated, 0, 'No re-escalation for already escalated follow-up');
      assert.strictEqual(sentNotifications.length, countBefore);

      pass('24h overdue follow-up correctly escalated to Sales Manager and locked against repeat dispatch');
    } catch (e) {
      fail('Overdue escalation failed', e);
    }

    // -------------------------------------------------------------------------
    // TEST 6: Exclusion of Completed and Cancelled Follow-ups
    // -------------------------------------------------------------------------
    console.log('\n--- Test 6: Exclusion of Completed and Cancelled Follow-ups ---');
    try {
      sentNotifications.length = 0;
      const pastTime = new Date(Date.now() - 48 * 60 * 60 * 1000);

      // Completed follow-up
      const completedFup = await prisma.crmFollowUp.create({
        data: {
          customerId: testCustomer.id,
          assignedStaffId: testStaffSales.id,
          followUpNumber: 41,
          activityType: 'CALL',
          title: 'Already Finished Call',
          scheduledDate: pastTime,
          status: 'COMPLETED',
          completedDate: pastTime,
        },
      });

      // Cancelled follow-up
      const cancelledFup = await prisma.crmFollowUp.create({
        data: {
          customerId: testCustomer.id,
          assignedStaffId: testStaffSales.id,
          followUpNumber: 42,
          activityType: 'CALL',
          title: 'Cancelled Call',
          scheduledDate: pastTime,
          status: 'CANCELLED',
        },
      });

      // Run reminders and escalations
      await schedulerService.checkAndDispatchDueReminders();
      await schedulerService.checkAndDispatchOverdueEscalations(false);

      const notifCompleted = sentNotifications.find((n) => n.entityId === completedFup.id);
      const notifCancelled = sentNotifications.find((n) => n.entityId === cancelledFup.id);

      assert.strictEqual(notifCompleted, undefined, 'Completed follow-up must not receive notifications');
      assert.strictEqual(notifCancelled, undefined, 'Cancelled follow-up must not receive notifications');

      pass('Completed and cancelled follow-ups properly excluded from reminders and escalations');
    } catch (e) {
      fail('Exclusion of completed/cancelled follow-ups failed', e);
    }

    // -------------------------------------------------------------------------
    // TEST 7: Callback Suggestion API Endpoint Output Structure
    // -------------------------------------------------------------------------
    console.log('\n--- Test 7: Callback Suggestion API Output Structure ---');
    try {
      const suggestion = schedulerService.getNextWorkingDayCallback();
      assert.ok(suggestion.suggestedDate instanceof Date);
      assert.ok(typeof suggestion.suggestedDateIso === 'string');
      assert.ok(suggestion.formattedIST.includes('11:00 AM IST'));
      assert.strictEqual(suggestion.timezone, 'Asia/Kolkata');
      assert.ok(typeof suggestion.dayOfWeek === 'string');

      pass('Callback suggestion returns complete, well-formed API payload');
    } catch (e) {
      fail('Callback suggestion API failed', e);
    }

  } finally {
    // -------------------------------------------------------------------------
    // CLEANUP TEST FIXTURES
    // -------------------------------------------------------------------------
    console.log('\n--- Cleaning up test fixtures ---');
    if (testCustomer) {
      await prisma.crmDigestLog.deleteMany({
        where: { staffId: { in: [testStaffSales?.id, testStaffManager?.id].filter(Boolean) } },
      });
      await prisma.crmAttachment.deleteMany({ where: { customerId: testCustomer.id } });
      await prisma.crmFollowUp.deleteMany({ where: { customerId: testCustomer.id } });
      await prisma.crmActivity.deleteMany({ where: { customerId: testCustomer.id } });
      await prisma.customer.delete({ where: { id: testCustomer.id } });
    }
    if (testStaffSales) {
      await prisma.staff.delete({ where: { id: testStaffSales.id } });
    }
    if (testStaffManager) {
      await prisma.staff.delete({ where: { id: testStaffManager.id } });
    }
    if (testUserSales) {
      await prisma.user.delete({ where: { id: testUserSales.id } });
    }
    if (testUserManager) {
      await prisma.user.delete({ where: { id: testUserManager.id } });
    }
    await prisma.$disconnect();
    console.log('Cleanup completed.');
  }

  console.log('\n========================================================================');
  console.log(`PHASE 2 SCHEDULER VERIFICATION SUMMARY:`);
  console.log(`Total Passed: ${testsPassed}`);
  console.log(`Total Failed: ${testsFailed}`);
  console.log('========================================================================\n');

  if (testsFailed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
