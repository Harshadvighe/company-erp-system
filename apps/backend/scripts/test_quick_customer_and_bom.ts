import * as http from 'http';

interface HttpRequestOptions {
  path: string;
  method?: string;
  headers?: Record<string, string>;
  data?: any;
}

function apiRequest(options: HttpRequestOptions): Promise<{ status: number; data: any }> {
  return new Promise((resolve, reject) => {
    const dataString = options.data ? JSON.stringify(options.data) : null;
    const req = http.request(
      {
        hostname: 'localhost',
        port: 3000,
        path: options.path,
        method: options.method || 'GET',
        headers: {
          'Content-Type': 'application/json',
          ...(dataString ? { 'Content-Length': Buffer.byteLength(dataString) } : {}),
          ...(options.headers || {}),
        },
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(body);
            resolve({
              status: res.statusCode || 200,
              data: parsed.data !== undefined ? parsed.data : parsed,
            });
          } catch {
            resolve({ status: res.statusCode || 200, data: body });
          }
        });
      }
    );
    req.on('error', reject);
    if (dataString) req.write(dataString);
    req.end();
  });
}

let passedTests = 0;
let totalTests = 0;

function assert(condition: boolean, msg: string) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`✅ [TEST ${totalTests}] PASS: ${msg}`);
  } else {
    console.error(`❌ [TEST ${totalTests}] FAIL: ${msg}`);
    throw new Error(`Assertion failed: ${msg}`);
  }
}

async function runQuickCustomerAndBomTests() {
  console.log('================================================================');
  console.log('   SAARK ERP: QUICK ADD CUSTOMER & CALCULATE BOM TEST SUITE      ');
  console.log('================================================================\n');

  // 1. Authenticate as Admin
  console.log('🔑 STEP 1: Authenticating as Admin User...');
  const loginRes = await apiRequest({
    path: '/api/v1/auth/login',
    method: 'POST',
    data: {
      emailOrUsername: 'admin',
      password: 'Saark@2026',
    },
  });

  assert(loginRes.status === 200 || loginRes.status === 201, 'Login HTTP Status 200/201');
  const token =
    loginRes.data?.tokens?.accessToken ||
    loginRes.data?.data?.accessToken ||
    loginRes.data?.accessToken;
  assert(typeof token === 'string' && token.length > 20, 'JWT token acquired');
  const authHeaders = { Authorization: `Bearer ${token}` };

  // 2. Quick Add Customer with +12.5% Margin
  console.log('\n👤 STEP 2: Quick Adding Customer (Aqua Flow Automation with +12.5% Margin)...');
  const custRes = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/quick-customer',
    method: 'POST',
    headers: authHeaders,
    data: {
      companyName: 'Aqua Flow Automation Systems',
      percentage: 12.5,
    },
  });

  assert(custRes.status === 201, 'Quick customer creation endpoint returned HTTP 201');
  const cust1 = custRes.data;
  assert(cust1.companyName === 'Aqua Flow Automation Systems', 'Customer companyName stored');
  assert(cust1.customerCode.startsWith('CUS-'), `Generated sequential code ${cust1.customerCode}`);
  assert(cust1.percentage === 12.5, 'Stored custom percentage of 12.5%');
  assert(typeof cust1.id === 'string' && cust1.id.length > 10, 'Customer UUID generated');

  // 3. Calculate BOM with Customer and Margin
  console.log('\n⚡ STEP 3: Calculating BOM with Customer Aqua Flow & 12.5% Margin...');
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
    customerId: cust1.id,
    customer_margin_percent: 12.5,
  };

  const calcRes = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/calculate',
    method: 'POST',
    headers: authHeaders,
    data: calcPayload,
  });

  assert(calcRes.status === 201, 'Calculation returned HTTP 201');
  const pricing = calcRes.data.pricing;
  assert(pricing.totalMaterialCost === 182189.50, 'Total Material Cost = Rs. 182,189.50');
  assert(pricing.laborCost === 2250.00, 'Labor Cost = Rs. 2,250.00');
  assert(pricing.basePanelCost === 184439.50, 'Base Panel Cost = Rs. 184,439.50');
  assert(pricing.customerAdjustmentPercent === 12.5, 'Adjustment percentage applied = 12.5%');
  assert(pricing.customerAdjustmentAmount === 23054.94, 'Calculated +12.5% amount = Rs. 23,054.94');
  assert(pricing.grandTotal === 207494.44, 'Grand Total with Margin = Rs. 207,494.44');
  assert(calcRes.data.bom.length === 36, 'Complete 36-line BOM generated');

  // 4. Save Spec to DB with this Customer
  console.log('\n💾 STEP 4: Saving Calculated Specification into MES DB with Customer Link...');
  const saveRes = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/save-spec',
    method: 'POST',
    headers: authHeaders,
    data: calcPayload,
  });

  assert(saveRes.status === 201, 'Saved specification returned HTTP 201');
  const savedSpec = saveRes.data.spec;
  assert(savedSpec.customerId === cust1.id, 'Saved spec is linked to Aqua Flow Automation Systems');
  assert(savedSpec.marginPercent === 12.5, 'Saved spec marginPercent is 12.5%');
  assert(savedSpec.finalPrice === 207494.44, 'Saved spec final price is Rs. 207,494.44');
  assert(savedSpec.customer.companyName === 'Aqua Flow Automation Systems', 'Customer relation joined');
  assert(savedSpec.bomItems.length === 36, 'All 36 BOM items stored in DB');

  // 5. Quick Add Second Customer with Discount (-5.0%)
  console.log('\n👤 STEP 5: Quick Adding Dealer Customer (Shree Balaji Hydro Tech with -5.0% Discount)...');
  const cust2Res = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/quick-customer',
    method: 'POST',
    headers: authHeaders,
    data: {
      companyName: 'Shree Balaji Hydro Tech',
      percentage: -5.0,
    },
  });

  assert(cust2Res.status === 201, 'Second quick customer created');
  const cust2 = cust2Res.data;
  assert(cust2.companyName === 'Shree Balaji Hydro Tech', 'Customer 2 name stored');
  assert(cust2.percentage === -5.0, 'Stored discount of -5.0%');

  // 6. Calculate BOM for Second Customer
  console.log('\n⚡ STEP 6: Calculating BOM with Customer 2 Discount (-5.0%)...');
  const calc2Res = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/calculate',
    method: 'POST',
    headers: authHeaders,
    data: {
      ...calcPayload,
      customerId: cust2.id,
      customer_margin_percent: -5.0,
    },
  });

  const pricing2 = calc2Res.data.pricing;
  assert(pricing2.customerAdjustmentPercent === -5.0, 'Discount percentage = -5.0%');
  assert(pricing2.customerAdjustmentAmount === -9221.98, 'Calculated discount amount = -Rs. 9,221.98');
  assert(pricing2.grandTotal === 175217.52, 'Discounted Grand Total = Rs. 175,217.52');

  console.log('\n================================================================');
  console.log(`🎉 ALL ${passedTests}/${totalTests} TESTS PASSED WITH 100% SUCCESS!`);
  console.log('   Quick Add Customer modal, percentage integration, and BOM calculation');
  console.log('   are fully verified against the live NestJS backend and database!');
  console.log('================================================================');
}

runQuickCustomerAndBomTests().catch((err) => {
  console.error('\n❌ Test execution failed:', err);
  process.exit(1);
});
