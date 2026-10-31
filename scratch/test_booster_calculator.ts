import { BoosterPumpCalculatorService } from '../apps/backend/src/modules/panel-manufacturing/booster-pump-calculator.service';

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
console.log('Labor Cost:', result.pricing.laborCost, '(Expected: 2250.00)');
console.log('Total Material DP:', result.pricing.totalMaterialCost, '(Expected: 182189.50)');
console.log('Grand Total:', result.pricing.grandTotal, '(Expected: 184439.50)');
console.log('Total BOM Items:', result.bom.length, '(Expected: 35)');

const diffMaterial = Math.abs(result.pricing.totalMaterialCost - 182189.50);
const diffLabor = Math.abs(result.pricing.laborCost - 2250.00);
const diffGrand = Math.abs(result.pricing.grandTotal - 184439.50);

if (diffMaterial < 0.01 && diffLabor < 0.01 && diffGrand < 0.01 && result.bom.length === 35) {
  console.log('\n>>> SUCCESS! All formulas and numbers EXACTLY match the specification! <<<');
} else {
  console.error('\n>>> MISMATCH DETECTED:');
  console.error('Material diff:', diffMaterial);
  console.error('Labor diff:', diffLabor);
  console.error('Grand diff:', diffGrand);
  console.error('BOM item count:', result.bom.length);
  console.log(JSON.stringify(result.bom, null, 2));
  process.exit(1);
}
