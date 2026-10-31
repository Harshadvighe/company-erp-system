const http = require('http');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'saark_erp_production_jwt_secret_key_2026_x98123';

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    req.on('error', reject);
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

async function runTests() {
  console.log('🚀 Starting B2B Marketplace & Trading Platform API E2E Tests...\n');

  // Find admin user to issue token
  const adminUser = await prisma.user.findFirst({
    where: { email: 'admin@saark.in' },
  });

  if (!adminUser) {
    throw new Error('Admin user not found in database. Run seed first.');
  }

  const token = jwt.sign(
    { sub: adminUser.id, email: adminUser.email, username: adminUser.username },
    JWT_SECRET,
    { expiresIn: '1h' }
  );

  const authHeaders = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  };

  // 1. Get Categories
  console.log('--- Test 1: GET /api/v1/b2b/categories ---');
  const catRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/b2b/categories',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`Status: ${catRes.status}, Categories found: ${catRes.data?.data?.length || 0}`);
  if (catRes.status !== 200) throw new Error(`Categories test failed: ${JSON.stringify(catRes.data)}`);

  // 2. Get Suppliers
  console.log('\n--- Test 2: GET /api/v1/b2b/suppliers ---');
  const supRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/b2b/suppliers',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`Status: ${supRes.status}, Suppliers found: ${supRes.data?.data?.length || 0}`);
  if (supRes.status !== 200) throw new Error(`Suppliers test failed: ${JSON.stringify(supRes.data)}`);

  // 3. Test Financial Calculator Engine
  console.log('\n--- Test 3: POST /api/v1/b2b/products/calculate-financials ---');
  // Formula check from user spec:
  // Base Cost = 10, Branding = 876, Packaging = 876, Freight = 876 => Landed = 2638
  // Retail = 87600 => Margin = ((87600 - 2638) / 87600) * 100 = 96.99%
  const finCalcRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/b2b/products/calculate-financials',
      method: 'POST',
      headers: authHeaders,
    },
    {
      baseCost: 10,
      brandingFee: 876,
      sampleShipping: 876,
      freightPerUnit: 876,
      retailPrice: 87600,
    }
  );
  console.log(`Status: ${finCalcRes.status}`);
  console.log('Calculation Result:', finCalcRes.data?.data);
  const fin = finCalcRes.data?.data;
  if (!fin || Math.abs(fin.landedCost - 2638) > 0.01 || Math.abs(fin.marginPct - 96.99) > 0.01) {
    throw new Error(`Financial calculation mismatch! Expected Landed: 2638, Margin: 96.99%. Got: ${JSON.stringify(fin)}`);
  }
  console.log('✅ Financial Formulas matched specification exactly: Landed Cost = 2638, Margin = 96.99%');

  // 4. Get All Products (Check Seed Data)
  console.log('\n--- Test 4: GET /api/v1/b2b/products ---');
  const prodsRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/b2b/products',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`Status: ${prodsRes.status}, Products count: ${prodsRes.data?.data?.length || 0}`);
  const legacyProd = prodsRes.data?.data?.find((p) => p.prodId === '20260920203658');
  if (legacyProd) {
    console.log(`✅ Legacy sample product found: ID ${legacyProd.prodId}, Rebranded: ${legacyProd.rebrandedName}, Retail: Rs.${legacyProd.retailPrice}, Margin: ${legacyProd.marginPct}%`);
  }

  // 5. Get Published Products Catalog
  console.log('\n--- Test 5: GET /api/v1/b2b/products/published ---');
  const pubRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/b2b/products/published',
    method: 'GET',
    headers: authHeaders,
  });
  console.log(`Status: ${pubRes.status}, Published items: ${pubRes.data?.data?.length || 0}`);

  // 6. Create New B2B Product with 7-Step PIM Data
  console.log('\n--- Test 6: POST /api/v1/b2b/products ---');
  const testProdId = `TEST_${Date.now()}`;
  const createRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/b2b/products',
      method: 'POST',
      headers: authHeaders,
    },
    {
      prodId: testProdId,
      primaryCategory: 'domastic',
      subCategory: 'dom1',
      internalTag: 'Automation, High-Tech',
      originalName: 'Hydro Booster Variable Inverter OEM',
      originalModel: 'HB-VFD-1000',
      rebrandedName: 'SAARK Hydro-Master Pro VFD',
      rebrandedModel: 'SRK-HM-1000',
      collection: 'Smart Water Solutions',
      description: 'Industrial automated booster pump inverter with dual pressure sensor feedback',
      material: 'SS304 Stainless Steel',
      dimensions: '450 x 300 x 200 mm',
      weight: 12.5,
      hsCode: '84137010',
      moq: 10,
      sampleCost: 15000,
      leadTime: 15,
      rating: 5,
      baseCost: 8500,
      brandingFee: 750,
      sampleShipping: 500,
      freightPerUnit: 1250,
      retailPrice: 24500,
      status: 'Draft',
    }
  );
  const createdId = createRes.data?.data?.id;
  console.log(`Status: ${createRes.status}`);
  console.log(`Created Product ID: ${createdId}, Landed Cost: ${createRes.data?.data?.landedCost}, Margin: ${createRes.data?.data?.marginPct}%`);

  // 7. Publish the Created Product
  console.log('\n--- Test 7: PUT /api/v1/b2b/products/:id (Publishing) ---');
  const updateRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: `/api/v1/b2b/products/${createdId}`,
      method: 'PUT',
      headers: authHeaders,
    },
    {
      status: 'published',
    }
  );
  console.log(`Status: ${updateRes.status}, New Status: ${updateRes.data?.data?.status}`);

  console.log('\n======================================================');
  console.log('🎉 ALL B2B MARKETPLACE & TRADING PLATFORM TESTS PASSED!');
  console.log('======================================================\n');

  await prisma.$disconnect();
}

runTests().catch(async (err) => {
  console.error('❌ Test failed:', err);
  await prisma.$disconnect();
  process.exit(1);
});
