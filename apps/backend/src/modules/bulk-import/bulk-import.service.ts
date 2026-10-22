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
  MATERIAL_COLUMN_DEFINITIONS,
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
        : dto.target === ImportTarget.MATERIAL
        ? MATERIAL_COLUMN_DEFINITIONS
        : VENDOR_COLUMN_DEFINITIONS;

    // 3. Collect in-file duplicate trackers
    const gstinCountInFile = new Map<string, number[]>();
    const phoneCountInFile = new Map<string, number[]>();
    const nameCountInFile = new Map<string, number[]>();
    const skuCountInFile = new Map<string, number[]>();

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

      // Track Material SKU
      if (dto.target === ImportTarget.MATERIAL && mappedData.sku) {
        const cleanSku = String(mappedData.sku).trim().replace(/\.0+$/, '');
        if (!skuCountInFile.has(cleanSku)) skuCountInFile.set(cleanSku, []);
        skuCountInFile.get(cleanSku)!.push(rowNumber);
      }

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
    let existingBySku = new Map<string, any>();

    if (dto.checkDuplicates !== false) {
      if (dto.target === ImportTarget.MATERIAL) {
        const skuList = Array.from(skuCountInFile.keys());
        if (skuList.length > 0) {
          const matchedProducts = await this.prisma.product.findMany({
            where: { sku: { in: skuList }, status: { not: 'DELETED' } },
            select: { id: true, sku: true, name: true, purchasePrice: true, sellingPrice: true, make: true, category: { select: { name: true } } },
          });
          matchedProducts.forEach((p) => {
            existingBySku.set(p.sku.trim(), p);
          });
        }
      } else if (dto.target === ImportTarget.CUSTOMER) {
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

      // Handle MATERIAL target preview & validation
      if (dto.target === ImportTarget.MATERIAL) {
        let validationStatus = RowValidationStatus.VALID;
        const rawSku = mappedData.sku ? String(mappedData.sku).trim().replace(/\.0+$/, '') : '';
        const rawName = mappedData.name ? String(mappedData.name).trim() : '';

        // Role/permission-based Internal Pricing protection
        const userPerms: string[] = user?.permissions || [];
        const isAdmin = user?.isAdmin || (user?.roles || []).some((r: string) => ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r));
        const canViewInternalPrice = isAdmin || userPerms.includes('INTERNAL_PRICING:VIEW') || userPerms.includes('MATERIALS:VIEW_INTERNAL_PRICING');

        const enrichedData: Record<string, any> = { ...mappedData };
        if (!canViewInternalPrice) {
          delete mappedData.dpDiscount;
          delete mappedData.dealerPrice;
          delete enrichedData.dpDiscount;
          delete enrichedData.dealerPrice;
        }

        // Validate mandatory fields
        if (!rawSku && !rawName) {
          validationStatus = RowValidationStatus.INVALID;
          errors.push('Mandatory fields missing: Both SKU and Item Name are blank');
        } else if (!rawSku) {
          validationStatus = RowValidationStatus.WARNING;
          warnings.push('SKU is blank; system will auto-assign a SKU upon import');
        }

        // Duplicate checks
        let duplicateInfo: any = undefined;
        if (rawSku) {
          const inRows = skuCountInFile.get(rawSku) || [];
          if (inRows.length > 1) {
            validationStatus = RowValidationStatus.DUPLICATE_POSSIBLE;
            duplicateInfo = {
              type: 'IN_FILE',
              field: 'sku',
              description: `Duplicate SKU "${rawSku}" appears in rows: ${inRows.join(', ')}`,
            };
            warnings.push(`Duplicate SKU in spreadsheet (rows ${inRows.join(', ')})`);
          }

          if (existingBySku.has(rawSku)) {
            const existing = existingBySku.get(rawSku);
            validationStatus = RowValidationStatus.DUPLICATE_EXACT;
            duplicateInfo = {
              type: 'DATABASE_EXACT',
              field: 'sku',
              existingId: existing.id,
              existingCode: existing.sku,
              existingName: existing.name,
              description: `SKU already exists in database: ${rawSku} (${existing.name})`,
            };
            warnings.push(`SKU already exists in database: ${rawSku}`);

            if (rawName && existing.name !== rawName) {
              conflicts.push({
                field: 'name',
                label: 'Item Name',
                userValue: rawName,
                gstValue: existing.name,
              });
            }
          }
        }

        // Numeric price validation
        const priceKeys = [
          { key: 'listPrice', label: 'List Price' },
          { key: 'dpDiscount', label: 'DP Discount' },
          { key: 'dealerPrice', label: 'Dealer Price (DP)' },
          { key: 'lpDiscount', label: 'LP Discount' },
          { key: 'landingPrice', label: 'Landing Price (LP)' },
        ];
        priceKeys.forEach(({ key, label }) => {
          if (mappedData[key] !== undefined && mappedData[key] !== '') {
            const num = Number(mappedData[key]);
            if (isNaN(num)) {
              errors.push(`${label} must be a valid number (got "${mappedData[key]}")`);
              if (validationStatus === RowValidationStatus.VALID) {
                validationStatus = RowValidationStatus.INVALID;
              }
            }
          }
        });

        if (errors.length > 0) invalidCount++;
        else if (validationStatus === RowValidationStatus.DUPLICATE_EXACT || validationStatus === RowValidationStatus.DUPLICATE_POSSIBLE) duplicateCount++;
        else if (warnings.length > 0) warningCount++;
        else validCount++;

        const isIncluded =
          validationStatus === RowValidationStatus.VALID ||
          validationStatus === RowValidationStatus.WARNING;

        previewRows.push({
          rowNumber,
          isIncluded,
          validationStatus,
          gstLookupStatus: GstLookupStatus.NOT_APPLICABLE,
          rawData,
          mappedData,
          enrichedData,
          duplicateInfo,
          errors,
          warnings,
          conflicts,
        });

        continue;
      }

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

    // Role/permission-based Internal Pricing protection
    const userPerms: string[] = user?.permissions || [];
    const isAdmin =
      user?.isAdmin === true ||
      (user?.roles || []).some((r: string) =>
        ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r),
      );
    const canViewInternalPrice =
      isAdmin ||
      userPerms.includes('INTERNAL_PRICING:VIEW') ||
      userPerms.includes('MATERIALS:VIEW_INTERNAL_PRICING');

    for (const item of rowsToImport) {
      const { rowNumber, data, gstData, gstVerificationToken } = item;
      const combined = { ...(gstData || {}), ...(data || {}) };

      // ─── Handle MATERIAL target execution ────────────────────────────
      if (dto.target === ImportTarget.MATERIAL) {
        const rawSku = combined.sku ? String(combined.sku).trim().replace(/\.0+$/, '') : '';
        const rawName = combined.name
          ? String(combined.name).trim()
          : (combined.itemName ? String(combined.itemName).trim() : '');

        if (!rawSku && !rawName) {
          const error = 'Missing mandatory fields: Both SKU and Item Name are blank.';
          errors.push({ rowNumber, companyName: undefined, error });
          rowResults.push({ rowNumber, companyName: undefined, status: 'FAILED', error });
          continue;
        }

        const sku = rawSku || `MAT-${Date.now().toString().slice(-6)}-${rowNumber}`;
        const name = rawName || sku;

        // Duplicate prevention within import batch
        const duplicateKey = `sku:${sku}`;
        if (dto.skipDuplicates !== false && seenIdentifiers.has(duplicateKey)) {
          const error = `Duplicate SKU (${sku}) inside this import batch was skipped.`;
          skippedCount++;
          rowResults.push({ rowNumber, companyName: name, status: 'SKIPPED', error });
          continue;
        }
        seenIdentifiers.add(duplicateKey);

        try {
          const existingProduct = await this.prisma.product.findUnique({
            where: { sku },
          });

          // Resolve Category
          let categoryId: string | null = null;
          const catName = (combined.category || 'General').trim();
          let cat = await this.prisma.productCategory.findFirst({
            where: { name: { equals: catName } },
          });
          if (!cat) {
            const catCode = catName.toUpperCase().replace(/[^A-Z0-9]/g, '_').slice(0, 20) || 'CAT';
            cat = await this.prisma.productCategory.create({
              data: { name: catName, code: `${catCode}_${Date.now().toString().slice(-4)}` },
            });
          }
          categoryId = cat.id;

          // Resolve Unit
          let unitId: string | null = null;
          const uName = (combined.unit || 'Nos').trim();
          let u = await this.prisma.unit.findFirst({
            where: { name: { equals: uName } },
          });
          if (!u) {
            const uCode = uName.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10) || 'NOS';
            u = await this.prisma.unit.create({
              data: { name: uName, code: `${uCode}_${Date.now().toString().slice(-4)}` },
            });
          }
          unitId = u.id;

          // Numeric price parsing helper
          const parsePrice = (val: any) => {
            if (val === undefined || val === null || val === '') return null;
            const n = Number(val);
            return isNaN(n) ? null : n;
          };

          const listPrice = parsePrice(combined.listPrice);
          const dpDiscount = canViewInternalPrice ? parsePrice(combined.dpDiscount) : null;
          const dealerPrice = canViewInternalPrice ? parsePrice(combined.dealerPrice || combined.dp) : null;
          const lpDiscount = parsePrice(combined.lpDiscount);
          const landingPrice = parsePrice(combined.landingPrice || combined.lp);
          const purchasePrice = dealerPrice !== null ? dealerPrice : 0;
          const sellingPrice = landingPrice !== null ? landingPrice : (listPrice !== null ? listPrice : 0);

          if (existingProduct) {
            if (dto.updateExisting) {
              const updateData: any = {
                name,
                categoryId,
                unitId,
                make: combined.make?.trim() || existingProduct.make,
                subCategory1: combined.subCategory1?.trim() || existingProduct.subCategory1,
                subCategory2: combined.subCategory2?.trim() || existingProduct.subCategory2,
                subCategory3: combined.subCategory3?.trim() || existingProduct.subCategory3,
                subCategory4: combined.subCategory4?.trim() || existingProduct.subCategory4,
                subCategory5: combined.subCategory5?.trim() || existingProduct.subCategory5,
                subCategory6: combined.subCategory6?.trim() || existingProduct.subCategory6,
                subCategory7: combined.subCategory7?.trim() || existingProduct.subCategory7,
                subCategory8: combined.subCategory8?.trim() || existingProduct.subCategory8,
                subCategory9: combined.subCategory9?.trim() || existingProduct.subCategory9,
                subCategory10: combined.subCategory10?.trim() || existingProduct.subCategory10,
                capacity: combined.capacity?.trim() || existingProduct.capacity,
                supplier: combined.supplier?.trim() || existingProduct.supplier,
                hsnSac: combined.hsnSac?.trim() || existingProduct.hsnSac,
              };

              if (listPrice !== null) updateData.listPrice = listPrice;
              if (canViewInternalPrice && dpDiscount !== null) updateData.dpDiscount = dpDiscount;
              if (canViewInternalPrice && dealerPrice !== null) {
                updateData.dealerPrice = dealerPrice;
                updateData.purchasePrice = dealerPrice;
              }
              if (lpDiscount !== null) updateData.lpDiscount = lpDiscount;
              if (landingPrice !== null) {
                updateData.landingPrice = landingPrice;
                updateData.sellingPrice = landingPrice;
              }

              await this.prisma.product.update({
                where: { id: existingProduct.id },
                data: updateData,
              });
              updatedCount++;
              rowResults.push({ rowNumber, companyName: name, status: 'UPDATED' });
            } else {
              skippedCount++;
              rowResults.push({
                rowNumber,
                companyName: name,
                status: 'SKIPPED',
                error: `Matching material SKU already exists (${sku}).`,
              });
            }
          } else {
            await this.prisma.product.create({
              data: {
                sku,
                name,
                productType: 'RAW_MATERIAL',
                categoryId,
                unitId,
                make: combined.make?.trim() || null,
                subCategory1: combined.subCategory1?.trim() || null,
                subCategory2: combined.subCategory2?.trim() || null,
                subCategory3: combined.subCategory3?.trim() || null,
                subCategory4: combined.subCategory4?.trim() || null,
                subCategory5: combined.subCategory5?.trim() || null,
                subCategory6: combined.subCategory6?.trim() || null,
                subCategory7: combined.subCategory7?.trim() || null,
                subCategory8: combined.subCategory8?.trim() || null,
                subCategory9: combined.subCategory9?.trim() || null,
                subCategory10: combined.subCategory10?.trim() || null,
                capacity: combined.capacity?.trim() || null,
                supplier: combined.supplier?.trim() || null,
                listPrice,
                dpDiscount,
                dealerPrice,
                lpDiscount,
                landingPrice,
                purchasePrice,
                sellingPrice,
                hsnSac: combined.hsnSac?.trim() || null,
                status: 'ACTIVE',
              },
            });
            successCount++;
            rowResults.push({ rowNumber, companyName: name, status: 'IMPORTED' });
          }
        } catch (err: any) {
          this.logger.error(`Import error on row ${rowNumber}: ${err.message}`, err.stack);
          databaseErrorCount++;
          errors.push({
            rowNumber,
            companyName: name,
            error: err.message || 'Database insert failed',
          });
          rowResults.push({
            rowNumber,
            companyName: name,
            status: 'FAILED',
            error: err.message || 'Database insert failed',
          });
        }

        continue;
      }

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
      module: dto.target === ImportTarget.CUSTOMER ? 'CUSTOMERS' : dto.target === ImportTarget.MATERIAL ? 'MATERIALS' : 'VENDORS',
      entityType: dto.target === ImportTarget.CUSTOMER ? 'Customer' : dto.target === ImportTarget.MATERIAL ? 'Product' : 'Vendor',
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
    if (target === ImportTarget.MATERIAL) {
      return [
        'SKU,Category,Make,SUB Category Type 1,SUB Category Type 2,SUB Category Type 3,SUB Category Type 4,Item Name,CAPACITY,Unit,Supplier,List Price,DP Discount,DP,LP Discount,LP',
        'AI-PCU01,Controller,SAARK,HMI,HMI FOR LESS THAN 3 HP SVFD,<=3,AI-PCU01 WITH HMI DISPLAY,AI-PCU01,1.0,Nos,Saark Exploration Pvt Ltd,50000,50,25000,0,25000',
        'SCH-LC1D25,CONTACTOR,Schneider,3 POLE,415V AC,LC1D25,25A,25A 3P Contactor,25A,Nos,Schneider Electric India,2450,42,1421,10,2205',
        'POL-1.5-BLU,Wire,Polycab,Single Core,Copper,FR,1.5 SQMM,1.5 sqmm Blue Wire,1.5,Meter,Polycab India,18.5,25,13.88,5,17.5',
      ].join('\r\n');
    }

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
