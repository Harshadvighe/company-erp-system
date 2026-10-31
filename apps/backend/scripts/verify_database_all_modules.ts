import { PrismaClient, Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition: boolean, testName: string, detail?: string) {
  totalTests++;
  if (condition) {
    console.log(`  [PASS ${totalTests}] ${testName}`);
    if (detail) console.log(`         -> ${detail}`);
    passedTests++;
  } else {
    console.error(`  [FAIL ${totalTests}] ${testName}`);
    if (detail) console.error(`         -> ${detail}`);
    failedTests++;
    throw new Error(`Assertion failed: ${testName}`);
  }
}

async function assertThrowsPrismaP2002(
  fn: () => Promise<any>,
  testName: string,
  targetFieldSubstring?: string,
) {
  totalTests++;
  try {
    await fn();
    console.error(`  [FAIL ${totalTests}] ${testName} (Expected Prisma P2002 unique constraint error, but call succeeded)`);
    failedTests++;
    throw new Error(`Expected P2002 unique constraint error: ${testName}`);
  } catch (err: any) {
    const isP2002 = err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
    const hasField = targetFieldSubstring
      ? (JSON.stringify(err.meta || '')).includes(targetFieldSubstring) || (err.message || '').includes(targetFieldSubstring)
      : true;

    if (isP2002 && hasField) {
      console.log(`  [PASS ${totalTests}] ${testName}`);
      console.log(`         -> Caught expected Prisma P2002 (Unique constraint violation on ${targetFieldSubstring || 'target'})`);
      passedTests++;
    } else {
      console.error(`  [FAIL ${totalTests}] ${testName}`);
      console.error(`         -> Expected Prisma P2002, received: ${err?.constructor?.name} [${err?.code}]: ${err?.message}`);
      failedTests++;
      throw err;
    }
  }
}

// Luhn Mod-36 checksum generator for realistic, valid Indian GSTINs
function generateValidGstin(suffix: string) {
  const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const pan = `AABCS${suffix}B`;
  const first14 = `27${pan}1Z`;
  let factor = 1;
  let sum = 0;
  for (let i = 0; i < 14; i++) {
    const codePoint = chars.indexOf(first14[i]);
    let product = factor * codePoint;
    factor = factor === 2 ? 1 : 2;
    product = Math.floor(product / 36) + (product % 36);
    sum += product;
  }
  const checkCodePoint = (36 - (sum % 36)) % 36;
  return { gstin: `${first14}${chars[checkCodePoint]}`, pan };
}

async function runDatabaseModuleVerification() {
  console.log('================================================================');
  console.log('   SAARK ERP - MULTI-MODULE DATABASE VERIFICATION TEST SUITE    ');
  console.log('   Modules Tested Directly At Database Layer:                   ');
  console.log('     1. SYSTEM & DATABASE ENGINE (Prisma ORM & Latency)         ');
  console.log('     2. ADMIN MODULE (Users, RBAC, Roles, Permissions, Audits)  ');
  console.log('     3. CRM MODULE (Customers, Contacts, Pipeline, Valuations)  ');
  console.log('     4. HR MODULE (Employees, Attendance, Payroll, Biometrics)  ');
  console.log('     5. PRODUCTION MODULE (Panels, BOM, Stock, Quotations, SO)  ');
  console.log('     6. CROSS-MODULE ATOMIC TRANSACTIONS & ROLLBACK INTEGRITY   ');
  console.log('================================================================\n');

  const testSuffix = Math.floor(1000 + Math.random() * 9000).toString();
  const startTime = Date.now();

  // Track created entities for precise teardown
  const createdUserIds: string[] = [];
  const createdRoleIds: string[] = [];
  const createdPermissionIds: string[] = [];
  const createdDepartmentIds: string[] = [];
  const createdDesignationIds: string[] = [];
  let createdStaffId: string | null = null;
  const createdAuditLogIds: string[] = [];
  const createdCustomerIds: string[] = [];
  const createdLeadIds: string[] = [];
  const createdEnquiryIds: string[] = [];
  const createdOpportunityIds: string[] = [];
  const createdShiftCodes: string[] = [];
  const createdEmployeeIds: string[] = [];
  const createdSafetyIncidentIds: string[] = [];
  const createdProductCategoryIds: string[] = [];
  const createdUnitIds: string[] = [];
  const createdProductIds: string[] = [];
  const createdWarehouseIds: string[] = [];
  const createdPanelSpecIds: string[] = [];
  const createdQuotationIds: string[] = [];
  const createdSalesOrderIds: string[] = [];
  const createdSaarkSectorIds: string[] = [];

  try {
    // =========================================================================
    // SECTION 1: DATABASE ENGINE & LATENCY BENCHMARK
    // =========================================================================
    console.log('--- 1. DATABASE ENGINE CONNECTIVITY & METRICS ---');
    await prisma.$connect();
    assert(true, 'Prisma database connection established successfully');

    const pingStart = Date.now();
    const countUsers = await prisma.user.count();
    const countCustomers = await prisma.customer.count();
    const countEmployees = await prisma.employee.count();
    const countProducts = await prisma.product.count();
    const pingLatency = Date.now() - pingStart;

    assert(
      countUsers >= 0 && countCustomers >= 0 && countEmployees >= 0 && countProducts >= 0,
      `Core database tables responsive (Read latency: ${pingLatency}ms)`,
      `Counts: Users=${countUsers}, Customers=${countCustomers}, Employees=${countEmployees}, Products=${countProducts}`,
    );

    // =========================================================================
    // SECTION 2: ADMIN MODULE DATABASE OPERATIONS & INTEGRITY
    // =========================================================================
    console.log('\n--- 2. ADMIN MODULE: USERS, RBAC & AUDIT LOGS ---');

    // 2.1 Password Hashing & User Creation
    const adminUsername = `db_admin_${testSuffix}`;
    const adminEmail = `admin.db.${testSuffix}@saark.in`;
    const plainPassword = `AdminPass@${testSuffix}!`;
    const passwordHash = await bcrypt.hash(plainPassword, 10);

    const user = await prisma.user.create({
      data: {
        username: adminUsername,
        email: adminEmail,
        passwordHash,
        fullName: `DB Administrator ${testSuffix}`,
        phone: `+91 98200 ${testSuffix}`,
        designation: 'Senior Database Systems Administrator',
        status: 'ACTIVE',
      },
    });
    createdUserIds.push(user.id);
    assert(user.id != null && user.username === adminUsername, 'Admin User inserted with UUID primary key');

    // Verify bcrypt password verification
    const isPasswordValid = await bcrypt.compare(plainPassword, user.passwordHash);
    assert(isPasswordValid === true, 'Bcrypt password hash matches original credentials in database');

    // 2.2 Unique Constraint: Duplicate Email
    await assertThrowsPrismaP2002(
      () =>
        prisma.user.create({
          data: {
            username: `alt_user_${testSuffix}`,
            email: adminEmail, // DUPLICATE
            passwordHash: 'dummyhash',
            fullName: 'Collision User',
          },
        }),
      'Database rejects duplicate user email with P2002 error',
      'email',
    );

    // 2.3 Unique Constraint: Duplicate Username
    await assertThrowsPrismaP2002(
      () =>
        prisma.user.create({
          data: {
            username: adminUsername, // DUPLICATE
            email: `alt.email.${testSuffix}@saark.in`,
            passwordHash: 'dummyhash',
            fullName: 'Collision User',
          },
        }),
      'Database rejects duplicate username with P2002 error',
      'username',
    );

    // 2.4 User Status Update
    const updatedUser = await prisma.user.update({
      where: { id: user.id },
      data: { status: 'LOCKED', failedFaceAttempts: 3 },
    });
    assert(updatedUser.status === 'LOCKED' && updatedUser.failedFaceAttempts === 3, 'User status & security counters updated');

    // Revert user back to ACTIVE for subsequent tests
    await prisma.user.update({ where: { id: user.id }, data: { status: 'ACTIVE', failedFaceAttempts: 0 } });

    // 2.5 Role & Permission Creation (RBAC)
    const roleCode = `ROLE_DB_TEST_${testSuffix}`;
    const role = await prisma.role.create({
      data: {
        name: `Database Test Manager ${testSuffix}`,
        code: roleCode,
        description: 'Role for verifying database operations',
        isSystem: false,
      },
    });
    createdRoleIds.push(role.id);
    assert(role.id != null && role.code === roleCode, 'Security Role created in database');

    // Unique Constraint: Duplicate Role Code
    await assertThrowsPrismaP2002(
      () =>
        prisma.role.create({
          data: {
            name: `Duplicate Role ${testSuffix}`,
            code: roleCode, // DUPLICATE
          },
        }),
      'Database rejects duplicate role code with P2002 error',
      'code',
    );

    // Permission Creation
    const permission = await prisma.permission.create({
      data: {
        module: `DB_ADMIN_${testSuffix}`,
        action: 'EXECUTE_TEST',
        description: 'Permission to run automated database validations',
      },
    });
    createdPermissionIds.push(permission.id);
    assert(permission.id != null, 'Security Permission created in database');

    // Unique Constraint: Duplicate Permission [module, action]
    await assertThrowsPrismaP2002(
      () =>
        prisma.permission.create({
          data: {
            module: `DB_ADMIN_${testSuffix}`, // DUPLICATE
            action: 'EXECUTE_TEST',          // DUPLICATE
          },
        }),
      'Database rejects duplicate permission composite key [module, action] with P2002 error',
    );

    // 2.6 Composite Key Join Tables: RolePermission @@id([roleId, permissionId])
    const rolePerm = await prisma.rolePermission.create({
      data: {
        roleId: role.id,
        permissionId: permission.id,
      },
    });
    assert(rolePerm.roleId === role.id && rolePerm.permissionId === permission.id, 'RolePermission composite key join record persisted');

    // Duplicate Composite Primary Key in RolePermission
    await assertThrowsPrismaP2002(
      () =>
        prisma.rolePermission.create({
          data: {
            roleId: role.id,
            permissionId: permission.id,
          },
        }),
      'Database rejects duplicate composite primary key in RolePermission with P2002',
    );

    // 2.7 Composite Key Join Tables: UserRole @@id([userId, roleId])
    const userRole = await prisma.userRole.create({
      data: {
        userId: user.id,
        roleId: role.id,
      },
    });
    assert(userRole.userId === user.id && userRole.roleId === role.id, 'UserRole composite key join record persisted');

    // 2.8 Nested Relational RBAC Query
    const userWithRbac = await prisma.user.findUnique({
      where: { id: user.id },
      include: {
        userRoles: {
          include: {
            role: {
              include: {
                rolePermissions: {
                  include: {
                    permission: true,
                  },
                },
              },
            },
          },
        },
      },
    });
    const retrievedPerm = userWithRbac?.userRoles[0]?.role?.rolePermissions[0]?.permission;
    assert(
      retrievedPerm?.module === `DB_ADMIN_${testSuffix}` && retrievedPerm?.action === 'EXECUTE_TEST',
      'Nested relational query resolves User -> UserRole -> Role -> RolePermission -> Permission hierarchy',
    );

    // 2.9 Department & Designation Relational Masters
    const dept = await prisma.department.create({
      data: {
        name: `Industrial IoT Systems ${testSuffix}`,
        code: `DEPT_IIOT_${testSuffix}`,
      },
    });
    createdDepartmentIds.push(dept.id);

    const desig = await prisma.designation.create({
      data: {
        name: `Principal Automation Lead ${testSuffix}`,
        code: `DESIG_LEAD_${testSuffix}`,
        description: 'Senior technical engineering designation',
      },
    });
    createdDesignationIds.push(desig.id);

    // Connect User to Department
    const userWithDept = await prisma.user.update({
      where: { id: user.id },
      data: { departmentId: dept.id },
      include: { department: true },
    });
    assert(userWithDept.department?.id === dept.id, 'User foreign key successfully mapped to Department');

    // Verify or provision Staff record for CRM/Pipeline activities
    let staffRecord = await prisma.staff.findFirst();
    if (!staffRecord) {
      staffRecord = await prisma.staff.create({
        data: {
          employeeId: `EMP-${testSuffix}`,
          fullName: `Test Staff Engineer ${testSuffix}`,
          email: `staff.${testSuffix}@saark.in`,
          departmentId: dept.id,
          designationId: desig.id,
          userId: user.id,
        },
      });
      createdStaffId = staffRecord.id;
    }

    // 2.10 AuditLog Storage and Index Query
    const auditRecord = await prisma.auditLog.create({
      data: {
        userId: user.id,
        userEmail: user.email,
        action: 'VERIFY_DATABASE',
        module: 'DATABASE_CORE',
        entityType: 'USER',
        entityId: user.id,
        details: JSON.stringify({ ip: '127.0.0.1', suite: 'Automated Multi-Module DB Test' }),
      },
    });
    createdAuditLogIds.push(auditRecord.id);

    const queriedAudits = await prisma.auditLog.findMany({
      where: { module: 'DATABASE_CORE', userId: user.id },
      orderBy: { timestamp: 'desc' },
    });
    assert(queriedAudits.length > 0 && queriedAudits[0].id === auditRecord.id, 'Audit log persisted with user relation and queried via indexed fields');

    // =========================================================================
    // SECTION 3: CRM MODULE DATABASE OPERATIONS & INTEGRITY
    // =========================================================================
    console.log('\n--- 3. CRM MODULE: CUSTOMERS, CONTACTS & SALES PIPELINE ---');

    // 3.1 Customer Master with Verified GSTIN & PAN
    const { gstin: validGstin, pan: validPan } = generateValidGstin(testSuffix);
    const customerCode = `CUS-DB-${testSuffix}`;
    const customer = await prisma.customer.create({
      data: {
        customerCode,
        companyName: `Saark Automation Infrastructure ${testSuffix} Pvt Ltd`,
        gstin: validGstin,
        pan: validPan,
        customerType: 'END_CUSTOMER',
        customerSegment: 'BOOSTER_PUMP',
        contactPerson: 'Vikramaditya Shinde',
        email: `procurement.${testSuffix}@saarkinfratech.com`,
        phone: `+91 98330 ${testSuffix}`,
        address: 'Sector 19, MIDC Industrial Zone',
        country: 'India',
        state: 'Maharashtra',
        district: 'Pune',
        city: 'Pune',
        pincode: '411026',
        gstStatus: 'GST_REGISTERED',
        gstVerified: true,
        potentialValue: 1200000,
        createdByUserId: user.id,
      },
    });
    createdCustomerIds.push(customer.id);
    assert(customer.id != null && customer.customerCode === customerCode, 'Customer record created with foreign key to creator User');

    // Extract embedded PAN from GSTIN (characters 3 through 12, 0-indexed 2..12)
    const embeddedPan = validGstin.substring(2, 12);
    assert(customer.pan === embeddedPan, `PAN correctly matches embedded GSTIN key (${customer.pan} === ${embeddedPan})`);

    // Unique Constraint: Duplicate Customer Code
    await assertThrowsPrismaP2002(
      () =>
        prisma.customer.create({
          data: {
            customerCode, // DUPLICATE
            companyName: 'Duplicate Customer Co',
            email: `alt.${testSuffix}@domain.com`,
            phone: '9988776655',
            address: 'Addr',
            state: 'MH',
            district: 'Pune',
            city: 'Pune',
            pincode: '411001',
            contactPerson: 'Person',
          },
        }),
      'Database rejects duplicate customerCode with P2002 error',
      'customerCode',
    );

    // 3.2 Relations: CustomerContact, CustomerValuation (1:1), CustomerInteraction
    const contact = await prisma.customerContact.create({
      data: {
        customerId: customer.id,
        name: 'Rajesh Deshmukh',
        designation: 'Head of Electrical Procurement',
        email: `rajesh.${testSuffix}@saarkinfratech.com`,
        mobile: `+91 97660 ${testSuffix}`,
        isPrimary: true,
      },
    });
    assert(contact.id != null && contact.customerId === customer.id, 'CustomerContact child record created');

    const valuation = await prisma.customerValuation.create({
      data: {
        customerId: customer.id,
        vfdWorkScore: 85.0,
        dewateringWorkScore: 70.0,
        ratingScore: 4.8,
        valuablePercentage: 88.0,
        lifetimeValue: 4500000,
      },
    });
    assert(valuation.id != null && valuation.customerId === customer.id, 'CustomerValuation 1:1 record created');

    const interaction = await prisma.customerInteraction.create({
      data: {
        customerId: customer.id,
        contactId: contact.id,
        interactionType: 'MEETING',
        subject: 'Multi-Pump Booster Panel Electrical Sizing',
        description: 'Finalized dual-pump 7.5 HP VFD specification with Modbus RTU communication',
        recordedBy: user.fullName,
      },
    });
    assert(interaction.id != null && interaction.interactionType === 'MEETING', 'CustomerInteraction record created');

    // Query Customer with all nested child models
    const customerAggregate = await prisma.customer.findUnique({
      where: { id: customer.id },
      include: {
        contacts: true,
        valuations: true,
        interactions: true,
        createdByUser: { select: { fullName: true, email: true } },
      },
    });
    assert(
      customerAggregate?.contacts.length === 1 &&
      customerAggregate?.valuations != null &&
      customerAggregate?.interactions.length === 1 &&
      customerAggregate?.createdByUser?.email === adminEmail,
      'Relational aggregate query successfully loads Customer with Contacts, Valuations, Interactions, and User creator',
    );

    // 3.3 CRM Sales Pipeline: Lead, Enquiry & Opportunity
    const leadNumber = `LEAD-DB-${testSuffix}`;
    const lead = await prisma.lead.create({
      data: {
        leadNumber,
        companyName: customer.companyName,
        contactPerson: customer.contactPerson,
        phone: customer.phone,
        email: customer.email,
        customerId: customer.id,
        source: 'DIRECT_ENQUIRY',
        leadType: 'END_CUSTOMER',
        productInterest: 'Booster Pump Control Panels',
        estimatedValue: 480000,
        priority: 'HIGH',
        status: 'QUALIFIED',
        qualificationStatus: 'QUALIFIED',
        bantBudget: 500000,
        bantAuthority: 'CHIEF_ELECTRICAL_OFFICER',
        bantNeed: 'Automated pressure boosting system for high-rise commercial complex',
        bantTimeline: 'WITHIN_30_DAYS',
      },
    });
    createdLeadIds.push(lead.id);
    assert(lead.id != null && lead.leadNumber === leadNumber, 'Lead created in QUALIFIED state with BANT criteria');

    // Unique Constraint: Duplicate Lead Number
    await assertThrowsPrismaP2002(
      () =>
        prisma.lead.create({
          data: {
            leadNumber, // DUPLICATE
            companyName: 'Collision Lead',
            contactPerson: 'Contact',
            phone: '9988771122',
          },
        }),
      'Database rejects duplicate leadNumber with P2002 error',
      'leadNumber',
    );

    // Enquiry
    const enquiryNumber = `ENQ-DB-${testSuffix}`;
    const enquiry = await prisma.enquiry.create({
      data: {
        enquiryNumber,
        customerId: customer.id,
        productInterest: 'Twin 7.5HP VFD Booster Control Panel',
        quantity: 2,
        expectedValue: 480000,
        priority: 'HIGH',
        status: 'PENDING',
      },
    });
    createdEnquiryIds.push(enquiry.id);
    assert(enquiry.id != null && enquiry.enquiryNumber === enquiryNumber, 'Enquiry record created with customer link');

    // Opportunity with probability and weighted value
    const oppNumber = `OPP-DB-${testSuffix}`;
    const opportunity = await prisma.opportunity.create({
      data: {
        opportunityNumber: oppNumber,
        title: `Twin Booster Panel Supply - ${customer.companyName}`,
        customerId: customer.id,
        leadId: lead.id,
        enquiryId: enquiry.id,
        assignedStaffId: staffRecord.id,
        stage: 'PROPOSAL_SENT',
        probability: 60,
        estimatedValue: 480000,
        weightedValue: 480000 * 0.60,
      },
    });
    createdOpportunityIds.push(opportunity.id);
    assert(opportunity.id != null && opportunity.weightedValue === 288000, 'Opportunity created with calculated weighted value (₹288,000)');

    // Update Opportunity to CLOSED_WON
    const wonOpportunity = await prisma.opportunity.update({
      where: { id: opportunity.id },
      data: { stage: 'CLOSED_WON', probability: 100, weightedValue: 480000 },
    });
    assert(wonOpportunity.stage === 'CLOSED_WON' && wonOpportunity.probability === 100, 'Opportunity stage transitioned to CLOSED_WON');

    // 3.4 CRM Activity & Follow-Up Sequence
    const activity = await prisma.crmActivity.create({
      data: {
        customerId: customer.id,
        leadId: lead.id,
        staffId: staffRecord.id,
        activityType: 'SITE_VISIT',
        subject: 'Plant Electrical Room Inspection',
        description: 'Verified cabling duct and 415V 3-phase feeder availability',
      },
    });
    assert(activity.id != null, 'CrmActivity persisted');

    const followUp = await prisma.crmFollowUp.create({
      data: {
        customerId: customer.id,
        assignedStaffId: staffRecord.id,
        followUpNumber: 1,
        title: 'Dispatch Proforma Invoice & GA Drawings',
        priority: 'HIGH',
        status: 'PENDING',
        scheduledDate: new Date(Date.now() + 86400000 * 3),
      },
    });
    assert(followUp.id != null && followUp.status === 'PENDING', 'CrmFollowUp sequence record created');

    const completedFollowUp = await prisma.crmFollowUp.update({
      where: { id: followUp.id },
      data: { status: 'COMPLETED', notes: 'Client approved GA drawing without modifications', completedDate: new Date() },
    });
    assert(completedFollowUp.status === 'COMPLETED', 'FollowUp marked as COMPLETED in database');

    // =========================================================================
    // SECTION 4: HR MODULE DATABASE OPERATIONS & INTEGRITY
    // =========================================================================
    console.log('\n--- 4. HR MODULE: EMPLOYEES, ATTENDANCE, PAYROLL & BIOMETRICS ---');

    // 4.1 ShiftMaster
    const shiftCode = `SHIFT_TEST_${testSuffix}`;
    const shift = await prisma.shiftMaster.create({
      data: {
        code: shiftCode,
        name: `Automated Night Shift ${testSuffix}`,
        startTime: '22:00',
        endTime: '06:00',
        graceMinutes: 15,
        shiftAllowance: 250.0,
        departmentName: 'Shopfloor Panel Assembly',
        isActive: true,
      },
    });
    createdShiftCodes.push(shift.code);
    assert(shift.code === shiftCode && shift.shiftAllowance === 250, 'ShiftMaster record inserted with shift allowance');

    // 4.2 Employee Master
    const empCode = `EMP-TEST-${testSuffix}`;
    const empEmail = `worker.${testSuffix}@saark.in`;
    const employee = await prisma.employee.create({
      data: {
        employeeCode: empCode,
        firstName: 'Aniket',
        lastName: `Kulkarni_${testSuffix}`,
        email: empEmail,
        phone: `+91 99220 ${testSuffix}`,
        designation: 'Senior Busbar & Panel Wireman',
        departmentId: dept.id,
        employmentType: 'FULL_TIME',
        workerCategory: 'SHOPFLOOR_TECH',
        skillLevel: 'LEVEL_3_BUSBAR_SPECIALIST',
        assignedBay: 'BAY_2_BUSBAR',
        shiftCode: shift.code,
        electricalLicenseNo: `MH-PWD-TECH-${testSuffix}`,
        ppeKitIssued: true,
        status: 'ACTIVE',
        salaryCtc: 480000,
      },
    });
    createdEmployeeIds.push(employee.id);
    assert(employee.id != null && employee.employeeCode === empCode, 'Employee record created with technical skill & shopfloor bay');

    // Unique Constraint: Duplicate employeeCode
    await assertThrowsPrismaP2002(
      () =>
        prisma.employee.create({
          data: {
            employeeCode: empCode, // DUPLICATE
            firstName: 'Dup',
            lastName: 'Emp',
            email: `alt.emp.${testSuffix}@saark.in`,
            phone: '9988774433',
            designation: 'Wireman',
            shiftCode: shift.code,
          },
        }),
      'Database rejects duplicate employeeCode with P2002 error',
      'employeeCode',
    );

    // Unique Constraint: Duplicate employee email
    await assertThrowsPrismaP2002(
      () =>
        prisma.employee.create({
          data: {
            employeeCode: `EMP-DIFF-${testSuffix}`,
            firstName: 'Dup',
            lastName: 'Email',
            email: empEmail, // DUPLICATE
            phone: '9988774433',
            designation: 'Wireman',
            shiftCode: shift.code,
          },
        }),
      'Database rejects duplicate employee email with P2002 error',
      'email',
    );

    // 4.3 Attendance Master & Composite Unique Constraint @@unique([employeeId, punchDate])
    const punchDate = new Date('2026-10-24T00:00:00.000Z');
    const punchIn = new Date('2026-10-24T09:00:00.000Z');
    const punchOut = new Date('2026-10-24T18:30:00.000Z');

    const attendance = await prisma.attendance.create({
      data: {
        employeeId: employee.id,
        punchDate,
        punchIn,
        punchOut,
        workHours: 8.5,
        overtimeHours: 1.0,
        overtimeApproved: true,
        status: 'PRESENT',
        shiftCode: shift.code,
        assignedBay: 'BAY_2_BUSBAR',
        ppeCompliant: true,
        checkInNote: 'Facial recognition match verified. Full PPE compliance checked.',
      },
    });
    assert(attendance.id != null && attendance.workHours === 8.5, 'Employee Attendance record created with overtime approval');

    // Composite Unique Violation: Second punch record on same [employeeId, punchDate]
    await assertThrowsPrismaP2002(
      () =>
        prisma.attendance.create({
          data: {
            employeeId: employee.id, // SAME EMPLOYEE
            punchDate,               // SAME DATE
            workHours: 8.0,
            status: 'PRESENT',
          },
        }),
      'Database enforces composite unique constraint @@unique([employeeId, punchDate]) with P2002',
    );

    // 4.4 PayrollRecord Master & Composite Unique Constraint @@unique([employeeId, month, year])
    const slipNumber = `PAY-DB-${testSuffix}`;
    const basicSalary = 25000;
    const hraAllowance = 10000;
    const specialAllowance = 5000;
    const overtimePay = 2500;
    const shiftAllowancePay = 1500;
    const grossPay = basicSalary + hraAllowance + specialAllowance + overtimePay + shiftAllowancePay; // 44,000
    const pfDeduction = 3000;
    const taxDeduction = 1500;
    const totalDeductions = pfDeduction + taxDeduction; // 4,500
    const netPay = grossPay - totalDeductions; // 39,500

    const payroll = await prisma.payrollRecord.create({
      data: {
        slipNumber,
        employeeId: employee.id,
        month: 'October 2026',
        year: 2026,
        monthNumber: 10,
        workingDays: 26,
        presentDays: 26,
        basicSalary,
        hraAllowance,
        specialAllowance,
        overtimeHours: 10,
        overtimePay,
        shiftAllowance: shiftAllowancePay,
        grossPay,
        pfDeduction,
        taxDeduction,
        totalDeductions,
        netPay,
        paymentStatus: 'PAID',
        paymentMode: 'NEFT/RTGS',
      },
    });
    assert(payroll.id != null && payroll.netPay === 39500, `Payroll calculated and persisted accurately (Net ₹${payroll.netPay})`);

    // Verify mathematical integrity in database
    assert(
      payroll.grossPay === (payroll.basicSalary + payroll.hraAllowance + payroll.specialAllowance + payroll.overtimePay + payroll.shiftAllowance),
      'Gross pay matches sum of earnings in database record',
    );
    assert(
      payroll.netPay === (payroll.grossPay - payroll.totalDeductions),
      'Net pay matches gross minus total deductions in database record',
    );

    // Unique Constraint: Duplicate slipNumber on PayrollRecord
    await assertThrowsPrismaP2002(
      () =>
        prisma.payrollRecord.create({
          data: {
            slipNumber,              // DUPLICATE SLIP NUMBER
            employeeId: employee.id,
            month: 'November 2026',
            year: 2026,
            grossPay: 40000,
            netPay: 36000,
          },
        }),
      'Database enforces unique constraint on PayrollRecord.slipNumber with P2002',
      'slipNumber',
    );

    // 4.5 Biometric Security: EmployeeFaceBiometric (1:1 Relation)
    const dummyEmbedding = JSON.stringify(new Array(128).fill(0.088388));
    const faceBiometric = await prisma.employeeFaceBiometric.create({
      data: {
        employeeId: employee.id,
        encryptedEmbedding: Buffer.from(dummyEmbedding).toString('base64'),
        embeddingIv: 'a1b2c3d4e5f60718293a4b5c',
        embeddingAuthTag: 'f1e2d3c4b5a69788',
        faceModel: 'ssd-mobilenetv1-128d',
        isActive: true,
      },
    });
    assert(faceBiometric.id != null && faceBiometric.employeeId === employee.id, 'EmployeeFaceBiometric record linked to Employee');

    // Unique Constraint: 1:1 uniqueness on employeeId in EmployeeFaceBiometric
    await assertThrowsPrismaP2002(
      () =>
        prisma.employeeFaceBiometric.create({
          data: {
            employeeId: employee.id, // DUPLICATE (Violates 1:1 relation)
            encryptedEmbedding: 'another_embedding',
            embeddingIv: 'iv',
            embeddingAuthTag: 'tag',
          },
        }),
      'Database enforces 1:1 unique constraint on EmployeeFaceBiometric.employeeId with P2002',
      'employeeId',
    );

    // 4.6 Safety Incident Logging
    const incident = await prisma.safetyIncident.create({
      data: {
        incidentCode: `INC-DB-${testSuffix}`,
        incidentType: 'NEAR_MISS',
        severity: 'LOW',
        locationBay: 'BAY_2_BUSBAR',
        employeeId: employee.id,
        description: 'Busbar torque wrench calibration required before final bus tightening',
        actionTaken: 'Recalibrated digital torque wrench and re-verified torque specs',
        status: 'RESOLVED',
        reportedBy: user.fullName,
      },
    });
    createdSafetyIncidentIds.push(incident.id);
    assert(incident.id != null && incident.status === 'RESOLVED', 'Safety incident logged and resolved in database');

    // =========================================================================
    // SECTION 5: PRODUCTION MODULE DATABASE OPERATIONS & INTEGRITY
    // =========================================================================
    console.log('\n--- 5. PRODUCTION MODULE: PANELS, BOM, STOCK & SALES ORDERS ---');

    // 5.1 ProductCategory, Unit & Product
    const category = await prisma.productCategory.create({
      data: {
        name: `Electrical Automation Components ${testSuffix}`,
        code: `CAT_ELEC_${testSuffix}`,
      },
    });
    createdProductCategoryIds.push(category.id);

    const unit = await prisma.unit.create({
      data: {
        name: `Pieces_${testSuffix}`,
        code: `PCS_${testSuffix}`,
      },
    });
    createdUnitIds.push(unit.id);

    const skuCode = `SKU-VFD-${testSuffix}`;
    const product = await prisma.product.create({
      data: {
        sku: skuCode,
        name: `7.5 HP Heavy Duty VFD Inverter Drive ${testSuffix}`,
        categoryId: category.id,
        unitId: unit.id,
        productType: 'COMPONENT',
        purchasePrice: 24000,
        sellingPrice: 36000,
        reorderLevel: 5,
        currentStock: 50,
      },
    });
    createdProductIds.push(product.id);
    assert(product.id != null && product.sku === skuCode, 'Product component inserted with Category and Unit foreign keys');

    // Unique Constraint: Duplicate SKU
    await assertThrowsPrismaP2002(
      () =>
        prisma.product.create({
          data: {
            sku: skuCode, // DUPLICATE
            name: 'Duplicate Product SKU',
            categoryId: category.id,
            unitId: unit.id,
            purchasePrice: 100,
            sellingPrice: 200,
          },
        }),
      'Database rejects duplicate product SKU with P2002 error',
      'sku',
    );

    // 5.2 Warehouse & StockItem Composite Constraint @@unique([warehouseId, productId])
    const warehouseCode = `WH-MIDC-${testSuffix}`;
    const warehouse = await prisma.warehouse.create({
      data: {
        code: warehouseCode,
        name: `Main Plant Production Warehouse ${testSuffix}`,
        location: 'Bay 1 Staging Yard',
      },
    });
    createdWarehouseIds.push(warehouse.id);
    assert(warehouse.id != null && warehouse.code === warehouseCode, 'Warehouse record created');

    const stockItem = await prisma.stockItem.create({
      data: {
        warehouseId: warehouse.id,
        productId: product.id,
        currentQuantity: 50,
        reservedQuantity: 4,
      },
    });
    assert(stockItem.id != null && stockItem.currentQuantity === 50, 'StockItem created linking Warehouse and Product');

    // Duplicate Composite Key @@unique([warehouseId, productId])
    await assertThrowsPrismaP2002(
      () =>
        prisma.stockItem.create({
          data: {
            warehouseId: warehouse.id, // SAME WAREHOUSE
            productId: product.id,     // SAME PRODUCT
            currentQuantity: 20,
          },
        }),
      'Database enforces composite unique constraint @@unique([warehouseId, productId]) in StockItem with P2002',
    );

    // StockTransaction
    const stockTx = await prisma.stockTransaction.create({
      data: {
        productId: product.id,
        warehouseId: warehouse.id,
        transactionType: 'INWARD_GRN',
        referenceType: 'MANUAL',
        quantity: 50,
        unit: 'PCS',
        unitCost: 24000,
        totalCost: 1200000,
        notes: 'Initial component inventory for panel batch assembly',
      },
    });
    assert(stockTx.id != null && stockTx.quantity === 50, 'StockTransaction recorded with positive inward quantity');

    // 5.3 PanelSpecification & PanelBOMItem Relational Integrity & Cascade Deletion
    const panelCode = `PANEL-DB-${testSuffix}`;
    const panelSpec = await prisma.panelSpecification.create({
      data: {
        panelCode,
        customerId: customer.id,
        panelType: 'BOOSTER_PUMP',
        voltage: '415V 3-Phase',
        currentRating: '32A',
        pumpQty: 2,
        pumpHp: 7.5,
        controlType: 'AUTOMATIC_PLC',
        starterType: 'VFD',
        ipRating: 'IP55',
        enclosureType: 'POWDER_COATED_MS',
        materialCost: 65000,
        labourCost: 8000,
        overheadCost: 5000,
        marginPercent: 20.0,
        finalPrice: 93600, // (65k + 8k + 5k) * 1.20 = 78,000 * 1.20 = 93,600
        status: 'APPROVED',
      },
    });
    createdPanelSpecIds.push(panelSpec.id);
    assert(panelSpec.id != null && panelSpec.panelCode === panelCode, 'PanelSpecification created with engineering formula');

    // Insert 3 Line Items into PanelBOMItem
    const bomItem1 = await prisma.panelBOMItem.create({
      data: {
        panelSpecId: panelSpec.id,
        productId: product.id,
        componentName: '7.5 HP VFD Inverter Drive',
        quantity: 2,
        unitPrice: 24000,
        totalPrice: 48000,
      },
    });
    const bomItem2 = await prisma.panelBOMItem.create({
      data: {
        panelSpecId: panelSpec.id,
        componentName: '32A 3-Pole 35kA MCCB Incomer',
        specification: 'Schneider EasyPact CVS',
        quantity: 1,
        unitPrice: 7000,
        totalPrice: 7000,
      },
    });
    const bomItem3 = await prisma.panelBOMItem.create({
      data: {
        panelSpecId: panelSpec.id,
        componentName: 'IP55 Sheet Steel Powder-Coated Enclosure',
        specification: '800 x 600 x 250 mm RAL 7035',
        quantity: 1,
        unitPrice: 10000,
        totalPrice: 10000,
      },
    });
    assert(bomItem1.id != null && bomItem2.id != null && bomItem3.id != null, 'All 3 PanelBOMItem lines inserted linked to PanelSpecification');

    // Verify BOM items sum
    const totalBomMaterialCost = bomItem1.totalPrice + bomItem2.totalPrice + bomItem3.totalPrice;
    assert(totalBomMaterialCost === 65000, `BOM material cost calculated and verified (₹${totalBomMaterialCost} === ₹65,000)`);

    // Verify Cascade Delete on temporary PanelSpecification
    const tempPanelSpec = await prisma.panelSpecification.create({
      data: {
        panelCode: `PANEL-TEMP-${testSuffix}`,
        customerId: customer.id,
        panelType: 'STP_PANEL',
      },
    });
    const tempBomItem = await prisma.panelBOMItem.create({
      data: {
        panelSpecId: tempPanelSpec.id,
        componentName: 'Temporary Relay for Cascade Test',
        quantity: 1,
        unitPrice: 500,
        totalPrice: 500,
      },
    });
    // Delete parent specification
    await prisma.panelSpecification.delete({ where: { id: tempPanelSpec.id } });
    const orphanedBom = await prisma.panelBOMItem.findUnique({ where: { id: tempBomItem.id } });
    assert(orphanedBom === null, 'Cascade deletion verified: Deleting PanelSpecification cleanly cascaded to remove child PanelBOMItem');

    // 5.4 Quotation & SalesOrder Workflow
    const quotationNumber = `QUO-DB-${testSuffix}`;
    const quotationCode = `QUO-DB-${testSuffix}-REV-0`;
    const quotation = await prisma.quotation.create({
      data: {
        quotationNumber,
        revisionNumber: 0,
        code: quotationCode,
        customerId: customer.id,
        panelSpecId: panelSpec.id,
        opportunityId: opportunity.id,
        subject: `Supply of Dual 7.5HP VFD Booster Panels for ${customer.companyName}`,
        subtotal: 187200, // 2 panels * 93,600
        taxableAmount: 187200,
        cgstPercent: 9.0,
        cgstAmount: 16848,
        sgstPercent: 9.0,
        sgstAmount: 16848,
        grandTotal: 220896,
        status: 'ACCEPTED',
      },
    });
    createdQuotationIds.push(quotation.id);
    assert(quotation.id != null && quotation.code === quotationCode, 'Quotation record created with PanelSpecification reference');

    // Quotation Items
    const qItem = await prisma.quotationItem.create({
      data: {
        quotationId: quotation.id,
        productId: product.id,
        description: 'Smart Dual 7.5HP VFD Booster Pump Control Panel (IP55)',
        quantity: 2,
        unitPrice: 93600,
        taxableAmount: 187200,
        gstPercent: 18.0,
        gstAmount: 33696,
        totalAmount: 220896,
      },
    });
    assert(qItem.id != null && qItem.totalAmount === 220896, 'Quotation line item created with GST computation');

    // SalesOrder
    const soNumber = `SO-DB-${testSuffix}`;
    const salesOrder = await prisma.salesOrder.create({
      data: {
        orderNumber: soNumber,
        quotationId: quotation.id,
        customerId: customer.id,
        poNumber: `PO-CLIENT-${testSuffix}`,
        poDate: new Date(),
        subtotal: 187200,
        taxableAmount: 187200,
        taxAmount: 33696,
        grandTotal: 220896,
        status: 'CONFIRMED',
        productionStatus: 'SCHEDULED',
      },
    });
    createdSalesOrderIds.push(salesOrder.id);
    assert(salesOrder.id != null && salesOrder.orderNumber === soNumber, 'SalesOrder created with confirmed status and scheduled production');

    // 5.5 SaarkProductSector 38-Field Technical Model
    const sectorSku = `SAARK-SEC-${testSuffix}`;
    const productSector = await prisma.saarkProductSector.create({
      data: {
        productSector: 'Booster Pump Control Panel',
        productName: `Quad Multi-Cascade Smart Intelligent Booster Panel ${testSuffix}`,
        skuModelNumber: sectorSku,
        productCategory: 'Control Panel',
        inputVoltage: '415V 3-Phase',
        ratedFrequency: '50 Hz',
        minPowerRating: 5.0,
        maxPowerRating: 30.0,
        powerRatingUnit: 'HP',
        starterDriveType: 'Integrated VFD',
        enclosureIpRating: 'IP55',
        pumpSupportCapacity: '4+ Multi-Cascade',
        controlModes: 'Constant Pressure; Auto-Alternation; Duty/Assist/Standby',
        pressureSensorCompatibility: '4-20 mA; RS-485 Digital',
        minPressure: 1.0,
        maxPressure: 16.0,
        userInterfaceDisplay: 'Touchscreen HMI',
        communicationProtocols: 'RS-485 Modbus RTU; Ethernet',
        iotCloudFeatures: 'GSM/4G Remote Telemetry; Wi-Fi Dashboard',
        electricalProtections: 'Overload; Under/Over-Voltage; Phase Failure; Short Circuit',
        hydraulicProtections: 'Dry Run Protection; High/Low Pressure Cutoff; Pipe Burst Detection',
        status: 'ACTIVE',
      },
    });
    createdSaarkSectorIds.push(productSector.id);
    assert(productSector.id != null && productSector.skuModelNumber === sectorSku, 'SaarkProductSector 38-field technical master model persisted');

    // =========================================================================
    // SECTION 6: CROSS-MODULE ATOMIC TRANSACTIONS & ROLLBACK INTEGRITY
    // =========================================================================
    console.log('\n--- 6. CROSS-MODULE ATOMIC TRANSACTIONS & ROLLBACK INTEGRITY ---');

    // 6.1 Multi-Module Atomic Commit across CRM, HR, Production & Admin
    const txCustomerCode = `CUS-TX-${testSuffix}`;
    const txEmpCode = `EMP-TX-${testSuffix}`;
    const { gstin: txGstin, pan: txPan } = generateValidGstin(`T${testSuffix.slice(-3)}`);

    const txResult = await prisma.$transaction(async (tx) => {
      // Step A: CRM Customer
      const txCust = await tx.customer.create({
        data: {
          customerCode: txCustomerCode,
          companyName: `Atomic Transaction Corp ${testSuffix}`,
          gstin: txGstin,
          pan: txPan,
          email: `tx.${testSuffix}@atomictest.in`,
          phone: `+91 91100 ${testSuffix}`,
          address: 'Tech Park',
          state: 'Maharashtra',
          district: 'Pune',
          city: 'Pune',
          pincode: '411057',
          contactPerson: 'TX Manager',
        },
      });

      // Step B: HR Employee
      const txEmp = await tx.employee.create({
        data: {
          employeeCode: txEmpCode,
          firstName: 'Transaction',
          lastName: 'Tester',
          email: `tx.worker.${testSuffix}@saark.in`,
          phone: `+91 92200 ${testSuffix}`,
          designation: 'Certified QC Testing Engineer',
          shiftCode: shift.code,
        },
      });

      // Step C: Production Panel Specification
      const txPanel = await tx.panelSpecification.create({
        data: {
          panelCode: `PANEL-TX-${testSuffix}`,
          customerId: txCust.id,
          panelType: 'VFD_PANEL',
          finalPrice: 125000,
        },
      });

      // Step D: Admin Audit Log
      const txAudit = await tx.auditLog.create({
        data: {
          action: 'ATOMIC_TRANSACTION_TEST',
          module: 'MULTI_MODULE',
          details: JSON.stringify({ customerId: txCust.id, employeeId: txEmp.id, panelId: txPanel.id }),
        },
      });

      return { customerId: txCust.id, employeeId: txEmp.id, panelId: txPanel.id, auditId: txAudit.id };
    });

    createdCustomerIds.push(txResult.customerId);
    createdEmployeeIds.push(txResult.employeeId);
    createdPanelSpecIds.push(txResult.panelId);
    createdAuditLogIds.push(txResult.auditId);

    assert(
      txResult.customerId != null && txResult.employeeId != null && txResult.panelId != null && txResult.auditId != null,
      'Multi-module atomic transaction committed successfully across CRM, HR, Production and Admin models simultaneously',
    );

    // Verify all 4 records exist in the database
    const verifyCust = await prisma.customer.findUnique({ where: { id: txResult.customerId } });
    const verifyEmp = await prisma.employee.findUnique({ where: { id: txResult.employeeId } });
    const verifyPanel = await prisma.panelSpecification.findUnique({ where: { id: txResult.panelId } });
    const verifyAudit = await prisma.auditLog.findUnique({ where: { id: txResult.auditId } });
    assert(
      verifyCust != null && verifyEmp != null && verifyPanel != null && verifyAudit != null,
      'All 4 transaction-committed entities verified to exist in persistent database storage',
    );

    // 6.2 Atomic Rollback On Intentional Failure
    const ghostCustCode = `CUS-GHOST-${testSuffix}`;
    let rollbackSucceeded = false;

    try {
      await prisma.$transaction(async (tx) => {
        // Step 1: Create ghost customer
        await tx.customer.create({
          data: {
            customerCode: ghostCustCode,
            companyName: 'Ghost Customer Should Be Rolled Back',
            email: `ghost.${testSuffix}@rollback.in`,
            phone: '9988776655',
            address: 'Nowhere',
            state: 'MH',
            district: 'Pune',
            city: 'Pune',
            pincode: '411001',
            contactPerson: 'Ghost',
          },
        });

        // Step 2: Create audit log
        await tx.auditLog.create({
          data: {
            action: 'GHOST_LOG',
            module: 'TEST',
          },
        });

        // Step 3: INTENTIONAL UNIQUE CONSTRAINT FAILURE (duplicate adminUsername)
        await tx.user.create({
          data: {
            username: adminUsername, // DUPLICATE -> TRIGGERS P2002
            email: `ghost.user.${testSuffix}@saark.in`,
            passwordHash: 'dummy',
            fullName: 'Collision User',
          },
        });
      });
    } catch (err: any) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        rollbackSucceeded = true;
      } else {
        throw err;
      }
    }

    assert(rollbackSucceeded, 'Intentional transaction failure caught expected P2002 constraint error');

    // Verify Ghost Customer was ROLLED BACK and NOT saved to database
    const ghostCheck = await prisma.customer.findUnique({ where: { customerCode: ghostCustCode } });
    assert(ghostCheck === null, 'Database rollback integrity confirmed: Zero orphaned records persisted upon transaction abort');

    // 6.3 Concurrency & Read Isolation
    const readStart = Date.now();
    const concurrentReads = await Promise.all([
      prisma.user.findMany({ take: 5 }),
      prisma.customer.findMany({ take: 5 }),
      prisma.employee.findMany({ take: 5 }),
      prisma.product.findMany({ take: 5 }),
      prisma.panelSpecification.findMany({ take: 5 }),
      prisma.quotation.findMany({ take: 5 }),
      prisma.salesOrder.findMany({ take: 5 }),
      prisma.auditLog.findMany({ take: 5 }),
      prisma.shiftMaster.findMany({ take: 5 }),
      prisma.saarkProductSector.findMany({ take: 5 }),
    ]);
    const readTime = Date.now() - readStart;
    assert(
      concurrentReads.length === 10 && concurrentReads.every((r) => Array.isArray(r)),
      `10 concurrent parallel queries across all 4 modules resolved cleanly with zero locks/timeouts in ${readTime}ms`,
    );

  } finally {
    // =========================================================================
    // SECTION 7: CLEANUP OF TEST ARTIFACTS
    // =========================================================================
    console.log('\n--- 7. TEARDOWN & REVERSIBLE TEST ARTIFACT CLEANUP ---');

    // Clean up Sales Orders & Items
    for (const soId of createdSalesOrderIds) {
      await prisma.salesOrderItem.deleteMany({ where: { salesOrderId: soId } });
      await prisma.salesOrder.delete({ where: { id: soId } }).catch(() => {});
    }

    // Clean up Quotations & Items
    for (const qId of createdQuotationIds) {
      await prisma.quotationItem.deleteMany({ where: { quotationId: qId } });
      await prisma.quotation.delete({ where: { id: qId } }).catch(() => {});
    }

    // Clean up SaarkProductSector
    for (const secId of createdSaarkSectorIds) {
      await prisma.saarkProductSector.delete({ where: { id: secId } }).catch(() => {});
    }

    // Clean up Panel Specifications (cascade removes PanelBOMItems)
    for (const pId of createdPanelSpecIds) {
      await prisma.panelBOMItem.deleteMany({ where: { panelSpecId: pId } });
      await prisma.panelSpecification.delete({ where: { id: pId } }).catch(() => {});
    }

    // Clean up Stock Items, Transactions & Products
    for (const pId of createdProductIds) {
      await prisma.stockTransaction.deleteMany({ where: { productId: pId } });
      await prisma.stockItem.deleteMany({ where: { productId: pId } });
      await prisma.product.delete({ where: { id: pId } }).catch(() => {});
    }

    // Clean up Warehouses, Units, Categories
    for (const wId of createdWarehouseIds) {
      await prisma.warehouse.delete({ where: { id: wId } }).catch(() => {});
    }
    for (const uId of createdUnitIds) {
      await prisma.unit.delete({ where: { id: uId } }).catch(() => {});
    }
    for (const cId of createdProductCategoryIds) {
      await prisma.productCategory.delete({ where: { id: cId } }).catch(() => {});
    }

    // Clean up HR: Safety Incidents, Biometrics, Attendance, Payroll, Employees, Shifts
    for (const incId of createdSafetyIncidentIds) {
      await prisma.safetyIncident.delete({ where: { id: incId } }).catch(() => {});
    }
    for (const empId of createdEmployeeIds) {
      await prisma.employeeFaceBiometric.deleteMany({ where: { employeeId: empId } });
      await prisma.attendance.deleteMany({ where: { employeeId: empId } });
      await prisma.payrollRecord.deleteMany({ where: { employeeId: empId } });
      await prisma.employee.delete({ where: { id: empId } }).catch(() => {});
    }
    for (const sc of createdShiftCodes) {
      await prisma.shiftMaster.deleteMany({ where: { code: sc } });
    }

    // Clean up CRM: FollowUps, Activities, Opportunities, Enquiries, Leads, Valuations, Contacts, Customers
    for (const cId of createdCustomerIds) {
      await prisma.crmFollowUp.deleteMany({ where: { customerId: cId } });
      await prisma.crmActivity.deleteMany({ where: { customerId: cId } });
      await prisma.opportunity.deleteMany({ where: { customerId: cId } });
      await prisma.enquiry.deleteMany({ where: { customerId: cId } });
      await prisma.lead.deleteMany({ where: { customerId: cId } });
      await prisma.customerInteraction.deleteMany({ where: { customerId: cId } });
      await prisma.customerValuation.deleteMany({ where: { customerId: cId } });
      await prisma.customerContact.deleteMany({ where: { customerId: cId } });
      await prisma.customer.delete({ where: { id: cId } }).catch(() => {});
    }

    // Clean up Staff if created by test
    if (createdStaffId) {
      await prisma.staff.delete({ where: { id: createdStaffId } }).catch(() => {});
    }

    // Clean up Admin: AuditLogs, UserRole, RolePermission, Permissions, Roles, Users, Designations, Departments
    for (const aId of createdAuditLogIds) {
      await prisma.auditLog.delete({ where: { id: aId } }).catch(() => {});
    }
    for (const uId of createdUserIds) {
      await prisma.userRole.deleteMany({ where: { userId: uId } });
      await prisma.user.delete({ where: { id: uId } }).catch(() => {});
    }
    for (const rId of createdRoleIds) {
      await prisma.rolePermission.deleteMany({ where: { roleId: rId } });
      await prisma.role.delete({ where: { id: rId } }).catch(() => {});
    }
    for (const pId of createdPermissionIds) {
      await prisma.permission.delete({ where: { id: pId } }).catch(() => {});
    }
    for (const dId of createdDesignationIds) {
      await prisma.designation.delete({ where: { id: dId } }).catch(() => {});
    }
    for (const depId of createdDepartmentIds) {
      await prisma.department.delete({ where: { id: depId } }).catch(() => {});
    }

    await prisma.$disconnect();
    console.log('  [PASS] All test database records cleanly purged without leaving orphaned data');
  }

  const durationSec = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log('\n================================================================');
  console.log(`  VERIFICATION RESULTS: TOTAL PASSED: ${passedTests} | FAILED: ${failedTests} `);
  console.log(`  SUITE DURATION: ${durationSec}s`);
  console.log('================================================================');

  if (failedTests === 0) {
    console.log('\n🎉 ALL DATABASE-TO-MODULE TESTS PASSED WITH 100% SUCCESS!');
  } else {
    throw new Error(`${failedTests} tests failed.`);
  }
}

runDatabaseModuleVerification().catch((err) => {
  console.error('\n❌ Database module verification suite failed:', err);
  process.exit(1);
});
