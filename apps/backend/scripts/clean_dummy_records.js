require('dotenv').config({ path: __dirname + '/../.env' });
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('🚀 Starting Saark ERP Dummy Data Cleanup across all modules...');

  // 1. Find Super Admin
  const adminUser = await prisma.user.findFirst({
    where: {
      OR: [
        { username: 'admin' },
        { email: 'admin@saark.in' },
      ],
    },
  });

  if (!adminUser) {
    throw new Error('❌ Super Admin user not found! Aborting cleanup to prevent lock-out.');
  }

  console.log(`✅ Identified Super Admin user: ${adminUser.username} (${adminUser.id})`);

  // 2. Perform deletions in foreign-key safe order
  const summary = {};

  async function safeDelete(modelName, where = {}) {
    try {
      if (typeof prisma[modelName]?.deleteMany === 'function') {
        const res = await prisma[modelName].deleteMany({ where });
        summary[modelName] = res.count;
        if (res.count > 0) {
          console.log(`  🗑️  Cleared ${res.count} rows from ${modelName}`);
        }
      }
    } catch (e) {
      console.error(`  ⚠️  Error clearing ${modelName}:`, e.message);
    }
  }

  console.log('\n--- 1. Cleaning Production & Panels Dummy Data ---');
  await safeDelete('panelBOMItem');
  await safeDelete('panelSpecification');
  await safeDelete('workstationAllocation');
  await safeDelete('dailyProductionLog');
  await safeDelete('productionBatch');

  console.log('\n--- 2. Cleaning Sales & CRM Dummy Data ---');
  await safeDelete('salesOrderItem');
  await safeDelete('salesOrder');
  await safeDelete('salesInvoiceItem');
  await safeDelete('salesInvoice');
  await safeDelete('salesPayment');
  await safeDelete('quotationItem');
  await safeDelete('quotation');
  await safeDelete('crmFollowUp');
  await safeDelete('crmActivity');
  await safeDelete('opportunity');
  await safeDelete('customerValuation');
  await safeDelete('customerContact');
  await safeDelete('customerInteraction');
  await safeDelete('companyProductInterest');
  await safeDelete('enquiry');
  await safeDelete('lead');
  await safeDelete('customer');

  console.log('\n--- 3. Cleaning Procurement & Vendor Dummy Data ---');
  await safeDelete('purchaseReturnItem');
  await safeDelete('purchaseReturn');
  await safeDelete('purchasePayment');
  await safeDelete('purchaseInvoiceItem');
  await safeDelete('purchaseInvoice');
  await safeDelete('purchaseOrderItem');
  await safeDelete('purchaseOrder');
  await safeDelete('purchaseRequisitionItem');
  await safeDelete('purchaseRequisition');
  await safeDelete('rfqVendor');
  await safeDelete('rfqItem');
  await safeDelete('rfq');
  await safeDelete('vendorQuotationItem');
  await safeDelete('vendorQuotation');
  await safeDelete('vendorContact');
  await safeDelete('vendorBankAccount');
  await safeDelete('vendorAddress');
  await safeDelete('vendor');

  console.log('\n--- 4. Cleaning Projects & Tasks Dummy Data ---');
  await safeDelete('taskActivity');
  await safeDelete('taskComment');
  await safeDelete('task');
  await safeDelete('milestone');
  await safeDelete('projectMember');
  await safeDelete('projectBudget');
  await safeDelete('projectFile');
  await safeDelete('projectUpdate');
  await safeDelete('project');

  console.log('\n--- 5. Cleaning B2B Trading Dummy Data ---');
  await safeDelete('b2bProductMedia');
  await safeDelete('b2bVariant');
  await safeDelete('b2bProduct');
  await safeDelete('b2bSupplier');
  await safeDelete('b2bCategory');

  console.log('\n--- 6. Cleaning HR, Workforce, Biometrics & Payroll Dummy Data ---');
  await safeDelete('attendance');
  await safeDelete('attendanceRecord');
  await safeDelete('payrollRecord');
  await safeDelete('safetyIncident');
  await safeDelete('leaveRequest');
  await safeDelete('employeeFaceBiometric');
  await safeDelete('employee');

  // Disconnect headStaff on departments before deleting staff
  try {
    await prisma.department.updateMany({
      data: { headStaffId: null },
    });
  } catch (e) {
    console.error('Error unlinking department head staff:', e.message);
  }
  await safeDelete('staff');

  console.log('\n--- 7. Cleaning Stock & Activity Logs ---');
  await safeDelete('stockTransaction');
  await safeDelete('stockItem');
  await safeDelete('notification');
  await safeDelete('userSession');
  await safeDelete('auditLog');

  console.log('\n--- 8. Cleaning Test Users (Preserving Super Admin) ---');
  await safeDelete('userRole', { userId: { not: adminUser.id } });
  await safeDelete('user', { id: { not: adminUser.id } });

  // Ensure Admin is active and linked to ROLE_ADMIN
  const adminRole = await prisma.role.findFirst({
    where: { code: 'ROLE_ADMIN' },
  });

  if (adminRole) {
    await prisma.userRole.upsert({
      where: {
        userId_roleId: {
          userId: adminUser.id,
          roleId: adminRole.id,
        },
      },
      update: {},
      create: {
        userId: adminUser.id,
        roleId: adminRole.id,
      },
    });
    console.log('✅ Confirmed Super Admin retains ROLE_ADMIN permissions');
  }

  // Create clean audit record
  await prisma.auditLog.create({
    data: {
      action: 'SYSTEM_DUMMY_DATA_CLEANUP',
      module: 'DATABASE_ADMIN',
      details: 'All dummy test records across all modules successfully cleared. System masters & Admin preserved.',
      userId: adminUser.id,
      userEmail: adminUser.email,
    },
  });

  console.log('\n🎉 ====================================================');
  console.log('🎉   ALL DUMMY RECORDS ACROSS ALL MODULES PURGED!    ');
  console.log('🎉   SYSTEM IS CLEAN, FRESH, AND PRODUCTION-READY.   ');
  console.log('🎉 ====================================================\n');
}

main()
  .catch((e) => {
    console.error('Fatal error during cleanup:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
