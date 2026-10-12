import * as fflate from 'fflate';

export interface ParsedSheet {
  headers: string[];
  rawRows: Array<Record<string, string>>;
  rowCount: number;
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
    synonyms: ['contact person', 'contact name', 'person name', 'owner name', 'owner', 'contact', 'authorized person', 'representative', 'key person'],
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
    field: 'notes',
    label: 'Notes / Remarks',
    required: false,
    synonyms: ['notes', 'remarks', 'comments', 'description', 'special notes'],
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
    return { headers: [], rawRows: [], rowCount: 0 };
  }

  const rawHeaders = rows[0].map((h) => h.trim());
  const headers = rawHeaders.map((h, idx) => (h.length > 0 ? h : `Column_${idx + 1}`));

  const rawRows: Array<Record<string, string>> = [];
  for (let r = 1; r < rows.length; r++) {
    const rowValues = rows[r];
    // Skip empty lines
    if (!rowValues.some((v) => v.trim().length > 0)) continue;
    const rowObj: Record<string, string> = { _originalRowNumber: String(r + 1) };
    headers.forEach((h, colIdx) => {
      rowObj[h] = rowValues[colIdx] !== undefined ? rowValues[colIdx].trim() : '';
    });
    rawRows.push(rowObj);
  }

  return {
    headers,
    rawRows,
    rowCount: rawRows.length,
  };
}

/**
 * Fast and robust XLSX Workbook Parser using fflate and XML parsing.
 * Reads sharedStrings.xml and sheet1.xml, extracting string and numeric cells safely.
 */
export function parseXlsx(buffer: Buffer | Uint8Array): ParsedSheet {
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
    // Extract <si>...</si> entries
    const siMatches = sstXml.match(/<si\b[^>]*>[\s\S]*?<\/si>/gi) || [];
    for (const si of siMatches) {
      // Extract all <t>...</t> content within the <si>
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

  // 2. Find first worksheet XML (usually xl/worksheets/sheet1.xml)
  const sheetEntry =
    Object.keys(unzipped).find((k) => /xl\/worksheets\/sheet1\.xml$/i.test(k)) ||
    Object.keys(unzipped).find((k) => /xl\/worksheets\/sheet\d+\.xml$/i.test(k));

  if (!sheetEntry || !unzipped[sheetEntry]) {
    throw new Error('No valid worksheet found in Excel file');
  }

  const sheetXml = fflate.strFromU8(unzipped[sheetEntry]);

  // 3. Parse rows and cells
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
    return { headers: [], rawRows: [], rowCount: 0 };
  }

  // Determine maximum column index
  let maxCol = 0;
  for (const row of tableRows) {
    for (const colIdx of row.keys()) {
      if (colIdx > maxCol) maxCol = colIdx;
    }
  }

  // First row is headers
  const headerRow = tableRows[0];
  const headers: string[] = [];
  for (let c = 0; c <= maxCol; c++) {
    const h = (headerRow.get(c) || '').trim();
    headers.push(h.length > 0 ? h : `Column_${c + 1}`);
  }

  const rawRows: Array<Record<string, string>> = [];
  for (let r = 1; r < tableRows.length; r++) {
    const rowMap = tableRows[r];
    const rowObj: Record<string, string> = { _originalRowNumber: String(r + 1) };
    let hasData = false;

    for (let c = 0; c <= maxCol; c++) {
      const headerName = headers[c];
      const val = (rowMap.get(c) || '').trim();
      if (val.length > 0) hasData = true;
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
): ParsedSheet {
  const lowerName = filename.toLowerCase();
  if (lowerName.endsWith('.csv') || lowerName.endsWith('.txt')) {
    return parseCsv(buffer);
  }
  if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xlsm') || lowerName.endsWith('.xls')) {
    // Check if it's zip based (PK..)
    if (buffer.length >= 4 && buffer[0] === 0x50 && buffer[1] === 0x4b) {
      return parseXlsx(buffer);
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
    return parseXlsx(buffer);
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
  target: 'CUSTOMER' | 'VENDOR',
): Record<string, string> {
  const definitions =
    target === 'CUSTOMER' ? CUSTOMER_COLUMN_DEFINITIONS : VENDOR_COLUMN_DEFINITIONS;

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
