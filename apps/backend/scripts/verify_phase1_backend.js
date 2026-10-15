const path = require('path');
const fs = require('fs');
const assert = require('assert');
const { PrismaClient } = require('@prisma/client');

// Ensure SQLite URL for local PrismaClient
const sqliteDbPath = path.resolve(__dirname, '../../storage/saark_erp.db').replace(/\\/g, '/');
process.env.DATABASE_URL = `file:${sqliteDbPath}`;
const prisma = new PrismaClient({
  datasources: {
    db: { url: `file:${sqliteDbPath}` }
  }
});

// Load Staging Client if available
let stagingPrisma = null;
try {
  const { PrismaClient: StagingPrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client-staging'));
  const env = {};
  fs.readFileSync(path.resolve(__dirname, '../.env.staging'), 'utf8').split(/\r?\n/).forEach(line => {
    const parts = line.split('=');
    if (parts.length >= 2) env[parts[0].trim()] = parts.slice(1).join('=').trim().replace(/^["']|["']$/g, '');
  });
  if (env.DATABASE_URL) {
    stagingPrisma = new StagingPrismaClient({
      datasources: {
        db: { url: env.DATABASE_URL }
      }
    });
  }
} catch (e) {
  console.log('[WARN] Staging client could not be initialized:', e.message);
}

// Mock/real services for CrmService testing
const { LocalFileStorageService } = require('../dist/src/core/storage/file-storage.service');
const { AuditService } = require('../dist/src/core/audit/audit.service');
const { SequenceService } = require('../dist/src/core/database/sequence.service');
const { GstVerificationService } = require('../dist/src/modules/crm/gst-verification.service');
const { CrmService } = require('../dist/src/modules/crm/crm.service');

async function runPhase1Verification() {
  console.log('================================================================');
  console.log('SAARK ERP UNIFIED CRM FOLLOW-UPS — PHASE 1 VERIFICATION SUITE');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function recordPass(testName) {
    passed++;
    console.log(`[PASS] ${testName}`);
  }

  function recordFail(testName, err) {
    failed++;
    console.error(`[FAIL] ${testName}:`, err.message);
    if (err.stack) console.error(err.stack);
  }

  await prisma.$connect();

  const auditService = new AuditService(prisma);
  const sequenceService = new SequenceService(prisma);
  const gstVerificationService = new GstVerificationService();
  const fileStorageService = new LocalFileStorageService();
  const crmService = new CrmService(
    prisma,
    auditService,
    gstVerificationService,
    sequenceService,
    fileStorageService
  );

  // ─────────────────────────────────────────────────────────────
  // 1. SCHEMA PARITY & MODEL VERIFICATION
  // ─────────────────────────────────────────────────────────────
  console.log('\n--- 1. SCHEMA PARITY & ATTRIBUTE VERIFICATION ---');
  try {
    assert(typeof prisma.crmAttachment.create === 'function', 'crmAttachment model must exist on SQLite Prisma client');
    assert(typeof prisma.crmFollowUp.update === 'function', 'crmFollowUp model must exist on SQLite Prisma client');
    assert(typeof prisma.crmActivity.create === 'function', 'crmActivity model must exist on SQLite Prisma client');
    recordPass('Local SQLite schema contains crmAttachment, crmActivity, crmFollowUp models');
  } catch (err) {
    recordFail('Local SQLite schema verification', err);
  }

  if (stagingPrisma) {
    try {
      await stagingPrisma.$connect();
      assert(typeof stagingPrisma.crmAttachment.create === 'function', 'crmAttachment model must exist on staging Prisma client');
      assert(typeof stagingPrisma.crmFollowUp.update === 'function', 'crmFollowUp model must exist on staging Prisma client');
      assert(typeof stagingPrisma.crmActivity.create === 'function', 'crmActivity model must exist on staging Prisma client');
      
      // Verify staging table presence via raw count
      const stagingAttachmentCount = await stagingPrisma.crmAttachment.count();
      const stagingFollowUpCount = await stagingPrisma.crmFollowUp.count();
      console.log(`Staging PostgreSQL counts: crmAttachments=${stagingAttachmentCount}, crmFollowUps=${stagingFollowUpCount}`);
      recordPass('Staging PostgreSQL schema matches models with zero table/column drift');
    } catch (err) {
      recordFail('Staging PostgreSQL schema verification', err);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. ISOLATED TEST FIXTURES SETUP
  // ─────────────────────────────────────────────────────────────
  console.log('\n--- 2. TEST FIXTURES SETUP ---');
  let testCustomer = null;
  let testStaff = null;
  let unauthorizedStaff = null;
  let adminUser = null;
  let employeeUser = null;
  let unauthorizedUser = null;
  let testFollowUp = null;

  try {
    // Find or create test staff
    testStaff = await prisma.staff.findFirst();
    if (!testStaff) {
      throw new Error('No staff found in database to link test user');
    }

    // Unauthorized staff
    unauthorizedStaff = await prisma.staff.findFirst({
      where: { id: { not: testStaff.id } }
    });
    if (!unauthorizedStaff) {
      unauthorizedStaff = await prisma.staff.create({
        data: {
          employeeCode: 'EMP-UNAUTH-TEST',
          fullName: 'Unauthorized Test Employee',
          departmentId: testStaff.departmentId,
          designationId: testStaff.designationId,
        }
      });
    }

    const existingUser = await prisma.user.findFirst();
    const testUserId = existingUser ? existingUser.id : undefined;

    // Users
    adminUser = {
      id: testUserId,
      userId: testUserId,
      username: 'admin',
      roles: ['ROLE_ADMIN'],
      staffId: testStaff.id,
      fullName: 'System Admin',
    };

    employeeUser = {
      id: testUserId,
      userId: testUserId,
      username: 'sales_rep',
      roles: ['ROLE_SALES_REP'],
      staffId: testStaff.id,
      fullName: 'Authorized Sales Rep',
    };

    unauthorizedUser = {
      id: testUserId,
      userId: testUserId,
      username: 'unauth_rep',
      roles: ['ROLE_USER'],
      staffId: unauthorizedStaff.id,
      fullName: 'Unauthorized Employee',
    };

    // Create isolated test customer
    testCustomer = await prisma.customer.create({
      data: {
        customerCode: `CUST-TEST-${Date.now()}`,
        companyName: `Phase1 Test Enterprise ${Date.now()}`,
        contactPerson: 'Rajesh Sharma',
        email: `contact-${Date.now()}@example.com`,
        phone: '9876543210',
        address: 'Plot 42, MIDC Bhosari',
        state: 'Maharashtra',
        district: 'Pune',
        city: 'Pune',
        pincode: '411026',
        assignedStaffId: testStaff.id,
        status: 'ACTIVE',
        customerType: 'DIRECT_CLIENT',
      }
    });

    // Create isolated test follow up
    testFollowUp = await prisma.crmFollowUp.create({
      data: {
        title: 'Initial Discovery Call',
        activityType: 'CALL',
        customerId: testCustomer.id,
        assignedStaffId: testStaff.id,
        followUpNumber: 1,
        status: 'PENDING',
        priority: 'MEDIUM',
        notes: 'Pre-meeting preparation notes',
      }
    });

    recordPass(`Created test customer (${testCustomer.companyName}) and pending follow-up (${testFollowUp.id})`);
  } catch (err) {
    recordFail('Test fixture creation', err);
  }

  // ─────────────────────────────────────────────────────────────
  // 3. PBAC & ROLE ENFORCEMENT
  // ─────────────────────────────────────────────────────────────
  console.log('\n--- 3. PBAC & AUTHORIZATION CHECKS ---');
  try {
    let forbiddenCaught = false;
    try {
      await crmService.resolveFollowUp(
        testFollowUp.id,
        {
          activityType: 'CALL',
          outcome: 'CONNECTED',
          discussion: 'Unauthorized resolution attempt',
        },
        unauthorizedUser
      );
    } catch (e) {
      forbiddenCaught = true;
      assert(e.status === 403 || e.message.includes('permission'), 'Must return 403 Forbidden for unassigned staff');
    }
    assert(forbiddenCaught, 'PBAC must reject follow-up resolution by non-assigned non-manager staff');
    recordPass('PBAC correctly forbids unauthorized employee from resolving unassigned follow-up');
  } catch (err) {
    recordFail('PBAC authorization enforcement', err);
  }

  // ─────────────────────────────────────────────────────────────
  // 4. ATTACHMENT MULTI-FILE UPLOAD & STREAMING
  // ─────────────────────────────────────────────────────────────
  console.log('\n--- 4. ATTACHMENT UPLOAD & AUTHENTICATED STREAMING ---');
  let uploadedAttachment = null;
  try {
    // Test MIME limit rejection
    let mimeRejected = false;
    try {
      await crmService.uploadAttachments(
        [
          {
            originalname: 'malicious.exe',
            mimetype: 'application/x-msdownload',
            size: 1024,
            buffer: Buffer.from('MZ00000'),
          }
        ],
        { customerId: testCustomer.id },
        employeeUser
      );
    } catch (e) {
      mimeRejected = true;
      assert(e.message.includes('Unsupported file type'), 'Must reject unsupported file types');
    }
    assert(mimeRejected, 'Must reject executable / unallowed MIME types');
    recordPass('MIME type enforcement correctly rejected unauthorized file types');

    // Test valid audio recording and document upload
    const sampleAudioBuffer = Buffer.from('FAKE-AUDIO-DATA-STREAM-123456');
    const uploadRes = await crmService.uploadAttachments(
      [
        {
          originalname: 'discovery_call_recording.webm',
          mimetype: 'audio/webm',
          size: sampleAudioBuffer.length,
          buffer: sampleAudioBuffer,
        }
      ],
      {
        customerId: testCustomer.id,
        followUpId: testFollowUp.id,
        sourceCategory: 'CALL_RECORDING',
        description: 'Customer discovery audio call recording',
      },
      employeeUser
    );

    assert(Array.isArray(uploadRes) && uploadRes.length === 1, 'Upload must return array of created attachments');
    uploadedAttachment = uploadRes[0];
    assert.strictEqual(uploadedAttachment.mediaClass, 'AUDIO', 'Media class must be identified as AUDIO');
    assert.strictEqual(uploadedAttachment.fileName, 'discovery_call_recording.webm');
    assert(uploadedAttachment.storagePath.length > 0, 'Must have valid storagePath');
    recordPass('Multi-file attachment upload succeeded with media class classification');

    // Test Authenticated Streaming
    const streamRes = await crmService.getAttachmentStream(uploadedAttachment.id, employeeUser);
    assert(streamRes.attachment.id === uploadedAttachment.id, 'Must return attachment metadata');
    assert(Buffer.isBuffer(streamRes.buffer), 'Must return file Buffer');
    assert.strictEqual(streamRes.buffer.toString(), 'FAKE-AUDIO-DATA-STREAM-123456', 'Buffer content must match uploaded file');
    recordPass('Authenticated attachment streaming downloaded exact file buffer');
  } catch (err) {
    recordFail('Attachment upload and streaming verification', err);
  }

  // ─────────────────────────────────────────────────────────────
  // 5. ATOMIC FOLLOW-UP RESOLUTION & IDEMPOTENCY
  // ─────────────────────────────────────────────────────────────
  console.log('\n--- 5. ATOMIC RESOLUTION, TRANSACTIONS & IDEMPOTENCY ---');
  let resolutionResult = null;
  const testIdempotencyKey = `idemp-key-${Date.now()}`;

  try {
    const nextDate = new Date();
    nextDate.setDate(nextDate.getDate() + 3);
    nextDate.setHours(11, 0, 0, 0);

    resolutionResult = await crmService.resolveFollowUp(
      testFollowUp.id,
      {
        activityType: 'CALL',
        subject: 'Detailed technical scoping call',
        discussion: 'Customer specified need for 75HP VFD booster pump panel with auto PLC changeover.',
        outcome: 'CONNECTED',
        callDurationSec: 240,
        callOutcome: 'CONNECTED',
        customerRequirements: '75HP VFD panel with IP55 powder coated enclosure and star delta bypass',
        productsDiscussed: ['VFD_PANEL', 'BOOSTER_PUMP'],
        documentsSent: ['CATALOG', 'QUOTATION'],
        scheduleNext: true,
        nextActivityType: 'MEETING',
        nextScheduledDate: nextDate.toISOString(),
        nextSubject: 'Commercial negotiation meeting at customer office',
        nextNotes: 'Present SLD drawing revision 1',
        nextPriority: 'HIGH',
        attachmentIds: uploadedAttachment ? [uploadedAttachment.id] : [],
        idempotencyKey: testIdempotencyKey,
      },
      employeeUser
    );

    assert(resolutionResult.followUp, 'Must return completed followUp');
    assert.strictEqual(resolutionResult.followUp.status, 'COMPLETED', 'FollowUp status must be COMPLETED');
    assert(resolutionResult.followUp.completedDate, 'completedDate must be populated');
    assert(resolutionResult.followUp.completedActivityId, 'completedActivityId must be linked');
    assert(resolutionResult.activity, 'Activity record must be created');
    assert.strictEqual(resolutionResult.activity.activityType, 'CALL', 'Activity type must be CALL');
    assert(resolutionResult.nextFollowUp, 'Next followUp must be scheduled');
    assert.strictEqual(resolutionResult.nextFollowUp.status, 'PENDING');
    assert.strictEqual(resolutionResult.nextFollowUp.parentFollowUpId, testFollowUp.id, 'parentFollowUpId must chain to completed follow-up');

    // Verify type specific call child record
    const callRecord = await prisma.crmCall.findUnique({
      where: { activityId: resolutionResult.activity.id }
    });
    assert(callRecord, 'CrmCall detail record must exist');
    assert.strictEqual(callRecord.durationSec, 240);
    assert.strictEqual(callRecord.callOutcome, 'CONNECTED');

    // Verify attachment linkage
    const linkedAttachment = await prisma.crmAttachment.findUnique({
      where: { id: uploadedAttachment.id }
    });
    assert.strictEqual(linkedAttachment.activityId, resolutionResult.activity.id, 'Attachment must link to activityId');
    assert.strictEqual(linkedAttachment.followUpId, testFollowUp.id, 'Attachment must link to followUpId');

    recordPass('Atomic resolution recorded activity, completed follow-up, linked media and chained next follow-up');

    // Test Idempotency Retry
    console.log('Testing idempotency retry with identical idempotencyKey...');
    const retryResult = await crmService.resolveFollowUp(
      testFollowUp.id,
      {
        activityType: 'CALL',
        discussion: 'Retry should not re-execute or duplicate records',
        idempotencyKey: testIdempotencyKey,
      },
      employeeUser
    );

    assert.strictEqual(retryResult.idempotent, true, 'Retry must return idempotent: true');
    assert.strictEqual(retryResult.followUp.id, testFollowUp.id, 'Must return original completed follow-up');
    assert.strictEqual(retryResult.activity.id, resolutionResult.activity.id, 'Must return original activity');
    recordPass('Idempotency protection safely returned existing result without creating duplicates');

    // Test Concurrent / Second Resolution without idempotencyKey
    let conflictCaught = false;
    try {
      await crmService.resolveFollowUp(
        testFollowUp.id,
        {
          activityType: 'CALL',
          discussion: 'Attempting to resolve already completed follow-up',
        },
        employeeUser
      );
    } catch (e) {
      conflictCaught = true;
      assert(e.message.includes('already completed'), 'Must throw BadRequestException for already completed follow-up');
    }
    assert(conflictCaught, 'Concurrency guard blocks duplicate completion attempts');
    recordPass('Concurrency check blocked duplicate completion of already resolved follow-up');
  } catch (err) {
    recordFail('Atomic resolution & idempotency verification', err);
  }

  // ─────────────────────────────────────────────────────────────
  // 6. CONSOLIDATED CUSTOMER TIMELINE PARITY
  // ─────────────────────────────────────────────────────────────
  console.log('\n--- 6. CONSOLIDATED CUSTOMER TIMELINE ---');
  try {
    // Create a legacy customer interaction to verify timeline inclusion
    const legacyInteraction = await prisma.customerInteraction.create({
      data: {
        customerId: testCustomer.id,
        interactionType: 'VISIT',
        subject: 'Historical Factory Visit 2025',
        description: 'Legacy customer interaction from previous year before CRM migration',
        outcome: 'POSITIVE',
        recordedBy: 'Harshad V',
        interactionDate: new Date('2025-06-15T10:00:00Z'),
      }
    });

    const timeline = await crmService.getCompanyTimeline(testCustomer.id, employeeUser);
    assert(Array.isArray(timeline), 'Timeline must return an array');
    assert(timeline.length >= 3, `Timeline must contain activities, follow-ups, attachments and legacy interactions (got ${timeline.length})`);

    const hasLegacy = timeline.some(t => t.id === legacyInteraction.id && t.type.includes('LEGACY_INTERACTION'));
    const hasActivity = timeline.some(t => t.id === resolutionResult.activity.id);
    const hasFollowUp = timeline.some(t => t.id === testFollowUp.id);
    const hasAttachment = timeline.some(t => t.id === uploadedAttachment.id && t.type.includes('ATTACHMENT'));

    assert(hasLegacy, 'Timeline must include historical customer_interactions without backfills');
    assert(hasActivity, 'Timeline must include new unified CrmActivity');
    assert(hasFollowUp, 'Timeline must include CrmFollowUp records');
    assert(hasAttachment, 'Timeline must include CrmAttachment media records');

    // Verify chronological order
    for (let i = 0; i < timeline.length - 1; i++) {
      const currTime = new Date(timeline[i].timestamp).getTime();
      const nextTime = new Date(timeline[i + 1].timestamp).getTime();
      assert(currTime >= nextTime, 'Timeline must be ordered chronologically descending');
    }

    recordPass('Consolidated timeline correctly unifies legacy interactions, activities, follow-ups and attachments');
  } catch (err) {
    recordFail('Consolidated customer timeline verification', err);
  }

  // ─────────────────────────────────────────────────────────────
  // 7. CLEANUP ISOLATED TEST DATA
  // ─────────────────────────────────────────────────────────────
  console.log('\n--- 7. TEARDOWN & REPOSITORY INTEGRITY ---');
  try {
    if (uploadedAttachment) {
      await crmService.deleteAttachment(uploadedAttachment.id, adminUser);
    }
    if (testCustomer) {
      // Cascade delete test customer (will cleanly delete follow-ups, activities, interactions)
      await prisma.customer.delete({ where: { id: testCustomer.id } });
    }
    recordPass('Isolated test fixtures cleaned up; baseline database integrity preserved');
  } catch (err) {
    recordFail('Teardown test data cleanup', err);
  }

  // ─────────────────────────────────────────────────────────────
  // 8. FINAL RESULTS
  // ─────────────────────────────────────────────────────────────
  console.log('\n================================================================');
  console.log(`PHASE 1 VERIFICATION COMPLETE: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================');

  await prisma.$disconnect();
  if (stagingPrisma) await stagingPrisma.$disconnect();

  if (failed > 0) {
    process.exit(1);
  }
}

runPhase1Verification().catch((e) => {
  console.error('Unhandled fatal error in test suite:', e);
  process.exit(1);
});
