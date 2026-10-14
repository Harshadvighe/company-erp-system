import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';

@Injectable()
export class PanelManufacturingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
    private readonly auditService: AuditService,
  ) {}

  async findAll() {
    return this.prisma.panelSpecification.findMany({
      include: {
        customer: { select: { companyName: true, customerCode: true } },
        bomItems: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const spec = await this.prisma.panelSpecification.findUnique({
      where: { id },
      include: {
        customer: true,
        bomItems: { include: { product: true } },
      },
    });
    if (!spec) throw new NotFoundException('Panel specification not found');
    return spec;
  }

  async create(dto: any, actor?: any) {
    const panelCode = await this.sequenceService.nextPanelCode();

    // Auto calculate BOM costs
    let calculatedMaterialCost = 0;
    const bomItemsData: any[] = [];

    if (Array.isArray(dto.bomItems)) {
      for (const item of dto.bomItems) {
        const qty = Number(item.quantity || 1);
        const unitPrice = Number(item.unitPrice || 0);
        const total = qty * unitPrice;
        calculatedMaterialCost += total;

        bomItemsData.push({
          productId: item.productId,
          componentName: item.componentName,
          specification: item.specification,
          manufacturer: item.manufacturer,
          quantity: qty,
          unitPrice,
          totalPrice: total,
        });
      }
    }

    const materialCost = Number(dto.materialCost) || calculatedMaterialCost;
    const labourCost = Number(dto.labourCost || 10000);
    const overheadCost = Number(dto.overheadCost || 5000);
    const marginPercent = Number(dto.marginPercent || 15);

    // FORMULA: Final Price = (Material + Labour + Overhead) * (1 + Margin / 100)
    const baseCost = materialCost + labourCost + overheadCost;
    const finalPrice = Math.round(baseCost * (1 + marginPercent / 100));

    const created = await this.prisma.panelSpecification.create({
      data: {
        panelCode,
        customerId: dto.customerId,
        panelType: dto.panelType || 'VFD_PANEL',
        voltage: dto.voltage || '415V 3-Phase',
        currentRating: dto.currentRating || '100A',
        pumpQty: Number(dto.pumpQty || 2),
        pumpHp: Number(dto.pumpHp || 7.5),
        controlType: dto.controlType || 'AUTOMATIC_PLC',
        starterType: dto.starterType || 'VFD',
        ipRating: dto.ipRating || 'IP55',
        enclosureType: dto.enclosureType || 'POWDER_COATED_MS',
        materialCost,
        labourCost,
        overheadCost,
        marginPercent,
        finalPrice,
        status: dto.status || 'DRAFT',
        bomItems: {
          create: bomItemsData,
        },
      },
      include: { bomItems: true },
    });

    await this.auditService.recordAction({
      actor,
      action: 'CREATE',
      module: 'PRODUCTION',
      entityType: 'PanelSpecification',
      entityId: created.id,
      after: created,
      details: { panelCode: created.panelCode, finalPrice: created.finalPrice },
    });

    return created;
  }

  /**
   * Export Panel Specification BOM with Centralized Audit Logging
   */
  async exportBom(id: string, format = 'csv', actor?: any, req?: any) {
    const spec = await this.findOne(id);

    await this.auditService.recordAction({
      req,
      actor,
      action: 'EXPORT',
      module: 'PRODUCTION',
      entityType: 'PanelSpecification',
      entityId: id,
      outcome: 'SUCCESS',
      details: {
        format: format.toUpperCase(),
        panelCode: spec.panelCode,
        itemCount: spec.bomItems?.length || 0,
        finalPrice: spec.finalPrice,
      },
    });

    if (format.toLowerCase() === 'json') {
      return {
        format: 'json',
        data: {
          panelCode: spec.panelCode,
          panelType: spec.panelType,
          voltage: spec.voltage,
          currentRating: spec.currentRating,
          status: spec.status,
          finalPrice: spec.finalPrice,
          materialCost: spec.materialCost,
          labourCost: spec.labourCost,
          overheadCost: spec.overheadCost,
          marginPercent: spec.marginPercent,
          bomItems: spec.bomItems,
        },
      };
    }

    const headers = [
      'Item No',
      'Component Name',
      'Specification',
      'Manufacturer',
      'Quantity',
      'Unit Price (INR)',
      'Total Price (INR)',
    ];

    const escapeCsv = (val: any) => {
      if (val === null || val === undefined) return '';
      const str = String(val);
      if (str.includes(',') || str.includes('"') || str.includes('\n')) return `"${str.replace(/"/g, '""')}"`;
      return str;
    };

    const rows = (spec.bomItems || []).map((item, idx) =>
      [
        idx + 1,
        item.componentName,
        item.specification || '',
        item.manufacturer || '',
        item.quantity,
        item.unitPrice,
        item.totalPrice,
      ]
        .map(escapeCsv)
        .join(','),
    );

    const csvContent = [
      `"SAARK EXPLORATION - PANEL BILL OF MATERIALS (BOM) SPECIFICATION"`,
      `"Panel Code: ${spec.panelCode} | Type: ${spec.panelType} | Voltage: ${spec.voltage} | Current: ${spec.currentRating}"`,
      `"Final Configured Price: INR ${spec.finalPrice}"`,
      headers.join(','),
      ...rows,
    ].join('\r\n');

    return {
      format: 'csv',
      csvContent,
      fileName: `saark_panel_bom_${spec.panelCode}.csv`,
    };
  }
}
