const http = require('http');

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

function makeRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, headers: res.headers, data: parsed });
        } catch (_) {
          resolve({ status: res.statusCode, headers: res.headers, data });
        }
      });
    });
    req.on('error', reject);
    if (postData) {
      req.write(typeof postData === 'string' ? postData : JSON.stringify(postData));
    }
    req.end();
  });
}

async function runTestSuite() {
  console.log('========================================================================');
  console.log('  DUAL-FACTOR AUTHENTICATION (2FA) GATEKEEPER AUTOMATED TEST SUITE     ');
  console.log('========================================================================\n');

  let passed = 0;
  let total = 0;

  function assert(condition, testName, detail = '') {
    total++;
    if (condition) {
      passed++;
      console.log(`  \x1b[32m✔ PASS\x1b[0m [Test ${total}] ${testName}`);
    } else {
      console.error(`  \x1b[31m✖ FAIL\x1b[0m [Test ${total}] ${testName} ${detail ? '--> ' + detail : ''}`);
    }
  }

  const registeredFace = createTestJpegImage(0x5a);
  const imposterFace = createTestJpegImage(0xa5);

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 1: User Lookup Failure (Non-Existent User)
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\x1b[36m--- Step 1 Tests: User Lookup & Password Gatekeeper ---\x1b[0m');
  const res1 = await makeRequest({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    username: 'non_existent_user_xyz',
    password: 'AnyPassword123!',
    face_data: registeredFace,
  });

  assert(
    res1.status === 401 && res1.data.message?.includes('Invalid credentials'),
    'Unknown user rejects immediately with 401 Unauthorized (Prevents User Enumeration)',
    `Status: ${res1.status}, Msg: ${JSON.stringify(res1.data)}`
  );

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 2: Password Verification Failure (Wrong Password)
  // ──────────────────────────────────────────────────────────────────────────
  const res2 = await makeRequest({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    username: 'admin',
    password: 'WrongPassword@123',
    face_data: registeredFace,
  });

  assert(
    res2.status === 401 && res2.data.message?.includes('Invalid credentials'),
    'Wrong password rejects with generic 401 Unauthorized (Even if face is supplied)',
    `Status: ${res2.status}, Msg: ${JSON.stringify(res2.data)}`
  );

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 3: Strict 2FA Endpoint Rejection When face_data is Missing
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n\x1b[36m--- Step 2 Tests: Facial Biometric Verification Gatekeeper ---\x1b[0m');
  const res3 = await makeRequest({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login-2fa',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    username: 'admin',
    password: 'Saark@2026',
    // Missing face_data
  });

  assert(
    res3.status === 401 && res3.data.message?.includes('Dual-factor authentication requires facial biometric data'),
    'Strict 2FA endpoint rejects with 401 if face_data is missing',
    `Status: ${res3.status}, Msg: ${JSON.stringify(res3.data)}`
  );

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 4: Imposter Biometric Rejection (Confidence below 85% threshold)
  // ──────────────────────────────────────────────────────────────────────────
  const res4 = await makeRequest({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    username: 'admin',
    password: 'Saark@2026',
    face_data: imposterFace,
  });

  assert(
    res4.status === 401 && res4.data.message?.includes('Face Verification Failed'),
    'Imposter face rejected with 401 Unauthorized (Confidence below strict 85% threshold)',
    `Status: ${res4.status}, Msg: ${JSON.stringify(res4.data)}`
  );

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 5: Successful Dual-Factor Authentication (Valid Credentials + Matching Face)
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n\x1b[36m--- Step 3 Tests: Access Grant & Session Issuance ---\x1b[0m');
  const res5 = await makeRequest({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    username: 'admin',
    password: 'Saark@2026',
    face_data: registeredFace,
  });

  const body5 = res5.data?.data || res5.data;
  const hasTokens = Boolean(body5?.tokens?.accessToken && body5?.tokens?.refreshToken);
  const userMatches = body5?.user?.username === 'admin';

  assert(
    res5.status === 200 || res5.status === 201,
    'HTTP 200/201 Success status returned on dual credential + biometric match',
    `Status: ${res5.status}`
  );

  assert(
    hasTokens && userMatches,
    'Session access granted with valid JWT accessToken & user profile',
    `User: ${body5?.user?.username}, AccessToken: ${body5?.tokens?.accessToken ? 'Present' : 'Missing'}`
  );

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 6: Strict 2FA Endpoint (POST /api/v1/auth/login-2fa) Full Match
  // ──────────────────────────────────────────────────────────────────────────
  const res6 = await makeRequest({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login-2fa',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    username: 'admin',
    password: 'Saark@2026',
    face_data: registeredFace,
  });

  const body6 = res6.data?.data || res6.data;
  assert(
    (res6.status === 200 || res6.status === 201) && body6?.tokens?.accessToken,
    'Strict /api/v1/auth/login-2fa endpoint succeeds and issues full JWT session',
    `Status: ${res6.status}`
  );

  // ──────────────────────────────────────────────────────────────────────────
  // TEST 7: Authenticated Profile Verification with Issued JWT
  // ──────────────────────────────────────────────────────────────────────────
  const token = body5?.tokens?.accessToken || body6?.tokens?.accessToken;
  const res7 = await makeRequest({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/me',
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  const body7 = res7.data?.data || res7.data;
  const profileUsername = body7?.username || body7?.user?.username;
  assert(
    res7.status === 200 && profileUsername === 'admin',
    'Protected /auth/me route verifies JWT session validity and returns authenticated identity',
    `Status: ${res7.status}, User: ${profileUsername}`
  );


  console.log('\n========================================================================');
  console.log(`  TEST RESULTS: ${passed} / ${total} TESTS PASSED (${((passed / total) * 100).toFixed(0)}%)`);
  console.log('========================================================================\n');

  if (passed === total) {
    console.log('\x1b[32m✔ ALL DUAL-FACTOR AUTHENTICATION TESTS PASSED PERFECTLY!\x1b[0m');
    process.exit(0);
  } else {
    console.error('\x1b[31m✖ SOME TESTS FAILED!\x1b[0m');
    process.exit(1);
  }
}

runTestSuite().catch(console.error);
