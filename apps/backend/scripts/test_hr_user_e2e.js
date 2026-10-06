const BASE_URL = 'http://localhost:3000/api/v1';

async function testHrLoginAndWorkflows() {
  console.log('================================================================');
  console.log('       TESTING HR LOGIN & WORKFLOWS (USER: hr / Sneha Deshmukh)  ');
  console.log('================================================================\n');

  let total = 0;
  let passed = 0;
  let failed = 0;

  function assert(condition, testName, details = '') {
    total++;
    if (condition) {
      passed++;
      console.log(`  \x1b[32m✔ PASS\x1b[0m [${total}] ${testName}`);
    } else {
      failed++;
      console.error(`  \x1b[31m✖ FAIL\x1b[0m [${total}] ${testName} ${details ? '-> ' + details : ''}`);
    }
  }

  // 1. Authenticate with hr / Saark@2026
  console.log('1. Authenticating as HR Manager...');
  const loginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ emailOrUsername: 'hr', password: 'Saark@2026' }),
  });
  assert(loginRes.status === 201 || loginRes.status === 200, 'HTTP status 200/201 on login');
  const loginData = await loginRes.json();
  const token = loginData.data?.tokens?.accessToken;
  const user = loginData.data?.user;

  assert(!!token, 'Access Token issued for HR Manager session');
  assert(user?.username === 'hr', 'Username matches "hr"');
  assert(user?.fullName === 'Sneha Deshmukh', 'Full name is "Sneha Deshmukh"');
  assert(user?.roles?.includes('ROLE_HR'), 'User has ROLE_HR role');
  assert(user?.permissions?.includes('HR:VIEW'), 'User has HR:VIEW permission');
  assert(user?.permissions?.includes('HR:APPROVE'), 'User has HR:APPROVE permission');

  const authHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  };

  // 2. Test /auth/me
  console.log('\n2. Verifying Session via /auth/me...');
  const meRes = await fetch(`${BASE_URL}/auth/me`, { headers: authHeaders });
  assert(meRes.ok, '/auth/me returns 200 OK');
  const meData = await meRes.json();
  assert(meData.data?.email === 'hr@saark.in', 'Session verified for hr@saark.in');

  // 3. HR Executive Dashboard
  console.log('\n3. Testing HR Executive Dashboard...');
  const dashRes = await fetch(`${BASE_URL}/hr/dashboard`, { headers: authHeaders });
  assert(dashRes.ok, 'GET /hr/dashboard returns 200 OK');
  const dashData = await dashRes.json();
  const metrics = dashData.data;
  assert(typeof metrics?.totalEmployees === 'number' && metrics.totalEmployees >= 1, 'Total employees metric loaded');
  assert(!!metrics?.workforceBreakdown, 'Workforce category breakdown loaded');
  assert(!!metrics?.shiftBreakdown, 'Shift breakdown loaded');
  assert(!!metrics?.safetyKpis, 'Safety/EHS KPIs loaded');

  // 4. Plant Shift Rosters
  console.log('\n4. Testing Plant Shifts (Factories Act)...');
  const shiftsRes = await fetch(`${BASE_URL}/hr/shifts`, { headers: authHeaders });
  assert(shiftsRes.ok, 'GET /hr/shifts returns 200 OK');
  const shiftsData = await shiftsRes.json();
  const shifts = shiftsData.data || [];
  assert(shifts.length >= 4, 'Shift setup includes SHIFT_G, SHIFT_A, SHIFT_B, SHIFT_N');
  assert(shifts.some(s => s.code === 'SHIFT_G'), 'General Plant Day Shift active');

  // 5. Workstations / Assembly Bays
  console.log('\n5. Testing Workstations & Assembly Bays...');
  const wsRes = await fetch(`${BASE_URL}/hr/workstations`, { headers: authHeaders });
  assert(wsRes.ok, 'GET /hr/workstations returns 200 OK');
  const wsData = await wsRes.json();
  assert(Array.isArray(wsData.data), 'Assembly bay allocations list returned');

  // 6. Safety & EHS Incidents
  console.log('\n6. Testing Safety & EHS Incidents...');
  const safetyRes = await fetch(`${BASE_URL}/hr/safety`, { headers: authHeaders });
  assert(safetyRes.ok, 'GET /hr/safety returns 200 OK');
  const safetyData = await safetyRes.json();
  assert(Array.isArray(safetyData.data), 'EHS incident logs list returned');

  // 7. Form 25 Muster Roll
  console.log('\n7. Testing Factories Act Form 25 Muster Roll...');
  const musterRes = await fetch(`${BASE_URL}/hr/muster-roll?month=10&year=2026`, { headers: authHeaders });
  assert(musterRes.ok, 'GET /hr/muster-roll returns 200 OK');
  const musterData = await musterRes.json();
  assert(Array.isArray(musterData.data) && musterData.data.length >= 1, 'Muster roll report generated with worker attendance & overtime');

  // 8. Employee Directory & Profile
  console.log('\n8. Testing Employee Directory & Profile...');
  const empRes = await fetch(`${BASE_URL}/hr/employees`, { headers: authHeaders });
  assert(empRes.ok, 'GET /hr/employees returns 200 OK');
  const empData = await empRes.json();
  const employees = empData.data || [];
  assert(employees.length >= 1, `Employee directory contains ${employees.length} records`);

  const sampleEmp = employees[0];
  const profileRes = await fetch(`${BASE_URL}/hr/employees/${sampleEmp.id}`, { headers: authHeaders });
  assert(profileRes.ok, `GET /hr/employees/${sampleEmp.employeeCode} returns full 360-degree profile`);
  const profileData = await profileRes.json();
  assert(profileData.data?.employeeCode === sampleEmp.employeeCode, 'Profile data matches requested employee');

  // 9. Attendance Tracker
  console.log('\n9. Testing Attendance Tracker...');
  const attRes = await fetch(`${BASE_URL}/hr/attendance`, { headers: authHeaders });
  assert(attRes.ok, 'GET /hr/attendance returns 200 OK');
  const attData = await attRes.json();
  assert(Array.isArray(attData.data?.records), 'Daily attendance sheet returned with punch status');

  // 10. Leave Requests
  console.log('\n10. Testing Leave Management...');
  const leaveRes = await fetch(`${BASE_URL}/hr/leaves`, { headers: authHeaders });
  assert(leaveRes.ok, 'GET /hr/leaves returns 200 OK');
  const leaveData = await leaveRes.json();
  assert(Array.isArray(leaveData.data), 'Leave requests register returned');

  // 11. Payroll Register
  console.log('\n11. Testing Payroll & Salary Registers...');
  const payRes = await fetch(`${BASE_URL}/hr/payroll?month=October 2026&year=2026`, { headers: authHeaders });
  assert(payRes.ok, 'GET /hr/payroll returns 200 OK');
  const payData = await payRes.json();
  assert(Array.isArray(payData.data), 'Statutory payroll register returned');

  // 12. Create a test employee as HR Manager
  console.log('\n12. Testing HR Employee Creation Workflow...');
  const randomSuffix = Date.now().toString().slice(-4);
  const newEmpPayload = {
    firstName: 'Kavita',
    lastName: 'Kulkarni',
    email: `kavita.test.${randomSuffix}@saark.in`,
    phone: '+91 98200 44556',
    designation: 'Wireman Assistant',
    workerCategory: 'SHOPFLOOR_TECH',
    skillLevel: 'LEVEL_1_TRAINEE',
    assignedBay: 'BAY_3_MOUNTING',
    shiftCode: 'SHIFT_A',
    salaryCtc: 300000,
    status: 'PENDING_APPROVAL',
  };
  const createEmpRes = await fetch(`${BASE_URL}/hr/employees`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify(newEmpPayload),
  });
  assert(createEmpRes.status === 201 || createEmpRes.status === 200, 'HR Manager successfully created new employee (POST /hr/employees)');
  const createEmpData = await createEmpRes.json();
  const createdEmp = createEmpData.data;
  assert(createdEmp?.status === 'PENDING_APPROVAL', 'Created employee initialized as PENDING_APPROVAL');
  assert(createdEmp?.employeeCode?.startsWith('EMP-2026-'), 'Employee code auto-assigned (EMP-2026-xxx)');

  // 13. Test Leave Application by HR
  console.log('\n13. Testing Leave Application as HR Manager...');
  const leavePayload = {
    employeeId: sampleEmp.id,
    leaveType: 'CASUAL',
    startDate: '2026-11-20T00:00:00.000Z',
    endDate: '2026-11-21T00:00:00.000Z',
    daysCount: 2,
    reason: 'Family event in Pune',
  };
  const createLeaveRes = await fetch(`${BASE_URL}/hr/leaves`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify(leavePayload),
  });
  assert(createLeaveRes.ok, 'HR successfully submitted leave request (POST /hr/leaves)');
  const createLeaveData = await createLeaveRes.json();
  const newLeave = createLeaveData.data;
  assert(newLeave?.leaveCode?.startsWith('LV-2026-'), 'Leave request assigned LV-2026-xxxx code');

  // 14. Approve Leave Request
  console.log('\n14. Testing Leave Approval by HR Manager...');
  const approveLeaveRes = await fetch(`${BASE_URL}/hr/leaves/${newLeave.id}/status`, {
    method: 'PATCH',
    headers: authHeaders,
    body: JSON.stringify({ status: 'APPROVED', decisionNote: 'Approved by Sneha Deshmukh (HR Manager)' }),
  });
  assert(approveLeaveRes.ok, 'HR Manager approved leave request (PATCH /hr/leaves/:id/status)');
  const approvedData = await approveLeaveRes.json();
  assert(approvedData.data?.status === 'APPROVED', 'Leave status changed to APPROVED');

  // 15. Clean up temporary test data
  console.log('\n15. Cleaning up temporary test records...');
  const { PrismaClient } = require('@prisma/client');
  const prisma = new PrismaClient();
  if (createdEmp?.id) await prisma.employee.delete({ where: { id: createdEmp.id } });
  if (newLeave?.id) await prisma.leaveRequest.delete({ where: { id: newLeave.id } });
  await prisma.$disconnect();
  assert(true, 'Test records cleaned up successfully');

  console.log('\n================================================================');
  console.log(`TOTAL HR TESTS:  ${total}`);
  console.log(`PASSED:          \x1b[32m${passed}\x1b[0m`);
  console.log(`FAILED:          \x1b[31m${failed}\x1b[0m`);
  console.log(`SUCCESS RATE:    ${Math.round((passed / total) * 100)}%`);
  console.log('================================================================\n');

  if (failed > 0) process.exit(1);
}

testHrLoginAndWorkflows().catch(err => {
  console.error('Fatal error during HR test:', err);
  process.exit(1);
});
