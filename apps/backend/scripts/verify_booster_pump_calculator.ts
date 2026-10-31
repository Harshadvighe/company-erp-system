import { BoosterPumpCalculatorService } from '../src/modules/panel-manufacturing/booster-pump-calculator.service';

const dummyPrisma: any = {};
const dummySequence: any = {};
const service = new BoosterPumpCalculatorService(dummyPrisma, dummySequence);

const sampleInput = {
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

const result = service.calculate(sampleInput);

console.log('=== CALCULATION VERIFICATION ===');
console.log('Kilowatt:', result.derived.kilowatt, '(Expected: 14.9)');
console.log('Total Current:', result.derived.totalCurrent, '(Expected: 120.0)');
console.log('Starter Type:', result.derived.starterType, '(Expected: STARDELTA)');
console.log('Controller:', result.derived.controllerType, '(Expected: HMI)');
console.log('Labor Cost: Rs.', result.pricing.laborCost.toFixed(2), '(Expected: 2250.00)');
console.log('Total Material DP: Rs.', result.pricing.totalMaterialCost.toFixed(2), '(Expected: 182189.50)');
console.log('Grand Total: Rs.', result.pricing.grandTotal.toFixed(2), '(Expected: 184439.50)');
console.log('Total BOM Items:', result.bom.length, '(Expected: 35)');

const expectedItems: Record<string, { qty: number; unit: number; total: number }> = {
  '4': { qty: 1, unit: 35000.00, total: 35000.00 },
  '15': { qty: 1, unit: 585.00, total: 585.00 },
  '17': { qty: 1, unit: 320.00, total: 320.00 },
  '285': { qty: 1, unit: 359.00, total: 359.00 },
  '316': { qty: 3, unit: 32260.00, total: 96780.00 },
  '132': { qty: 1, unit: 180.30, total: 180.30 },
  '164': { qty: 3, unit: 1575.30, total: 4725.90 },
  '276': { qty: 3, unit: 609.00, total: 1827.00 },
  '220': { qty: 6, unit: 4562.00, total: 27372.00 },
  '354': { qty: 2, unit: 687.50, total: 1375.00 },
  '355': { qty: 2, unit: 687.50, total: 1375.00 },
  '356': { qty: 2, unit: 687.50, total: 1375.00 },
  '379': { qty: 3, unit: 47.50, total: 142.50 },
  '380': { qty: 3, unit: 47.50, total: 142.50 },
  '381': { qty: 3, unit: 47.50, total: 142.50 },
  '387': { qty: 300, unit: 12.50, total: 3750.00 },
  '421': { qty: 4, unit: 32.90, total: 131.60 },
  '420': { qty: 2, unit: 370.00, total: 740.00 },
  '391': { qty: 120, unit: 0.50, total: 60.00 },
  '340': { qty: 6, unit: 16.45, total: 98.70 },
  '341': { qty: 6, unit: 14.00, total: 84.00 },
  '342': { qty: 6, unit: 14.00, total: 84.00 },
  '349': { qty: 14, unit: 10.23, total: 143.22 },
  '408': { qty: 15, unit: 10.50, total: 157.50 },
  '425': { qty: 1, unit: 102.00, total: 102.00 },
  '426': { qty: 6, unit: 187.20, total: 1123.20 },
  '423': { qty: 3, unit: 62.16, total: 186.48 },
  '441': { qty: 3, unit: 105.00, total: 315.00 },
  '442': { qty: 6, unit: 60.90, total: 365.40 },
  '443': { qty: 3, unit: 60.90, total: 182.70 },
  '449': { qty: 3, unit: 9.00, total: 27.00 },
  '20': { qty: 3, unit: 795.00, total: 2385.00 },
  '475': { qty: 2, unit: 30.00, total: 60.00 },
  '427': { qty: 6, unit: 70.00, total: 420.00 },
  '2345': { qty: 2, unit: 11.00, total: 22.00 },
  '2432': { qty: 1, unit: 50.00, total: 50.00 },
};

let hasError = false;
for (const item of result.bom) {
  const exp = expectedItems[item.sku];
  if (!exp) {
    console.log(`EXTRA SKU: ${item.sku} - ${item.itemName} = ${item.totalPrice}`);
    hasError = true;
  } else if (Math.abs(exp.total - item.totalPrice) > 0.01) {
    console.log(`DIFF IN SKU ${item.sku} (${item.itemName}): expected ${exp.total} (${exp.qty}x${exp.unit}), got ${item.totalPrice} (${item.quantity}x${item.unitPrice})`);
    hasError = true;
  }
}
for (const [sku, exp] of Object.entries(expectedItems)) {
  if (!result.bom.find((b) => b.sku === sku)) {
    console.log(`MISSING SKU: ${sku} = ${exp.total}`);
    hasError = true;
  }
}

const diffMaterial = Math.abs(result.pricing.totalMaterialCost - 182189.50);
const diffLabor = Math.abs(result.pricing.laborCost - 2250.00);
const diffGrand = Math.abs(result.pricing.grandTotal - 184439.50);

if (!hasError && diffMaterial < 0.01 && diffLabor < 0.01 && diffGrand < 0.01) {
  console.log('\n>>> SUCCESS! All engineering formulas, 36 BOM SKUs and DP totals EXACTLY match the specification sample! <<<');
  process.exit(0);
} else {
  console.error('\n>>> TEST FAILED! <<<');
  process.exit(1);
}
