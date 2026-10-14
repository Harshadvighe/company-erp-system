const http = require('http');

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
  console.log('SAARK ERP — LIVE HTTP API END-TO-END VERIFICATION: EMPLOYEE ACCESS');
  console.log('========================================================================\n');

  try {
    // ─── 1. Admin Login ───────────────────────────────────────────────────────
    console.log('1. Admin Authentication & Access Listing:');
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
    assert(Boolean(adminToken), 'Admin received valid JWT accessToken');

    // ─── 2. GET /admin/employees/access ───────────────────────────────────────
    const listRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/employees/access?page=1&limit=10',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });

    assert(listRes.status === 200, 'GET /admin/employees/access returns HTTP 200');
    const employees = listRes.body.data?.employees || listRes.body.employees || listRes.body.data;
    assert(Array.isArray(employees), 'Employee directory list returned');
    assert(employees.length > 0, `Employees returned in listing (count: ${employees?.length})`);

    // Find test user Rahul PM
    const rahulSearchRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/employees/access?search=rahul',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const rahulEmployees = rahulSearchRes.body.data?.employees || rahulSearchRes.body.employees || rahulSearchRes.body.data;
    const targetEmp = rahulEmployees[0];
    const targetEmployeeId = targetEmp.id;
    console.log(`   Selected target employee: ${targetEmp.fullName || targetEmp.firstName} (${targetEmp.id})`);

    // ─── 3. GET /admin/employees/:id/access ───────────────────────────────────
    console.log('\n2. Detail Matrix Endpoint Verification:');
    const detailRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/admin/employees/${targetEmployeeId}/access`,
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });

    assert(detailRes.status === 200, 'GET /admin/employees/:id/access returns HTTP 200');
    const detail = detailRes.body.data || detailRes.body;
    assert(Boolean(detail.modules || detail.modulesMap), 'Matrix contains module groups');
    const permList = detail.modules || Object.values(detail.modulesMap || {});
    assert(permList.length > 0, 'Module permissions mapped accurately');

    // Find permission IDs for test:
    // 1. ORGANIZATION:VIEW (not possessed by PM by default)
    // 2. PROJECTS:CREATE (possessed by PM by default)
    let orgViewPermId = null;
    let projCreatePermId = null;

    if (Array.isArray(detail.modules)) {
      for (const m of detail.modules) {
        for (const p of m.permissions) {
          if (p.module === 'ORGANIZATION' && p.action === 'VIEW') orgViewPermId = p.id || p.permissionId;
          if (p.module === 'PROJECTS' && p.action === 'CREATE') projCreatePermId = p.id || p.permissionId;
        }
      }
    } else if (detail.modulesMap) {
      for (const modName of Object.keys(detail.modulesMap)) {
        for (const p of detail.modulesMap[modName]) {
          if (p.module === 'ORGANIZATION' && p.action === 'VIEW') orgViewPermId = p.permissionId || p.id;
          if (p.module === 'PROJECTS' && p.action === 'CREATE') projCreatePermId = p.permissionId || p.id;
        }
      }
    }

    assert(Boolean(orgViewPermId), `Found ORGANIZATION:VIEW permission ID: ${orgViewPermId}`);
    assert(Boolean(projCreatePermId), `Found PROJECTS:CREATE permission ID: ${projCreatePermId}`);

    // ─── 4. Rahul PM Authentication ──────────────────────────────────────────
    console.log('\n3. Employee Dynamic Permission Overrides & Next-Request Reflection:');
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
    assert(Boolean(rahulToken), 'Rahul PM received JWT accessToken');

    // Step A: Initially, Rahul tries to access /api/v1/admin/company -> should return 403 Forbidden
    const checkBeforeAllow = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/company',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(checkBeforeAllow.status === 403, 'Employee without permission is blocked from /api/v1/admin/company (HTTP 403)');

    // Step B: Admin grants ALLOW override for ORGANIZATION:VIEW to Rahul
    const applyAllowRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/admin/employees/${targetEmployeeId}/access`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
      },
      {
        overrides: [{ permissionId: orgViewPermId, effect: 'ALLOW', reason: 'Live E2E test grant' }],
        reason: 'Live E2E test grant',
      }
    );
    assert(applyAllowRes.status === 200, 'Admin successfully saved custom ALLOW override (HTTP 200)');

    // Step C: Rahul repeats the EXACT SAME request with the SAME token -> now returns HTTP 200!
    const checkAfterAllow = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/company',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(checkAfterAllow.status === 200, 'Custom ALLOW took effect on next request with existing token (HTTP 200)');

    // Step D: Admin applies explicit DENY on PROJECTS:CREATE
    const applyDenyRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/admin/employees/${targetEmployeeId}/access`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
      },
      {
        overrides: [
          { permissionId: orgViewPermId, effect: 'ALLOW' },
          { permissionId: projCreatePermId, effect: 'DENY', reason: 'Live E2E test deny' },
        ],
        reason: 'Live E2E test deny',
      }
    );
    assert(applyDenyRes.status === 200, 'Admin successfully saved explicit DENY override (HTTP 200)');

    // Step E: Rahul attempts to create a project -> blocked with HTTP 403 Forbidden!
    const checkAfterDeny = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: '/api/v1/projects',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${rahulToken}`,
        },
      },
      { name: 'Blocked Project', code: 'PRJ-BLOCKED' }
    );
    assert(checkAfterDeny.status === 403, 'Explicit DENY override revoked role permission immediately on next request (HTTP 403)');

    // Step F: Admin reverts overrides back to INHERIT
    const applyInheritRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/admin/employees/${targetEmployeeId}/access`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${adminToken}`,
        },
      },
      {
        overrides: [
          { permissionId: orgViewPermId, effect: 'INHERIT' },
          { permissionId: projCreatePermId, effect: 'INHERIT' },
        ],
        reason: 'Live E2E test reset to inherit',
      }
    );
    assert(applyInheritRes.status === 200, 'Admin reverted overrides to INHERIT (HTTP 200)');

    // Step G: Rahul tries /admin/company -> blocked with 403 again!
    const checkAfterInherit = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/admin/company',
      method: 'GET',
      headers: { Authorization: `Bearer ${rahulToken}` },
    });
    assert(checkAfterInherit.status === 403, 'Reverting to INHERIT removed ALLOW; /admin/company returns HTTP 403 again');

    // ─── 5. Non-admin privilege escalation test ───────────────────────────────
    console.log('\n4. Privilege Escalation & Unauthorized Access Tests:');
    const nonAdminUpdateAttempt = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: `/api/v1/admin/employees/${targetEmployeeId}/access`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${rahulToken}`,
        },
      },
      {
        overrides: [{ permissionId: orgViewPermId, effect: 'ALLOW' }],
        reason: 'Illegal self-grant attempt',
      }
    );
    assert(nonAdminUpdateAttempt.status === 403, 'Non-admin user blocked from modifying employee permissions (HTTP 403)');

    // ─── 6. Existing CRM & HR verification ────────────────────────────────────
    console.log('\n5. Existing CRM and HR Functionality Verification:');
    const hrLoginRes = await request(
      {
        hostname: 'localhost',
        port: 3000,
        path: '/api/v1/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      { emailOrUsername: 'hr.manager', password: 'Saark@2026' }
    );
    const hrToken = extractToken(hrLoginRes.body);

    const hrDashboardRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/hr/dashboard',
      method: 'GET',
      headers: { Authorization: `Bearer ${hrToken}` },
    });
    assert(hrDashboardRes.status === 200, 'HR Manager accesses /api/v1/hr/dashboard successfully (HTTP 200)');

    const crmDashboardRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/crm/dashboard',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(crmDashboardRes.status === 200, 'Admin accesses /api/v1/crm/dashboard successfully (HTTP 200)');

    const customersRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/customers',
      method: 'GET',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(customersRes.status === 200, 'Admin accesses /api/v1/customers successfully (HTTP 200)');

    console.log('\n========================================================================');
    console.log(`LIVE HTTP API TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
    console.log('========================================================================\n');

    if (failed > 0) {
      process.exit(1);
    }
  } catch (err) {
    console.error('Fatal test error:', err);
    process.exit(1);
  }
}

run();
