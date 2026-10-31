const http = require('http');

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: body ? JSON.parse(body) : null });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    req.on('error', reject);
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

const unwrap = (res) => res.data?.data || res.data;

// Generates valid high-entropy mock JPEG images with deterministic biometric features
function generateMockJpeg(seed) {
  const header = [
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00,
  ];
  const body = [];
  for (let i = 0; i < 2048; i++) {
    body.push(((i * 7) ^ seed) % 256);
  }
  const trailer = [0xff, 0xd9];
  const buffer = Buffer.from([...header, ...body, ...trailer]);
  return `data:image/jpeg;base64,${buffer.toString('base64')}`;
}

async function runFaceVerificationSuite() {
  console.log('========================================================================');
  console.log('SAARK ERP - HR AUTO-VERIFICATION & LOGIN FACE SCAN VERIFICATION TEST');
  console.log('========================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, testName, details) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}`);
      if (details) console.error(`       Details:`, details);
      failed++;
    }
  }

  // Step 0: Login as HR Manager
  console.log('--- Step 0: Authenticate as HR Manager (hr / Saark@2026) ---');
  const hrLogin = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, { emailOrUsername: 'hr', password: 'Saark@2026' });

  assert(hrLogin.status === 200 || hrLogin.status === 201, 'HR Authentication successful (HTTP 200/201)', `Status: ${hrLogin.status}`);
  const hrToken = unwrap(hrLogin)?.tokens?.accessToken || hrLogin.data?.tokens?.accessToken;
  assert(!!hrToken, 'HR Access Token retrieved');

  const authHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${hrToken}`,
  };

  const timestamp = Date.now();
  const empSeedA = 0x5a; // Employee's true face biometric
  const empSeedB = 0xa5; // Imposter / completely different biometric

  const livePhotoA = generateMockJpeg(empSeedA);
  const passportPhotoA = generateMockJpeg(empSeedA); // Matching passport photo
  const passportPhotoB = generateMockJpeg(empSeedB); // Mismatched passport photo

  // Test 1: HR Profile Creation with MISMATCHED Live Photo and Passport Photo
  console.log('\n--- Test 1: HR Photo Auto-Verification Mismatch Rejection ---');
  const mismatchPayload = {
    firstName: 'Vikram',
    middleName: 'Rajendra',
    lastName: 'Kulkarni',
    email: `vikram.kulkarni.${timestamp}@saark.in`,
    phone: '+91 98222 11223',
    designation: 'Senior Automation Engineer',
    livePhotoBase64: livePhotoA,
    passportPhotoBase64: passportPhotoB, // Mismatched photo
  };

  const res1 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, mismatchPayload);

  assert(
    res1.status === 400,
    'HTTP 400 Bad Request returned when Live Photo does not match Passport Photo',
    `Status: ${res1.status}, Msg: ${JSON.stringify(res1.data?.message)}`
  );
  assert(
    typeof res1.data?.message === 'string' && res1.data.message.includes('Face Verification Failed: Captured live face does not match the uploaded passport photo'),
    'Expected HR photo mismatch error message returned to user',
    res1.data?.message
  );

  // Test 2: HR Profile Creation with MATCHING Live Photo and Passport Photo (Auto-Verified) + User Login Creation
  console.log('\n--- Test 2: HR Photo Auto-Verification Match & User Account Profile Enrollment ---');
  const testUsername = `vikram.${timestamp}`;
  const testPassword = 'Employee@2026';

  const matchPayload = {
    firstName: 'Vikram',
    middleName: 'Rajendra',
    lastName: 'Kulkarni',
    email: `vikram.kulkarni.${timestamp}@saark.in`,
    phone: '+91 98222 11223',
    designation: 'Senior Automation Engineer',
    createUserAccount: true,
    username: testUsername,
    password: testPassword,
    enableFaceAuth: true,
    livePhotoBase64: livePhotoA,
    passportPhotoBase64: passportPhotoA, // Matching photo!
  };

  const res2 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, matchPayload);

  const empCreated = unwrap(res2);
  assert(
    res2.status === 201,
    'HTTP 201 Created: Employee & user login auto-verified and enrolled successfully',
    `Status: ${res2.status}`
  );
  assert(
    empCreated && empCreated.firstName === 'Vikram' && empCreated.middleName === 'Rajendra',
    'Created employee profile contains first and middle name',
    `${empCreated?.firstName} ${empCreated?.middleName} ${empCreated?.lastName}`
  );

  // Test 3: Face Scanned Login Option - Mismatched Face Rejection
  console.log('\n--- Test 3: Face Scanned Login Option - Mismatched Face Rejection ---');
  const imposterFace = generateMockJpeg(empSeedB);
  const faceLoginMismatch = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    emailOrUsername: testUsername,
    password: testPassword,
    livePhotoBase64: imposterFace, // Imposter face doesn't match registered biometric!
  });

  assert(
    faceLoginMismatch.status === 401,
    'HTTP 401 Unauthorized: Mismatched face login rejected',
    `Status: ${faceLoginMismatch.status}, Msg: ${JSON.stringify(faceLoginMismatch.data?.message)}`
  );
  assert(
    typeof faceLoginMismatch.data?.message === 'string' &&
    faceLoginMismatch.data.message.includes('Face Verification Failed: Face does not match registered profile. Access denied.'),
    'Access denied error message displayed on mismatch: "Face does not match registered profile"',
    faceLoginMismatch.data?.message
  );

  // Test 4: Face Scanned Login Option - MATCHING Face Acceptance
  console.log('\n--- Test 4: Face Scanned Login Option - Matching Face Acceptance ---');
  const matchingFace = generateMockJpeg(empSeedA);
  const faceLoginMatch = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    emailOrUsername: testUsername,
    password: testPassword,
    livePhotoBase64: matchingFace, // Matching live face!
  });

  assert(
    faceLoginMatch.status === 200 || faceLoginMatch.status === 201,
    'HTTP 200/201 OK: Matching face login successfully authenticated',
    `Status: ${faceLoginMatch.status}`
  );

  const faceLoginData = unwrap(faceLoginMatch);
  assert(
    !!faceLoginData?.tokens?.accessToken,
    'JWT Access Token issued upon matching face login',
    `Token: ${faceLoginData?.tokens?.accessToken?.substring(0, 20)}...`
  );
  assert(
    Array.isArray(faceLoginData?.user?.permissions),
    'Assigned module permissions returned with authenticated session',
    `Permissions Count: ${faceLoginData?.user?.permissions?.length}`
  );
  assert(
    Array.isArray(faceLoginData?.user?.roles) && faceLoginData.user.roles.length > 0,
    'Assigned roles returned to control module visibility',
    `Roles: ${faceLoginData?.user?.roles?.join(', ')}`
  );

  // Test 5: Standard Login Triggering Face Verification Modal (2FA Mode)
  console.log('\n--- Test 5: Standard Login without Face Prompting Biometric Verification ---');
  const step1Res = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    emailOrUsername: testUsername,
    password: testPassword,
  });

  const step1Data = unwrap(step1Res);
  assert(
    step1Data?.requiresFaceVerification === true,
    'Step 1: requiresFaceVerification flag returned for face-enrolled user',
    `requiresFaceVerification: ${step1Data?.requiresFaceVerification}`
  );
  assert(
    !!step1Data?.faceSessionToken,
    'Step 1: Short-lived faceSessionToken issued for biometric camera scan'
  );

  const sessionToken = step1Data.faceSessionToken;

  // Step 2 with imposter face
  console.log('\n--- Test 6: Biometric Modal Verification with Imposter Face ---');
  const step2Fail = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/face-verify',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    faceSessionToken: sessionToken,
    faceImage: imposterFace,
  });

  assert(
    step2Fail.status === 401,
    'Step 2: Imposter face rejected with HTTP 401',
    `Status: ${step2Fail.status}`
  );
  assert(
    typeof step2Fail.data?.message === 'string' &&
    step2Fail.data.message.includes('Face Verification Failed: Face does not match registered profile. Access denied.'),
    'Step 2: Correct access denied message returned on mismatch',
    step2Fail.data?.message
  );

  // Step 2 with matching face
  console.log('\n--- Test 7: Biometric Modal Verification with Matching Face ---');
  const step2Pass = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/face-verify',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, {
    faceSessionToken: sessionToken,
    faceImage: matchingFace,
  });

  assert(
    step2Pass.status === 200 || step2Pass.status === 201,
    'Step 2: Matching face verified with HTTP 200/201',
    `Status: ${step2Pass.status}`
  );
  const step2Data = unwrap(step2Pass);
  assert(
    !!step2Data?.tokens?.accessToken,
    'Step 2: JWT Access Token issued for user session'
  );
  assert(
    Array.isArray(step2Data?.user?.roles) && step2Data.user.roles.length > 0,
    'Step 2: User roles returned to enable authorized ERP modules',
    `Roles: ${step2Data?.user?.roles?.join(', ')}`
  );

  console.log('\n========================================================================');
  console.log(`TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('========================================================================\n');
}

runFaceVerificationSuite().catch((err) => {
  console.error('Fatal Test Suite Error:', err);
  process.exit(1);
});
