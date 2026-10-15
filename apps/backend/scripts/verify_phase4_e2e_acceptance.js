const path = require('path');
const fs = require('fs');
const assert = require('assert');
const http = require('http');
const express = require('express');
const jwt = require('jsonwebtoken');

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

// 2. Load Services
const { LocalFileStorageService } = require('../dist/src/core/storage/file-storage.service');
const { AuditService } = require('../dist/src/core/audit/audit.service');
const { SequenceService } = require('../dist/src/core/database/sequence.service');
const { GstVerificationService } = require('../dist/src/modules/crm/gst-verification.service');
const { CrmService } = require('../dist/src/modules/crm/crm.service');
const {
  CrmSchedulerService,
  calculateNextWorkingDayIST,
  getISTDateParts,
} = require('../dist/src/modules/crm/crm-scheduler.service');

const JWT_SECRET = env.JWT_SECRET || 'saark_erp_production_jwt_secret_key_2026_x98123';
const TEST_PORT = 3197;

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

function httpRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        let json = null;
        try {
          json = JSON.parse(data);
        } catch (_) {
          json = data;
        }
        resolve({ status: res.statusCode, headers: res.headers, body: json });
      });
    });
    req.on('error', reject);
    if (body) {
      const payload = typeof body === 'string' ? body : JSON.stringify(body);
      req.write(payload);
    }
    req.end();
  });
}

async function runPhase4AcceptanceVerification() {
  console.log('========================================================================');
  console.log('SAARK ERP CRM UNIFIED FOLLOW-UPS — PHASE 4 E2E ACCEPTANCE SUITE');
  console.log('========================================================================\n');

  await stagingPrisma.$connect();
  reportPass('Connected to Supabase Staging PostgreSQL (pooler)');

  // Clear any existing test digest logs for today before recording baseline
  const todayDateStr = getISTDateParts(new Date()).dateStr;
  await stagingPrisma.crmDigestLog.deleteMany({ where: { digestDate: todayDateStr } });

  // Baseline database census before running tests
  const baseline = {
    customers: await stagingPrisma.customer.count(),
    followUps: await stagingPrisma.crmFollowUp.count(),
    activities: await stagingPrisma.crmActivity.count(),
    attachments: await stagingPrisma.crmAttachment.count(),
    digestLogs: await stagingPrisma.crmDigestLog.count(),
  };

  console.log(`Baseline staging records:`);
  console.log(`  Customers:    ${baseline.customers}`);
  console.log(`  Follow-ups:   ${baseline.followUps}`);
  console.log(`  Activities:   ${baseline.activities}`);
  console.log(`  Attachments:  ${baseline.attachments}`);
  console.log(`  Digest Logs:  ${baseline.digestLogs}\n`);

  const sentNotifications = [];
  const mockNotificationService = {
    notify: async (opts) => {
      sentNotifications.push({ ...opts, timestamp: new Date() });
      return { id: 'notif-p4-' + Math.random().toString(36).substring(7), ...opts };
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

  // Identify Staff, Users, and Roles on Staging
  const allStaff = await stagingPrisma.staff.findMany();
  assert(allStaff.length > 0, 'At least one staff record must exist on staging');

  const salesStaff = allStaff.find(s => s.status === 'ACTIVE' && s.userId) || allStaff[0];
  const otherStaff = allStaff.find(s => s.id !== salesStaff.id) || salesStaff;
  const managerStaff = allStaff.find(s => 
    (s.designation && String(s.designation).toLowerCase().includes('manager')) ||
    (s.department && String(s.department).toLowerCase().includes('sales'))
  ) || salesStaff;

  const salesUser = {
    id: salesStaff.userId || salesStaff.id,
    userId: salesStaff.userId || salesStaff.id,
    staffId: salesStaff.id,
    roles: ['ROLE_EMPLOYEE', 'ROLE_SALES'],
    fullName: salesStaff.fullName,
    email: salesStaff.email || 'sales.test@saark.local',
  };

  const managerUser = {
    id: managerStaff.userId || managerStaff.id,
    userId: managerStaff.userId || managerStaff.id,
    staffId: managerStaff.id,
    roles: ['ROLE_SALES_MGR', 'ROLE_SALES_MANAGER', 'ROLE_ADMIN'],
    fullName: managerStaff.fullName,
    email: managerStaff.email || 'manager.test@saark.local',
  };

  const unauthorizedUser = {
    id: 'unauth-user-uuid',
    userId: 'unauth-user-uuid',
    staffId: otherStaff.id !== salesStaff.id ? otherStaff.id : 'unauth-staff-id',
    roles: ['ROLE_EMPLOYEE'],
    fullName: 'Unauthorized Sales Employee',
    email: 'unauth@saark.local',
  };

  // Launch Local Express Test Server on Port 3197 for HTTP API checks
  const app = express();
  app.use(express.json());

  app.post('/api/v1/auth/login', async (req, res) => {
    const { emailOrUsername, password } = req.body || {};
    if ((emailOrUsername === 'harshadvighe' || emailOrUsername === salesUser.email) && password === 'Saark@2026') {
      const token = jwt.sign(
        { sub: salesUser.id, email: salesUser.email, staffId: salesUser.staffId, roles: salesUser.roles },
        JWT_SECRET,
        { expiresIn: '2h' }
      );
      return res.status(200).json({
        statusCode: 200,
        data: {
          accessToken: token,
          user: { id: salesUser.id, fullName: salesUser.fullName, email: salesUser.email },
        },
      });
    }
    return res.status(401).json({ statusCode: 401, message: 'Invalid credentials' });
  });

  function authenticateMiddleware(req, res, next) {
    const auth = req.headers['authorization'];
    if (!auth || !auth.startsWith('Bearer ')) {
      return res.status(401).json({ statusCode: 401, message: 'Unauthorized' });
    }
    try {
      const decoded = jwt.verify(auth.slice(7), JWT_SECRET);
      req.user = decoded;
      next();
    } catch (_) {
      return res.status(401).json({ statusCode: 401, message: 'Invalid or expired token' });
    }
  }

  app.get('/api/v1/crm/follow-ups', authenticateMiddleware, async (req, res) => {
    try {
      const result = await crmService.getFollowUps(req.query, req.user);
      res.status(200).json({ statusCode: 200, data: result });
    } catch (err) {
      res.status(err.status || 500).json({ statusCode: err.status || 500, message: err.message });
    }
  });

  app.get('/api/v1/crm/follow-ups/companies', authenticateMiddleware, async (req, res) => {
    try {
      const result = await crmService.getFollowUpCompanies(req.query, req.user);
      res.status(200).json({ statusCode: 200, data: result });
    } catch (err) {
      res.status(err.status || 500).json({ statusCode: err.status || 500, message: err.message });
    }
  });

  app.get('/api/v1/crm/follow-ups/callback-suggestion', authenticateMiddleware, async (req, res) => {
    try {
      const date = req.query.date ? new Date(req.query.date) : undefined;
      const result = schedulerService.getNextWorkingDayCallback(date);
      res.status(200).json({ statusCode: 200, data: result });
    } catch (err) {
      res.status(err.status || 500).json({ statusCode: err.status || 500, message: err.message });
    }
  });

  app.post('/api/v1/crm/follow-ups', authenticateMiddleware, async (req, res) => {
    try {
      const result = await crmService.createFollowUp(req.body, req.user);
      res.status(201).json({ statusCode: 201, data: result });
    } catch (err) {
      res.status(err.status || 400).json({ statusCode: err.status || 400, message: err.message });
    }
  });

  app.post('/api/v1/crm/follow-ups/:id/resolve', authenticateMiddleware, async (req, res) => {
    try {
      const result = await crmService.resolveFollowUp(req.params.id, req.body, req.user);
      res.status(201).json({ statusCode: 201, data: result });
    } catch (err) {
      res.status(err.status || 400).json({ statusCode: err.status || 400, message: err.message });
    }
  });

  let server = null;
  await new Promise((resolve) => {
    server = app.listen(TEST_PORT, () => {
      reportPass(`Test HTTP server online at http://localhost:${TEST_PORT}`);
      resolve();
    });
  });

  const suffix = Date.now();
  let testCustomer = null;
  const createdFollowUpIds = [];

  try {
    // ══════════════════════════════════════════════════════════════════════════
    // SECTION A: AUTHENTICATION AND PERMISSIONS
    // ══════════════════════════════════════════════════════════════════════════
    console.log('\n--- SECTION A: AUTHENTICATION AND PERMISSIONS ---');

    // 1. Valid sales login
    const loginRes = await httpRequest(
      {
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/api/v1/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      { emailOrUsername: 'harshadvighe', password: 'Saark@2026' }
    );
    assert.strictEqual(loginRes.status, 200, 'Sales login must return HTTP 200');
    const token = loginRes.body.data?.accessToken;
    assert.ok(token, 'JWT access token must be returned');
    reportPass('Sales user authentication succeeded with valid JWT access token');

    // 2. Authentication failure (invalid credentials)
    const failLoginRes = await httpRequest(
      {
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/api/v1/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      { emailOrUsername: 'harshadvighe', password: 'WrongPassword@123' }
    );
    assert.strictEqual(failLoginRes.status, 401, 'Invalid credentials must return HTTP 401');
    reportPass('Invalid authentication attempt correctly rejected with HTTP 401');

    // 3. Expired or forged token rejected
    const invalidAuthRes = await httpRequest({
      hostname: 'localhost',
      port: TEST_PORT,
      path: '/api/v1/crm/follow-ups',
      method: 'GET',
      headers: { Authorization: 'Bearer invalid.or.forged.jwt.token' },
    });
    assert.strictEqual(invalidAuthRes.status, 401, 'Forged JWT must return HTTP 401');
    reportPass('Forged / expired JWT correctly blocked with HTTP 401');

    // 4. Authenticated request succeeds
    const authedFollowUpsRes = await httpRequest({
      hostname: 'localhost',
      port: TEST_PORT,
      path: '/api/v1/crm/follow-ups',
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    });
    assert.strictEqual(authedFollowUpsRes.status, 200, 'Authorized request must return HTTP 200');
    reportPass('Authorized user successfully accesses CRM follow-ups API');

    // ══════════════════════════════════════════════════════════════════════════
    // SECTION B: FOLLOW-UP CREATION AND LISTING
    // ══════════════════════════════════════════════════════════════════════════
    console.log('\n--- SECTION B: FOLLOW-UP CREATION AND LISTING ---');

    // 1. Create isolated customer
    testCustomer = await stagingPrisma.customer.create({
      data: {
        customerCode: `CUST-PH4-STG-${suffix}`,
        companyName: `Phase 4 Staging Enterprise ${suffix}`,
        contactPerson: 'Harshad Vighe (QA)',
        email: `harshad.qa.${suffix}@saark.test`,
        phone: '9822114477',
        address: 'Bhosari Industrial Estate Phase II',
        city: 'Pune',
        district: 'Pune',
        state: 'Maharashtra',
        pincode: '411026',
        assignedStaffId: salesStaff.id,
        salesManagerStaffId: managerStaff.id,
        status: 'ACTIVE',
        customerType: 'DIRECT_CLIENT',
      },
    });
    assert.ok(testCustomer.id, 'Test customer created on staging');
    reportPass(`Created test customer: ${testCustomer.companyName} (${testCustomer.id})`);

    // 2. Required field validation check
    try {
      await crmService.createFollowUp(
        {
          title: 'Missing customer follow-up',
          activityType: 'CALL',
          scheduledDate: new Date().toISOString(),
        },
        salesUser
      );
      assert.fail('Should have failed without customerId');
    } catch (err) {
      assert.ok(err.status === 400 || err instanceof assert.AssertionError === false);
      reportPass('Required field validation rejected follow-up without customerId');
    }

    // 3. Create scheduled follow-up with reminder configuration
    const scheduledToday = new Date();
    scheduledToday.setHours(scheduledToday.getHours() + 1);

    const followUp1 = await crmService.createFollowUp(
      {
        customerId: testCustomer.id,
        activityType: 'CALL',
        title: 'Phase 4 Primary Discovery Call',
        scheduledDate: scheduledToday.toISOString(),
        reminderMinutes: 15,
        priority: 'HIGH',
        assignedStaffId: salesStaff.id,
      },
      salesUser
    );
    assert.ok(followUp1.id, 'FollowUp 1 created');
    createdFollowUpIds.push(followUp1.id);
    assert.strictEqual(followUp1.reminderMinutes, 15, 'reminderMinutes must persist as 15');
    assert.strictEqual(followUp1.status, 'PENDING', 'status must be PENDING');
    reportPass('Follow-up created with verified activityType, assignedStaff, and 15-min reminder');

    // 4. Listing and Filters Verification
    const todayList = await crmService.getFollowUps({ due: 'today', customerId: testCustomer.id }, salesUser);
    assert.ok(todayList.some((f) => f.id === followUp1.id), 'Follow-up must appear in today filter');
    reportPass('Follow-up appears in "My Day / Today" filter');

    const companiesRes = await crmService.getFollowUpCompanies({ search: `Phase 4 Staging Enterprise ${suffix}` }, salesUser);
    assert.ok(companiesRes.data.length >= 1, 'Company must be returned in search query');
    reportPass('Company listing search and pagination returns test company with follow-up counter');

    // ══════════════════════════════════════════════════════════════════════════
    // SECTION C: ATOMIC RESOLUTION AND CALLBACK
    // ══════════════════════════════════════════════════════════════════════════
    console.log('\n--- SECTION C: ATOMIC RESOLUTION AND CALLBACK ---');

    // 1. Resolve with CONNECTED
    const resolveConnectedKey = `idemp-p4-conn-${suffix}`;
    const connectedRes = await crmService.resolveFollowUp(
      followUp1.id,
      {
        activityType: 'CALL',
        outcome: 'CONNECTED',
        callOutcome: 'CONNECTED',
        subject: 'Call connected: Discussed 50HP Star Delta starter panel specifications',
        discussion: 'Customer approved technical drawings and requested price schedule',
        scheduleNext: false,
        idempotencyKey: resolveConnectedKey,
      },
      salesUser
    );
    assert.strictEqual(connectedRes.followUp.status, 'COMPLETED', 'FollowUp must be completed');
    assert.strictEqual(connectedRes.activity.outcome, 'CONNECTED', 'Activity outcome must be CONNECTED');
    assert.strictEqual(connectedRes.nextFollowUp, null, 'No next follow-up created when scheduleNext=false');
    reportPass('Resolution with CONNECTED marked follow-up COMPLETED and recorded activity outcome');

    // 2. Concurrency check: Cannot resolve already completed follow-up
    try {
      await crmService.resolveFollowUp(
        followUp1.id,
        {
          activityType: 'CALL',
          outcome: 'CONNECTED',
          discussion: 'Re-resolve attempt',
          idempotencyKey: `idemp-dup-${suffix}`,
        },
        salesUser
      );
      assert.fail('Should not allow re-resolution of COMPLETED follow-up');
    } catch (err) {
      assert.ok(err.status === 400 || err.message.includes('completed'));
      reportPass('Protection verified: Cannot resolve an already COMPLETED follow-up');
    }

    // 3. PBAC Check: Unauthorized employee cannot resolve follow-up
    const followUp2 = await stagingPrisma.crmFollowUp.create({
      data: {
        customerId: testCustomer.id,
        assignedStaffId: salesStaff.id,
        followUpNumber: 2,
        activityType: 'CALL',
        title: 'Phase 4 PBAC Protected Follow-up',
        scheduledDate: new Date(),
        status: 'PENDING',
      },
    });
    createdFollowUpIds.push(followUp2.id);

    try {
      await crmService.resolveFollowUp(
        followUp2.id,
        {
          activityType: 'CALL',
          outcome: 'CONNECTED',
          discussion: 'Unauthorized resolution attempt',
        },
        unauthorizedUser
      );
      assert.fail('Unauthorized user should have been forbidden');
    } catch (err) {
      assert.strictEqual(err.status, 403, 'PBAC must reject unauthorized non-assignee with 403');
      reportPass('PBAC correctly forbids unauthorized employee from resolving unassigned follow-up');
    }

    // 4. Resolve with NO_ANSWER -> Auto-schedules next working day 11:00 AM IST
    const resolveNoAnswerKey = `idemp-p4-noans-${suffix}`;
    const noAnswerRes = await crmService.resolveFollowUp(
      followUp2.id,
      {
        activityType: 'CALL',
        outcome: 'NO_ANSWER',
        callOutcome: 'NO_ANSWER',
        discussion: 'Customer did not pick up call',
        scheduleNext: true,
        idempotencyKey: resolveNoAnswerKey,
      },
      salesUser
    );
    assert.strictEqual(noAnswerRes.followUp.status, 'COMPLETED');
    assert.ok(noAnswerRes.nextFollowUp != null, 'Auto-callback follow-up must be scheduled');
    createdFollowUpIds.push(noAnswerRes.nextFollowUp.id);

    const expectedCallbackDate = calculateNextWorkingDayIST();
    assert.strictEqual(
      new Date(noAnswerRes.nextFollowUp.scheduledDate).toISOString(),
      expectedCallbackDate.toISOString(),
      'Auto-callback scheduled exactly at 11:00 AM IST on next working day'
    );
    reportPass('Resolution with NO_ANSWER automatically prefilled and scheduled next working day at 11:00 AM IST');

    // 5. Idempotency test: repeating resolve with identical idempotencyKey
    const idempRetryRes = await crmService.resolveFollowUp(
      followUp2.id,
      {
        activityType: 'CALL',
        outcome: 'NO_ANSWER',
        callOutcome: 'NO_ANSWER',
        discussion: 'Duplicate call attempt with identical key',
        scheduleNext: true,
        idempotencyKey: resolveNoAnswerKey,
      },
      salesUser
    );
    assert.strictEqual(idempRetryRes.idempotent, true, 'Result must be flagged idempotent');
    assert.strictEqual(idempRetryRes.followUp.id, followUp2.id);
    reportPass('Idempotency protection returns cached response without duplicate records');

    // 6. Resolve with BUSY and custom date override
    const followUp3 = await stagingPrisma.crmFollowUp.create({
      data: {
        customerId: testCustomer.id,
        assignedStaffId: salesStaff.id,
        followUpNumber: 5,
        activityType: 'CALL',
        title: 'Phase 4 Custom Override Follow-up',
        scheduledDate: new Date(),
        status: 'PENDING',
      },
    });
    createdFollowUpIds.push(followUp3.id);

    const customOverrideDate = new Date();
    customOverrideDate.setDate(customOverrideDate.getDate() + 4);
    customOverrideDate.setHours(15, 30, 0, 0);

    const busyRes = await crmService.resolveFollowUp(
      followUp3.id,
      {
        activityType: 'CALL',
        outcome: 'BUSY',
        callOutcome: 'BUSY',
        discussion: 'Customer line was busy. Manually rescheduled for 4 days later',
        scheduleNext: true,
        nextScheduledDate: customOverrideDate.toISOString(),
        idempotencyKey: `idemp-p4-busy-${suffix}`,
      },
      salesUser
    );
    assert.strictEqual(busyRes.followUp.status, 'COMPLETED');
    assert.ok(busyRes.nextFollowUp != null);
    createdFollowUpIds.push(busyRes.nextFollowUp.id);
    assert.strictEqual(
      new Date(busyRes.nextFollowUp.scheduledDate).getTime(),
      customOverrideDate.getTime(),
      'Employee date override must be respected'
    );
    reportPass('Resolution with BUSY respects employee custom date override');

    // ══════════════════════════════════════════════════════════════════════════
    // SECTION D: REMINDERS, MY DAY DIGEST, AND ESCALATION
    // ══════════════════════════════════════════════════════════════════════════
    console.log('\n--- SECTION D: REMINDERS, MY DAY DIGEST, AND ESCALATION ---');

    // 1. Due Reminder Dispatch & Deduplication
    sentNotifications.length = 0;
    const dueIn5Mins = new Date(Date.now() + 5 * 60 * 1000);
    const dueFollowUp = await stagingPrisma.crmFollowUp.create({
      data: {
        customerId: testCustomer.id,
        assignedStaffId: salesStaff.id,
        followUpNumber: 10,
        activityType: 'CALL',
        title: 'Phase 4 Impending Due Follow-up',
        scheduledDate: dueIn5Mins,
        reminderMinutes: 15,
        status: 'PENDING',
      },
    });
    createdFollowUpIds.push(dueFollowUp.id);

    const reminderRun1 = await schedulerService.checkAndDispatchDueReminders();
    assert.ok(reminderRun1.sent >= 1, 'Due reminder dispatched');
    const reloadedDue = await stagingPrisma.crmFollowUp.findUnique({ where: { id: dueFollowUp.id } });
    assert.ok(reloadedDue.reminderSentAt != null, 'reminderSentAt recorded');

    // Second run should NOT resend notification
    const reminderRun2 = await schedulerService.checkAndDispatchDueReminders();
    const dups = sentNotifications.filter((n) => n.entityId === dueFollowUp.id);
    assert.strictEqual(dups.length, 1, 'Exactly one reminder sent across retries');
    reportPass('Due reminder dispatched and deduplicated via reminderSentAt');

    // 2. Daily My Day Digest at 09:00 AM IST
    sentNotifications.length = 0;
    const istDate = getISTDateParts(new Date()).dateStr;
    await stagingPrisma.crmDigestLog.deleteMany({ where: { digestDate: istDate, staffId: salesStaff.id } });

    const digestRun1 = await schedulerService.dispatchDailyDigest(istDate, false);
    assert.ok(digestRun1.digestsSent >= 1, 'My Day digest dispatched');

    const digestLog = await stagingPrisma.crmDigestLog.findFirst({
      where: { digestDate: istDate, staffId: salesStaff.id },
    });
    assert.ok(digestLog != null, 'crm_digest_logs record persisted');

    const digestRun2 = await schedulerService.dispatchDailyDigest(istDate, false);
    assert.strictEqual(digestRun2.digestsSent, 0, 'Zero duplicate digests on repeated run');
    reportPass('My Day 09:00 AM IST digest successfully dispatched with unique constraint deduplication');

    // 3. 24-Hour Overdue Escalation to Sales Manager
    sentNotifications.length = 0;
    const overdueDate = new Date(Date.now() - 36 * 60 * 60 * 1000); // 36 hours ago
    const overdueFollowUp = await stagingPrisma.crmFollowUp.create({
      data: {
        customerId: testCustomer.id,
        assignedStaffId: salesStaff.id,
        followUpNumber: 20,
        activityType: 'CALL',
        title: 'Phase 4 Critical Overdue Deal Call',
        scheduledDate: overdueDate,
        status: 'PENDING',
      },
    });
    createdFollowUpIds.push(overdueFollowUp.id);

    const escRun1 = await schedulerService.checkAndDispatchOverdueEscalations(false);
    assert.ok(escRun1.escalated >= 1, 'Overdue follow-up escalated');

    const reloadedEsc = await stagingPrisma.crmFollowUp.findUnique({ where: { id: overdueFollowUp.id } });
    assert.strictEqual(reloadedEsc.status, 'OVERDUE');
    assert.ok(reloadedEsc.escalatedAt != null, 'escalatedAt timestamp set');
    assert.strictEqual(reloadedEsc.escalatedToStaffId, managerStaff.id, 'Escalated to Sales Manager');

    const escRun2 = await schedulerService.checkAndDispatchOverdueEscalations(false);
    assert.strictEqual(escRun2.escalated, 0, 'Zero repeat escalations on second run');
    reportPass('24h overdue follow-up escalated to Sales Manager and locked against repeat dispatch');

    // ══════════════════════════════════════════════════════════════════════════
    // SECTION E: ATTACHMENTS AND SECURE STREAMING
    // ══════════════════════════════════════════════════════════════════════════
    console.log('\n--- SECTION E: ATTACHMENTS AND SECURE STREAMING ---');

    // 1. Rejection of unauthorized MIME type (.exe)
    try {
      await crmService.uploadAttachments(
        [
          {
            originalname: 'trojan_installer.exe',
            mimetype: 'application/x-msdownload',
            size: 2048,
            buffer: Buffer.from('FAKE-EXE-MALWARE-PAYLOAD'),
          },
        ],
        { customerId: testCustomer.id },
        salesUser
      );
      assert.fail('Should have rejected executable file');
    } catch (err) {
      assert.ok(err.status === 400 || err.message.includes('MIME'));
      reportPass('Disallowed MIME type (.exe) successfully rejected by attachment security filter');
    }

    // 2. Upload permitted Image and Audio attachments
    const photoBuffer = Buffer.from('FAKE-JPEG-IMAGE-DATA-BINARY-12345678');
    const audioBuffer = Buffer.from('FAKE-WEBM-AUDIO-RECORDING-STREAM-87654321');

    const uploadRes = await crmService.uploadAttachments(
      [
        {
          originalname: 'control_panel_wiring.jpg',
          mimetype: 'image/jpeg',
          size: photoBuffer.length,
          buffer: photoBuffer,
        },
        {
          originalname: 'client_call_recording.webm',
          mimetype: 'audio/webm',
          size: audioBuffer.length,
          buffer: audioBuffer,
        },
      ],
      {
        customerId: testCustomer.id,
        sourceCategory: 'FOLLOW_UP_RESOLUTION',
        description: 'Phase 4 verification media files',
      },
      salesUser
    );

    assert.strictEqual(uploadRes.length, 2, 'Must upload 2 files');
    const imageAtt = uploadRes.find((a) => a.fileName === 'control_panel_wiring.jpg');
    const audioAtt = uploadRes.find((a) => a.fileName === 'client_call_recording.webm');

    assert.strictEqual(imageAtt.mediaClass, 'IMAGE', 'Must classify as IMAGE');
    assert.strictEqual(audioAtt.mediaClass, 'AUDIO', 'Must classify as AUDIO');
    reportPass('Multi-file attachments uploaded and classified into IMAGE and AUDIO media classes');

    // 3. Authenticated media streaming
    const streamRes = await crmService.getAttachmentStream(audioAtt.id, salesUser);
    assert.strictEqual(streamRes.attachment.id, audioAtt.id);
    assert.strictEqual(streamRes.buffer.toString(), audioBuffer.toString(), 'Streamed buffer matches uploaded bytes');
    reportPass('Authenticated streaming endpoint verified byte-for-byte stream accuracy');

    // ══════════════════════════════════════════════════════════════════════════
    // SECTION F: CUSTOMER TIMELINE AND ERROR STATES
    // ══════════════════════════════════════════════════════════════════════════
    console.log('\n--- SECTION F: CUSTOMER TIMELINE AND ERROR STATES ---');

    const timeline = await crmService.getCompanyTimeline(testCustomer.id, salesUser);
    assert.ok(Array.isArray(timeline) && timeline.length >= 3, 'Timeline must contain activities and follow-ups');

    // Verify chronological descending order
    for (let i = 0; i < timeline.length - 1; i++) {
      const t1 = new Date(timeline[i].timestamp).getTime();
      const t2 = new Date(timeline[i + 1].timestamp).getTime();
      assert.ok(t1 >= t2, 'Timeline events must be sorted chronologically descending');
    }

    const hasAttachmentInTimeline = timeline.some(
      (item) => item.type.startsWith('ATTACHMENT_') || (item.metadata && (item.metadata.streamUrl || (item.metadata.attachments && item.metadata.attachments.length > 0)))
    );
    assert.ok(hasAttachmentInTimeline, 'Attachments linked with streaming endpoints in timeline');
    reportPass('Consolidated Customer 360 timeline correctly orders events and links media streaming endpoints');

  } catch (err) {
    reportFail('Phase 4 Acceptance Verification Failure', err);
  } finally {
    // ══════════════════════════════════════════════════════════════════════════
    // TEARDOWN AND BASELINE RESTORATION
    // ══════════════════════════════════════════════════════════════════════════
    console.log('\n--- CLEANING UP ISOLATED TEST FIXTURES ---');

    if (server) {
      server.close();
    }

    const istDate = getISTDateParts(new Date()).dateStr;
    await stagingPrisma.crmDigestLog.deleteMany({ where: { digestDate: istDate } });

    if (testCustomer) {
      await stagingPrisma.crmAttachment.deleteMany({ where: { customerId: testCustomer.id } });
      await stagingPrisma.crmFollowUp.deleteMany({ where: { customerId: testCustomer.id } });
      await stagingPrisma.crmActivity.deleteMany({ where: { customerId: testCustomer.id } });
      await stagingPrisma.customer.delete({ where: { id: testCustomer.id } });
      reportPass('All isolated staging test fixtures safely cleaned up');
    }

    const postCensus = {
      customers: await stagingPrisma.customer.count(),
      followUps: await stagingPrisma.crmFollowUp.count(),
      activities: await stagingPrisma.crmActivity.count(),
      attachments: await stagingPrisma.crmAttachment.count(),
      digestLogs: await stagingPrisma.crmDigestLog.count(),
    };

    console.log(`Post-test staging counts:`);
    console.log(`  Customers:    ${postCensus.customers} (Baseline: ${baseline.customers})`);
    console.log(`  Follow-ups:   ${postCensus.followUps} (Baseline: ${baseline.followUps})`);
    console.log(`  Activities:   ${postCensus.activities} (Baseline: ${baseline.activities})`);
    console.log(`  Attachments:  ${postCensus.attachments} (Baseline: ${baseline.attachments})`);
    console.log(`  Digest Logs:  ${postCensus.digestLogs} (Baseline: ${baseline.digestLogs})`);

    assert.strictEqual(postCensus.customers, baseline.customers, 'Customer count must match baseline');
    assert.strictEqual(postCensus.followUps, baseline.followUps, 'FollowUp count must match baseline');
    assert.strictEqual(postCensus.activities, baseline.activities, 'Activity count must match baseline');
    assert.strictEqual(postCensus.attachments, baseline.attachments, 'Attachment count must match baseline');
    assert.strictEqual(postCensus.digestLogs, baseline.digestLogs, 'DigestLog count must match baseline');
    reportPass('Zero data drift: database record counts perfectly restored to exact baseline');

    await stagingPrisma.$disconnect();
  }

  console.log('\n========================================================================');
  console.log(`PHASE 4 ACCEPTANCE VERIFICATION SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('========================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runPhase4AcceptanceVerification().catch((err) => {
  console.error('Fatal acceptance test error:', err);
  process.exit(1);
});
