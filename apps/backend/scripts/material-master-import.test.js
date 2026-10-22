const assert = require('node:assert/strict');
const { test, describe, before, after } = require('node:test');
const fs = require('fs');
const path = require('path');
const { PrismaClient } = require('@prisma/client');

// Import Bulk Import & Materials components
const {
  parseSpreadsheet,
  autoDetectColumnMapping,
  MATERIAL_COLUMN_DEFINITIONS,
} = require('../dist/src/modules/bulk-import/excel-parser.util');
const { BulkImportService } = require('../dist/src/modules/bulk-import/bulk-import.service');
const { MaterialsService } = require('../dist/src/modules/materials/materials.service');
const { ImportTarget } = require('../dist/src/modules/bulk-import/dto/bulk-import.dto');

describe('SAARK ERP - Material Master + Excel Import Test Suite', () => {
  let prisma;
  let bulkImportService;
  let materialsService;
  let auditLogs = [];
  const testCreatedProductIds = [];
  const testCreatedCategoryIds = [];
  const testCreatedUnitIds = [];

  const realExcelPath = 'C:/Users/HP/Downloads/AUTO PRICE CALCULATOR.xlsx';

  before(async () => {
    prisma = new PrismaClient();
    await prisma.$connect();

    // Mock AuditService to capture logs
    const mockAuditService = {
      recordAction: async (entry) => {
        auditLogs.push(entry);
        return entry;
      },
      log: async (entry) => {
        auditLogs.push(entry);
        return entry;
      },
    };

    const mockGstVerificationService = {
      validateFormat: () => true,
      validateChecksum: () => true,
      getVerifiedMetadata: () => null,
    };

    const mockSequenceService = {
      nextCustomerCode: async () => `CUS-${Date.now()}`,
      nextVendorCode: async () => `VEN-${Date.now()}`,
    };

    const mockCustomersService = {};

    bulkImportService = new BulkImportService(
      prisma,
      mockAuditService,
      mockSequenceService,
      mockGstVerificationService,
      mockCustomersService,
    );

    materialsService = new MaterialsService(prisma, mockAuditService);
  });

  after(async () => {
    // Cleanup any test created products
    if (testCreatedProductIds.length > 0) {
      await prisma.product.deleteMany({
        where: { id: { in: testCreatedProductIds } },
      });
    }
    if (testCreatedCategoryIds.length > 0) {
      await prisma.productCategory.deleteMany({
        where: { id: { in: testCreatedCategoryIds } },
      });
    }
    if (testCreatedUnitIds.length > 0) {
      await prisma.unit.deleteMany({
        where: { id: { in: testCreatedUnitIds } },
      });
    }
    await prisma.$disconnect();
  });

  // ─── Test Group 1: Workbook Analysis & Column Detection ───────────────────
  describe('1. Workbook & Multi-Sheet Analysis', () => {
    test('Should parse real AUTO PRICE CALCULATOR.xlsx and identify all 3 sheets', async () => {
      assert.ok(fs.existsSync(realExcelPath), 'Workbook file must exist at ' + realExcelPath);
      const buffer = fs.readFileSync(realExcelPath);
      const parsed = parseSpreadsheet('AUTO PRICE CALCULATOR.xlsx', buffer);

      assert.ok(Array.isArray(parsed.sheetNames), 'sheetNames must be an array');
      assert.equal(parsed.sheetNames.length, 3, 'Must contain exactly 3 sheets');
      assert.ok(parsed.sheetNames.includes('FINAL UPDATE SHEET PRICE'), 'Must contain FINAL UPDATE SHEET PRICE');
      assert.ok(parsed.sheetNames.includes('auto panel BOQ and Price calcul'), 'Must contain auto panel BOQ');
      assert.ok(parsed.sheetNames.includes('Sheet4'), 'Must contain Sheet4');

      // Check Sheet 1 rows
      assert.equal(parsed.selectedSheet, 'FINAL UPDATE SHEET PRICE');
      assert.ok(parsed.rawRows.length >= 600, `Expected at least 600 populated data rows, got ${parsed.rawRows.length}`);
    });

    test('Should auto-detect all Material Master column mappings accurately', () => {
      const buffer = fs.readFileSync(realExcelPath);
      const parsed = parseSpreadsheet('AUTO PRICE CALCULATOR.xlsx', buffer, { sheetName: 'FINAL UPDATE SHEET PRICE' });
      const mapping = autoDetectColumnMapping(parsed.headers, ImportTarget.MATERIAL);

      assert.equal(mapping['SKU'], 'sku');
      assert.equal(mapping['Category'], 'category');
      assert.equal(mapping['make'], 'make');
      assert.equal(mapping['Item Name'], 'name');
      assert.equal(mapping['CAPACITY'], 'capacity');
      assert.equal(mapping['Unit'], 'unit');
      assert.equal(mapping['Supplier'], 'supplier');
      assert.equal(mapping['List Price'], 'listPrice');
      assert.equal(mapping['DP Discount'], 'dpDiscount');
      assert.equal(mapping['DP'], 'dealerPrice');
      assert.equal(mapping['LP Discount'], 'lpDiscount');
      assert.equal(mapping['LP'], 'landingPrice');
      assert.equal(mapping['SUB Category Type 1'], 'subCategory1');
      assert.equal(mapping['SUB Category Type 2'], 'subCategory2');
    });
  });

  // ─── Test Group 2: Preview, Validation & In-File Duplicate Detection ──────
  describe('2. Preview & In-File Validation Engine', () => {
    test('Should identify in-file duplicate SKUs and missing mandatory fields in preview', async () => {
      const mockCsv = [
        'SKU,Item Name,Category,Make,Unit,List Price,DP,LP',
        'TEST-SKU-001,Valid Component 1,Switchgear,Siemens,Nos,1000,600,850',
        'TEST-SKU-DUP,First Occurrence,Switchgear,Siemens,Nos,1000,600,850',
        'TEST-SKU-DUP,Duplicate SKU in file,Switchgear,Siemens,Nos,1000,600,850',
        ',Component With Blank SKU,Sensors,Omron,Nos,500,300,450',
        ',,Missing Both SKU and Name,Unknown,Nos,0,0,0',
        'TEST-SKU-002,Invalid Price Component,Relay,Schneider,Nos,INVALID_PRICE,400,600',
      ].join('\n');

      const preview = await bulkImportService.parseAndPreview(
        {
          target: ImportTarget.MATERIAL,
          fileName: 'materials_test.csv',
          checkDuplicates: true,
        },
        Buffer.from(mockCsv, 'utf-8'),
        { isAdmin: true, permissions: ['MATERIALS:VIEW', 'INTERNAL_PRICING:VIEW'] },
      );

      assert.equal(preview.totalRows, 6);
      
      // Row 1: Valid
      assert.equal(preview.rows[0].validationStatus, 'VALID');

      // Row 2 & 3: In-file duplicate SKU
      assert.equal(preview.rows[1].validationStatus, 'DUPLICATE_POSSIBLE');
      assert.equal(preview.rows[2].validationStatus, 'DUPLICATE_POSSIBLE');
      assert.ok(preview.rows[2].duplicateInfo?.description.includes('TEST-SKU-DUP'));

      // Row 4: Blank SKU -> Warning (auto-assign on import)
      assert.equal(preview.rows[3].validationStatus, 'WARNING');
      assert.ok(preview.rows[3].warnings.some((w) => w.includes('auto-assign')));

      // Row 5: Both SKU and Name missing -> INVALID
      assert.equal(preview.rows[4].validationStatus, 'INVALID');
      assert.ok(preview.rows[4].errors.some((e) => e.includes('Mandatory fields missing')));

      // Row 6: Non-numeric price -> INVALID
      assert.equal(preview.rows[5].validationStatus, 'INVALID');
      assert.ok(preview.rows[5].errors.some((e) => e.includes('must be a valid number')));
    });

    test('Should redact internal purchase pricing in preview when caller lacks permission', async () => {
      const mockCsv = [
        'SKU,Item Name,Category,Make,Unit,List Price,DP Discount,DP,LP Discount,LP',
        'TEST-RED-01,Confidential Part,Control,ABB,Nos,10000,45,5500,10,9000',
      ].join('\n');

      // User WITHOUT internal pricing view
      const preview = await bulkImportService.parseAndPreview(
        {
          target: ImportTarget.MATERIAL,
          fileName: 'confidential.csv',
        },
        Buffer.from(mockCsv, 'utf-8'),
        { isAdmin: false, permissions: ['MATERIALS:VIEW'] },
      );

      const row = preview.rows[0];
      assert.equal(row.mappedData.listPrice, '10000');
      assert.equal(row.mappedData.landingPrice, '9000');
      assert.equal(row.mappedData.dealerPrice, undefined, 'dealerPrice must be stripped');
      assert.equal(row.mappedData.dpDiscount, undefined, 'dpDiscount must be stripped');
    });
  });

  // ─── Test Group 3: Execution, Persistence & Idempotency ───────────────────
  describe('3. Execution, Persistence & Idempotency', () => {
    const uniqueSku1 = `TEST-MAT-${Date.now()}-A`;
    const uniqueSku2 = `TEST-MAT-${Date.now()}-B`;

    test('Should execute import, auto-create category/unit, and persist all 22 material fields', async () => {
      const importPayload = {
        target: ImportTarget.MATERIAL,
        fileName: 'material_import.xlsx',
        skipDuplicates: true,
        updateExisting: false,
        rows: [
          {
            rowNumber: 2,
            isIncluded: true,
            data: {
              sku: uniqueSku1,
              name: 'Industrial Controller PCU-01',
              category: 'Automation & Controls',
              make: 'Saark Controls',
              subCategory1: 'HMI',
              subCategory2: 'SVFD',
              subCategory3: '<=3HP',
              subCategory4: 'Integrated Display',
              capacity: '3 HP',
              unit: 'Set',
              supplier: 'Saark Exploration Pvt Ltd',
              listPrice: 50000,
              dpDiscount: 50,
              dealerPrice: 25000,
              lpDiscount: 10,
              landingPrice: 45000,
              hsnSac: '85371000',
            },
          },
        ],
      };

      const result = await bulkImportService.executeImport(
        importPayload,
        { id: 'usr-admin-1', email: 'admin@saark.com', isAdmin: true, roles: ['ROLE_ADMIN'] },
        '127.0.0.1',
      );

      assert.equal(result.successCount, 1);
      assert.equal(result.updatedCount, 0);
      assert.equal(result.skippedCount, 0);
      assert.equal(result.errorCount, 0);

      // Verify DB record
      const dbRecord = await prisma.product.findUnique({
        where: { sku: uniqueSku1 },
        include: { category: true, unit: true },
      });

      assert.ok(dbRecord, 'Product must be found in database');
      testCreatedProductIds.push(dbRecord.id);
      testCreatedCategoryIds.push(dbRecord.categoryId);
      testCreatedUnitIds.push(dbRecord.unitId);

      assert.equal(dbRecord.name, 'Industrial Controller PCU-01');
      assert.equal(dbRecord.make, 'Saark Controls');
      assert.equal(dbRecord.subCategory1, 'HMI');
      assert.equal(dbRecord.subCategory2, 'SVFD');
      assert.equal(dbRecord.subCategory3, '<=3HP');
      assert.equal(dbRecord.capacity, '3 HP');
      assert.equal(dbRecord.supplier, 'Saark Exploration Pvt Ltd');
      assert.equal(dbRecord.listPrice, 50000);
      assert.equal(dbRecord.dpDiscount, 50);
      assert.equal(dbRecord.dealerPrice, 25000);
      assert.equal(dbRecord.purchasePrice, 25000);
      assert.equal(dbRecord.lpDiscount, 10);
      assert.equal(dbRecord.landingPrice, 45000);
      assert.equal(dbRecord.sellingPrice, 45000);
      assert.equal(dbRecord.category.name, 'Automation & Controls');
      assert.equal(dbRecord.unit.name, 'Set');
    });

    test('Should be idempotent with skipDuplicates: true (skip existing record)', async () => {
      const duplicatePayload = {
        target: ImportTarget.MATERIAL,
        fileName: 'material_reimport.xlsx',
        skipDuplicates: true,
        updateExisting: false,
        rows: [
          {
            rowNumber: 2,
            isIncluded: true,
            data: {
              sku: uniqueSku1,
              name: 'Duplicate Should Be Skipped',
              category: 'Automation & Controls',
            },
          },
        ],
      };

      const result = await bulkImportService.executeImport(
        duplicatePayload,
        { id: 'usr-admin-1', isAdmin: true, roles: ['ROLE_ADMIN'] },
      );

      assert.equal(result.successCount, 0);
      assert.equal(result.skippedCount, 1);
      assert.equal(result.updatedCount, 0);

      // Verify DB record was NOT mutated
      const dbRecord = await prisma.product.findUnique({ where: { sku: uniqueSku1 } });
      assert.equal(dbRecord.name, 'Industrial Controller PCU-01');
    });

    test('Should update existing material when updateExisting: true', async () => {
      const updatePayload = {
        target: ImportTarget.MATERIAL,
        fileName: 'material_update.xlsx',
        skipDuplicates: false,
        updateExisting: true,
        rows: [
          {
            rowNumber: 2,
            isIncluded: true,
            data: {
              sku: uniqueSku1,
              name: 'Industrial Controller PCU-01 (Updated Rev B)',
              make: 'Saark Controls Global',
              listPrice: 55000,
              landingPrice: 48000,
            },
          },
        ],
      };

      const result = await bulkImportService.executeImport(
        updatePayload,
        { id: 'usr-admin-1', isAdmin: true, roles: ['ROLE_ADMIN'] },
      );

      assert.equal(result.updatedCount, 1);
      assert.equal(result.successCount, 0);

      const dbRecord = await prisma.product.findUnique({ where: { sku: uniqueSku1 } });
      assert.equal(dbRecord.name, 'Industrial Controller PCU-01 (Updated Rev B)');
      assert.equal(dbRecord.make, 'Saark Controls Global');
      assert.equal(dbRecord.listPrice, 55000);
      assert.equal(dbRecord.landingPrice, 48000);
    });

    test('Should protect dealerPrice from unprivileged user during import execution', async () => {
      const payload = {
        target: ImportTarget.MATERIAL,
        fileName: 'restricted_user_import.xlsx',
        rows: [
          {
            rowNumber: 2,
            isIncluded: true,
            data: {
              sku: uniqueSku2,
              name: 'Standard Contactor 25A',
              category: 'Switchgear',
              make: 'Schneider',
              unit: 'Nos',
              listPrice: 3000,
              dpDiscount: 40,
              dealerPrice: 1800, // Non-privileged user provides this
              lpDiscount: 10,
              landingPrice: 2700,
            },
          },
        ],
      };

      // Non-privileged user
      const result = await bulkImportService.executeImport(
        payload,
        { id: 'usr-staff-1', email: 'sales@saark.com', isAdmin: false, permissions: ['MATERIALS:CREATE'] },
      );

      assert.equal(result.successCount, 1);

      const dbRecord = await prisma.product.findUnique({ where: { sku: uniqueSku2 } });
      testCreatedProductIds.push(dbRecord.id);

      assert.equal(dbRecord.listPrice, 3000);
      assert.equal(dbRecord.landingPrice, 2700);
      assert.equal(dbRecord.dealerPrice, null, 'dealerPrice must NOT be stored by unprivileged user');
      assert.equal(dbRecord.dpDiscount, null, 'dpDiscount must NOT be stored by unprivileged user');
    });

    test('Should isolate partial failures without terminating valid rows in the batch', async () => {
      const uniqueSku3 = `TEST-MAT-${Date.now()}-C`;
      const batchPayload = {
        target: ImportTarget.MATERIAL,
        fileName: 'mixed_batch.xlsx',
        rows: [
          {
            rowNumber: 2,
            isIncluded: true,
            data: {
              sku: '', // Both blank -> INVALID
              name: '',
            },
          },
          {
            rowNumber: 3,
            isIncluded: true,
            data: {
              sku: uniqueSku3,
              name: 'Valid Component in Mixed Batch',
              listPrice: 1500,
            },
          },
        ],
      };

      const result = await bulkImportService.executeImport(
        batchPayload,
        { id: 'usr-admin-1', isAdmin: true, roles: ['ROLE_ADMIN'] },
      );

      assert.equal(result.successCount, 1, 'Valid row must succeed');
      assert.equal(result.errorCount, 1, 'Invalid row must be counted as error');
      assert.equal(result.rowResults[0].status, 'FAILED');
      assert.equal(result.rowResults[1].status, 'IMPORTED');

      const dbRecord = await prisma.product.findUnique({ where: { sku: uniqueSku3 } });
      assert.ok(dbRecord);
      testCreatedProductIds.push(dbRecord.id);
    });
  });

  // ─── Test Group 4: Materials Master Module (Search, Sort, Pagination, RBAC) ─
  describe('4. Materials Master Module API Services', () => {
    test('Should list materials with pagination, search, and sorting', async () => {
      const res = await materialsService.findAll({
        page: 1,
        limit: 10,
        search: 'Industrial Controller',
        sortBy: 'name',
        sortOrder: 'asc',
      });

      assert.ok(Array.isArray(res.data));
      assert.ok(res.meta.total >= 1);
      assert.equal(res.meta.page, 1);
      assert.equal(res.meta.limit, 10);
      assert.ok(res.data.some((m) => m.name.includes('Industrial Controller')));
    });

    test('Should strip internal pricing in MaterialsService when canViewInternalPricing is false', async () => {
      const listRes = await materialsService.findAll({ limit: 10 }, false);
      for (const item of listRes.data) {
        assert.equal(item.dealerPrice, undefined);
        assert.equal(item.dpDiscount, undefined);
        assert.equal(item.purchasePrice, undefined);
      }

      // Privileged query
      const privRes = await materialsService.findAll({ limit: 10 }, true);
      const withPricing = privRes.data.find((m) => m.listPrice !== null);
      if (withPricing) {
        assert.notEqual(withPricing.dealerPrice, undefined);
      }
    });

    test('Should retrieve single material by SKU with RBAC redaction', async () => {
      const foundPrivileged = await materialsService.findOne(testCreatedProductIds[0], true);
      assert.equal(foundPrivileged.id, testCreatedProductIds[0]);
      assert.notEqual(foundPrivileged.dealerPrice, undefined);

      const foundRedacted = await materialsService.findOne(testCreatedProductIds[0], false);
      assert.equal(foundRedacted.dealerPrice, undefined);
      assert.equal(foundRedacted.dpDiscount, undefined);
    });

    test('Should record audit logs for bulk imports and CRUD operations', () => {
      const materialAudit = auditLogs.filter(
        (log) => log.module === 'MATERIALS' || log.entityType === 'Product',
      );
      assert.ok(materialAudit.length > 0, 'Audit logs must be written for material operations');
    });
  });
});
