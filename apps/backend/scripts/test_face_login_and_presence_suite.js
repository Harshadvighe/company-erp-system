/**
 * SAARK EXPLORATION ERP - AUTOMATED VERIFICATION SUITE
 * 
 * Tests:
 * 1. Office Hours Status Endpoint (6:00 PM / 18:00 Cutoff)
 * 2. Rahul Yeole Login Bypass (saarkexploration30 / Saark@2026 -> Sales & Marketing, No Camera)
 * 3. Superadmin Login (Saarkadmin / 12345678)
 * 4. 1:N Facial Auto-Login Endpoint (/api/v1/auth/face-login)
 *    - Empty payload validation (HTTP 400)
 *    - Unrecognized face rejection (HTTP 401)
 * 5. Periodic 30-Minute Presence Verification (/api/v1/auth/verify-presence)
 *    - Guard check without JWT (HTTP 401)
 *    - Rahul Yeole authorized bypass check (verified: true, bypass: true)
 *    - Unauthenticated / missing face handling
 * 6. Session Heartbeat & Office Hours Integration
 */

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';

let passed = 0;
let failed = 0;
let serverProcess = null;

function assert(condition, message) {
  if (condition) {
    console.log(`  [PASS] ${message}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${message}`);
    failed++;
  }
}

async function ensureBackendServer() {
  try {
    const res = await fetch(`${BASE_URL}/auth/face-config`);
    if (res.ok) {
      console.log('  Active backend server detected on http://localhost:3000.\n');
      return;
    }
  } catch (_) {}

  console.log('  Starting backend server on port 3000 for test suite...');
  const mainScript = path.resolve(__dirname, '../dist/src/main.js');

  serverProcess = spawn(process.execPath, [mainScript], {
    cwd: path.resolve(__dirname, '..'),
    env: { ...process.env, PORT: '3000' },
    stdio: 'ignore',
  });

  for (let i = 0; i < 40; i++) {
    await new Promise((r) => setTimeout(r, 600));
    try {
      const res = await fetch(`${BASE_URL}/auth/face-config`);
      if (res.ok) {
        console.log('  Backend test server is ready.\n');
        return;
      }
    } catch (_) {}
  }
  throw new Error('Failed to start backend server on port 3000');
}

async function runTestSuite() {
  console.log('\n===============================================================');
  console.log(' SAARK ERP: FACE AUTO-LOGIN, PRESENCE CHECK & 6 PM CUTOFF SUITE');
  console.log('===============================================================\n');

  await ensureBackendServer();

  let rahulToken = null;
  let adminToken = null;

  // -------------------------------------------------------------------------
  // TEST 1: Office Hours Status Endpoint
  // -------------------------------------------------------------------------
  console.log('TEST 1: Verifying Office Hours Status API...');
  try {
    const res = await fetch(`${BASE_URL}/auth/office-hours-status`);
    assert(res.ok, 'GET /api/v1/auth/office-hours-status returns HTTP 200');
    const json = await res.json();
    const data = json.data || json;
    assert(typeof data.isPastOfficeHours === 'boolean', `isPastOfficeHours is boolean (${data.isPastOfficeHours})`);
    assert(data.cutoffHour === 18, `cutoffHour is 18 (6:00 PM)`);

    // Verify IST logic mathematically
    const now = new Date();
    const utc = now.getTime() + (now.getTimezoneOffset() * 60000);
    const istTime = new Date(utc + (3600000 * 5.5));
    const expectedPast = istTime.getHours() >= 18;
    assert(data.isPastOfficeHours === expectedPast, `Server correctly matches IST time calculation (${istTime.getHours()}:${istTime.getMinutes()} IST)`);
  } catch (err) {
    assert(false, `TEST 1 Error: ${err.message}`);
  }

  // -------------------------------------------------------------------------
  // TEST 2: Rahul Yeole Direct Password Login (Camera Bypass)
  // -------------------------------------------------------------------------
  console.log('\nTEST 2: Verifying Rahul Yeole Direct Login Bypass...');
  try {
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: 'saarkexploration30',
        password: 'Saark@2026',
      }),
    });
    assert(res.ok, 'POST /api/v1/auth/login for Rahul Yeole returns HTTP 200');
    const json = await res.json();
    const data = json.data || json;
    assert(Boolean(data.tokens?.accessToken), 'JWT access token issued without camera requirement');
    assert(data.user?.username === 'saarkexploration30' || data.user?.fullName?.toLowerCase().includes('rahul'), 'User identity matched Rahul Yeole');
    assert(data.targetRoute === '/sales-marketing' || data.user?.targetRoute === '/sales-marketing', 'User automatically routed to Sales & Marketing (/sales-marketing)');
    rahulToken = data.tokens?.accessToken;
  } catch (err) {
    assert(false, `TEST 2 Error: ${err.message}`);
  }

  // -------------------------------------------------------------------------
  // TEST 3: Superadmin Login
  // -------------------------------------------------------------------------
  console.log('\nTEST 3: Verifying Super Administrator Login...');
  try {
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: 'Saarkadmin',
        password: '12345678',
      }),
    });
    assert(res.ok, 'POST /api/v1/auth/login for Saarkadmin returns HTTP 200');
    const json = await res.json();
    const data = json.data || json;
    assert(Boolean(data.tokens?.accessToken), 'Superadmin JWT access token issued');
    adminToken = data.tokens?.accessToken;
  } catch (err) {
    assert(false, `TEST 3 Error: ${err.message}`);
  }

  // -------------------------------------------------------------------------
  // TEST 4: Instant 1:N Facial Auto-Login Endpoint
  // -------------------------------------------------------------------------
  console.log('\nTEST 4: Verifying 1:N Face Auto-Login (/auth/face-login)...');
  try {
    // 4.1 Missing payload validation
    const emptyRes = await fetch(`${BASE_URL}/auth/face-login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    assert(emptyRes.status === 400, 'Empty face-login request returns HTTP 400 Bad Request');

    // 4.2 Unrecognized / random face descriptor
    const dummyDescriptor = Array.from({ length: 128 }, () => Math.random() * 0.1);
    const unrecRes = await fetch(`${BASE_URL}/auth/face-login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ face_data: dummyDescriptor }),
    });
    // Either 401 (not recognized) or 401 (after 6 PM cutoff)
    assert(unrecRes.status === 401, 'Unrecognized face returns HTTP 401 Unauthorized');
    const unrecData = await unrecRes.json();
    assert(
      unrecData.message?.includes('Face not recognized') ||
      unrecData.message?.includes('Office hours ended') ||
      unrecData.message?.includes('registered face biometrics'),
      `Proper security message returned: "${unrecData.message}"`
    );
  } catch (err) {
    assert(false, `TEST 4 Error: ${err.message}`);
  }

  // -------------------------------------------------------------------------
  // TEST 5: 30-Minute Periodic Presence Check Endpoint
  // -------------------------------------------------------------------------
  console.log('\nTEST 5: Verifying 30-Minute Presence Verification (/auth/verify-presence)...');
  try {
    // 5.1 Guarded without JWT
    const noJwtRes = await fetch(`${BASE_URL}/auth/verify-presence`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ face_data: 'dummy' }),
    });
    assert(noJwtRes.status === 401, 'Endpoint properly guarded by JwtAuthGuard (HTTP 401 without Bearer)');

    // 5.2 With Rahul Yeole JWT (Camera Bypass active)
    if (rahulToken) {
      const rahulPresRes = await fetch(`${BASE_URL}/auth/verify-presence`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${rahulToken}`,
        },
        body: JSON.stringify({
          face_data: 'bypass_token',
          currentRoute: '/sales-marketing',
        }),
      });
      assert(rahulPresRes.ok, 'Rahul Yeole presence check returns HTTP 200/201');
      const presJson = await rahulPresRes.json();
      const presData = presJson.data || presJson;
      assert(presData.verified === true, 'Rahul Yeole presence successfully verified without camera block');
      assert(presData.bypass === true, 'Response confirms camera bypass is active');
    } else {
      assert(false, 'Skipping Rahul Yeole presence check (no token)');
    }
  } catch (err) {
    assert(false, `TEST 5 Error: ${err.message}`);
  }

  // -------------------------------------------------------------------------
  // TEST 6: Session Heartbeat Verification
  // -------------------------------------------------------------------------
  console.log('\nTEST 6: Verifying Session Heartbeat...');
  try {
    if (adminToken) {
      const hbRes = await fetch(`${BASE_URL}/auth/heartbeat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${adminToken}`,
        },
        body: JSON.stringify({}),
      });
      assert(hbRes.ok, 'Heartbeat returns HTTP 200');
      const hbJson = await hbRes.json();
      const hbData = hbJson.data || hbJson;
      assert(hbData.success === true, 'Heartbeat successfully updated session timestamp');
    }
  } catch (err) {
    assert(false, `TEST 6 Error: ${err.message}`);
  }

  // -------------------------------------------------------------------------
  // CLEANUP & SUMMARY
  // -------------------------------------------------------------------------
  if (serverProcess) {
    serverProcess.kill();
  }

  console.log('\n===============================================================');
  console.log(` RESULTS: ${passed} PASSED | ${failed} FAILED`);
  console.log('===============================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTestSuite().catch((e) => {
  console.error('Test suite failed:', e);
  if (serverProcess) serverProcess.kill();
  process.exit(1);
});
