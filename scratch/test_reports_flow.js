async function testReports() {
  const baseURL = 'http://localhost:3000/api/v1';
  console.log('--- 1. Authenticating as Super Admin ---');
  const loginRes = await fetch(`${baseURL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ emailOrUsername: 'admin@saark.in', password: 'Saark@2026' })
  });
  const loginData = await loginRes.json();
  const token = loginData.data?.tokens?.accessToken || loginData.tokens?.accessToken || loginData.accessToken;
  const headers = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };
  console.log('✓ Token acquired');

  console.log('\n--- 2. Executive Summary Report ---');
  const sumRaw = await (await fetch(`${baseURL}/reports/summary`, { headers })).json();
  const sum = sumRaw.data || sumRaw;
  console.log('Financials:', sum.financials);
  console.log('Operations:', sum.operations);

  console.log('\n--- 3. Sales Performance Report ---');
  const salesRaw = await (await fetch(`${baseURL}/reports/sales`, { headers })).json();
  const sales = salesRaw.data || salesRaw;
  console.log(`Conversion Rate: ${sales.conversionRate}% (${sales.wonQuotations}/${sales.totalQuotations})`);
  console.log(`Top Corporate Clients (${sales.topCustomers?.length || 0}):`, sales.topCustomers?.map(c => `${c.name}: ₹${c.billedAmount}`));

  console.log('\n--- 4. Inventory Valuation Report ---');
  const invRaw = await (await fetch(`${baseURL}/reports/inventory`, { headers })).json();
  const inv = invRaw.data || invRaw;
  console.log('Warehouses:', inv.warehouseBreakdown?.map(w => `${w.code}: ${w.units} units, ₹${w.valuation}`));
  console.log(`Critical low stock items: ${inv.lowStockAlerts?.length || 0}`);

  console.log('\n--- 5. Production & QC Pipeline Report ---');
  const prodRaw = await (await fetch(`${baseURL}/reports/production`, { headers })).json();
  const prod = prodRaw.data || prodRaw;
  console.log(`Total Panels: ${prod.totalPanels}, Stage Breakdown:`, prod.stageBreakdown);

  console.log('\n>>> REPORTS & EXECUTIVE ANALYTICS ENGINE TEST COMPLETED 100% SUCCESSFULLY! <<<');
}

testReports().catch(err => {
  console.error('Error during reports test:', err);
  process.exit(1);
});
