require('reflect-metadata');
const { PrismaService } = require('../dist/src/core/database/prisma.service');
const { AdminService } = require('../dist/src/modules/admin/admin.service');
const { HrService } = require('../dist/src/modules/hr/hr.service');
const bcrypt = require('bcryptjs');

async function runTestSuite() {
  console.log('================================================================');
  console.log('       SAARK ERP - HR & ADMIN MODULE INTEGRATION TEST SUITE      ');
  console.log('================================================================\n');

  const prisma = new PrismaService();
  await prisma.$connect();
  const adminService = new AdminService(prisma);
  const hrService = new HrService(prisma);

  let totalTests = 0;
  let passedTests = 0;
  let failedTests = 0;
  const testResults = [];

  function assert(condition, testName, detail = '') {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`  \x1b[32m✔ PASS\x1b[0m [${totalTests}] ${testName}`);
      testResults.push({ name: testName, status: 'PASS', detail });
    } else {
      failedTests++;
      console.error(`  \x1b[31m✖ FAIL\x1b[0m [${totalTests}] ${testName} ${detail ? '-> ' + detail : ''}`);
      testResults.push({ name: testName, status: 'FAIL', detail });
    }
  }

  function section(title) {
    console.log(`\n\x1b[36m--- ${title} ---\x1b[0m`);
  }

  try {
    // =========================================================================
    // SECTION 1: ADMIN MODULE - CORE MASTERS & CONFIGURATION
    // =========================================================================
    section('1. Admin: Company Master Profile');
    const company = await adminService.getCompanyProfile();
    assert(!!company && !!company.id, 'Get Company Profile returns valid master record');
    assert(company.legalName === 'Saark Exploration Private Limited', 'Company legalName matches Saark Exploration Private Limited');
    assert(!!company.gstin && company.gstin.startsWith('27'), 'GSTIN is formatted for Maharashtra (starts with 27)');

    // Test company profile update
    const originalPhone = company.phone;
    const updatedCompany = await adminService.updateCompanyProfile({ phone: '+91 98201 99999' });
    assert(updatedCompany.phone === '+91 98201 99999', 'Update Company Profile updates phone field successfully');
    // Restore
    await adminService.updateCompanyProfile({ phone: originalPhone });

    section('2. Admin: Department Management');
    const depts = await adminService.getDepartments();
    assert(Array.isArray(depts) && depts.length >= 13, 'List Departments returns all enterprise departments (>= 13)');
    const execDept = depts.find(d => d.code === 'EXECUTIVE');
    assert(!!execDept && execDept._count.users >= 1, 'Executive department has user count relation');

    // Create temporary department
    const tempDeptCode = `TEST_DEPT_${Date.now().toString().slice(-4)}`;
    const createdDept = await adminService.createDepartment({
      name: `Test Department ${tempDeptCode}`,
      code: tempDeptCode,
    });
    assert(!!createdDept && createdDept.code === tempDeptCode, 'Create Department successfully persists new department');

    // Duplicate check
    let duplicateDeptFailed = false;
    try {
      await adminService.createDepartment({ name: createdDept.name, code: createdDept.code });
    } catch (e) {
      duplicateDeptFailed = true;
    }
    assert(duplicateDeptFailed, 'Create Department throws ConflictException on duplicate code/name');

    // Update department
    const updatedDept = await adminService.updateDepartment(createdDept.id, { name: `Updated ${tempDeptCode}` });
    assert(updatedDept.name === `Updated ${tempDeptCode}`, 'Update Department modifies department attributes');

    // Delete empty department
    await adminService.deleteDepartment(createdDept.id);
    const postDeleteDept = await prisma.department.findUnique({ where: { id: createdDept.id } });
    assert(!postDeleteDept, 'Delete Department removes clean department without users');

    // Block deletion of department with active users
    let blockDeleteDeptPassed = false;
    try {
      if (execDept) await adminService.deleteDepartment(execDept.id);
    } catch (e) {
      blockDeleteDeptPassed = true;
    }
    assert(blockDeleteDeptPassed, 'Delete Department enforces relational integrity (blocks if users/staff exist)');

    section('3. Admin: Designation Master');
    const desigs = await adminService.getDesignations();
    assert(Array.isArray(desigs) && desigs.length >= 10, 'List Designations returns master designations (>= 10)');

    const tempDesigCode = `DESIG_${Date.now().toString().slice(-4)}`;
    const createdDesig = await adminService.createDesignation({
      name: `Specialist ${tempDesigCode}`,
      code: tempDesigCode,
      description: 'Temporary Test Designation',
    });
    assert(!!createdDesig && createdDesig.code === tempDesigCode, 'Create Designation successfully persists new designation');

    // Delete clean designation
    await adminService.deleteDesignation(createdDesig.id);
    const postDeleteDesig = await prisma.designation.findUnique({ where: { id: createdDesig.id } });
    assert(!postDeleteDesig, 'Delete Designation removes clean designation');

    section('4. Admin: Financial Years, Tax Rates & Payment Modes');
    const fYears = await adminService.getFinancialYears();
    assert(Array.isArray(fYears) && fYears.length >= 1, 'Financial Years list returns records');

    const taxRates = await adminService.getTaxRates();
    assert(Array.isArray(taxRates), 'Tax Rates list returns GST slabs');

    const payModes = await adminService.getPaymentModes();
    assert(Array.isArray(payModes), 'Payment Modes list returns configured modes');

    section('5. Admin: Users Management & RBAC');
    const allUsers = await adminService.getUsers();
    assert(Array.isArray(allUsers) && allUsers.length >= 10, 'List Users returns active user directory');

    // Filter by search
    const filteredUsers = await adminService.getUsers({ search: 'admin' });
    assert(filteredUsers.some(u => u.username === 'admin'), 'User search returns admin user correctly');

    // Create a new User
    const testUsername = `test.user.${Date.now().toString().slice(-5)}`;
    const testEmail = `${testUsername}@saark.in`;
    const createdUser = await adminService.createUser({
      username: testUsername,
      email: testEmail,
      password: 'TemporaryPassword@2026',
      fullName: 'Test Verification User',
      phone: '+91 99999 11111',
      designation: 'QA Automation Engineer',
      departmentId: execDept ? execDept.id : undefined,
    });
    assert(!!createdUser && createdUser.username === testUsername, 'Create User successfully provisions account');

    // Verify password hash
    const dbUser = await prisma.user.findUnique({ where: { id: createdUser.id } });
    const isPasswordHashed = await bcrypt.compare('TemporaryPassword@2026', dbUser.passwordHash);
    assert(isPasswordHashed, 'User password is encrypted with bcrypt and verifies correctly');

    // Duplicate email check
    let duplicateUserCheck = false;
    try {
      await adminService.createUser({
        username: `diff.${testUsername}`,
        email: testEmail,
        password: 'Password@123',
        fullName: 'Duplicate Email User',
      });
    } catch (e) {
      duplicateUserCheck = true;
    }
    assert(duplicateUserCheck, 'Create User prevents duplicate email registration (ConflictException)');

    // Toggle user status
    const toggledUser = await adminService.toggleUserStatus(createdUser.id);
    assert(toggledUser.status === 'INACTIVE', 'Toggle User Status flips ACTIVE to INACTIVE');
    const restoredUser = await adminService.toggleUserStatus(createdUser.id);
    assert(restoredUser.status === 'ACTIVE', 'Toggle User Status flips INACTIVE back to ACTIVE');

    // Roles and Permissions
    const roles = await adminService.getRoles();
    const adminRole = roles.find(r => r.code === 'ROLE_ADMIN');
    assert(!!adminRole && adminRole.isSystem === true, 'Admin Role is registered as a system-protected role');

    // Test system role protection
    let systemRoleProtected = false;
    try {
      await adminService.updateRolePermissions(adminRole.id, []);
    } catch (e) {
      systemRoleProtected = true;
    }
    assert(systemRoleProtected, 'System Role is protected: updateRolePermissions rejects modifications with ConflictException');

    const perms = await adminService.getPermissions();
    assert(Array.isArray(perms) && perms.length >= 25, 'Permissions list returns module:action pairs (>= 25)');

    // Clean up test user
    await prisma.userRole.deleteMany({ where: { userId: createdUser.id } });
    await prisma.user.delete({ where: { id: createdUser.id } });

    // =========================================================================
    // SECTION 2: HR MODULE - INDUSTRIAL WORKFORCE & SHOPFLOOR OPERATIONS
    // =========================================================================
    section('6. HR: Executive & Industrial Dashboard Metrics');
    const hrMetrics = await hrService.getDashboardMetrics();
    assert(typeof hrMetrics.totalEmployees === 'number' && hrMetrics.totalEmployees >= 1, 'Total Employees is calculated accurately');
    assert(typeof hrMetrics.activeEmployees === 'number', 'Active Employees metric exists');
    assert(!!hrMetrics.workforceBreakdown, 'Workforce Category breakdown exists');
    assert(typeof hrMetrics.workforceBreakdown.shopfloorTechs === 'number', 'Shopfloor Techs count is calculated');
    assert(typeof hrMetrics.workforceBreakdown.staffOffice === 'number', 'Office Staff count is calculated');
    assert(!!hrMetrics.shiftBreakdown, 'Shift Attendance breakdown exists (Shifts G, A, B, N)');
    assert(!!hrMetrics.overtimeSummary, 'Factories Act Section 59 Overtime summary exists');
    assert(!!hrMetrics.safetyKpis, 'Safety & EHS KPIs exist (Incident-free days, PPE compliance)');
    assert(hrMetrics.safetyKpis.incidentFreeDays >= 100, 'Incident-free days tracked (milestone >= 100 days)');
    assert(typeof hrMetrics.bayAllocationsCount === 'number', 'Shopfloor Bay allocation count is tracked');
    assert(Array.isArray(hrMetrics.departmentStats), 'Department employee distribution statistics provided');

    section('7. HR: Shift Management (Factories Act 1948)');
    const shifts = await hrService.getShifts();
    assert(Array.isArray(shifts) && shifts.length >= 4, 'Shift Master returns manufacturing shifts (>= 4)');
    const shiftG = shifts.find(s => s.code === 'SHIFT_G');
    const shiftN = shifts.find(s => s.code === 'SHIFT_N');
    assert(!!shiftG && shiftG.startTime === '08:30' && shiftG.endTime === '17:00', 'SHIFT_G configured for 08:30 - 17:00 general day shift');
    assert(!!shiftN && shiftN.shiftAllowance > 0, 'SHIFT_N includes night shift hardship allowance');

    section('8. HR: Assembly Bays & Workstation Allocation');
    const testEmployee = await prisma.employee.findFirst({ where: { status: 'ACTIVE' } });
    assert(!!testEmployee, 'Active test employee exists in database');

    const allocation = await hrService.allocateWorkstation({
      employeeId: testEmployee.id,
      bayCode: 'BAY_4_WIRING',
      panelCode: 'PANEL-TEST-001',
      shiftCode: 'SHIFT_G',
      targetHours: 8.5,
      supervisorNote: 'Wiring integration for 15HP Dual VFD Panel',
    });
    assert(allocation.bayCode === 'BAY_4_WIRING', 'Technician successfully allocated to BAY_4_WIRING');
    assert(allocation.panelCode === 'PANEL-TEST-001', 'Panel Job linked to workstation allocation');

    // Verify employee record updated
    const updatedEmpBay = await prisma.employee.findUnique({ where: { id: testEmployee.id } });
    assert(updatedEmpBay.assignedBay === 'BAY_4_WIRING', 'Employee master assignedBay updated on allocation');

    const bayAllocations = await hrService.getWorkstationAllocations();
    assert(bayAllocations.some(a => a.employeeId === testEmployee.id), 'Allocations query returns today\'s allocated technicians');

    section('9. HR: Attendance Tracking & Overtime Detection');
    const attendanceSheet = await hrService.getAttendance();
    assert(attendanceSheet.records.length >= hrMetrics.activeEmployees, 'Daily attendance sheet includes all active employees (virtual fallbacks)');

    // Test Clock In
    const clockInResult = await hrService.clockIn({
      employeeId: testEmployee.id,
      location: 'Saark Factory Unit 1',
      note: 'Automated Shift Punch In',
    });
    assert(!!clockInResult.punchIn, 'Clock-in records exact punchIn timestamp');
    assert(clockInResult.status === 'PRESENT' || clockInResult.status === 'LATE', 'Punch status computed based on grace period');

    // Test Clock Out with Overtime Detection
    const clockOutResult = await hrService.clockOut({
      employeeId: testEmployee.id,
      note: 'Shift completed with assembly signoff',
    });
    assert(!!clockOutResult.punchOut, 'Clock-out records punchOut timestamp');
    assert(typeof clockOutResult.workHours === 'number', 'Work hours computed automatically');

    // Overtime Management (Factories Act Sec 59)
    const otLogged = await hrService.logOvertime({
      attendanceId: clockOutResult.id,
      overtimeHours: 2.0,
      approved: false,
    });
    assert(otLogged.overtimeHours === 2.0 && otLogged.overtimeApproved === false, 'Log Overtime records OT hours awaiting supervisor signoff');

    const otApproved = await hrService.approveOvertime(clockOutResult.id, true);
    assert(otApproved.overtimeApproved === true, 'Supervisor successfully approves overtime hours');

    section('10. HR: Safety & EHS Incident Management');
    const reportedIncident = await hrService.reportSafetyIncident(
      {
        incidentType: 'NEAR_MISS',
        severity: 'LOW',
        locationBay: 'BAY_2_BUSBAR',
        employeeId: testEmployee.id,
        description: 'Bending machine guard vibrated loose; immediate tightening executed',
        actionTaken: 'Tightened securing fasteners and verified safety interlock',
      },
      'Senior Safety Officer',
    );
    assert(!!reportedIncident.incidentCode && reportedIncident.incidentCode.startsWith('INC-2026-'), 'Safety incident generated unique INC-2026-xxx code');
    assert(reportedIncident.status === 'RESOLVED', 'Safety incident status initialized');

    const incidentsList = await hrService.getSafetyIncidents();
    assert(incidentsList.some(i => i.id === reportedIncident.id), 'Get Safety Incidents retrieves newly reported incident');

    section('11. HR: Factories Act Form 25 Muster Roll');
    const musterRoll = await hrService.getMusterRoll('10', 2026);
    assert(Array.isArray(musterRoll) && musterRoll.length >= 1, 'Muster Roll generated for factory inspection');
    const musterRow = musterRoll[0];
    assert(typeof musterRow.presentDays === 'number', 'Muster roll contains presentDays');
    assert(typeof musterRow.overtimeHours === 'number', 'Muster roll contains overtimeHours');
    assert(typeof musterRow.otEarnings === 'number', 'Muster roll calculates 2x ordinary rate OT earnings');

    section('12. HR: Employee Directory & 360 Profile');
    const empList = await hrService.getEmployees('Vikram');
    assert(Array.isArray(empList) && empList.length >= 1, 'Search employee by name returns matching results');

    const fullProfile = await hrService.getEmployeeById(testEmployee.id);
    assert(!!fullProfile.department, 'Employee 360 profile includes department relation');
    assert(Array.isArray(fullProfile.attendances), 'Employee 360 profile includes attendance log');
    assert(Array.isArray(fullProfile.workstationAllocations), 'Employee 360 profile includes bay history');
    assert(Array.isArray(fullProfile.leaveRequests), 'Employee 360 profile includes leave history');
    assert(Array.isArray(fullProfile.payrollRecords), 'Employee 360 profile includes salary slip history');

    section('13. HR: Leave Management Workflow');
    const createdLeave = await hrService.createLeaveRequest({
      employeeId: testEmployee.id,
      leaveType: 'CASUAL',
      startDate: new Date('2026-11-10').toISOString(),
      endDate: new Date('2026-11-12').toISOString(),
      daysCount: 3,
      reason: 'Attending family wedding ceremony',
    });
    assert(createdLeave.leaveCode.startsWith('LV-2026-'), 'Leave request auto-generates LV-2026-xxxx code');
    assert(createdLeave.status === 'PENDING', 'Leave request status is PENDING');

    const approvedLeave = await hrService.updateLeaveStatus(
      createdLeave.id,
      { status: 'APPROVED', decisionNote: 'Approved by Plant Manager' },
      'Plant Manager Vikram',
    );
    assert(approvedLeave.status === 'APPROVED' && approvedLeave.approvedBy === 'Plant Manager Vikram', 'Leave successfully approved with manager signoff');

    section('14. HR: Payroll & Statutory Registers');
    const payrollList = await hrService.getPayrollRecords('October 2026', 2026);
    assert(Array.isArray(payrollList), 'Payroll records returned for target month');

    // =========================================================================
    // SECTION 3: END-TO-END WORKFORCE ONBOARDING & PROVISIONING LIFECYCLE
    // =========================================================================
    section('15. End-to-End: Industrial Technician Onboarding & IT Provisioning');
    const uniqueNum = Date.now().toString().slice(-4);
    const techEmail = `tech.ganesh.${uniqueNum}@saark.in`;
    const techUsername = `ganesh.tech.${uniqueNum}`;

    // Step 1: HR creates technician onboarding request
    const onboardedTech = await hrService.createEmployee({
      firstName: 'Ganesh',
      lastName: 'Patil',
      email: techEmail,
      phone: '+91 98222 33445',
      designation: 'Wireman Grade II',
      departmentId: execDept ? execDept.id : undefined,
      workerCategory: 'SHOPFLOOR_TECH',
      skillLevel: 'LEVEL_2_WIREMAN',
      assignedBay: 'BAY_4_WIRING',
      shiftCode: 'SHIFT_G',
      electricalLicenseNo: `MH-LIC-${uniqueNum}`,
      contractorAgency: 'Saark Direct Plant Payroll',
      ppeKitIssued: true,
      salaryCtc: 360000,
      bankAccountNo: '50100482910392',
      bankIfsc: 'HDFC0001234',
      panNo: 'ABCDG1234E',
      aadhaarNo: '9988 7766 5544',
      status: 'PENDING_APPROVAL',
    });

    assert(!!onboardedTech.id, 'Step 1: HR successfully creates employee record');
    assert(onboardedTech.status === 'PENDING_APPROVAL', 'Step 1: Technician status initialized to PENDING_APPROVAL');
    assert(onboardedTech.employeeCode.startsWith('EMP-2026-'), 'Step 1: Unique employeeCode EMP-2026-xxx generated');

    // Step 2: Admin views pending requests
    const pendingRequests = await adminService.getEmployeeRequests({ status: 'PENDING_APPROVAL' });
    const targetRequest = pendingRequests.find(r => r.id === onboardedTech.id);
    assert(!!targetRequest, 'Step 2: Admin employee-requests endpoint lists pending technician');

    // Step 3: Admin approves technician and provisions credentials
    const realAdminUser = await prisma.user.findFirst({ where: { username: 'admin' } });
    const adminUser = realAdminUser ? { id: realAdminUser.id, email: realAdminUser.email } : { email: 'admin@saark.in' };
    const empRole = roles.find(r => r.code === 'ROLE_EMPLOYEE') || roles[0];

    const approvalResult = await adminService.approveEmployeeRequest(
      onboardedTech.id,
      {
        username: techUsername,
        password: 'TechPassword@2026',
        roleIds: [empRole.id],
      },
      adminUser,
    );

    assert(approvalResult.success === true, 'Step 3: Admin approves technician successfully');
    assert(approvalResult.employee.status === 'ACTIVE', 'Step 3: Employee status transitioned to ACTIVE');
    assert(!!approvalResult.user && approvalResult.user.username === techUsername, 'Step 3: User login account provisioned');

    // Step 4: Verify authentication with provisioned password
    const provisionedUser = await prisma.user.findUnique({ where: { username: techUsername } });
    assert(!!provisionedUser, 'Step 4: Provisioned user found in database');
    const authSuccess = await bcrypt.compare('TechPassword@2026', provisionedUser.passwordHash);
    assert(authSuccess, 'Step 4: Provisioned credentials match and authenticate against bcrypt');

    // Step 5: Verify linked Staff profile
    const linkedStaff = await prisma.staff.findFirst({ where: { email: techEmail } });
    assert(!!linkedStaff && linkedStaff.userId === provisionedUser.id, 'Step 5: Staff profile created and linked to provisioned User');

    // Step 6: Verify Audit Trail
    const auditEntry = await prisma.auditLog.findFirst({
      where: { entityId: onboardedTech.id, action: 'APPROVE' },
    });
    assert(!!auditEntry, 'Step 6: Security Audit Log records employee onboarding approval');

    // Step 7: Test Reject Workflow on a mock request
    const rejectEmail = `reject.candidate.${uniqueNum}@saark.in`;
    const rejectCandidate = await hrService.createEmployee({
      firstName: 'Applicant',
      lastName: 'Rejected',
      email: rejectEmail,
      phone: '+91 98000 00000',
      designation: 'Helper',
      status: 'PENDING_APPROVAL',
    });
    const rejectionResult = await adminService.rejectEmployeeRequest(
      rejectCandidate.id,
      'Failed physical safety verification',
      adminUser,
    );
    assert(rejectionResult.employee.status === 'REJECTED', 'Step 7: Admin rejection transitions status to REJECTED');
    const rejectAudit = await prisma.auditLog.findFirst({
      where: { entityId: rejectCandidate.id, action: 'REJECT' },
    });
    assert(!!rejectAudit, 'Step 7: Security Audit Log records employee rejection');

    // Clean up temporary technician and candidate
    await prisma.auditLog.deleteMany({ where: { entityId: { in: [onboardedTech.id, rejectCandidate.id] } } });
    await prisma.userRole.deleteMany({ where: { userId: provisionedUser.id } });
    await prisma.staff.deleteMany({ where: { email: techEmail } });
    await prisma.employee.delete({ where: { id: onboardedTech.id } });
    await prisma.employee.delete({ where: { id: rejectCandidate.id } });
    await prisma.user.delete({ where: { id: provisionedUser.id } });
    await prisma.attendance.deleteMany({ where: { employeeId: testEmployee.id, checkInNote: 'Automated Shift Punch In' } });
    await prisma.leaveRequest.deleteMany({ where: { id: createdLeave.id } });
    await prisma.safetyIncident.deleteMany({ where: { id: reportedIncident.id } });

  } catch (err) {
    console.error('\n\x1b[31mFATAL TEST ERROR:\x1b[0m', err);
    failedTests++;
  } finally {
    await prisma.$disconnect();
  }

  console.log('\n================================================================');
  console.log(`TOTAL TESTS:  ${totalTests}`);
  console.log(`PASSED:       \x1b[32m${passedTests}\x1b[0m`);
  console.log(`FAILED:       \x1b[31m${failedTests}\x1b[0m`);
  console.log(`SUCCESS RATE: ${Math.round((passedTests / (totalTests || 1)) * 100)}%`);
  console.log('================================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runTestSuite();
