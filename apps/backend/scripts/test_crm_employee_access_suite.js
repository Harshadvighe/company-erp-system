const http = require('http');
const path = require('path');
const fs = require('fs');

// Load environment for direct database checks
const env = {};
const stagingEnvPath = path.resolve(__dirname, '../.env.staging');
fs.readFileSync(stagingEnvPath, 'utf8')
  .split(/\r?\n/)
  .forEach((l) => {
    const p = l.split('=');
    if (p.length >= 2) env[p[0].trim()] = p.slice(1).join('=').trim().replace(/^['"]|['"]$/g, '');
  });
process.env.DATABASE_URL = env.DATABASE_URL;

const { PrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client-staging'));
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

const PORT = 3199;

async function run() {
  console.log('========================================================================');
  console.log('SAARK ERP — CRM CUSTOMER DIRECTORY EMPLOYEE ACCESS REGRESSION SUITE');
  console.log('========================================================================\n');

  let testCustomerId = null;
  let crmViewPerm = null;
  let harshadUser = null;

  try {
    // ─── SECTION 1: VERIFY DATABASE PERSISTENCE & EFFECTIVE PERMISSIONS ──────
    console.log('1. Database Permission Resolution & User State:');

    harshadUser = await prisma.user.findFirst({
      where: { email: 'harshadvighe545@gmail.com' },
      include: {
        userRoles: { include: { role: true } },
        userPermissions: { include: { permission: true } },
      },
    });

    assert(Boolean(harshadUser), 'Harshad Ashok Vighe user record exists in Supabase PostgreSQL');
    const roles = harshadUser.userRoles.map((ur) => ur.role.code);
    assert(roles.includes('ROLE_EMPLOYEE'), `User has employee role (Roles: [${roles.join(', ')}])`);

    const crmPerms = harshadUser.userPermissions
      .filter((up) => up.permission?.module === 'CRM')
      .map((up) => `${up.permission.action} (${up.effect})`);
    console.log(`   Harshad CRM Permissions: [${crmPerms.join(', ')}]`);
    assert(crmPerms.some((p) => p.startsWith('VIEW')), 'Harshad has CRM:VIEW override in user_permissions');
    assert(crmPerms.some((p) => p.startsWith('CREATE')), 'Harshad has CRM:CREATE override in user_permissions');
    assert(crmPerms.some((p) => p.startsWith('EDIT')), 'Harshad has CRM:EDIT override in user_permissions');
    assert(crmPerms.some((p) => p.startsWith('DELETE')), 'Harshad has CRM:DELETE override in user_permissions');
    assert(crmPerms.some((p) => p.startsWith('EXPORT')), 'Harshad has CRM:EXPORT override in user_permissions');

    const hasCustomersModulePerm = harshadUser.userPermissions.some((up) => up.permission?.module === 'CUSTOMERS');
    assert(!hasCustomersModulePerm, 'Harshad does NOT have CUSTOMERS module overrides (confirming reproduction scenario)');

    crmViewPerm = await prisma.permission.findFirst({
      where: { module: 'CRM', action: 'VIEW' },
    });
    assert(Boolean(crmViewPerm), 'Permission record for CRM:VIEW exists');

    // ─── SECTION 2: AUTHENTICATION AS HARSHAD ─────────────────────────────────
    console.log('\n2. Employee Authentication (Harshad Vighe):');
    const harshadLoginRes = await request(
      {
        hostname: 'localhost',
        port: PORT,
        path: '/api/v1/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      { emailOrUsername: 'harshadvighe', password: 'Saark@2026' }
    );

    assert(harshadLoginRes.status === 200 || harshadLoginRes.status === 201, 'Harshad authentication succeeded');
    const harshadToken = extractToken(harshadLoginRes.body);
    assert(Boolean(harshadToken), 'Received valid JWT access token for Harshad');

    // ─── SECTION 3: CUSTOMER DIRECTORY LISTING & FILTER OPTIONS ──────────────
    console.log('\n3. Customer Directory Access (Fixing 403 Root Cause):');

    const customersListRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers?page=1&limit=10',
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });

    assert(
      customersListRes.status === 200,
      'GET /api/v1/customers returns HTTP 200 OK (no 403 Forbidden)',
      `Status: ${customersListRes.status}, Body: ${JSON.stringify(customersListRes.body)}`
    );
    const customersData = customersListRes.body.data?.data || customersListRes.body.data?.customers || (Array.isArray(customersListRes.body.data) ? customersListRes.body.data : []);
    assert(Array.isArray(customersData), 'Customer list returned as array');

    const filterOptionsRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers/filter-options',
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });

    assert(
      filterOptionsRes.status === 200,
      'GET /api/v1/customers/filter-options returns HTTP 200 OK',
      `Status: ${filterOptionsRes.status}`
    );

    // ─── SECTION 4: SEARCH, FILTERS, PAGINATION, EXPORT ───────────────────────
    console.log('\n4. Search, Filters, Pagination, and Export:');

    const searchRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers?search=test&page=1&limit=5',
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });
    assert(searchRes.status === 200, 'Search query with pagination returns HTTP 200');

    const stateFilterRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers?state=Maharashtra&page=1&limit=5',
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });
    assert(stateFilterRes.status === 200, 'State filter query returns HTTP 200');

    const exportRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers/export',
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });
    assert(exportRes.status === 200, 'GET /api/v1/customers/export with CRM:EXPORT returns HTTP 200');
    assert(
      exportRes.headers['content-type']?.includes('text/csv'),
      'Customer export returns CSV content type'
    );

    const dupCheckRes = await request(
      {
        hostname: 'localhost',
        port: PORT,
        path: '/api/v1/customers/check-duplicate',
        method: 'POST',
        headers: {
          Authorization: `Bearer ${harshadToken}`,
          'Content-Type': 'application/json',
        },
      },
      { phone: '9999999999', email: 'test@example.com' }
    );
    assert(dupCheckRes.status === 200 || dupCheckRes.status === 201, 'POST /customers/check-duplicate returns HTTP 200/201');

    // ─── SECTION 5: CUSTOMER CRUD (VIEW, CREATE, EDIT, DELETE) ────────────────
    console.log('\n5. Granular Customer CRUD Lifecycle:');

    const createRes = await request(
      {
        hostname: 'localhost',
        port: PORT,
        path: '/api/v1/customers',
        method: 'POST',
        headers: {
          Authorization: `Bearer ${harshadToken}`,
          'Content-Type': 'application/json',
        },
      },
      {
        companyName: `Regression Customer ${Date.now()}`,
        contactPerson: 'Harshad Test Contact',
        phone: `91${Math.floor(10000000 + Math.random() * 90000000)}`,
        email: `reg_test_${Date.now()}@example.com`,
        customerType: 'END_CUSTOMER',
        address: '123 Industrial Area',
        city: 'Pune',
        state: 'Maharashtra',
        district: 'Pune',
        pincode: '411001',
        country: 'India',
      }
    );

    assert(
      createRes.status === 200 || createRes.status === 201,
      'POST /api/v1/customers with CRM:CREATE returns HTTP 201/200 Created',
      `Status: ${createRes.status}, Body: ${JSON.stringify(createRes.body)}`
    );
    const createdCust = createRes.body.data || createRes.body;
    testCustomerId = createdCust.id;
    assert(Boolean(testCustomerId), `New customer created with ID: ${testCustomerId}`);

    const detailRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: `/api/v1/customers/${testCustomerId}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });
    assert(detailRes.status === 200, 'GET /api/v1/customers/:id with CRM:VIEW returns HTTP 200');

    const timelineRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: `/api/v1/customers/${testCustomerId}/timeline`,
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });
    assert(timelineRes.status === 200, 'GET /api/v1/customers/:id/timeline with CRM:VIEW returns HTTP 200');

    const updateRes = await request(
      {
        hostname: 'localhost',
        port: PORT,
        path: `/api/v1/customers/${testCustomerId}`,
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${harshadToken}`,
          'Content-Type': 'application/json',
        },
      },
      {
        companyName: `Updated Customer ${Date.now()}`,
        turnover: '50-100 Cr',
      }
    );
    assert(updateRes.status === 200, 'PUT /api/v1/customers/:id with CRM:EDIT returns HTTP 200');

    const addContactRes = await request(
      {
        hostname: 'localhost',
        port: PORT,
        path: `/api/v1/customers/${testCustomerId}/contacts`,
        method: 'POST',
        headers: {
          Authorization: `Bearer ${harshadToken}`,
          'Content-Type': 'application/json',
        },
      },
      {
        name: 'Secondary Contact Person',
        mobile: '9888877777',
        phone: '9888877777',
        email: 'secondary@example.com',
        isPrimary: false,
      }
    );
    assert(
      addContactRes.status === 200 || addContactRes.status === 201,
      'POST /api/v1/customers/:id/contacts with CRM:CREATE returns HTTP 200/201',
      `Got status: ${addContactRes.status}, body: ${JSON.stringify(addContactRes.body)}`
    );
    const contactData = addContactRes.body.data || addContactRes.body;
    const contactId = contactData?.id;

    if (contactId) {
      const deleteContactRes = await request({
        hostname: 'localhost',
        port: PORT,
        path: `/api/v1/customers/${testCustomerId}/contacts/${contactId}`,
        method: 'DELETE',
        headers: { Authorization: `Bearer ${harshadToken}` },
      });
      assert(deleteContactRes.status === 200, 'DELETE /customers/:id/contacts/:contactId with CRM:DELETE returns HTTP 200');
    }

    const recordInteractionRes = await request(
      {
        hostname: 'localhost',
        port: PORT,
        path: `/api/v1/customers/${testCustomerId}/interactions`,
        method: 'POST',
        headers: {
          Authorization: `Bearer ${harshadToken}`,
          'Content-Type': 'application/json',
        },
      },
      {
        interactionType: 'CALL',
        subject: 'Introductory phone call discussing panel automation requirements',
        description: 'Discussed technical specifications and lead times',
      }
    );
    assert(
      recordInteractionRes.status === 200 || recordInteractionRes.status === 201,
      'POST /customers/:id/interactions with CRM:CREATE returns HTTP 200/201',
      `Got status: ${recordInteractionRes.status}, body: ${JSON.stringify(recordInteractionRes.body)}`
    );

    const deleteCustomerRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: `/api/v1/customers/${testCustomerId}`,
      method: 'DELETE',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });
    assert(deleteCustomerRes.status === 200, 'DELETE /api/v1/customers/:id with CRM:DELETE returns HTTP 200');

    // ─── SECTION 6: EXPLICIT DENY OVERRIDE ON NEXT REQUEST ────────────────────
    console.log('\n6. Explicit DENY Overrides Inherited & Granted Permissions in Supabase PostgreSQL:');

    // Apply explicit DENY on CRM:VIEW
    await prisma.userPermission.upsert({
      where: {
        userId_permissionId: {
          userId: harshadUser.id,
          permissionId: crmViewPerm.id,
        },
      },
      create: {
        userId: harshadUser.id,
        permissionId: crmViewPerm.id,
        effect: 'DENY',
        reason: 'Security regression test explicit DENY verification',
      },
      update: {
        effect: 'DENY',
        reason: 'Security regression test explicit DENY verification',
      },
    });

    // Immediate next request with same token must fail with 403
    const denyCheckRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers?page=1&limit=5',
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });
    assert(
      denyCheckRes.status === 403,
      'Immediate next request returns HTTP 403 Forbidden when CRM:VIEW has explicit DENY',
      `Got status: ${denyCheckRes.status}`
    );

    // Restore ALLOW
    await prisma.userPermission.upsert({
      where: {
        userId_permissionId: {
          userId: harshadUser.id,
          permissionId: crmViewPerm.id,
        },
      },
      create: {
        userId: harshadUser.id,
        permissionId: crmViewPerm.id,
        effect: 'ALLOW',
      },
      update: {
        effect: 'ALLOW',
      },
    });

    // Immediate next request must succeed with 200
    const allowRestoredRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers?page=1&limit=5',
      method: 'GET',
      headers: { Authorization: `Bearer ${harshadToken}` },
    });
    assert(
      allowRestoredRes.status === 200,
      'Immediate next request returns HTTP 200 OK after restoring ALLOW in Supabase PostgreSQL',
      `Got status: ${allowRestoredRes.status}`
    );

    // ─── SECTION 7: UNAUTHORIZED EMPLOYEE ACCESS BLOCKED ──────────────────────
    console.log('\n7. Unauthorized Employee Access Blocking (No CRM or CUSTOMERS perms):');

    // Find an employee user without CRM or CUSTOMERS overrides
    const unauthorizedUser = await prisma.user.findFirst({
      where: {
        status: 'ACTIVE',
        userRoles: {
          some: { role: { code: 'ROLE_EMPLOYEE' } },
          none: { role: { code: { in: ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN', 'ROLE_CRM_MGR'] } } },
        },
        userPermissions: {
          none: { permission: { module: { in: ['CRM', 'CUSTOMERS'] } } },
        },
      },
    });

    if (unauthorizedUser) {
      console.log(`   Found test unauthorized user: ${unauthorizedUser.username} (${unauthorizedUser.email})`);
      const unauthLoginRes = await request(
        {
          hostname: 'localhost',
          port: PORT,
          path: '/api/v1/auth/login',
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
        },
        { emailOrUsername: unauthorizedUser.username, password: 'Saark@2026' }
      );

      if (unauthLoginRes.status === 200 || unauthLoginRes.status === 201) {
        const unauthToken = extractToken(unauthLoginRes.body);
        const unauthAccessRes = await request({
          hostname: 'localhost',
          port: PORT,
          path: '/api/v1/customers',
          method: 'GET',
          headers: { Authorization: `Bearer ${unauthToken}` },
        });
        assert(unauthAccessRes.status === 403, 'Unauthorized employee blocked with HTTP 403 Forbidden from /customers');

        const unauthExportRes = await request({
          hostname: 'localhost',
          port: PORT,
          path: '/api/v1/customers/export',
          method: 'GET',
          headers: { Authorization: `Bearer ${unauthToken}` },
        });
        assert(unauthExportRes.status === 403, 'Unauthorized employee blocked with HTTP 403 Forbidden from /customers/export');
      } else {
        console.log('   (Unauthorized user password mismatch; skipping login check)');
      }
    } else {
      console.log('   (All employees have overrides; verified via DENY test)');
    }

    // ─── SECTION 8: ADMIN ACCESS REMAINS FULLY FUNCTIONAL ─────────────────────
    console.log('\n8. Administrator & Existing CRM Workflows:');

    const adminLoginRes = await request(
      {
        hostname: 'localhost',
        port: PORT,
        path: '/api/v1/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      { emailOrUsername: 'admin', password: 'Saark@2026' }
    );
    assert(adminLoginRes.status === 200 || adminLoginRes.status === 201, 'Admin login succeeded');
    const adminToken = extractToken(adminLoginRes.body);

    const adminCustRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers?page=1&limit=5',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(adminCustRes.status === 200, 'Admin can list customers (HTTP 200)');

    const adminExportRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/customers/export',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(adminExportRes.status === 200, 'Admin can export customers (HTTP 200)');

    const adminCrmDashRes = await request({
      hostname: 'localhost',
      port: PORT,
      path: '/api/v1/crm/dashboard',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(adminCrmDashRes.status === 200, 'Admin can access CRM dashboard (HTTP 200)');

  } catch (err) {
    console.error('Fatal test error:', err);
    failed++;
  } finally {
    // Ensure Harshad's CRM:VIEW is set to ALLOW
    if (harshadUser && crmViewPerm) {
      try {
        await prisma.userPermission.upsert({
          where: {
            userId_permissionId: {
              userId: harshadUser.id,
              permissionId: crmViewPerm.id,
            },
          },
          create: {
            userId: harshadUser.id,
            permissionId: crmViewPerm.id,
            effect: 'ALLOW',
          },
          update: {
            effect: 'ALLOW',
          },
        });
      } catch (_) {}
    }
    await prisma.$disconnect();
  }

  console.log('\n========================================================================');
  console.log(`CRM EMPLOYEE ACCESS REGRESSION SUITE: ${passed} PASSED, ${failed} FAILED (${passed + failed > 0 ? Math.round((passed / (passed + failed)) * 100) : 0}%)`);
  console.log('========================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

run();
