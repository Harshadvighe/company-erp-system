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

async function run() {
  console.log('--- Testing Sales & Marketing Financial Reports API ---');

  // 1. Authenticate
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
  if (!token) throw new Error('Authentication failed');
  console.log('✓ Authentication successful as Admin');

  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // 2. Fetch Financial Reports (Default Period)
  const reportRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/financial-reports',
    method: 'GET',
    headers,
  });

  if (reportRes.status !== 200) {
    throw new Error(`Failed to fetch financial reports: ${JSON.stringify(reportRes)}`);
  }

  const reports = reportRes.data;
  console.log('✓ Fetched financial reports successfully for period:', reports.period);

  // 3. Verify Tab 1: Dashboard KPIs
  const dash = reports.dashboard;
  console.log('\n📊 [Tab 1: Dashboard KPIs]');
  console.log(' - Today Sales: ₹' + dash.todaySales);
  console.log(' - Monthly Sales: ₹' + dash.monthlySales);
  console.log(' - Bank Balance: ₹' + dash.bankBalance);
  console.log(' - Cash in Hand: ₹' + dash.cashBalance);
  console.log(' - Customer Outstanding: ₹' + dash.customerOutstanding);
  console.log(' - Vendor Outstanding: ₹' + dash.vendorOutstanding);
  console.log(' - Monthly Expenses: ₹' + dash.monthlyExpense);
  console.log(' - Monthly Profit: ₹' + dash.monthlyProfit);
  console.log(' - GST Payable: ₹' + dash.gstPayable);

  if (dash.monthlyProfit !== dash.monthlySales - dash.monthlyExpense) {
    throw new Error('Monthly Profit formula mismatch!');
  }
  console.log('✓ Dashboard formula: Monthly_Profit = Monthly_Sales - Monthly_Expense verified!');

  // 4. Verify Tab 2: Profit & Loss Statement
  const pl = reports.profitAndLoss;
  console.log('\n📈 [Tab 2: Profit & Loss Statement]');
  console.log(' - Income Rows count:', pl.incomeRows.length);
  console.log(' - Expense Rows count:', pl.expenseRows.length);
  console.log(' - Total Income: ₹' + pl.totalIncome);
  console.log(' - Total Expenses: ₹' + pl.totalExpenses);
  console.log(' - Net Profit: ₹' + pl.netProfit);

  if (pl.netProfit !== pl.totalIncome - pl.totalExpenses) {
    throw new Error('P&L Net Profit formula mismatch!');
  }
  console.log('✓ P&L formula: Net_Profit = Total_Income - Total_Expenses verified!');

  // 5. Verify Tab 3: Cash Flow Statement
  const cf = reports.cashFlow;
  console.log('\n🏦 [Tab 3: Cash Flow Statement]');
  console.log(' - Inflow Rows count:', cf.inflowRows.length);
  console.log(' - Outflow Rows count:', cf.outflowRows.length);
  console.log(' - Total Inflow: ₹' + cf.totalInflow);
  console.log(' - Total Outflow: ₹' + cf.totalOutflow);
  console.log(' - Net Cash Flow: ₹' + cf.netCashFlow);

  if (cf.netCashFlow !== cf.totalInflow - cf.totalOutflow) {
    throw new Error('Cash Flow formula mismatch!');
  }
  console.log('✓ Cash Flow formula: Net_Cash_Flow = Total_Inflow - Total_Outflow verified!');

  // 6. Verify Tab 4: Balance Sheet
  const bs = reports.balanceSheet;
  console.log('\n📋 [Tab 4: Balance Sheet]');
  console.log(' - Asset Rows count:', bs.assetRows.length);
  console.log(' - Liability Rows count:', bs.liabilityRows.length);
  console.log(' - Equity Rows count:', bs.equityRows.length);
  console.log(' - Total Assets: ₹' + bs.totalAssets);
  console.log(' - Total Liabilities: ₹' + bs.totalLiabilities);
  console.log(' - Total Equity: ₹' + bs.totalEquity);

  if (bs.totalEquity !== bs.totalAssets - bs.totalLiabilities) {
    throw new Error('Balance Sheet Equity formula mismatch!');
  }
  if (Math.abs(bs.totalAssets - (bs.totalLiabilities + bs.totalEquity)) > 0.001) {
    throw new Error('Balance Sheet Equality (Assets = Liabilities + Equity) failed!');
  }
  console.log('✓ Balance Sheet Equality: Assets = Liabilities + Equity verified!');

  // 7. Verify Tab 5: Outstanding Report
  const out = reports.outstanding;
  console.log('\n⏳ [Tab 5: Outstanding Report]');
  console.log(' - Total Customer Outstanding: ₹' + out.totalCustomerOutstanding);
  console.log(' - Customer Pending Invoices count:', out.customerPending.length);
  console.log(' - Total Vendor Outstanding: ₹' + out.totalVendorOutstanding);
  console.log(' - Vendor Pending Bills count:', out.vendorPending.length);

  const calculatedCustOut = out.customerPending.reduce((sum, p) => sum + p.pendingAmount, 0);
  if (calculatedCustOut !== out.totalCustomerOutstanding) {
    throw new Error('Customer Outstanding sum mismatch!');
  }
  const calculatedVendOut = out.vendorPending.reduce((sum, p) => sum + p.pendingAmount, 0);
  if (calculatedVendOut !== out.totalVendorOutstanding) {
    throw new Error('Vendor Outstanding sum mismatch!');
  }
  console.log('✓ Outstanding totals verified!');

  console.log('\n======================================================');
  console.log('ALL FINANCIAL REPORTS API TESTS PASSED SUCCESSFULLY! (100%)');
  console.log('======================================================');
}

run().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
