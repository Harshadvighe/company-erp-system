const http = require('http');
const path = require('path');
const { PrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client'));

const prisma = new PrismaClient();

let passed = 0;
let failed = 0;

function assert(condition, testName, details = '') {
  if (condition) {
    passed++;
    console.log(`  [PASS] ${testName}`);
  } else {
    failed++;
    console.error(`  [FAIL] ${testName} - ${details}`);
  }
}

function request(options, body = null) {
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

function extractToken(body) {
  if (!body) return null;
  return body.tokens?.accessToken || body.data?.tokens?.accessToken || body.accessToken || body.data?.accessToken;
}

async function run() {
  console.log('========================================================================');
  console.log('SAARK ERP - PHASE 4 & 5 VERIFICATION SUITE');
  console.log('GLOBAL AUTHORIZATION & CENTRALIZED AUDIT TRAIL INTEGRITY');
  console.log('========================================================================\n');

  try {
    // ─── 1. AUTHENTICATION & BASELINE SETUP ──────────────────────────────────
    console.log('1. Admin Authentication & Baseline Setup:');
    const adminLoginRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: '/api/v1/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      { emailOrUsername: 'admin', password: 'Saark@2026' }
    );
    assert(adminLoginRes.status === 200 || adminLoginRes.status === 201, 'Admin login succeeded');
    const adminToken = extractToken(adminLoginRes.body);
    assert(Boolean(adminToken), 'Admin JWT token received');

    // Find test employee Rahul PM
    const rahulSearchRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/employees/access?search=rahul',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const rahulEmployees = rahulSearchRes.body.data?.employees || rahulSearchRes.body.employees || rahulSearchRes.body.data;
    const targetEmp = rahulEmployees[0];
    assert(Boolean(targetEmp), `Found target employee: ${targetEmp?.fullName || targetEmp?.firstName}`);
    const targetEmployeeId = targetEmp.id;

    const rahulLoginRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: '/api/v1/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      { emailOrUsername: 'rahul.pm', password: 'Saark@2026' }
    );
    assert(rahulLoginRes.status === 200 || rahulLoginRes.status === 201, 'Employee (Rahul PM) login succeeded');
    const rahulToken = extractToken(rahulLoginRes.body);
    assert(Boolean(rahulToken), 'Rahul PM received JWT token');

    // Retrieve Rahul's User record
    const rahulUser = await prisma.user.findFirst({
      where: { OR: [{ username: 'rahul.pm' }, { email: targetEmp.email }] },
    });
    assert(Boolean(rahulUser), 'Retrieved Rahul user database record');

    // ─── 2. UNAUTHENTICATED CALLS BLOCKED (401) ──────────────────────────────
    console.log('\n2. Unauthenticated Direct API Access Blocked:');
    const noAuthInventory = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/inventory/summary',
      method: 'GET',
    });
    assert(noAuthInventory.status === 401, 'Unauthenticated GET /inventory/summary returned 401');

    const noAuthPurchase = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/purchase/orders',
      method: 'GET',
    });
    assert(noAuthPurchase.status === 401, 'Unauthenticated GET /purchase/orders returned 401');

    const noAuthAudit = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs',
      method: 'GET',
    });
    assert(noAuthAudit.status === 401, 'Unauthenticated GET /audit-logs returned 401');

    // ─── 3. AUTHORIZATION DENY & FAILED ATTEMPT LOGGING (403) ────────────────
    console.log('\n3. Employee Forbidden Endpoints (403) & Audit Denials:');

    // Reset any custom overrides on Rahul first
    await prisma.userPermission.deleteMany({
      where: { userId: rahulUser.id },
    });

    const empAuditAccess = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(empAuditAccess.status === 403, 'Employee without AUDIT:VIEW blocked with 403 Forbidden');

    const empOrgAccess = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/company',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(empOrgAccess.status === 403, 'Employee without ORGANIZATION:VIEW blocked with 403 Forbidden');

    // Wait 250ms to allow asynchronous audit write
    await new Promise((r) => setTimeout(r, 250));

    // Verify AUTHORIZATION_DENIED was recorded in audit_logs without secrets
    const denialLog = await prisma.auditLog.findFirst({
      where: {
        userId: rahulUser.id,
        action: 'AUTHORIZATION_DENIED',
      },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(denialLog), 'AUTHORIZATION_DENIED recorded in audit_logs for forbidden request');
    assert(denialLog?.module === 'AUDIT' || denialLog?.module === 'ORGANIZATION', `Denial logged correct module: ${denialLog?.module}`);
    assert(!JSON.stringify(denialLog).includes('Saark@2026'), 'Denial log strictly contains no passwords or secrets');

    // ─── 4. EXPLICIT ALLOW OVERRIDE ENFORCEMENT ──────────────────────────────
    console.log('\n4. Explicit ALLOW Override Enforcement:');

    // Find permission ID for ORGANIZATION:VIEW
    const orgPerm = await prisma.permission.findUnique({
      where: { module_action: { module: 'ORGANIZATION', action: 'VIEW' } },
    });
    assert(Boolean(orgPerm), 'Found ORGANIZATION:VIEW permission in DB');

    const grantRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/admin/employees/${targetEmployeeId}/access`,
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
      },
      {
        overrides: [{ permissionId: orgPerm.id, effect: 'ALLOW' }],
        reason: 'Temporary organization profile audit authorization',
      }
    );
    assert(grantRes.status === 200, 'Admin granted ALLOW on ORGANIZATION:VIEW');

    const empOrgAfterGrant = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/company',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(empOrgAfterGrant.status === 200, 'Employee immediately granted access (200 OK) on next request without re-login');

    // ─── 5. EXPLICIT DENY OVERRIDE ENFORCEMENT ──────────────────────────────
    console.log('\n5. Explicit DENY Override Precedence:');

    const denyRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/admin/employees/${targetEmployeeId}/access`,
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
      },
      {
        overrides: [{ permissionId: orgPerm.id, effect: 'DENY' }],
        reason: 'Revoked organization view test',
      }
    );
    assert(denyRes.status === 200, 'Admin set DENY on ORGANIZATION:VIEW');

    const empOrgAfterDeny = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/company',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(empOrgAfterDeny.status === 403, 'Employee immediately DENIED access (403 Forbidden) overriding baseline permission');

    // ─── 6. AUDIT TRAIL FOR WRITE OPERATIONS & FIELD DIFFS ───────────────────
    console.log('\n6. Centralized Audit Trail on Business Writes:');

    const defaultCategory = await prisma.productCategory.findFirst();
    const defaultUnit = await prisma.unit.findFirst();

    const testSku = `SKU-AUDIT-${Date.now()}`;
    const createProductRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: '/api/v1/products',
        method: 'POST',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
          'x-request-id': 'req-audit-test-999',
        },
      },
      {
        sku: testSku,
        name: 'Audit Test Product',
        categoryId: defaultCategory?.id,
        unitId: defaultUnit?.id,
        purchasePrice: 1500,
        sellingPrice: 2200,
        openingStock: 25,
      }
    );
    assert(createProductRes.status === 201 || createProductRes.status === 200, 'Admin created product via POST /products');
    const createdProductId = createProductRes.body.data?.id || createProductRes.body.id;

    await new Promise((r) => setTimeout(r, 200));

    // Verify create audit log
    const createProductAudit = await prisma.auditLog.findFirst({
      where: {
        entityId: createdProductId,
        action: 'CREATE',
        module: 'INVENTORY',
      },
    });
    assert(Boolean(createProductAudit), 'Product CREATE audit log entry recorded in database');
    const parsedCreateDetails = JSON.parse(createProductAudit.details);
    assert(parsedCreateDetails.actor?.userId !== undefined, 'Audit record contains actor snapshot userId');
    assert(parsedCreateDetails.requestId === 'req-audit-test-999', 'Audit record captured request ID from header');

    // Update product
    const updateProductRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/products/${createdProductId}`,
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
      },
      {
        name: 'Audit Test Product (Updated Name)',
        sellingPrice: 2400,
      }
    );
    assert(updateProductRes.status === 200, 'Admin updated product via PUT /products/:id');

    await new Promise((r) => setTimeout(r, 200));

    const updateProductAudit = await prisma.auditLog.findFirst({
      where: {
        entityId: createdProductId,
        action: 'UPDATE',
        module: 'INVENTORY',
      },
    });
    assert(Boolean(updateProductAudit), 'Product UPDATE audit log recorded');
    const parsedUpdateDetails = JSON.parse(updateProductAudit.details);
    assert(Boolean(parsedUpdateDetails.before && parsedUpdateDetails.after), 'Audit record contains before and after snapshots');
    assert(Array.isArray(parsedUpdateDetails.changedFields), 'Audit record contains list of changed fields');
    assert(parsedUpdateDetails.changedFields.includes('sellingPrice') || parsedUpdateDetails.changedFields.includes('name'), 'Changed fields list identifies altered properties');

    // ─── 7. SENSITIVE DATA REDACTION INTEGRITY ────────────────────────────────
    console.log('\n7. Automatic Redaction Engine Verification:');

    // Onboard test employee with password, pan, aadhaar, bank details
    const hrToken = adminToken;
    const testEmployeeEmail = `tech.audit.${Date.now()}@saark.in`;
    const onboardRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: '/api/v1/hr/employees',
        method: 'POST',
        headers: {
          Authorization: `Bearer ${hrToken}`,
          'Content-Type': 'application/json',
        },
      },
      {
        firstName: 'Audit',
        lastName: 'Technician',
        email: testEmployeeEmail,
        phone: '9890123456',
        designation: 'Assembly Technician',
        panNo: 'ABCDE1234F',
        aadhaarNo: '123456789012',
        bankAccountNo: '987654321098',
        bankIfsc: 'HDFC0001234',
        salaryCtc: 350000,
      }
    );
    assert(onboardRes.status === 200 || onboardRes.status === 201, 'HR onboarded employee with financial/PII data');
    const onboardedEmpId = onboardRes.body.data?.id || onboardRes.body.id;

    await new Promise((r) => setTimeout(r, 200));

    const empAudit = await prisma.auditLog.findFirst({
      where: {
        entityId: onboardedEmpId,
        action: 'CREATE',
        module: 'HR',
      },
    });
    assert(Boolean(empAudit), 'Employee CREATE recorded in central audit trail');
    const parsedEmpDetails = JSON.parse(empAudit.details);
    const serializedEmpDetails = JSON.stringify(parsedEmpDetails);

    // Verify PAN, Aadhaar, Bank Account No are redacted
    assert(!serializedEmpDetails.includes('123456789012'), 'Aadhaar number is strictly REDACTED from audit details');
    assert(!serializedEmpDetails.includes('987654321098'), 'Bank account number is strictly REDACTED from audit details');
    assert(!serializedEmpDetails.includes('ABCDE1234F'), 'PAN number is strictly REDACTED from audit details');

    // ─── 8. APPEND-ONLY INTEGRITY ────────────────────────────────────────────
    console.log('\n8. Append-Only Integrity Check:');
    const deleteAuditAttempt = await request({
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/audit-logs/${createProductAudit.id}`,
      method: 'DELETE',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(deleteAuditAttempt.status === 404 || deleteAuditAttempt.status === 405, 'DELETE /audit-logs/:id is not supported (404/405) - Audit log is append-only');

    // ─── 9. CLEANUP TEST DATA ────────────────────────────────────────────────
    console.log('\n9. Cleanup Test Data:');
    if (createdProductId) {
      await prisma.product.delete({ where: { id: createdProductId } }).catch(() => {});
    }
    if (onboardedEmpId) {
      await prisma.employee.delete({ where: { id: onboardedEmpId } }).catch(() => {});
    }
    // Restore clean state for Rahul
    await prisma.userPermission.deleteMany({ where: { userId: rahulUser.id } });
    console.log('  Cleaned up temporary product and employee records.');

    console.log('\n========================================================================');
    console.log(`VERIFICATION SUMMARY: ${passed} PASSED, ${failed} FAILED`);
    console.log('========================================================================\n');

    await prisma.$disconnect();

    if (failed > 0) {
      process.exit(1);
    }
  } catch (err) {
    console.error('Unhandled test suite error:', err);
    await prisma.$disconnect();
    process.exit(1);
  }
}

run();
