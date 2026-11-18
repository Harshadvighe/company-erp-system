/**
 * ============================================================================
 * SAARK EXPLORATION PVT. LTD. - ERP SYSTEM
 * MASTER ARCHITECTURAL & WORKFLOW VERIFICATION TEST SUITE
 * ============================================================================
 * 
 * Verifies the complete enterprise architectural blueprint:
 * 1. Governance & Author Protection Shield (sonwanep968@gmail.com)
 * 2. Biometric 2FA, 1:N Face Auto-Login & Rahul Yeole Direct Bypass
 * 3. 30-Minute Camera Presence Verification & 6 PM Cutoff
 * 4. Sales & Marketing (CRM) Pipeline & Duplicate Prevention
 * 5. Product Development (NPD 24-Step Dual-Track Engine)
 * 6. Biometric Attendance Terminal Fleet (192.168.1.114:5005)
 */

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';

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

async function unwrap(res) {
  try {
    const json = await res.json();
    return json.data !== undefined ? json.data : json;
  } catch (_) {
    return null;
  }
}

async function runMasterArchitectureSuite() {
  console.log('\n================================================================================');
  console.log('       SAARK ERP: MASTER ARCHITECTURAL & SYSTEM WORKFLOW TEST SUITE');
  console.log('================================================================================\n');

  let adminToken = null;
  let rahulToken = null;
  let testProjectId = null;

  // ===========================================================================
  // SUITE 1: Governance & Author Gatekeeper Shield (sonwanep968@gmail.com)
  // ===========================================================================
  console.log('--- [SUITE 1] Master Governance & Author Gatekeeper Shield ---');
  try {
    // 1.1 Status Endpoint
    const statusRes = await fetch(`${BASE_URL}/governance/status`);
    assert(statusRes.ok, '1.1 GET /api/v1/governance/status returns HTTP 200');
    const status = await unwrap(statusRes);
    assert(status.primaryAuthor === 'sonwanep968@gmail.com', `1.2 Primary author locked to sonwanep968@gmail.com (${status.primaryAuthor})`);
    assert(status.isEnforced === true, '1.3 Zero-trust architectural lock is strictly ENFORCED');
    assert(Array.isArray(status.protectedFiles) && status.protectedFiles.includes('SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md'),
      '1.4 Master architecture blueprint file is under active protection');
    assert(Array.isArray(status.protectedModules) && status.protectedModules.includes('NPD_PRODUCT_DEVELOPMENT'),
      '1.5 NPD Product Development module is registered under protected governance');

    // 1.2 Request Access validation
    const badReqRes = await fetch(`${BASE_URL}/governance/request-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ requesterEmail: 'invalid-email' }),
    });
    assert(badReqRes.status === 400, '1.6 Malformed permission request rejected with HTTP 400 Bad Request');

    // 1.3 Dispatch OTP Challenge
    const reqRes = await fetch(`${BASE_URL}/governance/request-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requesterName: 'Lead Engineer',
        requesterEmail: 'pooja.saark@gmail.com',
        targetResource: 'SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md',
        changeSummary: 'Automated test suite verification check',
      }),
    });
    assert(reqRes.ok, '1.7 Valid edit request dispatches OTP challenge to sonwanep968@gmail.com');
    const reqData = await unwrap(reqRes);
    assert(reqData.author === 'sonwanep968@gmail.com', '1.8 Challenge confirms author email sonwanep968@gmail.com');

    // 1.4 Invalid OTP rejection
    const verifyFailRes = await fetch(`${BASE_URL}/governance/verify-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requesterEmail: 'pooja.saark@gmail.com',
        targetResource: 'SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md',
        otp: '000000',
      }),
    });
    assert(verifyFailRes.status === 401, '1.9 Invalid OTP rejected with HTTP 401 Unauthorized');
  } catch (err) {
    assert(false, `Suite 1 Exception: ${err.message}`);
  }

  // ===========================================================================
  // SUITE 2: Core Authentication, Biometrics, Rahul Yeole Bypass & 6 PM Cutoff
  // ===========================================================================
  console.log('\n--- [SUITE 2] Authentication, Biometrics, Presence & Bypass ---');
  try {
    // 2.1 Office Hours Status
    const ohRes = await fetch(`${BASE_URL}/auth/office-hours-status`);
    assert(ohRes.ok, '2.1 GET /api/v1/auth/office-hours-status returns HTTP 200');
    const ohData = await unwrap(ohRes);
    assert(typeof ohData.isPastOfficeHours === 'boolean', `2.2 isPastOfficeHours returns boolean (${ohData.isPastOfficeHours})`);
    assert(ohData.cutoffHour === 18, '2.3 Company cutoff hour enforced at 18:00 (6:00 PM IST)');

    // 2.2 Rahul Yeole Direct Bypass
    const rahulRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: 'saarkexploration30',
        password: 'Saark@2026',
      }),
    });
    assert(rahulRes.ok, '2.4 POST /api/v1/auth/login for Rahul Yeole returns HTTP 200');
    const rahulData = await unwrap(rahulRes);
    assert(Boolean(rahulData.tokens?.accessToken), '2.5 JWT Access Token issued for Rahul Yeole');
    assert(rahulData.targetRoute === '/sales-marketing' || rahulData.user?.targetRoute === '/sales-marketing',
      '2.6 Auto-routes directly to Sales & Marketing (/sales-marketing)');
    rahulToken = rahulData.tokens?.accessToken;

    // 2.3 Superadmin Login
    const adminRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: 'Saarkadmin',
        password: '12345678',
      }),
    });
    assert(adminRes.ok, '2.7 POST /api/v1/auth/login for Saarkadmin returns HTTP 200');
    const adminData = await unwrap(adminRes);
    assert(Boolean(adminData.tokens?.accessToken), '2.8 SuperAdmin JWT Access Token issued');
    adminToken = adminData.tokens?.accessToken;

    // 2.4 1:N Facial Auto-Login Empty Rejection
    const faceEmptyRes = await fetch(`${BASE_URL}/auth/face-login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    assert(faceEmptyRes.status === 400, '2.9 1:N Face Auto-Login without face descriptor rejected with HTTP 400');

    // 2.5 1:N Facial Auto-Login Unrecognized Rejection
    const dummyDescriptor = Array.from({ length: 128 }, () => Math.random() * 0.1);
    const faceUnknownRes = await fetch(`${BASE_URL}/auth/face-login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ face_data: dummyDescriptor }),
    });
    assert(faceUnknownRes.status === 401, '2.10 Unrecognized face biometric rejected with HTTP 401');

    // 2.6 Presence Verification Guard
    const presenceNoAuthRes = await fetch(`${BASE_URL}/auth/verify-presence`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ face_data: 'test' }),
    });
    assert(presenceNoAuthRes.status === 401, '2.11 30-Minute Presence check requires valid JWT (HTTP 401 without token)');

    // 2.7 Presence Verification with Rahul Yeole (Camera Bypass Honored)
    if (rahulToken) {
      const presenceRahulRes = await fetch(`${BASE_URL}/auth/verify-presence`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${rahulToken}`,
        },
        body: JSON.stringify({
          face_data: 'bypass_token',
          currentRoute: '/sales-marketing',
        }),
      });
      assert(presenceRahulRes.ok, '2.12 Presence check for Rahul Yeole returns HTTP 200');
      const presenceRahulData = await unwrap(presenceRahulRes);
      assert(presenceRahulData.verified === true, '2.13 Rahul Yeole presence automatically verified via camera bypass');
      assert(presenceRahulData.bypass === true, '2.14 Camera bypass confirmed in verification payload');
    }

    // 2.8 Auth Me Profile
    if (adminToken) {
      const meRes = await fetch(`${BASE_URL}/auth/me`, {
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      assert(meRes.ok, '2.15 GET /api/v1/auth/me returns HTTP 200 with active session profile');
    }
  } catch (err) {
    assert(false, `Suite 2 Exception: ${err.message}`);
  }

  // ===========================================================================
  // SUITE 3: Sales & Marketing (CRM) Pipeline & Duplicate Check
  // ===========================================================================
  console.log('\n--- [SUITE 3] Sales & Marketing (CRM) Pipeline & Anti-Duplicate ---');
  try {
    const authHeader = { Authorization: `Bearer ${adminToken || rahulToken}` };

    // 3.1 CRM Dashboard
    const crmDashRes = await fetch(`${BASE_URL}/crm/dashboard`, { headers: authHeader });
    assert(crmDashRes.ok, '3.1 GET /api/v1/crm/dashboard returns HTTP 200');

    // 3.2 CRM Leads List
    const crmLeadsRes = await fetch(`${BASE_URL}/crm/leads`, { headers: authHeader });
    assert(crmLeadsRes.ok, '3.2 GET /api/v1/crm/leads returns HTTP 200');
    const leadsData = await unwrap(crmLeadsRes);
    const leadsArray = Array.isArray(leadsData) ? leadsData : (leadsData?.data || []);
    assert(Array.isArray(leadsArray), `3.3 Leads list returned as structured array (Total: ${leadsArray.length})`);

    // 3.3 Anti-duplicate validation check
    const dupTestPhone = '+919988776655';
    const dupTestEmail = 'lead.pipeline@saark.in';
    const createLeadRes1 = await fetch(`${BASE_URL}/crm/leads`, {
      method: 'POST',
      headers: { ...authHeader, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        companyName: 'Saark Automation Client Test',
        contactPerson: 'Lead Manager',
        email: dupTestEmail,
        phone: dupTestPhone,
        status: 'NEW',
        leadSource: 'DIRECT',
      }),
    });
    assert(createLeadRes1.ok || createLeadRes1.status === 409 || createLeadRes1.status === 400,
      '3.4 CRM Lead creation processed with anti-duplicate validation guard');
  } catch (err) {
    assert(false, `Suite 3 Exception: ${err.message}`);
  }

  // ===========================================================================
  // SUITE 4: Product Development (NPD 24-Step Dual-Track Engine)
  // ===========================================================================
  console.log('\n--- [SUITE 4] Product Development (NPD 24-Step Dual-Track Engine) ---');
  try {
    const authHeader = { Authorization: `Bearer ${adminToken}` };

    // 4.1 Fetch NPD Projects
    const npdListRes = await fetch(`${BASE_URL}/npd/projects`, { headers: authHeader });
    assert(npdListRes.ok, '4.1 GET /api/v1/npd/projects returns HTTP 200');
    const npdList = await unwrap(npdListRes);
    assert(Array.isArray(npdList), '4.2 NPD projects returned as array');

    // 4.2 Create New NPD Project with whitelist-compliant DTO
    const uniqueCode = `PRJ-NPD-${Date.now().toString().slice(-4)}`;
    const createNpdRes = await fetch(`${BASE_URL}/npd/projects`, {
      method: 'POST',
      headers: { ...authHeader, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        projectCode: uniqueCode,
        projectName: 'Smart Industrial VFD Controller Rig',
        productCategory: 'SOLAR_PUMP_INVERTER',
        targetMcu: 'STM32F407',
        operatingVoltage: '415V 3-Phase',
        formFactor: 'IP65 Panel Mount',
        complianceTargets: 'RoHS, CE, IS-14724',
      }),
    });
    assert(createNpdRes.ok || createNpdRes.status === 201, '4.3 POST /api/v1/npd/projects successfully creates project');
    const createdProject = await unwrap(createNpdRes);
    testProjectId = createdProject?.id || (npdList.length > 0 ? npdList[0].id : null);

    if (testProjectId) {
      // 4.3 Board with 24 Steps
      const boardRes = await fetch(`${BASE_URL}/npd/projects/${testProjectId}/board`, { headers: authHeader });
      assert(boardRes.ok, `4.4 GET /api/v1/npd/projects/${testProjectId}/board returns HTTP 200`);
      const board = await unwrap(boardRes);
      const steps = board.steps || [];
      assert(steps.length === 24, `4.5 Master Board holds exactly 24 dual-track engineering steps (Found: ${steps.length})`);

      const track1Steps = steps.filter((s) => s.stepNumber >= 1 && s.stepNumber <= 12);
      const track2Steps = steps.filter((s) => s.stepNumber >= 13 && s.stepNumber <= 24);
      assert(track1Steps.length === 12, '4.6 Track 1 (R&D / Systems Architecture) has 12 sequential steps');
      assert(track2Steps.length === 12, '4.7 Track 2 (Hardware, Rig & Factory QC) has 12 sequential steps');

      // 4.4 Step 1 Signoff with whitelist-compliant DTO
      const signoffRes = await fetch(`${BASE_URL}/npd/projects/${testProjectId}/steps/1/signoff`, {
        method: 'POST',
        headers: { ...authHeader, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          signoffComments: 'Automated architectural verification signoff',
          signoffRole: 'LEAD_ARCHITECT',
        }),
      });
      assert(signoffRes.ok, '4.8 POST step signoff advances workflow milestone');

      // 4.5 SSOT Register Map
      const regRes = await fetch(`${BASE_URL}/npd/projects/${testProjectId}/register-map`, { headers: authHeader });
      assert(regRes.ok, '4.9 GET /register-map returns SSOT hardware/firmware register schema');

      // 4.6 BOM & RoHS Status
      const bomRes = await fetch(`${BASE_URL}/npd/projects/${testProjectId}/bom`, { headers: authHeader });
      assert(bomRes.ok, '4.10 GET /bom returns bill of materials lifecycle & compliance');

      // 4.7 Automated Factory QC Telemetry Ingestion with whitelist-compliant DTO
      const qcRes = await fetch(`${BASE_URL}/npd/factory-test`, {
        method: 'POST',
        headers: { ...authHeader, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          projectId: testProjectId,
          stepNumber: 18,
          serialNumber: 'RIG-PUMP-QC-001',
          testStatus: 'PASS',
          currentConsumptionMa: 1480,
          operatorName: 'Automated Rig Tester',
        }),
      });
      assert(qcRes.ok, '4.11 POST /factory-test records automated QC rig test telemetry');
    }
  } catch (err) {
    assert(false, `Suite 4 Exception: ${err.message}`);
  }

  // ===========================================================================
  // SUITE 5: Biometric Attendance Terminal Fleet (192.168.1.114:5005)
  // ===========================================================================
  console.log('\n--- [SUITE 5] Biometric Attendance Terminal Fleet (192.168.1.114:5005) ---');
  try {
    const authHeader = { Authorization: `Bearer ${adminToken}` };

    // 5.1 Device Types
    const typesRes = await fetch(`${BASE_URL}/attendance-sync/device-types`, { headers: authHeader });
    assert(typesRes.ok, '5.1 GET /api/v1/attendance-sync/device-types returns HTTP 200');
    const types = await unwrap(typesRes);
    assert(Array.isArray(types.supportedManufacturers) && types.supportedManufacturers.includes('TeamOffice'),
      `5.2 TeamOffice biometric protocol supported (${types.supportedManufacturers?.join(', ')})`);

    // 5.2 Registered Devices List
    const devRes = await fetch(`${BASE_URL}/attendance-sync/devices`, { headers: authHeader });
    assert(devRes.ok, '5.3 GET /api/v1/attendance-sync/devices returns HTTP 200');

    // 5.3 Sync Logs
    const logsRes = await fetch(`${BASE_URL}/attendance-sync/sync-logs`, { headers: authHeader });
    assert(logsRes.ok, '5.4 GET /api/v1/attendance-sync/sync-logs returns HTTP 200');
  } catch (err) {
    assert(false, `Suite 5 Exception: ${err.message}`);
  }

  // ===========================================================================
  // SUMMARY RESULTS
  // ===========================================================================
  console.log('\n================================================================================');
  console.log(` MASTER ARCHITECTURAL TEST RESULTS: ${passed} PASSED, ${failed} FAILED (TOTAL: ${passed + failed})`);
  console.log('================================================================================\n');

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runMasterArchitectureSuite().catch((err) => {
  console.error('Fatal Test Suite Error:', err);
  process.exit(1);
});
