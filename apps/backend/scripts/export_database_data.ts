import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

async function exportAllData() {
  console.log('========================================================================');
  console.log('     SAARK ERP: EXPORTING ALL CRM, HR, PRODUCTION & ADMIN DATA          ');
  console.log('========================================================================\n');

  try {
    const backup: Record<string, any[]> = {};

    const modelsToExport = [
      // 1. ADMIN & AUTH
      'company',
      'department',
      'designation',
      'financialYear',
      'taxRate',
      'paymentMode',
      'productCategory',
      'unit',
      'role',
      'permission',
      'user',
      'userRole',
      'rolePermission',

      // 2. HR & WORKFORCE
      'staff',
      'shiftMaster',
      'employee',
      'employeeFaceBiometric',
      'attendance',
      'workstationAllocation',
      'leaveRequest',
      'payrollRecord',
      'safetyIncident',

      // 3. CRM MODULE
      'customer',
      'customerContact',
      'customerValuation',
      'companyValuationHistory',
      'productSystem',
      'companyProductInterest',
      'lead',
      'enquiry',
      'opportunity',
      'crmActivity',
      'crmMeeting',
      'meetingScheduleHistory',
      'crmCall',
      'callRecording',
      'crmSiteVisit',
      'crmFollowUp',

      // 4. PRODUCTION & INVENTORY
      'vendor',
      'product',
      'warehouse',
      'stockItem',
      'panelSpecification',
      'panelBOMItem',
      'quotation',
      'quotationItem',
      'salesOrder',
      'salesOrderItem',

      // 5. DOCUMENTS, AUDIT & NOTIFICATIONS
      'documentItem',
      'auditLog',
      'notification',
      'project',
      'task',
    ];

    let totalRecords = 0;
    for (const model of modelsToExport) {
      if ((prisma as any)[model] && typeof (prisma as any)[model].findMany === 'function') {
        const rows = await (prisma as any)[model].findMany();
        backup[model] = rows;
        console.log(`   • ${model.padEnd(28)}: ${rows.length} records`);
        totalRecords += rows.length;
      }
    }

    const outputDir = path.join(__dirname, '../../storage');
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    const outputPath = path.join(outputDir, 'saark_erp_export.json');
    fs.writeFileSync(outputPath, JSON.stringify(backup, null, 2), 'utf8');

    console.log('\n========================================================================');
    console.log(`✅ EXPORT SUCCESS: Backed up ${totalRecords} records across all modules!`);
    console.log(`   Destination: ${outputPath}`);
    console.log('========================================================================');
  } catch (error) {
    console.error('❌ Export failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

exportAllData();
