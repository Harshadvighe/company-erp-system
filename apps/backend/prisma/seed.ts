import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting Saark Exploration ERP Database Seeding...');

  // 1. Company Master
  const company = await prisma.company.upsert({
    where: { id: 'saark-company-001' },
    update: {},
    create: {
      id: 'saark-company-001',
      name: 'Saark Exploration Private Limited',
      legalName: 'Saark Exploration Private Limited',
      gstin: '27AAACS9821F1ZM',
      pan: 'AAACS9821F',
      cin: 'U74999MH2020PTC345678',
      email: 'info@saark.in',
      phone: '+91 98201 12345',
      website: 'https://saark.in',
      address: 'Plot 42, Industrial Zone, MIDC Phase II',
      city: 'Mumbai',
      state: 'Maharashtra',
      country: 'India',
      pincode: '400093',
      bankName: 'HDFC Bank Ltd',
      accountNo: '50200049182391',
      ifscCode: 'HDFC0000123',
    },
  });
  console.log('✅ Company Seeded:', company.name);

  // 2. Departments (13 Master Departments)
  const departmentsData = [
    { name: 'Executive / Leadership', code: 'EXECUTIVE' },
    { name: 'Sales & Marketing', code: 'SALES' },
    { name: 'Purchase / Procurement', code: 'PURCHASE' },
    { name: 'R&D / Engineering', code: 'RND' },
    { name: 'Production', code: 'PRODUCTION' },
    { name: 'Panel Department', code: 'PANEL' },
    { name: 'Quality', code: 'QUALITY' },
    { name: 'Accounts & Finance', code: 'FINANCE' },
    { name: 'Stores / Warehouse', code: 'STORE' },
    { name: 'Projects', code: 'PROJECTS' },
    { name: 'IT', code: 'IT' },
    { name: 'Customer Service', code: 'CUSTOMER_SERVICE' },
    { name: 'Administration', code: 'ADMIN' },
  ];

  const deptMap: Record<string, any> = {};
  for (const dept of departmentsData) {
    deptMap[dept.code] = await prisma.department.upsert({
      where: { code: dept.code },
      update: { name: dept.name },
      create: dept,
    });
  }
  const deptAdmin = deptMap['ADMIN'];
  const deptSales = deptMap['SALES'];
  const deptPurchase = deptMap['PURCHASE'];
  const deptEngineering = deptMap['RND'] || deptMap['PRODUCTION'];
  console.log('✅ 13 Master Departments Seeded!');

  // 2.1 Designations Master
  const designationsData = [
    { name: 'Managing Director', code: 'MD', description: 'Executive Leadership' },
    { name: 'Project Manager', code: 'PM', description: 'Leads project planning & execution' },
    { name: 'Sales Executive', code: 'SALES_EXEC', description: 'Handles client relations & pipeline' },
    { name: 'Purchase Executive', code: 'PURCHASE_EXEC', description: 'Vendor coordination & POs' },
    { name: 'Engineer', code: 'LEAD_ENG', description: 'Design & technical engineering' },
    { name: 'Production Engineer', code: 'PROD_ENG', description: 'Assembly, wiring & shop floor' },
    { name: 'QC Engineer', code: 'QC_ENG', description: 'Quality assurance & testing' },
    { name: 'Accountant', code: 'ACCOUNTANT', description: 'Financial books & invoicing' },
    { name: 'Technician', code: 'TECHNICIAN', description: 'Field and panel maintenance' },
    { name: 'Employee', code: 'EMPLOYEE', description: 'General operational staff' },
  ];

  const desigMap: Record<string, any> = {};
  for (const desig of designationsData) {
    desigMap[desig.code] = await prisma.designation.upsert({
      where: { code: desig.code },
      update: { name: desig.name },
      create: desig,
    });
  }
  console.log('✅ Designations Master Seeded!');

  // 3. Roles
  const rolesData = [
    { name: 'Super Administrator', code: 'ROLE_ADMIN', description: 'Full System Control', isSystem: true },
    { name: 'Project Manager', code: 'ROLE_PROJECT_MGR', description: 'Manages Projects, Tasks & Teams' },
    { name: 'Sales Manager', code: 'ROLE_SALES_MGR', description: 'Manages Sales Pipeline & Quotations' },
    { name: 'Sales Executive', code: 'ROLE_SALES_EXEC', description: 'Handles Leads, Enquiries & Interactions' },
    { name: 'Purchase Manager', code: 'ROLE_PURCHASE_MGR', description: 'Handles Vendors, RFQs & POs' },
    { name: 'Store Manager', code: 'ROLE_STORE_MGR', description: 'Manages Stock Ledger & Goods Issue' },
    { name: 'Production Engineer', code: 'ROLE_PRODUCTION_MGR', description: 'Panel Specs & Panel BOM Design' },
    { name: 'QC Engineer', code: 'ROLE_QC_ENG', description: 'Quality inspection & signoff' },
    { name: 'Accountant', code: 'ROLE_ACCOUNTANT', description: 'Invoicing & Receivables/Payables' },
    { name: 'Employee', code: 'ROLE_EMPLOYEE', description: 'Standard Employee with My Work access' },
  ];

  const roleMap: Record<string, any> = {};
  for (const r of rolesData) {
    roleMap[r.code] = await prisma.role.upsert({
      where: { code: r.code },
      update: { name: r.name, description: r.description },
      create: r,
    });
  }
  const roleAdmin = roleMap['ROLE_ADMIN'];
  const roleSalesMgr = roleMap['ROLE_SALES_MGR'];
  const roleSalesExec = roleMap['ROLE_SALES_EXEC'];
  const rolePurchaseMgr = roleMap['ROLE_PURCHASE_MGR'];
  const roleProductionMgr = roleMap['ROLE_PRODUCTION_MGR'];

  // 3.1 Permissions Master
  const modules = [
    'MY_WORK', 'STAFF', 'ORGANIZATION', 'USERS', 'ROLES',
    'CUSTOMERS', 'CRM', 'SALES', 'PURCHASE', 'VENDORS',
    'INVENTORY', 'PRODUCTION', 'PROJECTS', 'PROJECT_TEAM',
    'PROJECT_BUDGET', 'TASKS', 'REPORTS', 'AUDIT'
  ];
  const actions = ['VIEW', 'CREATE', 'EDIT', 'DELETE', 'APPROVE', 'ASSIGN', 'REVIEW', 'EXPORT', 'PRINT'];

  const permMap: Record<string, any> = {};
  for (const m of modules) {
    for (const a of actions) {
      const key = `${m}:${a}`;
      permMap[key] = await prisma.permission.upsert({
        where: { module_action: { module: m, action: a } },
        update: {},
        create: { module: m, action: a, description: `${a} permission for ${m}` },
      });
    }
  }

  // Helper to link permissions
  const assignRolePerms = async (roleCode: string, perms: string[]) => {
    const role = roleMap[roleCode];
    if (!role) return;
    for (const p of perms) {
      const perm = permMap[p];
      if (perm) {
        await prisma.rolePermission.upsert({
          where: { roleId_permissionId: { roleId: role.id, permissionId: perm.id } },
          update: {},
          create: { roleId: role.id, permissionId: perm.id },
        });
      }
    }
  };

  // ADMIN: Gets all permissions
  await assignRolePerms('ROLE_ADMIN', Object.keys(permMap));

  // PROJECT MANAGER
  await assignRolePerms('ROLE_PROJECT_MGR', [
    'MY_WORK:VIEW',
    'STAFF:VIEW',
    'PROJECTS:VIEW', 'PROJECTS:CREATE', 'PROJECTS:EDIT', 'PROJECTS:EXPORT',
    'PROJECT_TEAM:VIEW', 'PROJECT_TEAM:ASSIGN',
    'PROJECT_BUDGET:VIEW', 'PROJECT_BUDGET:EDIT',
    'TASKS:VIEW', 'TASKS:CREATE', 'TASKS:EDIT', 'TASKS:ASSIGN', 'TASKS:REVIEW', 'TASKS:COMPLETE', 'TASKS:EXPORT',
    'CUSTOMERS:VIEW',
    'REPORTS:VIEW', 'REPORTS:EXPORT',
  ]);

  // SALES EXECUTIVE
  await assignRolePerms('ROLE_SALES_EXEC', [
    'MY_WORK:VIEW',
    'STAFF:VIEW',
    'CUSTOMERS:VIEW', 'CUSTOMERS:CREATE', 'CUSTOMERS:EDIT',
    'CRM:VIEW', 'CRM:CREATE', 'CRM:EDIT',
    'SALES:VIEW', 'SALES:CREATE',
    'TASKS:VIEW', 'TASKS:EDIT',
  ]);

  // PURCHASE MANAGER
  await assignRolePerms('ROLE_PURCHASE_MGR', [
    'MY_WORK:VIEW',
    'STAFF:VIEW',
    'PURCHASE:VIEW', 'PURCHASE:CREATE', 'PURCHASE:EDIT', 'PURCHASE:APPROVE', 'PURCHASE:EXPORT', 'PURCHASE:PRINT',
    'VENDORS:VIEW', 'VENDORS:CREATE', 'VENDORS:EDIT',
    'INVENTORY:VIEW', 'INVENTORY:CREATE', 'INVENTORY:EDIT',
    'TASKS:VIEW', 'TASKS:EDIT',
  ]);

  // PRODUCTION ENGINEER
  await assignRolePerms('ROLE_PRODUCTION_MGR', [
    'MY_WORK:VIEW',
    'STAFF:VIEW',
    'PRODUCTION:VIEW', 'PRODUCTION:CREATE', 'PRODUCTION:EDIT', 'PRODUCTION:APPROVE',
    'INVENTORY:VIEW',
    'PROJECTS:VIEW',
    'TASKS:VIEW', 'TASKS:EDIT',
  ]);

  // QC ENGINEER
  await assignRolePerms('ROLE_QC_ENG', [
    'MY_WORK:VIEW',
    'STAFF:VIEW',
    'PRODUCTION:VIEW', 'PRODUCTION:APPROVE',
    'TASKS:VIEW', 'TASKS:EDIT',
  ]);

  // EMPLOYEE
  await assignRolePerms('ROLE_EMPLOYEE', [
    'MY_WORK:VIEW',
    'STAFF:VIEW',
    'TASKS:VIEW', 'TASKS:EDIT',
    'PROJECTS:VIEW',
  ]);

  console.log('✅ Permissions and Role-Permissions Matrix Seeded!');

  // 4. Test Users & Linked Staff Profiles
  const defaultPasswordHash = await bcrypt.hash('Saark@2026', 10);

  const testAccounts = [
    {
      empId: 'EMP001',
      name: 'Vikram Sharma',
      email: 'admin@saark.in',
      username: 'admin',
      deptCode: 'EXECUTIVE',
      desigCode: 'MD',
      roleCode: 'ROLE_ADMIN',
      phone: '+91 98200 00001',
      location: 'Mumbai Head Office',
    },
    {
      empId: 'EMP002',
      name: 'Rahul Patil',
      email: 'pm@saark.in',
      username: 'rahul.pm',
      deptCode: 'PROJECTS',
      desigCode: 'PM',
      roleCode: 'ROLE_PROJECT_MGR',
      phone: '+91 98200 00002',
      location: 'Pune Works',
    },
    {
      empId: 'EMP003',
      name: 'Amit Joshi',
      email: 'sales@saark.in',
      username: 'amit.sales',
      deptCode: 'SALES',
      desigCode: 'SALES_EXEC',
      roleCode: 'ROLE_SALES_EXEC',
      phone: '+91 98200 00003',
      location: 'Mumbai Head Office',
    },
    {
      empId: 'EMP004',
      name: 'Sneha More',
      email: 'sneha@saark.in',
      username: 'sneha.eng',
      deptCode: 'RND',
      desigCode: 'LEAD_ENG',
      roleCode: 'ROLE_EMPLOYEE',
      phone: '+91 98200 00004',
      location: 'R&D Center, Pune',
    },
    {
      empId: 'EMP005',
      name: 'Pooja Patil',
      email: 'purchase@saark.in',
      username: 'purchasemgr',
      deptCode: 'PURCHASE',
      desigCode: 'PURCHASE_EXEC',
      roleCode: 'ROLE_PURCHASE_MGR',
      phone: '+91 98200 00005',
      location: 'Mumbai Head Office',
    },
    {
      empId: 'EMP006',
      name: 'Rohit Shinde',
      email: 'rohit@saark.in',
      username: 'rohit.prod',
      deptCode: 'PRODUCTION',
      desigCode: 'PROD_ENG',
      roleCode: 'ROLE_PRODUCTION_MGR',
      phone: '+91 98200 00006',
      location: 'MIDC Plant',
    },
    {
      empId: 'EMP007',
      name: 'Neha Pawar',
      email: 'neha@saark.in',
      username: 'neha.qc',
      deptCode: 'QUALITY',
      desigCode: 'QC_ENG',
      roleCode: 'ROLE_QC_ENG',
      phone: '+91 98200 00007',
      location: 'MIDC Plant',
    },
  ];

  const staffMap: Record<string, any> = {};
  let adminUser: any = null;
  let salesMgrUser: any = null;
  let salesExecUser: any = null;

  for (const acc of testAccounts) {
    const dept = deptMap[acc.deptCode];
    const desig = desigMap[acc.desigCode];
    const role = roleMap[acc.roleCode];

    const user = await prisma.user.upsert({
      where: { email: acc.email },
      update: { fullName: acc.name, designation: desig?.name, departmentId: dept?.id },
      create: {
        username: acc.username,
        email: acc.email,
        passwordHash: defaultPasswordHash,
        fullName: acc.name,
        designation: desig?.name,
        departmentId: dept?.id,
        phone: acc.phone,
        status: 'ACTIVE',
      },
    });

    if (acc.email === 'admin@saark.in') adminUser = user;
    if (acc.email === 'sales@saark.in') {
      salesMgrUser = user;
      salesExecUser = user;
    }

    if (role) {
      await prisma.userRole.upsert({
        where: { userId_roleId: { userId: user.id, roleId: role.id } },
        update: {},
        create: { userId: user.id, roleId: role.id },
      });
    }

    const staff = await prisma.staff.upsert({
      where: { employeeId: acc.empId },
      update: {
        fullName: acc.name,
        email: acc.email,
        mobile: acc.phone,
        departmentId: dept.id,
        designationId: desig.id,
        userId: user.id,
        location: acc.location,
        status: 'ACTIVE',
      },
      create: {
        employeeId: acc.empId,
        fullName: acc.name,
        email: acc.email,
        mobile: acc.phone,
        departmentId: dept.id,
        designationId: desig.id,
        userId: user.id,
        location: acc.location,
        status: 'ACTIVE',
        joiningDate: new Date('2023-01-15'),
      },
    });

    staffMap[acc.empId] = staff;
  }

  // Also preserve legacy sales.mgr and engineer users for compatibility
  const legacySales = await prisma.user.upsert({
    where: { email: 'sales.mgr@saark.in' },
    update: {},
    create: {
      username: 'salesmgr',
      email: 'sales.mgr@saark.in',
      passwordHash: defaultPasswordHash,
      fullName: 'Rahul Verma',
      designation: 'Sales Head',
      departmentId: deptSales.id,
      phone: '+91 98200 00002',
    },
  });
  await prisma.userRole.upsert({
    where: { userId_roleId: { userId: legacySales.id, roleId: roleSalesMgr.id } },
    update: {},
    create: { userId: legacySales.id, roleId: roleSalesMgr.id },
  });

  const legacyEngineer = await prisma.user.upsert({
    where: { email: 'engineer@saark.in' },
    update: {},
    create: {
      username: 'engineer',
      email: 'engineer@saark.in',
      passwordHash: defaultPasswordHash,
      fullName: 'Rajesh Kulkarni',
      designation: 'Lead Panel Design Engineer',
      departmentId: deptEngineering.id,
      phone: '+91 98200 00005',
    },
  });
  await prisma.userRole.upsert({
    where: { userId_roleId: { userId: legacyEngineer.id, roleId: roleProductionMgr.id } },
    update: {},
    create: { userId: legacyEngineer.id, roleId: roleProductionMgr.id },
  });

  console.log('✅ Users, Roles & Staff Profiles Seeded!');

  // 5. Financial Years
  await prisma.financialYear.upsert({
    where: { name: '2025-26' },
    update: {},
    create: {
      name: '2025-26',
      startDate: new Date('2025-04-01'),
      endDate: new Date('2026-03-31'),
      isCurrent: false,
    },
  });
  await prisma.financialYear.upsert({
    where: { name: '2026-27' },
    update: {},
    create: {
      name: '2026-27',
      startDate: new Date('2026-04-01'),
      endDate: new Date('2027-03-31'),
      isCurrent: true,
    },
  });

  // 6. Tax Rates
  const taxGst18 = await prisma.taxRate.upsert({
    where: { id: 'tax-gst-18' },
    update: {},
    create: { id: 'tax-gst-18', name: 'GST 18%', percentage: 18.0, cgst: 9.0, sgst: 9.0, igst: 18.0 },
  });
  const taxGst12 = await prisma.taxRate.upsert({
    where: { id: 'tax-gst-12' },
    update: {},
    create: { id: 'tax-gst-12', name: 'GST 12%', percentage: 12.0, cgst: 6.0, sgst: 6.0, igst: 12.0 },
  });

  // 7. Payment Modes
  await prisma.paymentMode.upsert({
    where: { code: 'NEFT_RTGS' },
    update: {},
    create: { name: 'NEFT / RTGS Bank Transfer', code: 'NEFT_RTGS' },
  });
  await prisma.paymentMode.upsert({
    where: { code: 'UPI' },
    update: {},
    create: { name: 'UPI Digital Transfer', code: 'UPI' },
  });

  // 8. Product Categories & Units
  const catPanels = await prisma.productCategory.upsert({
    where: { code: 'CAT_PANELS' },
    update: {},
    create: { name: 'Electrical & VFD Panels', code: 'CAT_PANELS' },
  });
  const catPumps = await prisma.productCategory.upsert({
    where: { code: 'CAT_PUMPS' },
    update: {},
    create: { name: 'Water & Dewatering Pumps', code: 'CAT_PUMPS' },
  });
  const catSensors = await prisma.productCategory.upsert({
    where: { code: 'CAT_SENSORS' },
    update: {},
    create: { name: 'Sensors & Dataloggers', code: 'CAT_SENSORS' },
  });

  const unitNos = await prisma.unit.upsert({
    where: { code: 'NOS' },
    update: {},
    create: { name: 'Numbers', code: 'NOS' },
  });
  const unitSets = await prisma.unit.upsert({
    where: { code: 'SETS' },
    update: {},
    create: { name: 'Sets', code: 'SETS' },
  });

  // 9. Products
  const prodVfdPanel = await prisma.product.upsert({
    where: { sku: 'PNL-VFD-007' },
    update: {},
    create: {
      sku: 'PNL-VFD-007',
      name: 'VFD Control Panel 7.5 HP Dual Pump Skid',
      categoryId: catPanels.id,
      productType: 'FINISHED_PRODUCT',
      unitId: unitSets.id,
      taxRateId: taxGst18.id,
      hsnSac: '85371000',
      purchasePrice: 65000.0,
      sellingPrice: 95000.0,
      minSellingPrice: 88000.0,
      reorderLevel: 5,
      openingStock: 12,
      currentStock: 12,
    },
  });

  const prodBoosterPanel = await prisma.product.upsert({
    where: { sku: 'PNL-BST-015' },
    update: {},
    create: {
      sku: 'PNL-BST-015',
      name: 'Booster Pump Control Panel 15 HP PLC Controlled',
      categoryId: catPanels.id,
      productType: 'FINISHED_PRODUCT',
      unitId: unitSets.id,
      taxRateId: taxGst18.id,
      hsnSac: '85371000',
      purchasePrice: 110000.0,
      sellingPrice: 155000.0,
      minSellingPrice: 145000.0,
      reorderLevel: 3,
      openingStock: 8,
      currentStock: 8,
    },
  });

  const prodFlowMeter = await prisma.product.upsert({
    where: { sku: 'MET-FLW-050' },
    update: {},
    create: {
      sku: 'MET-FLW-050',
      name: 'Electromagnetic Water Flow Meter DN50',
      categoryId: catSensors.id,
      productType: 'COMPONENT',
      unitId: unitNos.id,
      taxRateId: taxGst18.id,
      hsnSac: '90261010',
      purchasePrice: 18500.0,
      sellingPrice: 28000.0,
      reorderLevel: 10,
      openingStock: 25,
      currentStock: 25,
    },
  });

  console.log('✅ Products Seeded!');

  // 10. Customers & Contacts & Valuation
  const customer1 = await prisma.customer.upsert({
    where: { customerCode: 'CUS-2026-00001' },
    update: {},
    create: {
      customerCode: 'CUS-2026-00001',
      companyName: 'Apex Water Infrastructure Ltd',
      gstin: '27AAACA1234A1Z5',
      pan: 'AAACA1234A',
      customerType: 'END_CUSTOMER',
      customerCategory: 'PREMIUM',
      contactPerson: 'Sanjay Deshmukh',
      designation: 'General Manager - Utility',
      email: 'sdeshmukh@apexwater.in',
      phone: '+91 98211 44556',
      address: 'Plot 105, Turbhe Industrial Park',
      city: 'Navi Mumbai',
      state: 'Maharashtra',
      district: 'Thane',
      pincode: '400705',
      ownerName: 'Apex Holdings',
      staffCount: 450,
      turnover: 'Rs 120 Cr',
      industry: 'Water Treatment & Infrastructure',
      customerRating: 4.8,
      status: 'ACTIVE',
    },
  });

  await prisma.customerContact.createMany({
    data: [
      {
        customerId: customer1.id,
        name: 'Sanjay Deshmukh',
        designation: 'General Manager - Utility',
        department: 'Operations',
        mobile: '+91 98211 44556',
        email: 'sdeshmukh@apexwater.in',
        isPrimary: true,
      },
      {
        customerId: customer1.id,
        name: 'Anil Kulkarni',
        designation: 'Senior Purchase Officer',
        department: 'Procurement',
        mobile: '+91 98211 44557',
        email: 'akulkarni@apexwater.in',
        isPrimary: false,
      },
    ],
  });

  await prisma.customerValuation.upsert({
    where: { customerId: customer1.id },
    update: {},
    create: {
      customerId: customer1.id,
      vfdWorkScore: 85.0,
      dewateringWorkScore: 70.0,
      isDealer: false,
      isDistributor: true,
      ratingScore: 4.8,
      valuablePercentage: 92.5,
      activityCount: 14,
      distributorName: 'Apex Regional Distribution',
    },
  });

  const customer2 = await prisma.customer.upsert({
    where: { customerCode: 'CUS-2026-00002' },
    update: {},
    create: {
      customerCode: 'CUS-2026-00002',
      companyName: 'Bluestar Industrial Systems',
      gstin: '27AAABB9988C1Z2',
      pan: 'AAABB9988C',
      customerType: 'OEM',
      customerCategory: 'STANDARD',
      contactPerson: 'Manish Mehta',
      designation: 'Technical Director',
      email: 'manish@bluestarsys.com',
      phone: '+91 98222 77889',
      address: 'GIDC Estate, Sector 3',
      city: 'Vapi',
      state: 'Gujarat',
      district: 'Valsad',
      pincode: '396195',
      staffCount: 120,
      turnover: 'Rs 45 Cr',
      industry: 'HVAC & Industrial Automation',
      customerRating: 4.5,
      status: 'ACTIVE',
    },
  });

  await prisma.customerValuation.upsert({
    where: { customerId: customer2.id },
    update: {},
    create: {
      customerId: customer2.id,
      vfdWorkScore: 90.0,
      dewateringWorkScore: 40.0,
      isDealer: true,
      isDistributor: false,
      ratingScore: 4.5,
      valuablePercentage: 84.0,
      activityCount: 9,
      dealerName: 'Bluestar OEM Network',
    },
  });

  console.log('✅ Customers & Valuations Seeded!');

  // 11. Customer Interactions
  await prisma.customerInteraction.create({
    data: {
      customerId: customer1.id,
      interactionType: 'MEETING',
      subject: 'Annual VFD Panel Supply Contract Discussion',
      description: 'Met Sanjay Deshmukh at site regarding requirement of 8 Nos 15 HP Booster Pump Panels.',
      outcome: 'Customer requested formal quotation with Schneider VFDs by end of week.',
      nextFollowUp: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      recordedBy: salesMgrUser.fullName,
    },
  });

  // 12. Vendors
  await prisma.vendor.upsert({
    where: { vendorCode: 'VEN-2026-00001' },
    update: {},
    create: {
      vendorCode: 'VEN-2026-00001',
      companyName: 'Schneider Electric India Pvt Ltd',
      gstin: '27AAACS1234F1Z8',
      pan: 'AAACS1234F',
      contactPerson: 'Rohan Joshi',
      email: 'rohan.joshi@se.com',
      phone: '+91 22 6123 4567',
      address: '5th Floor, Corporate Park',
      city: 'Mumbai',
      state: 'Maharashtra',
      productsSupplied: 'VFD Drives, Contactors, PLCs, Circuit Breakers',
      rating: 4.9,
    },
  });

  // 13. CRM Leads & Enquiries
  await prisma.lead.upsert({
    where: { leadNumber: 'LEAD-2026-00001' },
    update: {},
    create: {
      leadNumber: 'LEAD-2026-00001',
      companyName: 'GreenField STP Solutions',
      contactPerson: 'Karan Malhotra',
      phone: '+91 98333 11223',
      email: 'karan@greenfieldstp.com',
      source: 'EXHIBITION',
      productInterest: 'STP Control Panels & Dewatering Skids',
      requirement: 'Requires 4 units IP55 Outdoor Panels for municipal STP plant.',
      estimatedValue: 680000.0,
      assignedTo: salesExecUser.fullName,
      priority: 'HIGH',
      status: 'QUALIFIED',
      customerId: customer1.id,
    },
  });

  await prisma.enquiry.upsert({
    where: { enquiryNumber: 'ENQ-2026-00001' },
    update: {},
    create: {
      enquiryNumber: 'ENQ-2026-00001',
      customerId: customer1.id,
      productInterest: 'VFD Control Panel 7.5 HP Dual Pump Skid',
      quantity: 4,
      requirement: 'Include RS485 Modbus telemetry module and IP55 MS powder coated enclosure.',
      expectedValue: 380000.0,
      assignedTo: salesMgrUser.fullName,
      priority: 'HIGH',
      status: 'PENDING',
    },
  });

  // 14. Client Specific: Panel Specification & BOM
  const panelSpec = await prisma.panelSpecification.upsert({
    where: { panelCode: 'PANEL-2026-0001' },
    update: {},
    create: {
      panelCode: 'PANEL-2026-0001',
      customerId: customer1.id,
      panelType: 'VFD_PANEL',
      voltage: '415V 3-Phase 50Hz',
      currentRating: '125A',
      pumpQty: 2,
      pumpHp: 7.5,
      controlType: 'AUTOMATIC_PLC',
      starterType: 'VFD',
      ipRating: 'IP55',
      enclosureType: 'POWDER_COATED_MS',
      materialCost: 58000.0,
      labourCost: 12000.0,
      overheadCost: 5000.0,
      marginPercent: 20.0,
      finalPrice: 90000.0,
      status: 'APPROVED',
    },
  });

  await prisma.panelBOMItem.createMany({
    data: [
      {
        panelSpecId: panelSpec.id,
        productId: prodVfdPanel.id,
        componentName: 'Schneider ATV320 7.5HP VFD Drive',
        specification: '5.5kW / 7.5HP 3-Phase 415V',
        manufacturer: 'Schneider Electric',
        quantity: 2,
        unitPrice: 21000.0,
        totalPrice: 42000.0,
      },
      {
        panelSpecId: panelSpec.id,
        productId: prodFlowMeter.id,
        componentName: 'Electromagnetic Flow Meter Transmitter',
        specification: 'DN50 Pulse & 4-20mA Output',
        manufacturer: 'Saark Analytics',
        quantity: 1,
        unitPrice: 16000.0,
        totalPrice: 16000.0,
      },
    ],
  });

  // 15. Warehouse & Stock
  const warehouseMain = await prisma.warehouse.upsert({
    where: { code: 'WH-MAIN' },
    update: {},
    create: {
      code: 'WH-MAIN',
      name: 'Main Assembly Warehouse MIDC',
      location: 'Plot 42 MIDC Phase II, Mumbai',
      status: 'ACTIVE',
    },
  });

  await prisma.stockItem.upsert({
    where: { warehouseId_productId: { warehouseId: warehouseMain.id, productId: prodVfdPanel.id } },
    update: {},
    create: {
      warehouseId: warehouseMain.id,
      productId: prodVfdPanel.id,
      currentQuantity: 12,
      reservedQuantity: 2,
    },
  });

  // 16. Audit Log & Notification
  await prisma.auditLog.create({
    data: {
      userEmail: adminUser.email,
      action: 'SYSTEM_SEED',
      module: 'ADMIN',
      details: 'Saark Exploration ERP system initial seed completed successfully.',
    },
  });

  await prisma.notification.create({
    data: {
      userId: salesMgrUser.id,
      title: 'New High Priority Enquiry',
      message: 'Enquiry ENQ-2026-00001 assigned for Apex Water Infrastructure Ltd.',
      module: 'CRM',
      entityId: 'ENQ-2026-00001',
    },
  });

  // 17. Seed Initial Project & Tasks
  const pmStaff = staffMap['EMP002'];
  const snehaStaff = staffMap['EMP004'];
  const nehaStaff = staffMap['EMP007'];
  const poojaStaff = staffMap['EMP005'];

  if (pmStaff) {
    const sampleProject = await prisma.project.upsert({
      where: { projectNumber: 'PRJ-2026-001' },
      update: {},
      create: {
        projectNumber: 'PRJ-2026-001',
        name: 'VFD & PLC Automation Panel (Water Treatment Plant)',
        description: 'Complete fabrication, wiring, PLC programming, and FAT testing for 3-tier VFD automation control panel.',
        projectType: 'Panel Manufacturing',
        projectManagerStaffId: pmStaff.id,
        customerId: customer1?.id || null,
        priority: 'HIGH',
        budget: 750000,
        status: 'ACTIVE',
        health: 'ON_TRACK',
        startDate: new Date('2026-04-01'),
        endDate: new Date('2026-06-30'),
      },
    });

    if (snehaStaff) {
      await prisma.projectMember.upsert({
        where: { projectId_staffId: { projectId: sampleProject.id, staffId: snehaStaff.id } },
        update: {},
        create: { projectId: sampleProject.id, staffId: snehaStaff.id, projectRole: 'Lead Engineer', allocationPercent: 75 },
      });
    }
    if (nehaStaff) {
      await prisma.projectMember.upsert({
        where: { projectId_staffId: { projectId: sampleProject.id, staffId: nehaStaff.id } },
        update: {},
        create: { projectId: sampleProject.id, staffId: nehaStaff.id, projectRole: 'QC Engineer', allocationPercent: 50 },
      });
    }

    const m1 = await prisma.milestone.create({
      data: {
        projectId: sampleProject.id,
        title: 'Single Line Diagram & GA Approval',
        dueDate: new Date('2026-04-20'),
        status: 'COMPLETED',
      },
    });
    const m2 = await prisma.milestone.create({
      data: {
        projectId: sampleProject.id,
        title: 'Component Procurement & Enclosure Fabrication',
        dueDate: new Date('2026-05-15'),
        status: 'IN_PROGRESS',
      },
    });
    const m3 = await prisma.milestone.create({
      data: {
        projectId: sampleProject.id,
        title: 'Wiring, Internal Testing & Factory Acceptance (FAT)',
        dueDate: new Date('2026-06-15'),
        status: 'PENDING',
      },
    });

    if (snehaStaff) {
      await prisma.task.upsert({
        where: { taskNumber: 'TSK-2026-001' },
        update: {},
        create: {
          taskNumber: 'TSK-2026-001',
          title: 'Validate I/O Wiring Schematic with Schneider PLC',
          description: 'Review terminal block assignments, 24V DC auxiliary loops, and verify safety interlocks.',
          projectId: sampleProject.id,
          milestoneId: m2.id,
          departmentId: deptMap['RND']?.id,
          assigneeStaffId: snehaStaff.id,
          createdByStaffId: pmStaff.id,
          assignedByStaffId: pmStaff.id,
          priority: 'HIGH',
          status: 'IN_PROGRESS',
          dueDate: new Date('2026-05-10'),
          estimatedHours: 16,
          actualHours: 8,
          progress: 50,
        },
      });
    }

    if (poojaStaff) {
      await prisma.task.upsert({
        where: { taskNumber: 'TSK-2026-002' },
        update: {},
        create: {
          taskNumber: 'TSK-2026-002',
          title: 'Expedite 45kW ABB VFD Drive Inward',
          description: 'Follow up with authorized distributor for express dispatch and gate pass.',
          projectId: sampleProject.id,
          milestoneId: m2.id,
          departmentId: deptMap['PURCHASE']?.id,
          assigneeStaffId: poojaStaff.id,
          createdByStaffId: pmStaff.id,
          assignedByStaffId: pmStaff.id,
          priority: 'CRITICAL',
          status: 'ACCEPTED',
          dueDate: new Date('2026-05-08'),
          estimatedHours: 6,
          actualHours: 1,
          progress: 25,
        },
      });
    }

    if (nehaStaff) {
      await prisma.task.upsert({
        where: { taskNumber: 'TSK-2026-003' },
        update: {},
        create: {
          taskNumber: 'TSK-2026-003',
          title: 'Prepare Pre-FAT Quality Inspection Checklist',
          description: 'Draft insulation resistance, high-voltage withstand, and busbar torque verification protocol.',
          projectId: sampleProject.id,
          milestoneId: m3.id,
          departmentId: deptMap['QUALITY']?.id,
          assigneeStaffId: nehaStaff.id,
          createdByStaffId: pmStaff.id,
          assignedByStaffId: pmStaff.id,
          priority: 'MEDIUM',
          status: 'ASSIGNED',
          dueDate: new Date('2026-05-25'),
          estimatedHours: 12,
          actualHours: 0,
          progress: 0,
        },
      });
    }
  }

  console.log('🎉 Seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
