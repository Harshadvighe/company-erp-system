import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';

@Injectable()
export class InventoryService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. INVENTORY SUMMARY & KPI OVERVIEW
  // ─────────────────────────────────────────────────────────────────────────────

  async getInventorySummary() {
    const [warehouses, products, stockItems, recentTransactions] = await Promise.all([
      this.prisma.warehouse.findMany({ where: { status: 'ACTIVE' } }),
      this.prisma.product.findMany({
        where: { status: 'ACTIVE' },
        include: { unit: true, category: true },
      }),
      this.prisma.stockItem.findMany({
        include: { product: true, warehouse: true },
      }),
      this.prisma.stockTransaction.findMany({
        take: 10,
        orderBy: { transactionDate: 'desc' },
        include: {
          product: { select: { sku: true, name: true, unit: true } },
          warehouse: { select: { code: true, name: true } },
        },
      }),
    ]);

    let totalValuation = 0;
    let totalStockUnits = 0;
    let lowStockCount = 0;

    // Evaluate stock health per product
    const lowStockItems: any[] = [];

    products.forEach((p) => {
      const current = p.currentStock || 0;
      const unitCost = p.purchasePrice || 0;
      totalValuation += current * unitCost;
      totalStockUnits += current;

      if (current <= p.reorderLevel) {
        lowStockCount++;
        lowStockItems.push({
          id: p.id,
          sku: p.sku,
          name: p.name,
          category: p.category?.name,
          currentStock: current,
          reorderLevel: p.reorderLevel,
          unit: p.unit?.name || 'Nos',
          unitCost: p.purchasePrice,
          deficit: p.reorderLevel - current,
        });
      }
    });

    return {
      totalProducts: products.length,
      totalWarehouses: warehouses.length,
      totalStockUnits,
      totalValuation,
      lowStockCount,
      lowStockItems,
      recentTransactions,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. WAREHOUSES MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────────

  async getWarehouses() {
    const warehouses = await this.prisma.warehouse.findMany({
      include: {
        stockItems: {
          include: { product: true },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    return warehouses.map((wh) => {
      let totalUnits = 0;
      let totalValuation = 0;
      const uniqueSkus = wh.stockItems.length;

      wh.stockItems.forEach((si) => {
        totalUnits += si.currentQuantity;
        totalValuation += si.currentQuantity * (si.product?.purchasePrice || 0);
      });

      return {
        id: wh.id,
        code: wh.code,
        name: wh.name,
        location: wh.location,
        status: wh.status,
        uniqueSkus,
        totalUnits,
        totalValuation,
        createdAt: wh.createdAt,
      };
    });
  }

  async createWarehouse(dto: { code: string; name: string; location: string }) {
    const existing = await this.prisma.warehouse.findUnique({
      where: { code: dto.code.trim().toUpperCase() },
    });

    if (existing) {
      throw new BadRequestException(`Warehouse with code "${dto.code}" already exists`);
    }

    return this.prisma.warehouse.create({
      data: {
        code: dto.code.trim().toUpperCase(),
        name: dto.name.trim(),
        location: dto.location.trim(),
        status: 'ACTIVE',
      },
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. STOCK ITEMS & INVENTORY LEDGER
  // ─────────────────────────────────────────────────────────────────────────────

  async getStockItems(query: {
    warehouseId?: string;
    categoryId?: string;
    lowStockOnly?: boolean;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Math.max(1, Number(query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(query.limit) || 50));
    const skip = (page - 1) * limit;

    const where: any = {
      status: 'ACTIVE',
    };

    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }

    if (query.search && query.search.trim()) {
      const s = query.search.trim();
      where.OR = [
        { name: { contains: s, mode: 'insensitive' } },
        { sku: { contains: s, mode: 'insensitive' } },
        { hsnSac: { contains: s, mode: 'insensitive' } },
      ];
    }

    // Fetch matching products
    const [products, totalCount] = await Promise.all([
      this.prisma.product.findMany({
        where,
        include: {
          unit: true,
          category: true,
          stockItems: {
            where: query.warehouseId ? { warehouseId: query.warehouseId } : undefined,
            include: { warehouse: true },
          },
        },
        skip,
        take: limit,
        orderBy: { name: 'asc' },
      }),
      this.prisma.product.count({ where }),
    ]);

    let items = products.map((p) => {
      let warehouseQty = 0;
      let reservedQty = 0;

      if (query.warehouseId) {
        const si = p.stockItems.find((s) => s.warehouseId === query.warehouseId);
        warehouseQty = si ? si.currentQuantity : 0;
        reservedQty = si ? si.reservedQuantity : 0;
      } else {
        warehouseQty = p.currentStock || 0;
        reservedQty = p.stockItems.reduce((acc, curr) => acc + curr.reservedQuantity, 0);
      }

      const availableQty = Math.max(0, warehouseQty - reservedQty);
      const isLowStock = warehouseQty <= p.reorderLevel;
      const valuation = warehouseQty * (p.purchasePrice || 0);

      return {
        id: p.id,
        sku: p.sku,
        name: p.name,
        productType: p.productType,
        category: p.category?.name || 'General',
        categoryId: p.categoryId,
        unit: p.unit?.name || 'Nos',
        hsnSac: p.hsnSac,
        purchasePrice: p.purchasePrice,
        sellingPrice: p.sellingPrice,
        currentStock: warehouseQty,
        reservedStock: reservedQty,
        availableStock: availableQty,
        reorderLevel: p.reorderLevel,
        isLowStock,
        valuation,
        warehouses: p.stockItems.map((si) => ({
          warehouseId: si.warehouseId,
          warehouseCode: si.warehouse?.code,
          warehouseName: si.warehouse?.name,
          quantity: si.currentQuantity,
          reserved: si.reservedQuantity,
        })),
      };
    });

    if (query.lowStockOnly) {
      items = items.filter((item) => item.isLowStock);
    }

    return {
      items,
      totalCount: query.lowStockOnly ? items.length : totalCount,
      page,
      limit,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. MANUAL STOCK ADJUSTMENT (RECONCILIATION / DAMAGE / CORRECTION)
  // ─────────────────────────────────────────────────────────────────────────────

  async adjustStock(
    dto: {
      productId: string;
      warehouseId: string;
      quantity: number;
      adjustmentType: 'INCREASE' | 'DECREASE' | 'CORRECTION';
      reason?: string;
      notes?: string;
    },
    userId?: string,
  ) {
    const product = await this.prisma.product.findUnique({
      where: { id: dto.productId },
      include: { unit: true },
    });
    if (!product) throw new NotFoundException('Product not found');

    const warehouse = await this.prisma.warehouse.findUnique({
      where: { id: dto.warehouseId },
    });
    if (!warehouse) throw new NotFoundException('Warehouse not found');

    const qty = Number(dto.quantity) || 0;
    if (qty <= 0) throw new BadRequestException('Adjustment quantity must be greater than 0');

    // Fetch existing StockItem
    let stockItem = await this.prisma.stockItem.findUnique({
      where: {
        warehouseId_productId: {
          warehouseId: dto.warehouseId,
          productId: dto.productId,
        },
      },
    });

    let delta = 0;
    let newQty = stockItem ? stockItem.currentQuantity : 0;

    if (dto.adjustmentType === 'INCREASE') {
      delta = qty;
      newQty += delta;
    } else if (dto.adjustmentType === 'DECREASE') {
      delta = -qty;
      newQty = Math.max(0, newQty + delta);
    } else if (dto.adjustmentType === 'CORRECTION') {
      delta = qty - newQty;
      newQty = qty;
    }

    // 1. Upsert StockItem
    stockItem = await this.prisma.stockItem.upsert({
      where: {
        warehouseId_productId: {
          warehouseId: dto.warehouseId,
          productId: dto.productId,
        },
      },
      update: {
        currentQuantity: newQty,
      },
      create: {
        warehouseId: dto.warehouseId,
        productId: dto.productId,
        currentQuantity: newQty,
        reservedQuantity: 0,
      },
    });

    // 2. Re-compute total Product.currentStock across all warehouses
    const allStockItems = await this.prisma.stockItem.findMany({
      where: { productId: dto.productId },
    });
    const totalCurrentStock = allStockItems.reduce((sum, item) => sum + item.currentQuantity, 0);

    await this.prisma.product.update({
      where: { id: dto.productId },
      data: { currentStock: totalCurrentStock },
    });

    // 3. Log StockTransaction
    const transaction = await this.prisma.stockTransaction.create({
      data: {
        productId: dto.productId,
        warehouseId: dto.warehouseId,
        transactionType: 'ADJUSTMENT',
        referenceType: 'MANUAL',
        quantity: delta,
        unit: product.unit?.name || 'Nos',
        unitCost: product.purchasePrice || 0,
        totalCost: Math.abs(delta) * (product.purchasePrice || 0),
        transactionDate: new Date(),
        userId,
        notes: dto.notes ? `${dto.adjustmentType} [${dto.reason || 'Reconciliation'}]: ${dto.notes}` : `${dto.adjustmentType} [${dto.reason || 'Reconciliation'}]`,
      },
    });

    return {
      success: true,
      newQuantity: newQty,
      delta,
      productName: product.name,
      warehouseName: warehouse.name,
      transactionId: transaction.id,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. INTER-WAREHOUSE STOCK TRANSFER
  // ─────────────────────────────────────────────────────────────────────────────

  async transferStock(
    dto: {
      productId: string;
      fromWarehouseId: string;
      toWarehouseId: string;
      quantity: number;
      notes?: string;
    },
    userId?: string,
  ) {
    if (dto.fromWarehouseId === dto.toWarehouseId) {
      throw new BadRequestException('Source and destination warehouse cannot be the same');
    }

    const qty = Number(dto.quantity) || 0;
    if (qty <= 0) throw new BadRequestException('Transfer quantity must be greater than 0');

    const product = await this.prisma.product.findUnique({
      where: { id: dto.productId },
      include: { unit: true },
    });
    if (!product) throw new NotFoundException('Product not found');

    const [fromWh, toWh] = await Promise.all([
      this.prisma.warehouse.findUnique({ where: { id: dto.fromWarehouseId } }),
      this.prisma.warehouse.findUnique({ where: { id: dto.toWarehouseId } }),
    ]);

    if (!fromWh || !toWh) throw new NotFoundException('One or both warehouses not found');

    // Check source warehouse available stock
    const sourceStockItem = await this.prisma.stockItem.findUnique({
      where: {
        warehouseId_productId: {
          warehouseId: dto.fromWarehouseId,
          productId: dto.productId,
        },
      },
    });

    const currentSourceQty = sourceStockItem?.currentQuantity || 0;
    const reservedSourceQty = sourceStockItem?.reservedQuantity || 0;
    const availableSourceQty = Math.max(0, currentSourceQty - reservedSourceQty);

    if (availableSourceQty < qty) {
      throw new BadRequestException(
        `Insufficient stock in ${fromWh.name}. Available: ${availableSourceQty} ${product.unit?.name || 'units'}, Requested: ${qty}`,
      );
    }

    // Deduct from Source
    await this.prisma.stockItem.update({
      where: {
        warehouseId_productId: {
          warehouseId: dto.fromWarehouseId,
          productId: dto.productId,
        },
      },
      data: {
        currentQuantity: currentSourceQty - qty,
      },
    });

    // Add to Destination
    await this.prisma.stockItem.upsert({
      where: {
        warehouseId_productId: {
          warehouseId: dto.toWarehouseId,
          productId: dto.productId,
        },
      },
      update: {
        currentQuantity: { increment: qty },
      },
      create: {
        warehouseId: dto.toWarehouseId,
        productId: dto.productId,
        currentQuantity: qty,
        reservedQuantity: 0,
      },
    });

    // Record Stock Transactions (Outward & Inward)
    const unitCost = product.purchasePrice || 0;
    const totalCost = qty * unitCost;

    await this.prisma.stockTransaction.createMany({
      data: [
        {
          productId: dto.productId,
          warehouseId: dto.fromWarehouseId,
          transactionType: 'TRANSFER_OUT',
          referenceType: 'MANUAL',
          quantity: -qty,
          unit: product.unit?.name || 'Nos',
          unitCost,
          totalCost,
          transactionDate: new Date(),
          userId,
          notes: `Transferred to ${toWh.name} (${toWh.code}). ${dto.notes || ''}`,
        },
        {
          productId: dto.productId,
          warehouseId: dto.toWarehouseId,
          transactionType: 'TRANSFER_IN',
          referenceType: 'MANUAL',
          quantity: qty,
          unit: product.unit?.name || 'Nos',
          unitCost,
          totalCost,
          transactionDate: new Date(),
          userId,
          notes: `Received from ${fromWh.name} (${fromWh.code}). ${dto.notes || ''}`,
        },
      ],
    });

    return {
      success: true,
      message: `Successfully transferred ${qty} ${product.unit?.name || 'units'} from ${fromWh.name} to ${toWh.name}`,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. STOCK TRANSACTIONS / MOVEMENT AUDIT TRAIL
  // ─────────────────────────────────────────────────────────────────────────────

  async getTransactions(query: {
    productId?: string;
    warehouseId?: string;
    transactionType?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Math.max(1, Number(query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(query.limit) || 50));
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query.productId) where.productId = query.productId;
    if (query.warehouseId) where.warehouseId = query.warehouseId;
    if (query.transactionType) where.transactionType = query.transactionType;

    const [transactions, totalCount] = await Promise.all([
      this.prisma.stockTransaction.findMany({
        where,
        include: {
          product: { select: { sku: true, name: true, unit: true } },
          warehouse: { select: { code: true, name: true } },
        },
        skip,
        take: limit,
        orderBy: { transactionDate: 'desc' },
      }),
      this.prisma.stockTransaction.count({ where }),
    ]);

    return {
      transactions,
      totalCount,
      page,
      limit,
    };
  }
}
