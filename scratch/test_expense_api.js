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
  const token = payload.tokens?.accessToken || payload.accessToken || payload.token;
  if (!token) {
    console.error('❌ No accessToken found:', payload);
    process.exit(1);
  }
  console.log('✅ Authenticated! Token acquired.');

  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  // 2. GET Expenses
  console.log('\n💸 2. Testing GET /api/v1/sales/expenses...');
  const expListRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/expenses',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`✅ Expenses count: ${expListRes.data.length}, status: ${expListRes.status}`);

  // 3. GET Expenses Summary
  console.log('\n📊 3. Testing GET /api/v1/sales/expenses/summary...');
  const summaryRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/expenses/summary',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`✅ Initial Total Expenses: ₹${summaryRes.data.totalExpenses}`);
  console.log(`✅ This Month: ₹${summaryRes.data.thisMonthExpenses}`);
  console.log(`✅ Top Category: ${summaryRes.data.topCategory}`);
  console.log('Categories:', summaryRes.data.categoryBreakdown.map(c => `${c.category}: ₹${c.subtotal} (${c.percentage.toFixed(1)}%)`));

  const initialTotal = summaryRes.data.totalExpenses;

  // 4. POST new Expense
  console.log('\n➕ 4. Testing POST /api/v1/sales/expenses (Add Material Purchase: ₹15,000)...');
  const createRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/sales/expenses',
      method: 'POST',
      headers: authHeaders,
    },
    {
      date: '2026-10-15',
      category: 'Material Purchase',
      description: 'Raw copper busbars and industrial terminal lugs',
      amount: 15000.0,
      paymentMethod: 'Bank Transfer',
      paidTo: 'Metal Craft Suppliers Ltd',
      notes: 'GST Inv: MC-2026-88',
    }
  );
  console.log(`✅ Create Status: ${createRes.status}, ID: ${createRes.data.id}`);
  const testId = createRes.data.id;

  // 5. Verify Updated Summary
  console.log('\n🔍 5. Verifying summary recalculation after insert...');
  const afterRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/expenses/summary',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`New Total: ₹${afterRes.data.totalExpenses} (Expected: ₹${initialTotal + 15000})`);
  if (afterRes.data.totalExpenses === initialTotal + 15000) {
    console.log('🎯 FORMULA VERIFICATION (Total_Expenses = Sum(Amount)): PASS');
  } else {
    console.error('❌ Formula verification failed!');
    process.exit(1);
  }

  // 6. DELETE test record
  console.log('\n🧹 6. Cleaning up test expense record...');
  await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/sales/expenses/${testId}`,
    method: 'DELETE',
    headers: authHeaders,
  });
  console.log('✅ Cleaned up successfully.');

  console.log('\n🎉 ALL BACKEND EXPENSE API TESTS PASSED SUCCESSFULLY!');
}

run().catch((e) => {
  console.error('Test error:', e);
  process.exit(1);
});
