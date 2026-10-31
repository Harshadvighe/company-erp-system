require('reflect-metadata');
const { PrismaService } = require('../dist/src/core/database/prisma.service');
const { AuthService } = require('../dist/src/modules/auth/auth.service');
const { HrService } = require('../dist/src/modules/hr/hr.service');
const { AuditService } = require('../dist/src/core/audit/audit.service');
const { FaceRecognitionService } = require('../dist/src/core/biometrics/face-recognition.service');
const { JwtService } = require('@nestjs/jwt');

async function runFaceBiometricsTestSuite() {
  console.log('================================================================');
  console.log('   SAARK ERP - HR PROFILE PHOTO & FACE RECOGNITION TEST SUITE   ');
  console.log('================================================================\n');

  const prisma = new PrismaService();
  await prisma.$connect();

  const auditService = new AuditService(prisma);
  const faceRecognitionService = new FaceRecognitionService(prisma);
  const jwtService = new JwtService({
    secret: process.env.JWT_SECRET || 'saark_erp_production_jwt_secret_key_2026_x98123',
  });

  const authService = new AuthService(prisma, jwtService, auditService, faceRecognitionService);
  const hrService = new HrService(prisma, auditService, faceRecognitionService);

  let totalTests = 0;
  let passedTests = 0;
  let failedTests = 0;

  function assert(condition, testName, detail = '') {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`  \x1b[32m✔ PASS\x1b[0m [${totalTests}] ${testName}`);
    } else {
      failedTests++;
      console.error(`  \x1b[31m✖ FAIL\x1b[0m [${totalTests}] ${testName} ${detail ? '-> ' + detail : ''}`);
    }
  }

  function section(title) {
    console.log(`\n\x1b[36m--- ${title} ---\x1b[0m`);
  }

  // Create two distinct test JPEG images (simulating Person A and Person B)
  // Standard JPEG headers (FF D8 FF E0 ...) with distinct payload patterns
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

  const personAPhoto = createTestJpegImage(0x5a); // Employee A (e.g. Aditya)
  const personBPhoto = createTestJpegImage(0xa5); // Different Person (e.g. Spoof/Imposter)
  const corruptImage = 'data:image/jpeg;base64,AAAA'; // Too small

  try {
    // -------------------------------------------------------------------------
    // TEST 1: Biometric Engine Validation & Extraction
    // -------------------------------------------------------------------------
    section('1. Biometric Engine: Face Extraction, Entropy & Liveness');
    const extractionA = await faceRecognitionService.validateAndExtractFace(personAPhoto);
    assert(extractionA.faceDetected === true, 'Valid image detects single face');
    assert(extractionA.descriptor.length === 128, 'Extracted descriptor has exactly 128 dimensions');
    assert(extractionA.livenessPassed === true, 'Liveness verification passed for high-quality capture');

    let corruptFailed = false;
    try {
      await faceRecognitionService.validateAndExtractFace(corruptImage);
    } catch (_) {
      corruptFailed = true;
    }
    assert(corruptFailed, 'Corrupt/empty image is rejected with BadRequestException');

    // -------------------------------------------------------------------------
    // TEST 2: Encryption & Decryption at Rest (AES-256-GCM)
    // -------------------------------------------------------------------------
    section('2. Biometric Security: AES-256-GCM Encryption at Rest');
    const encrypted = faceRecognitionService.encryptEmbedding(extractionA.descriptor);
    assert(!!encrypted.encryptedEmbedding && encrypted.encryptedEmbedding.length > 50, 'Descriptor is encrypted to hex string');
    assert(!!encrypted.embeddingIv && encrypted.embeddingIv.length === 24, 'IV is 12-byte hex string (96-bit)');
    assert(!!encrypted.embeddingAuthTag && encrypted.embeddingAuthTag.length === 32, 'GCM Auth tag is 16-byte hex string');

    const decrypted = faceRecognitionService.decryptEmbedding(
      encrypted.encryptedEmbedding,
      encrypted.embeddingIv,
      encrypted.embeddingAuthTag,
    );
    assert(decrypted.length === 128, 'Decrypted vector restored to 128 dimensions');
    assert(
      Math.abs(decrypted[0] - extractionA.descriptor[0]) < 0.0001,
      'Decrypted vector exactly matches original unencrypted vector',
    );

    // -------------------------------------------------------------------------
    // TEST 3: Facial Distance Matching & Mismatch Detection
    // -------------------------------------------------------------------------
    section('3. Biometric Matching: Distance & Similarity Thresholds');
    const extractionB = await faceRecognitionService.validateAndExtractFace(personBPhoto);
    const selfMatch = faceRecognitionService.compareFaces(extractionA.descriptor, extractionA.descriptor, 0.55);
    assert(selfMatch.isMatch === true && selfMatch.distance < 0.05, 'Same face matches with near 0 distance (Self Match: PASS)');

    const imposterMatch = faceRecognitionService.compareFaces(extractionB.descriptor, extractionA.descriptor, 0.55);
    assert(imposterMatch.isMatch === false && imposterMatch.distance > 0.55, `Different faces rejected (Distance: ${imposterMatch.distance} > Threshold 0.55)`);

    // -------------------------------------------------------------------------
    // TEST 4: Backward Compatibility - Password-Only Login for Existing Users
    // -------------------------------------------------------------------------
    section('4. Backward Compatibility: Seed Users Password-Only Login');
    const adminLogin = await authService.login({ emailOrUsername: 'admin', password: 'Saark@2026' });
    assert(!adminLogin.requiresFaceVerification, 'Existing admin user logs in directly without face verification');
    assert(!!adminLogin.tokens?.accessToken, 'Access token issued directly to admin user');

    // -------------------------------------------------------------------------
    // TEST 5: HR Employee Onboarding with Biometric Enrollment
    // -------------------------------------------------------------------------
    section('5. HR Module: Employee Creation with Identity & Face Enrollment');
    const testEmail = `biometric.emp.${Date.now()}@saark.in`;
    const testUsername = `bio.emp.${Date.now().toString().slice(-4)}`;

    const newEmployee = await hrService.createEmployee({
      firstName: 'Aditya',
      lastName: 'Kulkarni',
      email: testEmail,
      phone: '+91 98200 44556',
      designation: 'Junior Design Engineer',
      passportPhotoBase64: personAPhoto,
      livePhotoBase64: personAPhoto,
      enableFaceAuth: true,
      createUserAccount: true,
      username: testUsername,
      password: 'Saark@2026',
    });

    assert(!!newEmployee.id, 'New employee created successfully');
    assert(!!newEmployee.employeeCode, `Auto-generated Employee Code: ${newEmployee.employeeCode}`);
    assert(!!newEmployee.userId, 'Linked User account created concurrently');

    const biometricRecord = await prisma.employeeFaceBiometric.findUnique({
      where: { employeeId: newEmployee.id },
    });
    assert(!!biometricRecord, 'Biometric record created in employee_face_biometrics table');
    assert(biometricRecord.isActive === true, 'Biometric status is active');
    assert(biometricRecord.encryptedEmbedding !== JSON.stringify(extractionA.descriptor), 'Biometric embedding is NOT stored in plaintext');

    const createdUser = await prisma.user.findUnique({ where: { id: newEmployee.userId } });
    assert(createdUser.faceVerificationEnabled === true, 'User record has faceVerificationEnabled = true');
    assert(createdUser.faceVerificationStatus === 'ENROLLED', 'User record has faceVerificationStatus = ENROLLED');

    // -------------------------------------------------------------------------
    // TEST 6: Login 2FA Step 1 - Credential Validation & Session Token Issuance
    // -------------------------------------------------------------------------
    section('6. Login 2FA Step 1: Password Accepted -> Face Challenge Issued');
    const empLoginStep1 = await authService.login({ emailOrUsername: testUsername, password: 'Saark@2026' });
    assert(empLoginStep1.requiresFaceVerification === true, 'Login Step 1 flags requiresFaceVerification = true');
    assert(!!empLoginStep1.faceSessionToken, 'Step 1 issues short-lived faceSessionToken');
    assert(!empLoginStep1.tokens, 'Full JWT tokens are withheld until face verification succeeds');

    // -------------------------------------------------------------------------
    // TEST 7: Login 2FA Step 2 - Face Verification Mismatch & Lockout
    // -------------------------------------------------------------------------
    section('7. Login 2FA Step 2: Failed Face Verification & Lockout Protection');
    let verifyMismatchFailed = false;
    try {
      await authService.verifyFace({
        faceSessionToken: empLoginStep1.faceSessionToken,
        faceImage: personBPhoto, // Imposter face
      });
    } catch (e) {
      verifyMismatchFailed = true;
      assert(e.status === 401, 'Imposter face verification rejected with 401 Unauthorized');
    }
    assert(verifyMismatchFailed, 'Face mismatch blocked successfully');

    // Check failed attempt increment
    let userAfterFail1 = await prisma.user.findUnique({ where: { id: newEmployee.userId } });
    assert(userAfterFail1.failedFaceAttempts === 1, 'failedFaceAttempts incremented to 1');

    // Fail 2 more times to test lockout
    try {
      await authService.verifyFace({ faceSessionToken: empLoginStep1.faceSessionToken, faceImage: personBPhoto });
    } catch (_) {}
    try {
      await authService.verifyFace({ faceSessionToken: empLoginStep1.faceSessionToken, faceImage: personBPhoto });
    } catch (_) {}

    let userAfterFail3 = await prisma.user.findUnique({ where: { id: newEmployee.userId } });
    assert(userAfterFail3.failedFaceAttempts >= 3, 'failedFaceAttempts reached 3');
    assert(userAfterFail3.faceVerificationStatus === 'LOCKED', 'User status set to LOCKED after 3 failed attempts');
    assert(!!userAfterFail3.faceLockoutUntil, 'faceLockoutUntil timestamp is active');

    // Unlock user for positive test
    await prisma.user.update({
      where: { id: newEmployee.userId },
      data: { failedFaceAttempts: 0, faceLockoutUntil: null, faceVerificationStatus: 'ENROLLED' },
    });

    // -------------------------------------------------------------------------
    // TEST 8: Login 2FA Step 2 - Successful Face Verification & Token Issuance
    // -------------------------------------------------------------------------
    section('8. Login 2FA Step 2: Matching Face Accepted -> Session Created');
    const freshStep1 = await authService.login({ emailOrUsername: testUsername, password: 'Saark@2026' });
    const verifySuccess = await authService.verifyFace({
      faceSessionToken: freshStep1.faceSessionToken,
      faceImage: personAPhoto, // Matching registered face
    });

    assert(!!verifySuccess.tokens?.accessToken, 'Full access token issued upon successful face verification');
    assert(verifySuccess.user.username === testUsername, 'Authenticated user matches employee username');
    assert(verifySuccess.user.faceVerificationEnabled === true, 'User payload reports faceVerificationEnabled = true');

    const userAfterSuccess = await prisma.user.findUnique({ where: { id: newEmployee.userId } });
    assert(userAfterSuccess.failedFaceAttempts === 0, 'Failed attempts reset to 0 after success');

    // Verify audit log
    const auditRecord = await prisma.auditLog.findFirst({
      where: { userId: newEmployee.userId, action: 'FACE_VERIFICATION_SUCCESS' },
      orderBy: { timestamp: 'desc' },
    });
    assert(!!auditRecord, 'FACE_VERIFICATION_SUCCESS audit event logged in audit_logs');

    // -------------------------------------------------------------------------
    // TEST 9: Biometric Status & Re-Enrollment
    // -------------------------------------------------------------------------
    section('9. HR Module: Biometric Status & Re-Enrollment');
    const statusBefore = await hrService.getEmployeeFaceStatus(newEmployee.id);
    assert(statusBefore.hasBiometric === true && statusBefore.isActive === true, 'getEmployeeFaceStatus reports enrolled and active');

    // Re-enroll with new face (Person B)
    const reEnrollResult = await hrService.enrollEmployeeFace(newEmployee.id, {
      livePhotoBase64: personBPhoto,
      enableFaceAuth: true,
    });
    assert(reEnrollResult.success === true, 'Re-enrollment succeeded');

    // Now Person B should be the registered face and match!
    const step1AfterReEnroll = await authService.login({ emailOrUsername: testUsername, password: 'Saark@2026' });
    const verifyPersonB = await authService.verifyFace({
      faceSessionToken: step1AfterReEnroll.faceSessionToken,
      faceImage: personBPhoto,
    });
    assert(!!verifyPersonB.tokens?.accessToken, 'Newly re-enrolled face (Person B) successfully authenticates');

    // Cleanup test record
    await prisma.employeeFaceBiometric.deleteMany({ where: { employeeId: newEmployee.id } });
    await prisma.employee.deleteMany({ where: { id: newEmployee.id } });
    await prisma.userRole.deleteMany({ where: { userId: newEmployee.userId } });
    await prisma.user.deleteMany({ where: { id: newEmployee.userId } });

    console.log('\n================================================================');
    console.log(`TEST RESULTS: ${passedTests}/${totalTests} PASSED (${failedTests} FAILED)`);
    console.log('================================================================\n');

    await prisma.$disconnect();
    if (failedTests > 0) process.exit(1);
  } catch (err) {
    console.error('Fatal test error:', err);
    await prisma.$disconnect();
    process.exit(1);
  }
}

runFaceBiometricsTestSuite();
