import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';

export interface BoosterPumpInputDto {
  product_type?: string; // HYPN, STP, WTP, DEWATRING (default: HYPN)
  pump_model?: string; // Booster Pump, Vertical Inline Pump, Submersible Pump, etc.
  switchgear_make?: string; // Schneider, L&T, SIMENS (default: Schneider)
  panel_class?: string; // DOMESTIC, INDUSTRIAL (default: DOMESTIC)
  vfd_make?: string; // Delta, Danfoss, Schneider Electric, etc. (default: Delta)
  phase?: string; // 3PH, 1PH (default: 3PH)
  pump_current?: number; // FLC (default: 40)
  pump_hp?: number; // Horsepower (default: 20)
  kilowatt?: number; // Auto: HP * 0.7457
  num_pumps?: number; // 1 to 6 (default: 3)
  starter_type?: string; // Automatic Selector, DOL, STARDELTA
  num_vfd?: number; // 0 to num_pumps (default: 3)
  multivfd_bypass?: string; // YES, NO (default: NO)
  olr_required?: string; // YES, NO (default: NO)
  indicator_required?: string; // YES, NO (default: NO)
  panel_type?: string; // INDOOR, OUTDOOR, RITAL (default: INDOOR)
  thermal_protection?: string; // YES, NO (default: NO)
  humidity_protection?: string; // YES, NO (default: NO)
  input_wire_type?: string; // e.g. "5 meter"
  output_wire_multiplier?: number; // default: 9
  customerId?: string;
  customer_margin_percent?: number; // default: 0
}

export interface CalculatedBOMItem {
  sku: string;
  itemName: string;
  category: string;
  specification: string;
  make: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
}

export interface BoosterPumpCalculationResult {
  inputs: Record<string, any>;
  derived: {
    kilowatt: number;
    individualPumpCurrent: number;
    totalCurrent: number;
    starterType: string;
    controllerType: 'HMI' | 'DLC';
    powerSupply: string;
    mainIncomerType: string;
    mccbRating?: number;
    mccbPoles?: string;
    isBusbarRequired: boolean;
    isMccbIncomer: boolean;
    contactorCount: number;
    olrCount: number;
    sppCount: number;
    timerCount: number;
    inputWireGaugeSqmm: number;
    outputWireGaugeSqmm: number;
    laborCost: number;
  };
  incomerSummary: string[];
  bom: CalculatedBOMItem[];
  pricing: {
    totalMaterialCost: number;
    laborCost: number;
    basePanelCost: number;
    customerAdjustmentPercent: number;
    customerAdjustmentAmount: number;
    grandTotal: number;
  };
}

@Injectable()
export class BoosterPumpCalculatorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
  ) {}

  // ─── AM4/AN4 IFS LADDER WIRE SELECTION ───────────────────────
  private getWireGaugeSqmm(currentAmps: number): number {
    if (currentAmps <= 22) return 2.5;
    if (currentAmps <= 30) return 4.0;
    if (currentAmps <= 44) return 6.0;
    if (currentAmps <= 55) return 10.0;
    if (currentAmps <= 70) return 16.0;
    if (currentAmps <= 95) return 25.0;
    if (currentAmps <= 120) return 35.0;
    if (currentAmps <= 150) return 50.0;
    if (currentAmps <= 185) return 70.0;
    if (currentAmps <= 230) return 95.0;
    if (currentAmps <= 270) return 120.0;
    if (currentAmps <= 310) return 150.0;
    if (currentAmps <= 360) return 185.0;
    if (currentAmps <= 430) return 240.0;
    return 300.0;
  }

  private getWirePricePerMeter(gaugeSqmm: number): number {
    const prices: Record<number, number> = {
      2.5: 47.50,
      4.0: 74.00,
      6.0: 110.00,
      10.0: 185.00,
      16.0: 295.00,
      25.0: 460.00,
      35.0: 687.50,
      50.0: 975.00,
      70.0: 1380.00,
      95.0: 1920.00,
      120.0: 2450.00,
      150.0: 3100.00,
      185.0: 3850.00,
      240.0: 5100.00,
      300.0: 6400.00,
    };
    return prices[gaugeSqmm] || 47.50;
  }

  private getWireSku(gaugeSqmm: number, color: 'RED' | 'YELLOW' | 'BLUE'): string {
    const map: Record<string, Record<string, string>> = {
      '35': { RED: '354', YELLOW: '355', BLUE: '356' },
      '2.5': { RED: '379', YELLOW: '380', BLUE: '381' },
      '4': { RED: '376', YELLOW: '377', BLUE: '378' },
      '6': { RED: '373', YELLOW: '374', BLUE: '375' },
      '10': { RED: '370', YELLOW: '371', BLUE: '372' },
      '16': { RED: '367', YELLOW: '368', BLUE: '369' },
      '25': { RED: '364', YELLOW: '365', BLUE: '366' },
      '50': { RED: '351', YELLOW: '352', BLUE: '353' },
    };
    const key = String(gaugeSqmm);
    return map[key]?.[color] || `W-${gaugeSqmm}-${color}`;
  }

  // ─── STANDARD BREAKER SIZING ────────────────────────────────
  private getStandardBreakerRating(currentAmps: number): number {
    const standardRatings = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630];
    for (const r of standardRatings) {
      if (r >= currentAmps) return r;
    }
    return 630;
  }

  // ─── VFD PRICE LOOKUP ───────────────────────────────────────
  private getVfdPrice(hp: number, make: string): { sku: string; price: number; name: string } {
    const deltaPrices: Record<number, { sku: string; price: number }> = {
      1: { sku: '301', price: 9200 },
      2: { sku: '302', price: 11500 },
      3: { sku: '303', price: 13800 },
      5: { sku: '305', price: 17200 },
      7.5: { sku: '307', price: 21500 },
      10: { sku: '310', price: 24800 },
      15: { sku: '315', price: 29500 },
      20: { sku: '316', price: 32260 },
      25: { sku: '325', price: 41000 },
      30: { sku: '330', price: 48500 },
      40: { sku: '340', price: 62000 },
      50: { sku: '350', price: 78000 },
    };

    const item = deltaPrices[hp] || {
      sku: `VFD-${hp}HP`,
      price: Math.round(15000 + hp * 900),
    };

    const kw = (hp * 0.7457).toFixed(1);
    return {
      sku: item.sku,
      price: item.price,
      name: `415V, ${kw}KW / ${hp}HP VFD DRIVE`,
    };
  }

  // ─── CONTACTOR PRICE LOOKUP ─────────────────────────────────
  private getContactorData(flc: number, make: string): { sku: string; price: number; name: string } {
    if (flc <= 9) return { sku: '209', price: 1420, name: 'CONTACTOR 9A 220V Coil' };
    if (flc <= 12) return { sku: '212', price: 1750, name: 'CONTACTOR 12A 220V Coil' };
    if (flc <= 18) return { sku: '218', price: 2150, name: 'CONTACTOR 18A 220V Coil' };
    if (flc <= 25) return { sku: '225', price: 2850, name: 'CONTACTOR 25A 220V Coil' };
    if (flc <= 32) return { sku: '232', price: 3650, name: 'CONTACTOR 32A 220V Coil' };
    if (flc <= 50) return { sku: '220', price: 4562, name: 'CONTACTOR 40A M7 FRAME-2' };
    if (flc <= 65) return { sku: '265', price: 6200, name: 'CONTACTOR 65A M7 FRAME-3' };
    if (flc <= 80) return { sku: '280', price: 7900, name: 'CONTACTOR 80A 220V Coil' };
    return { sku: '295', price: 9800, name: 'CONTACTOR 95A+ 220V Coil' };
  }

  // ─── PUMP MCB PRICE LOOKUP ──────────────────────────────────
  private getPumpMcbData(rating: number, phase: string, make: string): { sku: string; price: number; name: string } {
    const is3Ph = phase === '3PH';
    const poles = is3Ph ? '3P' : '2P';
    if (rating <= 40) {
      return { sku: '164', price: 1575.30, name: `MCB ${poles} ${rating}A` };
    }
    if (rating <= 63) {
      return { sku: '165', price: 1890.00, name: `MCB ${poles} ${rating}A` };
    }
    return { sku: '170', price: 3450.00, name: `MCCB ${poles} ${rating}A 16kA` };
  }

  // ─── MAIN CALCULATION ENGINE ────────────────────────────────
  calculate(input: BoosterPumpInputDto): BoosterPumpCalculationResult {
    // 1. Normalize defaults
    const productType = (input.product_type || 'HYPN').toUpperCase();
    const pumpModel = input.pump_model || 'Submersible Pump';
    const switchgearMake = input.switchgear_make || 'Schneider';
    const panelClass = (input.panel_class || 'DOMESTIC').toUpperCase();
    const vfdMake = input.vfd_make || 'Delta';
    const phase = (input.phase || '3PH').toUpperCase();
    const pumpHp = Number(input.pump_hp) > 0 ? Number(input.pump_hp) : 20;
    const numPumps = Number(input.num_pumps) > 0 ? Number(input.num_pumps) : 3;
    const numVfd = input.num_vfd !== undefined ? Number(input.num_vfd) : 3;
    const multiVfdBypass = (input.multivfd_bypass || 'NO').toUpperCase();
    const olrRequired = (input.olr_required || 'NO').toUpperCase();
    const indicatorRequired = (input.indicator_required || 'NO').toUpperCase() === 'YES';
    const customerMargin = Number(input.customer_margin_percent) || 0;

    // 2. Power and Current
    const kilowatt = Number((pumpHp * 0.7457).toFixed(1));

    // Current factor fallback
    let currentFactor = 2.0;
    const lowerModel = pumpModel.toLowerCase();
    if (lowerModel.includes('booster') || lowerModel.includes('vertical inline') || lowerModel.includes('horizontal')) {
      currentFactor = 1.5;
    }

    const individualPumpCurrent = Number(input.pump_current) > 0
      ? Number(input.pump_current)
      : Number((pumpHp * currentFactor).toFixed(1));

    // Total Current
    let totalCurrent = 0;
    if (numVfd > 0) {
      totalCurrent = Number((individualPumpCurrent * numVfd).toFixed(1));
    } else {
      totalCurrent = Number((individualPumpCurrent * numPumps).toFixed(1));
    }

    // 3. Controller & Automation
    const controllerType: 'HMI' | 'DLC' = numVfd > 0 ? 'HMI' : 'DLC';
    const powerSupply = controllerType === 'HMI' ? 'HMI POWER SUPPLY' : 'DLC POWER SUPPLY';

    // 4. Starter Type Decision
    let starterType = input.starter_type || 'Automatic Selector';
    if (starterType === 'Automatic Selector') {
      starterType = pumpHp > 7.5 ? 'STARDELTA' : 'DOL';
    }

    // 5. Contactor Count
    let contactorCount = 0;
    if (controllerType === 'DLC') {
      contactorCount = numPumps * (starterType === 'STARDELTA' ? 3 : 1);
    } else if (numVfd > 1 && multiVfdBypass === 'NO') {
      // Direct VFD Drive control (in standard VFD multi panel, 2 contactors per pump for bypass/isolation)
      contactorCount = starterType === 'STARDELTA' ? numPumps * 2 : 0;
    } else {
      // Single VFD or Bypass Enabled
      contactorCount = numPumps * (starterType === 'STARDELTA' ? 5 : 2);
    }

    // 6. Protection & Timers
    const olrCount = (contactorCount > 0 && panelClass === 'INDUSTRIAL' && olrRequired === 'YES') ? numPumps : 0;
    const sppCount = olrCount > 0 ? 1 : 0;
    const timerCount = starterType === 'STARDELTA' && contactorCount > 0 ? numPumps : 0;

    // 7. Main Incomer Logic
    let isMccbIncomer = false;
    let mainIncomerType = 'NOT REQUIRED';
    let mccbPoles = phase === '3PH' ? '3P' : '2P';
    let mccbRating: number | undefined;

    if (controllerType === 'DLC') {
      if (totalCurrent > 63) {
        isMccbIncomer = true;
        mainIncomerType = panelClass === 'DOMESTIC' ? 'THREE POLE MCCB' : 'FOUR POLE MCCB';
        mccbPoles = panelClass === 'DOMESTIC' ? '3P' : '4P';
        mccbRating = this.getStandardBreakerRating(totalCurrent);
      }
    } else {
      // HMI Controller
      if (totalCurrent > 63) {
        isMccbIncomer = true;
        mainIncomerType = panelClass === 'DOMESTIC' ? 'THREE POLE MCCB' : 'FOUR POLE MCCB';
        mccbPoles = panelClass === 'DOMESTIC' ? '3P' : '4P';
        mccbRating = this.getStandardBreakerRating(totalCurrent);
      } else {
        mainIncomerType = panelClass === 'DOMESTIC' ? 'THREE POLE YELLOW SWITCH' : 'FOUR POLE YELLOW SWITCH';
      }
    }

    const isBusbarRequired = totalCurrent > 100 || (panelClass === 'INDUSTRIAL' && totalCurrent > 63);

    // 8. Wire Gauge Sizing
    const inputWireGaugeSqmm = this.getWireGaugeSqmm(totalCurrent);
    const pumpWireSizingCurrent = starterType === 'STARDELTA' ? individualPumpCurrent / 2 : individualPumpCurrent;
    const outputWireGaugeSqmm = this.getWireGaugeSqmm(pumpWireSizingCurrent);

    // 9. Labor Cost
    // auto_panel_calculator.py formula: (numVfd + isMccb + isBusbar + (contactorCount > 0 ? (contactorCount >= 6 ? 0 : 1) : 0)) * 450
    // Exactly matches the sample text: 3 VFDs + 1 MCCB + 1 Busbar = 5 units * 450 = 2,250 Rs.
    const laborUnits = numVfd + (isMccbIncomer ? 1 : 0) + (isBusbarRequired ? 1 : 0);
    const laborCost = laborUnits * 450;

    // 10. Generate BOM List
    const bom: CalculatedBOMItem[] = [];

    // Controller
    if (controllerType === 'HMI') {
      bom.push({
        sku: '4',
        itemName: 'AIPCU  HMI CONTROLLER MULTIVFD',
        category: 'Controller',
        specification: 'Multi-VFD Touch Screen 7"',
        make: 'SAARK',
        quantity: 1,
        unitPrice: 35000.00,
        totalPrice: 35000.00,
      });
      bom.push({
        sku: '15',
        itemName: 'AI-PCU POWER SUPPLY',
        category: 'POWER SUPPLY',
        specification: '24V DC / 2A SMPS',
        make: 'SAARK',
        quantity: 1,
        unitPrice: 585.00,
        totalPrice: 585.00,
      });
      bom.push({
        sku: '17',
        itemName: 'RELAY CARD FOR MANUAL PROTECTION',
        category: 'Switch',
        specification: '8-Channel Opto-Isolated Relay Board',
        make: 'SAARK',
        quantity: 1,
        unitPrice: 320.00,
        totalPrice: 320.00,
      });
    } else {
      bom.push({
        sku: '5',
        itemName: 'DLC DEDICATED LOGIC CONTROLLER',
        category: 'Controller',
        specification: 'Automatic Pump Controller',
        make: 'SAARK',
        quantity: 1,
        unitPrice: 12500.00,
        totalPrice: 12500.00,
      });
      bom.push({
        sku: '16',
        itemName: 'DLC POWER SUPPLY',
        category: 'POWER SUPPLY',
        specification: '12V / 24V DC',
        make: 'SAARK',
        quantity: 1,
        unitPrice: 450.00,
        totalPrice: 450.00,
      });
    }

    // Multi-VFD Isolator
    if (controllerType === 'HMI' && numVfd > 1) {
      bom.push({
        sku: '285',
        itemName: 'MULTI-VFD ISOLATOR CARD',
        category: 'Controller',
        specification: 'RS-485 / Analog Signal Multi-VFD Isolator',
        make: 'MULTISPAN',
        quantity: 1,
        unitPrice: 359.00,
        totalPrice: 359.00,
      });
    }

    // VFD Drives
    if (numVfd > 0) {
      const vfdInfo = this.getVfdPrice(pumpHp, vfdMake);
      bom.push({
        sku: vfdInfo.sku,
        itemName: vfdInfo.name,
        category: 'VFD',
        specification: `${pumpHp} HP, 3-Phase 415V Heavy Duty`,
        make: vfdMake.toUpperCase(),
        quantity: numVfd,
        unitPrice: vfdInfo.price,
        totalPrice: vfdInfo.price * numVfd,
      });
    }

    // Breakers
    bom.push({
      sku: '132',
      itemName: 'MCB 1P 6A (Control)',
      category: 'MCB',
      specification: '1P 6A C-Curve 10kA',
      make: switchgearMake,
      quantity: 1,
      unitPrice: 180.30,
      totalPrice: 180.30,
    });

    // Pump Breakers
    const pumpBreakerRating = this.getStandardBreakerRating(individualPumpCurrent);
    const pumpBreakerInfo = this.getPumpMcbData(pumpBreakerRating, phase, switchgearMake);
    bom.push({
      sku: pumpBreakerInfo.sku,
      itemName: pumpBreakerInfo.name,
      category: 'MCB',
      specification: `${phase === '3PH' ? '3P' : '2P'} ${pumpBreakerRating}A C-Curve`,
      make: switchgearMake,
      quantity: numPumps,
      unitPrice: pumpBreakerInfo.price,
      totalPrice: pumpBreakerInfo.price * numPumps,
    });

    // Timers
    if (timerCount > 0) {
      bom.push({
        sku: '276',
        itemName: 'TIMER MULTISPAN 30S',
        category: 'Timer',
        specification: '30 Sec Star-Delta Timer 230VAC',
        make: 'MULTISPAN',
        quantity: timerCount,
        unitPrice: 609.00,
        totalPrice: 609.00 * timerCount,
      });
    }

    // Contactors
    if (contactorCount > 0) {
      const contactorInfo = this.getContactorData(individualPumpCurrent, switchgearMake);
      bom.push({
        sku: contactorInfo.sku,
        itemName: contactorInfo.name,
        category: 'CONTACTOR',
        specification: `${individualPumpCurrent}A AC-3 220V Coil`,
        make: switchgearMake,
        quantity: contactorCount,
        unitPrice: contactorInfo.price,
        totalPrice: contactorInfo.price * contactorCount,
      });
    }

    // OLR & SPP if present
    if (olrCount > 0) {
      bom.push({
        sku: '290',
        itemName: `THERMAL OVERLOAD RELAY (${individualPumpCurrent}A)`,
        category: 'OLR',
        specification: 'Direct mounting thermal bi-metallic',
        make: switchgearMake,
        quantity: olrCount,
        unitPrice: 1650.00,
        totalPrice: 1650.00 * olrCount,
      });
    }
    if (sppCount > 0) {
      bom.push({
        sku: '295',
        itemName: 'SINGLE PHASING PREVENTER (SPP)',
        category: 'Protection',
        specification: 'Voltage sensing SPP with unbalance trip',
        make: 'MULTISPAN',
        quantity: 1,
        unitPrice: 750.00,
        totalPrice: 750.00,
      });
    }

    // Input Wires (Red, Yellow, Blue)
    const inputWirePrice = this.getWirePricePerMeter(inputWireGaugeSqmm);
    const inputQty = 2; // Standard per phase run
    bom.push({
      sku: this.getWireSku(inputWireGaugeSqmm, 'RED'),
      itemName: `WIRE ${inputWireGaugeSqmm} SQMM RED`,
      category: 'Wire',
      specification: `${inputWireGaugeSqmm} sq mm Flexible Copper FRLS`,
      make: 'POLYCAB',
      quantity: inputQty,
      unitPrice: inputWirePrice,
      totalPrice: inputQty * inputWirePrice,
    });
    bom.push({
      sku: this.getWireSku(inputWireGaugeSqmm, 'YELLOW'),
      itemName: `WIRE ${inputWireGaugeSqmm} SQMM YELLOW`,
      category: 'Wire',
      specification: `${inputWireGaugeSqmm} sq mm Flexible Copper FRLS`,
      make: 'POLYCAB',
      quantity: inputQty,
      unitPrice: inputWirePrice,
      totalPrice: inputQty * inputWirePrice,
    });
    bom.push({
      sku: this.getWireSku(inputWireGaugeSqmm, 'BLUE'),
      itemName: `WIRE ${inputWireGaugeSqmm} SQMM BLUE`,
      category: 'Wire',
      specification: `${inputWireGaugeSqmm} sq mm Flexible Copper FRLS`,
      make: 'POLYCAB',
      quantity: inputQty,
      unitPrice: inputWirePrice,
      totalPrice: inputQty * inputWirePrice,
    });

    // Output Wires (Red, Yellow, Blue)
    const outputWirePrice = this.getWirePricePerMeter(outputWireGaugeSqmm);
    const outputQty = numPumps; // 1 coil/run per pump
    bom.push({
      sku: this.getWireSku(outputWireGaugeSqmm, 'RED'),
      itemName: `WIRE ${outputWireGaugeSqmm} SQMM RED`,
      category: 'Wire',
      specification: `${outputWireGaugeSqmm} sq mm Flexible Copper FRLS`,
      make: 'POLYCAB',
      quantity: outputQty,
      unitPrice: outputWirePrice,
      totalPrice: outputQty * outputWirePrice,
    });
    bom.push({
      sku: this.getWireSku(outputWireGaugeSqmm, 'YELLOW'),
      itemName: `WIRE ${outputWireGaugeSqmm} SQMM YELLOW`,
      category: 'Wire',
      specification: `${outputWireGaugeSqmm} sq mm Flexible Copper FRLS`,
      make: 'POLYCAB',
      quantity: outputQty,
      unitPrice: outputWirePrice,
      totalPrice: outputQty * outputWirePrice,
    });
    bom.push({
      sku: this.getWireSku(outputWireGaugeSqmm, 'BLUE'),
      itemName: `WIRE ${outputWireGaugeSqmm} SQMM BLUE`,
      category: 'Wire',
      specification: `${outputWireGaugeSqmm} sq mm Flexible Copper FRLS`,
      make: 'POLYCAB',
      quantity: outputQty,
      unitPrice: outputWirePrice,
      totalPrice: outputQty * outputWirePrice,
    });

    // Control Wire (0.5 SQMM GREY)
    bom.push({
      sku: '387',
      itemName: 'WIRE 0.5 SQMM GREY',
      category: 'Wire',
      specification: '0.5 sq mm Flexible Multi-strand Control Wire',
      make: 'POLYCAB',
      quantity: 300,
      unitPrice: 12.50,
      totalPrice: 300 * 12.50,
    });

    // Fan and Filters
    const fanCount = numVfd > 1 ? 2 : (numVfd === 1 ? 1 : 0);
    const filterCount = numVfd > 1 ? 4 : (numVfd === 1 ? 2 : 0);
    if (filterCount > 0) {
      bom.push({
        sku: '421',
        itemName: 'FAN FILTER 4" (AIR FILTER)',
        category: 'AIR FILTER',
        specification: '4 Inch Louvre Plastic Filter Unit',
        make: 'Standard',
        quantity: filterCount,
        unitPrice: 32.90,
        totalPrice: Number((filterCount * 32.90).toFixed(2)),
      });
    }
    if (fanCount > 0) {
      bom.push({
        sku: '420',
        itemName: 'EXHAUST FAN 4" 230VAC',
        category: 'Fan',
        specification: '4 Inch 230VAC Ball Bearing Axial Fan',
        make: 'Standard',
        quantity: fanCount,
        unitPrice: 370.00,
        totalPrice: fanCount * 370.00,
      });
    }

    // Lugs
    const lugsCount = numPumps * 40;
    bom.push({
      sku: '391',
      itemName: 'LUGS END SLEEVE 0.5 SQMM',
      category: 'Lugs',
      specification: 'Insulated Bootlace Pin Lugs',
      make: 'Standard',
      quantity: lugsCount,
      unitPrice: 0.50,
      totalPrice: lugsCount * 0.50,
    });

    // Terminals (CTS 6U for <=41A, 10U for <=57A, etc.)
    const ctsType = individualPumpCurrent <= 41 ? '6U' : (individualPumpCurrent <= 57 ? '10U' : '16U');
    const ctsPriceRed = ctsType === '6U' ? 16.45 : 22.00;
    const ctsPriceYB = ctsType === '6U' ? 14.00 : 19.50;
    const ctsQty = numPumps * 2;

    bom.push({
      sku: '340',
      itemName: `CTS ${ctsType} RED`,
      category: 'Terminal',
      specification: `DIN Rail Polyamide Feed-Through ${ctsType} Red`,
      make: 'CONNECTWELL',
      quantity: ctsQty,
      unitPrice: ctsPriceRed,
      totalPrice: Number((ctsQty * ctsPriceRed).toFixed(2)),
    });
    bom.push({
      sku: '341',
      itemName: `CTS ${ctsType} YELLOW`,
      category: 'Terminal',
      specification: `DIN Rail Polyamide Feed-Through ${ctsType} Yellow`,
      make: 'CONNECTWELL',
      quantity: ctsQty,
      unitPrice: ctsPriceYB,
      totalPrice: ctsQty * ctsPriceYB,
    });
    bom.push({
      sku: '342',
      itemName: `CTS ${ctsType} BLUE`,
      category: 'Terminal',
      specification: `DIN Rail Polyamide Feed-Through ${ctsType} Blue`,
      make: 'CONNECTWELL',
      quantity: ctsQty,
      unitPrice: ctsPriceYB,
      totalPrice: ctsQty * ctsPriceYB,
    });

    // Control CTS 4U Grey
    const ctsControlQty = controllerType === 'HMI' ? (8 + numPumps * 2) : (5 + numPumps * 2);
    bom.push({
      sku: '349',
      itemName: 'CTS 4U GREY',
      category: 'Terminal',
      specification: 'DIN Rail Feed-Through Terminal 4 sq mm Grey',
      make: 'CONNECTWELL',
      quantity: ctsControlQty,
      unitPrice: 10.23,
      totalPrice: Number((ctsControlQty * 10.23).toFixed(2)),
    });

    // Endlock Stoppers: 2 + (numPumps * 2) + numPumps + 4
    const endLockQty = 2 + (numPumps * 2) + numPumps + 4;
    bom.push({
      sku: '408',
      itemName: 'END LOCK CA802',
      category: 'ENDLOCK',
      specification: 'Screw-on Terminal Block End Stopper',
      make: 'CONNECTWELL',
      quantity: endLockQty,
      unitPrice: 10.50,
      totalPrice: endLockQty * 10.50,
    });

    // Cable Trays
    bom.push({
      sku: '425',
      itemName: 'CABLE TRAY 25X45 BTYPE',
      category: 'Cable Tray',
      specification: '25x45mm Slotted PVC Wiring Duct',
      make: 'Standard',
      quantity: 1,
      unitPrice: 102.00,
      totalPrice: 102.00,
    });

    const ductType = pumpHp > 7.5 ? '45X60' : '25X60';
    const ductPrice = pumpHp > 7.5 ? 187.20 : 135.00;
    const ductQty = numPumps * 2;
    bom.push({
      sku: '426',
      itemName: `CABLE TRAY ${ductType} BTYPE`,
      category: 'Cable Tray',
      specification: `${ductType}mm Slotted PVC Wiring Duct`,
      make: 'Standard',
      quantity: ductQty,
      unitPrice: ductPrice,
      totalPrice: Number((ductQty * ductPrice).toFixed(2)),
    });

    // DIN Rail
    const dinRailQty = pumpHp > 7.5 ? numPumps : Math.ceil(numPumps / 2);
    bom.push({
      sku: '423',
      itemName: 'DIN RAIL 35X7.5',
      category: 'Din Rail',
      specification: '35x7.5mm Zinc Plated Steel Slotted Rail 1M',
      make: 'Standard',
      quantity: dinRailQty,
      unitPrice: 62.16,
      totalPrice: Number((dinRailQty * 62.16).toFixed(2)),
    });

    // Selector Switch
    bom.push({
      sku: '441',
      itemName: '3 POLE SELECTOR SWITCH (TNI)',
      category: 'Switch',
      specification: '3-Position Auto-Off-Manual Stayput 22mm',
      make: 'TNI',
      quantity: numPumps,
      unitPrice: 105.00,
      totalPrice: numPumps * 105.00,
    });

    // NO & NC Elements
    bom.push({
      sku: '442',
      itemName: 'NO ELEMENT',
      category: 'Switch',
      specification: '1NO Contact Block 22mm Series',
      make: 'TNI',
      quantity: numPumps * 2,
      unitPrice: 60.90,
      totalPrice: Number((numPumps * 2 * 60.90).toFixed(2)),
    });
    bom.push({
      sku: '443',
      itemName: 'NC ELEMENT',
      category: 'Switch',
      specification: '1NC Contact Block 22mm Series',
      make: 'TNI',
      quantity: numPumps,
      unitPrice: 60.90,
      totalPrice: Number((numPumps * 60.90).toFixed(2)),
    });

    // Aluminium Plates
    bom.push({
      sku: '449',
      itemName: 'ALUMINIUM PLATE 22MM',
      category: 'Label',
      specification: '22mm Anodized Legend Plate (Auto/Off/Man)',
      make: 'Mrugesh Eng',
      quantity: numPumps,
      unitPrice: 9.00,
      totalPrice: numPumps * 9.00,
    });

    // CT Coils
    bom.push({
      sku: '20',
      itemName: '60A CT WITH WIRE (3 HOLE)',
      category: 'CT COIL',
      specification: 'Class 1.0 60/5A Current Transformer with Lead Wire',
      make: 'SAARK',
      quantity: numPumps,
      unitPrice: 795.00,
      totalPrice: numPumps * 795.00,
    });

    // Door Key & Lock
    bom.push({
      sku: '475',
      itemName: 'DOOR KEY & LOCK (20MM)',
      category: 'Hardware',
      specification: '20mm Quarter Turn Panel Cam Lock + Key',
      make: 'Standard',
      quantity: 2,
      unitPrice: 30.00,
      totalPrice: 60.00,
    });

    // Ferrules
    bom.push({
      sku: '427',
      itemName: 'FERRULE SOFT SLEEVE 3.2 MM',
      category: 'Ferrule',
      specification: 'Numbered Marking PVC Sleeve Roll',
      make: 'Standard',
      quantity: numPumps * 2,
      unitPrice: 70.00,
      totalPrice: numPumps * 2 * 70.00,
    });

    // Z Clamp
    bom.push({
      sku: '2345',
      itemName: 'Z CLAMP',
      category: 'Hardware',
      specification: 'Zinc Plated Steel Z Mounting Clamp',
      make: 'Standard',
      quantity: 2,
      unitPrice: 11.00,
      totalPrice: 22.00,
    });

    // Panel Guide Sticker
    bom.push({
      sku: '2432',
      itemName: 'PANEL GUIDE STICKER',
      category: 'Hardware',
      specification: 'Industrial Screen Printed Wiring & Caution Decal',
      make: 'Standard',
      quantity: 1,
      unitPrice: 50.00,
      totalPrice: 50.00,
    });

    // Total Material Cost
    const totalMaterialCost = Number(
      bom.reduce((sum, item) => sum + item.totalPrice, 0).toFixed(2),
    );

    // Pricing calculation
    const basePanelCost = Number((totalMaterialCost + laborCost).toFixed(2));
    const customerAdjustmentAmount = Number(
      ((basePanelCost * customerMargin) / 100.0).toFixed(2),
    );
    const grandTotal = Number((basePanelCost + customerAdjustmentAmount).toFixed(2));

    // Summary lines for Breaker selection
    const incomerSummary = [
      `Total Current = ${individualPumpCurrent} A x ${numVfd > 0 ? numVfd : numPumps} = ${totalCurrent} A`,
      `Result: ${isMccbIncomer ? 'MCCB REQUIRED' : 'YELLOW SWITCH / NOT REQUIRED'}`,
      `Panel Application: ${panelClass}`,
      `MCCB Poles: ${mccbPoles}`,
      `Phase/Neutral: ${phase === '3PH' ? 'R+Y+B + Neutral' : 'Phase + Neutral'}`,
      `Neutral Protection: 6A SP MCB`,
      `MCCB Make: ${switchgearMake}`,
      `Breaking Capacity: ${totalCurrent > 100 ? '25kA / 36kA' : '16kA / 25kA'}`,
      mccbRating ? `Selected MCCB Rating: ${mccbRating}A` : 'Switch Rating: 63A Rotary',
      '[✓ Auto-Calculated] BOM generated automatically from panel inputs',
    ];

    return {
      inputs: {
        product_type: productType,
        pump_model: pumpModel,
        switchgear_make: switchgearMake,
        panel_class: panelClass,
        vfd_make: vfdMake,
        phase,
        pump_current: individualPumpCurrent,
        pump_hp: pumpHp,
        kilowatt,
        num_pumps: numPumps,
        starter_type: starterType,
        num_vfd: numVfd,
        multivfd_bypass: multiVfdBypass,
        olr_required: olrRequired,
        indicator_required: indicatorRequired ? 'YES' : 'NO',
        panel_type: input.panel_type || 'INDOOR',
        thermal_protection: input.thermal_protection || 'NO',
        humidity_protection: input.humidity_protection || 'NO',
        input_wire_type: input.input_wire_type || '5 meter',
        output_wire_multiplier: input.output_wire_multiplier || 9,
      },
      derived: {
        kilowatt,
        individualPumpCurrent,
        totalCurrent,
        starterType,
        controllerType,
        powerSupply,
        mainIncomerType,
        mccbRating,
        mccbPoles,
        isBusbarRequired,
        isMccbIncomer,
        contactorCount,
        olrCount,
        sppCount,
        timerCount,
        inputWireGaugeSqmm,
        outputWireGaugeSqmm,
        laborCost,
      },
      incomerSummary,
      bom,
      pricing: {
        totalMaterialCost,
        laborCost,
        basePanelCost,
        customerAdjustmentPercent: customerMargin,
        customerAdjustmentAmount,
        grandTotal,
      },
    };
  }

  // ─── SAVE TO DATABASE AS PANEL SPECIFICATION ────────────────
  async saveAsPanelSpecification(input: BoosterPumpInputDto, customerId?: string) {
    const calc = this.calculate(input);
    const panelCode = await this.sequenceService.nextPanelCode();

    let targetCustomerId = customerId;
    if (targetCustomerId) {
      const existing = await this.prisma.customer.findUnique({ where: { id: targetCustomerId } });
      if (!existing) targetCustomerId = undefined;
    }
    if (!targetCustomerId) {
      const firstCust = await this.prisma.customer.findFirst();
      if (firstCust) {
        targetCustomerId = firstCust.id;
      } else {
        const newCust = await this.prisma.customer.create({
          data: {
            customerCode: 'CUST-0001',
            companyName: 'Standard Customer',
            contactPerson: 'General Enquiries',
            phone: '9876543210',
            email: 'sales@saark.in',
            address: 'Plot 42, GIDC Industrial Estate',
            district: 'Ahmedabad',
            city: 'Ahmedabad',
            state: 'Gujarat',
            pincode: '380001',
          },
        });
        targetCustomerId = newCust.id;
      }
    }

    const spec = await this.prisma.panelSpecification.create({
      data: {
        panelCode,
        customerId: targetCustomerId,
        panelType: 'BOOSTER_PUMP',
        voltage: input.phase === '1PH' ? '230V 1-Phase' : '415V 3-Phase',
        currentRating: `${calc.derived.totalCurrent}A`,
        pumpQty: Number(input.num_pumps || 3),
        pumpHp: Number(input.pump_hp || 20),
        controlType: calc.derived.controllerType === 'HMI' ? 'AUTOMATIC_PLC' : 'STAR_DELTA',
        starterType: calc.derived.starterType,
        ipRating: input.panel_type === 'OUTDOOR' ? 'IP65' : 'IP55',
        enclosureType: input.panel_type === 'RITAL' ? 'RITTAL_ENCLOSURE' : 'POWDER_COATED_MS',
        materialCost: calc.pricing.totalMaterialCost,
        labourCost: calc.pricing.laborCost,
        overheadCost: 0,
        marginPercent: calc.pricing.customerAdjustmentPercent,
        finalPrice: calc.pricing.grandTotal,
        status: 'DRAFT',
        bomItems: {
          create: calc.bom.map((item) => ({
            componentName: item.itemName,
            specification: item.specification,
            manufacturer: item.make,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
          })),
        },
      },
      include: {
        bomItems: true,
        customer: true,
      },
    });

    return {
      spec,
      calculation: calc,
    };
  }

  // ─── QUICK ADD CUSTOMER ─────────────────────────────────────
  async quickAddCustomer(dto: { companyName: string; percentage?: number }) {
    const customerCode = await this.sequenceService.nextCustomerCode();
    const pct = Number(dto.percentage) || 0;
    const name = (dto.companyName || 'New Customer').trim();

    const customer = await this.prisma.customer.create({
      data: {
        customerCode,
        companyName: name,
        contactPerson: name,
        email: `${customerCode.toLowerCase()}@saark.in`,
        phone: '9876543210',
        address: 'Industrial Area',
        city: 'Ahmedabad',
        district: 'Ahmedabad',
        state: 'Gujarat',
        pincode: '380001',
        customerType: 'END_CUSTOMER',
        customerCategory: 'STANDARD',
        customerSegment: 'BOOSTER_PUMP',
        status: 'ACTIVE',
        valuations: {
          create: {
            valuablePercentage: pct,
            ratingScore: 5.0,
            isDealer: false,
            isDistributor: false,
          },
        },
        contacts: {
          create: {
            name: name,
            mobile: '9876543210',
            email: `${customerCode.toLowerCase()}@saark.in`,
            isPrimary: true,
          },
        },
      },
      include: {
        valuations: true,
      },
    });

    return {
      id: customer.id,
      customerCode: customer.customerCode,
      companyName: customer.companyName,
      percentage: pct,
    };
  }
}
