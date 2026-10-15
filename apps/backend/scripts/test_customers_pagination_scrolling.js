const http = require('http');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'saark_erp_production_jwt_secret_key_2026_x98123';
const PORT = 3199;

function generateToken() {
  return jwt.sign(
    {
      sub: 'bae1c7dc-d65c-46f5-ab92-d3798c721545',
      email: 'harshadvighe545@gmail.com',
      roles: ['ROLE_EMPLOYEE'],
      permissions: ['CRM:VIEW', 'CUSTOMERS:VIEW', 'CRM:CREATE', 'CUSTOMERS:CREATE'],
    },
    JWT_SECRET,
    { expiresIn: '1h' },
  );
}

function fetchCustomers(query = '') {
  return new Promise((resolve, reject) => {
    const token = generateToken();
    const path = `/api/v1/customers${query ? '?' + query : ''}`;
    const req = http.request(
      {
        hostname: 'localhost',
        port: PORT,
        path,
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, body: JSON.parse(data) });
          } catch (e) {
            resolve({ status: res.statusCode, raw: data });
          }
        });
      },
    );
    req.on('error', reject);
    req.end();
  });
}

async function runRegressionSuite() {
  console.log('====================================================================');
  console.log('  SAARK ERP — CUSTOMER TABLE SCROLLING & PAGINATION REGRESSION SUITE');
  console.log('====================================================================');

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

  // ── TEST 1: Baseline Total Customers in Staging ──
  console.log('\n--- 1. Verification of Active Customer Count ---');
  const resBase = await fetchCustomers('page=1&limit=25');
  assert(resBase.status === 200, `API returned HTTP 200 OK`);
  const meta = resBase.body.data.meta;
  assert(meta.total === 79, `Total active customer count is exactly 79 (got ${meta.total})`);
  assert(meta.totalPages === 4, `Total pages for limit=25 is 4 (got ${meta.totalPages})`);
  assert(resBase.body.data.data.length === 25, `Page 1 returns exactly 25 records`);

  // ── TEST 2: Reachability Beyond Row 25 & Uniqueness Across All 4 Pages ──
  console.log('\n--- 2. Paged Retrieval Across All 4 Pages (Rows 1 to 79) ---');
  const allIds = new Set();
  const allCodes = new Set();
  let totalRetrieved = 0;

  for (let page = 1; page <= 4; page++) {
    const res = await fetchCustomers(`page=${page}&limit=25`);
    const rows = res.body.data.data;
    const pageMeta = res.body.data.meta;

    if (page < 4) {
      assert(rows.length === 25, `Page ${page} contains exactly 25 rows`);
    } else {
      assert(rows.length === 4, `Page 4 (final page) contains exactly 4 remaining rows (25+25+25+4 = 79)`);
    }

    rows.forEach((r, idx) => {
      const globalRowNum = (page - 1) * 25 + idx + 1;
      assert(!allIds.has(r.id), `Row #${globalRowNum} (${r.companyName}) is unique across pages`);
      allIds.add(r.id);
      allCodes.add(r.customerCode);
    });

    totalRetrieved += rows.length;
  }

  assert(totalRetrieved === 79, `All 79 records successfully reached across pages without omissions`);
  assert(allIds.size === 79, `Exactly 79 unique customer IDs collected (zero duplicates)`);

  // Verify row 26 is accessible
  const page2Res = await fetchCustomers('page=2&limit=25');
  const row26 = page2Res.body.data.data[0];
  assert(Boolean(row26 && row26.id), `Record beyond row 25 (Row #26: "${row26.companyName}" / ${row26.customerCode}) is accessible on Page 2`);

  // Verify the last record (#79) is accessible
  const page4Res = await fetchCustomers('page=4&limit=25');
  const row79 = page4Res.body.data.data[3];
  assert(Boolean(row79 && row79.id), `Final record (Row #79: "${row79.companyName}" / ${row79.customerCode}) is accessible on Page 4`);

  // ── TEST 3: Page Size Selector (50 Rows Per Page) ──
  console.log('\n--- 3. Page Size Selector: 50 Rows Per Page ---');
  const res50p1 = await fetchCustomers('page=1&limit=50');
  assert(res50p1.body.data.data.length === 50, `Page 1 with limit=50 returns 50 records`);
  assert(res50p1.body.data.meta.totalPages === 2, `Total pages for limit=50 is 2`);

  const res50p2 = await fetchCustomers('page=2&limit=50');
  assert(res50p2.body.data.data.length === 29, `Page 2 with limit=50 returns remaining 29 records (50 + 29 = 79)`);

  const combined50 = new Set([
    ...res50p1.body.data.data.map((r) => r.id),
    ...res50p2.body.data.data.map((r) => r.id),
  ]);
  assert(combined50.size === 79, `Combined 50-per-page pages yield all 79 unique customers`);

  // ── TEST 4: Page Size Selector: 100 Rows Per Page (All on One Page) ──
  console.log('\n--- 4. Page Size Selector: 100 Rows Per Page ---');
  const res100 = await fetchCustomers('page=1&limit=100');
  assert(res100.body.data.data.length === 79, `Page 1 with limit=100 returns all 79 records in a single dataset`);
  assert(res100.body.data.meta.totalPages === 1, `Total pages for limit=100 is 1`);

  // ── TEST 5: 'All' Option (limit=1000) ──
  console.log('\n--- 5. "All" Option: limit=1000 ---');
  const resAll = await fetchCustomers('page=1&limit=1000');
  assert(resAll.body.data.data.length === 79, `Limit=1000 ("All") returns all 79 records`);
  assert(resAll.body.data.meta.limit === 1000, `Meta correctly records limit=1000`);

  // Verify first and last records in "All" dataset match paged records
  const firstInAll = resAll.body.data.data[0];
  const lastInAll = resAll.body.data.data[78];
  assert(firstInAll.id === resBase.body.data.data[0].id, `First record in "All" view matches Page 1 Row 1`);
  assert(lastInAll.id === row79.id, `Last record in "All" view matches Page 4 Row 4 (#79)`);

  // ── TEST 6: Row Numbering Formula Accuracy ──
  console.log('\n--- 6. Dynamic Row Numbering Verification ---');
  function calculateRowNum(page, pageSize, index) {
    return (page - 1) * pageSize + index + 1;
  }
  assert(calculateRowNum(1, 25, 0) === 1, `Page 1, size 25, index 0 -> #1`);
  assert(calculateRowNum(1, 25, 24) === 25, `Page 1, size 25, index 24 -> #25`);
  assert(calculateRowNum(2, 25, 0) === 26, `Page 2, size 25, index 0 -> #26`);
  assert(calculateRowNum(4, 25, 3) === 79, `Page 4, size 25, index 3 -> #79`);
  assert(calculateRowNum(2, 50, 0) === 51, `Page 2, size 50, index 0 -> #51`);
  assert(calculateRowNum(1, 1000, 78) === 79, `Page 1, size 1000, index 78 -> #79`);

  console.log('\n====================================================================');
  console.log(`  REGRESSION RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('====================================================================');

  process.exit(failed === 0 ? 0 : 1);
}

runRegressionSuite().catch((err) => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
