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
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

async function run() {
  console.log('🚀 1. Authenticating as admin...');
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

  if (loginRes.status !== 200 && loginRes.status !== 201) {
    console.error('❌ Login failed:', loginRes);
    process.exit(1);
  }

  const payload = loginRes.data;
  const token =
    payload.tokens?.accessToken ||
    payload.accessToken ||
    payload.token;

  if (!token) {
    console.error('❌ Could not find accessToken in login response:', payload);
    process.exit(1);
  }
  console.log('✅ Authenticated successfully! Token received.');

  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // 2. Test GET Bank Accounts
  console.log('\n🏦 2. Testing GET /api/v1/sales/bank-cash/accounts...');
  const accountsRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/bank-cash/accounts',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`✅ Accounts Status: ${accountsRes.status}`);
  console.log('Registered Accounts:', accountsRes.data.map(a => `${a.accountName}: Opening ₹${a.openingBalance}, Current: ₹${a.currentBalance}`));

  // 3. Test POST new Bank Account
  console.log('\n➕ 3. Testing POST /api/v1/sales/bank-cash/accounts (Add ICICI Export Account)...');
  const createAccRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/sales/bank-cash/accounts',
      method: 'POST',
      headers: authHeaders,
    },
    {
      accountName: 'ICICI Export Account',
      bankName: 'ICICI Bank Ltd',
      accountNumber: '001105001234',
      openingBalance: 50000.00,
      notes: 'Forex EEFC Account',
    }
  );
  console.log(`✅ Create Account Status: ${createAccRes.status}, Created:`, createAccRes.data.accountName);
  const testAccId = createAccRes.data.id;

  // 4. Test GET Transactions
  console.log('\n💳 4. Testing GET /api/v1/sales/bank-cash/transactions...');
  const txListRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/bank-cash/transactions',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`✅ Transactions Status: ${txListRes.status}, Total count: ${txListRes.data.length}`);

  // 5. Test POST new Transaction
  console.log('\n💸 5. Testing POST /api/v1/sales/bank-cash/transactions (Deposit ₹25,000 into ICICI Export)...');
  const createTxRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/sales/bank-cash/transactions',
      method: 'POST',
      headers: authHeaders,
    },
    {
      date: '2026-10-15',
      accountName: 'ICICI Export Account',
      type: 'Deposit',
      amount: 25000.00,
      description: 'Export advance remittance for Solar Tracking Panel',
      reference: 'FIRC-992182',
      notes: 'Foreign customer remittance',
    }
  );
  console.log(`✅ Create Transaction Status: ${createTxRes.status}, Recorded:`, createTxRes.data.description);
  const testTxId = createTxRes.data.id;

  // 6. Test GET Summary
  console.log('\n📊 6. Testing GET /api/v1/sales/bank-cash/summary...');
  const summaryRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/bank-cash/summary',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`✅ Summary Status: ${summaryRes.status}`);
  console.log('Total Liquidity across all accounts: ₹' + summaryRes.data.totalBalance.toLocaleString('en-IN'));
  const iciciUpdated = summaryRes.data.accounts.find(a => a.accountName === 'ICICI Export Account');
  console.log(`Verified ICICI Balance: Opening ₹${iciciUpdated.openingBalance} + Deposit ₹25,000 = ₹${iciciUpdated.currentBalance}`);

  if (iciciUpdated.currentBalance === 75000) {
    console.log('🎯 FORMULA VERIFICATION: PASS (50000 + 25000 = 75000)');
  } else {
    console.error('❌ Formula error: expected 75000, got', iciciUpdated.currentBalance);
    process.exit(1);
  }

  // 7. Cleanup
  console.log('\n🧹 7. Cleaning up test records...');
  await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/sales/bank-cash/transactions/${testTxId}`,
    method: 'DELETE',
    headers: authHeaders,
  });
  await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/sales/bank-cash/accounts/${testAccId}`,
    method: 'DELETE',
    headers: authHeaders,
  });
  console.log('✅ Cleaned up test records.');

  console.log('\n🎉 ALL BACKEND BANK & CASH API TESTS PASSED SUCCESSFULLY!');
}

run().catch((err) => {
  console.error('Test run failed:', err);
  process.exit(1);
});
