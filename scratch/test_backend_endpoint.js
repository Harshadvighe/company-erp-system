const http = require('http');

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, data: parsed.data !== undefined ? parsed.data : parsed });
        } catch {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function runTest() {
  console.log('1. Logging in as Admin...');
  const loginRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/auth/login',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    },
    { emailOrUsername: 'admin', password: 'Saark@2026' }
  );

  const token = loginRes.data?.tokens?.accessToken || loginRes.data?.accessToken || loginRes.data?.token;
  if (!token) {
    console.error('Failed to get auth token:', loginRes.data);
    process.exit(1);
  }
  console.log('Login OK, token acquired.');

  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  console.log('\n2. Testing /api/v1/panel-manufacturing/booster-pump/calculate...');
  const calcPayload = {
    product_type: 'HYPN',
    pump_model: 'Booster Pump',
    switchgear_make: 'Schneider',
    panel_class: 'DOMESTIC',
    vfd_make: 'Delta',
    phase: '3PH',
    pump_current: 40.0,
    pump_hp: 20,
    num_pumps: 3,
    starter_type: 'STARDELTA',
    num_vfd: 3,
    multivfd_bypass: 'NO',
    olr_required: 'NO',
    indicator_required: 'YES',
    panel_type: 'INDOOR',
    thermal_protection: 'NO',
    humidity_protection: 'NO',
    customer_margin_percent: 0,
  };

  const calcRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/panel-manufacturing/booster-pump/calculate',
      method: 'POST',
      headers,
    },
    calcPayload
  );

  console.log('Calculation HTTP Status:', calcRes.status);
  console.log('Pricing:', calcRes.data.pricing);
  console.log('Derived:', calcRes.data.derived);
  console.log('BOM item count:', calcRes.data.bom?.length);

  if (
    calcRes.data.pricing?.totalMaterialCost === 182189.50 &&
    calcRes.data.pricing?.laborCost === 2250.00 &&
    calcRes.data.pricing?.grandTotal === 184439.50 &&
    calcRes.data.bom?.length === 36
  ) {
    console.log('\n✅ CALCULATION REST ENDPOINT VERIFIED 100% MATCH!');
  } else {
    console.error('Mismatch in calculation REST endpoint response');
    process.exit(1);
  }

  console.log('\n3. Testing Save Specification...');
  // Get first customer
  const custRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/customers',
      method: 'GET',
      headers,
    }
  );
  const firstCustomer = Array.isArray(custRes.data) ? custRes.data[0] : (custRes.data?.customers?.[0]);
  const customerId = firstCustomer?.id;
  console.log('Using Customer ID:', customerId || 'fallback');

  const saveRes = await request(
    {
      hostname: 'localhost',
      port: 3000,
      path: '/api/v1/panel-manufacturing/booster-pump/save-spec',
      method: 'POST',
      headers,
    },
    { ...calcPayload, customerId }
  );

  console.log('Save Spec HTTP Status:', saveRes.status);
  console.log('Saved Spec Panel Code:', saveRes.data?.spec?.panelCode);
  console.log('Saved Spec Final Price: Rs.', saveRes.data?.spec?.finalPrice);
  console.log('Saved Spec BOM Items:', saveRes.data?.spec?.bomItems?.length);

  if (saveRes.data?.spec?.panelCode && saveRes.data?.spec?.bomItems?.length === 36) {
    console.log('\n✅ SAVE SPECIFICATION REST ENDPOINT VERIFIED 100% SUCCESS!');
  } else {
    console.error('Failed to verify saved spec');
    process.exit(1);
  }
}

runTest().catch((err) => {
  console.error('Test execution error:', err);
  process.exit(1);
});
