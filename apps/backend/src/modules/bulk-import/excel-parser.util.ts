import * as fflate from 'fflate';

export interface ParsedSheet {
  headers: string[];
  rawRows: Array<Record<string, string>>;
  rowCount: number;
  sheetNames?: string[];
  selectedSheet?: string;
}

export interface ColumnMappingDefinition {
  field: string;
  label: string;
  required: boolean;
  synonyms: string[];
}

export const CUSTOMER_COLUMN_DEFINITIONS: ColumnMappingDefinition[] = [
  {
    field: 'companyName',
    label: 'Company / Business Name',
    required: false, // Optional if GSTIN is present
    synonyms: ['company name', 'company', 'business name', 'legal name', 'trade name', 'firm name', 'party name', 'customer name', 'client name', 'name', 'account name', 'customer'],
  },
  {
    field: 'gstin',
    label: 'GSTIN / GST Number',
    required: false,
    synonyms: ['gstin', 'gst number', 'gst no', 'gst no.', 'gst identification number', 'gstin/uin', 'gst', 'tax id', 'gstin_number'],
  },
  {
    field: 'pan',
    label: 'PAN Number',
    required: false,
    synonyms: ['pan', 'pan number', 'pan no', 'pan no.', 'permanent account number', 'pan card'],
  },
  {
    field: 'contactPerson',
    label: 'Contact Person',
    required: false,
    synonyms: ['contact person', 'contact name', 'person name', 'owner name', 'owner', 'contact', 'authorized person', 'representative', 'key person', 'caller'],
  },
  {
    field: 'designation',
    label: 'Designation / Role',
    required: false,
    synonyms: ['designation', 'role', 'title', 'job title', 'position'],
  },
  {
    field: 'phone',
    label: 'Mobile / Phone Number',
    required: false,
    synonyms: ['mobile', 'phone', 'mobile number', 'phone number', 'contact number', 'tel', 'telephone', 'cell', 'mobile no', 'phone no', 'whatsapp', 'primary phone'],
  },
  {
    field: 'alternatePhone',
    label: 'Alternate Phone',
    required: false,
    synonyms: ['alternate phone', 'alt phone', 'alternate mobile', 'alt mobile', 'secondary phone', 'other phone', 'landline'],
  },
  {
    field: 'email',
    label: 'Email Address',
    required: false,
    synonyms: ['email', 'business email', 'email address', 'e-mail', 'mail', 'contact email', 'official email'],
  },
  {
    field: 'address',
    label: 'Registered Address',
    required: false,
    synonyms: ['address', 'registered address', 'street', 'office address', 'factory address', 'billing address', 'address line 1', 'address line', 'location address'],
  },
  {
    field: 'city',
    label: 'City / Town',
    required: false,
    synonyms: ['city', 'town', 'district/city', 'city name', 'place', 'city/location'],
  },
  {
    field: 'district',
    label: 'District',
    required: false,
    synonyms: ['district', 'dist', 'county', 'region'],
  },
  {
    field: 'state',
    label: 'State',
    required: false,
    synonyms: ['state', 'province', 'state name', 'state code', 'lacation', 'location', 'state/location', 'place of supply'],
  },
  {
    field: 'pincode',
    label: 'PIN / Postal Code',
    required: false,
    synonyms: ['pincode', 'pin code', 'postal code', 'zip', 'zip code', 'postal', 'pin'],
  },
  {
    field: 'website',
    label: 'Website URL',
    required: false,
    synonyms: ['website', 'web', 'url', 'domain', 'portal', 'web address'],
  },
  {
    field: 'customerType',
    label: 'Customer Type',
    required: false,
    synonyms: ['customer type', 'type', 'business type', 'category type', 'segment type'],
  },
  {
    field: 'customerCategory',
    label: 'Customer Category',
    required: false,
    synonyms: ['customer category', 'tier', 'grade', 'category'],
  },
  {
    field: 'industry',
    label: 'Industry / Segment',
    required: false,
    synonyms: ['industry', 'segment', 'customer segment', 'sector', 'business line'],
  },
  {
    field: 'turnover',
    label: 'Annual Turnover',
    required: false,
    synonyms: ['turnover', 'annual turnover', 'revenue', 'approx turnover'],
  },
  {
    field: 'creditLimit',
    label: 'Credit Limit',
    required: false,
    synonyms: ['credit limit', 'credit', 'credit amount'],
  },
  {
    field: 'paymentTerms',
    label: 'Payment Terms',
    required: false,
    synonyms: ['payment terms', 'credit terms', 'terms', 'payment term'],
  },
  {
    field: 'outcome',
    label: 'Call / Lead Outcome',
    required: false,
    synonyms: ['outcome', 'call outcome', 'lead outcome', 'status', 'call status', 'lead status', 'disposition'],
  },
  {
    field: 'followUp',
    label: 'Follow-Up Notes',
    required: false,
    synonyms: ['follow-up', 'follow up', 'followup', 'follow-up 1', 'follow-up 2', 'next step', 'action item'],
  },
  {
    field: 'notes',
    label: 'Notes / Remarks',
    required: false,
    synonyms: ['notes', 'remarks', 'comments', 'description', 'special notes', 'remark', 'calling remarks'],
  },
];

export const VENDOR_COLUMN_DEFINITIONS: ColumnMappingDefinition[] = [
  {
    field: 'companyName',
    label: 'Vendor / Company Name',
    required: false,
    synonyms: ['company name', 'vendor name', 'company', 'business name', 'legal name', 'trade name', 'firm name', 'party name', 'supplier name', 'supplier', 'name', 'vendor'],
  },
  {
    field: 'gstin',
    label: 'GSTIN / GST Number',
    required: false,
    synonyms: ['gstin', 'gst number', 'gst no', 'gst no.', 'gst identification number', 'gstin/uin', 'gst', 'tax id', 'gstin_number'],
  },
  {
    field: 'pan',
    label: 'PAN Number',
    required: false,
    synonyms: ['pan', 'pan number', 'pan no', 'pan no.', 'permanent account number', 'pan card'],
  },
  {
    field: 'contactPerson',
    label: 'Contact Person',
    required: false,
    synonyms: ['contact person', 'contact name', 'person name', 'owner name', 'owner', 'contact', 'authorized person', 'representative', 'sales person'],
  },
  {
    field: 'designation',
    label: 'Designation / Role',
    required: false,
    synonyms: ['designation', 'role', 'title', 'job title', 'position'],
  },
  {
    field: 'phone',
    label: 'Mobile / Phone Number',
    required: false,
    synonyms: ['mobile', 'phone', 'mobile number', 'phone number', 'contact number', 'tel', 'telephone', 'cell', 'mobile no', 'phone no', 'whatsapp', 'primary phone'],
  },
  {
    field: 'alternatePhone',
    label: 'Alternate Phone',
    required: false,
    synonyms: ['alternate phone', 'alt phone', 'alternate mobile', 'alt mobile', 'secondary phone', 'other phone', 'landline'],
  },
  {
    field: 'email',
    label: 'Email Address',
    required: false,
    synonyms: ['email', 'business email', 'email address', 'e-mail', 'mail', 'contact email', 'official email'],
  },
  {
    field: 'address',
    label: 'Registered Address',
    required: false,
    synonyms: ['address', 'registered address', 'street', 'office address', 'factory address', 'billing address', 'address line 1', 'address line', 'location address'],
  },
  {
    field: 'city',
    label: 'City / Town',
    required: false,
    synonyms: ['city', 'town', 'district/city', 'city name', 'place'],
  },
  {
    field: 'district',
    label: 'District',
    required: false,
    synonyms: ['district', 'dist', 'county', 'region'],
  },
  {
    field: 'state',
    label: 'State',
    required: false,
    synonyms: ['state', 'province', 'state name', 'state code'],
  },
  {
    field: 'pincode',
    label: 'PIN / Postal Code',
    required: false,
    synonyms: ['pincode', 'pin code', 'postal code', 'zip', 'zip code', 'postal', 'pin'],
  },
  {
    field: 'website',
    label: 'Website URL',
    required: false,
    synonyms: ['website', 'web', 'url', 'domain', 'portal', 'web address'],
  },
  {
    field: 'vendorType',
    label: 'Vendor Type',
    required: false,
    synonyms: ['vendor type', 'type', 'business type', 'supplier type', 'category type'],
  },
  {
    field: 'vendorCategory',
    label: 'Vendor Category',
    required: false,
    synonyms: ['vendor category', 'tier', 'grade', 'category'],
  },
  {
    field: 'constitution',
    label: 'Constitution',
    required: false,
    synonyms: ['constitution', 'entity type', 'business constitution', 'legal structure'],
  },
  {
    field: 'productsSupplied',
    label: 'Products / Services Supplied',
    required: false,
    synonyms: ['products supplied', 'items supplied', 'materials supplied', 'services', 'products', 'supplies'],
  },
  {
    field: 'creditLimit',
    label: 'Credit Limit',
    required: false,
    synonyms: ['credit limit', 'credit', 'credit amount'],
  },
  {
    field: 'paymentTerms',
    label: 'Payment Terms',
    required: false,
    synonyms: ['payment terms', 'credit terms', 'terms', 'payment term'],
  },
  {
    field: 'msmeStatus',
    label: 'MSME Status (YES / NO)',
    required: false,
    synonyms: ['msme status', 'msme', 'udyam', 'msme registered'],
  },
  {
    field: 'notes',
    label: 'Notes / Remarks',
    required: false,
    synonyms: ['notes', 'remarks', 'comments', 'description', 'special notes'],
  },
];

export const MATERIAL_COLUMN_DEFINITIONS: ColumnMappingDefinition[] = [
  {
    field: 'sku',
    label: 'SKU / Item Code',
    required: true,
    synonyms: ['sku', 'item code', 'product code', 'part no', 'part number', 'code', 'cat no', 'cat. no', 'item no', 'article code'],
  },
  {
    field: 'name',
    label: 'Item / Material Name',
    required: true,
    synonyms: ['item name', 'product name', 'material name', 'name', 'item description', 'description', 'particulars', 'code with size', 'fans 12 vdc 240 vac', 'pin type insulated lugs', 'description cat no', 'specification'],
  },
  {
    field: 'category',
    label: 'Category',
    required: false,
    synonyms: ['category', 'product category', 'item category', 'group', 'type', 'product type', 'pump type'],
  },
  {
    field: 'make',
    label: 'Make / Manufacturer',
    required: false,
    synonyms: ['make', 'brand', 'manufacturer', 'mfr', 'switchgare make', 'vfd make'],
  },
  {
    field: 'subCategory1',
    label: 'Sub Category Type 1',
    required: false,
    synonyms: ['sub category type 1', 'sub category 1', 'sub-category 1', 'subcategory 1', 'sub category', 'panel type'],
  },
  {
    field: 'subCategory2',
    label: 'Sub Category Type 2',
    required: false,
    synonyms: ['sub category type 2', 'sub category 2', 'sub-category 2', 'subcategory 2'],
  },
  {
    field: 'subCategory3',
    label: 'Sub Category Type 3',
    required: false,
    synonyms: ['sub category type 3', 'sub category 3', 'sub-category 3', 'subcategory 3'],
  },
  {
    field: 'subCategory4',
    label: 'Sub Category Type 4',
    required: false,
    synonyms: ['sub category type 4', 'sub category 4', 'sub-category 4', 'subcategory 4'],
  },
  {
    field: 'subCategory5',
    label: 'Sub Category Type 5',
    required: false,
    synonyms: ['sub category type 5', 'sub category 5', 'sub-category 5', 'subcategory 5'],
  },
  {
    field: 'subCategory6',
    label: 'Sub Category Type 6',
    required: false,
    synonyms: ['sub category type 6', 'sub category 6', 'sub-category 6', 'subcategory 6'],
  },
  {
    field: 'subCategory7',
    label: 'Sub Category Type 7',
    required: false,
    synonyms: ['sub category type 7', 'sub category 7', 'sub-category 7', 'subcategory 7'],
  },
  {
    field: 'subCategory8',
    label: 'Sub Category Type 8',
    required: false,
    synonyms: ['sub category type 8', 'sub category 8', 'sub-category 8', 'subcategory 8'],
  },
  {
    field: 'subCategory9',
    label: 'Sub Category Type 9',
    required: false,
    synonyms: ['sub category type 9', 'sub category 9', 'sub-category 9', 'subcategory 9'],
  },
  {
    field: 'subCategory10',
    label: 'Sub Category Type 10',
    required: false,
    synonyms: ['sub category type 10', 'sub category 10', 'sub-category 10', 'subcategory 10'],
  },
  {
    field: 'capacity',
    label: 'Capacity / Rating',
    required: false,
    synonyms: ['capacity', 'rating', 'hp', 'kw', 'kilo watt', 'current', 'size', 'size (mm)', 'inch', 'mm2', 'voltage', 'pump hp', 'pump current'],
  },
  {
    field: 'unit',
    label: 'Unit of Measure',
    required: false,
    synonyms: ['unit', 'uom', 'unit of measure', 'nos', 'meter', 'pcs', 'kg', 'mtr'],
  },
  {
    field: 'supplier',
    label: 'Supplier / Source',
    required: false,
    synonyms: ['supplier', 'vendor', 'supplier name', 'source', 'party'],
  },
  {
    field: 'listPrice',
    label: 'List Price (Catalog / MRP)',
    required: false,
    synonyms: ['list price', 'catalog price', 'mrp', 'standard price'],
  },
  {
    field: 'dpDiscount',
    label: 'DP Discount (%) [Internal]',
    required: false,
    synonyms: ['dp discount', 'dp discount %', 'dealer discount', 'purchase discount', 'purchase discount %', 'discount %'],
  },
  {
    field: 'dealerPrice',
    label: 'Dealer Price (DP / Purchase Cost) [Internal]',
    required: false,
    synonyms: ['dp', 'dealer price', 'purchase price', 'purchase cost', 'cost price', 'net purchase price'],
  },
  {
    field: 'lpDiscount',
    label: 'LP Discount (%)',
    required: false,
    synonyms: ['lp discount', 'lp discount %', 'landing discount'],
  },
  {
    field: 'landingPrice',
    label: 'Landing Price (LP / Quoted Price)',
    required: false,
    synonyms: ['lp', 'landing price', 'selling price', 'sale price', 'final price', 'quoted price', 'price', 'price grey', 'price colour', 'price white', 'price jigo', 'price metal'],
  },
  {
    field: 'hsnSac',
    label: 'HSN / SAC Code',
    required: false,
    synonyms: ['hsn', 'sac', 'hsn/sac', 'hsn code', 'sac code'],
  },
];

/**
 * Formula Injection Protection:
 * Prevent CSV/Spreadsheet formula execution by escaping leading formula operators.
 */
export function sanitizeSpreadsheetCell(value: unknown): string {
  if (value === null || value === undefined) return '';
  let str = String(value).trim();
  // Strip null bytes and control chars
  str = str.replace(/\0/g, '');
  // If string begins with formula trigger (=, +, -, @, tab, cr), prefix with single quote
  if (/^[=+\-@\t\r]/.test(str)) {
    return `'${str}`;
  }
  return str;
}

/**
 * Strip formulas when reading spreadsheet inputs (do not execute or treat as formula)
 */
export function sanitizeInputCell(value: unknown): string {
  if (value === null || value === undefined) return '';
  let str = String(value).trim();
  // If the cell was an Excel formula string like "=SUM(A1:B1)" or "=+1234", strip the leading '=' if desired or return text
  if (str.startsWith('=')) {
    str = str.replace(/^=+/, '').trim();
  }
  return str;
}

/**
 * Excel serial date parser (days since 1899-12-30)
 */
export function parseExcelSerialDate(val: string): string {
  const trimmed = val.trim();
  const num = parseFloat(trimmed);
  // Valid Excel serial dates typically between 30000 (1982) and 65000 (2077)
  if (!isNaN(num) && num >= 30000 && num <= 65000 && /^\d+(\.\d+)?$/.test(trimmed)) {
    const utcDays = Math.floor(num - 25569);
    const date = new Date(utcDays * 86400 * 1000);
    if (!isNaN(date.getTime())) {
      const year = date.getUTCFullYear();
      const month = String(date.getUTCMonth() + 1).padStart(2, '0');
      const day = String(date.getUTCDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    }
  }
  return val;
}

/**
 * Clean phone numbers: avoid floating point notation or scientific notation
 */
export function parseCleanPhone(val: string): string {
  if (!val) return '';
  const trimmed = val.trim();
  const num = Number(trimmed);
  if (!isNaN(num) && num > 1000000 && num < 1e15 && /^\d+(\.0+)?$/.test(trimmed)) {
    return String(Math.floor(num));
  }
  return trimmed.replace(/\.0+$/, '');
}

/**
 * Parse CSV buffer or string with full support for quotes, commas, semicolons, and CRLF
 */
export function parseCsv(content: string | Buffer): ParsedSheet {
  let text = typeof content === 'string' ? content : content.toString('utf8');
  // Strip BOM
  if (text.charCodeAt(0) === 0xfeff) {
    text = text.slice(1);
  }

  // Detect delimiter: comma, semicolon, tab
  const firstLine = text.split(/\r\n|\n|\r/)[0] || '';
  let delimiter = ',';
  const commaCount = (firstLine.match(/,/g) || []).length;
  const semiCount = (firstLine.match(/;/g) || []).length;
  const tabCount = (firstLine.match(/\t/g) || []).length;
  if (semiCount > commaCount && semiCount > tabCount) delimiter = ';';
  else if (tabCount > commaCount && tabCount > semiCount) delimiter = '\t';

  const rows: string[][] = [];
  let currentRow: string[] = [];
  let currentCell = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    const nextChar = text[i + 1];

    if (inQuotes) {
      if (char === '"') {
        if (nextChar === '"') {
          currentCell += '"';
          i++; // Skip escaped quote
        } else {
          inQuotes = false;
        }
      } else {
        currentCell += char;
      }
    } else {
      if (char === '"') {
        inQuotes = true;
      } else if (char === delimiter) {
        currentRow.push(sanitizeInputCell(currentCell));
        currentCell = '';
      } else if (char === '\r') {
        if (nextChar === '\n') i++;
        currentRow.push(sanitizeInputCell(currentCell));
        if (currentRow.some((c) => c.trim().length > 0)) {
          rows.push(currentRow);
        }
        currentRow = [];
        currentCell = '';
      } else if (char === '\n') {
        currentRow.push(sanitizeInputCell(currentCell));
        if (currentRow.some((c) => c.trim().length > 0)) {
          rows.push(currentRow);
        }
        currentRow = [];
        currentCell = '';
      } else {
        currentCell += char;
      }
    }
  }

  if (currentCell.length > 0 || currentRow.length > 0) {
    currentRow.push(sanitizeInputCell(currentCell));
    if (currentRow.some((c) => c.trim().length > 0)) {
      rows.push(currentRow);
    }
  }

  if (rows.length === 0) {
    return { headers: [], rawRows: [], rowCount: 0, sheetNames: ['Default'], selectedSheet: 'Default' };
  }

  // Find header row: first non-empty row
  let headerRowIdx = 0;
  while (headerRowIdx < rows.length && !rows[headerRowIdx].some((c) => c.trim().length > 0)) {
    headerRowIdx++;
  }
  if (headerRowIdx >= rows.length) {
    return { headers: [], rawRows: [], rowCount: 0, sheetNames: ['Default'], selectedSheet: 'Default' };
  }

  const rawHeaderRow = rows[headerRowIdx];
  const maxCol = Math.max(...rows.map((r) => r.length)) - 1;

  // Filter out trailing columns that have NO header AND all rows are empty
  const activeCols: number[] = [];
  for (let c = 0; c <= maxCol; c++) {
    const headerVal = (rawHeaderRow[c] || '').trim();
    let colHasData = headerVal.length > 0;
    if (!colHasData) {
      for (let r = headerRowIdx + 1; r < rows.length; r++) {
        if ((rows[r][c] || '').trim().length > 0) {
          colHasData = true;
          break;
        }
      }
    }
    if (colHasData) {
      activeCols.push(c);
    }
  }

  // Deduplicate headers
  const headerCounts: Record<string, number> = {};
  const headers: string[] = [];
  for (const c of activeCols) {
    let h = (rawHeaderRow[c] || '').trim();
    if (!h) h = `Column_${c + 1}`;
    if (!headerCounts[h]) {
      headerCounts[h] = 1;
      headers.push(h);
    } else {
      headerCounts[h]++;
      headers.push(`${h} (${headerCounts[h]})`);
    }
  }

  const rawRows: Array<Record<string, string>> = [];
  for (let r = headerRowIdx + 1; r < rows.length; r++) {
    const rowValues = rows[r];
    if (!rowValues.some((v) => v.trim().length > 0)) continue;

    const rowObj: Record<string, string> = { _originalRowNumber: String(r + 1) };
    let rowHasData = false;

    for (let i = 0; i < activeCols.length; i++) {
      const colIdx = activeCols[i];
      const headerName = headers[i];
      let val = rowValues[colIdx] !== undefined ? rowValues[colIdx].trim() : '';

      if (val.length > 0) {
        rowHasData = true;
        if (/date/i.test(headerName)) {
          val = parseExcelSerialDate(val);
        } else if (/phone|mobile/i.test(headerName)) {
          val = parseCleanPhone(val);
        }
      }
      rowObj[headerName] = val;
    }

    if (rowHasData) {
      rawRows.push(rowObj);
    }
  }

  return {
    headers,
    rawRows,
    rowCount: rawRows.length,
    sheetNames: ['Default'],
    selectedSheet: 'Default',
  };
}

/**
 * Fast and robust XLSX Workbook Parser using fflate and XML parsing.
 * Supports multiple worksheets, header deduplication, date/number formatting, and trailing column pruning.
 */
export function parseXlsx(
  buffer: Buffer | Uint8Array,
  options?: { sheetName?: string },
): ParsedSheet {
  const u8 = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
  let unzipped: fflate.Unzipped;
  try {
    unzipped = fflate.unzipSync(u8);
  } catch (err: any) {
    throw new Error(`Failed to read Excel workbook: ${err.message || 'Invalid ZIP archive'}`);
  }

  // 1. Extract shared strings table
  const sharedStrings: string[] = [];
  const sharedStringsEntry = Object.keys(unzipped).find((k) =>
    /xl\/sharedStrings\.xml$/i.test(k),
  );
  if (sharedStringsEntry && unzipped[sharedStringsEntry]) {
    const sstXml = fflate.strFromU8(unzipped[sharedStringsEntry]);
    const siMatches = sstXml.match(/<si\b[^>]*>[\s\S]*?<\/si>/gi) || [];
    for (const si of siMatches) {
      const tMatches = si.match(/<t\b[^>]*>([\s\S]*?)<\/t>/gi) || [];
      const text = tMatches
        .map((tTag) => {
          const content = tTag.replace(/<t\b[^>]*>/i, '').replace(/<\/t>/i, '');
          return unescapeXml(content);
        })
        .join('');
      sharedStrings.push(text);
    }
  }

  // 2. Discover sheets from xl/workbook.xml & xl/_rels/workbook.xml.rels
  const sheetMetadata: Array<{ name: string; rId: string; target: string }> = [];
  const wbEntry = Object.keys(unzipped).find((k) => /xl\/workbook\.xml$/i.test(k));
  const relsEntry = Object.keys(unzipped).find((k) => /xl\/_rels\/workbook\.xml\.rels$/i.test(k));

  if (wbEntry && unzipped[wbEntry]) {
    const wbXml = fflate.strFromU8(unzipped[wbEntry]);
    const relsXml = relsEntry && unzipped[relsEntry] ? fflate.strFromU8(unzipped[relsEntry]) : '';

    const sheetTags = wbXml.match(/<sheet\b[^>]*\/>/gi) || [];
    for (const tag of sheetTags) {
      const nameMatch = tag.match(/\bname="([^"]+)"/i);
      const rIdMatch = tag.match(/r:id="([^"]+)"/i);
      const name = nameMatch ? nameMatch[1] : 'Sheet';
      const rId = rIdMatch ? rIdMatch[1] : '';

      let target = '';
      if (relsXml && rId) {
        const relMatch = relsXml.match(
          new RegExp('<Relationship\\b[^>]*Id="' + rId + '"[^>]*Target="([^"]+)"', 'i'),
        );
        if (relMatch) {
          target = relMatch[1];
        }
      }
      if (!target) {
        target = `worksheets/sheet${sheetMetadata.length + 1}.xml`;
      }
      if (!target.toLowerCase().startsWith('xl/')) {
        target = 'xl/' + target.replace(/^\//, '');
      }
      sheetMetadata.push({ name, rId, target });
    }
  }

  const sheetNames = sheetMetadata.map((s) => s.name);

  // 3. Resolve target worksheet XML entry
  let targetSheetEntry: string | undefined;
  let selectedSheetName = 'Sheet1';

  if (options?.sheetName) {
    const matched = sheetMetadata.find(
      (s) => s.name.toLowerCase() === options.sheetName!.toLowerCase(),
    );
    if (matched && unzipped[matched.target]) {
      targetSheetEntry = matched.target;
      selectedSheetName = matched.name;
    }
  }

  if (!targetSheetEntry && sheetMetadata.length > 0) {
    for (const s of sheetMetadata) {
      if (unzipped[s.target]) {
        targetSheetEntry = s.target;
        selectedSheetName = s.name;
        break;
      }
    }
  }

  if (!targetSheetEntry) {
    targetSheetEntry =
      Object.keys(unzipped).find((k) => /xl\/worksheets\/sheet1\.xml$/i.test(k)) ||
      Object.keys(unzipped).find((k) => /xl\/worksheets\/sheet\d+\.xml$/i.test(k));
    if (targetSheetEntry && sheetNames.length > 0) {
      selectedSheetName = sheetNames[0];
    }
  }

  if (!targetSheetEntry || !unzipped[targetSheetEntry]) {
    throw new Error('No valid worksheet found in Excel file');
  }

  const sheetXml = fflate.strFromU8(unzipped[targetSheetEntry]);

  // 4. Parse rows and cells
  const rowMatches = sheetXml.match(/<row\b[^>]*>[\s\S]*?<\/row>/gi) || [];
  const tableRows: Array<Map<number, string>> = [];

  for (const rowXml of rowMatches) {
    const cellMatches = rowXml.match(/<c\b[^>]*>[\s\S]*?<\/c>|<c\b[^>]*\/>/gi) || [];
    const cellMap = new Map<number, string>();

    for (const cellXml of cellMatches) {
      const rAttr = cellXml.match(/\br="([A-Z]+)(\d+)"/i);
      if (!rAttr) continue;
      const colRef = rAttr[1].toUpperCase();
      const colIndex = columnLetterToIndex(colRef);

      const tAttr = (cellXml.match(/\bt="([a-z]+)"/i) || [])[1];

      let cellValue = '';
      if (tAttr === 's') {
        // Shared string index
        const vMatch = cellXml.match(/<v>(\d+)<\/v>/i);
        if (vMatch) {
          const idx = parseInt(vMatch[1], 10);
          cellValue = sharedStrings[idx] || '';
        }
      } else if (tAttr === 'inlineStr') {
        // Inline string
        const tMatch = cellXml.match(/<t\b[^>]*>([\s\S]*?)<\/t>/i);
        if (tMatch) {
          cellValue = unescapeXml(tMatch[1]);
        }
      } else {
        // Direct value / number / formula result
        const vMatch = cellXml.match(/<v>([\s\S]*?)<\/v>/i);
        if (vMatch) {
          cellValue = unescapeXml(vMatch[1]);
        }
      }

      cellMap.set(colIndex, sanitizeInputCell(cellValue));
    }

    if (cellMap.size > 0) {
      tableRows.push(cellMap);
    }
  }

  if (tableRows.length === 0) {
    return {
      headers: [],
      rawRows: [],
      rowCount: 0,
      sheetNames: sheetNames.length > 0 ? sheetNames : ['Sheet1'],
      selectedSheet: selectedSheetName,
    };
  }

  // 5. Determine maximum column index
  let maxCol = 0;
  for (const row of tableRows) {
    for (const colIdx of row.keys()) {
      if (colIdx > maxCol) maxCol = colIdx;
    }
  }

  // 6. Find header row: first row with non-empty cell
  let headerRowIdx = 0;
  while (headerRowIdx < tableRows.length) {
    let hasCell = false;
    for (const val of tableRows[headerRowIdx].values()) {
      if (val.trim().length > 0) {
        hasCell = true;
        break;
      }
    }
    if (hasCell) break;
    headerRowIdx++;
  }
  if (headerRowIdx >= tableRows.length) {
    return {
      headers: [],
      rawRows: [],
      rowCount: 0,
      sheetNames,
      selectedSheet: selectedSheetName,
    };
  }

  const headerRow = tableRows[headerRowIdx];

  // 7. Filter out trailing columns that have NO header AND all rows are empty
  const activeCols: number[] = [];
  for (let c = 0; c <= maxCol; c++) {
    const headerVal = (headerRow.get(c) || '').trim();
    let colHasData = headerVal.length > 0;
    if (!colHasData) {
      for (let r = headerRowIdx + 1; r < tableRows.length; r++) {
        if ((tableRows[r].get(c) || '').trim().length > 0) {
          colHasData = true;
          break;
        }
      }
    }
    if (colHasData) {
      activeCols.push(c);
    }
  }

  // 8. Deduplicate headers
  const headerCounts: Record<string, number> = {};
  const headers: string[] = [];
  for (const c of activeCols) {
    let h = (headerRow.get(c) || '').trim();
    if (!h) h = `Column_${c + 1}`;
    if (!headerCounts[h]) {
      headerCounts[h] = 1;
      headers.push(h);
    } else {
      headerCounts[h]++;
      headers.push(`${h} (${headerCounts[h]})`);
    }
  }

  // 9. Build data rows with Excel date & numeric phone handling
  const rawRows: Array<Record<string, string>> = [];
  for (let r = headerRowIdx + 1; r < tableRows.length; r++) {
    const rowMap = tableRows[r];
    const rowObj: Record<string, string> = { _originalRowNumber: String(r + 1) };
    let hasData = false;

    for (let i = 0; i < activeCols.length; i++) {
      const colIdx = activeCols[i];
      const headerName = headers[i];
      let val = (rowMap.get(colIdx) || '').trim();

      if (val.length > 0) {
        hasData = true;
        if (/date/i.test(headerName)) {
          val = parseExcelSerialDate(val);
        } else if (/phone|mobile/i.test(headerName)) {
          val = parseCleanPhone(val);
        }
      }
      rowObj[headerName] = val;
    }

    if (hasData) {
      rawRows.push(rowObj);
    }
  }

  return {
    headers,
    rawRows,
    rowCount: rawRows.length,
    sheetNames: sheetNames.length > 0 ? sheetNames : [selectedSheetName],
    selectedSheet: selectedSheetName,
  };
}

/**
 * Convert Excel column letters (A, B, ..., Z, AA, AB...) to 0-based column index
 */
function columnLetterToIndex(letters: string): number {
  let index = 0;
  for (let i = 0; i < letters.length; i++) {
    index = index * 26 + (letters.charCodeAt(i) - 64);
  }
  return index - 1;
}

function unescapeXml(xml: string): string {
  return xml
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, dec) => String.fromCharCode(Number(dec)))
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
}

/**
 * Universal file parser: parses buffer based on file name or content signature
 */
export function parseSpreadsheet(
  filename: string,
  buffer: Buffer,
  options?: { sheetName?: string },
): ParsedSheet {
  const lowerName = filename.toLowerCase();
  if (lowerName.endsWith('.csv') || lowerName.endsWith('.txt')) {
    return parseCsv(buffer);
  }
  if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xlsm') || lowerName.endsWith('.xls')) {
    // Check if it's zip based (PK..)
    if (buffer.length >= 4 && buffer[0] === 0x50 && buffer[1] === 0x4b) {
      return parseXlsx(buffer, options);
    }
    // Fallback: try parsing as CSV if plain text disguised as xls
    try {
      return parseCsv(buffer);
    } catch {
      throw new Error('Unsupported or corrupted Excel binary format. Please upload standard .xlsx or .csv');
    }
  }
  // Try XLSX then CSV
  try {
    return parseXlsx(buffer, options);
  } catch {
    return parseCsv(buffer);
  }
}

/**
 * Normalize a column header for matching against dictionary
 */
export function normalizeHeader(header: string): string {
  return header
    .toLowerCase()
    .replace(/[^a-z0-9]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Automatically map detected column headers to target schema fields
 */
export function autoDetectColumnMapping(
  headers: string[],
  target: 'CUSTOMER' | 'VENDOR' | 'MATERIAL' | string,
): Record<string, string> {
  const definitions =
    target === 'CUSTOMER'
      ? CUSTOMER_COLUMN_DEFINITIONS
      : target === 'MATERIAL' || target === 'PRODUCT'
      ? MATERIAL_COLUMN_DEFINITIONS
      : VENDOR_COLUMN_DEFINITIONS;

  const mapping: Record<string, string> = {};
  const usedFields = new Set<string>();

  for (const header of headers) {
    const norm = normalizeHeader(header);
    if (!norm) continue;

    // 1. Exact field name match
    let matchedField: string | null = null;
    const exactField = definitions.find((d) => d.field.toLowerCase() === norm);
    if (exactField && !usedFields.has(exactField.field)) {
      matchedField = exactField.field;
    }

    // 2. Exact synonym match
    if (!matchedField) {
      const synMatch = definitions.find(
        (d) => !usedFields.has(d.field) && d.synonyms.includes(norm),
      );
      if (synMatch) {
        matchedField = synMatch.field;
      }
    }

    // 3. Substring / contains match
    if (!matchedField) {
      const containsMatch = definitions.find((d) => {
        if (usedFields.has(d.field)) return false;
        return d.synonyms.some(
          (syn) => norm === syn || norm.startsWith(`${syn} `) || norm.endsWith(` ${syn}`),
        );
      });
      if (containsMatch) {
        matchedField = containsMatch.field;
      }
    }

    if (matchedField) {
      mapping[header] = matchedField;
      usedFields.add(matchedField);
    }
  }

  return mapping;
}
