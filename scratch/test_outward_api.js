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
  console.log('--- Testing Sales & Marketing Outward Documents (Other Documents) API ---');

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

  // 2. Test Smart Numbering Generation
  const qNum = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/outward/next-number?type=Quotation&date=2026-10-15',
    method: 'GET',
    headers,
  });
  console.log('✓ Quotation Next Number Response:', qNum.data);
  if (!qNum.data.documentNo.startsWith('Q-20261015-')) {
    throw new Error('Quotation numbering format mismatch: ' + qNum.data.documentNo);
  }

  const dcNum = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/outward/next-number?type=Delivery%20Challan&date=2026-10-15',
    method: 'GET',
    headers,
  });
  console.log('✓ Delivery Challan Next Number Response:', dcNum.data);
  if (!dcNum.data.documentNo.startsWith('DC-20261015-')) {
    throw new Error('Delivery Challan numbering format mismatch: ' + dcNum.data.documentNo);
  }

  // 3. Test Customers & Catalog
  const customers = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/outward/customers',
    method: 'GET',
    headers,
  });
  console.log(`✓ Fetched ${customers.data.length} customer records for autocomplete`);

  const catalog = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/outward/catalog',
    method: 'GET',
    headers,
  });
  console.log(`✓ Fetched ${catalog.data.length} catalog items for line item builder`);

  // 4. Test Save Outward Document (Document with multiple line items)
  const docNo = qNum.data.documentNo;
  const savePayload = {
    documentType: 'Quotation',
    documentDate: '2026-10-15',
    documentNo: docNo,
    customer: 'Win Win Distribution Pvt Ltd',
    department: 'Panel Department',
    items: [
      {
        itemDescription: 'AI-PCU02 WITH HMI DISPLAY 1 Nos',
        quantity: 2,
        rate: 50000.0,
        amount: 100000.0,
      },
      {
        itemDescription: 'AIPCU HMI CONTROLLER MULTIVFD 3 Nos',
        quantity: 1,
        rate: 80000.0,
        amount: 80000.0,
      },
    ],
    notes: 'Urgent factory dispatch for municipal pump test rig; transport by VRL Logistics',
  };

  const saveRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/sales/outward',
      method: 'POST',
      headers,
    },
    savePayload
  );
  console.log('✓ Outward document saved:', saveRes.data);
  if (saveRes.data.totalAmount !== 180000) {
    throw new Error(`Expected total 180,000 but got ${saveRes.data.totalAmount}`);
  }

  // 5. Verify increment in next document number for same type and date
  const nextQNum = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/sales/outward/next-number?type=Quotation&date=2026-10-15',
    method: 'GET',
    headers,
  });
  console.log('✓ Next Quotation Number after save:', nextQNum.data.documentNo);
  if (nextQNum.data.sequence <= qNum.data.sequence) {
    throw new Error('Sequence did not increment properly');
  }

  // 6. Test delete & cleanup
  const delRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: `/api/v1/sales/outward/${docNo}`,
    method: 'DELETE',
    headers,
  });
  console.log('✓ Cleanup test outward document:', delRes.data);

  console.log('\n======================================================');
  console.log('ALL OUTWARD DOCUMENTS API TESTS PASSED SUCCESSFULLY! (100%)');
  console.log('======================================================');
}

run().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
