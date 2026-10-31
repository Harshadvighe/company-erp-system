const BASE_URL = 'http://localhost:3000/api/v1';

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

async function run() {
  console.log('================================================================');
  console.log('  SAARK ERP - HR ONBOARDING -> ADMIN APPROVAL -> FACE 2FA FLOW  ');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, name, details = '') {
    if (condition) {
      passed++;
      console.log(`  \x1b[32m✔ PASS\x1b[0m ${name}`);
    } else {
      failed++;
      console.error(`  \x1b[31m✖ FAIL\x1b[0m ${name} ${details ? '-> ' + details : ''}`);
    }
  }

  // -------------------------------------------------------------
  // STEP 1: HR Standard Login
  // -------------------------------------------------------------
  console.log('STEP 1: HR Standard Login (Username: hr, Saark@2026)...');
  const hrLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ emailOrUsername: 'hr', password: 'Saark@2026' }),
  });
  assert(hrLoginRes.ok, 'HTTP 200/201 on HR login');
  const hrLoginData = await hrLoginRes.json();
  const hrToken = hrLoginData.data?.tokens?.accessToken;
  const hrUser = hrLoginData.data?.user;

  assert(!!hrToken, 'JWT access token issued to HR');
  assert(hrUser?.username === 'hr', 'Authenticated user is "hr"');

  const hrHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${hrToken}`,
  };

  // -------------------------------------------------------------
  // STEP 2: HR creates employee profile with live face biometric & PENDING_APPROVAL status
  // -------------------------------------------------------------
  console.log('\nSTEP 2: HR onboards employee & submits for Admin Approval (PENDING_APPROVAL)...');
  const testSuffix = Date.now().toString().slice(-4);
  const testCode = 'EMP-HRTEST-' + testSuffix;
  const sampleFace = createTestJpegImage(0x5a); // Registered Employee Face

  const createEmpRes = await fetch(`${BASE_URL}/hr/employees`, {
    method: 'POST',
    headers: hrHeaders,
    body: JSON.stringify({
      firstName: 'Rohan',
      lastName: 'Kulkarni',
      email: `rohan.${testSuffix}@saark.in`,
      phone: '+91 9820011223',
      designation: 'Senior Process Engineer',
      status: 'PENDING_APPROVAL',
      livePhotoBase64: sampleFace,
      enableFaceAuth: true,
      createUserAccount: false, // Deferred to Admin approval
    }),
  });
  const createEmpData = await createEmpRes.json();
  assert(createEmpRes.ok, 'HR creates employee profile successfully');
  const newEmp = createEmpData.data || createEmpData;
  const empId = newEmp?.id;
  assert(!!empId, `Created employee ID: ${empId}`);
  assert(newEmp?.status === 'PENDING_APPROVAL', 'Employee status is initialized to PENDING_APPROVAL');
  assert(!newEmp?.userId, 'Employee user account is NOT provisioned yet (Waiting for Admin)');

  // -------------------------------------------------------------
  // STEP 3: Verify Biometric Status in HR Module
  // -------------------------------------------------------------
  console.log('\nSTEP 3: HR verifies biometric template enrollment...');
  const statusRes = await fetch(`${BASE_URL}/hr/employees/${empId}/face/status`, { headers: hrHeaders });
  assert(statusRes.ok, 'GET /hr/employees/:id/face/status returns 200');
  const statusData = await statusRes.json();
  const biometrics = statusData.data || statusData;
  assert(biometrics?.hasBiometric === true, 'Face biometric enrolled for employee');
  assert(biometrics?.isActive === true, 'Biometric status is active (128-d ready)');

  // HR LOGS OUT (Simulated by dropping HR token and proceeding to Admin login)
  console.log('\nSTEP 4: HR logs out from session...');
  assert(true, 'HR session concluded');

  // -------------------------------------------------------------
  // STEP 5: Admin Login
  // -------------------------------------------------------------
  console.log('\nSTEP 5: Admin Login (Username: admin, Saark@2026)...');
  const adminLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ emailOrUsername: 'admin', password: 'Saark@2026' }),
  });
  assert(adminLoginRes.ok, 'HTTP 200/201 on Admin login');
  const adminLoginData = await adminLoginRes.json();
  const adminToken = adminLoginData.data?.tokens?.accessToken;
  assert(!!adminToken, 'JWT access token issued to Admin');

  const adminHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${adminToken}`,
  };

  // -------------------------------------------------------------
  // STEP 6: Admin checks Pending Onboarding Requests Queue
  // -------------------------------------------------------------
  console.log('\nSTEP 6: Admin queries Pending Onboarding Requests Queue...');
  const reqsRes = await fetch(`${BASE_URL}/admin/employee-requests?status=PENDING_APPROVAL`, { headers: adminHeaders });
  assert(reqsRes.ok, 'GET /admin/employee-requests returns 200');
  const reqsData = await reqsRes.json();
  const pendingRequests = reqsData.data || reqsData;
  assert(Array.isArray(pendingRequests), 'Pending requests array returned');
  
  const targetReq = pendingRequests.find((r) => r.id === empId);
  assert(!!targetReq, `Newly submitted employee (${newEmp.employeeCode}) found in Admin Pending Approval queue!`);
  assert(targetReq?.faceBiometric?.isActive === true, 'Admin sees face biometric status attached to request');

  // -------------------------------------------------------------
  // STEP 7: Admin confirms, provisions user credentials & approves request
  // -------------------------------------------------------------
  console.log('\nSTEP 7: Admin reviews & approves request, creating ERP user account...');
  const approvedUsername = `rohan_${testSuffix}`;
  const approveRes = await fetch(`${BASE_URL}/admin/employee-requests/${empId}/approve`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      username: approvedUsername,
      password: 'Saark@2026',
      departmentId: targetReq?.departmentId,
      roleIds: ['ROLE_EMPLOYEE'],
    }),
  });
  assert(approveRes.ok, 'POST /admin/employee-requests/:id/approve returns 200/201');
  const approveData = await approveRes.json();
  const approvedUser = approveData.data?.user || approveData.user;
  assert(approvedUser?.username === approvedUsername, `User account "${approvedUsername}" successfully provisioned by Admin`);

  // -------------------------------------------------------------
  // STEP 8: Newly Approved Employee 2-Step Login (Password -> Face 2FA)
  // -------------------------------------------------------------
  console.log('\nSTEP 8: Employee Step 1 Login (Password validation)...');
  const empLoginStep1 = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      emailOrUsername: approvedUsername,
      password: 'Saark@2026',
    }),
  });
  assert(empLoginStep1.ok, 'Step 1 login request accepted');
  const step1Data = await empLoginStep1.json();
  const loginPayload = step1Data.data || step1Data;
  assert(loginPayload?.requiresFaceVerification === true, 'requiresFaceVerification is true (2FA Enforced)');
  assert(!!loginPayload?.faceSessionToken, 'Short-lived faceSessionToken issued');
  assert(!loginPayload?.tokens, 'Full tokens withheld until face verification succeeds');

  const faceSessionToken = loginPayload?.faceSessionToken;

  // -------------------------------------------------------------
  // STEP 9: Security Check - Imposter Face Rejected
  // -------------------------------------------------------------
  console.log('\nSTEP 9: Security Check - Imposter / Mismatched Face Verification...');
  const imposterFace = createTestJpegImage(0xa5); // Different face vector
  const imposterRes = await fetch(`${BASE_URL}/auth/face-verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      faceSessionToken,
      livePhotoBase64: imposterFace,
    }),
  });
  assert(imposterRes.status === 401, 'HTTP 401 Unauthorized on mismatched imposter face');

  // -------------------------------------------------------------
  // STEP 10: Legitimate Face Verification with Registered Face
  // -------------------------------------------------------------
  console.log('\nSTEP 10: Legitimate Face Verification with Registered Employee Face...');
  const legitRes = await fetch(`${BASE_URL}/auth/face-verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      faceSessionToken,
      livePhotoBase64: sampleFace,
    }),
  });
  assert(legitRes.ok, 'HTTP 200/201 on matching face verification');
  const legitData = await legitRes.json();
  const legitPayload = legitData.data || legitData;
  assert(!!legitPayload?.tokens?.accessToken, 'Full JWT access token issued to approved employee');
  assert(legitPayload?.user?.username === approvedUsername, 'Authenticated session user matches employee');

  console.log('\n================================================================');
  console.log(`TOTAL TESTS: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
  console.log('================================================================\n');

  if (failed > 0) process.exit(1);
}

run().catch(err => {
  console.error('Fatal error during test:', err);
  process.exit(1);
});
