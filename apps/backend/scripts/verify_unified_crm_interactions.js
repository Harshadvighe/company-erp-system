const path = require('path');
const fs = require('fs');
const assert = require('assert');

// Load environment configuration from apps/backend/.env.staging
function loadStagingEnv() {
  const envPath = path.resolve(__dirname, '../.env.staging');
  if (!fs.existsSync(envPath)) {
    throw new Error('apps/backend/.env.staging file not found');
  }
  const env = {};
  fs.readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .forEach((l) => {
      const trimmed = l.trim();
      if (!trimmed || trimmed.startsWith('#')) return;
      const eq = trimmed.indexOf('=');
      if (eq !== -1) {
        const key = trimmed.slice(0, eq).trim();
        let val = trimmed.slice(eq + 1).trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.slice(1, -1);
        }
        env[key] = val;
      }
    });
  return env;
}

const env = loadStagingEnv();
if (!env.DATABASE_URL) {
  console.error('DATABASE_URL missing in .env.staging');
  process.exit(1);
}

// 1. Initialize Prisma Staging Client
const { PrismaClient: StagingPrismaClient } = require(path.resolve(
  __dirname,
  '../node_modules/@prisma/client-staging'
));
const stagingPrisma = new StagingPrismaClient({
  datasources: {
    db: { url: env.DATABASE_URL },
  },
});

// 2. Load Services from dist
const { LocalFileStorageService } = require('../dist/src/core/storage/file-storage.service');
const { AuditService } = require('../dist/src/core/audit/audit.service');
const { SequenceService } = require('../dist/src/core/database/sequence.service');
const { GstVerificationService } = require('../dist/src/modules/crm/gst-verification.service');
const { CrmService } = require('../dist/src/modules/crm/crm.service');

let passed = 0;
let failed = 0;

function reportPass(label, details = '') {
  passed++;
  console.log(`  [PASS] ${label}${details ? ' - ' + details : ''}`);
}

function reportFail(label, err) {
  failed++;
  console.error(`  [FAIL] ${label}:`, err?.message || err);
  if (err?.stack) console.error(err.stack);
}

async function runUnifiedInteractionsVerification() {
  console.log('========================================================================');
  console.log('SAARK ERP CRM — UNIFIED INTERACTION WORKSPACE ACCEPTANCE VERIFICATION');
  console.log('========================================================================\n');

  await stagingPrisma.$connect();
  reportPass('Connected to Staging PostgreSQL');

  // Pre-cleanup of any orphaned test tasks or activities
  const orphanedTasks = await stagingPrisma.task.findMany({
    where: { description: { contains: '[SiteVisit:' } },
  });
  if (orphanedTasks.length > 0) {
    const oIds = orphanedTasks.map(t => t.id);
    await stagingPrisma.taskActivity.deleteMany({ where: { taskId: { in: oIds } } });
    await stagingPrisma.task.deleteMany({ where: { id: { in: oIds } } });
  }

  const orphanedActivities = await stagingPrisma.crmActivity.findMany({
    where: { description: { contains: 'solar pump panels' } },
  });
  if (orphanedActivities.length > 0) {
    for (const a of orphanedActivities) {
      const calls = await stagingPrisma.crmCall.findMany({ where: { activityId: a.id } });
      for (const c of calls) {
        await stagingPrisma.callRecording.deleteMany({ where: { callId: c.id } });
      }
      await stagingPrisma.crmCall.deleteMany({ where: { activityId: a.id } });
      await stagingPrisma.crmActivity.delete({ where: { id: a.id } }).catch(() => {});
    }
  }

  const baseline = {
    customers: await stagingPrisma.customer.count(),
    siteVisits: await stagingPrisma.crmSiteVisit.count(),
    meetings: await stagingPrisma.crmMeeting.count(),
    activities: await stagingPrisma.crmActivity.count(),
    tasks: await stagingPrisma.task.count(),
  };

  console.log(`Baseline staging records:`);
  console.log(`  Customers:    ${baseline.customers}`);
  console.log(`  Site Visits:  ${baseline.siteVisits}`);
  console.log(`  Meetings:     ${baseline.meetings}`);
  console.log(`  Activities:   ${baseline.activities}`);
  console.log(`  Tasks:        ${baseline.tasks}\n`);

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

  const activeStaff = await stagingPrisma.staff.findMany({
    where: { status: 'ACTIVE' },
    take: 5,
  });
  assert(activeStaff.length >= 2, 'Need at least 2 active staff records on staging to test team assignment');

  const staff1 = activeStaff[0];
  const staff2 = activeStaff[1];

  const testUser = {
    id: staff1.userId || staff1.id,
    userId: staff1.userId || staff1.id,
    staffId: staff1.id,
    roles: ['ROLE_SALES', 'ROLE_EMPLOYEE', 'ROLE_ADMIN'],
    fullName: staff1.fullName,
    email: staff1.email || 'test@saark.local',
  };

  // Use existing active customer on staging
  const testCustomer = await stagingPrisma.customer.findFirst({
    where: { status: 'ACTIVE' },
  });
  assert(testCustomer, 'An active customer must exist on staging');

  const createdEntities = {
    activityIds: [],
    taskIds: [],
  };

  try {
    // -------------------------------------------------------------
    // TEST 1: Site Visit Team Size Mismatch Validation
    // -------------------------------------------------------------
    console.log('\n--- Section 1: Site Visit Team Validation ---');
    try {
      await crmService.createSiteVisit(
        {
          customerId: testCustomer.id,
          visitPurpose: 'Preliminary site measurements',
          siteLocation: 'Pune Industrial Area Shed 4',
          visitDate: new Date(),
          teamSize: 3,
          teamMemberIds: [staff1.id], // 1 member for teamSize 3
        },
        testUser
      );
      reportFail('Team size mismatch rejection', new Error('Expected validation error for teamSize mismatch'));
    } catch (err) {
      if (err.message && (err.message.toLowerCase().includes('team size') || err.message.includes('team member count'))) {
        reportPass('Team size mismatch rejection', err.message);
      } else {
        reportFail('Team size mismatch rejection', err);
      }
    }

    // -------------------------------------------------------------
    // TEST 2: Site Visit Duplicate Team Members Rejection
    // -------------------------------------------------------------
    try {
      await crmService.createSiteVisit(
        {
          customerId: testCustomer.id,
          visitPurpose: 'Preliminary site measurements',
          siteLocation: 'Pune Industrial Area Shed 4',
          visitDate: new Date(),
          teamSize: 2,
          teamMemberIds: [staff1.id, staff1.id], // duplicate
        },
        testUser
      );
      reportFail('Duplicate team member rejection', new Error('Expected validation error for duplicate members'));
    } catch (err) {
      if (err.message && err.message.toLowerCase().includes('duplicate team member')) {
        reportPass('Duplicate team member rejection', err.message);
      } else {
        reportFail('Duplicate team member rejection', err);
      }
    }

    // -------------------------------------------------------------
    // TEST 3: Site Visit Creation + Multi-Employee Task Integration
    // -------------------------------------------------------------
    const validSiteVisit = await crmService.createSiteVisit(
      {
        customerId: testCustomer.id,
        visitPurpose: 'VFD Panel site clearance and earthing check',
        siteLocation: 'Pune Chakan Phase 2',
        visitDate: new Date(Date.now() + 86400000), // tomorrow
        startTime: '10:00 AM',
        endTime: '01:00 PM',
        teamSize: 2,
        teamMemberIds: [staff1.id, staff2.id],
        agenda: 'Check cable tray routing and power incomer busbar',
      },
      testUser
    );
    assert(validSiteVisit && validSiteVisit.id, 'Site visit must be created with ID');
    if (validSiteVisit.activityId) {
      createdEntities.activityIds.push(validSiteVisit.activityId);
    }
    reportPass('Site visit creation with teamSize=2', `ID: ${validSiteVisit.id}`);

    // Verify tasks generated for both employees
    const visitTasks = await stagingPrisma.task.findMany({
      where: {
        description: { contains: `[SiteVisit:${validSiteVisit.id}]` },
      },
    });
    for (const t of visitTasks) {
      createdEntities.taskIds.push(t.id);
    }
    assert.strictEqual(visitTasks.length, 2, 'Exactly 2 tasks must be created, one per assigned team member');
    for (const t of visitTasks) {
      assert(t.title.startsWith('[Site Visit]'), 'Task title must identify activity as [Site Visit]');
      assert([staff1.id, staff2.id].includes(t.assigneeStaffId), 'Task must be assigned to correct staff ID');
      assert(t.description.includes('/crm/interactions?customerId='), 'Task description must include direct navigation link');
    }
    reportPass('Tasks created and linked for all assigned team members in Tasks/My Work', `Task IDs: ${visitTasks.map(t=>t.id).join(', ')}`);

    // -------------------------------------------------------------
    // TEST 4: Meeting Creation + Host Task Integration
    // -------------------------------------------------------------
    console.log('\n--- Section 2: Meeting Creation & Task Integration ---');
    const meeting = await crmService.createMeeting(
      {
        customerId: testCustomer.id,
        title: 'Commercial Discussion: VFD Control Panels',
        agenda: 'Finalize payment terms and warranty period',
        meetingDate: new Date(Date.now() + 172800000), // 2 days from now
        startTime: '02:30 PM',
        endTime: '03:30 PM',
        location: 'Conference Room 1 / Google Meet',
        isOnline: true,
        meetingLink: 'https://meet.google.com/xyz-test',
        hostStaffId: staff1.id,
      },
      testUser
    );
    assert(meeting && meeting.id, 'Meeting must be created with ID');
    if (meeting.activityId) {
      createdEntities.activityIds.push(meeting.activityId);
    }
    reportPass('Meeting created with host and agenda', `ID: ${meeting.id}`);

    const meetingTasks = await stagingPrisma.task.findMany({
      where: {
        description: { contains: `[Meeting:${meeting.id}]` },
      },
    });
    for (const t of meetingTasks) {
      createdEntities.taskIds.push(t.id);
    }
    assert.strictEqual(meetingTasks.length, 1, 'Exactly 1 task must be created for the meeting host');
    assert(meetingTasks[0].title.startsWith('[Meeting]'), 'Task title must identify activity as [Meeting]');
    assert.strictEqual(meetingTasks[0].assigneeStaffId, staff1.id, 'Task must be assigned to meeting host');
    reportPass('Task created for meeting host in Tasks/My Work', `Task ID: ${meetingTasks[0].id}`);

    // -------------------------------------------------------------
    // TEST 5: Call Logging with Outcome and Next Follow-up
    // -------------------------------------------------------------
    console.log('\n--- Section 3: Call Workflow & Outcomes ---');
    const callActivity = await crmService.createCall(
      {
        customerId: testCustomer.id,
        contactPerson: 'Aditi Sharma',
        phoneNumber: '9876543210',
        outcome: 'CONNECTED',
        callOutcome: 'CONNECTED',
        subject: 'Introductory call regarding solar pump panels',
        notes: 'Customer is interested in 10HP hybrid solar VFD drive.',
        scheduleNext: true,
        nextActivityType: 'FOLLOW_UP',
        nextScheduledDate: new Date(Date.now() + 86400000),
        nextSubject: 'Share product brochure and preliminary quote',
      },
      testUser
    );
    assert(callActivity && callActivity.id, 'Call activity must be created');
    if (callActivity.activityId) {
      createdEntities.activityIds.push(callActivity.activityId);
    }
    reportPass('Call logged with outcome CONNECTED and automatic next follow-up', `Call ID: ${callActivity.id}, Activity ID: ${callActivity.activityId}`);

    // Verify activity appears in Customer Timeline
    const timeline = await crmService.getCompanyTimeline(testCustomer.id, testUser);
    assert(Array.isArray(timeline), 'Customer timeline must be an array');
    const hasCall = timeline.some((item) => item.id === callActivity.activityId || (item.type && item.type.includes('CALL')));
    const hasSiteVisit = timeline.some((item) => (item.type && item.type.includes('SITE_VISIT')) || (item.title && item.title.includes('Site Inspection')) || (item.metadata && item.metadata.siteVisit));
    const hasMeeting = timeline.some((item) => (item.type && item.type.includes('MEETING')) || (item.title && item.title.includes('Commercial Discussion')) || (item.metadata && item.metadata.meeting));

    assert(hasCall, 'Customer timeline must include the call activity');
    assert(hasSiteVisit, 'Customer timeline must include the site visit');
    assert(hasMeeting, 'Customer timeline must include the meeting');
    reportPass('Unified Customer Timeline contains calls, site visits, and meetings without drift');

  } finally {
    // -------------------------------------------------------------
    // CLEANUP: Zero Data Drift
    // -------------------------------------------------------------
    console.log('\n--- Section 4: Cleanup & Data Drift Verification ---');
    for (const taskId of createdEntities.taskIds) {
      await stagingPrisma.taskActivity.deleteMany({ where: { taskId } });
      await stagingPrisma.task.delete({ where: { id: taskId } }).catch(() => {});
    }

    // Deleting parent crmActivity cascades to crmSiteVisit, crmMeeting, crmCall
    for (const activityId of createdEntities.activityIds) {
      await stagingPrisma.crmSiteVisit.deleteMany({ where: { activityId } });
      await stagingPrisma.crmMeeting.deleteMany({ where: { activityId } });
      const calls = await stagingPrisma.crmCall.findMany({ where: { activityId } });
      for (const c of calls) {
        await stagingPrisma.callRecording.deleteMany({ where: { callId: c.id } });
      }
      await stagingPrisma.crmCall.deleteMany({ where: { activityId } });
      await stagingPrisma.crmActivity.delete({ where: { id: activityId } }).catch(() => {});
    }

    // Clean up follow-ups created for testCustomer
    await stagingPrisma.crmFollowUp.deleteMany({
      where: { customerId: testCustomer.id },
    });

    // Check final counts against baseline
    const finalCounts = {
      customers: await stagingPrisma.customer.count(),
      siteVisits: await stagingPrisma.crmSiteVisit.count(),
      meetings: await stagingPrisma.crmMeeting.count(),
      activities: await stagingPrisma.crmActivity.count(),
      tasks: await stagingPrisma.task.count(),
    };

    console.log(`Final staging records:`);
    console.log(`  Site Visits:  ${finalCounts.siteVisits} (Baseline: ${baseline.siteVisits})`);
    console.log(`  Meetings:     ${finalCounts.meetings} (Baseline: ${baseline.meetings})`);
    console.log(`  Activities:   ${finalCounts.activities} (Baseline: ${baseline.activities})`);
    console.log(`  Tasks:        ${finalCounts.tasks} (Baseline: ${baseline.tasks})`);

    assert.strictEqual(finalCounts.siteVisits, baseline.siteVisits, 'Site visits count must match baseline');
    assert.strictEqual(finalCounts.meetings, baseline.meetings, 'Meetings count must match baseline');
    assert.strictEqual(finalCounts.activities, baseline.activities, 'Activities count must match baseline');
    assert.strictEqual(finalCounts.tasks, baseline.tasks, 'Tasks count must match baseline');
    reportPass('Zero database drift: all staging record counts returned to exact baseline');
  }

  console.log('\n========================================================================');
  console.log(`SUMMARY: ${passed} passed, ${failed} failed`);
  console.log('========================================================================\n');

  await stagingPrisma.$disconnect();
  if (failed > 0) {
    process.exit(1);
  }
}

runUnifiedInteractionsVerification().catch((err) => {
  console.error('Unhandled verification error:', err);
  process.exit(1);
});
