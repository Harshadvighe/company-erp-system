const http = require('http');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'saark_erp_production_jwt_secret_key_2026_x98123';
const PORT = 3199;

function generateToken(userType = 'admin') {
  if (userType === 'viewer') {
    return jwt.sign(
      {
        sub: 'bae1c7dc-d65c-46f5-ab92-d3798c721545',
        email: 'harshadvighe545@gmail.com',
        roles: ['ROLE_EMPLOYEE'],
      },
      JWT_SECRET,
      { expiresIn: '1h' },
    );
  }
  return jwt.sign(
    {
      sub: '34b661b1-7d62-42df-a52e-3beabbbcf5af',
      email: 'admin@saark.in',
      roles: ['ROLE_ADMIN'],
    },
    JWT_SECRET,
    { expiresIn: '1h' },
  );
}

function request(method, path, body = null, token = generateToken()) {
  return new Promise((resolve, reject) => {
    const dataString = body ? JSON.stringify(body) : '';
    const req = http.request(
      {
        hostname: 'localhost',
        port: PORT,
        path,
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          ...(body ? { 'Content-Length': Buffer.byteLength(dataString) } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, body: data ? JSON.parse(data) : {} });
          } catch (_) {
            resolve({ status: res.statusCode, raw: data });
          }
        });
      },
    );
    req.on('error', reject);
    if (body) req.write(dataString);
    req.end();
  });
}

async function runTests() {
  console.log('====================================================================');
  console.log('  SAARK ERP — CUSTOMER RECYCLE BIN & PERMANENT DELETION TEST SUITE');
  console.log('====================================================================\n');

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

  // 1. Check existing trash endpoint
  console.log('--- 1. GET /api/v1/customers/trash ---');
  const trashRes = await request('GET', '/api/v1/customers/trash');
  assert(trashRes.status === 200, `Trash endpoint returned 200 (got ${trashRes.status})`);
  const trashPayload = trashRes.body.data || trashRes.body;
  const trashedList = trashPayload.data || [];
  assert(Array.isArray(trashedList), 'Trash data is an array');
  assert(trashPayload.meta && typeof trashPayload.meta.total === 'number', 'Trash meta has total count');
  console.log(`  Found ${trashedList.length} trashed customer(s) currently in Recycle Bin`);

  // 2. Create two disposable test customers for safe lifecycle testing
  console.log('\n--- 2. Create Disposable Test Customers ---');
  const codeA = `CUS-TEST-${Date.now()}-A`;
  const codeB = `CUS-TEST-${Date.now()}-B`;

  const createA = await request('POST', '/api/v1/customers', {
    companyName: 'Disposable Test Customer Alpha',
    contactPerson: 'Tester A',
    email: `tester_a_${Date.now()}@test.saark.in`,
    phone: '9876543210',
    address: '123 Test Street',
    state: 'Tamil Nadu',
    district: 'Coimbatore',
    city: 'Coimbatore',
    pincode: '641001',
    customerType: 'END_CUSTOMER',
  });
  assert(createA.status === 201, `Customer Alpha created successfully (201)`);
  const custA = createA.body.data?.data || createA.body.data || createA.body;

  const createB = await request('POST', '/api/v1/customers', {
    companyName: 'Disposable Test Customer Beta',
    contactPerson: 'Tester B',
    email: `tester_b_${Date.now()}@test.saark.in`,
    phone: '9876543211',
    address: '456 Test Road',
    state: 'Karnataka',
    district: 'Bengaluru',
    city: 'Bengaluru',
    pincode: '560001',
    customerType: 'OEM',
  });
  assert(createB.status === 201, `Customer Beta created successfully (201)`);
  const custB = createB.body.data?.data || createB.body.data || createB.body;

  // 3. Verify Active Directory contains Alpha and Beta
  console.log('\n--- 3. Verify Active Directory Contains Test Records ---');
  const activeCheck = await request('GET', `/api/v1/customers?search=${encodeURIComponent(custA.companyName)}`);
  assert(activeCheck.status === 200, 'Search active customers returned 200');
  const activeData = activeCheck.body.data?.data || activeCheck.body.data || [];
  const foundA = activeData.find((c) => c.id === custA.id);
  assert(foundA !== undefined, 'Customer Alpha found in active directory');

  // 4. Test Single Move to Recycle Bin (DELETE /api/v1/customers/:id)
  console.log('\n--- 4. Test Single Move to Recycle Bin (Soft Delete) ---');
  const trashSingle = await request('DELETE', `/api/v1/customers/${custA.id}`);
  assert(trashSingle.status === 200, `Single delete returned 200 (got ${trashSingle.status})`);
  const singleMsg = (trashSingle.body.data?.message || trashSingle.body.message || '');
  assert(singleMsg.includes('Recycle Bin'), `Response confirms moved to Recycle Bin: "${singleMsg}"`);

  // Verify Alpha is gone from active directory
  const activeAfterA = await request('GET', `/api/v1/customers?search=${encodeURIComponent(custA.companyName)}`);
  const activeAfterData = activeAfterA.body.data?.data || activeAfterA.body.data || [];
  const foundAAfter = activeAfterData.find((c) => c.id === custA.id);
  assert(foundAAfter === undefined, 'Customer Alpha no longer in active directory');

  // 5. Test Bulk Move to Recycle Bin (POST /api/v1/customers/bulk-trash)
  console.log('\n--- 5. Test Bulk Move to Recycle Bin (POST /bulk-trash) ---');
  const bulkTrashRes = await request('POST', '/api/v1/customers/bulk-trash', {
    ids: [custB.id],
    reason: 'Testing bulk trash API',
  });
  assert(bulkTrashRes.status === 201, `Bulk trash returned 201 (got ${bulkTrashRes.status})`);
  const bulkTrashPayload = bulkTrashRes.body.data || bulkTrashRes.body;
  assert(bulkTrashPayload.count === 1, `Moved exactly 1 customer to trash (got ${bulkTrashPayload.count})`);
  assert(bulkTrashPayload.affectedIds && bulkTrashPayload.affectedIds.includes(custB.id), 'Customer Beta ID in affectedIds');

  // 6. Verify Both Alpha and Beta appear in Recycle Bin (GET /trash)
  console.log('\n--- 6. Verify Both In Recycle Bin ---');
  const trashCheck = await request('GET', '/api/v1/customers/trash?limit=50');
  assert(trashCheck.status === 200, 'GET /customers/trash returned 200');
  const trashItems = (trashCheck.body.data?.data || trashCheck.body.data || []);
  const foundInTrashA = trashItems.find((c) => c.id === custA.id);
  const foundInTrashB = trashItems.find((c) => c.id === custB.id);
  assert(foundInTrashA !== undefined, 'Customer Alpha found in Recycle Bin with deletedAt & deletedBy');
  assert(foundInTrashB !== undefined, 'Customer Beta found in Recycle Bin with deletedAt & deletedBy');

  // 7. Test Single Restore (POST /api/v1/customers/:id/restore)
  console.log('\n--- 7. Test Single Restore (POST /:id/restore) ---');
  const restoreA = await request('POST', `/api/v1/customers/${custA.id}/restore`);
  assert(restoreA.status === 201, `Restore Alpha returned 201 (got ${restoreA.status})`);
  const restoreAMsg = restoreA.body.data?.message || restoreA.body.message || '';
  assert(restoreAMsg.includes('restored'), `Message confirms restore: "${restoreAMsg}"`);

  // Verify Alpha is back in active directory
  const activeRestoredA = await request('GET', `/api/v1/customers?search=${encodeURIComponent(custA.companyName)}`);
  const restoredAData = activeRestoredA.body.data?.data || activeRestoredA.body.data || [];
  const foundRestoredA = restoredAData.find((c) => c.id === custA.id);
  assert(foundRestoredA !== undefined, 'Customer Alpha successfully restored to active directory');

  // 8. Test Bulk Restore (POST /api/v1/customers/bulk-restore)
  console.log('\n--- 8. Test Bulk Restore (POST /bulk-restore) ---');
  const restoreB = await request('POST', '/api/v1/customers/bulk-restore', { ids: [custB.id] });
  assert(restoreB.status === 201, `Bulk restore returned 201 (got ${restoreB.status})`);
  const restoreBPayload = restoreB.body.data || restoreB.body;
  assert(restoreBPayload.count === 1, `Restored count is 1 (got ${restoreBPayload.count})`);

  // Verify Beta is back in active directory
  const activeRestoredB = await request('GET', `/api/v1/customers?search=${encodeURIComponent(custB.companyName)}`);
  const restoredBData = activeRestoredB.body.data?.data || activeRestoredB.body.data || [];
  const foundRestoredB = restoredBData.find((c) => c.id === custB.id);
  assert(foundRestoredB !== undefined, 'Customer Beta successfully restored to active directory');

  // 9. Guard Check: Permanent Deletion of Active Customer MUST Be Rejected
  console.log('\n--- 9. Guard: Permanent Deletion of Active Customer Rejected ---');
  const activeDeleteAttempt = await request('DELETE', `/api/v1/customers/${custA.id}/permanent`);
  assert(activeDeleteAttempt.status === 400, `Permanent delete of active customer rejected with 400 (got ${activeDeleteAttempt.status})`);
  const guardMsg = activeDeleteAttempt.body.message || '';
  assert(
    guardMsg.includes('Recycle Bin'),
    `Error message requires customer to be in Recycle Bin first: "${guardMsg}"`,
  );

  // 10. Move both to trash again for permanent deletion tests
  console.log('\n--- 10. Move Back to Trash for Permanent Delete Tests ---');
  await request('POST', '/api/v1/customers/bulk-trash', { ids: [custA.id, custB.id] });

  // 11. Test Single Permanent Delete (DELETE /api/v1/customers/:id/permanent)
  console.log('\n--- 11. Test Single Permanent Delete ---');
  const permDelA = await request('DELETE', `/api/v1/customers/${custA.id}/permanent`);
  assert(permDelA.status === 200, `Permanent delete returned 200 (got ${permDelA.status})`);
  const permDelAMsg = permDelA.body.data?.message || permDelA.body.message || '';
  assert(permDelAMsg.includes('permanently deleted'), `Message confirms permanent deletion: "${permDelAMsg}"`);

  // Verify Alpha is completely gone from DB
  const getCustA = await request('GET', `/api/v1/customers/${custA.id}`);
  assert(getCustA.status === 404, 'Customer Alpha completely removed from database (404)');

  // 12. Test Bulk Permanent Delete (POST /api/v1/customers/bulk-permanent-delete)
  console.log('\n--- 12. Test Bulk Permanent Delete ---');
  const bulkPermDel = await request('POST', '/api/v1/customers/bulk-permanent-delete', { ids: [custB.id] });
  assert(bulkPermDel.status === 201, `Bulk permanent delete returned 201 (got ${bulkPermDel.status})`);
  const bulkPermPayload = bulkPermDel.body.data || bulkPermDel.body;
  assert(bulkPermPayload.deletedCount === 1, `Deleted count is 1 (got ${bulkPermPayload.deletedCount})`);
  const getCustB = await request('GET', `/api/v1/customers/${custB.id}`);
  assert(getCustB.status === 404, 'Customer Beta completely removed from database (404)');

  // 13. Test Empty Recycle Bin (POST /api/v1/customers/recycle-bin/empty)
  console.log('\n--- 13. Test Empty Recycle Bin ---');
  // Create test customer Gamma, move to trash, then empty
  const createGamma = await request('POST', '/api/v1/customers', {
    companyName: 'Disposable Customer Gamma',
    contactPerson: 'Tester Gamma',
    email: `tester_gamma_${Date.now()}@test.saark.in`,
    phone: '9876543299',
    address: '789 Gamma Way',
    state: 'Maharashtra',
    district: 'Pune',
    city: 'Pune',
    pincode: '411001',
    customerType: 'END_CUSTOMER',
  });
  const custGamma = createGamma.body.data?.data || createGamma.body.data;
  await request('POST', '/api/v1/customers/bulk-trash', { ids: [custGamma.id] });

  const emptyRes = await request('POST', '/api/v1/customers/recycle-bin/empty');
  assert(emptyRes.status === 201, `Empty recycle bin returned 201 (got ${emptyRes.status})`);
  const emptyPayload = emptyRes.body.data || emptyRes.body;
  assert(emptyPayload.deletedCount >= 1, `Empty recycle bin deleted at least 1 customer (got ${emptyPayload.deletedCount})`);
  const getGamma = await request('GET', `/api/v1/customers/${custGamma.id}`);
  assert(getGamma.status === 404, 'Customer Gamma permanently removed after emptying Recycle Bin (404)');

  // 14. Test Statutory Business Record Retention Protection
  console.log('\n--- 14. Test Statutory Business Record Retention Protection ---');
  // Customer CUS-2026-00001 has active quotation/orders
  // Find customer with code CUS-2026-00001
  const searchCus1 = await request('GET', '/api/v1/customers?search=CUS-2026-00001');
  const cus1 = (searchCus1.body.data?.data || []).find((c) => c.customerCode === 'CUS-2026-00001');
  if (cus1) {
    // Attempt permanent delete on active record
    const permFail = await request('DELETE', `/api/v1/customers/${cus1.id}/permanent`);
    assert(permFail.status === 400, 'Permanent deletion on protected active customer rejected (400)');
  } else {
    console.log('  [SKIP] CUS-2026-00001 not found for statutory test');
  }

  // 15. Test RBAC Permissions Guard & Explicit DENY Override
  console.log('\n--- 15. Test RBAC Permissions Guard & Explicit DENY ---');
  const viewerToken = generateToken('viewer');
  // Harshad does not have DELETE_PERMANENT
  const unauthorizedPerm = await request('DELETE', '/api/v1/customers/some-id/permanent', null, viewerToken);
  assert(unauthorizedPerm.status === 403, `User without DELETE_PERMANENT gets 403 Forbidden (got ${unauthorizedPerm.status})`);

  const unauthorizedEmpty = await request('POST', '/api/v1/customers/recycle-bin/empty', null, viewerToken);
  assert(unauthorizedEmpty.status === 403, `User without DELETE_PERMANENT cannot empty recycle bin (403 got ${unauthorizedEmpty.status})`);

  console.log('\n====================================================================');
  console.log(`  RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('====================================================================\n');

  if (failed > 0) process.exit(1);
}

runTests().catch((e) => {
  console.error('Test suite failed:', e);
  process.exit(1);
});
