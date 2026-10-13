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
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function runSuite() {
  console.log('================================================================');
  console.log('   PHASE 14 SECURITY VERIFICATION SUITE (STAGING POSTGRESQL)    ');
  console.log('================================================================');
  console.log('[Target Port]:', TEST_PORT);
  console.log('[Database]:    Supabase PostgreSQL Staging');

  const app = await NestFactory.create(AppModule, { logger: false });
  app.enableCors({ origin: true, credentials: true });
  await app.listen(TEST_PORT);
  console.log('[Status]: NestJS test instance listening on port', TEST_PORT);

  const prisma = app.get(SingletonStagingPrismaService);
  const jwtService = app.get(JwtService);

  // Retrieve test actors
  const adminUser = await prisma.user.findFirst({
    where: { username: 'admin' },
    include: { staff: true, userRoles: { include: { role: true } } },
  });
  const amitSalesUser = await prisma.user.findFirst({
    where: { username: 'amit.sales' },
    include: { staff: true, userRoles: { include: { role: true } } },
  });
  const unmappedUser = await prisma.user.findFirst({
    where: { username: 'salesexec' },
    include: { staff: true, userRoles: { include: { role: true } } },
  });
  const adminRole = await prisma.role.findFirst({ where: { code: 'ROLE_ADMIN' } });

  // Records for testing isolation
  const leadA = await prisma.lead.findFirst({
    where: { assignedStaffId: amitSalesUser.staff.id },
  });
  const leadAdmin = await prisma.lead.findFirst({
    where: { assignedStaffId: adminUser.staff.id },
  });
  const companyAdmin = await prisma.customer.findFirst({
    where: { assignedStaffId: adminUser.staff.id },
  });
  const enquiryA = await prisma.enquiry.findFirst({
    where: { assignedStaffId: amitSalesUser.staff.id },
  });
  const enquiryAdmin = await prisma.enquiry.findFirst({
    where: { assignedStaffId: adminUser.staff.id },
  });
  const meetingAdmin = await prisma.crmMeeting.findFirst({
    where: { hostStaffId: adminUser.staff.id },
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

  console.log('\n--- TASK A: ADMIN PRIVILEGE ESCALATION NEGATIVE & POSITIVE TESTS ---');

  // T1: Non-admin self-promotion
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/admin/users/${amitSalesUser.id}`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { roleIds: [adminRole.id] },
    );
    assert(
      'T1: Non-admin cannot assign ROLE_ADMIN to self (Expect 403)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T2: Non-admin promoting another user to admin
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/admin/users/${unmappedUser.id}`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { roleIds: [adminRole.id] },
    );
    assert(
      'T2: Non-admin cannot promote other user to ROLE_ADMIN (Expect 403)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T3: Non-admin creating user with admin role
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: '/api/v1/admin/users',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      {
        username: 'malicious.admin',
        email: 'malicious@test.com',
        password: 'Password123!',
        fullName: 'Malicious Admin',
        roleIds: [adminRole.id],
      },
    );
    assert(
      'T3: Non-admin cannot create new user with ROLE_ADMIN (Expect 403)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T4: Non-admin modifying existing admin account
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/admin/users/${adminUser.id}`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { fullName: 'Compromised Admin' },
    );
    assert(
      'T4: Non-admin cannot modify existing admin account (Expect 403)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T5: Non-admin toggling admin user status
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/admin/users/${adminUser.id}/toggle-status`,
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
    );
    assert(
      'T5: Non-admin cannot toggle admin account active/inactive (Expect 403)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T6: Non-admin creating admin role
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: '/api/v1/admin/roles',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { name: 'Fake Admin', code: 'ROLE_ADMIN' },
    );
    assert(
      'T6: Non-admin cannot create role with code ROLE_ADMIN (Expect 403)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T7: Non-admin updating admin role permissions
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/admin/roles/${adminRole.id}/permissions`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { permissionIds: [] },
    );
    assert(
      'T7: Non-admin cannot modify permissions on administrator role (Expect 403)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T8: Unauthenticated request to admin endpoint
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/admin/users',
      method: 'GET',
    });
    assert(
      'T8: Unauthenticated access to /api/v1/admin/users denied (Expect 401)',
      res.statusCode === 401,
      `Got status: ${res.statusCode}`,
    );
  }

  // T9: Legitimate admin listing users
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/admin/users',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(
      'T9: Legitimate admin user can list users (Expect 200 with user list)',
      res.statusCode === 200 && Array.isArray(res.body),
      `Got status: ${res.statusCode}`,
    );
  }

  // T10: Legitimate admin listing roles
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/admin/roles',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(
      'T10: Legitimate admin user can list roles (Expect 200 with role list)',
      res.statusCode === 200 && Array.isArray(res.body),
      `Got status: ${res.statusCode}`,
    );
  }

  console.log('\n--- TASK B: CRM RECORD-LEVEL AUTHORIZATION & ISOLATION TESTS ---');

  // T11: Unmapped employee leads query fail closed
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/crm/leads',
      method: 'GET',
      headers: { Authorization: `Bearer ${unmappedToken}` },
    });
    const isEmpty = res.statusCode === 200 && res.body?.data && res.body.data.length === 0;
    assert(
      'T11: Unmapped employee fails closed on leads query (Expect 200 with data: [])',
      isEmpty,
      `Got count: ${res.body?.data?.length}, status: ${res.statusCode}`,
    );
  }

  // T12: Unmapped employee companies query fail closed
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/crm/companies',
      method: 'GET',
      headers: { Authorization: `Bearer ${unmappedToken}` },
    });
    const isEmpty = res.statusCode === 200 && res.body?.data && res.body.data.length === 0;
    assert(
      'T12: Unmapped employee fails closed on companies query (Expect 200 with data: [])',
      isEmpty,
      `Got count: ${res.body?.data?.length}, status: ${res.statusCode}`,
    );
  }

  // T13: Unmapped employee enquiries query fail closed
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/crm/enquiries',
      method: 'GET',
      headers: { Authorization: `Bearer ${unmappedToken}` },
    });
    const isEmpty = res.statusCode === 200 && res.body?.data && res.body.data.length === 0;
    assert(
      'T13: Unmapped employee fails closed on enquiries query (Expect 200 with data: [])',
      isEmpty,
      `Got count: ${res.body?.data?.length}, status: ${res.statusCode}`,
    );
  }

  // T14: Unmapped employee meetings query fail closed
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/crm/meetings',
      method: 'GET',
      headers: { Authorization: `Bearer ${unmappedToken}` },
    });
    const isEmpty = res.statusCode === 200 && res.body?.items && res.body.items.length === 0;
    assert(
      'T14: Unmapped employee fails closed on meetings query (Expect 200 with items: [])',
      isEmpty,
      `Got count: ${res.body?.items?.length}, status: ${res.statusCode}`,
    );
  }

  // T15: Unmapped employee single lead access fail closed
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/leads/${leadAdmin.id}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${unmappedToken}` },
    });
    assert(
      'T15: Unmapped employee fails closed on single lead detail (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T16: Employee A leads query scoped strictly to Employee A
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/crm/leads',
      method: 'GET',
      headers: { Authorization: `Bearer ${employeeAToken}` },
    });
    const leads = res.body?.data || [];
    const allAssignedToAmit = leads.every(
      (l) => l.assignedStaff?.id === amitSalesUser.staff.id,
    );
    assert(
      'T16: Employee A leads list is strictly scoped to Employee A assignment',
      res.statusCode === 200 && leads.length > 0 && allAssignedToAmit,
      `Count: ${leads.length}, allAssignedToAmit: ${allAssignedToAmit}`,
    );
  }

  // T17: Employee A cross-record access denial (Lead)
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/leads/${leadAdmin.id}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${employeeAToken}` },
    });
    assert(
      'T17: Employee A cannot access Admin-assigned lead (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T18: Employee A cross-record modification denial (Lead)
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/crm/leads/${leadAdmin.id}`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { remarks: 'Unauthorized modification' },
    );
    assert(
      'T18: Employee A cannot modify Admin-assigned lead (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T19: Employee A cross-record access denial (Company 360)
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/companies/${companyAdmin.id}/360`,
      method: 'GET',
      headers: { Authorization: `Bearer ${employeeAToken}` },
    });
    assert(
      'T19: Employee A cannot access Company 360 for unassigned company (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T20: Employee A cross-record timeline denial (Company Timeline)
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/companies/${companyAdmin.id}/timeline`,
      method: 'GET',
      headers: { Authorization: `Bearer ${employeeAToken}` },
    });
    assert(
      'T20: Employee A cannot access Company Timeline for unassigned company (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T21: Employee A cross-record modification denial (Company)
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/crm/companies/${companyAdmin.id}`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { contactPerson: 'Hacked Contact' },
    );
    assert(
      'T21: Employee A cannot update unassigned company master (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T22: Employee A cross-record access denial (Enquiry)
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/enquiries/${enquiryAdmin.id}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${employeeAToken}` },
    });
    assert(
      'T22: Employee A cannot view Enquiry assigned to Admin (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T23: Employee A cross-record modification denial (Enquiry)
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/crm/enquiries/${enquiryAdmin.id}`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { remarks: 'Unauthorized update' },
    );
    assert(
      'T23: Employee A cannot update Enquiry assigned to Admin (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T24: Employee A cross-record meeting response denial
  {
    const res = await httpRequest(
      {
        ...baseUrl,
        path: `/api/v1/crm/meetings/${meetingAdmin.id}/respond`,
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${employeeAToken}`,
        },
      },
      { action: 'ACCEPT' },
    );
    assert(
      'T24: Employee A cannot respond to Meeting hosted by Admin (Expect 403 Forbidden)',
      res.statusCode === 403,
      `Got status: ${res.statusCode}`,
    );
  }

  // T25: Employee A legitimate access to assigned lead
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/leads/${leadA.id}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${employeeAToken}` },
    });
    assert(
      'T25: Employee A can view their own assigned lead (Expect 200 OK)',
      res.statusCode === 200 && res.body?.id === leadA.id,
      `Got status: ${res.statusCode}`,
    );
  }

  // T26: Employee A legitimate access to assigned enquiry
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/enquiries/${enquiryA.id}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${employeeAToken}` },
    });
    assert(
      'T26: Employee A can view their own assigned enquiry (Expect 200 OK)',
      res.statusCode === 200 && res.body?.id === enquiryA.id,
      `Got status: ${res.statusCode}`,
    );
  }

  // T27: Admin organization-wide lead visibility
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/crm/leads',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const leads = res.body?.data || [];
    assert(
      'T27: Admin has organization-wide lead visibility (Expect 200 with all leads)',
      res.statusCode === 200 && leads.length > 1,
      `Count: ${leads.length}`,
    );
  }

  // T28: Admin single record access across staff
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/leads/${leadA.id}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(
      'T28: Admin can view Lead assigned to Employee A (Expect 200 OK)',
      res.statusCode === 200 && res.body?.id === leadA.id,
      `Got status: ${res.statusCode}`,
    );
  }

  // T29: Admin Company 360 access across staff
  {
    const res = await httpRequest({
      ...baseUrl,
      path: `/api/v1/crm/companies/${companyAdmin.id}/360`,
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(
      'T29: Admin can view Company 360 profile (Expect 200 OK)',
      res.statusCode === 200 && res.body?.id === companyAdmin.id,
      `Got status: ${res.statusCode}`,
    );
  }

  // T30: Global search employee isolation
  {
    const res = await httpRequest({
      ...baseUrl,
      path: '/api/v1/crm/search?q=saark',
      method: 'GET',
      headers: { Authorization: `Bearer ${unmappedToken}` },
    });
    const isEmpty =
      res.statusCode === 200 &&
      (res.body?.leads || []).length === 0 &&
      (res.body?.companies || []).length === 0 &&
      (res.body?.enquiries || []).length === 0;
    assert(
      'T30: Global search fails closed for unmapped employee (Expect 0 records across entities)',
      isEmpty,
      `Got leads: ${(res.body?.leads || []).length}, companies: ${(res.body?.companies || []).length}`,
    );
  }

  console.log('\n================================================================');
  console.log(`SUMMARY: ${passed} PASSED, ${failed} FAILED (TOTAL: ${passed + failed})`);
  console.log('================================================================');

  await app.close();
  console.log('[Status]: NestJS test instance stopped.');

  if (failed > 0) {
    process.exit(1);
  }
}

runSuite()
  .then(() => {
    console.log('[Result]: All Phase 14 security verification tests completed successfully.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Fatal test error:', err);
    process.exit(1);
  });
