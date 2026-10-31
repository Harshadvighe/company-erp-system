/**
 * Saark ERP - Comprehensive End-to-End Test Suite:
 * 1. Python Face Recognition Engine (OpenCV feature extraction & liveness)
 * 2. HR Employee Onboarding (PENDING_APPROVAL + Face Biometric Capture)
 * 3. Admin Approval & Account Provisioning -> Auto-generated Welcome Email
 * 4. HR Credential Update (Username & Password) -> Auto-generated Update Email
 * 5. Employee Step 1 Password Login -> Step 2 Face 2FA Verification
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';

let passed = 0;
let failed = 0;

function assert(condition, testName, details = '') {
  if (condition) {
    console.log(`  ✔ PASS ${testName}`);
    passed++;
  } else {
    console.error(`  ✖ FAIL ${testName} ${details}`);
    failed++;
  }
}

function createTestJpegImage(seedByte = 0x5a) {
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
  console.log('  SAARK ERP - COMPREHENSIVE HR, ADMIN & BIOMETRIC TEST SUITE    ');
  console.log('================================================================');

  const testSuffix = Math.floor(1000 + Math.random() * 9000);
  const sampleFace = createTestJpegImage(0x5a);

  // -------------------------------------------------------------
  // TEST 1: Python Face Recognition Engine Execution
  // -------------------------------------------------------------
  console.log('\nTEST 1: Python Face Recognition Engine (OpenCV)...');
  const pythonScript = path.join(__dirname, '../src/core/biometrics/face_engine.py');
  assert(fs.existsSync(pythonScript), 'Python face engine script exists at src/core/biometrics/face_engine.py');

  // Test vector comparison
  const vec1 = JSON.stringify(new Array(128).fill(0.088388));
  const vec2 = JSON.stringify(new Array(128).fill(0.088388));
  const pyCompare = spawnSync('python', [pythonScript, 'compare', '--vec1', vec1, '--vec2', vec2], { encoding: 'utf8' });
  assert(pyCompare.status === 0, 'Python compare command runs successfully');
  try {
    const compRes = JSON.parse(pyCompare.stdout.trim());
    assert(compRes.isMatch === true && compRes.distance < 0.05, 'Python compares 128-d vectors correctly with matching metric');
  } catch (e) {
    assert(false, 'Python compare output parsed as JSON', e.message);
  }

  // -------------------------------------------------------------
  // TEST 2: HR Login
  // -------------------------------------------------------------
  console.log('\nTEST 2: HR Login (hr / Saark@2026)...');
  const hrLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ emailOrUsername: 'hr', password: 'Saark@2026' }),
  });
  assert(hrLoginRes.ok, 'HTTP 200/201 on HR login');
  const hrLoginData = await hrLoginRes.json();
  const hrToken = hrLoginData.data?.tokens?.accessToken || hrLoginData.tokens?.accessToken;
  assert(!!hrToken, 'JWT access token issued to HR');
  const hrHeaders = { 'Content-Type': 'application/json', Authorization: `Bearer ${hrToken}` };

  // -------------------------------------------------------------
  // TEST 3: HR Onboards Employee with Face Biometric Capture (PENDING_APPROVAL)
  // -------------------------------------------------------------
  console.log('\nTEST 3: HR Onboards Employee with Face Biometric (PENDING_APPROVAL)...');
  const empEmail = `test_emp_${testSuffix}@saark.in`;
  const createEmpRes = await fetch(`${BASE_URL}/hr/employees`, {
    method: 'POST',
    headers: hrHeaders,
    body: JSON.stringify({
      firstName: 'Rohan',
      lastName: `Sharma_${testSuffix}`,
      email: empEmail,
      phone: '+91 98200 99887',
      designation: 'Senior Panel Wiring Technician',
      workerCategory: 'SHOPFLOOR_TECH',
      skillLevel: 'LEVEL_2_WIREMAN',
      assignedBay: 'BAY_4_WIRING',
      shiftCode: 'SHIFT_G',
      status: 'PENDING_APPROVAL',
      createUserAccount: false,
      livePhotoBase64: sampleFace,
      enableFaceAuth: true,
    }),
  });
  assert(createEmpRes.ok, 'POST /hr/employees creates profile successfully');
  const createEmpData = await createEmpRes.json();
  const newEmp = createEmpData.data || createEmpData;
  const empId = newEmp.id;
  assert(!!empId, `Created employee ID: ${empId}`);
  assert(newEmp.status === 'PENDING_APPROVAL', 'Status is initialized to PENDING_APPROVAL');
  assert(!newEmp.userId, 'User account is not created yet (Waiting for Admin approval)');

  // Verify biometric enrollment
  const bioStatusRes = await fetch(`${BASE_URL}/hr/employees/${empId}/face/status`, {
    headers: hrHeaders,
  });
  const bioStatus = (await bioStatusRes.json()).data;
  assert(bioStatus?.hasBiometric === true && bioStatus?.isActive === true, 'Face biometric active and enrolled');

  // -------------------------------------------------------------
  // TEST 4: Admin Login & Review Pending Queue
  // -------------------------------------------------------------
  console.log('\nTEST 4: Admin Login & Approval Review...');
  const adminLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ emailOrUsername: 'admin', password: 'Saark@2026' }),
  });
  assert(adminLoginRes.ok, 'HTTP 200 on Admin login');
  const adminToken = (await adminLoginRes.json()).data?.tokens?.accessToken;
  const adminHeaders = { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` };

  const pendingReqsRes = await fetch(`${BASE_URL}/admin/employee-requests`, { headers: adminHeaders });
  const pendingRequests = (await pendingReqsRes.json()).data || [];
  const targetReq = pendingRequests.find((r) => r.id === empId);
  assert(!!targetReq, `Found submitted employee (${newEmp.employeeCode}) in Admin Pending Approval queue`);
  assert(targetReq?.faceBiometric?.isActive === true, 'Admin sees face biometric status attached to request');

  // -------------------------------------------------------------
  // TEST 5: Admin Approves Request -> Triggers Auto Welcome Email
  // -------------------------------------------------------------
  console.log('\nTEST 5: Admin Approves Request & Dispatches Welcome Email...');
  const approvedUsername = `rohan_orig_${testSuffix}`;
  const approveRes = await fetch(`${BASE_URL}/admin/employee-requests/${empId}/approve`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      username: approvedUsername,
      password: 'Saark@2026',
      departmentId: targetReq?.departmentId,
      roleIds: ['ROLE_EMPLOYEE'],
      sendWelcomeEmail: true,
    }),
  });
  assert(approveRes.ok, 'POST /admin/employee-requests/:id/approve returns 200/201');
  const approveJson = await approveRes.json();
  const approvedUser = approveJson.data?.user || approveJson.user;
  assert(approvedUser?.username === approvedUsername, `User account "${approvedUsername}" created by Admin`);

  // Verify welcome email in mail logs
  const mailLogsRes = await fetch(`${BASE_URL}/admin/mail-logs`, { headers: adminHeaders });
  assert(mailLogsRes.ok, 'GET /admin/mail-logs returns 200');
  const mailLogs = (await mailLogsRes.json()).data || [];
  const welcomeMail = mailLogs.find((m) => m.to === empEmail && m.type === 'WELCOME_ONBOARDING');
  assert(!!welcomeMail, `Welcome onboarding email generated and delivered to ${empEmail}`);
  assert(welcomeMail?.subject.includes('Welcome to Saark Exploration'), 'Welcome email subject is correct');

  // -------------------------------------------------------------
  // TEST 6: HR Updates Username and Password -> Triggers Update Email
  // -------------------------------------------------------------
  console.log('\nTEST 6: HR Updates Employee Username & Password -> Dispatches Update Email...');
  const updatedUsername = `rohan_updated_${testSuffix}`;
  const updatedPassword = 'NewSecret@2026';

  const updateRes = await fetch(`${BASE_URL}/hr/employees/${empId}`, {
    method: 'PUT',
    headers: hrHeaders,
    body: JSON.stringify({
      username: updatedUsername,
      password: updatedPassword,
      designation: 'Lead Production Engineer',
    }),
  });
  assert(updateRes.ok, 'PUT /hr/employees/:id returns 200 OK');
  const updateData = (await updateRes.json()).data;
  assert(updateData?.user?.username === updatedUsername, `Linked User record redirected/updated to "${updatedUsername}"`);

  // Verify credential change email in mail logs
  const mailLogsAfterUpdate = (await (await fetch(`${BASE_URL}/admin/mail-logs`, { headers: adminHeaders })).json()).data || [];
  const credMail = mailLogsAfterUpdate.find((m) => m.to === empEmail && m.type === 'CREDENTIALS_UPDATED');
  assert(!!credMail, `Credential update notification email dispatched to ${empEmail}`);
  assert(credMail?.subject.includes('Credentials Updated'), 'Credential update email subject is correct');

  // -------------------------------------------------------------
  // TEST 7: Employee Logs in with Newly Updated Credentials + Face 2FA
  // -------------------------------------------------------------
  console.log('\nTEST 7: Employee Login with Updated Credentials (Password -> Face 2FA)...');
  const empLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      emailOrUsername: updatedUsername,
      password: updatedPassword,
    }),
  });
  assert(empLoginRes.ok, 'Employee logs in successfully with new updated credentials');
  const empLoginData = (await empLoginRes.json()).data;
  assert(empLoginData?.requiresFaceVerification === true, 'requiresFaceVerification is true (2FA Enforced)');
  assert(!!empLoginData?.faceSessionToken, 'Short-lived faceSessionToken issued');

  const faceToken = empLoginData.faceSessionToken;

  // Security check: Imposter face rejected
  console.log('\nTEST 8: Security Validation - Imposter Face Scan Rejected...');
  const imposterFace = createTestJpegImage(0xa5);
  const imposterRes = await fetch(`${BASE_URL}/auth/face-verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      faceSessionToken: faceToken,
      livePhotoBase64: imposterFace,
    }),
  });
  assert(imposterRes.status === 401, 'HTTP 401 Unauthorized on mismatched face scan');

  // Legitimate face verification
  console.log('\nTEST 9: Legitimate Face Verification with Registered Employee Face...');
  const legitRes = await fetch(`${BASE_URL}/auth/face-verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      faceSessionToken: faceToken,
      livePhotoBase64: sampleFace,
    }),
  });
  assert(legitRes.ok, 'HTTP 200/201 on matching face verification');
  const legitData = (await legitRes.json()).data;
  assert(!!legitData?.tokens?.accessToken, 'Full JWT access token issued to employee');
  assert(legitData?.user?.username === updatedUsername, 'Session user matches updated username');

  // -------------------------------------------------------------
  // TEST 10: Admin Settings Endpoint
  // -------------------------------------------------------------
  console.log('\nTEST 10: Admin Settings & Configuration...');
  const settingsRes = await fetch(`${BASE_URL}/admin/settings`, { headers: adminHeaders });
  assert(settingsRes.ok, 'GET /admin/settings returns 200');
  const settingsData = (await settingsRes.json()).data;
  assert(settingsData?.sendWelcomeEmailOnApproval === true, 'Settings has sendWelcomeEmailOnApproval toggle');
  assert(settingsData?.sendEmailOnCredentialChange === true, 'Settings has sendEmailOnCredentialChange toggle');

  console.log('\n================================================================');
  console.log(`TOTAL TESTS: ${passed + failed} | PASSED: ${passed} | FAILED: ${failed}`);
  console.log('================================================================\n');

  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
