const http = require('http');

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: body ? JSON.parse(body) : null });
        } catch (e) {
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

const unwrap = (res) => res.data?.data || res.data;

async function runTests() {
  console.log('===============================================================');
  console.log('STARTING HR BACKEND NAME VALIDATION & INTEGRATION TEST SUITE');
  console.log('===============================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, testName, details) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}`);
      if (details) console.error(`       Details:`, details);
      failed++;
    }
  }

  // Step 0: Authenticate as HR to get JWT token
  console.log('--- Step 0: Authenticate as HR Manager (hr / Saark@2026) ---');
  const loginRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, { emailOrUsername: 'hr', password: 'Saark@2026' });

  assert(loginRes.status === 200 || loginRes.status === 201, 'HR Authentication successful', `Status: ${loginRes.status}`);
  const loginObj = unwrap(loginRes);
  const token = loginObj?.tokens?.accessToken || loginRes.data?.tokens?.accessToken;
  assert(!!token, 'JWT Access Token received for HR session');

  const authHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  };

  const timestamp = Date.now();

  // Test 1: Create Employee with First, Middle, and Last Name
  console.log('\n--- Test 1: Create Employee with First Name, Middle Name, Last Name ---');
  const emp1Payload = {
    firstName: 'Devendra',
    middleName: 'Pratap',
    lastName: 'Singhania',
    email: `devendra.singhania.${timestamp}@saark.in`,
    phone: '+91 98200 45678',
    designation: 'Senior Automation Engineer',
    status: 'ACTIVE',
    salaryCtc: 850000,
  };

  const res1 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, emp1Payload);

  const emp1 = unwrap(res1);
  assert(res1.status === 201, 'HTTP 201 Created for full 3-part name', `Status: ${res1.status}`);
  assert(emp1 && emp1.firstName === 'Devendra', 'Employee firstName correctly recorded', emp1?.firstName);
  assert(emp1 && emp1.middleName === 'Pratap', 'Employee middleName correctly recorded', emp1?.middleName);
  assert(emp1 && emp1.lastName === 'Singhania', 'Employee lastName correctly recorded', emp1?.lastName);
  const createdEmpId = emp1?.id;

  // Test 2: Create Employee without Middle Name (Optional Middle Name)
  console.log('\n--- Test 2: Create Employee without Middle Name (Optional Middle Name) ---');
  const emp2Payload = {
    firstName: 'Pooja',
    lastName: 'Sharma',
    email: `pooja.sharma.${timestamp}@saark.in`,
    phone: '+91 98200 99887',
    designation: 'Quality Control Lead',
    status: 'ACTIVE',
  };

  const res2 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, emp2Payload);

  const emp2 = unwrap(res2);
  assert(res2.status === 201, 'HTTP 201 Created for 2-part name (no middle name)', `Status: ${res2.status}`);
  assert(emp2 && emp2.firstName === 'Pooja', 'Employee firstName is recorded', emp2?.firstName);
  assert(emp2 && (emp2.middleName === null || emp2.middleName === undefined), 'middleName is null/empty as expected', emp2?.middleName);
  assert(emp2 && emp2.lastName === 'Sharma', 'Employee lastName is recorded', emp2?.lastName);

  // Test 3: Validation Rejection - Missing or empty First Name
  console.log('\n--- Test 3: Validation Rejection - Missing First Name ---');
  const invalid1 = {
    firstName: '',
    middleName: 'Kumar',
    lastName: 'Verma',
    email: `invalid.first.${timestamp}@saark.in`,
    phone: '+91 98200 11111',
    designation: 'Technician',
  };
  const res3 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, invalid1);

  assert(res3.status === 400, 'HTTP 400 Bad Request returned when firstName is empty', `Status: ${res3.status}`);

  // Test 4: Validation Rejection - First Name shorter than 2 characters
  console.log('\n--- Test 4: Validation Rejection - First Name < 2 chars ---');
  const invalid2 = {
    firstName: 'A',
    lastName: 'Verma',
    email: `invalid.short.${timestamp}@saark.in`,
    phone: '+91 98200 22222',
    designation: 'Technician',
  };
  const res4 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, invalid2);

  assert(res4.status === 400, 'HTTP 400 Bad Request returned when firstName < 2 chars', `Status: ${res4.status}`);

  // Test 5: Validation Rejection - Missing Last Name
  console.log('\n--- Test 5: Validation Rejection - Missing Last Name ---');
  const invalid3 = {
    firstName: 'Ramesh',
    middleName: 'Kumar',
    lastName: '',
    email: `invalid.last.${timestamp}@saark.in`,
    phone: '+91 98200 33333',
    designation: 'Technician',
  };
  const res5 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, invalid3);

  assert(res5.status === 400, 'HTTP 400 Bad Request returned when lastName is empty', `Status: ${res5.status}`);

  // Test 6: Validation Rejection - Invalid Email format
  console.log('\n--- Test 6: Validation Rejection - Invalid Email Format ---');
  const invalid4 = {
    firstName: 'Suresh',
    lastName: 'Patil',
    email: 'not-an-email-address',
    phone: '+91 98200 44444',
    designation: 'Technician',
  };
  const res6 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, invalid4);

  assert(res6.status === 400, 'HTTP 400 Bad Request returned for invalid email format', `Status: ${res6.status}`);

  // Test 7: Validation Rejection - Phone number too short
  console.log('\n--- Test 7: Validation Rejection - Phone Number Too Short ---');
  const invalid5 = {
    firstName: 'Mahesh',
    lastName: 'Gaikwad',
    email: `mahesh.g.${timestamp}@saark.in`,
    phone: '123',
    designation: 'Technician',
  };
  const res7 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, invalid5);

  assert(res7.status === 400, 'HTTP 400 Bad Request returned for phone number < 7 digits', `Status: ${res7.status}`);

  // Test 8: Duplicate Email Conflict
  console.log('\n--- Test 8: Duplicate Email Conflict (HTTP 409) ---');
  const res8 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees',
    method: 'POST',
    headers: authHeaders,
  }, emp1Payload);

  assert(res8.status === 409, 'HTTP 409 Conflict returned when re-using same work email', `Status: ${res8.status}`);

  // Test 9: Update Employee Names (First, Middle, Last)
  console.log('\n--- Test 9: Update Employee Names ---');
  if (createdEmpId) {
    const updatePayload = {
      firstName: 'Devendra',
      middleName: 'Prataprao',
      lastName: 'Singhania-Patil',
    };
    const res9 = await request({
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/hr/employees/${createdEmpId}`,
      method: 'PUT',
      headers: authHeaders,
    }, updatePayload);

    const empUpdated = unwrap(res9);
    assert(res9.status === 200, 'HTTP 200 OK returned on employee update', `Status: ${res9.status}`);
    assert(empUpdated && empUpdated.middleName === 'Prataprao', 'Updated middleName persisted correctly', empUpdated?.middleName);
    assert(empUpdated && empUpdated.lastName === 'Singhania-Patil', 'Updated lastName persisted correctly', empUpdated?.lastName);
  }

  // Test 10: Search Employee by middleName
  console.log('\n--- Test 10: Search Employee by Middle Name ---');
  const res10 = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/hr/employees?search=Prataprao',
    method: 'GET',
    headers: authHeaders,
  });

  const list = unwrap(res10);
  assert(res10.status === 200, 'HTTP 200 OK returned on search', `Status: ${res10.status}`);
  const match = Array.isArray(list) && list.some((e) => e.middleName === 'Prataprao');
  assert(match, 'Search query successfully found employee via middleName filter', `Matches: ${list?.length}`);

  console.log('\n===============================================================');
  console.log(`FINAL RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('===============================================================');

  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
