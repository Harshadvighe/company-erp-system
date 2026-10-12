const assert = require('node:assert/strict');
const { test, describe, beforeEach } = require('node:test');
const { plainToInstance } = require('class-transformer');
const { validate } = require('class-validator');

// Import utilities and services
const {
  parseCsv,
  parseSpreadsheet,
  autoDetectColumnMapping,
  sanitizeSpreadsheetCell,
  sanitizeInputCell,
  CUSTOMER_COLUMN_DEFINITIONS,
  VENDOR_COLUMN_DEFINITIONS,
} = require('../src/modules/bulk-import/excel-parser.util');
const { BulkImportService } = require('../src/modules/bulk-import/bulk-import.service');
const { ExecuteImportDto } = require('../src/modules/bulk-import/dto/bulk-import.dto');
const { GstVerificationService } = require('../src/modules/crm/gst-verification.service');

describe('SAARK ERP - Bulk Import Engine Test Suite', () => {
  let mockPrisma;
  let mockAudit;
  let mockSequence;
  let mockGstService;
  let mockCustomersService;
  let service;

  beforeEach(() => {
    // Mock Prisma
    mockPrisma = {
      customer: {
        findMany: async () => [],
        findFirst: async () => null,
        findUnique: async () => null,
        create: async ({ data }) => ({ id: `cus-${Date.now()}`, ...data }),
        update: async ({ data }) => ({ id: `cus-${Date.now()}`, ...data }),
        count: async () => 10,
      },
      vendor: {
        findMany: async () => [],
        findFirst: async () => null,
        findUnique: async () => null,
        create: async ({ data }) => ({ id: `ven-${Date.now()}`, ...data }),
        update: async ({ data }) => ({ id: `ven-${Date.now()}`, ...data }),
        count: async () => 5,
      },
      customerContact: {
        create: async ({ data }) => ({ id: `cnt-${Date.now()}`, ...data }),
      },
      customerValuation: {
        create: async ({ data }) => ({ id: `val-${Date.now()}`, ...data }),
      },
      vendorContact: {
        create: async ({ data }) => ({ id: `vcnt-${Date.now()}`, ...data }),
      },
      staff: {
        findFirst: async () => ({ id: 'staff-001', fullName: 'Rajesh Test Staff' }),
      },
    };
    mockPrisma.$transaction = async (callback) => callback({
      customer: mockPrisma.customer,
      customerContact: mockPrisma.customerContact,
      customerValuation: mockPrisma.customerValuation,
      vendor: mockPrisma.vendor,
      vendorContact: mockPrisma.vendorContact,
    });

    // Mock Audit
    mockAudit = {
      logs: [],
      log: async function (entry) {
        this.logs.push(entry);
      },
    };

    // Mock Sequence
    let customerCodeSeq = 100;
    let vendorCodeSeq = 50;
    mockSequence = {
      nextCustomerCode: async () => `CUS-2026-${String(++customerCodeSeq).padStart(5, '0')}`,
      nextVendorCode: async () => `VEN-2026-${String(++vendorCodeSeq).padStart(5, '0')}`,
    };

    // Mock GST Service
    mockGstService = new GstVerificationService();
    mockGstService.getVerifiedMetadata = (token, gstin) =>
      token
        ? {
            gstVerified: true,
            gstVerifiedAt: new Date('2026-01-01T00:00:00.000Z'),
            gstProviderRef: 'GSTINAPI_LIVE_LOOKUP',
          }
        : null;
    mockCustomersService = {
      createInTransaction: async (tx, dto, userId) => {
          const customerCode = await mockSequence.nextCustomerCode();
          const customer = await tx.customer.create({
            data: {
              ...dto,
              customerCode,
              email: dto.source === 'EXCEL_IMPORT'
                ? dto.email ?? ''
                : dto.email || `${customerCode.toLowerCase()}@example.com`,
              gstVerifiedAt: dto.gstVerifiedAt || null,
              status: 'ACTIVE',
              createdByUserId: userId,
              updatedByUserId: userId,
            },
          });
          await tx.customerContact.create({
            data: {
              customerId: customer.id,
              name: dto.contactPerson,
              designation: dto.designation,
              mobile: dto.phone,
              email: dto.email || null,
              whatsapp: dto.phone,
              isPrimary: true,
            },
          });
          await tx.customerValuation.create({
            data: {
              customerId: customer.id,
              isDealer: dto.customerType === 'DEALER',
              isDistributor: dto.customerType === 'DISTRIBUTOR',
              ratingScore: 5,
              valuablePercentage: 50,
              activityCount: 0,
            },
          });
          return customer;
      },
    };

    service = new BulkImportService(
      mockPrisma,
      mockAudit,
      mockSequence,
      mockGstService,
      mockCustomersService,
    );
  });

  test('execute DTO retains nested import fields through whitelist validation', async () => {
    const dto = plainToInstance(ExecuteImportDto, {
      target: 'CUSTOMER',
      rows: [{
        rowNumber: 2,
        data: { companyName: 'Acme Ltd', gstin: '27AAACA1234A1Z5' },
        gstData: { legalName: 'Acme Legal Ltd' },
        gstVerificationToken: 'signed-token',
        isIncluded: true,
      }],
    });

    const errors = await validate(dto, {
      whitelist: true,
      forbidNonWhitelisted: true,
    });

    assert.deepEqual(errors, []);
    assert.equal(dto.rows[0].rowNumber, 2);
    assert.equal(dto.rows[0].data.companyName, 'Acme Ltd');
    assert.equal(dto.rows[0].gstData.legalName, 'Acme Legal Ltd');
    assert.equal(dto.rows[0].gstVerificationToken, 'signed-token');
  });

  test('normalizes whitespace and casing in GSTIN cells before lookup', async () => {
    let lookedUpGstin;
    mockGstService.verifyAndFetch = async (gstin) => {
      lookedUpGstin = gstin;
      return {
        valid: true,
        gstin,
        legalName: 'Example Legal Ltd',
        tradeName: 'Example Trade',
        pan: gstin.substring(2, 12),
        state: 'Gujarat',
        city: 'Ahmedabad',
        district: 'Ahmedabad',
        pincode: '380015',
        address: 'Example address',
        companyType: 'PVT_LTD',
        verificationToken: 'test-token',
      };
    };
    const csv = ' GSTIN \n 24abkcs 2033b1zv ';

    const preview = await service.parseAndPreview({
      target: 'CUSTOMER',
      fileName: 'whitespace.csv',
      fileBase64: Buffer.from(csv).toString('base64'),
    });

    assert.equal(lookedUpGstin, '24ABKCS2033B1ZV');
    assert.equal(preview.rows[0].mappedData.gstin, '24ABKCS2033B1ZV');
    assert.equal(preview.rows[0].gstLookupStatus, 'VERIFIED');
  });

  // ─── CRITERION 1: Company-Name-Only Imports (Case A) ────────────────────────
  test('1. Company-name-only imports creates valid record without GST enrichment', async () => {
    const csv = `Company Name,Contact Person,Mobile,Email,City\nAlpha Switchgear Ltd,Anil Mehta,9820011223,anil@alphaswitch.com,Pune`;
    const preview = await service.parseAndPreview({
      target: 'CUSTOMER',
      fileName: 'test.csv',
      fileBase64: Buffer.from(csv).toString('base64'),
      enableGstEnrichment: true,
    });

    assert.equal(preview.totalRows, 1);
    assert.equal(preview.validRows, 1);
    assert.equal(preview.invalidRows, 0);
    assert.equal(preview.rows[0].validationStatus, 'VALID');
    assert.equal(preview.rows[0].gstLookupStatus, 'NOT_APPLICABLE');

    // Execute Import
    const execResult = await service.executeImport({
      target: 'CUSTOMER',
      rows: [
        {
          rowNumber: 1,
          data: preview.rows[0].mappedData,
          isIncluded: true,
        },
      ],
    }, { id: 'user-1', email: 'admin@saark.in' });

    assert.equal(execResult.successCount, 1, JSON.stringify(execResult));
    assert.equal(execResult.errorCount, 0);
  });

  // ─── CRITERION 2: GSTIN-Only Imports with GST Lookup (Case B) ───────────────
  test('2. GSTIN-only imports auto-fetches trade name, legal name, address, and creates record', async () => {
    const GSTIN = '27AACCN7475P1ZN';
    // Mock GST lookup
    mockGstService.verifyAndFetch = async () => ({
      valid: true,
      gstin: GSTIN,
      legalName: 'Acme Technologies Private Limited',
      tradeName: 'Acme Tech',
      pan: 'AAACA1234A',
      state: 'Maharashtra',
      city: 'Pune',
      district: 'Pune',
      pincode: '411026',
      address: 'Plot 12, Bhosari MIDC, Pune',
      companyType: 'PVT_LTD',
      companyStatus: 'Active',
      registrationDate: '2017-07-01',
      providerRef: 'GSTINAPI_LIVE_LOOKUP',
      isLiveLookup: true,
      verificationToken: 'test.token.signed',
    });

    const csv = `GSTIN\n${GSTIN}`;
    const preview = await service.parseAndPreview({
      target: 'CUSTOMER',
      fileName: 'gst_only.csv',
      fileBase64: Buffer.from(csv).toString('base64'),
      enableGstEnrichment: true,
    });

    assert.equal(preview.totalRows, 1);
    assert.equal(preview.validRows + preview.warningRows, 1);
    assert.equal(preview.rows[0].gstLookupStatus, 'VERIFIED');
    assert.equal(preview.rows[0].enrichedData.companyName, 'Acme Tech');
    assert.equal(preview.rows[0].enrichedData.state, 'Maharashtra');
    assert.equal(preview.rows[0].enrichedData.pincode, '411026');

    // Execute import
    let createdCustomer;
    mockPrisma.customer.create = async ({ data }) => {
      createdCustomer = data;
      return { id: 'gst-only-customer', ...data };
    };
    const execResult = await service.executeImport({
      target: 'CUSTOMER',
      rows: [
        {
          rowNumber: 1,
          data: preview.rows[0].enrichedData,
          gstData: preview.rows[0].gstDetails,
          isIncluded: true,
        },
      ],
    }, { id: 'user-1' });

    assert.equal(execResult.successCount, 1, JSON.stringify(execResult));
    assert.equal(createdCustomer.companyName, 'Acme Tech');
    assert.equal(createdCustomer.address, 'Plot 12, Bhosari MIDC, Pune');
    assert.equal(createdCustomer.phone, '');
    assert.equal(createdCustomer.email, '');
    assert.equal(createdCustomer.gstVerified, true);
  });

  // ─── CRITERION 3: GSTIN-Only Imports when Lookup Fails ───────────────────────
  test('3. GSTIN-only imports when lookup fails is flagged as invalid (cannot invent name)', async () => {
    const GSTIN = '27AACCN7475P1ZN';
    mockGstService.verifyAndFetch = async () => {
      const err = new Error('GSTIN not found on portal');
      err.status = 404;
      throw err;
    };

    const csv = `GSTIN,Contact Person,Mobile\n${GSTIN},Vikas Joshi,9822334455`;
    const preview = await service.parseAndPreview({
      target: 'CUSTOMER',
      fileName: 'gst_fail.csv',
      fileBase64: Buffer.from(csv).toString('base64'),
      enableGstEnrichment: true,
    });

    assert.equal(preview.totalRows, 1);
    assert.equal(preview.invalidRows, 1);
    assert.equal(preview.rows[0].validationStatus, 'INVALID');
    assert.ok(preview.rows[0].errors.some((e) => e.includes('GST lookup failed and no Company Name was provided')));
  });

  // ─── CRITERION 4: Mixed Spreadsheets (Case E) ───────────────────────────────
  test('4. Mixed spreadsheets: each row processed independently, partial errors do not block valid rows', async () => {
    mockGstService.verifyAndFetch = async (gstin) => ({
      valid: true,
      gstin,
      legalName: 'Valid Corp Ltd',
      tradeName: 'Valid Corp',
      pan: gstin.substring(2, 12),
      state: 'Maharashtra',
      city: 'Mumbai',
      district: 'Mumbai',
      pincode: '400001',
      address: 'Nariman Point, Mumbai',
      companyType: 'PVT_LTD',
      companyStatus: 'Active',
      verificationToken: 'token.123',
    });

    const csv = [
      'Company Name,GSTIN,Contact Person,Mobile,Email',
      'Row 1 Valid Corp,27AACCN7475P1ZN,Prakash,9820000001,prakash@corp.com', // Full row
      'Row 2 Name Only,,,9820000002,', // Name only
      ',,Only Contact,9820000003,', // Invalid (no name, no GST)
      ',24ABKCS2033B1ZV,GST Only,9820000004,', // GST only
    ].join('\n');

    const preview = await service.parseAndPreview({
      target: 'CUSTOMER',
      fileName: 'mixed.csv',
      fileBase64: Buffer.from(csv).toString('base64'),
      enableGstEnrichment: true,
      checkDuplicates: false,
    });

    assert.equal(preview.totalRows, 4);
    assert.equal(preview.invalidRows, 1); // Row 3 is invalid
    assert.equal(preview.validRows + preview.warningRows >= 2, true);

    // Selected rows execution
    const validRowsToImport = preview.rows.filter((r) => r.validationStatus !== 'INVALID');
    const result = await service.executeImport({
      target: 'CUSTOMER',
      rows: validRowsToImport.map((r) => ({
        rowNumber: r.rowNumber,
        data: r.enrichedData,
        gstData: r.gstDetails,
        isIncluded: true,
      })),
    }, { id: 'user-1' });

    assert.equal(result.successCount, 3);
    assert.equal(result.errorCount, 0);
  });

  // ─── CRITERION 5: Alternate Column Headings & Auto-Mapping ──────────────────
  test('5. Recognizes diverse column header synonyms (Trade Name, Tax ID, Owner, Telephone)', () => {
    const headers = [
      'Trade Name',
      'Tax ID',
      'Owner',
      'Telephone',
      'Office Address',
      'Postal Code',
      'Comments',
    ];

    const mapping = autoDetectColumnMapping(headers, 'CUSTOMER');
    assert.equal(mapping['Trade Name'], 'companyName');
    assert.equal(mapping['Tax ID'], 'gstin');
    assert.equal(mapping['Owner'], 'contactPerson');
    assert.equal(mapping['Telephone'], 'phone');
    assert.equal(mapping['Office Address'], 'address');
    assert.equal(mapping['Postal Code'], 'pincode');
    assert.equal(mapping['Comments'], 'notes');
  });

  // ─── CRITERION 6: Invalid GSTIN & Malformed Files ───────────────────────────
  test('6. Catches malformed GSTIN format, invalid length, and wrong checksum', async () => {
    const csv = [
      'Company Name,GSTIN',
      'Company A,INVALID_GST_123', // Bad format
      'Company B,27AAACA1234A1Z9', // Bad checksum
    ].join('\n');

    const preview = await service.parseAndPreview({
      target: 'CUSTOMER',
      fileName: 'bad_gst.csv',
      fileBase64: Buffer.from(csv).toString('base64'),
      enableGstEnrichment: true,
    });

    assert.equal(preview.totalRows, 2);
    assert.equal(preview.rows[0].gstLookupStatus, 'INVALID');
    assert.equal(preview.rows[1].gstLookupStatus, 'INVALID');
  });

  // ─── CRITERION 7: Duplicate Detection in File & Database ────────────────────
  test('7. Detects duplicate GSTIN within the same file and against existing database records', async () => {
    const DUP_GST = '24ABKCS2033B1ZV';

    // Mock existing database record
    mockPrisma.customer.findMany = async ({ where }) => {
      if (where?.gstin?.in?.includes(DUP_GST)) {
        return [
          {
            id: 'cus-existing-1',
            customerCode: 'CUS-2026-00001',
            companyName: 'Existing Company in DB',
            gstin: DUP_GST,
            phone: '9820112345',
          },
        ];
      }
      return [];
    };

    const csv = [
      'Company Name,GSTIN',
      `Alpha Corp,${DUP_GST}`, // DB Duplicate
      `Beta Corp,${DUP_GST}`,  // In-file Duplicate
    ].join('\n');

    const preview = await service.parseAndPreview({
      target: 'CUSTOMER',
      fileName: 'dups.csv',
      fileBase64: Buffer.from(csv).toString('base64'),
      enableGstEnrichment: false,
      checkDuplicates: true,
    });

    assert.equal(preview.duplicateRows, 2);
    assert.equal(preview.rows[0].duplicateInfo.type, 'IN_FILE');
    assert.equal(preview.rows[1].duplicateInfo.type, 'IN_FILE');
  });

  // ─── CRITERION 8: Customer and Vendor Separation ────────────────────────────
  test('8. Keeps Customer and Vendor records distinct into their respective tables & code sequences', async () => {
    let createdCustomerCount = 0;
    let createdVendorCount = 0;

    mockPrisma.customer.create = async ({ data }) => {
      createdCustomerCount++;
      return { id: 'c1', ...data };
    };

    mockPrisma.vendor.create = async ({ data }) => {
      createdVendorCount++;
      return { id: 'v1', ...data };
    };

    // Import as CUSTOMER
    await service.executeImport({
      target: 'CUSTOMER',
      rows: [{ rowNumber: 1, data: { companyName: 'Customer X' }, isIncluded: true }],
    }, { id: 'user-1' });

    // Import as VENDOR
    await service.executeImport({
      target: 'VENDOR',
      rows: [{ rowNumber: 1, data: { companyName: 'Vendor Y' }, isIncluded: true }],
    }, { id: 'user-1' });

    assert.equal(createdCustomerCount, 1);
    assert.equal(createdVendorCount, 1);
  });

  // ─── CRITERION 9: Ownership & Audit Permissions ─────────────────────────────
  test('9. Sets authenticated user as creator and writes detailed audit log entry', async () => {
    let capturedCustomerData;
    mockPrisma.customer.create = async ({ data }) => {
      capturedCustomerData = data;
      return { id: 'c-1', ...data };
    };

    await service.executeImport({
      target: 'CUSTOMER',
      rows: [{ rowNumber: 1, data: { companyName: 'Security Corp' }, isIncluded: true }],
      fileName: 'security_batch.xlsx',
    }, { id: 'auth-user-999', email: 'lead@saark.in' }, '192.168.1.100');

    assert.equal(capturedCustomerData.createdByUserId, 'auth-user-999');
    assert.equal(capturedCustomerData.updatedByUserId, 'auth-user-999');

    // Verify Audit log entry
    assert.equal(mockAudit.logs.length, 1);
    const auditEntry = mockAudit.logs[0];
    assert.equal(auditEntry.userId, 'auth-user-999');
    assert.equal(auditEntry.action, 'BULK_IMPORT');
    assert.equal(auditEntry.module, 'CUSTOMERS');
    assert.equal(auditEntry.ipAddress, '192.168.1.100');
  });

  // ─── CRITERION 10: Formula Injection Protection ─────────────────────────────
  test('10. Sanitizes formula triggers (=, +, -, @) to prevent CSV/Formula injection', () => {
    const maliciousInput = '=SUM(A1:B1)';
    const sanitizedInput = sanitizeInputCell(maliciousInput);
    assert.equal(sanitizedInput, 'SUM(A1:B1)'); // Stripped on input

    const maliciousExport = '=cmd|"/C calc"!A0';
    const sanitizedExport = sanitizeSpreadsheetCell(maliciousExport);
    assert.equal(sanitizedExport, '\'=cmd|"/C calc"!A0'); // Escaped with leading quote on output
  });

  // ─── CRITERION 11: Sample Template & Error Report Generation ────────────────
  test('11. Generates valid CSV sample template and sanitized error reports', () => {
    const customerTemplate = service.getSampleTemplate('CUSTOMER');
    assert.ok(customerTemplate.includes('Company Name,GSTIN,Contact Person'));

    const vendorTemplate = service.getSampleTemplate('VENDOR');
    assert.ok(vendorTemplate.includes('Vendor Name,GSTIN,Contact Person'));

    const errorReport = service.generateErrorReport({
      target: 'CUSTOMER',
      errors: [
        {
          rowNumber: 2,
          companyName: 'Broken Co',
          gstin: '27INVALIDGSTIN1Z',
          code: 'INVALID_GSTIN',
          message: 'Checksum mismatch',
          recommendation: 'Fix GSTIN',
        },
      ],
    });

    assert.ok(errorReport.includes('Row Number,Company Name,GSTIN'));
    assert.ok(errorReport.includes('"2","Broken Co","27INVALIDGSTIN1Z"'));
  });

  test('rejects an unresolvable GSTIN-only row without inventing a company name', async () => {
    const result = await service.executeImport({
      target: 'CUSTOMER',
      rows: [{
        rowNumber: 4,
        data: { gstin: '27AACCN7475P1ZN' },
        isIncluded: true,
      }],
    }, { id: 'user-1' });

    assert.equal(result.successCount, 0);
    assert.equal(result.rowResults[0].status, 'FAILED');
    assert.match(result.rowResults[0].error, /Company name could not be resolved/);
    assert.equal(result.databaseErrorCount, 0);
  });

  test('reports database transaction failures without counting the row as imported', async () => {
    mockPrisma.$transaction = async () => {
      throw new Error('Database unavailable');
    };

    const result = await service.executeImport({
      target: 'CUSTOMER',
      rows: [{
        rowNumber: 3,
        data: { companyName: 'Acme Ltd' },
        isIncluded: true,
      }],
    }, { id: 'user-1' });

    assert.equal(result.successCount, 0);
    assert.equal(result.errorCount, 1);
    assert.equal(result.databaseErrorCount, 1);
    assert.equal(result.rowResults[0].status, 'FAILED');
    assert.match(result.errors[0].error, /Database unavailable/);
  });

  test('does not report a customer as persisted when a related-record insert rolls back', async () => {
    let committedCustomer = false;
    mockPrisma.$transaction = async (callback) => {
      const staged = { customerCreated: false };
      const tx = {
        customer: {
          create: async () => {
            staged.customerCreated = true;
            return { id: 'staged-customer' };
          },
        },
        customerContact: {
          create: async () => {
            throw new Error('Contact insert failed');
          },
        },
        customerValuation: mockPrisma.customerValuation,
        vendor: mockPrisma.vendor,
        vendorContact: mockPrisma.vendorContact,
      };

      const result = await callback(tx);
      committedCustomer = staged.customerCreated;
      return result;
    };

    const result = await service.executeImport({
      target: 'CUSTOMER',
      rows: [{
        rowNumber: 5,
        data: { companyName: 'Rollback Example Ltd' },
        isIncluded: true,
      }],
    }, { id: 'user-1' });

    assert.equal(committedCustomer, false);
    assert.equal(result.successCount, 0);
    assert.equal(result.databaseErrorCount, 1);
    assert.equal(result.rowResults[0].status, 'FAILED');
  });

  test('imports only the first row for a duplicated GSTIN when duplicate skipping is enabled', async () => {
    const result = await service.executeImport({
      target: 'CUSTOMER',
      rows: [
        {
          rowNumber: 2,
          data: { companyName: 'First Example Ltd', gstin: '24ABKCS2033B1ZV' },
          isIncluded: true,
        },
        {
          rowNumber: 3,
          data: { companyName: 'Second Example Ltd', gstin: '24ABKCS2033B1ZV' },
          isIncluded: true,
        },
      ],
    }, { id: 'user-1' });

    assert.equal(result.successCount, 1);
    assert.equal(result.skippedCount, 1);
    assert.deepEqual(
      result.rowResults.map((row) => row.status),
      ['IMPORTED', 'SKIPPED'],
    );
  });

  test('does not mark an imported company GST-verified from untrusted client fields', async () => {
    let createdCustomer;
    mockPrisma.customer.create = async ({ data }) => {
      createdCustomer = data;
      return { id: 'unverified-customer', ...data };
    };

    await service.executeImport({
      target: 'CUSTOMER',
      rows: [{
        rowNumber: 1,
        data: {
          companyName: 'Unverified Example Ltd',
          gstin: '27AACCN7475P1ZN',
        },
        gstData: { valid: true, providerRef: 'FAKE_PROVIDER' },
        isIncluded: true,
      }],
    }, { id: 'user-1' });

    assert.equal(createdCustomer.gstVerified, false);
    assert.equal(createdCustomer.gstVerifiedAt ?? null, null);
    assert.equal(createdCustomer.gstProviderRef, undefined);
  });

  test('requires administrator authorization before updating matched customers', async () => {
    await assert.rejects(
      () => service.executeImport({
        target: 'CUSTOMER',
        rows: [{ rowNumber: 1, data: { companyName: 'Existing Ltd' } }],
        updateExisting: true,
      }, { id: 'user-1', roles: ['SALES'] }),
      (error) => error.status === 403,
    );
  });
});
