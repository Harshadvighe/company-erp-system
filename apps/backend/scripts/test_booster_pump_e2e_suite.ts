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

async function runComprehensiveBoosterPumpSuite() {
  console.log('================================================================');
  console.log('   SAARK ERP: BOOSTER PUMP CONTROL PANEL & CALCULATOR E2E TEST   ');
  console.log('================================================================\n');

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition: boolean, message: string) {
    totalTests++;
    if (!condition) {
      console.error(`❌ [TEST ${totalTests}] FAILED: ${message}`);
      throw new Error(`Assertion failed: ${message}`);
    }
    console.log(`✅ [TEST ${totalTests}] PASS: ${message}`);
    passedTests++;
  }

  // ─── 1. Authenticate with Real Backend ─────────────────────
  console.log('🔑 STEP 1: Backend Authentication & JWT Verification...');
  const loginRes = await apiRequest({
    path: '/api/v1/auth/login',
    method: 'POST',
    data: { emailOrUsername: 'admin', password: 'Saark@2026' },
  });

  assert(loginRes.status === 200 || loginRes.status === 201, 'Admin login HTTP Status is 200/201');
  const token =
    loginRes.data?.tokens?.accessToken ||
    loginRes.data?.accessToken ||
    loginRes.data?.token;
  assert(typeof token === 'string' && token.length > 20, 'Acquired valid JWT access token');

  const authHeaders = { Authorization: `Bearer ${token}` };

  // ─── 2. Scenario 1: Exact Benchmark (20 HP, 3 Pumps, 3 VFDs) ─
  console.log('\n⚡ STEP 2: Scenario 1 - Standard Specification Benchmark (20 HP, 3 Pumps, 3 VFDs)...');
  const s1Payload = {
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

  const s1Res = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/calculate',
    method: 'POST',
    headers: authHeaders,
    data: s1Payload,
  });

  assert(s1Res.status === 201, 'Scenario 1 calculation endpoint returned HTTP 201');
  const s1Pricing = s1Res.data.pricing;
  const s1Derived = s1Res.data.derived;
  const s1Bom = s1Res.data.bom;

  assert(s1Derived.kilowatt === 14.9, `Kilowatt is 14.9 kW (got ${s1Derived.kilowatt})`);
  assert(s1Derived.totalCurrent === 120.0, `Total panel current is 120.0 A (got ${s1Derived.totalCurrent})`);
  assert(s1Derived.controllerType === 'HMI', `Controller is HMI Touch (got ${s1Derived.controllerType})`);
  assert(s1Derived.starterType === 'STARDELTA', `Starter resolved to STARDELTA (got ${s1Derived.starterType})`);
  assert(s1Derived.mainIncomerType === 'THREE POLE MCCB', `Main incomer is THREE POLE MCCB (got ${s1Derived.mainIncomerType})`);
  assert(s1Derived.mccbRating === 125, `MCCB rating sized to 125A standard rating (got ${s1Derived.mccbRating})`);
  assert(s1Derived.isBusbarRequired === true, `Busbar Assembly is REQUIRED (>100A)`);
  assert(s1Derived.inputWireGaugeSqmm === 35, `Input wire gauge is 35 sq mm (got ${s1Derived.inputWireGaugeSqmm})`);
  assert(s1Derived.outputWireGaugeSqmm === 2.5, `Pump output wire gauge is 2.5 sq mm (got ${s1Derived.outputWireGaugeSqmm})`);

  // Assert exact price amounts
  assert(s1Pricing.totalMaterialCost === 182189.50, `Total Material DP = Rs. 182,189.50 (got ${s1Pricing.totalMaterialCost})`);
  assert(s1Pricing.laborCost === 2250.00, `Labor & Assembly Cost = Rs. 2,250.00 (got ${s1Pricing.laborCost})`);
  assert(s1Pricing.grandTotal === 184439.50, `Grand Total Price = Rs. 184,439.50 (got ${s1Pricing.grandTotal})`);
  assert(s1Bom.length === 36, `BOM contains all 36 line items (got ${s1Bom.length})`);

  // ─── 3. Scenario 2: Small Booster System (<= 7.5 HP, DOL) ───
  console.log('\n⚡ STEP 3: Scenario 2 - Small System (5 HP, 2 Pumps, 1 VFD, Automatic -> DOL)...');
  const s2Payload = {
    product_type: 'HYPN',
    pump_model: 'Booster Pump',
    switchgear_make: 'Schneider',
    panel_class: 'DOMESTIC',
    vfd_make: 'Delta',
    phase: '3PH',
    pump_hp: 5,
    num_pumps: 2,
    starter_type: 'Automatic Selector',
    num_vfd: 1,
    multivfd_bypass: 'NO',
  };

  const s2Res = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/calculate',
    method: 'POST',
    headers: authHeaders,
    data: s2Payload,
  });

  assert(s2Res.status === 201, 'Scenario 2 calculation returned HTTP 201');
  const s2Derived = s2Res.data.derived;
  const s2Bom = s2Res.data.bom;

  assert(s2Derived.starterType === 'DOL', `Automatic selector resolved to DOL for 5 HP <= 7.5 HP (got ${s2Derived.starterType})`);
  assert(s2Derived.outputWireGaugeSqmm === 2.5, `Output wire is 2.5 sq mm`);
  
  // Fans & Filters for 1 VFD: 1 fan, 2 filters
  const fanItems = s2Bom.filter((b: any) => b.category === 'Fan');
  const filterItems = s2Bom.filter((b: any) => b.category === 'AIR FILTER');
  assert(fanItems.length === 1 && fanItems[0].quantity === 1, `1 cooling fan for single VFD panel`);
  assert(filterItems.length === 1 && filterItems[0].quantity === 2, `2 louvre filters for single VFD panel`);

  // Duct sizing: 25x60 for HP <= 7.5
  const trayItem = s2Bom.find((b: any) => b.itemName.includes('25X60'));
  assert(trayItem !== undefined, `25x60 cable tray used for 5 HP system`);

  // ─── 4. Scenario 3: Industrial DLC Controller (0 VFD, 4 Pumps, Star-Delta) ─
  console.log('\n⚡ STEP 4: Scenario 3 - Industrial 4-Pump DLC Automation (No VFD, 30 HP, 4P MCCB)...');
  const s3Payload = {
    product_type: 'STP',
    pump_model: 'Submersible Pump',
    switchgear_make: 'L&T',
    panel_class: 'INDUSTRIAL',
    phase: '3PH',
    pump_hp: 30,
    pump_current: 45.0,
    num_pumps: 4,
    starter_type: 'STARDELTA',
    num_vfd: 0,
    olr_required: 'YES',
  };

  const s3Res = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/calculate',
    method: 'POST',
    headers: authHeaders,
    data: s3Payload,
  });

  assert(s3Res.status === 201, 'Scenario 3 calculation returned HTTP 201');
  const s3Derived = s3Res.data.derived;
  const s3Bom = s3Res.data.bom;

  assert(s3Derived.controllerType === 'DLC', `Resolved to DLC controller for 0 VFDs`);
  assert(s3Derived.mainIncomerType === 'FOUR POLE MCCB', `Industrial incomer resolved to FOUR POLE MCCB (got ${s3Derived.mainIncomerType})`);
  assert(s3Derived.mccbPoles === '4P', `MCCB poles is 4P`);
  assert(s3Derived.contactorCount === 12, `Contactor count for 4 pumps Star-Delta DLC is 12 (4 x 3 = 12, got ${s3Derived.contactorCount})`);
  assert(s3Derived.olrCount === 4, `OLR count is 4 (1 per pump in Industrial mode)`);
  assert(s3Derived.sppCount === 1, `SPP single phasing preventer included`);

  // Check DLC Controller item in BOM
  const dlcItem = s3Bom.find((b: any) => b.sku === '5');
  assert(dlcItem !== undefined, `DLC controller SKU 5 present in BOM`);

  // ─── 5. Scenario 4: Multi-VFD with Bypass Provision Enabled ──
  console.log('\n⚡ STEP 5: Scenario 4 - Multi-VFD with Bypass Enabled (10 HP, 2 Pumps, 2 VFDs)...');
  const s4Payload = {
    product_type: 'HYPN',
    pump_model: 'Vertical Inline Pump',
    switchgear_make: 'SIMENS',
    vfd_make: 'Siemens',
    phase: '3PH',
    pump_hp: 10,
    num_pumps: 2,
    starter_type: 'STARDELTA',
    num_vfd: 2,
    multivfd_bypass: 'YES',
  };

  const s4Res = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/calculate',
    method: 'POST',
    headers: authHeaders,
    data: s4Payload,
  });

  assert(s4Res.status === 201, 'Scenario 4 calculation returned HTTP 201');
  const s4Derived = s4Res.data.derived;
  const s4Bom = s4Res.data.bom;

  // StarDelta with Bypass enabled: 5 contactors per pump => 2 * 5 = 10
  assert(s4Derived.contactorCount === 10, `Contactor count for Bypass Star-Delta is 10 (2 pumps x 5 = 10, got ${s4Derived.contactorCount})`);
  const isolatorItem = s4Bom.find((b: any) => b.sku === '285');
  assert(isolatorItem !== undefined, `Multi-VFD Isolator card (SKU 285) included for multiple VFDs`);

  // ─── 6. Scenario 5: Commercial Pricing Adjustments (+15% & -5%) ─
  console.log('\n⚡ STEP 6: Scenario 5 - Customer Pricing Margin & Discount Adjustments...');
  
  // +15% Margin
  const marginPayload = { ...s1Payload, customer_margin_percent: 15.0 };
  const marginRes = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/calculate',
    method: 'POST',
    headers: authHeaders,
    data: marginPayload,
  });
  const mPricing = marginRes.data.pricing;
  const expectedAdj15 = Number(((mPricing.basePanelCost * 15) / 100).toFixed(2));
  assert(mPricing.customerAdjustmentAmount === expectedAdj15, `+15% margin correctly calculated as Rs. ${expectedAdj15}`);
  assert(mPricing.grandTotal === Number((mPricing.basePanelCost + expectedAdj15).toFixed(2)), `Grand total correctly reflects +15% margin`);

  // -5% Discount
  const discountPayload = { ...s1Payload, customer_margin_percent: -5.0 };
  const discountRes = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/calculate',
    method: 'POST',
    headers: authHeaders,
    data: discountPayload,
  });
  const dPricing = discountRes.data.pricing;
  const expectedAdjMinus5 = Number(((dPricing.basePanelCost * -5) / 100).toFixed(2));
  assert(dPricing.customerAdjustmentAmount === expectedAdjMinus5, `-5% discount correctly calculated as Rs. ${expectedAdjMinus5}`);
  assert(dPricing.grandTotal === Number((dPricing.basePanelCost + expectedAdjMinus5).toFixed(2)), `Grand total correctly reflects -5% discount`);

  // ─── 7. STEP 7: Database Persistence & Specification Verification ─
  console.log('\n💾 STEP 7: Database Persistence & Panel Specification CRUD Lifecycle...');
  
  // 7.1 Save Spec
  const saveRes = await apiRequest({
    path: '/api/v1/panel-manufacturing/booster-pump/save-spec',
    method: 'POST',
    headers: authHeaders,
    data: s1Payload,
  });

  assert(saveRes.status === 201, `Specification saved with HTTP Status 201`);
  const savedSpec = saveRes.data.spec;
  assert(typeof savedSpec.id === 'string', `Saved spec has valid UUID: ${savedSpec.id}`);
  assert(savedSpec.panelCode.startsWith('PANEL-'), `Panel code follows sequential format: ${savedSpec.panelCode}`);
  assert(savedSpec.panelType === 'BOOSTER_PUMP', `Panel type is BOOSTER_PUMP`);
  assert(savedSpec.finalPrice === 184439.50, `Final price stored matches calculation: Rs. ${savedSpec.finalPrice}`);
  assert(savedSpec.bomItems.length === 36, `All 36 BOM line items persisted in database`);

  // 7.2 Read Spec from DB via /api/v1/panel-manufacturing/specs/:id
  const getRes = await apiRequest({
    path: `/api/v1/panel-manufacturing/specs/${savedSpec.id}`,
    method: 'GET',
    headers: authHeaders,
  });

  assert(getRes.status === 200, `Fetched saved specification with HTTP Status 200`);
  const fetchedSpec = getRes.data;
  assert(fetchedSpec.id === savedSpec.id, `Fetched spec ID matches saved ID`);
  assert(fetchedSpec.customer !== null, `Customer relation successfully loaded`);
  assert(fetchedSpec.bomItems.length === 36, `Fetched spec has all 36 BOM items intact`);

  // Check specific BOM items in database
  const vfdInDb = fetchedSpec.bomItems.find((b: any) => b.componentName.includes('VFD DRIVE'));
  const hmiInDb = fetchedSpec.bomItems.find((b: any) => b.componentName.includes('HMI'));
  const contactorInDb = fetchedSpec.bomItems.find((b: any) => b.componentName.includes('CONTACTOR'));
  const wireInDb = fetchedSpec.bomItems.find((b: any) => b.componentName.includes('WIRE 35'));

  assert(vfdInDb !== undefined && vfdInDb.quantity === 3, `DB BOM: 3x VFD Drives stored with unitPrice Rs. ${vfdInDb?.unitPrice}`);
  assert(hmiInDb !== undefined && hmiInDb.quantity === 1, `DB BOM: 1x HMI Controller stored with unitPrice Rs. ${hmiInDb?.unitPrice}`);
  assert(contactorInDb !== undefined && contactorInDb.quantity === 6, `DB BOM: 6x Contactors stored with unitPrice Rs. ${contactorInDb?.unitPrice}`);
  assert(wireInDb !== undefined && wireInDb.quantity === 2, `DB BOM: 35 sq mm incomer wire stored with unitPrice Rs. ${wireInDb?.unitPrice}`);

  console.log('\n================================================================');
  console.log(`🎉 ALL ${passedTests}/${totalTests} TESTS PASSED WITH 100% SUCCESS!`);
  console.log('   The Booster Pump Control Panel & Calculator is fully verified');
  console.log('   against the real NestJS backend, SQLite database & Prisma MES!');
  console.log('================================================================');
}

runComprehensiveBoosterPumpSuite().catch((err) => {
  console.error('\n❌ TEST SUITE FAILED WITH ERROR:', err);
  process.exit(1);
});
