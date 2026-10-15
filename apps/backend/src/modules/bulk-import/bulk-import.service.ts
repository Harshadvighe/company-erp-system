import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import { SequenceService } from '../../core/database/sequence.service';
import { GstVerificationService } from '../crm/gst-verification.service';
import { CustomersService } from '../customers/customers.service';
import {
  parseSpreadsheet,
  autoDetectColumnMapping,
  sanitizeSpreadsheetCell,
  CUSTOMER_COLUMN_DEFINITIONS,
  VENDOR_COLUMN_DEFINITIONS,
} from './excel-parser.util';
import {
  ImportTarget,
  GstLookupStatus,
  RowValidationStatus,
  ParseAndPreviewDto,
  ExecuteImportDto,
  GenerateErrorReportDto,
} from './dto/bulk-import.dto';

const MAX_ROWS = 1000;
const MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024; // 15MB
const CONCURRENT_GST_LOOKUPS = 3;

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_CLEAN_REGEX = /[^0-9]/g;

function trimmed(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

export interface PreviewFieldConflict {
  field: string;
  label: string;
  userValue: string;
  gstValue: string;
}

export interface PreviewRow {
  rowNumber: number;
  isIncluded: boolean;
  validationStatus: RowValidationStatus;
  gstLookupStatus: GstLookupStatus;
  gstStatusReason?: string;
  rawData: Record<string, string>;
  mappedData: Record<string, any>;
  enrichedData: Record<string, any>;
  gstDetails?: any;
  duplicateInfo?: {
    type: 'DATABASE_EXACT' | 'DATABASE_POSSIBLE' | 'IN_FILE';
    field: string;
    existingId?: string;
    existingCode?: string;
    existingName?: string;
    description: string;
  };
  errors: string[];
  warnings: string[];
  conflicts: PreviewFieldConflict[];
}

export interface PreviewResult {
  target: ImportTarget;
  fileName: string;
  sheetNames?: string[];
  selectedSheet?: string;
  totalRows: number;
  validRows: number;
  warningRows: number;
  duplicateRows: number;
  invalidRows: number;
  gstSuccessCount: number;
  gstFailCount: number;
  reviewRowsCount: number;
  detectedHeaders: string[];
  columnMapping: Record<string, string>;
  availableDefinitions: Array<{ field: string; label: string; required: boolean }>;
  rows: PreviewRow[];
}

@Injectable()
export class BulkImportService {
  private readonly logger = new Logger(BulkImportService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly sequenceService: SequenceService,
    private readonly gstVerificationService: GstVerificationService,
    private readonly customersService: CustomersService,
  ) {}

  /**
   * 1. Parse uploaded file, auto-detect columns, validate data, enrich with GST,
   * detect duplicates, and generate comprehensive preview report.
   */
  async parseAndPreview(
    dto: ParseAndPreviewDto,
    fileBuffer?: Buffer,
    user?: any,
  ): Promise<PreviewResult> {
    let buffer: Buffer;
    const fileName = dto.fileName || 'import_file.xlsx';

    if (fileBuffer && fileBuffer.length > 0) {
      buffer = fileBuffer;
    } else if (dto.fileBase64 && dto.fileBase64.trim().length > 0) {
      const base64Data = dto.fileBase64.replace(/^data:.*?;base64,/, '');
      buffer = Buffer.from(base64Data, 'base64');
    } else {
      throw new BadRequestException('No spreadsheet file content provided.');
    }

    if (buffer.length > MAX_FILE_SIZE_BYTES) {
      throw new BadRequestException(
        `File size exceeds maximum allowed limit of ${MAX_FILE_SIZE_BYTES / (1024 * 1024)}MB.`,
      );
    }

    // 1. Parse spreadsheet
    const parsed = parseSpreadsheet(fileName, buffer, { sheetName: dto.sheetName });

    if (parsed.rowCount === 0) {
      throw new BadRequestException('The uploaded spreadsheet contains no data rows.');
    }

    if (parsed.rowCount > MAX_ROWS) {
      throw new BadRequestException(
        `File contains ${parsed.rowCount} rows. Maximum allowed rows per import job is ${MAX_ROWS}.`,
      );
    }

    // 2. Resolve column mapping
    const autoMapping = autoDetectColumnMapping(parsed.headers, dto.target);
    const activeMapping: Record<string, string> = {
      ...autoMapping,
      ...(dto.columnMapping || {}),
    };

    const definitions =
      dto.target === ImportTarget.CUSTOMER
        ? CUSTOMER_COLUMN_DEFINITIONS
        : VENDOR_COLUMN_DEFINITIONS;

    // 3. Collect in-file duplicate trackers
    const gstinCountInFile = new Map<string, number[]>();
    const phoneCountInFile = new Map<string, number[]>();
    const nameCountInFile = new Map<string, number[]>();

    const preliminaryRows: Array<{
      rowNumber: number;
      rawData: Record<string, string>;
      mappedData: Record<string, any>;
    }> = [];

    parsed.rawRows.forEach((rawRow) => {
      const rowNumber = parseInt(rawRow._originalRowNumber || '0', 10);
      const mappedData: Record<string, any> = {};

      Object.entries(rawRow).forEach(([header, val]) => {
        if (header.startsWith('_')) return;
        const targetField = activeMapping[header];
        if (targetField && val !== undefined && val !== null && val.trim().length > 0) {
          mappedData[targetField] =
            targetField === 'gstin'
              ? val.replace(/\s+/g, '').toUpperCase()
              : val.trim();
        }
      });

      preliminaryRows.push({ rowNumber, rawData: rawRow, mappedData });

      // Track GSTIN
      if (mappedData.gstin) {
        const cleanGst = mappedData.gstin.trim().toUpperCase();
        if (!gstinCountInFile.has(cleanGst)) gstinCountInFile.set(cleanGst, []);
        gstinCountInFile.get(cleanGst)!.push(rowNumber);
      }

      // Track Phone
      if (mappedData.phone) {
        const cleanPhone = mappedData.phone.replace(PHONE_CLEAN_REGEX, '');
        if (cleanPhone.length >= 7) {
          const trackKey = cleanPhone.length >= 10 ? cleanPhone.slice(-10) : cleanPhone;
          if (!phoneCountInFile.has(trackKey)) phoneCountInFile.set(trackKey, []);
          phoneCountInFile.get(trackKey)!.push(rowNumber);
        }
      }

      // Track Company Name
      if (mappedData.companyName) {
        const cleanName = mappedData.companyName.trim().toLowerCase();
        if (!nameCountInFile.has(cleanName)) nameCountInFile.set(cleanName, []);
        nameCountInFile.get(cleanName)!.push(rowNumber);
      }
    });

    // 4. Batch query existing records from database for duplicate checks
    const gstinList = Array.from(gstinCountInFile.keys());
    const phoneList = preliminaryRows
      .map((r) => r.mappedData.phone)
      .filter((p): p is string => Boolean(p && p.length > 5));
    const nameList = preliminaryRows
      .map((r) => r.mappedData.companyName)
      .filter((n): n is string => Boolean(n && n.length > 2));

    let existingByGstin = new Map<string, any>();
    let existingByPhone = new Map<string, any>();
    let existingByName = new Map<string, any>();

    if (dto.checkDuplicates !== false) {
      if (dto.target === ImportTarget.CUSTOMER) {
        const [gstMatches, phoneMatches, nameMatches] = await Promise.all([
          gstinList.length > 0
            ? this.prisma.customer.findMany({
                where: { gstin: { in: gstinList }, status: { not: 'DELETED' } },
                select: { id: true, customerCode: true, companyName: true, gstin: true, phone: true, email: true },
              })
            : [],
          phoneList.length > 0
            ? this.prisma.customer.findMany({
                where: {
                  OR: [
                    { phone: { in: phoneList } },
                    ...phoneList.map((p) => {
                      const d = p.replace(PHONE_CLEAN_REGEX, '');
                      return { phone: { contains: d.length >= 10 ? d.slice(-10) : d } };
                    }),
                  ],
                  status: { not: 'DELETED' },
                },
                select: { id: true, customerCode: true, companyName: true, gstin: true, phone: true },
                take: 100,
              })
            : [],
          nameList.length > 0
            ? this.prisma.customer.findMany({
                where: { companyName: { in: nameList }, status: { not: 'DELETED' } },
                select: { id: true, customerCode: true, companyName: true, gstin: true },
                take: 100,
              })
            : [],
        ]);

        gstMatches.forEach((c) => {
          if (c.gstin) existingByGstin.set(c.gstin.trim().toUpperCase(), { ...c, code: c.customerCode });
        });
        phoneMatches.forEach((c) => {
          if (c.phone) {
            existingByPhone.set(c.phone.trim(), { ...c, code: c.customerCode });
            const digits = c.phone.replace(PHONE_CLEAN_REGEX, '');
            if (digits.length >= 10) {
              existingByPhone.set(digits.slice(-10), { ...c, code: c.customerCode });
            }
          }
        });
        nameMatches.forEach((c) => {
          if (c.companyName) existingByName.set(c.companyName.trim().toLowerCase(), { ...c, code: c.customerCode });
        });
      } else {
        const [gstMatches, phoneMatches, nameMatches] = await Promise.all([
          gstinList.length > 0
            ? this.prisma.vendor.findMany({
                where: { gstin: { in: gstinList }, status: { not: 'DELETED' } },
                select: { id: true, vendorCode: true, companyName: true, gstin: true, phone: true, email: true },
              })
            : [],
          phoneList.length > 0
            ? this.prisma.vendor.findMany({
                where: {
                  OR: [
                    { phone: { in: phoneList } },
                    ...phoneList.map((p) => {
                      const d = p.replace(PHONE_CLEAN_REGEX, '');
                      return { phone: { contains: d.length >= 10 ? d.slice(-10) : d } };
                    }),
                  ],
                  status: { not: 'DELETED' },
                },
                select: { id: true, vendorCode: true, companyName: true, gstin: true, phone: true },
                take: 100,
              })
            : [],
          nameList.length > 0
            ? this.prisma.vendor.findMany({
                where: { companyName: { in: nameList }, status: { not: 'DELETED' } },
                select: { id: true, vendorCode: true, companyName: true, gstin: true },
                take: 100,
              })
            : [],
        ]);

        gstMatches.forEach((v) => {
          if (v.gstin) existingByGstin.set(v.gstin.trim().toUpperCase(), { ...v, code: v.vendorCode });
        });
        phoneMatches.forEach((v) => {
          if (v.phone) {
            existingByPhone.set(v.phone.trim(), { ...v, code: v.vendorCode });
            const digits = v.phone.replace(PHONE_CLEAN_REGEX, '');
            if (digits.length >= 10) {
              existingByPhone.set(digits.slice(-10), { ...v, code: v.vendorCode });
            }
          }
        });
        nameMatches.forEach((v) => {
          if (v.companyName) existingByName.set(v.companyName.trim().toLowerCase(), { ...v, code: v.vendorCode });
        });
      }
    }

    // 5. GST Auto-Fetch Cache & Deduplication within this job
    const gstLookupCache = new Map<
      string,
      { success: boolean; data?: any; error?: string; status: GstLookupStatus }
    >();

    const uniqueValidGstins = Array.from(
      new Set(
        preliminaryRows
          .map((r) => r.mappedData.gstin?.trim().toUpperCase())
          .filter(
            (g): g is string =>
              Boolean(g) &&
              this.gstVerificationService.validateFormat(g) &&
              this.gstVerificationService.validateChecksum(g),
          ),
      ),
    );

    if (dto.enableGstEnrichment !== false && uniqueValidGstins.length > 0) {
      await this.batchFetchGst(uniqueValidGstins, gstLookupCache, user?.id);
    }

    // 6. Process each row with comprehensive business logic
    const previewRows: PreviewRow[] = [];
    let validCount = 0;
    let warningCount = 0;
    let duplicateCount = 0;
    let invalidCount = 0;
    let gstSuccessCount = 0;
    let gstFailCount = 0;
    let reviewCount = 0;

    for (const item of preliminaryRows) {
      const { rowNumber, rawData, mappedData } = item;
      const errors: string[] = [];
      const warnings: string[] = [];
      const conflicts: PreviewFieldConflict[] = [];

      let rawGstin = mappedData.gstin?.trim().toUpperCase() || '';
      let rawCompanyName = mappedData.companyName?.trim() || '';
      let rawPhone = mappedData.phone?.trim() || '';
      let rawEmail = mappedData.email?.trim() || '';

      let gstLookupStatus = GstLookupStatus.NOT_APPLICABLE;
      let gstStatusReason: string | undefined;
      let gstDetails: any = null;
      let enrichedData: Record<string, any> = { ...mappedData };

      // A. GSTIN Validation & Lookup
      if (rawGstin) {
        const isFormatValid = this.gstVerificationService.validateFormat(rawGstin);
        const isChecksumValid = isFormatValid && this.gstVerificationService.validateChecksum(rawGstin);

        if (!isFormatValid) {
          gstLookupStatus = GstLookupStatus.INVALID;
          gstStatusReason = 'Invalid 15-character GSTIN format';
          errors.push('GSTIN format is invalid (must be 15 characters, e.g. 27AAAAA0000A1Z5)');
          gstFailCount++;
        } else if (!isChecksumValid) {
          gstLookupStatus = GstLookupStatus.INVALID;
          gstStatusReason = 'Invalid GSTIN checksum digit';
          errors.push('GSTIN checksum digit is incorrect');
          gstFailCount++;
        } else {
          // Valid format & checksum -> Check GST lookup cache
          const cached = gstLookupCache.get(rawGstin);
          if (cached) {
            gstLookupStatus = cached.status;
            if (cached.success && cached.data) {
              gstDetails = cached.data;
              gstSuccessCount++;
              gstStatusReason = 'Verified via GSTIN Portal';

              // Enrich missing fields from GST
              if (!enrichedData.legalName && gstDetails.legalName) {
                enrichedData.legalName = gstDetails.legalName;
              }
              if (!enrichedData.tradeName && gstDetails.tradeName) {
                enrichedData.tradeName = gstDetails.tradeName;
              }
              if (!enrichedData.pan && gstDetails.pan) {
                enrichedData.pan = gstDetails.pan;
              }
              if (!enrichedData.state && gstDetails.state) {
                enrichedData.state = gstDetails.state;
              }
              if (!enrichedData.city && gstDetails.city) {
                enrichedData.city = gstDetails.city;
              }
              if (!enrichedData.district && gstDetails.district) {
                enrichedData.district = gstDetails.district;
              }
              if (!enrichedData.pincode && gstDetails.pincode) {
                enrichedData.pincode = gstDetails.pincode;
              }
              if (!enrichedData.address && gstDetails.address) {
                enrichedData.address = gstDetails.address;
              }

              // Case B: GSTIN-only row -> Auto-populate company name from GST
              if (!rawCompanyName) {
                rawCompanyName = gstDetails.tradeName || gstDetails.legalName || '';
                enrichedData.companyName = rawCompanyName;
                warnings.push(`Company name auto-populated from GST registration: "${rawCompanyName}"`);
              } else {
                // Check conflicts between user provided values and GST records
                if (
                  gstDetails.legalName &&
                  rawCompanyName.toLowerCase() !== gstDetails.legalName.toLowerCase() &&
                  (!gstDetails.tradeName || rawCompanyName.toLowerCase() !== gstDetails.tradeName.toLowerCase())
                ) {
                  conflicts.push({
                    field: 'companyName',
                    label: 'Company Name vs GST Legal Name',
                    userValue: rawCompanyName,
                    gstValue: gstDetails.legalName,
                  });
                }
                if (
                  enrichedData.state &&
                  gstDetails.state &&
                  enrichedData.state.toLowerCase() !== gstDetails.state.toLowerCase()
                ) {
                  conflicts.push({
                    field: 'state',
                    label: 'State',
                    userValue: enrichedData.state,
                    gstValue: gstDetails.state,
                  });
                }
              }
            } else {
              gstFailCount++;
              gstStatusReason = cached.error || 'GST Portal lookup was unsuccessful';
              // If lookup failed, but row has company name (Case F), don't fail the whole row
              if (rawCompanyName) {
                warnings.push(`GST verification skipped/unavailable: ${gstStatusReason}`);
              } else {
                errors.push(`GST lookup failed and no Company Name was provided: ${gstStatusReason}`);
              }
            }
          }
        }
      }

      // B. Mandatory Requirements Check (Case A, B, C, D, E)
      if (!rawCompanyName && !rawGstin) {
        errors.push('Missing required business identifier: either Company Name or valid GSTIN is required');
      } else if (!rawCompanyName && errors.length > 0) {
        errors.push('Company name could not be resolved from spreadsheet or GSTIN lookup');
      }

      // Contact person check
      if (!enrichedData.contactPerson && !rawCompanyName) {
        errors.push('Contact Person or Company Name is required');
      }

      // Email format check
      if (rawEmail && !EMAIL_REGEX.test(rawEmail)) {
        warnings.push(`Email address "${rawEmail}" looks malformed`);
      }

      // Phone format check
      if (rawPhone) {
        const cleanDigits = rawPhone.replace(PHONE_CLEAN_REGEX, '');
        if (cleanDigits.length < 10) {
          warnings.push(`Phone number "${rawPhone}" has fewer than 10 digits`);
        }
      }

      // C. Duplicate Detection (In-File & In-Database)
      let duplicateInfo: PreviewRow['duplicateInfo'] | undefined;

      // 1. In-file duplicate check (only flag subsequent occurrences as duplicates)
      if (rawGstin && gstinCountInFile.has(rawGstin)) {
        const priorRowsWithSameGst = gstinCountInFile.get(rawGstin)!.filter((r) => r < rowNumber);
        if (priorRowsWithSameGst.length > 0) {
          duplicateInfo = {
            type: 'IN_FILE',
            field: 'gstin',
            description: `GSTIN ${rawGstin} is a duplicate of Row ${priorRowsWithSameGst[0]} in this file`,
          };
          warnings.push(`Duplicate GSTIN inside this file (matches Row ${priorRowsWithSameGst[0]})`);
        }
      }
      if (!duplicateInfo && rawPhone) {
        const cleanDigits = rawPhone.replace(PHONE_CLEAN_REGEX, '');
        const trackKey = cleanDigits.length >= 10 ? cleanDigits.slice(-10) : cleanDigits;
        if (phoneCountInFile.has(trackKey)) {
          const priorRowsWithSamePhone = phoneCountInFile.get(trackKey)!.filter((r) => r < rowNumber);
          if (priorRowsWithSamePhone.length > 0) {
            duplicateInfo = {
              type: 'IN_FILE',
              field: 'phone',
              description: `Phone ${rawPhone} is a duplicate of Row ${priorRowsWithSamePhone[0]} in this file`,
            };
            warnings.push(`Duplicate phone inside this file (matches Row ${priorRowsWithSamePhone[0]})`);
          }
        }
      }
      if (!duplicateInfo && rawCompanyName) {
        const cleanName = rawCompanyName.trim().toLowerCase();
        if (nameCountInFile.has(cleanName)) {
          const priorRowsWithSameName = nameCountInFile.get(cleanName)!.filter((r) => r < rowNumber);
          if (priorRowsWithSameName.length > 0) {
            duplicateInfo = {
              type: 'IN_FILE',
              field: 'companyName',
              description: `Company name "${rawCompanyName}" is a duplicate of Row ${priorRowsWithSameName[0]} in this file`,
            };
            warnings.push(`Duplicate company name inside this file (matches Row ${priorRowsWithSameName[0]})`);
          }
        }
      }

      // 2. Database duplicate check (Exact GSTIN)
      if (!duplicateInfo && rawGstin && existingByGstin.has(rawGstin)) {
        const match = existingByGstin.get(rawGstin);
        duplicateInfo = {
          type: 'DATABASE_EXACT',
          field: 'gstin',
          existingId: match.id,
          existingCode: match.code,
          existingName: match.companyName,
          description: `Exact GSTIN duplicate with existing record "${match.companyName}" (${match.code})`,
        };
      }

      // 3. Database duplicate check (Exact Phone)
      if (!duplicateInfo && rawPhone) {
        const cleanDigits = rawPhone.replace(PHONE_CLEAN_REGEX, '');
        const match =
          existingByPhone.get(rawPhone) ||
          (cleanDigits.length >= 10 ? existingByPhone.get(cleanDigits.slice(-10)) : undefined);
        if (match) {
          duplicateInfo = {
            type: 'DATABASE_POSSIBLE',
            field: 'phone',
            existingId: match.id,
            existingCode: match.code,
            existingName: match.companyName,
            description: `Phone ${rawPhone} already used by "${match.companyName}" (${match.code})`,
          };
          warnings.push(`Phone number matches existing record "${match.companyName}" (${match.code})`);
        }
      }

      // 4. Database duplicate check (Exact Company Name)
      if (!duplicateInfo && rawCompanyName && existingByName.has(rawCompanyName.toLowerCase())) {
        const match = existingByName.get(rawCompanyName.toLowerCase());
        duplicateInfo = {
          type: 'DATABASE_POSSIBLE',
          field: 'companyName',
          existingId: match.id,
          existingCode: match.code,
          existingName: match.companyName,
          description: `Company name matches existing record "${match.companyName}" (${match.code})`,
        };
        warnings.push(`Company name matches existing record "${match.companyName}" (${match.code})`);
      }

      // D. Determine Row Validation Status
      let validationStatus = RowValidationStatus.VALID;
      if (errors.length > 0) {
        validationStatus = RowValidationStatus.INVALID;
        invalidCount++;
      } else if (duplicateInfo?.type === 'DATABASE_EXACT') {
        validationStatus = RowValidationStatus.DUPLICATE_EXACT;
        duplicateCount++;
      } else if (duplicateInfo?.type === 'IN_FILE' || duplicateInfo?.type === 'DATABASE_POSSIBLE') {
        validationStatus = RowValidationStatus.DUPLICATE_POSSIBLE;
        duplicateCount++;
      } else if (warnings.length > 0 || conflicts.length > 0) {
        validationStatus = RowValidationStatus.WARNING;
        warningCount++;
      } else {
        validationStatus = RowValidationStatus.VALID;
        validCount++;
      }

      if (conflicts.length > 0 || duplicateInfo || warnings.length > 0) {
        reviewCount++;
      }

      // Default inclusion
      const isIncluded =
        validationStatus === RowValidationStatus.VALID ||
        validationStatus === RowValidationStatus.WARNING;

      previewRows.push({
        rowNumber,
        isIncluded,
        validationStatus,
        gstLookupStatus,
        gstStatusReason,
        rawData,
        mappedData,
        enrichedData,
        gstDetails,
        duplicateInfo,
        errors,
        warnings,
        conflicts,
      });
    }

    return {
      target: dto.target,
      fileName,
      sheetNames: parsed.sheetNames,
      selectedSheet: parsed.selectedSheet,
      totalRows: previewRows.length,
      validRows: validCount,
      warningRows: warningCount,
      duplicateRows: duplicateCount,
      invalidRows: invalidCount,
      gstSuccessCount,
      gstFailCount,
      reviewRowsCount: reviewCount,
      detectedHeaders: parsed.headers,
      columnMapping: activeMapping,
      availableDefinitions: definitions.map((d) => ({
        field: d.field,
        label: d.label,
        required: d.required,
      })),
      rows: previewRows,
    };
  }

  /**
   * Helper: Batch lookup GSTINs with controlled concurrency & error capture
   */
  private async batchFetchGst(
    gstins: string[],
    cache: Map<
      string,
      { success: boolean; data?: any; error?: string; status: GstLookupStatus }
    >,
    userId?: string,
  ): Promise<void> {
    for (let i = 0; i < gstins.length; i += CONCURRENT_GST_LOOKUPS) {
      const batch = gstins.slice(i, i + CONCURRENT_GST_LOOKUPS);
      await Promise.all(
        batch.map(async (gstin) => {
          if (cache.has(gstin)) return;
          try {
            const res = await this.gstVerificationService.verifyAndFetch(gstin, userId);
            cache.set(gstin, {
              success: true,
              data: res,
              status: GstLookupStatus.VERIFIED,
            });
          } catch (err: any) {
            const status =
              err.status === 404
                ? GstLookupStatus.INVALID
                : GstLookupStatus.LOOKUP_FAILED;
            cache.set(gstin, {
              success: false,
              error: err.message || 'GST lookup failed',
              status,
            });
          }
        }),
      );
    }
  }

  /**
   * 2. Execute bulk import into Customer or Vendor database tables.
   * Runs in controlled per-row batches with transaction safety and audit logging.
   */
  async executeImport(
    dto: ExecuteImportDto,
    user?: any,
    ipAddress?: string,
  ) {
    if (
      dto.updateExisting &&
      !['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].some((role) =>
        user?.roles?.includes(role),
      )
    ) {
      throw new ForbiddenException('Only administrators can update existing records during import.');
    }

    if (!dto.rows || dto.rows.length === 0) {
      throw new BadRequestException('No rows provided for import.');
    }

    const rowsToImport = dto.rows.filter((r) => r.isIncluded !== false);
    if (rowsToImport.length === 0) {
      throw new BadRequestException('No rows are selected for import.');
    }

    let successCount = 0;
    let updatedCount = 0;
    let skippedCount = 0;
    let databaseErrorCount = 0;
    const errors: Array<{ rowNumber: number; companyName?: string; error: string }> = [];
    const rowResults: Array<{
      rowNumber: number;
      companyName?: string;
      status: 'IMPORTED' | 'UPDATED' | 'SKIPPED' | 'FAILED';
      error?: string;
    }> = [];
    const seenIdentifiers = new Set<string>();

    // Find linked staff ID for owner assignment if authenticated
    let userStaffId: string | undefined;
    let ownerName: string | undefined;
    if (user?.id) {
      const staff = await this.prisma.staff.findFirst({ where: { userId: user.id } });
      if (staff) {
        userStaffId = staff.id;
        ownerName = staff.fullName;
      } else {
        ownerName = user.fullName || user.email || 'System';
      }
    }

    for (const item of rowsToImport) {
      const { rowNumber, data, gstData, gstVerificationToken } = item;
      const combined = { ...(gstData || {}), ...(data || {}) };

      const gstin = typeof combined.gstin === 'string' && combined.gstin.trim()
        ? combined.gstin.replace(/\s+/g, '').toUpperCase()
        : null;
      const companyName =
        trimmed(combined.companyName) ||
        trimmed(combined.tradeName) ||
        trimmed(combined.legalName) ||
        '';

      if (gstin && (
        !this.gstVerificationService.validateFormat(gstin) ||
        !this.gstVerificationService.validateChecksum(gstin)
      )) {
        const error = 'GSTIN format or checksum is invalid.';
        errors.push({ rowNumber, companyName: companyName || undefined, error });
        rowResults.push({ rowNumber, companyName: companyName || undefined, status: 'FAILED', error });
        continue;
      }

      const verificationToken =
        gstVerificationToken ||
        (typeof gstData?.verificationToken === 'string' ? gstData.verificationToken : undefined);
      let verification: ReturnType<GstVerificationService['getVerifiedMetadata']> = null;
      if (gstin && verificationToken) {
        try {
          verification = this.gstVerificationService.getVerifiedMetadata(
            verificationToken,
            gstin,
            user?.id,
          );
        } catch (err: any) {
          this.logger.warn(
            `Row ${rowNumber}: GST verification check failed (${err.message}). Retaining row data with unverified GST status.`,
          );
          verification = null;
        }
      }

      if (!companyName) {
        const error = gstin
          ? 'Company name could not be resolved from the GST lookup. Retry the GST lookup or provide a company name.'
          : 'Missing required company name and GSTIN.';
        errors.push({ rowNumber, error });
        rowResults.push({ rowNumber, status: 'FAILED', error });
        continue;
      }

      const finalCompanyName = companyName;
      const cleanPhone = trimmed(combined.phone);
      const cleanEmail = trimmed(combined.email);
      const cleanContact = trimmed(combined.contactPerson) || finalCompanyName;
      const cleanAddress = trimmed(combined.address);
      const cleanCity = trimmed(combined.city);
      const cleanDistrict = trimmed(combined.district);
      const cleanState = trimmed(combined.state);
      const cleanPincode = trimmed(combined.pincode);
      const vendorPhone = cleanPhone || '0000000000';
      const vendorAddress = cleanAddress || 'Registered Office';
      const vendorCity = cleanCity || 'Pune';
      const vendorDistrict = cleanDistrict || vendorCity;
      const vendorState = cleanState || 'Maharashtra';
      const vendorPincode = cleanPincode || '400001';

      // Duplicate prevention within import batch (by GSTIN, phone, or company name)
      const phoneDigits = cleanPhone.replace(PHONE_CLEAN_REGEX, '');
      const duplicateKey = gstin
        ? `gstin:${gstin}`
        : phoneDigits.length >= 10
        ? `phone:${phoneDigits.slice(-10)}`
        : `name:${finalCompanyName.toLowerCase().trim()}`;

      if (dto.skipDuplicates !== false && seenIdentifiers.has(duplicateKey)) {
        const error = `Duplicate row with identifier (${duplicateKey}) inside this import batch was skipped.`;
        skippedCount++;
        rowResults.push({ rowNumber, companyName: finalCompanyName, status: 'SKIPPED', error });
        continue;
      }
      seenIdentifiers.add(duplicateKey);

      // Collect unmapped non-empty spreadsheet columns
      const unmappedEntries: string[] = [];
      const rawData = item.rawData;
      if (rawData) {
        for (const [colName, val] of Object.entries(rawData)) {
          if (colName.startsWith('_')) continue;
          const targetField = dto.columnMapping ? dto.columnMapping[colName] : undefined;
          const isStandardField = [
            'companyName', 'legalName', 'tradeName', 'gstin', 'pan', 'phone',
            'email', 'address', 'city', 'state', 'pincode', 'contactPerson',
            'customerType', 'industry', 'turnover', 'creditLimit', 'paymentTerms',
            'outcome', 'remarks', 'followUp1', 'followUp2', 'quotation', 'date',
          ].includes(targetField || '');

          if (!isStandardField && val && typeof val === 'string' && val.trim().length > 0) {
            unmappedEntries.push(`${colName}: ${val.trim()}`);
          }
        }
      }

      try {
        if (dto.target === ImportTarget.CUSTOMER) {
          // Check existing customer by GSTIN, Phone (last 10 digits), or Company Name
          let existingCustomer: any = null;
          if (gstin) {
            existingCustomer = await this.prisma.customer.findFirst({
              where: { gstin, status: { not: 'DELETED' } },
            });
          }
          if (!existingCustomer && phoneDigits.length >= 10) {
            existingCustomer = await this.prisma.customer.findFirst({
              where: {
                phone: { contains: phoneDigits.slice(-10) },
                status: { not: 'DELETED' },
              },
            });
          }
          if (!existingCustomer && finalCompanyName) {
            existingCustomer = await this.prisma.customer.findFirst({
              where: {
                companyName: { equals: finalCompanyName },
                status: { not: 'DELETED' },
              },
            });
          }

          if (existingCustomer) {
            if (dto.updateExisting) {
              await this.prisma.customer.update({
                where: { id: existingCustomer.id },
                data: {
                  companyName: finalCompanyName,
                  legalName: trimmed(combined.legalName) || trimmed(gstData?.legalName) || existingCustomer.legalName,
                  tradeName: trimmed(combined.tradeName) || trimmed(gstData?.tradeName) || existingCustomer.tradeName,
                  pan: trimmed(combined.pan) || trimmed(gstData?.pan) || existingCustomer.pan,
                  contactPerson: cleanContact,
                  designation: combined.designation || existingCustomer.designation,
                  email: cleanEmail || existingCustomer.email,
                  phone: cleanPhone || existingCustomer.phone,
                  alternatePhone: combined.alternatePhone || existingCustomer.alternatePhone,
                  website: combined.website || existingCustomer.website,
                  address: cleanAddress || existingCustomer.address,
                  city: cleanCity || existingCustomer.city,
                  district: cleanDistrict || existingCustomer.district,
                  state: cleanState || existingCustomer.state,
                  pincode: cleanPincode || existingCustomer.pincode,
                  gstVerified: Boolean(verification?.gstVerified || existingCustomer.gstVerified),
                  gstVerifiedAt: verification?.gstVerifiedAt || existingCustomer.gstVerifiedAt,
                  gstProviderRef: verification?.gstProviderRef || existingCustomer.gstProviderRef,
                  updatedByUserId: user?.id,
                },
              });
              updatedCount++;
              rowResults.push({ rowNumber, companyName: finalCompanyName, status: 'UPDATED' });
            } else {
              skippedCount++;
              rowResults.push({
                rowNumber,
                companyName: finalCompanyName,
                status: 'SKIPPED',
                error: 'Matching customer already exists.',
              });
            }
          } else {
            // Atomic transaction for Customer + Primary Contact + Valuation + Calling Interaction
            await this.prisma.$transaction(async (tx) => {
              const newCustomer = await this.customersService.createInTransaction(
                tx,
                {
                  companyName: finalCompanyName,
                  legalName: trimmed(combined.legalName) || trimmed(gstData?.legalName) || finalCompanyName,
                  tradeName: trimmed(combined.tradeName) || trimmed(gstData?.tradeName) || undefined,
                  gstin,
                  pan: trimmed(combined.pan) || trimmed(gstData?.pan) || (gstin && gstin.length >= 12 ? gstin.substring(2, 12) : null),
                  customerType: combined.customerType || 'END_CUSTOMER',
                  customerCategory: combined.customerCategory || 'STANDARD',
                  customerSegment: trimmed(combined.industry) || trimmed(combined.customerSegment) || 'VFD_PANEL',
                  contactPerson: cleanContact,
                  designation: trimmed(combined.designation) || null,
                  email: cleanEmail,
                  phone: cleanPhone,
                  alternatePhone: combined.alternatePhone,
                  website: combined.website,
                  address: cleanAddress || 'Main Office',
                  country: combined.country || 'India',
                  state: cleanState || 'Maharashtra',
                  district: cleanDistrict || cleanCity || 'Pune',
                  city: cleanCity || 'Pune',
                  pincode: cleanPincode || '411001',
                  ownerName: ownerName || 'Self',
                  assignedStaffId: userStaffId,
                  gstStatus: gstin ? 'GST_REGISTERED' : 'NO_GST',
                  gstVerified: Boolean(verification?.gstVerified),
                  gstVerifiedAt: verification?.gstVerifiedAt,
                  gstProviderRef: verification?.gstProviderRef,
                  companyType: trimmed(gstData?.companyType) || trimmed(combined.companyType) || 'PVT_LTD',
                  industry: combined.industry,
                  turnover: combined.turnover,
                  creditLimit: Number(combined.creditLimit || 0),
                  paymentTerms: trimmed(combined.paymentTerms) || undefined,
                  source: 'EXCEL_IMPORT',
                },
                user?.id,
              );

              // Preserve Calling Sheet calling history, outcomes, and unmapped business fields in CustomerInteraction
              const outcome = combined.outcome || null;
              const remarks = combined.remarks || null;
              const followUp1 = combined.followUp1 || null;
              const followUp2 = combined.followUp2 || null;
              const quotation = combined.quotation || null;
              const dateVal = combined.date || null;

              if (outcome || remarks || followUp1 || followUp2 || quotation || unmappedEntries.length > 0) {
                const descParts: string[] = [];
                if (remarks) descParts.push(`Remarks: ${remarks}`);
                if (followUp1) descParts.push(`Follow-Up 1: ${followUp1}`);
                if (followUp2) descParts.push(`Follow-Up 2: ${followUp2}`);
                if (quotation) descParts.push(`Quotation: ${quotation}`);
                if (unmappedEntries.length > 0) {
                  descParts.push('--- Additional Spreadsheet Data ---');
                  descParts.push(...unmappedEntries);
                }

                let nextFollowUpDate: Date | null = null;
                const potentialDateStr = followUp1 || followUp2;
                if (potentialDateStr) {
                  const parsedDate = new Date(potentialDateStr);
                  if (!isNaN(parsedDate.getTime())) {
                    nextFollowUpDate = parsedDate;
                  }
                }

                let callDate = new Date();
                if (dateVal) {
                  const parsedCallDate = new Date(dateVal);
                  if (!isNaN(parsedCallDate.getTime())) {
                    callDate = parsedCallDate;
                  }
                }

                await tx.customerInteraction.create({
                  data: {
                    customerId: newCustomer.id,
                    interactionType: 'CALL',
                    interactionDate: callDate,
                    subject: `Calling Record - ${outcome || 'Initial Contact'}`,
                    description: descParts.join('\n') || 'Imported calling record',
                    outcome: outcome || 'LOGGED',
                    nextFollowUp: nextFollowUpDate,
                    recordedBy: ownerName || 'Excel Import',
                  },
                });
              }
            });

            successCount++;
            rowResults.push({ rowNumber, companyName: finalCompanyName, status: 'IMPORTED' });
          }
        } else {
          // VENDOR IMPORT
          let existingVendor: any = null;
          if (gstin) {
            existingVendor = await this.prisma.vendor.findFirst({
              where: { gstin, status: { not: 'DELETED' } },
            });
          }
          if (!existingVendor && phoneDigits.length >= 10) {
            existingVendor = await this.prisma.vendor.findFirst({
              where: {
                phone: { contains: phoneDigits.slice(-10) },
                status: { not: 'DELETED' },
              },
            });
          }
          if (!existingVendor && finalCompanyName) {
            existingVendor = await this.prisma.vendor.findFirst({
              where: {
                companyName: { equals: finalCompanyName },
                status: { not: 'DELETED' },
              },
            });
          }

          if (existingVendor) {
            if (dto.updateExisting) {
              await this.prisma.vendor.update({
                where: { id: existingVendor.id },
                data: {
                  companyName: finalCompanyName,
                  legalName: trimmed(combined.legalName) || trimmed(gstData?.legalName) || existingVendor.legalName,
                  pan: trimmed(combined.pan) || trimmed(gstData?.pan) || existingVendor.pan,
                  contactPerson: cleanContact,
                  designation: combined.designation || existingVendor.designation,
                  email: cleanEmail || existingVendor.email,
                  phone: cleanPhone || existingVendor.phone,
                  alternatePhone: combined.alternatePhone || existingVendor.alternatePhone,
                  website: combined.website || existingVendor.website,
                  address: vendorAddress !== 'Factory / Registered Office' ? vendorAddress : existingVendor.address,
                  city: vendorCity,
                  district: vendorDistrict,
                  state: vendorState,
                  pincode: vendorPincode,
                  productsSupplied: combined.productsSupplied || existingVendor.productsSupplied,
                  updatedByUserId: user?.id,
                },
              });
              updatedCount++;
              rowResults.push({ rowNumber, companyName: finalCompanyName, status: 'UPDATED' });
            } else {
              skippedCount++;
              rowResults.push({
                rowNumber,
                companyName: finalCompanyName,
                status: 'SKIPPED',
                error: 'Matching vendor already exists.',
              });
            }
          } else {
            // Atomic transaction for Vendor + Primary Contact
            await this.prisma.$transaction(async (tx) => {
              const vendorCode = await this.sequenceService.nextVendorCode();

              const newVendor = await tx.vendor.create({
                data: {
                  vendorCode,
                  companyName: finalCompanyName,
                  legalName: trimmed(combined.legalName) || trimmed(gstData?.legalName) || finalCompanyName,
                  gstin,
                  pan: combined.pan || gstData?.pan || (gstin && gstin.length >= 12 ? gstin.substring(2, 12) : null),
                  vendorType: combined.vendorType || 'MANUFACTURER',
                  vendorCategory: combined.vendorCategory || 'STANDARD',
                  constitution: combined.constitution || gstData?.companyType || 'PROPRIETORSHIP',
                  contactPerson: cleanContact,
                  designation: trimmed(combined.designation) || 'Manager',
                  email: cleanEmail || `${vendorCode.toLowerCase()}@example.com`,
                  phone: vendorPhone,
                  alternatePhone: combined.alternatePhone,
                  website: combined.website,
                  address: vendorAddress,
                  country: combined.country || 'India',
                  state: vendorState,
                  district: vendorDistrict,
                  city: vendorCity,
                  pincode: vendorPincode,
                  productsSupplied: combined.productsSupplied,
                  paymentTerms: combined.paymentTerms || 'NET_30',
                  creditLimit: Number(combined.creditLimit || 0),
                  msmeStatus: combined.msmeStatus || 'NO',
                  rating: 5.0,
                  approvalStatus: 'APPROVED',
                  assignedStaffId: userStaffId,
                  createdByUserId: user?.id,
                  updatedByUserId: user?.id,
                  status: 'ACTIVE',
                },
              });

              if (cleanContact) {
                await tx.vendorContact.create({
                  data: {
                    vendorId: newVendor.id,
                    contactPerson: cleanContact,
                    designation: combined.designation,
                    mobile: vendorPhone,
                    email: cleanEmail || null,
                    isPrimary: true,
                  },
                });
              }
            });

            successCount++;
            rowResults.push({ rowNumber, companyName: finalCompanyName, status: 'IMPORTED' });
          }
        }
      } catch (err: any) {
        this.logger.error(`Import error on row ${rowNumber}: ${err.message}`, err.stack);
        databaseErrorCount++;
        errors.push({
          rowNumber,
          companyName: finalCompanyName,
          error: err.message || 'Database insert failed',
        });
        rowResults.push({
          rowNumber,
          companyName: finalCompanyName,
          status: 'FAILED',
          error: err.message || 'Database insert failed',
        });
      }
    }

    // Write Audit Log
    await this.auditService.log({
      userId: user?.id,
      userEmail: user?.email,
      action: 'BULK_IMPORT',
      module: dto.target === ImportTarget.CUSTOMER ? 'CUSTOMERS' : 'VENDORS',
      entityType: dto.target === ImportTarget.CUSTOMER ? 'Customer' : 'Vendor',
      details: `Bulk Import (${dto.target}) Completed: ${successCount} imported, ${updatedCount} updated, ${skippedCount} skipped, ${errors.length} failed. File: ${dto.fileName || 'spreadsheet'}`,
      ipAddress,
    });

    return {
      target: dto.target,
      totalProcessed: rowsToImport.length,
      successCount,
      updatedCount,
      skippedCount,
      errorCount: errors.length,
      databaseErrorCount,
      errors,
      rowResults,
    };
  }

  /**
   * 3. Generate sample template CSV with headers and realistic sample rows
   */
  getSampleTemplate(target: ImportTarget): string {
    if (target === ImportTarget.CUSTOMER) {
      return [
        'Company Name,GSTIN,Contact Person,Mobile,Email,Address,City,State,PIN Code,PAN,Customer Type,Industry,Turnover,Payment Terms,Notes',
        'Acme Industrial Automation Pvt Ltd,27AAACA1234A1Z5,Rajesh Sharma,9820123456,rajesh@acmeautomation.in,"Plot 12, Bhosari MIDC",Pune,Maharashtra,411026,AAACA1234A,END_CUSTOMER,Manufacturing,5 Cr,NET_30,Key client for VFD panels',
        'Shree Ganesh Engineering,,Ganesh Patil,9890112233,ganesh@sge.com,"Sector 5, Rabale MIDC",Navi Mumbai,Maharashtra,400701,,DEALER,Automation,1.5 Cr,NET_15,Unregistered small scale dealer',
        ',24ABKCS2033B1ZV,Vijay Patel,9712345678,vijay@gujaratpanels.com,"GIDC Phase 2",Ahmedabad,Gujarat,380015,ABKCS2033B,DISTRIBUTOR,Switchgear,10 Cr,NET_45,Import with GSTIN only - auto fetches trade name',
      ].join('\r\n');
    }

    return [
      'Vendor Name,GSTIN,Contact Person,Mobile,Email,Address,City,State,PIN Code,PAN,Vendor Type,Constitution,Products Supplied,MSME Status,Payment Terms,Notes',
      'Siemens Switchgear Suppliers,27AAACS9821F1ZM,Amit Kulkarni,9822012345,amit.kulkarni@siemensdealer.com,"MIDC Phase II",Pune,Maharashtra,411018,AAACS9821F,MANUFACTURER,PVT_LTD,VFD Drives & Contactors,YES,NET_30,Authorized channel partner',
      'Mahalaxmi Electrical Hardware,,Mahesh Gupta,9422334455,sales@mahalaxmielectrical.in,"Budhwar Peth",Pune,Maharashtra,411002,,DEALER,PROPRIETORSHIP,Enclosures & MS Boxes,NO,NET_15,Local hardware vendor',
      ',29AAACC1234D1ZP,Suresh Rao,9845012345,suresh@bangaloreelectronics.com,"Peenya Industrial Area",Bengaluru,Karnataka,560058,AAACC1234D,MANUFACTURER,PVT_LTD,Transformers & Relays,YES,NET_45,Enriched via GST portal',
    ].join('\r\n');
  }

  /**
   * 4. Generate downloadable error report CSV with spreadsheet formula protection
   */
  generateErrorReport(dto: GenerateErrorReportDto): string {
    const headers = [
      'Row Number',
      'Company Name',
      'GSTIN',
      'Error Code',
      'Error Reason',
      'Recommended Correction',
    ];

    const rows = dto.errors.map((e) => [
      sanitizeSpreadsheetCell(e.rowNumber),
      sanitizeSpreadsheetCell(e.companyName || ''),
      sanitizeSpreadsheetCell(e.gstin || ''),
      sanitizeSpreadsheetCell(e.code),
      sanitizeSpreadsheetCell(e.message),
      sanitizeSpreadsheetCell(e.recommendation || 'Verify values in source spreadsheet and retry import'),
    ]);

    const csvLines = [
      headers.join(','),
      ...rows.map((row) =>
        row
          .map((cell) => {
            const escaped = cell.replace(/"/g, '""');
            return `"${escaped}"`;
          })
          .join(','),
      ),
    ];

    return csvLines.join('\r\n');
  }
}
