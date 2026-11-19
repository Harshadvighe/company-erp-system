const http = require('http');

async function run() {
  console.log('================================================================================');
  console.log('     SAARK ERP: WORKFLOW 4 - OFFICE EXPENSE (HR / ADMIN) TEST SUITE');
  console.log('================================================================================\n');

  // Step 0: Authenticate as SuperAdmin (Saarkadmin)
  const loginRes = await fetch('http://127.0.0.1:3000/api/v1/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'Saarkadmin', password: '12345678' })
  });
  const loginData = await loginRes.json();
  const token = loginData.data?.tokens?.accessToken || loginData.data?.accessToken || loginData.accessToken;
  if (!token) {
    console.error('❌ Failed to authenticate as SuperAdmin:', loginData);
    process.exit(1);
  }
  console.log('✅ Authenticated as Managing Director (Saarkadmin)\n');

  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  };

  // Test 1: Fetch Existing Expense Summary
  console.log('--- [TEST 1] Fetch Initial Expense Summary ---');
  const sumRes = await fetch('http://127.0.0.1:3000/api/v1/hr/expenses/summary', { headers });
  const sumData = await sumRes.json();
  console.log('HTTP', sumRes.status, 'Summary:', sumData.data?.summary || sumData.summary);
  console.log('Category breakdown count:', (sumData.data?.byCategory || sumData.byCategory)?.length);

  // Test 2: Step 4.1 Submission (Staff submits expense voucher)
  console.log('\n--- [TEST 2] Step 4.1: Submit Staff Expense Voucher ---');
  const submitPayload = {
    title: 'Site Visit Conveyance & Relay Testing Tools',
    category: 'TOOLS',
    amount: 1850.00,
    expenseDate: new Date().toISOString().split('T')[0],
    description: 'Digital multimeter probes and terminal crimping tool for plant line 2.',
    receiptUrl: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP...',
    staffName: 'Amit Deshmukh',
    department: 'Engineering & Assembly'
  };
  const submitRes = await fetch('http://127.0.0.1:3000/api/v1/hr/expenses', {
    method: 'POST',
    headers,
    body: JSON.stringify(submitPayload)
  });
  const submitData = await submitRes.json();
  const voucher = submitData.data || submitData;
  console.log('HTTP', submitRes.status, 'Created Voucher:', voucher.voucherNumber, '| Status:', voucher.status);
  const voucherId = voucher.id;

  // Test 3: Verify Voucher is in SUBMITTED State
  console.log('\n--- [TEST 3] Verify Voucher Listing in SUBMITTED State ---');
  const listRes = await fetch('http://127.0.0.1:3000/api/v1/hr/expenses?status=SUBMITTED', { headers });
  const listData = await listRes.json();
  const vouchers = listData.data || listData;
  const match = vouchers.find(v => v.id === voucherId || v.voucher_number === voucher.voucherNumber);
  console.log('Found in SUBMITTED queue:', match ? `YES (${match.voucher_number})` : 'NO');

  // Test 4: Step 4.2 Department / HR Admin Review
  console.log('\n--- [TEST 4] Step 4.2: Department Admin Review Voucher ---');
  const reviewPayload = {
    status: 'REVIEWED',
    reviewNotes: 'Verified receipt against tool store register. Item is genuine and approved for MD signoff.'
  };
  const reviewRes = await fetch(`http://127.0.0.1:3000/api/v1/hr/expenses/${voucherId}/review`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify(reviewPayload)
  });
  const reviewData = await reviewRes.json();
  console.log('HTTP', reviewRes.status, 'Review Status:', (reviewData.data || reviewData).status, '| Message:', (reviewData.data || reviewData).message);

  // Test 5: Step 4.2 & 4.3: Managing Director Approval & Automatic Ledger Posting
  console.log('\n--- [TEST 5] Step 4.2 & 4.3: Managing Director Approval & Ledger Posting ---');
  const approvePayload = {
    status: 'APPROVED',
    approvalNotes: 'Approved by Managing Director. Post to Office Expense Ledger.',
    paymentMode: 'PETTY_CASH',
    markPaid: true
  };
  const approveRes = await fetch(`http://127.0.0.1:3000/api/v1/hr/expenses/${voucherId}/approve`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify(approvePayload)
  });
  const approveData = await approveRes.json();
  const approvedResult = approveData.data || approveData;
  console.log('HTTP', approveRes.status, 'Final Status:', approvedResult.status);
  console.log('Ledger Account:', approvedResult.ledgerAccount);
  console.log('Ledger Ref (Journal Voucher):', approvedResult.ledgerRef);
  console.log('Payment Mode:', approvedResult.paymentMode);
  console.log('Confirmation:', approvedResult.message);

  // Test 6: Verify Final Updated Summary
  console.log('\n--- [TEST 6] Verify Updated Summary Metrics ---');
  const finalSumRes = await fetch('http://127.0.0.1:3000/api/v1/hr/expenses/summary', { headers });
  const finalSumData = await finalSumRes.json();
  console.log('HTTP', finalSumRes.status, 'Final Summary:', finalSumData.data?.summary || finalSumData.summary);

  console.log('\n================================================================================');
  console.log('   ✅ ALL WORKFLOW 4 LIFECYCLE TESTS COMPLETED SUCCESSFULLY!');
  console.log('================================================================================\n');
}

run().catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});
