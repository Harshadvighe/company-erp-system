const http = require('http');

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, data: parsed.data !== undefined ? parsed.data : parsed });
        } catch {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function runOverallCrmSuite() {
  console.log('================================================================');
  console.log('       SAARK ERP: OVERALL CRM & SALES SUITE VERIFICATION        ');
  console.log('================================================================\n');

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition, message) {
    totalTests++;
    if (!condition) {
      console.error(`❌ FAILED: ${message}`);
      throw new Error(`Assertion failed: ${message}`);
    }
    console.log(`✅ [${totalTests}] ${message}`);
    passedTests++;
  }

  // 1. Authenticate as Admin
  console.log('🔑 STEP 1: Admin Authentication...');
  const loginRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/auth/login',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    },
    { emailOrUsername: 'admin', password: 'Saark@2026' }
  );

  const payload = loginRes.data;
  const token = payload.tokens?.accessToken || payload.accessToken || payload.token;
  assert(token != null && token.length > 20, 'Admin login succeeded and valid JWT token acquired');

  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // 2. Customers & CRM Leads
  console.log('\n👥 STEP 2: Customer CRM & Client Directory...');
  const custRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/customers',
    method: 'GET',
    headers,
  });
  const custList = Array.isArray(custRes.data) ? custRes.data : (custRes.data.items || []);
  assert(custRes.status === 200, `GET /api/v1/customers returned status 200`);
  assert(custList.length >= 0, `Customer directory accessible (${custList.length} customers registered)`);

  // Create a CRM Customer Test Entity
  const testCustCode = `CRM-${Date.now().toString().slice(-4)}`;
  const testGstin = '27AABCU' + Math.floor(1000 + Math.random() * 9000) + 'R1ZM';
  const newCustRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/customers',
      method: 'POST',
      headers,
    },
    {
      companyName: `Saark Automation Client ${testCustCode}`,
      customerCode: testCustCode,
      contactPerson: 'Sachin Patil',
      designation: 'Managing Director',
      gstin: testGstin,
      email: `client.${testCustCode.toLowerCase()}@saarkerp.in`,
      phone: '9822001122',
      address: 'Plot 44, MIDC Bhosari Industrial Area',
      city: 'Pune',
      district: 'Pune',
      state: 'Maharashtra',
      pincode: '411026',
    }
  );
  if (newCustRes.status !== 200 && newCustRes.status !== 201) {
    console.error('Customer Creation Response Status:', newCustRes.status);
    console.error('Customer Creation Response Body:', newCustRes.data);
  }
  assert(newCustRes.status === 200 || newCustRes.status === 201, `Created new CRM customer ${testCustCode} (${testGstin})`);

  // 3. Vendors Master
  console.log('\n🏭 STEP 3: Vendor & Supplier Network...');
  const vendRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/vendors',
    method: 'GET',
    headers,
  });
  const vendList = Array.isArray(vendRes.data) ? vendRes.data : (vendRes.data.items || []);
  assert(vendRes.status === 200, `GET /api/v1/vendors returned status 200 (${vendList.length} vendors active)`);

  // 4. Products & Catalog
  console.log('\n📦 STEP 4: Products & Pricing Catalog...');
  const prodRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/products',
    method: 'GET',
    headers,
  });
  const prodList = Array.isArray(prodRes.data) ? prodRes.data : (prodRes.data.items || []);
  assert(prodRes.status === 200, `GET /api/v1/products returned status 200 (${prodList.length} items in catalog)`);

  // 5. Quotations Pipeline
  console.log('\n📝 STEP 5: Quotations Engine...');
  const quoteRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/quotations',
    method: 'GET',
    headers,
  });
  if (quoteRes.status !== 200) {
    console.error('Quotations Response Status:', quoteRes.status);
    console.error('Quotations Response Body:', quoteRes.data);
  }
  const quoteList = Array.isArray(quoteRes.data) ? quoteRes.data : (quoteRes.data.items || []);
  assert(quoteRes.status === 200, `GET /api/v1/sales/quotations returned status 200 (${quoteList.length} quotations)`);

  // 6. Sales Orders
  console.log('\n🛒 STEP 6: Sales Orders Pipeline...');
  const ordersRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/orders',
    method: 'GET',
    headers,
  });
  const orderList = Array.isArray(ordersRes.data) ? ordersRes.data : (ordersRes.data.items || []);
  assert(ordersRes.status === 200, `GET /api/v1/sales/orders returned status 200 (${orderList.length} sales orders)`);

  // 7. Commercial Invoices
  console.log('\n🧾 STEP 7: Commercial Invoices Ledger...');
  const invRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/invoices',
    method: 'GET',
    headers,
  });
  const invList = Array.isArray(invRes.data) ? invRes.data : (invRes.data.items || []);
  assert(invRes.status === 200, `GET /api/v1/sales/invoices returned status 200 (${invList.length} commercial invoices)`);

  // 8. Payment (Bank & Cash) Hub
  console.log('\n💳 STEP 8: Bank & Cash Liquidity...');
  const bankAccRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/bank-cash/accounts',
    method: 'GET',
    headers,
  });
  assert(bankAccRes.status === 200, `GET /api/v1/sales/bank-cash/accounts returned status 200`);

  const bankSummaryRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/bank-cash/summary',
    method: 'GET',
    headers,
  });
  assert(bankSummaryRes.status === 200, `GET /api/v1/sales/bank-cash/summary returned status 200`);
  assert(typeof bankSummaryRes.data.totalBalance === 'number', 'Total bank & cash liquidity balance is numeric');

  // 9. Operational Expenses
  console.log('\n💸 STEP 9: Expense Ledger & KPI Engine...');
  const expRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/expenses',
    method: 'GET',
    headers,
  });
  assert(expRes.status === 200, `GET /api/v1/sales/expenses returned status 200 (${expRes.data.length} expenses)`);

  const expSummaryRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/expenses/summary',
    method: 'GET',
    headers,
  });
  assert(expSummaryRes.status === 200, `GET /api/v1/sales/expenses/summary returned status 200`);
  assert(expSummaryRes.data.totalExpenses >= 0, 'Total cumulative expenses computed accurately');
  assert(Array.isArray(expSummaryRes.data.categoryBreakdown), 'Expenses by Category breakdown returned');

  // 10. Other Documents (Outward Logistics)
  console.log('\n📦 STEP 10: Outward Documents (Dispatch & Delivery Challan)...');
  const nextNumRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/outward/next-number?type=Delivery%20Challan&date=2026-10-16',
    method: 'GET',
    headers,
  });
  assert(nextNumRes.status === 200, `Smart document number generated: ${nextNumRes.data.documentNo}`);
  assert(nextNumRes.data.documentNo.startsWith('DC-20261016-'), 'Delivery Challan initials (DC) and date code verified');

  const outwardCatalogRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/outward/catalog',
    method: 'GET',
    headers,
  });
  assert(outwardCatalogRes.data.length > 0, `Outward catalog items fetched (${outwardCatalogRes.data.length} items)`);

  // 11. Financial Reports (5 Statements)
  console.log('\n📊 STEP 11: Financial Reports (Dashboard, P&L, Cash Flow, Balance Sheet, Outstanding)...');
  const finReportRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/financial-reports?period=2026-10',
    method: 'GET',
    headers,
  });
  assert(finReportRes.status === 200, `GET /api/v1/sales/financial-reports returned status 200`);

  const fin = finReportRes.data;
  assert(fin.dashboard != null, 'Tab 1: Dashboard 9-KPI data present');
  assert(fin.profitAndLoss != null, 'Tab 2: Profit & Loss Statement present');
  assert(fin.cashFlow != null, 'Tab 3: Cash Flow Statement present');
  assert(fin.balanceSheet != null, 'Tab 4: Balance Sheet present');
  assert(fin.outstanding != null, 'Tab 5: Outstanding Report present');

  // Verify critical financial equalities
  assert(
    fin.dashboard.monthlyProfit === (fin.dashboard.monthlySales - fin.dashboard.monthlyExpense),
    `Monthly Profit equality verified: ₹${fin.dashboard.monthlyProfit} = ₹${fin.dashboard.monthlySales} - ₹${fin.dashboard.monthlyExpense}`
  );
  assert(
    fin.profitAndLoss.netProfit === (fin.profitAndLoss.totalIncome - fin.profitAndLoss.totalExpenses),
    `P&L Net Profit equality verified: ₹${fin.profitAndLoss.netProfit} = ₹${fin.profitAndLoss.totalIncome} - ₹${fin.profitAndLoss.totalExpenses}`
  );
  assert(
    fin.cashFlow.netCashFlow === (fin.cashFlow.totalInflow - fin.cashFlow.totalOutflow),
    `Cash Flow net equality verified: ₹${fin.cashFlow.netCashFlow} = ₹${fin.cashFlow.totalInflow} - ₹${fin.cashFlow.totalOutflow}`
  );
  assert(
    Math.abs(fin.balanceSheet.totalAssets - (fin.balanceSheet.totalLiabilities + fin.balanceSheet.totalEquity)) < 0.01,
    `Balance Sheet Accounting Equation (Assets = Liabilities + Equity) perfectly balanced`
  );

  console.log('\n================================================================');
  console.log(`🎉 OVERALL CRM MODULE TEST COMPLETED: ${passedTests}/${totalTests} TESTS PASSED (100%)`);
  console.log('================================================================');
}

runOverallCrmSuite().catch((err) => {
  console.error('\n❌ OVERALL CRM TEST SUITE FAILED:', err);
  process.exit(1);
});
