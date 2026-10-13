const path = require('path');
const fs = require('fs');
const http = require('http');

// 1. Strict loading of apps/backend/.env.staging
const stagingEnvPath = path.resolve(__dirname, '../.env.staging');
if (!fs.existsSync(stagingEnvPath)) {
  console.error('FATAL: .env.staging not found:', stagingEnvPath);
  process.exit(1);
}

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

const TEST_PORT = 3299;
process.env.PORT = String(TEST_PORT);
process.env.DATABASE_PROVIDER = 'supabase';
process.env.STORAGE_PROVIDER = 'supabase';

// 2. Load and wrap isolated PostgreSQL Staging Client
const { PrismaClient: StagingPrismaClient } = require(
  path.resolve(__dirname, '../node_modules/@prisma/client-staging'),
);

let sharedClient = null;
class SingletonStagingPrismaService extends StagingPrismaClient {
  constructor() {
    if (sharedClient) return sharedClient;
    super();
    sharedClient = this;
  }
  async onModuleInit() {
    if (!this._connected) {
      await this.$connect();
      this._connected = true;
    }
  }
  async onModuleDestroy() {
    if (this._connected) {
      await this.$disconnect();
      this._connected = false;
    }
  }
}

// Intercept PrismaService across all NestJS modules
const prismaServiceModule = require(
  path.resolve(__dirname, '../dist/src/core/database/prisma.service'),
);
prismaServiceModule.PrismaService = SingletonStagingPrismaService;

const { NestFactory } = require(path.resolve(__dirname, '../node_modules/@nestjs/core'));
const { AppModule } = require(path.resolve(__dirname, '../dist/src/app.module'));
const { JwtService } = require(path.resolve(__dirname, '../node_modules/@nestjs/jwt'));

function httpRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        let parsed = null;
        try {
          parsed = JSON.parse(data);
        } catch {
          parsed = data;
        }
        resolve({ statusCode: res.statusCode, headers: res.headers, body: parsed });
      });
    });
    req.on('error', reject);
    if (body) {
      if (Buffer.isBuffer(body)) {
        req.write(body);
      } else {
        req.write(typeof body === 'string' ? body : JSON.stringify(body));
      }
    }
    req.end();
  });
}

function sendMultipartRequest(options, fields = {}, file = null) {
  const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);
  const crlf = '\r\n';
  const parts = [];

  for (const [key, value] of Object.entries(fields)) {
    parts.push(
      Buffer.from(
        `--${boundary}${crlf}Content-Disposition: form-data; name="${key}"${crlf}${crlf}${value}${crlf}`,
      ),
    );
  }

  if (file) {
    const fileHeader = `--${boundary}${crlf}Content-Disposition: form-data; name="${file.name}"; filename="${file.filename}"${crlf}Content-Type: ${file.contentType}${crlf}${crlf}`;
    const fileFooter = crlf;
    const fileContent = Buffer.isBuffer(file.content) ? file.content : Buffer.from(file.content);
    parts.push(Buffer.from(fileHeader));
    parts.push(fileContent);
    parts.push(Buffer.from(fileFooter));
  }

  parts.push(Buffer.from(`--${boundary}--${crlf}`));
  const payload = Buffer.concat(parts);

  const mergedHeaders = {
    ...options.headers,
    'Content-Type': `multipart/form-data; boundary=${boundary}`,
    'Content-Length': payload.length,
  };

  return httpRequest({ ...options, headers: mergedHeaders }, payload);
}

async function runSuite() {
  console.log('================================================================');
  console.log('   PHASE 15 CRM & SALES SECURITY REGRESSION TEST SUITE          ');
  console.log('================================================================');
  console.log('[Target Port]:', TEST_PORT);
  console.log('[Database]:    Supabase PostgreSQL Staging');

  const app = await NestFactory.create(AppModule, { logger: false });
  app.enableCors({ origin: true, credentials: true });
  await app.listen(TEST_PORT);
  console.log('[Status]: NestJS test instance listening on port', TEST_PORT);

  const prisma = app.get(SingletonStagingPrismaService);
  const jwtService = app.get(JwtService);

  // 1. Retrieve test actors
  const adminUser = await prisma.user.findFirst({
    where: { username: 'admin' },
    include: { staff: true, userRoles: { include: { role: true } } },
  });
  const amitSalesUser = await prisma.user.findFirst({
    where: { username: 'amit.sales' },
    include: { staff: true, userRoles: { include: { role: true } } },
  });
  const employeeBUser = await prisma.user.findFirst({
    where: { username: 'demo.sales2' },
    include: { staff: true, userRoles: { include: { role: true } } },
  });
  const unmappedUser = await prisma.user.findFirst({
    where: { username: 'salesexec' },
    include: { staff: true, userRoles: { include: { role: true } } },
  });

  // Mint authentic JWTs
  const adminToken = jwtService.sign({
    sub: adminUser.id,
    email: adminUser.email,
    username: adminUser.username,
  });
  const employeeAToken = jwtService.sign({
    sub: amitSalesUser.id,
    email: amitSalesUser.email,
    username: amitSalesUser.username,
  });
  const employeeBToken = jwtService.sign({
    sub: employeeBUser.id,
    email: employeeBUser.email,
    username: employeeBUser.username,
  });
  const unmappedToken = jwtService.sign({
    sub: unmappedUser.id,
    email: unmappedUser.email,
    username: unmappedUser.username,
  });

  const baseUrl = { hostname: '127.0.0.1', port: TEST_PORT };
  let passed = 0;
  let failed = 0;

  function assert(name, condition, details = '') {
    if (condition) {
      console.log(`  [PASS] ${name}`);
      passed++;
    } else {
      console.error(`  [FAIL] ${name} ${details}`);
      failed++;
    }
  }

  // 2. Setup isolated test fixtures
  console.log('\n[Setup]: Creating isolated test fixtures for Phase 15 regression testing...');
  const testSuffix = Date.now().toString().slice(-6);

  // Customer A (Assigned to Employee A)
  const custA = await prisma.customer.create({
    data: {
      customerCode: `CUST-P15-A-${testSuffix}`,
      companyName: `TEST_P15_CustA_${testSuffix}`,
      assignedStaffId: amitSalesUser.staff.id,
      createdByUserId: amitSalesUser.id,
      contactPerson: 'Contact A',
      phone: '9800000001',
      email: `test_a_${testSuffix}@example.com`,
      address: 'Plot 101, MIDC',
      city: 'Pune',
      district: 'Pune',
      state: 'Maharashtra',
      pincode: '411001',
      status: 'ACTIVE',
    },
  });

  // Customer B (Assigned to Employee B)
  const custB = await prisma.customer.create({
    data: {
      customerCode: `CUST-P15-B-${testSuffix}`,
      companyName: `TEST_P15_CustB_${testSuffix}`,
      assignedStaffId: employeeBUser.staff.id,
      createdByUserId: employeeBUser.id,
      contactPerson: 'Contact B',
      phone: '9800000002',
      email: `test_b_${testSuffix}@example.com`,
      address: 'Plot 202, MIDC',
      city: 'Mumbai',
      district: 'Mumbai',
      state: 'Maharashtra',
      pincode: '400001',
      status: 'ACTIVE',
    },
  });

  // Opportunity A (Employee A)
  const oppA = await prisma.opportunity.create({
    data: {
      opportunityNumber: `OPP-P15-A-${testSuffix}`,
      title: `Opportunity A ${testSuffix}`,
      customerId: custA.id,
      assignedStaffId: amitSalesUser.staff.id,
      stage: 'QUALIFICATION',
      estimatedValue: 150000,
      probability: 50,
    },
  });

  // Opportunity B (Employee B)
  const oppB = await prisma.opportunity.create({
    data: {
      opportunityNumber: `OPP-P15-B-${testSuffix}`,
      title: `Opportunity B ${testSuffix}`,
      customerId: custB.id,
      assignedStaffId: employeeBUser.staff.id,
      stage: 'QUALIFICATION',
      estimatedValue: 250000,
      probability: 60,
    },
  });

  // Quotation A (Employee A)
  const quoteA = await prisma.quotation.create({
    data: {
      quotationNumber: `QUO-P15-A-${testSuffix}`,
      code: `QUO-P15-A-${testSuffix}-REV-0`,
      subject: `Quotation A ${testSuffix}`,
      customerId: custA.id,
      opportunityId: oppA.id,
      assignedStaffId: amitSalesUser.staff.id,
      subtotal: 100000,
      taxableAmount: 100000,
      grandTotal: 118000,
      status: 'DRAFT',
    },
  });

  // Quotation B (Employee B)
  const quoteB = await prisma.quotation.create({
    data: {
      quotationNumber: `QUO-P15-B-${testSuffix}`,
      code: `QUO-P15-B-${testSuffix}-REV-0`,
      subject: `Quotation B ${testSuffix}`,
      customerId: custB.id,
      opportunityId: oppB.id,
      assignedStaffId: employeeBUser.staff.id,
      subtotal: 200000,
      taxableAmount: 200000,
      grandTotal: 236000,
      status: 'DRAFT',
    },
  });

  // Follow-up B (Employee B)
  const followUpB = await prisma.crmFollowUp.create({
    data: {
      followUpNumber: 1,
      title: `Follow-up B ${testSuffix}`,
      customerId: custB.id,
      opportunityId: oppB.id,
      assignedStaffId: employeeBUser.staff.id,
      scheduledDate: new Date(Date.now() + 86400000 * 2),
      status: 'PENDING',
      priority: 'HIGH',
    },
  });

  // Document B (Employee B)
  const docB = await prisma.documentItem.create({
    data: {
      documentCode: `DOC-P15-B-${testSuffix}`,
      name: `spec_b_${testSuffix}.pdf`,
      fileName: `spec_b_${testSuffix}.pdf`,
      entityType: 'Customer',
      entityId: custB.id,
      documentType: 'SPECIFICATION',
      fileSize: 1024,
      mimeType: 'application/pdf',
      storagePath: `documents/customer/${custB.id}/spec_b_${testSuffix}.pdf`,
      uploadedBy: employeeBUser.fullName,
    },
  });

  console.log('[Setup Complete]: Fixtures initialized successfully.');

  try {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. OPPORTUNITY RECORD-LEVEL AUTHORIZATION & ISOLATION
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 1. OPPORTUNITY RECORD-LEVEL AUTHORIZATION & ISOLATION ---');

    // T1: Employee A listing opportunities only sees assigned opportunities
    {
      const res = await httpRequest({
        ...baseUrl,
        path: '/api/v1/crm/opportunities',
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      const items = Array.isArray(res.body) ? res.body : (res.body?.data || []);
      const containsOppB = items.some((o) => o.id === oppB.id);
      assert(
        'T1: Employee A opportunity list is scoped and does not contain Employee B opportunity',
        res.statusCode === 200 && !containsOppB,
        `Contains Opp B: ${containsOppB}, items count: ${items.length}`,
      );
    }

    // T2: Employee A cannot read Employee B's opportunity
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/crm/opportunities/${oppB.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T2: Employee A cannot read Employee B opportunity (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T3: Employee A cannot modify Employee B's opportunity
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/crm/opportunities/${oppB.id}`,
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        { estimatedValue: 999999 },
      );
      assert(
        'T3: Employee A cannot modify Employee B opportunity (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T4: Employee A can read their own opportunity
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/crm/opportunities/${oppA.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T4: Employee A can read their own opportunity (Expect 200 OK)',
        res.statusCode === 200 && res.body?.id === oppA.id,
        `Got status: ${res.statusCode}`,
      );
    }

    // T5: Employee A can update their own opportunity
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/crm/opportunities/${oppA.id}`,
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        { stage: 'PROPOSAL' },
      );
      assert(
        'T5: Employee A can update their own opportunity (Expect 200 OK)',
        res.statusCode === 200 && res.body?.stage === 'PROPOSAL',
        `Got status: ${res.statusCode}`,
      );
    }

    // T6: Employee A cannot create opportunity for unauthorized company
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: '/api/v1/crm/opportunities',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        {
          title: 'Unauthorized Opp Creation',
          customerId: custB.id,
          stage: 'PROPOSAL',
        },
      );
      assert(
        'T6: Employee A cannot create opportunity for unauthorized company (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T7: Admin can view Employee B's opportunity
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/crm/opportunities/${oppB.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      assert(
        'T7: Admin has organization-wide opportunity visibility (Expect 200 OK)',
        res.statusCode === 200 && res.body?.id === oppB.id,
        `Got status: ${res.statusCode}`,
      );
    }

    // T8: Unmapped employee fails closed on opportunities query
    {
      const res = await httpRequest({
        ...baseUrl,
        path: '/api/v1/crm/opportunities',
        method: 'GET',
        headers: { Authorization: `Bearer ${unmappedToken}` },
      });
      const items = Array.isArray(res.body) ? res.body : (res.body?.data || []);
      assert(
        'T8: Unmapped employee fails closed on opportunities list (Expect empty array)',
        res.statusCode === 200 && items.length === 0,
        `Got status: ${res.statusCode}, items: ${items.length}`,
      );
    }

    // T9: Unmapped employee fails closed on single opportunity detail
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/crm/opportunities/${oppA.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${unmappedToken}` },
      });
      assert(
        'T9: Unmapped employee fails closed on single opportunity detail (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. QUOTATION GENERATION, VIEWING, EDITING & APPROVAL
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 2. QUOTATION GENERATION, VIEWING, EDITING & APPROVAL ---');

    // T10: Employee A quotation list excludes Employee B's quotation
    {
      const res = await httpRequest({
        ...baseUrl,
        path: '/api/v1/sales/quotations',
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      const items = Array.isArray(res.body) ? res.body : (res.body?.data || []);
      const containsQuoteB = items.some((q) => q.id === quoteB.id);
      assert(
        'T10: Employee A quotation list is scoped and does not contain Employee B quotation',
        res.statusCode === 200 && !containsQuoteB,
        `Contains Quote B: ${containsQuoteB}, items count: ${items.length}`,
      );
    }

    // T11: Employee A cannot view Employee B's quotation
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/sales/quotations/${quoteB.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T11: Employee A cannot view Employee B quotation (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T12: Employee A cannot create quotation for Employee B's customer
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: '/api/v1/sales/quotations',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        {
          customerId: custB.id,
          opportunityId: oppB.id,
          items: [{ itemType: 'PANEL', description: 'Unauthorized Panel', quantity: 1, unitRate: 50000 }],
        },
      );
      assert(
        'T12: Employee A cannot generate quotation for unauthorized customer (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T13: Employee A cannot revise Employee B's quotation
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/sales/quotations/${quoteB.id}/revisions`,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        { notes: 'Unauthorized revision' },
      );
      assert(
        'T13: Employee A cannot revise Employee B quotation (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T14: Employee A cannot update status / approve Employee B's quotation
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/sales/quotations/${quoteB.id}/status`,
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        { status: 'ACCEPTED', notes: 'Unauthorized approval' },
      );
      assert(
        'T14: Employee A cannot approve or update status of Employee B quotation (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T15: Employee A cannot convert Employee B's quotation to sales order
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/sales/quotations/${quoteB.id}/convert-to-order`,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        {},
      );
      assert(
        'T15: Employee A cannot convert Employee B quotation to sales order (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T16: Employee A can view their own quotation
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/sales/quotations/${quoteA.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T16: Employee A can view their own quotation (Expect 200 OK)',
        res.statusCode === 200 && res.body?.id === quoteA.id,
        `Got status: ${res.statusCode}`,
      );
    }

    // T17: Admin has organization-wide quotation visibility
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/sales/quotations/${quoteB.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      assert(
        'T17: Admin has organization-wide quotation visibility (Expect 200 OK)',
        res.statusCode === 200 && res.body?.id === quoteB.id,
        `Got status: ${res.statusCode}`,
      );
    }

    // T18: Unmapped employee fails closed on quotations list
    {
      const res = await httpRequest({
        ...baseUrl,
        path: '/api/v1/sales/quotations',
        method: 'GET',
        headers: { Authorization: `Bearer ${unmappedToken}` },
      });
      const items = Array.isArray(res.body) ? res.body : (res.body?.data || []);
      assert(
        'T18: Unmapped employee fails closed on quotations list (Expect empty array)',
        res.statusCode === 200 && items.length === 0,
        `Got status: ${res.statusCode}, count: ${items.length}`,
      );
    }

    // T19: Unmapped employee fails closed on quotation detail
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/sales/quotations/${quoteA.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${unmappedToken}` },
      });
      assert(
        'T19: Unmapped employee fails closed on quotation detail (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. FOLLOW-UP OWNERSHIP & RESCHEDULING VALIDATION
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 3. FOLLOW-UP OWNERSHIP & RESCHEDULING VALIDATION ---');

    // T20: Employee A cannot create follow-up for Employee B's customer
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: '/api/v1/crm/follow-ups',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        {
          customerId: custB.id,
          activityType: 'CALL',
          mode: 'SCHEDULE',
          scheduledDate: new Date(Date.now() + 86400000 * 3).toISOString(),
          discussion: 'Unauthorized follow-up attempt',
        },
      );
      assert(
        'T20: Employee A cannot create follow-up for Employee B customer (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T21: Employee A cannot create follow-up reassigning to another employee
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: '/api/v1/crm/follow-ups',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        {
          customerId: custA.id,
          assignedStaffId: employeeBUser.staff.id,
          activityType: 'CALL',
          mode: 'SCHEDULE',
          scheduledDate: new Date(Date.now() + 86400000 * 3).toISOString(),
        },
      );
      assert(
        'T21: Employee A cannot assign follow-up to Employee B (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T22: Employee A cannot complete Employee B's follow-up
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/crm/follow-ups/${followUpB.id}/complete`,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        { discussion: 'Unauthorized completion attempt' },
      );
      assert(
        'T22: Employee A cannot complete Employee B follow-up (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T23: Employee A cannot reschedule Employee B's follow-up
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/crm/follow-ups/${followUpB.id}/reschedule`,
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        {
          scheduledDate: new Date(Date.now() + 86400000 * 5).toISOString(),
          reason: 'Unauthorized reschedule attempt',
        },
      );
      assert(
        'T23: Employee A cannot reschedule Employee B follow-up (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T24: Employee A can create follow-up for their own customer
    let followUpAId = null;
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: '/api/v1/crm/follow-ups',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        {
          customerId: custA.id,
          opportunityId: oppA.id,
          activityType: 'CALL',
          mode: 'SCHEDULE',
          scheduledDate: new Date(Date.now() + 86400000 * 2).toISOString(),
          subject: 'Legitimate Customer A Follow-up',
        },
      );
      followUpAId = res.body?.id;
      assert(
        'T24: Employee A can create follow-up for their own customer (Expect 201 Created)',
        res.statusCode === 201 && !!followUpAId,
        `Got status: ${res.statusCode}`,
      );
    }

    // T25: Employee A can reschedule their own follow-up
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/crm/follow-ups/${followUpAId}/reschedule`,
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${employeeAToken}`,
          },
        },
        {
          scheduledDate: new Date(Date.now() + 86400000 * 4).toISOString(),
          reason: 'Customer requested postponing to Friday',
        },
      );
      assert(
        'T25: Employee A can reschedule their own follow-up (Expect 200 OK)',
        res.statusCode === 200 && res.body?.id === followUpAId,
        `Got status: ${res.statusCode}`,
      );
    }

    // T26: Unmapped employee fails closed on follow-up creation
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: '/api/v1/crm/follow-ups',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${unmappedToken}`,
          },
        },
        {
          customerId: custA.id,
          activityType: 'CALL',
          mode: 'SCHEDULE',
          scheduledDate: new Date(Date.now() + 86400000 * 2).toISOString(),
        },
      );
      assert(
        'T26: Unmapped employee fails closed on follow-up creation (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T27: Unmapped employee fails closed on follow-up reschedule
    {
      const res = await httpRequest(
        {
          ...baseUrl,
          path: `/api/v1/crm/follow-ups/${followUpAId}/reschedule`,
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${unmappedToken}`,
          },
        },
        {
          scheduledDate: new Date(Date.now() + 86400000 * 5).toISOString(),
        },
      );
      assert(
        'T27: Unmapped employee fails closed on follow-up reschedule (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. DOCUMENT UPLOAD, DOWNLOAD, REPLACEMENT & DELETION
    // ─────────────────────────────────────────────────────────────────────────
    console.log('\n--- 4. DOCUMENT UPLOAD, DOWNLOAD, REPLACEMENT & DELETION ---');

    // T28: Employee A cannot upload document for Employee B's customer
    {
      const res = await sendMultipartRequest(
        {
          ...baseUrl,
          path: '/api/v1/documents/upload',
          method: 'POST',
          headers: { Authorization: `Bearer ${employeeAToken}` },
        },
        {
          entityType: 'Customer',
          entityId: custB.id,
          documentType: 'ATTACHMENT',
        },
        {
          name: 'file',
          filename: 'unauthorized_upload.txt',
          contentType: 'text/plain',
          content: 'Secret content for B',
        },
      );
      assert(
        'T28: Employee A cannot upload document for Employee B customer (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T29: Employee A cannot view document list for Employee B's customer
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/documents/entity?type=Customer&id=${custB.id}`,
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T29: Employee A cannot list documents of Employee B customer (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T30: Employee A cannot download document attached to Employee B's customer
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/documents/${docB.id}/download`,
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T30: Employee A cannot download document belonging to Employee B record (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T31: Employee A cannot replace document attached to Employee B's customer
    {
      const res = await sendMultipartRequest(
        {
          ...baseUrl,
          path: `/api/v1/documents/${docB.id}/replace`,
          method: 'PUT',
          headers: { Authorization: `Bearer ${employeeAToken}` },
        },
        {},
        {
          name: 'file',
          filename: 'replacement_hack.txt',
          contentType: 'text/plain',
          content: 'Hacked file',
        },
      );
      assert(
        'T31: Employee A cannot replace document belonging to Employee B record (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T32: Employee A cannot delete document attached to Employee B's customer
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/documents/${docB.id}`,
        method: 'DELETE',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T32: Employee A cannot delete document belonging to Employee B record (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T33: Employee A can upload document for their own customer
    let docAId = null;
    {
      const res = await sendMultipartRequest(
        {
          ...baseUrl,
          path: '/api/v1/documents/upload',
          method: 'POST',
          headers: { Authorization: `Bearer ${employeeAToken}` },
        },
        {
          entityType: 'Customer',
          entityId: custA.id,
          documentType: 'ATTACHMENT',
        },
        {
          name: 'file',
          filename: `valid_doc_${testSuffix}.pdf`,
          contentType: 'application/pdf',
          content: '%PDF-1.4 Hello Saark ERP from Employee A',
        },
      );
      docAId = res.body?.id;
      assert(
        'T33: Employee A can upload document for their own customer (Expect 201 Created)',
        res.statusCode === 201 && !!docAId,
        `Got status: ${res.statusCode}`,
      );
    }

    // T34: Employee A can download document for their own customer
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/documents/${docAId}/download`,
        method: 'GET',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T34: Employee A can download document for their own customer (Expect 200 OK)',
        res.statusCode === 200,
        `Got status: ${res.statusCode}`,
      );
    }

    // T35: Employee A can replace document for their own customer
    {
      const res = await sendMultipartRequest(
        {
          ...baseUrl,
          path: `/api/v1/documents/${docAId}/replace`,
          method: 'PUT',
          headers: { Authorization: `Bearer ${employeeAToken}` },
        },
        {},
        {
          name: 'file',
          filename: `updated_doc_${testSuffix}.pdf`,
          contentType: 'application/pdf',
          content: '%PDF-1.4 Updated content for Employee A',
        },
      );
      assert(
        'T35: Employee A can replace document for their own customer (Expect 200 OK)',
        res.statusCode === 200 && res.body?.id === docAId,
        `Got status: ${res.statusCode}`,
      );
    }

    // T36: Employee A can delete document for their own customer
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/documents/${docAId}`,
        method: 'DELETE',
        headers: { Authorization: `Bearer ${employeeAToken}` },
      });
      assert(
        'T36: Employee A can delete document for their own customer (Expect 200 OK)',
        res.statusCode === 200 && res.body?.id === docAId,
        `Got status: ${res.statusCode}`,
      );
    }

    // T37: Admin can view and download Employee B's document
    {
      const res = await httpRequest({
        ...baseUrl,
        path: `/api/v1/documents/${docB.id}/download`,
        method: 'GET',
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      // Storage mock/download might return 200 (or 500 if storage path not physically uploaded in fixture)
      // Key verification is auth check passes without 403 Forbidden
      assert(
        'T37: Admin has organization-wide document access (Not 403 Forbidden)',
        res.statusCode !== 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T38: Unmapped employee fails closed on document upload
    {
      const res = await sendMultipartRequest(
        {
          ...baseUrl,
          path: '/api/v1/documents/upload',
          method: 'POST',
          headers: { Authorization: `Bearer ${unmappedToken}` },
        },
        {
          entityType: 'Customer',
          entityId: custA.id,
          documentType: 'ATTACHMENT',
        },
        {
          name: 'file',
          filename: 'unmapped_upload.txt',
          contentType: 'text/plain',
          content: 'Unmapped payload',
        },
      );
      assert(
        'T38: Unmapped employee fails closed on document upload (Expect 403 Forbidden)',
        res.statusCode === 403,
        `Got status: ${res.statusCode}`,
      );
    }

    // T39: Unmapped employee fails closed on global document repository query
    {
      const res = await httpRequest({
        ...baseUrl,
        path: '/api/v1/documents',
        method: 'GET',
        headers: { Authorization: `Bearer ${unmappedToken}` },
      });
      const items = Array.isArray(res.body) ? res.body : [];
      assert(
        'T39: Unmapped employee receives empty list from global documents endpoint (Expect 200 with 0 items)',
        res.statusCode === 200 && items.length === 0,
        `Got status: ${res.statusCode}, count: ${items.length}`,
      );
    }
  } finally {
    // 5. Clean up test fixtures (preserving all original records)
    console.log('\n[Teardown]: Cleaning up test fixtures created for Phase 15...');
    try {
      if (docB?.id) await prisma.documentItem.deleteMany({ where: { id: docB.id } });
      if (followUpB?.id) await prisma.crmFollowUp.deleteMany({ where: { id: followUpB.id } });
      await prisma.crmFollowUp.deleteMany({ where: { customerId: custA.id } });
      if (quoteA?.id) await prisma.quotation.deleteMany({ where: { id: quoteA.id } });
      if (quoteB?.id) await prisma.quotation.deleteMany({ where: { id: quoteB.id } });
      if (oppA?.id) await prisma.opportunity.deleteMany({ where: { id: oppA.id } });
      if (oppB?.id) await prisma.opportunity.deleteMany({ where: { id: oppB.id } });
      if (custA?.id) await prisma.customer.deleteMany({ where: { id: custA.id } });
      if (custB?.id) await prisma.customer.deleteMany({ where: { id: custB.id } });
      console.log('[Teardown Complete]: Staging database restored to exact baseline.');
    } catch (cleanErr) {
      console.warn('[Teardown Warning]: Error during fixture cleanup:', cleanErr.message);
    }
  }

  console.log('\n================================================================');
  console.log(`SUMMARY: ${passed} PASSED, ${failed} FAILED (TOTAL: ${passed + failed})`);
  console.log('================================================================');

  await app.close();
  console.log('[Status]: NestJS test instance stopped.');
  if (failed > 0) {
    console.error(`[Result]: ${failed} test(s) failed in Phase 15 security verification.`);
    process.exit(1);
  } else {
    console.log('[Result]: All Phase 15 security verification tests completed successfully.');
    process.exit(0);
  }
}

runSuite().catch((err) => {
  console.error('FATAL TEST SUITE ERROR:', err);
  process.exit(1);
});
