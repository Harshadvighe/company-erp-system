/**
 * SAARK ERP — EXPORT & DOWNLOAD AUDIT INTEGRATION SUITE
 * Tests server-side export auditing across:
 * 1. Customer Master CSV Export
 * 2. HR Employee Directory CSV Export (with PII Redaction)
 * 3. Factories Act Form 25 Muster Roll Export (CSV & JSON)
 * 4. GST GSTR-1 Tax Invoices Export (JSON & CSV)
 * 5. Bulk Import Template & Error Report CSV Downloads
 * 6. Document File Downloads
 * 7. Panel BOM Specification Export
 * 8. Executive Analytics Summary CSV Export
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
  console.log('SAARK ERP - CENTRALIZED EXPORT & DOWNLOAD AUDITING SUITE');
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
    // 1. Authenticate Admin and Rahul (regular employee)
    console.log('1. Authentication Setup:');
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

    const rahulUser = await prisma.user.findFirst({
      where: { email: 'rahul.patil@saark.in' },
    });
    if (rahulUser) {
      // Clean custom overrides for Rahul
      await prisma.userPermission.deleteMany({ where: { userId: rahulUser.id } });
    }

    // 2. Customer Master CSV Export
    console.log('\n2. Customer Master CSV Export & Auditing:');
    // 401 check
    const unauthCust = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/customers/export',
      method: 'GET',
    });
    assert(unauthCust.status === 401, 'Unauthenticated GET /api/v1/customers/export is blocked with 401');

    // 403 check (deny Rahul CUSTOMERS:EXPORT)
    const custPerm = await prisma.permission.findFirst({
      where: { module: 'CUSTOMERS', action: 'EXPORT' },
    });
    if (custPerm && rahulUser) {
      await prisma.userPermission.upsert({
        where: { userId_permissionId: { userId: rahulUser.id, permissionId: custPerm.id } },
        update: { effect: 'DENY' },
        create: { userId: rahulUser.id, permissionId: custPerm.id, effect: 'DENY' },
      });
    }
    const rahulCustRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/customers/export',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(rahulCustRes.status === 403, 'User with explicit DENY on CUSTOMERS:EXPORT is blocked with 403');

    // Clean override
    if (rahulUser) {
      await prisma.userPermission.deleteMany({ where: { userId: rahulUser.id } });
    }

    // Admin success
    const adminCustRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/customers/export',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'X-Request-Id': 'req-export-customers-001',
      },
    });
    assert(adminCustRes.status === 200, 'Admin GET /api/v1/customers/export returns 200 OK');
    assert((adminCustRes.headers['content-type'] || '').includes('text/csv'), 'Customers export Content-Type is text/csv');
    assert(adminCustRes.rawBody.includes('Customer Code,Company Name'), 'CSV includes Customer header schema');

    // Verify Audit log
    const custAudit = await prisma.auditLog.findFirst({
      where: { action: 'EXPORT', module: 'CRM', entityType: 'Customer' },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(custAudit), 'Centralized AuditService recorded Customer EXPORT action under CRM module');
    assert(custAudit?.details.includes('CSV'), 'Customer export audit details record format CSV');

    // 3. HR Employee Directory CSV Export with PII Redaction
    console.log('\n3. HR Employee Directory CSV Export & PII Redaction:');
    const empExportRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/hr/employees/export',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'X-Request-Id': 'req-export-employees-001',
      },
    });
    assert(empExportRes.status === 200, 'Admin GET /api/v1/hr/employees/export returns 200 OK');
    assert((empExportRes.headers['content-type'] || '').includes('text/csv'), 'Employees export Content-Type is text/csv');
    assert(empExportRes.rawBody.includes('Employee Code,First Name,Last Name'), 'CSV includes Employee headers');

    // PII Redaction Verification
    assert(!/(\b\d{4}[ -]?\d{4}[ -]?\d{4}\b)/.test(empExportRes.rawBody), 'Export strictly contains NO unmasked 12-digit Aadhaar numbers');
    assert(!/(\b[0-9]{9,18}\b)/.test(empExportRes.rawBody), 'Export strictly contains NO unmasked bank account numbers');

    // Audit log check
    const empAudit = await prisma.auditLog.findFirst({
      where: { action: 'EXPORT', module: 'HR', entityType: 'Employee' },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(empAudit), 'Centralized AuditService recorded Employee EXPORT action under HR module');

    // 4. Factories Act Form 25 Muster Roll Export
    console.log('\n4. Form 25 Muster Roll Export (CSV & JSON):');
    // Format CSV
    const musterCsvRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/hr/muster-roll/export?format=csv&month=10&year=2026',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'X-Request-Id': 'req-export-muster-csv',
      },
    });
    assert(musterCsvRes.status === 200, 'GET /api/v1/hr/muster-roll/export?format=csv returns 200 OK');
    assert((musterCsvRes.headers['content-type'] || '').includes('text/csv'), 'Muster roll CSV Content-Type is text/csv');
    assert(musterCsvRes.rawBody.includes('FACTORIES ACT 1948 - FORM 25'), 'Muster roll contains statutory Form 25 header');
    assert(musterCsvRes.rawBody.includes('Overtime Earnings'), 'Muster roll CSV includes overtime earnings column');

    // Format JSON
    const musterJsonRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/hr/muster-roll/export?format=json&month=10&year=2026',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'X-Request-Id': 'req-export-muster-json',
      },
    });
    assert(musterJsonRes.status === 200, 'GET /api/v1/hr/muster-roll/export?format=json returns 200 OK');
    assert(Boolean(musterJsonRes.body?.form), 'Muster roll JSON payload includes form title');
    assert(Array.isArray(musterJsonRes.body?.records), 'Muster roll JSON includes employee attendance records');

    const musterAudit = await prisma.auditLog.findFirst({
      where: { action: 'EXPORT', module: 'HR', entityType: 'MusterRoll' },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(musterAudit), 'Centralized AuditService recorded MusterRoll EXPORT action under HR module');

    // 5. GST GSTR-1 Tax Return Export (JSON & CSV)
    console.log('\n5. GST GSTR-1 Tax Return Export & Auditing:');
    // Format JSON
    const gstJsonRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/reports/gst/export?format=json&year=2026',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'X-Request-Id': 'req-export-gst-json',
      },
    });
    assert(gstJsonRes.status === 200, 'GET /api/v1/reports/gst/export?format=json returns 200 OK');
    assert(Boolean(gstJsonRes.body?.gstin), 'GST export JSON includes company GSTIN');
    assert(Array.isArray(gstJsonRes.body?.b2b), 'GST export JSON includes b2b invoice list');
    assert(Boolean(gstJsonRes.body?.summary), 'GST export JSON includes tax breakdown summary');

    // Format CSV
    const gstCsvRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/reports/gst/export?format=csv&year=2026',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'X-Request-Id': 'req-export-gst-csv',
      },
    });
    assert(gstCsvRes.status === 200, 'GET /api/v1/reports/gst/export?format=csv returns 200 OK');
    assert(gstCsvRes.rawBody.includes('GSTIN of Recipient'), 'GST CSV contains standard GSTR-1 tax columns');

    const gstAudit = await prisma.auditLog.findFirst({
      where: { action: 'EXPORT', module: 'REPORTS', entityType: 'GST_RETURN' },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(gstAudit), 'Centralized AuditService recorded GST_RETURN EXPORT action under REPORTS module');

    // 6. Bulk Import Template & Error Report Download Auditing
    console.log('\n6. Bulk Import Template & Error Report Auditing:');
    const templateRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/bulk-import/template/customer',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'X-Request-Id': 'req-export-template-001',
      },
    });
    assert(templateRes.status === 200, 'GET /api/v1/bulk-import/template/customer returns 200 OK');
    assert((templateRes.headers['content-type'] || '').includes('text/csv'), 'Template content-type is text/csv');

    const templateAudit = await prisma.auditLog.findFirst({
      where: { action: 'EXPORT', module: 'BULK_IMPORT', entityType: 'ImportTemplate' },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(templateAudit), 'Centralized AuditService recorded ImportTemplate EXPORT under BULK_IMPORT');

    const errorReportRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: '/api/v1/bulk-import/error-report',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
          'X-Request-Id': 'req-export-error-report-001',
        },
      },
      {
        target: 'CUSTOMER',
        errors: [{ rowNumber: 2, field: 'gstin', value: 'INVALID', error: 'Invalid GSTIN format' }],
      }
    );
    assert(errorReportRes.status === 200, 'POST /api/v1/bulk-import/error-report returns 200 OK');

    const errorAudit = await prisma.auditLog.findFirst({
      where: { action: 'EXPORT', module: 'BULK_IMPORT', entityType: 'ErrorReport' },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(errorAudit), 'Centralized AuditService recorded ErrorReport EXPORT under BULK_IMPORT');

    // 7. Executive Summary CSV Export
    console.log('\n7. Executive ERP Summary Report CSV Export:');
    const execSummaryRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/reports/summary/export',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'X-Request-Id': 'req-export-exec-summary',
      },
    });
    assert(execSummaryRes.status === 200, 'GET /api/v1/reports/summary/export returns 200 OK');
    assert(execSummaryRes.rawBody.includes('SAARK EXPLORATION ERP - EXECUTIVE MANAGEMENT SUMMARY REPORT'), 'Summary includes ERP executive report header');

    const summaryAudit = await prisma.auditLog.findFirst({
      where: { action: 'EXPORT', module: 'REPORTS', entityType: 'ExecutiveSummary' },
      orderBy: { timestamp: 'desc' },
    });
    assert(Boolean(summaryAudit), 'Centralized AuditService recorded ExecutiveSummary EXPORT under REPORTS module');

    // 8. Panel BOM Specification Export
    console.log('\n8. Panel BOM Specification Export:');
    const samplePanel = await prisma.panelSpecification.findFirst();
    if (samplePanel) {
      const bomExportRes = await request({
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/panel-manufacturing/specs/${samplePanel.id}/bom/export`,
        method: 'GET',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'X-Request-Id': 'req-export-bom-001',
        },
      });
      assert(bomExportRes.status === 200, 'GET /api/v1/panel-manufacturing/specs/:id/bom/export returns 200 OK');
      assert(bomExportRes.rawBody.includes('PANEL BILL OF MATERIALS (BOM)'), 'BOM export includes BOM header');

      const bomAudit = await prisma.auditLog.findFirst({
        where: { action: 'EXPORT', module: 'PRODUCTION', entityType: 'PanelSpecification' },
        orderBy: { timestamp: 'desc' },
      });
      assert(Boolean(bomAudit), 'Centralized AuditService recorded PanelSpecification BOM EXPORT');
    } else {
      console.log('  [SKIP] No PanelSpecification record found to export BOM');
    }

    // 9. Document Download Auditing
    console.log('\n9. Document Download Stream Auditing:');
    const sampleDoc = await prisma.documentItem.findFirst();
    if (sampleDoc) {
      const docDownloadRes = await request({
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/documents/${sampleDoc.id}/download`,
        method: 'GET',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'X-Request-Id': 'req-download-doc-001',
        },
      });
      assert(docDownloadRes.status === 200, 'GET /api/v1/documents/:id/download returns 200 OK');

      const docAudit = await prisma.auditLog.findFirst({
        where: { action: 'DOWNLOAD', module: 'DOCUMENTS', entityId: sampleDoc.id },
        orderBy: { timestamp: 'desc' },
      });
      assert(Boolean(docAudit), 'Centralized AuditService recorded DOWNLOAD action under DOCUMENTS module');
    } else {
      console.log('  [SKIP] No DocumentItem record found to download');
    }

    console.log('\n========================================================================');
    console.log(`EXPORT & DOWNLOAD AUDIT SUITE: ${passed} PASSED, ${failed} FAILED`);
    console.log('========================================================================\n');

    await prisma.$disconnect();
    if (failed > 0) process.exit(1);
  } catch (err) {
    console.error('Unhandled test suite error:', err);
    await prisma.$disconnect();
    process.exit(1);
  }
}

run();
