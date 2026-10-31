const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'saark_erp_production_jwt_secret_key_2026_x98123';
const BASE_URL = 'http://localhost:3000';

let authToken = '';

function request(method, pathName, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(pathName, BASE_URL);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Authorization': `Bearer ${authToken}`,
        ...headers,
      },
    };

    let bodyData = null;
    if (data && !(data instanceof Buffer) && typeof data === 'object') {
      bodyData = JSON.stringify(data);
      options.headers['Content-Type'] = 'application/json';
      options.headers['Content-Length'] = Buffer.byteLength(bodyData);
    } else if (data instanceof Buffer) {
      bodyData = data;
      options.headers['Content-Length'] = data.length;
    }

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        let parsed = body;
        try {
          parsed = JSON.parse(body);
        } catch (e) {}
        const responseData = (parsed && parsed.success === true && parsed.data !== undefined) ? parsed.data : parsed;
        resolve({ status: res.statusCode, data: responseData, raw: parsed, headers: res.headers });
      });
    });

    req.on('error', reject);
    if (bodyData) req.write(bodyData);
    req.end();
  });
}

function createMultipartFormData(fields, fileField) {
  const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);
  const crlf = '\r\n';
  const parts = [];

  for (const [key, val] of Object.entries(fields)) {
    parts.push(
      `--${boundary}${crlf}Content-Disposition: form-data; name="${key}"${crlf}${crlf}${val}${crlf}`
    );
  }

  if (fileField) {
    const { name, filename, contentType, buffer } = fileField;
    const header = `--${boundary}${crlf}Content-Disposition: form-data; name="${name}"; filename="${filename}"${crlf}Content-Type: ${contentType}${crlf}${crlf}`;
    const footer = crlf;
    
    const headBuf = Buffer.from(header, 'utf-8');
    const footBuf = Buffer.from(footer, 'utf-8');
    const fieldBufs = Buffer.concat(parts.map((p) => Buffer.from(p, 'utf-8')));
    const endBuf = Buffer.from(`--${boundary}--${crlf}`, 'utf-8');

    const totalBuffer = Buffer.concat([fieldBufs, headBuf, buffer, footBuf, endBuf]);
    return {
      buffer: totalBuffer,
      contentType: `multipart/form-data; boundary=${boundary}`,
    };
  }

  const fieldBufs = Buffer.concat(parts.map((p) => Buffer.from(p, 'utf-8')));
  const endBuf = Buffer.from(`--${boundary}--${crlf}`, 'utf-8');
  return {
    buffer: Buffer.concat([fieldBufs, endBuf]),
    contentType: `multipart/form-data; boundary=${boundary}`,
  };
}

async function runSuite() {
  console.log('================================================================');
  console.log('🧪 B2B MARKETPLACE COMPREHENSIVE TEST SUITE');
  console.log('   - File Uploads (PDF & Images)');
  console.log('   - Field-Level Validations');
  console.log('   - 7-Step PIM Lifecycle');
  console.log('   - Financials & Landed Cost Formulas');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✅ PASS: ${message}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${message}`);
      failed++;
    }
  }

  try {
    const adminUser = await prisma.user.findFirst({
      where: { email: 'admin@saark.in' },
    });
    if (!adminUser) throw new Error('Admin user not found');
    authToken = jwt.sign(
      { sub: adminUser.id, email: adminUser.email, username: adminUser.username },
      JWT_SECRET,
      { expiresIn: '1h' }
    );

    // -------------------------------------------------------------
    // TEST 1: PDF File Upload (Spec Sheet / Manual)
    // -------------------------------------------------------------
    console.log('--- TEST 1: PDF Document Upload & Storing ---');
    const dummyPdfContent = Buffer.from(
      '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 300 144]>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000018 00000 n\n0000000067 00000 n\n0000000116 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n185\n%%EOF'
    );
    const pdfMultipart = createMultipartFormData(
      {
        assetType: 'SPEC_SHEET',
        description: 'Industrial Booster Pump Full Technical Spec Sheet PDF',
      },
      {
        name: 'file',
        filename: 'Booster_Pump_Spec_Sheet_v2.pdf',
        contentType: 'application/pdf',
        buffer: dummyPdfContent,
      }
    );

    const pdfRes = await request('POST', '/api/v1/b2b/upload', pdfMultipart.buffer, {
      'Content-Type': pdfMultipart.contentType,
    });
    console.log('PDF Upload Response Data:', pdfRes.data);

    assert(pdfRes.status === 201, `PDF Upload response status is 201 (Got ${pdfRes.status})`);
    assert(pdfRes.data.fileUrl && pdfRes.data.fileUrl.startsWith('/api/v1/documents/files/'), `PDF fileUrl generated: ${pdfRes.data.fileUrl}`);
    assert(pdfRes.data.assetType === 'SPEC_SHEET', `Asset type is SPEC_SHEET`);
    assert(pdfRes.data.fileName.includes('.pdf'), `Uploaded file name has .pdf extension`);

    // Verify PDF can be downloaded/viewed via fileUrl
    const pdfFetch = await request('GET', pdfRes.data.fileUrl);
    assert(pdfFetch.status === 200, `PDF can be served via URL HTTP 200`);
    const savedPdfMediaId = pdfRes.data.id;

    // -------------------------------------------------------------
    // TEST 2: Image File Upload (Logo / Product Photo)
    // -------------------------------------------------------------
    console.log('\n--- TEST 2: Image File Upload & Storing ---');
    // Minimal 1x1 PNG buffer
    const dummyPngContent = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      'base64'
    );
    const imgMultipart = createMultipartFormData(
      {
        assetType: 'LOGO',
        description: 'Saark Clean Vector Brand Logo',
      },
      {
        name: 'file',
        filename: 'saark_brand_logo.png',
        contentType: 'image/png',
        buffer: dummyPngContent,
      }
    );

    const imgRes = await request('POST', '/api/v1/b2b/upload', imgMultipart.buffer, {
      'Content-Type': imgMultipart.contentType,
    });

    assert(imgRes.status === 201, `Image Upload response status is 201 (Got ${imgRes.status})`);
    assert(imgRes.data.fileUrl && imgRes.data.fileUrl.startsWith('/api/v1/documents/files/'), `Image fileUrl generated: ${imgRes.data.fileUrl}`);
    assert(imgRes.data.assetType === 'LOGO', `Asset type is LOGO`);

    // -------------------------------------------------------------
    // TEST 3: Validation - Reject Invalid / Empty Fields
    // -------------------------------------------------------------
    console.log('\n--- TEST 3: Validation - Reject Missing Required Fields ---');
    const badRes1 = await request('POST', '/api/v1/b2b/products', {
      originalName: '', // empty name
      originalModel: 'MOD-1',
    });
    assert(badRes1.status === 400, `Rejects empty originalName with 400 Bad Request (Got ${badRes1.status})`);

    const badRes2 = await request('POST', '/api/v1/b2b/products', {
      originalName: 'Valid Name',
      originalModel: '', // empty model
    });
    assert(badRes2.status === 400, `Rejects empty originalModel with 400 Bad Request (Got ${badRes2.status})`);

    const badRes3 = await request('POST', '/api/v1/b2b/products', {
      originalName: 'Valid Name',
      originalModel: 'MOD-1',
      baseCost: -500, // negative cost
    });
    assert(badRes3.status === 400, `Rejects negative baseCost with 400 Bad Request (Got ${badRes3.status})`);

    const badRes4 = await request('POST', '/api/v1/b2b/products', {
      originalName: 'Valid Name',
      originalModel: 'MOD-1',
      minOrderQty: 0, // invalid MOQ
    });
    assert(badRes4.status === 400, `Rejects MOQ <= 0 with 400 Bad Request (Got ${badRes4.status})`);

    // -------------------------------------------------------------
    // TEST 4: Financial Formula & Margin Calculation Accuracy
    // -------------------------------------------------------------
    console.log('\n--- TEST 4: Landed Cost & Margin Calculation Engine ---');
    const calcInput = {
      baseCost: 20000,
      brandingFee: 1500,
      packagingFee: 800,
      freightPerUnit: 1200,
      customsDutyPct: 10, // 10% of 20000 = 2000
      qualityInspectionPerUnit: 500,
      retailPrice: 35000,
    };
    // Expected Landed = 20000 + 1500 + 800 + 1200 + 2000 + 500 = 26000
    // Expected Gross Margin = ((35000 - 26000) / 35000) * 100 = (9000 / 35000) * 100 = 25.714...%
    const calcRes = await request('POST', '/api/v1/b2b/products/calculate-financials', calcInput);
    assert(calcRes.status === 201, `Financial calculation endpoint status is 201`);
    assert(Math.round(calcRes.data.landedCost) === 26000, `Landed cost correctly calculated as ₹26,000 (Got ₹${calcRes.data.landedCost})`);
    assert(calcRes.data.marginPct.toFixed(2) === '25.71', `Gross margin correctly calculated as 25.71% (Got ${calcRes.data.marginPct.toFixed(2)}%)`);

    // Test zero retail price protection
    const zeroPriceCalc = await request('POST', '/api/v1/b2b/products/calculate-financials', {
      baseCost: 1000,
      retailPrice: 0,
    });
    assert(zeroPriceCalc.status === 201 && zeroPriceCalc.data.marginPct === 0, `Zero retail price handled safely with 0% margin without crashing`);

    // -------------------------------------------------------------
    // TEST 5: Full 7-Step PIM Product Creation & Persistence
    // -------------------------------------------------------------
    console.log('\n--- TEST 5: Complete 7-Step PIM Product Creation ---');
    const fullProductPayload = {
      // 1. Taxonomy & Mapping
      rebrandedName: 'Saark HydroSmart Commercial Dual Booster Panel',
      rebrandedModel: 'SHS-DBP-75KW',
      originalName: 'Hangzhou Pump Co Dual Inverter Control Enclosure',
      originalModel: 'HZ-DICE-75000',
      primaryCategory: 'Pumps & Pumping Systems',
      subCategory: 'Booster Pump Panels',
      collection: 'Industrial 2026 Pro',
      skuCode: 'SKU-SHS-DBP-7501',
      status: 'Draft',

      // 2. Supplier & Factory
      supplierName: 'Hangzhou Fluidics & Power Electric Ltd.',
      factoryLocation: 'Zhejiang Industrial Zone, China',
      supplierRating: 4.8,
      leadTimeDays: 28,
      portOfOrigin: 'Ningbo Port',

      // 3. Technical Specifications
      material: 'CRCA Powder Coated Steel IP55 Enclosure',
      dimensions: '800 x 600 x 250 mm',
      weight: 42.5,
      hsCode: '8537.10.90',
      description: 'Fully automatic dual booster pump control panel with ABB VFD, Schneider switchgear and IoT remote telemetry.',

      // 4. White-Label Branding
      logoPlacement: 'Front Enclosure Door Laser Etched Badge',
      logoUrl: imgRes.data.fileUrl,
      warrantyPeriodMonths: 24,
      warrantyCardUrl: pdfRes.data.fileUrl,

      // 5. Commercial Financials
      baseCost: 20000,
      brandingFee: 1500,
      sampleShipping: 800, // used for packaging
      freightPerUnit: 1200,
      customsDutyPct: 10,
      qualityInspectionPerUnit: 500,
      landedCost: 26000,
      retailPrice: 35000,
      marginPct: 25.71,
      minOrderQty: 5,
      stock: 12,

      // 6 & 7: Variants and Documents
      variants: [
        { sku: 'SHS-DBP-75KW-380V', name: '3-Phase 380V 50Hz', baseCost: 20000, retailPrice: 35000, stock: 8 },
        { sku: 'SHS-DBP-75KW-415V', name: '3-Phase 415V 50Hz Heavy Duty', baseCost: 22000, retailPrice: 38500, stock: 4 },
      ],
      documents: [
        { assetType: 'SPEC_SHEET', filePath: pdfRes.data.fileUrl, fileName: 'Booster_Pump_Spec_Sheet_v2.pdf', description: 'Technical Spec Sheet PDF' },
        { assetType: 'LOGO', filePath: imgRes.data.fileUrl, fileName: 'saark_brand_logo.png', description: 'Brand Logo' },
      ],
    };

    const createRes = await request('POST', '/api/v1/b2b/products', fullProductPayload);
    if (createRes.status !== 201) {
      console.log('Create Error Response:', JSON.stringify(createRes.data, null, 2));
    }
    assert(createRes.status === 201, `Product created successfully with 201 (Got ${createRes.status})`);
    const createdId = createRes.data.id;
    assert(createdId && createdId.length > 5, `Product assigned unique ID: ${createdId}`);
    assert(createRes.data.rebrandedName === fullProductPayload.rebrandedName, `Rebranded title preserved`);
    const docs = createRes.data.documents || createRes.data.media || [];
    assert(docs.length === 2, `Both PDF and Image media linked to product (Found ${docs.length})`);

    // -------------------------------------------------------------
    // TEST 6: Media Association & Retrieval Endpoint
    // -------------------------------------------------------------
    console.log('\n--- TEST 6: Media Association & Retrieval ---');
    const mediaRes = await request('GET', `/api/v1/b2b/products/${createdId}/media`);
    assert(mediaRes.status === 200, `Media list endpoint status is 200`);
    assert(Array.isArray(mediaRes.data) && mediaRes.data.length === 2, `Product has exactly 2 associated media files`);
    const specSheetMedia = mediaRes.data.find((m) => m.assetType === 'SPEC_SHEET');
    assert(specSheetMedia && (specSheetMedia.fileUrl || specSheetMedia.filePath).includes('.pdf'), `Found SPEC_SHEET PDF media with valid fileUrl`);

    // -------------------------------------------------------------
    // TEST 7: Publishing Product & Catalog Visibility
    // -------------------------------------------------------------
    console.log('\n--- TEST 7: Product Publishing & Catalog Verification ---');
    const publishRes = await request('PUT', `/api/v1/b2b/products/${createdId}`, {
      status: 'published',
    });
    assert(publishRes.status === 200, `Product status updated to published`);
    assert(publishRes.data.status === 'published', `Status confirmed as 'published'`);

    const catalogRes = await request('GET', '/api/v1/b2b/products/published');
    assert(catalogRes.status === 200, `Published catalog endpoint returns HTTP 200`);
    const inCatalog = catalogRes.data.find((p) => p.id === createdId);
    assert(!!inCatalog, `Created product appears in published catalog for buyers`);
    assert(inCatalog && inCatalog.retailPrice === 35000, `Catalog retail price is ₹35,000`);

    // -------------------------------------------------------------
    // TEST 8: Delete Media Clean-up
    // -------------------------------------------------------------
    console.log('\n--- TEST 8: Media Deletion ---');
    const mediaToDeleteId = specSheetMedia ? specSheetMedia.id : savedPdfMediaId;
    const delRes = await request('DELETE', `/api/v1/b2b/media/${mediaToDeleteId}`);
    assert(delRes.status === 200, `Media deletion endpoint returned HTTP 200`);

    const mediaAfterDel = await request('GET', `/api/v1/b2b/products/${createdId}/media`);
    assert(mediaAfterDel.data.length === 1, `Media count decreased to 1 after deletion`);

  } catch (err) {
    console.error('Fatal test error:', err);
    failed++;
  }

  console.log('\n================================================================');
  console.log(`📊 FINAL RESULTS: ${passed} PASSED | ${failed} FAILED`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runSuite();
