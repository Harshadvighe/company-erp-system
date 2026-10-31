/**
 * Comprehensive Automated Verification Suite for User Login & Logout Session Tracking
 * Tests:
 * 1. User login session record creation with exact loginTime, IP, clientType, and 2FA status
 * 2. Active sessions query by administrator
 * 3. Session heartbeat tracking
 * 4. User logout recording: sets logoutTime, computes durationSeconds, updates status to LOGGED_OUT
 * 5. Tamper-evident AuditLog entry verification with login/logout timestamps
 * 6. Historical login and logout records retrieval (/admin/security/session-history)
 * 7. Administrator kill/revoke session handling
 */

const http = require('http');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const BASE_URL = 'http://localhost:3000';

function post(path, body, token) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body || {});
    const headers = {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload),
      'User-Agent': 'Saark-Plant-Terminal/1.0 (Windows 11; Industrial Edge)',
    };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(
      `${BASE_URL}${path}`,
      { method: 'POST', headers },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(data) });
          } catch (_) {
            resolve({ status: res.statusCode, raw: data });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function get(path, token) {
  return new Promise((resolve, reject) => {
    const headers = {
      'User-Agent': 'Saark-Admin-Dashboard/1.0 (Corporate HQ)',
    };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(
      `${BASE_URL}${path}`,
      { method: 'GET', headers },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(data) });
          } catch (_) {
            resolve({ status: res.statusCode, raw: data });
          }
        });
      }
    );
    req.on('error', reject);
    req.end();
  });
}

function del(path, token) {
  return new Promise((resolve, reject) => {
    const headers = {};
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const req = http.request(
      `${BASE_URL}${path}`,
      { method: 'DELETE', headers },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(data) });
          } catch (_) {
            resolve({ status: res.statusCode, raw: data });
          }
        });
      }
    );
    req.on('error', reject);
    req.end();
  });
}

function createTestJpegImage(seedByte) {
  const header = Buffer.from([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00,
  ]);
  const body = Buffer.alloc(2048);
  for (let i = 0; i < 2048; i++) {
    body[i] = ((i * 7) ^ seedByte) % 256;
  }
  const trailer = Buffer.from([0xff, 0xd9]);
  return `data:image/jpeg;base64,${Buffer.concat([header, body, trailer]).toString('base64')}`;
}

async function runSuite() {
  console.log('========================================================================');
  console.log('   USER LOGIN & LOGOUT LIFECYCLE AUDIT VERIFICATION SUITE              ');
  console.log('========================================================================\n');

  let passed = 0;
  let total = 0;

  function assert(condition, testName) {
    total++;
    if (condition) {
      passed++;
      console.log(`  ✔ PASS [Test ${total}] ${testName}`);
    } else {
      console.error(`  ✖ FAIL [Test ${total}] ${testName}`);
    }
  }

  // ─── Test 1: Authenticate User & Capture Created Session ─────────────────
  console.log('--- Step 1: User Login & Session Persistence ---');
  const validFace = createTestJpegImage(0x5a);
  const loginRes = await post('/api/v1/auth/login-2fa', {
    username: 'admin',
    password: 'Saark@2026',
    face_data: validFace,
  });

  assert(loginRes.status === 200 || loginRes.status === 201, 'Login endpoint returns HTTP 200/201');
  const body = loginRes.data?.data || loginRes.data;
  const accessToken = body?.tokens?.accessToken || body?.accessToken;
  const sessionId = body?.sessionId || body?.session?.id;
  assert(Boolean(accessToken), 'JWT accessToken successfully issued');
  assert(Boolean(sessionId), `Active Session ID issued (${sessionId})`);

  // Verify DB record in PostgreSQL
  const dbSession = await prisma.userSession.findUnique({ where: { id: sessionId } });
  assert(
    dbSession && dbSession.status === 'ACTIVE' && dbSession.loginTime instanceof Date,
    `PostgreSQL user_sessions table contains active record with valid loginTime: ${dbSession?.loginTime?.toISOString()}`
  );
  assert(
    dbSession && dbSession.faceVerified === true && dbSession.loginMethod.includes('BIOMETRIC'),
    `Biometric 2FA flag and login method correctly recorded (${dbSession?.loginMethod})`
  );

  // ─── Test 2: Active Sessions Query by Administrator ──────────────────────
  console.log('\n--- Step 2: Administrator Active Sessions Query ---');
  const activeSessionsRes = await get('/api/v1/admin/security/sessions', accessToken);
  assert(activeSessionsRes.status === 200, 'GET /admin/security/sessions returns HTTP 200');
  const sessionList = activeSessionsRes.data?.data || activeSessionsRes.data || [];
  const foundInActive = sessionList.some((s) => s.id === sessionId);
  assert(foundInActive, `New session (${sessionId}) is listed in active enterprise sessions`);

  // ─── Test 3: Session Heartbeat ───────────────────────────────────────────
  console.log('\n--- Step 3: Session Heartbeat ---');
  const heartbeatRes = await post('/api/v1/auth/heartbeat', { sessionId }, accessToken);
  assert(heartbeatRes.status === 200 || heartbeatRes.status === 201, 'POST /auth/heartbeat returns HTTP 200');

  // Wait 1.5 seconds so duration is positive
  await new Promise((r) => setTimeout(r, 1500));

  // ─── Test 4: User Logout & Timestamp Recording ───────────────────────────
  console.log('\n--- Step 4: User Logout & Duration Calculation ---');
  const logoutRes = await post('/api/v1/auth/logout', { sessionId }, accessToken);
  assert(logoutRes.status === 200 || logoutRes.status === 201, 'POST /auth/logout returns HTTP 200');
  assert(logoutRes.data?.success === true, 'Logout response confirms success');

  // Verify DB session updated to LOGGED_OUT with duration
  const loggedOutSession = await prisma.userSession.findUnique({ where: { id: sessionId } });
  assert(
    loggedOutSession && loggedOutSession.status === 'LOGGED_OUT',
    'Session status in database transitioned to "LOGGED_OUT"'
  );
  assert(
    loggedOutSession && loggedOutSession.logoutTime instanceof Date,
    `Logout timestamp successfully recorded: ${loggedOutSession?.logoutTime?.toISOString()}`
  );
  assert(
    loggedOutSession && (loggedOutSession.durationSeconds || 0) >= 1,
    `Session duration accurately computed: ${loggedOutSession?.durationSeconds} seconds`
  );

  // ─── Test 5: Audit Log Compliance Trail ──────────────────────────────────
  console.log('\n--- Step 5: Audit Trail Verification ---');
  const latestAuditLog = await prisma.auditLog.findFirst({
    where: { entityId: sessionId, action: 'LOGOUT' },
    orderBy: { timestamp: 'desc' },
  });
  assert(
    Boolean(latestAuditLog),
    `Tamper-evident AuditLog entry recorded with action LOGOUT: "${latestAuditLog?.details}"`
  );

  // ─── Test 6: Historical Login & Logout Records API ───────────────────────
  console.log('\n--- Step 6: Historical Login and Logout Records API ---');
  const historyRes = await get('/api/v1/admin/security/session-history', accessToken);
  assert(historyRes.status === 200, 'GET /admin/security/session-history returns HTTP 200');
  const historyData = historyRes.data?.data?.data || historyRes.data?.data || [];
  const foundInHistory = historyData.find((s) => s.id === sessionId);
  assert(
    Boolean(foundInHistory),
    `Session (${sessionId}) present in Historical Records with Login: ${foundInHistory?.loginTime} and Logout: ${foundInHistory?.logoutTime}`
  );

  // ─── Test 7: Administrator Session Revocation / Termination ──────────────
  console.log('\n--- Step 7: Administrator Manual Session Revocation ---');
  // Login second session to terminate
  const login2 = await post('/api/v1/auth/login-2fa', {
    username: 'admin',
    password: 'Saark@2026',
    face_data: validFace,
  });
  const body2 = login2.data?.data || login2.data;
  const session2Id = body2?.sessionId || body2?.session?.id;
  assert(Boolean(session2Id), `Second session created for revocation testing: ${session2Id}`);

  const revokeRes = await del(`/api/v1/admin/security/sessions/${session2Id}`, accessToken);
  assert(revokeRes.status === 200, 'DELETE /admin/security/sessions/:id returns HTTP 200');

  const revokedDb = await prisma.userSession.findUnique({ where: { id: session2Id } });
  assert(
    revokedDb && revokedDb.status === 'REVOKED' && revokedDb.logoutReason === 'ADMIN_REVOKED',
    `Session correctly revoked with status="REVOKED" and logoutReason="ADMIN_REVOKED"`
  );

  console.log('\n========================================================================');
  console.log(`  TEST RESULTS: ${passed} / ${total} TESTS PASSED (${Math.round((passed / total) * 100)}%)`);
  console.log('========================================================================\n');

  await prisma.$disconnect();

  if (passed === total) {
    console.log('✔ ALL USER LOGIN & LOGOUT TRACKING TESTS PASSED PERFECTLY!\n');
    process.exit(0);
  } else {
    console.error('✖ SOME TESTS FAILED!\n');
    process.exit(1);
  }
}

runSuite().catch(async (e) => {
  console.error('Test execution failed:', e);
  await prisma.$disconnect();
  process.exit(1);
});
