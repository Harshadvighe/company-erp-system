import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

async function importAllData() {
  console.log('========================================================================');
  console.log('     SAARK ERP: IMPORTING ALL DATA INTO POSTGRESQL DATABASE             ');
  console.log('========================================================================\n');

  const inputPath = path.join(__dirname, '../../storage/saark_erp_export.json');
  if (!fs.existsSync(inputPath)) {
    console.error(`❌ Export file not found at: ${inputPath}`);
    console.error(`   Run "npm run db:export" first.`);
    process.exit(1);
  }

  const rawData = fs.readFileSync(inputPath, 'utf8');
  const backup: Record<string, any[]> = JSON.parse(rawData);

  // Topological insertion order to respect foreign key constraints
  const importOrder = [
    // 1. Core Reference Masters
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

    // 2. HR & Industrial Workforce
    'staff',
    'shiftMaster',
    'employee',
    'employeeFaceBiometric',
    'attendance',
    'workstationAllocation',
    'leaveRequest',
    'payrollRecord',
    'safetyIncident',

    // 3. CRM Module
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

    // 4. Production, Panel Manufacturing & Inventory
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

    // 5. Audit & System
    'documentItem',
    'auditLog',
    'notification',
    'project',
    'task',
  ];

  let totalImported = 0;

  try {
    for (const model of importOrder) {
      const rows = backup[model];
      if (!rows || rows.length === 0) continue;

      const delegate = (prisma as any)[model];
      if (!delegate) {
        console.warn(`   ⚠️ Model "${model}" not found in Prisma schema, skipping.`);
        continue;
      }

      console.log(`📥 Importing ${model.padEnd(26)} (${rows.length} records)...`);
      let modelCount = 0;

      for (const row of rows) {
        // Parse date strings back into Date objects for DateTime fields
        const cleanedRow = { ...row };
        for (const [k, v] of Object.entries(cleanedRow)) {
          if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(v)) {
            cleanedRow[k] = new Date(v);
          }
        }

        try {
          if (row.id) {
            await delegate.upsert({
              where: { id: row.id },
              update: cleanedRow,
              create: cleanedRow,
            });
          } else {
            // Composite key models like userRole, rolePermission
            await delegate.create({ data: cleanedRow }).catch(() => {});
          }
          modelCount++;
        } catch (rowErr: any) {
          // If upsert fails on composite or constraint, try direct create
          try {
            await delegate.create({ data: cleanedRow });
            modelCount++;
          } catch (e: any) {
            // Ignore duplicate key errors if already present
            if (!e.message.includes('Unique constraint') && !e.message.includes('already exists')) {
              console.warn(`     [Warning on ${model}]:`, e.message);
            }
          }
        }
      }

      console.log(`   ✅ ${model.padEnd(26)}: ${modelCount}/${rows.length} imported.`);
      totalImported += modelCount;
    }

    console.log('\n========================================================================');
    console.log(`🎉 RESTORE SUCCESS: Imported ${totalImported} records into database!`);
    console.log('========================================================================');
  } catch (error) {
    console.error('❌ Import failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

importAllData();
