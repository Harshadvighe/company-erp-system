/**
 * SAARK ERP — PHASE 6 INTEGRATION & VERIFICATION TEST SUITE
 * Admin Audit Logs Viewer, Filters, Pagination, CSV Export & Self-Audit Integrity
 */

const http = require('http');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

function request(options, data = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        let parsed = body;
        try {
          parsed = JSON.parse(body);
        } catch (_) {}
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: parsed,
          rawBody: body,
        });
      });
    });

    req.on('error', reject);

    if (data) {
      const payload = typeof data === 'string' ? data : JSON.stringify(data);
      req.setHeader('Content-Length', Buffer.byteLength(payload));
      req.write(payload);
    }
    req.end();
  });
}

function extractToken(body) {
  if (!body) return null;
  return (
    body.tokens?.accessToken ||
    body.data?.tokens?.accessToken ||
    body.accessToken ||
    body.data?.accessToken
  );
}

async function run() {
  console.log('========================================================================');
  console.log('SAARK ERP - PHASE 6 VERIFICATION SUITE');
  console.log('ADMIN AUDIT LOGS VIEWER, FILTERS, PAGINATION, CSV EXPORT & SELF-AUDIT');
  console.log('========================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  [PASS] ${message}`);
      passed++;
    } else {
      console.error(`  [FAIL] ${message}`);
      failed++;
    }
  }

  try {
    // ─── 1. AUTHENTICATION & BASELINE SETUP ─────────────────────────────────
    console.log('1. Authentication Setup:');

    // Admin Login
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
    assert(adminLoginRes.status === 200 || adminLoginRes.status === 201, 'Admin login succeeded (200 OK)');
    const adminToken = extractToken(adminLoginRes.body);
    assert(Boolean(adminToken), 'Admin JWT token received');

    // Employee (Rahul PM) Login
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
    assert(rahulLoginRes.status === 200 || rahulLoginRes.status === 201, 'Employee (Rahul PM) login succeeded (200 OK)');
    const rahulToken = extractToken(rahulLoginRes.body);
    assert(Boolean(rahulToken), 'Rahul PM received JWT token');

    const rahulUser = await prisma.user.findFirst({
      where: { email: 'rahul.patil@saark.in' },
    });
    // Ensure clean state (no custom overrides on AUDIT:*)
    if (rahulUser) {
      await prisma.userPermission.deleteMany({ where: { userId: rahulUser.id } });
    }

    // ─── 2. ACCESS CONTROL & PERMISSION GUARDS ──────────────────────────────
    console.log('\n2. Access Control & Permission Enforcement (AUDIT:VIEW & AUDIT:EXPORT):');

    // 2.1 Unauthenticated calls blocked (401)
    const unauthList = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs',
      method: 'GET',
    });
    assert(unauthList.status === 401, 'Unauthenticated GET /api/v1/audit-logs blocked with 401');

    const unauthExport = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs/export',
      method: 'GET',
    });
    assert(unauthExport.status === 401, 'Unauthenticated GET /api/v1/audit-logs/export blocked with 401');

    // 2.2 Non-permitted employee blocked (403)
    const empList = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(empList.status === 403, 'Employee without AUDIT:VIEW blocked with 403 Forbidden');

    const empExport = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs/export',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(empExport.status === 403, 'Employee without AUDIT:EXPORT blocked with 403 Forbidden');

    // 2.3 Admin access allowed (200)
    const adminList = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(adminList.status === 200, 'Admin with AUDIT:VIEW granted access (200 OK)');
    assert(Array.isArray(adminList.body.data), 'Audit logs response contains data array');
    assert(Boolean(adminList.body.meta), 'Audit logs response contains pagination metadata');
    assert(adminList.body.meta.page === 1, 'Pagination default page is 1');
    assert(adminList.body.meta.total >= 1, `Total audit records indexed: ${adminList.body.meta.total}`);

    // ─── 3. SERVER-SIDE PAGINATION & LIMIT VALIDATION ────────────────────────
    console.log('\n3. Server-Side Pagination & Limit Verification:');

    const pageLimitRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs?page=1&limit=5',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(pageLimitRes.status === 200, 'Paginated query ?page=1&limit=5 returns 200 OK');
    assert(pageLimitRes.body.data.length <= 5, `Returned page size (${pageLimitRes.body.data.length}) <= limit 5`);
    assert(pageLimitRes.body.meta.limit === 5, 'Metadata reflects requested limit 5');

    // ─── 4. RICH FILTERING (MODULE, ACTION, OUTCOME, SEARCH, DATES) ───────────
    console.log('\n4. Multi-Dimensional Audit Filters:');

    // 4.1 Filter by Module
    const filterModuleRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs?module=INVENTORY',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(filterModuleRes.status === 200, 'Filter by module=INVENTORY returns 200 OK');
    const allInventory = filterModuleRes.body.data.every((l) => l.module === 'INVENTORY');
    assert(allInventory, 'All returned records strictly match module INVENTORY');

    // 4.2 Filter by Action
    const filterActionRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs?action=AUTHORIZATION_DENIED',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(filterActionRes.status === 200, 'Filter by action=AUTHORIZATION_DENIED returns 200 OK');
    const allDeniedAction = filterActionRes.body.data.every((l) => l.action === 'AUTHORIZATION_DENIED');
    assert(allDeniedAction, 'All returned records strictly match action AUTHORIZATION_DENIED');

    // 4.3 Filter by Outcome
    const filterOutcomeRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs?outcome=DENIED',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(filterOutcomeRes.status === 200, 'Filter by outcome=DENIED returns 200 OK');
    assert(filterOutcomeRes.body.data.length > 0, 'Found security denial records');

    // 4.4 Search Filter (Email / Name)
    const filterSearchRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs?search=admin',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(filterSearchRes.status === 200, 'Filter by search=admin returns 200 OK');
    assert(filterSearchRes.body.data.length > 0, 'Search query returned matching audit entries');

    // 4.5 Date Range Filter
    const todayStr = new Date().toISOString().slice(0, 10);
    const filterDateRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/audit-logs?startDate=${todayStr}&endDate=${todayStr}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(filterDateRes.status === 200, 'Filter by today date range returns 200 OK');
    assert(filterDateRes.body.data.length > 0, 'Date range returns events recorded today');

    // ─── 5. EVENT DETAIL INSPECTION (GET /audit-logs/:id) ───────────────────
    console.log('\n5. Event Detail Inspection:');

    const sampleLog = adminList.body.data[0];
    assert(Boolean(sampleLog?.id), 'Sample audit log identified');

    const detailRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/audit-logs/${sampleLog.id}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const logData = detailRes.body.data || detailRes.body;
    assert(detailRes.status === 200, 'GET /api/v1/audit-logs/:id returns 200 OK');
    assert(logData.id === sampleLog.id, 'Returned event ID matches requested ID');
    assert(typeof logData.details === 'object', 'Audit details parsed into structured object');
    assert(logData.timestamp !== undefined, 'Event contains ISO timestamp');

    // 5.1 Non-existent event returns 404
    const notFoundRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs/00000000-0000-0000-0000-000000000000',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(notFoundRes.status === 404, 'GET /api/v1/audit-logs/:nonExistentId returns 404 Not Found');

    // ─── 6. CSV EXPORT & SELF-AUDIT INTEGRITY ────────────────────────────────
    console.log('\n6. CSV Export & Self-Audit Generation:');

    const exportRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/audit-logs/export?module=INVENTORY',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'x-request-id': 'req-export-audit-888',
      },
    });
    assert(exportRes.status === 200, 'GET /api/v1/audit-logs/export returns 200 OK');
    assert(
      exportRes.headers['content-type']?.includes('text/csv'),
      'Content-Type header is text/csv'
    );
    assert(
      exportRes.headers['content-disposition']?.includes('attachment; filename='),
      'Content-Disposition header specifies CSV download attachment'
    );

    const csvLines = exportRes.rawBody.trim().split(/\r?\n/);
    assert(csvLines.length >= 2, `Exported CSV contains header and data rows (${csvLines.length} lines)`);
    assert(
      csvLines[0].includes('Log ID') &&
        csvLines[0].includes('Timestamp (UTC)') &&
        csvLines[0].includes('Actor Email') &&
        csvLines[0].includes('Module') &&
        csvLines[0].includes('Action') &&
        csvLines[0].includes('Outcome'),
      'CSV header adheres strictly to standard schema'
    );

    // Wait 250ms for the self-audit log to persist
    await new Promise((r) => setTimeout(r, 250));

    // Verify the export execution ITSELF was recorded in audit_logs!
    const selfAuditLog = await prisma.auditLog.findFirst({
      where: {
        action: 'EXPORT',
        module: 'AUDIT',
      },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(selfAuditLog), 'Self-Audit: Export action recorded an EXPORT event under AUDIT module');
    const parsedSelfAudit = JSON.parse(selfAuditLog.details);
    assert(parsedSelfAudit.outcome === 'SUCCESS', 'Self-Audit recorded outcome SUCCESS');
    assert(parsedSelfAudit.requestId === 'req-export-audit-888', 'Self-Audit recorded request ID from header');
    const filterCriteria = parsedSelfAudit.meta?.filterCriteria || parsedSelfAudit.details?.filterCriteria;
    assert(
      filterCriteria?.module === 'INVENTORY',
      'Self-Audit recorded active filter criteria (module: INVENTORY)'
    );

    // ─── 7. SENSITIVE DATA REDACTION VERIFICATION ────────────────────────────
    console.log('\n7. Data Redaction Verification in Output:');

    assert(!exportRes.rawBody.includes('admin123') && !exportRes.rawBody.includes('Saark@2026'), 'Exported CSV contains NO plain passwords');
    assert(!exportRes.rawBody.includes('123456789012'), 'Exported CSV contains NO plain Aadhaar numbers');
    assert(!exportRes.rawBody.includes('987654321098'), 'Exported CSV contains NO plain bank account numbers');

    // ─── 8. APPEND-ONLY INTEGRITY ────────────────────────────────────────────
    console.log('\n8. Append-Only Immutability Enforcement:');

    const putAttempt = await request({
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/audit-logs/${sampleLog.id}`,
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
    }, { module: 'TAMPERED' });
    assert(putAttempt.status === 404 || putAttempt.status === 405, 'PUT /api/v1/audit-logs/:id is blocked (404/405) - Audit log is immutable');

    const deleteAttempt = await request({
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/audit-logs/${sampleLog.id}`,
      method: 'DELETE',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(deleteAttempt.status === 404 || deleteAttempt.status === 405, 'DELETE /api/v1/audit-logs/:id is blocked (404/405) - Audit log is append-only');

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
