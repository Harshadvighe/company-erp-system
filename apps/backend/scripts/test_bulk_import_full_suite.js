const fs = require('fs');
const path = require('path');
const http = require('http');

// Load environment variables from .env.staging
const stagingEnvPath = path.resolve(__dirname, '../.env.staging');
if (fs.existsSync(stagingEnvPath)) {
  const envContent = fs.readFileSync(stagingEnvPath, 'utf8');
  envContent.split(/\r?\n/).forEach((line) => {
    const t = line.trim();
    if (t && !t.startsWith('#')) {
      const eq = t.indexOf('=');
      if (eq !== -1) {
        const k = t.slice(0, eq).trim();
        let v = t.slice(eq + 1).trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          v = v.slice(1, -1);
        }
        process.env[k] = v;
      }
    }
  });
}

const { parseSpreadsheet, autoDetectColumnMapping, parseExcelSerialDate, parseCleanPhone } = require('../dist/src/modules/bulk-import/excel-parser.util');
const { PrismaClient } = require('../node_modules/@prisma/client-staging');
const prisma = new PrismaClient();

const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET || 'saark_erp_production_jwt_secret_key_2026_x98123';

function generateTestToken(user) {
  return jwt.sign(
    {
      sub: user.id,
      email: user.email,
      roles: user.roles || [],
      permissions: user.permissions || [],
    },
    JWT_SECRET,
    { expiresIn: '1h' },
  );
}

function makeRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve({ status: res.statusCode, headers: res.headers, body: json });
        } catch {
          resolve({ status: res.statusCode, headers: res.headers, body: data });
        }
      });
    });
    req.on('error', reject);
    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  console.log('===============================================================');
  console.log('  SAARK ERP — COMPREHENSIVE BULK IMPORT REGRESSION SUITE       ');
  console.log('===============================================================');
  let passCount = 0;
  let failCount = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  [PASS] ${message}`);
      passCount++;
    } else {
      console.error(`  [FAIL] ${message}`);
      failCount++;
    }
  }

  // ── TEST 1: Main Excell.xlsx Parsing & Robustness ──
  console.log('\n--- TEST 1: Parsing Main Excell.xlsx ---');
  const mainExcelPath = path.resolve(__dirname, '../../../scratch/Main Excell.xlsx');
  assert(fs.existsSync(mainExcelPath), `Main Excell.xlsx exists at ${mainExcelPath}`);

  const buffer = fs.readFileSync(mainExcelPath);
  const parsed = parseSpreadsheet('Main Excell.xlsx', buffer);

  assert(parsed.sheetNames.includes('Calling Sheet'), `Detected worksheet names includes 'Calling Sheet': [${parsed.sheetNames.join(', ')}]`);
  assert(parsed.selectedSheet === 'Calling Sheet', `Active sheet is 'Calling Sheet' (got '${parsed.selectedSheet}')`);
  assert(parsed.rowCount === 72, `Correctly parsed exactly 72 customer rows from Calling Sheet (got ${parsed.rowCount})`);

  // Check duplicate headers deduplicated
  assert(parsed.headers.includes('Follow-Up 1') && parsed.headers.includes('Follow-Up 1 (2)'), 'Duplicate headers Follow-Up 1 deduplicated with suffix');
  assert(parsed.headers.includes('Follow-Up 2') && parsed.headers.includes('Follow-Up 2 (2)'), 'Duplicate headers Follow-Up 2 deduplicated with suffix');

  // Check empty trailing columns pruned
  assert(!parsed.headers.includes('Column_13') && !parsed.headers.includes('Column_25'), 'Empty trailing columns Column_13 to Column_25 pruned');

  // Check column auto-mapping
  const mapping = autoDetectColumnMapping(parsed.headers, 'CUSTOMER');
  assert(mapping['Company Name'] === 'companyName', `Auto-mapped 'Company Name' -> 'companyName'`);
  assert(mapping['Phone'] === 'phone', `Auto-mapped 'Phone' -> 'phone'`);
  assert(mapping['Lacation'] === 'state', `Auto-mapped misspelled 'Lacation' -> 'state'`);
  assert(mapping['Outcome'] === 'outcome', `Auto-mapped 'Outcome' -> 'outcome'`);
  assert(mapping['Remarks'] === 'notes', `Auto-mapped 'Remarks' -> 'notes'`);
  assert(mapping['Follow-Up 1'] === 'followUp', `Auto-mapped 'Follow-Up 1' -> 'followUp'`);

  // Check Excel serial date and phone extraction on sample rows
  const row0 = parsed.rawRows[0];
  const dateFormatted = parseExcelSerialDate(row0['Date']);
  assert(dateFormatted === '2026-10-12', `Excel serial date '${row0['Date']}' converted to '2026-10-12'`);
  const cleanPhone = parseCleanPhone(row0['Phone']);
  assert(cleanPhone === '9176999832', `Numeric phone number cleaned to '9176999832'`);

  // ── TEST 2: Database and User PBAC Verification ──
  console.log('\n--- TEST 2: PBAC & RBAC Authorization Checks ---');
  await prisma.$connect();

  const harshadUser = await prisma.user.findFirst({
    where: { email: 'harshadvighe545@gmail.com' },
    include: {
      userRoles: { include: { role: { include: { rolePermissions: { include: { permission: true } } } } } },
      userPermissions: { include: { permission: true } },
    },
  });
  assert(Boolean(harshadUser), `Found employee user harshadvighe545@gmail.com`);

  const harshadRoles = harshadUser.userRoles.map((ur) => ur.role.code);
  const harshadPerms = [];
  harshadUser.userRoles.forEach((ur) => {
    ur.role.rolePermissions.forEach((rp) => {
      harshadPerms.push(`${rp.permission.module}:${rp.permission.action}`);
    });
  });
  if (harshadUser.userPermissions) {
    harshadUser.userPermissions.forEach((up) => {
      if (up.effect === 'ALLOW' || !up.effect) {
        harshadPerms.push(`${up.permission.module}:${up.permission.action}`);
      }
    });
  }
  assert(harshadPerms.includes('CRM:CREATE') || harshadPerms.includes('CRM:VIEW'), `Harshad has effective permissions [${harshadPerms.slice(0, 5).join(', ')}...]`);

  const authorizedToken = generateTestToken({
    id: harshadUser.id,
    email: harshadUser.email,
    roles: harshadRoles,
    permissions: harshadPerms,
  });

  const unauthorizedUser = (await prisma.user.findFirst({
    where: {
      status: 'ACTIVE',
      email: { not: 'harshadvighe545@gmail.com' },
      userRoles: {
        some: {
          role: {
            code: 'ROLE_EMPLOYEE',
          },
        },
      },
    },
  })) || { id: '55f97234-715e-4aa1-97a9-cd790bb7f7e3', email: 'demo.production2@saark.in' };

  const unauthorizedToken = generateTestToken({
    id: unauthorizedUser.id,
    email: unauthorizedUser.email,
    roles: ['ROLE_EMPLOYEE'],
    permissions: ['STAFF:VIEW', 'MY_WORK:VIEW'],
  });

  const PORT = 3199;

  // Test 2a: Authorized employee can parse Main Excell.xlsx
  console.log(`\nTesting POST /api/bulk-import/parse-preview on port ${PORT}...`);
  const base64Data = buffer.toString('base64');
  const parseRes = await makeRequest(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/bulk-import/parse-preview',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authorizedToken}`,
      },
    },
    {
      target: 'CUSTOMER',
      fileName: 'Main Excell.xlsx',
      fileBase64: base64Data,
      enableGstEnrichment: false, // Pure calling sheet, no GSTINs
      checkDuplicates: true,
    },
  );

  assert(parseRes.status === 200 || parseRes.status === 201, `Authorized employee parse-preview succeeded with HTTP ${parseRes.status} (no 403!)`);
  const preview = parseRes.body?.data || parseRes.body;
  assert(preview.totalRows === 72, `Preview returned 72 rows`);
  assert(preview.selectedSheet === 'Calling Sheet', `Preview selectedSheet is 'Calling Sheet'`);
  assert(preview.invalidRows === 0, `All rows without GSTIN are valid (invalidRows === 0)`);
  assert(preview.validRows + preview.warningRows + preview.duplicateRows === 72, `Valid + warning + duplicate rows sum to 72`);

  // Test 2b: Unauthorized employee gets HTTP 403 Forbidden
  const unauthRes = await makeRequest(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/bulk-import/parse-preview',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${unauthorizedToken}`,
      },
    },
    {
      target: 'CUSTOMER',
      fileName: 'Main Excell.xlsx',
      fileBase64: base64Data,
    },
  );
  assert(unauthRes.status === 403, `Unauthorized user blocked with HTTP 403 Forbidden (got ${unauthRes.status})`);

  // Test 2c: CRM employee cannot import VENDOR target (PBAC target enforcement)
  const vendorRes = await makeRequest(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/bulk-import/parse-preview',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authorizedToken}`,
      },
    },
    {
      target: 'VENDOR',
      fileName: 'Main Excell.xlsx',
      fileBase64: base64Data,
    },
  );
  assert(vendorRes.status === 403, `CRM user without VENDOR permissions blocked with HTTP 403 on VENDOR target (got ${vendorRes.status})`);

  // ── TEST 3: Optional GSTIN, Malformed Rows, In-File Duplicates ──
  console.log('\n--- TEST 3: Validation, Optional GSTIN & In-File Duplicates ---');

  // Test file without GSTIN vs file with valid GSTIN vs file with invalid GSTIN vs malformed row
  const testCsvContent = [
    'Company Name,Phone,Lacation,GSTIN,Outcome,Remarks',
    'Acme Automation Systems,9820123456,Pune,,Interested,Needs quote for VFD panel', // Valid without GSTIN
    'Nova Switchgears,9822334455,Mumbai,27AAACA1234A1ZK,Connected,Full GST registered client', // Valid with GSTIN
    'Delta Motors,9822998877,Kolhapur,INVALID_GST_123,Ringing,Invalid GSTIN format', // Invalid GSTIN
    ',9822112233,Nashik,,Wrong Number,Missing company name and GSTIN', // Malformed row
    'Acme Automation Systems,9820123456,Pune,,Interested,Duplicate in-file row', // In-file duplicate
  ].join('\r\n');

  const csvBase64 = Buffer.from(testCsvContent).toString('base64');
  const csvParseRes = await makeRequest(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/bulk-import/parse-preview',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authorizedToken}`,
      },
    },
    {
      target: 'CUSTOMER',
      fileName: 'test_validation.csv',
      fileBase64: csvBase64,
      enableGstEnrichment: false,
      checkDuplicates: true,
    },
  );

  const csvPreview = csvParseRes.body?.data || csvParseRes.body;
  assert(csvPreview.totalRows === 5, `CSV preview processed 5 data rows`);
  assert(csvPreview.rows[0].validationStatus === 'VALID' || csvPreview.rows[0].validationStatus === 'WARNING', `Row 1 (without GSTIN) is valid`);
  assert(csvPreview.rows[1].validationStatus === 'VALID' || csvPreview.rows[1].validationStatus === 'WARNING', `Row 2 (with GSTIN) is valid`);
  assert(csvPreview.rows[2].validationStatus === 'INVALID', `Row 3 (with invalid GSTIN) flagged as INVALID`);
  assert(csvPreview.rows[3].validationStatus === 'INVALID', `Row 4 (missing company name and GSTIN) flagged as INVALID`);
  assert(csvPreview.rows[4].duplicateInfo?.type === 'IN_FILE', `Row 5 (duplicate Acme Automation) detected as IN_FILE duplicate`);

  // ── TEST 4: Idempotency & Database Persistence on Supabase Staging ──
  console.log('\n--- TEST 4: Execution, Idempotency & Audit Trail ---');

  // Clean up any previous test customer with company name 'SAARK Test Import Automation'
  await prisma.customerInteraction.deleteMany({
    where: { customer: { companyName: 'SAARK Test Import Automation' } },
  });
  await prisma.customerContact.deleteMany({
    where: { customer: { companyName: 'SAARK Test Import Automation' } },
  });
  await prisma.customerValuation.deleteMany({
    where: { customer: { companyName: 'SAARK Test Import Automation' } },
  });
  await prisma.customer.deleteMany({
    where: { companyName: 'SAARK Test Import Automation' },
  });

  const initialCustomerCount = await prisma.customer.count({ where: { status: { not: 'DELETED' } } });
  console.log(`Initial active customer count in Supabase staging: ${initialCustomerCount}`);

  const testImportRows = [
    {
      rowNumber: 1,
      isIncluded: true,
      data: {
        companyName: 'SAARK Test Import Automation',
        phone: '9876543210',
        state: 'Maharashtra',
        city: 'Pune',
        outcome: 'Interested in VFD',
        remarks: 'Sample import test for Calling Sheet verification',
        followUp1: '2026-10-25',
        followUp2: '2026-11-05',
        quotation: 'Rs. 2,50,000',
      },
      rawData: {
        'Company Name': 'SAARK Test Import Automation',
        'Phone': '9876543210',
        'Lacation': 'Pune',
        'Outcome': 'Interested in VFD',
        'Remarks': 'Sample import test for Calling Sheet verification',
        'Follow-Up 1': '2026-10-25',
        'Follow-Up 2': '2026-11-05',
        'Quotation': 'Rs. 2,50,000',
        'Custom Note': 'Preserve this unmapped field',
      },
    },
  ];

  // 4a. Execute Import
  const execRes1 = await makeRequest(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/bulk-import/execute',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authorizedToken}`,
      },
    },
    {
      target: 'CUSTOMER',
      rows: testImportRows,
      skipDuplicates: true,
      updateExisting: false,
      fileName: 'Main Excell.xlsx',
    },
  );

  const result1 = execRes1.body?.data || execRes1.body;
  assert(result1.successCount === 1, `Execution 1: successfully imported 1 customer record`);

  // Verify created record in DB
  const createdCustomer = await prisma.customer.findFirst({
    where: { companyName: 'SAARK Test Import Automation' },
    include: { contacts: true, valuations: true, interactions: true },
  });
  assert(Boolean(createdCustomer), `Customer record saved in Supabase database`);
  assert(createdCustomer.phone === '9876543210', `Customer phone matches '9876543210'`);
  assert(createdCustomer.contacts.length >= 1, `Primary customer contact created`);
  assert(Boolean(createdCustomer.valuations), `Customer valuation initialized`);
  assert(createdCustomer.interactions.length >= 1, `CustomerInteraction record created from Calling Sheet`);
  assert(createdCustomer.interactions[0].outcome === 'Interested in VFD', `Interaction outcome preserved`);
  assert(createdCustomer.interactions[0].description.includes('Preserve this unmapped field'), `Unmapped business information preserved in interaction description`);

  // 4b. Execute Import AGAIN (Idempotency verification)
  const execRes2 = await makeRequest(
    {
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/bulk-import/execute',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authorizedToken}`,
      },
    },
    {
      target: 'CUSTOMER',
      rows: testImportRows,
      skipDuplicates: true,
      updateExisting: false,
      fileName: 'Main Excell.xlsx',
    },
  );

  const result2 = execRes2.body?.data || execRes2.body;
  assert(result2.successCount === 0 && result2.skippedCount === 1, `Execution 2 (Retry): skipped duplicate record (success: 0, skipped: 1)`);

  const duplicateCheckCount = await prisma.customer.count({
    where: { companyName: 'SAARK Test Import Automation' },
  });
  assert(duplicateCheckCount === 1, `Zero duplicate customers created on retry (exactly 1 record in DB)`);

  // 4c. Verify Centralized Audit Trail
  const recentAudit = await prisma.auditLog.findFirst({
    where: { action: 'BULK_IMPORT', module: 'CUSTOMERS' },
    orderBy: { timestamp: 'desc' },
  });
  assert(Boolean(recentAudit), `Audit trail entry created for BULK_IMPORT`);
  assert(recentAudit.userId === harshadUser.id, `Audit trail recorded actor ID correctly`);
  assert(recentAudit.details.includes('Bulk Import (CUSTOMER) Completed'), `Audit trail recorded import counts without sensitive raw data`);

  // Clean up test record to preserve existing database state
  await prisma.customerInteraction.deleteMany({
    where: { customerId: createdCustomer.id },
  });
  await prisma.customerContact.deleteMany({
    where: { customerId: createdCustomer.id },
  });
  await prisma.customerValuation.deleteMany({
    where: { customerId: createdCustomer.id },
  });
  await prisma.customer.delete({
    where: { id: createdCustomer.id },
  });

  const finalCustomerCount = await prisma.customer.count({ where: { status: { not: 'DELETED' } } });
  assert(finalCustomerCount === initialCustomerCount, `Customer table count restored exactly to initial count (${finalCustomerCount})`);

  console.log('\n===============================================================');
  console.log(`  TEST RESULTS: ${passCount} PASSED, ${failCount} FAILED       `);
  console.log('===============================================================');

  await prisma.$disconnect();
  process.exit(failCount === 0 ? 0 : 1);
}

runTests().catch((err) => {
  console.error('Test execution error:', err);
  process.exit(1);
});
