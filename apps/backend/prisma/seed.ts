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

  // 2. Departments
  const deptAdmin = await prisma.department.upsert({
    where: { code: 'ADMIN' },
    update: {},
    create: { name: 'Administration & IT', code: 'ADMIN' },
  });
  const deptSales = await prisma.department.upsert({
    where: { code: 'SALES' },
    update: {},
    create: { name: 'Sales & Business Development', code: 'SALES' },
  });
  const deptPurchase = await prisma.department.upsert({
    where: { code: 'PURCHASE' },
    update: {},
    create: { name: 'Procurement & Vendor Mgmt', code: 'PURCHASE' },
  });
  const deptStore = await prisma.department.upsert({
    where: { code: 'STORE' },
    update: {},
    create: { name: 'Store & Warehouse Operations', code: 'STORE' },
  });
  const deptEngineering = await prisma.department.upsert({
    where: { code: 'ENG' },
    update: {},
    create: { name: 'Panel Manufacturing & R&D', code: 'ENG' },
  });
  const deptFinance = await prisma.department.upsert({
    where: { code: 'FINANCE' },
    update: {},
    create: { name: 'Accounts & Finance', code: 'FINANCE' },
  });

  // 3. Roles
  const roleAdmin = await prisma.role.upsert({
    where: { code: 'ROLE_ADMIN' },
    update: {},
    create: { name: 'Super Administrator', code: 'ROLE_ADMIN', description: 'Full System Control', isSystem: true },
  });
  const roleSalesMgr = await prisma.role.upsert({
    where: { code: 'ROLE_SALES_MGR' },
    update: {},
    create: { name: 'Sales Manager', code: 'ROLE_SALES_MGR', description: 'Manages Sales Pipeline & Quotations' },
  });
  const roleSalesExec = await prisma.role.upsert({
    where: { code: 'ROLE_SALES_EXEC' },
    update: {},
    create: { name: 'Sales Executive', code: 'ROLE_SALES_EXEC', description: 'Handles Leads, Enquiries & Interactions' },
  });
  const rolePurchaseMgr = await prisma.role.upsert({
    where: { code: 'ROLE_PURCHASE_MGR' },
    update: {},
    create: { name: 'Purchase Manager', code: 'ROLE_PURCHASE_MGR', description: 'Handles Vendors, RFQs & POs' },
  });
  const roleStoreMgr = await prisma.role.upsert({
    where: { code: 'ROLE_STORE_MGR' },
    update: {},
    create: { name: 'Store Manager', code: 'ROLE_STORE_MGR', description: 'Manages Stock Ledger & Goods Issue' },
  });
  const roleProductionMgr = await prisma.role.upsert({
    where: { code: 'ROLE_PRODUCTION_MGR' },
    update: {},
    create: { name: 'Production Engineer', code: 'ROLE_PRODUCTION_MGR', description: 'Panel Specs & Panel BOM Design' },
  });
  const roleAccountant = await prisma.role.upsert({
    where: { code: 'ROLE_ACCOUNTANT' },
    update: {},
    create: { name: 'Accountant', code: 'ROLE_ACCOUNTANT', description: 'Invoicing & Receivables/Payables' },
  });

  // 4. Users
  const defaultPasswordHash = await bcrypt.hash('Saark@2026', 10);

  const adminUser = await prisma.user.upsert({
    where: { email: 'admin@saark.in' },
    update: {},
    create: {
      username: 'admin',
      email: 'admin@saark.in',
      passwordHash: defaultPasswordHash,
      fullName: 'Vikram Sharma',
      designation: 'Managing Director',
      departmentId: deptAdmin.id,
      phone: '+91 98200 00001',
    },
  });
  await prisma.userRole.upsert({
    where: { userId_roleId: { userId: adminUser.id, roleId: roleAdmin.id } },
    update: {},
    create: { userId: adminUser.id, roleId: roleAdmin.id },
  });

  const salesMgrUser = await prisma.user.upsert({
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
    where: { userId_roleId: { userId: salesMgrUser.id, roleId: roleSalesMgr.id } },
    update: {},
    create: { userId: salesMgrUser.id, roleId: roleSalesMgr.id },
  });

  const salesExecUser = await prisma.user.upsert({
    where: { email: 'sales.exec@saark.in' },
    update: {},
    create: {
      username: 'salesexec',
      email: 'sales.exec@saark.in',
      passwordHash: defaultPasswordHash,
      fullName: 'Priya Nair',
      designation: 'Senior Sales Executive',
      departmentId: deptSales.id,
      phone: '+91 98200 00003',
    },
  });
  await prisma.userRole.upsert({
    where: { userId_roleId: { userId: salesExecUser.id, roleId: roleSalesExec.id } },
    update: {},
    create: { userId: salesExecUser.id, roleId: roleSalesExec.id },
  });

  const purchaseMgrUser = await prisma.user.upsert({
    where: { email: 'purchase@saark.in' },
    update: {},
    create: {
      username: 'purchasemgr',
      email: 'purchase@saark.in',
      passwordHash: defaultPasswordHash,
      fullName: 'Amit Patel',
      designation: 'Procurement Manager',
      departmentId: deptPurchase.id,
      phone: '+91 98200 00004',
    },
  });
  await prisma.userRole.upsert({
    where: { userId_roleId: { userId: purchaseMgrUser.id, roleId: rolePurchaseMgr.id } },
    update: {},
    create: { userId: purchaseMgrUser.id, roleId: rolePurchaseMgr.id },
  });

  const engineerUser = await prisma.user.upsert({
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
    where: { userId_roleId: { userId: engineerUser.id, roleId: roleProductionMgr.id } },
    update: {},
    create: { userId: engineerUser.id, roleId: roleProductionMgr.id },
  });

  console.log('✅ Users & Roles Seeded!');

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
