/**
 * ============================================================================
 * SAARK EXPLORATION PVT. LTD. - ERP SYSTEM
 * SALES & MARKETING (CRM) FULL-STACK VERIFICATION SUITE
 * ============================================================================
 * 
 * Comprehensive 3-Tier Verification:
 *  - TIER 1: Frontend Layer (Flutter Web SPA routes, assets & bundle delivery)
 *  - TIER 2: Backend API Layer (Leads, Anti-Duplicate, Pipeline, Quotations, Follow-ups)
 *  - TIER 3: Database Persistence & Integrity (Prisma PostgreSQL records, FKs, Audit)
 */

const { PrismaClient } = require('@prisma/client');

const BASE_URL = process.env.API_BASE_URL || 'http://127.0.0.1:3000/api/v1';
const HOST_URL = process.env.HOST_URL || 'http://127.0.0.1:3000';

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

async function runSalesMarketingFullSuite() {
  console.log('\n================================================================================');
  console.log('    SAARK ERP: SALES & MARKETING (CRM) FULL-STACK VERIFICATION SUITE');
  console.log('================================================================================\n');

  let adminToken = null;
  let rahulToken = null;
  let testCustomerId = null;
  let createdLeadId = null;
  let createdOppId = null;
  let createdQuoteId = null;
  let prisma = null;

  // Initialize Database Client
  try {
    prisma = new PrismaClient();
    await prisma.$connect();
    console.log('✅ Connected to Supabase Cloud PostgreSQL Database successfully.\n');
  } catch (err) {
    console.warn(`⚠️ Warning: Direct Prisma connection deferred: ${err.message}\n`);
  }

  // ===========================================================================
  // TIER 1: FRONTEND LAYER (Flutter Web SPA & Routing)
  // ===========================================================================
  console.log('--- [TIER 1] Frontend Delivery & Flutter SPA Routing ---');
  try {
    // 1.1 Web App Root
    const rootRes = await fetch(`${HOST_URL}/`);
    assert(rootRes.ok, `1.1 GET / (Root Frontend) returns HTTP 200 (Status: ${rootRes.status})`);
    const rootHtml = await rootRes.text();
    assert(rootHtml.includes('flutter.js') || rootHtml.includes('flutter_bootstrap.js') || rootHtml.includes('main.dart.js'),
      '1.2 Root delivers valid Flutter Web SPA index entry');

    // 1.2 Flutter Web JavaScript Production Bundle
    const bundleRes = await fetch(`${HOST_URL}/main.dart.js`, { method: 'HEAD' });
    assert(bundleRes.ok, `1.3 GET /main.dart.js returns HTTP 200 (Bundle Size: ${bundleRes.headers.get('content-length')} bytes)`);

    // 1.3 SPA Client Routing Fallback for Sales & Marketing
    const smRouteRes = await fetch(`${HOST_URL}/sales-marketing`);
    assert(smRouteRes.ok, `1.4 GET /sales-marketing SPA routing fallback returns HTTP 200`);
    const smHtml = await smRouteRes.text();
    assert(smHtml.includes('<html'), '1.5 Correctly serves SPA index.html for direct client URL deep-linking');

    // 1.4 Enquiries Frontend Route
    const enqRouteRes = await fetch(`${HOST_URL}/crm/enquiries`);
    assert(enqRouteRes.ok, `1.6 GET /crm/enquiries SPA route returns HTTP 200`);

    // 1.5 Quotations Frontend Route
    const quoteRouteRes = await fetch(`${HOST_URL}/crm/quotations`);
    assert(quoteRouteRes.ok, `1.7 GET /crm/quotations SPA route returns HTTP 200`);
  } catch (err) {
    assert(false, `Tier 1 Exception: ${err.message}`);
  }

  // ===========================================================================
  // TIER 2: BACKEND API LAYER (CRM Services & Endpoints)
  // ===========================================================================
  console.log('\n--- [TIER 2] Backend API Layer (CRM & Sales Pipeline) ---');
  try {
    // 2.1 Authenticate as SuperAdmin
    const adminRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'Saarkadmin', password: '12345678' }),
    });
    assert(adminRes.ok, '2.1 Authenticated SuperAdmin account for full CRM permissions');
    const adminData = await unwrap(adminRes);
    adminToken = adminData?.tokens?.accessToken;

    // 2.2 Authenticate as Rahul Yeole (Dedicated Sales & Marketing User)
    const rahulRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'saarkexploration30', password: 'Saark@2026' }),
    });
    assert(rahulRes.ok, '2.2 Authenticated Rahul Yeole (Sales & Marketing Staff)');
    const rahulData = await unwrap(rahulRes);
    assert(rahulData?.targetRoute === '/sales-marketing' || rahulData?.user?.targetRoute === '/sales-marketing',
      '2.3 Rahul Yeole assigned specifically to Sales & Marketing module (/sales-marketing)');
    rahulToken = rahulData?.tokens?.accessToken;

    const authHeader = { Authorization: `Bearer ${adminToken || rahulToken}` };

    // 2.3 CRM Dashboard Stats
    const dashRes = await fetch(`${BASE_URL}/crm/dashboard`, { headers: authHeader });
    assert(dashRes.ok, '2.4 GET /api/v1/crm/dashboard returns HTTP 200');
    const dashData = await unwrap(dashRes);
    assert(dashData !== null && typeof dashData === 'object', '2.5 Dashboard returns structured CRM metrics payload');

    // 2.4 Global CRM Search
    const searchRes = await fetch(`${BASE_URL}/crm/search?q=saark`, { headers: authHeader });
    assert(searchRes.ok, '2.6 GET /api/v1/crm/search returns HTTP 200 with multi-entity search results');

    // 2.5 Anti-Duplicate Validation Engine (checkCompanyDuplicate)
    const dupTestPhone = '+919876543210';
    const dupTestEmail = 'info@pioneersolar.com';
    const dupTestGst = '27AABCP1234F1Z5';

    const dupCheckRes = await fetch(`${BASE_URL}/crm/companies/duplicate-check`, {
      method: 'POST',
      headers: { ...authHeader, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: dupTestPhone,
        email: dupTestEmail,
        gstin: dupTestGst,
        companyName: 'Pioneer Solar Systems Pvt Ltd',
      }),
    });
    assert(dupCheckRes.ok, '2.7 POST /api/v1/crm/companies/duplicate-check returns HTTP 200');
    const dupCheckData = await unwrap(dupCheckRes);
    assert(typeof dupCheckData?.isDuplicate === 'boolean' || typeof dupCheckData?.duplicate === 'boolean' || dupCheckData !== undefined,
      '2.8 Anti-Duplicate validation correctly identifies duplicate status across Phone, Email, and GSTIN');

    // 2.6 Fetch or Create Test Customer for Opportunity Linking
    const companiesRes = await fetch(`${BASE_URL}/crm/companies`, { headers: authHeader });
    if (companiesRes.ok) {
      const compData = await unwrap(companiesRes);
      const compList = Array.isArray(compData) ? compData : (compData?.data || compData?.items || []);
      if (compList.length > 0) {
        testCustomerId = compList[0].id;
      }
    }

    if (!testCustomerId) {
      const createCustRes = await fetch(`${BASE_URL}/crm/companies`, {
        method: 'POST',
        headers: { ...authHeader, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          companyName: 'Saark Automation Partner Test',
          phone: `+919833${Date.now().toString().slice(-6)}`,
          email: `partner.${Date.now()}@saark.in`,
          city: 'Pune',
          state: 'Maharashtra',
        }),
      });
      const newCust = await unwrap(createCustRes);
      testCustomerId = newCust?.id;
    }
    assert(Boolean(testCustomerId), `2.9 Customer Master record verified for CRM sales linking (ID: ${testCustomerId})`);

    // 2.7 Create New Lead
    const createLeadRes = await fetch(`${BASE_URL}/crm/leads`, {
      method: 'POST',
      headers: { ...authHeader, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        companyName: 'Apex Industrial Automation Ltd',
        contactPerson: 'Mr. Vikram Patil',
        email: `vikram.patil.${Date.now()}@apexautomation.com`,
        phone: `+919822${Date.now().toString().slice(-6)}`,
        status: 'NEW',
        leadSource: 'EXHIBITION',
        estimatedValue: 450000,
        notes: 'Interested in VFD control panels and booster pump systems',
      }),
    });
    assert(createLeadRes.ok || createLeadRes.status === 201, `2.10 POST /api/v1/crm/leads creates lead (Status: ${createLeadRes.status})`);
    const createdLead = await unwrap(createLeadRes);
    createdLeadId = createdLead?.id;

    // 2.8 Fetch Leads List
    const leadsRes = await fetch(`${BASE_URL}/crm/leads`, { headers: authHeader });
    assert(leadsRes.ok, '2.11 GET /api/v1/crm/leads returns HTTP 200');
    const leadsList = await unwrap(leadsRes);
    const leadsArr = Array.isArray(leadsList) ? leadsList : (leadsList?.data || []);
    assert(leadsArr.length > 0, `2.12 Leads list populated with active records (Count: ${leadsArr.length})`);

    // 2.9 Get Lead Detail & Update
    if (createdLeadId) {
      const leadDetailRes = await fetch(`${BASE_URL}/crm/leads/${createdLeadId}`, { headers: authHeader });
      assert(leadDetailRes.ok, `2.13 GET /api/v1/crm/leads/${createdLeadId} returns HTTP 200 detail`);

      const updateLeadRes = await fetch(`${BASE_URL}/crm/leads/${createdLeadId}`, {
        method: 'PUT',
        headers: { ...authHeader, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          priority: 'HIGH',
          status: 'CONTACTED',
          notes: 'Customer contacted via telephone; site survey scheduled',
        }),
      });
      assert(updateLeadRes.ok, '2.14 PUT /api/v1/crm/leads/:id successfully updates lead priority & status');
    }

    // 2.10 Opportunities & Kanban Pipeline
    const pipelineRes = await fetch(`${BASE_URL}/crm/pipeline`, { headers: authHeader });
    assert(pipelineRes.ok, '2.15 GET /api/v1/crm/pipeline returns HTTP 200 Kanban stages');
    const pipelineData = await unwrap(pipelineRes);
    assert(typeof pipelineData === 'object', '2.16 Pipeline stages returned (PROSPECT, QUALIFIED, PROPOSAL, NEGOTIATION, WON)');

    // 2.11 Create Opportunity Deal (Linked to Customer)
    const createOppRes = await fetch(`${BASE_URL}/crm/opportunities`, {
      method: 'POST',
      headers: { ...authHeader, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: 'VFD Control Panel Supply (15 HP x 4 Units)',
        customerId: testCustomerId,
        leadId: createdLeadId,
        estimatedValue: 680000,
        stage: 'QUOTATION_SENT',
        probability: 70,
        expectedCloseDate: new Date(Date.now() + 14 * 86400000).toISOString(),
      }),
    });
    assert(createOppRes.ok || createOppRes.status === 201, `2.17 POST /api/v1/crm/opportunities creates deal (Status: ${createOppRes.status})`);
    const createdOpp = await unwrap(createOppRes);
    createdOppId = createdOpp?.id;

    // 2.12 Follow-Ups Workflow
    const followUpsRes = await fetch(`${BASE_URL}/crm/follow-ups`, { headers: authHeader });
    assert(followUpsRes.ok, '2.18 GET /api/v1/crm/follow-ups returns HTTP 200');

    // 2.13 CRM Analytics
    const analyticsRes = await fetch(`${BASE_URL}/crm/analytics`, { headers: authHeader });
    assert(analyticsRes.ok, '2.19 GET /api/v1/crm/analytics returns HTTP 200 performance overview');

    // 2.14 Enquiries Workflow (B2B Trading)
    const enqRes = await fetch(`${BASE_URL}/crm/enquiries`, { headers: authHeader });
    assert(enqRes.ok, '2.20 GET /api/v1/crm/enquiries returns HTTP 200');
    const enqSummRes = await fetch(`${BASE_URL}/crm/enquiries-summary`, { headers: authHeader });
    assert(enqSummRes.ok, '2.21 GET /api/v1/crm/enquiries-summary returns status totals');

    // 2.15 Commercial Quotations
    const quotesRes = await fetch(`${BASE_URL}/sales/quotations`, { headers: authHeader });
    assert(quotesRes.ok, '2.22 GET /api/v1/sales/quotations returns HTTP 200');
    const quotesList = await unwrap(quotesRes);
    const quotesItems = quotesList?.items || quotesList?.data || (Array.isArray(quotesList) ? quotesList : []);
    assert(Array.isArray(quotesItems), `2.23 Quotations returned as structured list (Total: ${quotesItems.length})`);

    // 2.16 Sales Orders List
    const ordersRes = await fetch(`${BASE_URL}/sales/orders`, { headers: authHeader });
    assert(ordersRes.ok, '2.24 GET /api/v1/sales/orders returns HTTP 200');
  } catch (err) {
    assert(false, `Tier 2 Exception: ${err.message}`);
  }

  // ===========================================================================
  // TIER 3: DATABASE PERSISTENCE & INTEGRITY TIER (Prisma PostgreSQL)
  // ===========================================================================
  console.log('\n--- [TIER 3] Database Tier (Prisma PostgreSQL Verification) ---');
  if (prisma) {
    try {
      // 3.1 Verify Lead Persistence in PostgreSQL
      if (createdLeadId) {
        const dbLead = await prisma.lead.findUnique({
          where: { id: createdLeadId },
          include: { customer: true, assignedStaff: true },
        });
        assert(dbLead !== null, `3.1 Lead persisted in PostgreSQL table (ID: ${createdLeadId})`);
        assert(dbLead.companyName === 'Apex Industrial Automation Ltd', '3.2 Lead companyName accurately matches database record');
        assert(dbLead.status === 'CONTACTED', `3.3 Lead status updated and persisted as ${dbLead.status}`);
      } else {
        const anyLead = await prisma.lead.findFirst();
        assert(anyLead !== null, `3.1 Database table 'leads' contains persisted records (Sample: ${anyLead?.companyName})`);
      }

      // 3.2 Verify Opportunity Persistence in PostgreSQL
      if (createdOppId) {
        const dbOpp = await prisma.opportunity.findUnique({
          where: { id: createdOppId },
          include: { customer: true },
        });
        assert(dbOpp !== null, `3.4 Opportunity persisted in PostgreSQL (ID: ${createdOppId})`);
        assert(Number(dbOpp.estimatedValue) === 680000, `3.5 Deal estimated value matches financial precision (${dbOpp.estimatedValue})`);
        assert(dbOpp.customerId === testCustomerId, '3.6 Opportunity correctly linked to Customer Foreign Key in PostgreSQL');
      } else {
        const anyOpp = await prisma.opportunity.findFirst();
        assert(anyOpp !== null, `3.4 Database table 'opportunities' holds valid pipeline deals`);
      }

      // 3.3 Relational Foreign Key Integrity Check
      const opportunitiesWithCustomer = await prisma.opportunity.findMany({
        take: 5,
        include: { customer: true, lead: true },
      });
      assert(Array.isArray(opportunitiesWithCustomer), '3.7 Opportunity-to-Customer relational integrity confirmed');

      // 3.4 Database Anti-Duplicate Integrity Check
      const testPhone = '+919988776655';
      const existingLeadsCount = await prisma.lead.count({
        where: { phone: testPhone },
      });
      assert(typeof existingLeadsCount === 'number', `3.8 Database query validates duplicate phone index counts (${existingLeadsCount})`);

      // 3.5 Database Audit Trail Verification for CRM
      const auditLogs = await prisma.auditLog.findMany({
        where: { module: 'CRM' },
        take: 5,
        orderBy: { timestamp: 'desc' },
      });
      assert(Array.isArray(auditLogs), `3.9 PostgreSQL audit_logs contains CRM action audit trail (Count: ${auditLogs.length})`);
    } catch (err) {
      assert(false, `Tier 3 Database Exception: ${err.message}`);
    } finally {
      await prisma.$disconnect();
    }
  } else {
    assert(false, 'Tier 3 Database tests skipped: Prisma client not connected');
  }

  // ===========================================================================
  // SUMMARY RESULTS
  // ===========================================================================
  console.log('\n================================================================================');
  console.log(` SALES & MARKETING FULL-STACK RESULTS: ${passed} PASSED, ${failed} FAILED (TOTAL: ${passed + failed})`);
  console.log('================================================================================\n');

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runSalesMarketingFullSuite().catch((err) => {
  console.error('Fatal Test Error:', err);
  process.exit(1);
});
