import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';

@Injectable()
export class PanelManufacturingService {
  constructor(private readonly prisma: PrismaService) {}

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

  async create(dto: any) {
    const count = await this.prisma.panelSpecification.count();
    const panelCode = `PANEL-2026-${String(count + 1).padStart(4, '0')}`;

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

    return this.prisma.panelSpecification.create({
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
  }
}
