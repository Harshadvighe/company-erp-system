import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Injectable()
export class ProductsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  // ─── PRODUCTS ──────────────────────────────────────────────────────────────

  async findAll(query?: {
    search?: string;
    categoryId?: string;
    type?: string;
    status?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.categoryId) where.categoryId = query.categoryId;
    if (query?.type) where.productType = query.type;
    if (query?.search) {
      where.OR = [
        { name: { contains: query.search } },
        { sku: { contains: query.search } },
        { hsnSac: { contains: query.search } },
        { description: { contains: query.search } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        skip,
        take: limit,
        include: { category: true, unit: true, taxRate: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.product.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async findOne(id: string) {
    const product = await this.prisma.product.findUnique({
      where: { id },
      include: {
        category: true,
        unit: true,
        taxRate: true,
        stockItems: { include: { warehouse: true } },
      },
    });
    if (!product) throw new NotFoundException(`Product ${id} not found`);
    return product;
  }

  async create(dto: any, userId?: string, userEmail?: string) {
    if (dto.sku) {
      const exists = await this.prisma.product.findUnique({ where: { sku: dto.sku } });
      if (exists) throw new ConflictException(`Product with SKU ${dto.sku} already exists`);
    }

    const product = await this.prisma.product.create({
      data: {
        sku: dto.sku,
        name: dto.name,
        categoryId: dto.categoryId,
        productType: dto.productType || 'FINISHED_PRODUCT',
        description: dto.description,
        unitId: dto.unitId,
        taxRateId: dto.taxRateId,
        hsnSac: dto.hsnSac,
        purchasePrice: Number(dto.purchasePrice || 0),
        sellingPrice: Number(dto.sellingPrice || 0),
        minSellingPrice: Number(dto.minSellingPrice || 0),
        reorderLevel: Number(dto.reorderLevel || 10),
        openingStock: Number(dto.openingStock || 0),
        currentStock: Number(dto.openingStock || 0),
        status: 'ACTIVE',
      },
      include: { category: true, unit: true, taxRate: true },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'CREATE',
      module: 'PRODUCTS',
      entityType: 'Product',
      entityId: product.id,
      details: `Created Product: ${product.name} (SKU: ${product.sku})`,
    });

    return product;
  }

  async update(id: string, dto: any, userId?: string, userEmail?: string) {
    const existing = await this.prisma.product.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Product not found');

    if (dto.sku && dto.sku !== existing.sku) {
      const dup = await this.prisma.product.findFirst({
        where: { sku: dto.sku, NOT: { id } },
      });
      if (dup) throw new ConflictException(`SKU ${dto.sku} already in use`);
    }

    const fields = [
      'sku', 'name', 'categoryId', 'productType', 'description', 'unitId',
      'taxRateId', 'hsnSac', 'purchasePrice', 'sellingPrice', 'minSellingPrice',
      'reorderLevel', 'imageUrl', 'status',
    ];
    const updateData: any = {};
    fields.forEach((f) => { if (dto[f] !== undefined) updateData[f] = dto[f]; });
    if (dto.purchasePrice !== undefined) updateData.purchasePrice = Number(dto.purchasePrice);
    if (dto.sellingPrice !== undefined) updateData.sellingPrice = Number(dto.sellingPrice);
    if (dto.minSellingPrice !== undefined) updateData.minSellingPrice = Number(dto.minSellingPrice);

    const product = await this.prisma.product.update({
      where: { id },
      data: updateData,
      include: { category: true, unit: true, taxRate: true },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'UPDATE',
      module: 'PRODUCTS',
      entityType: 'Product',
      entityId: id,
      details: `Updated Product: ${product.name}`,
    });

    return product;
  }

  async delete(id: string, userId?: string, userEmail?: string) {
    const existing = await this.prisma.product.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Product not found');

    await this.prisma.product.update({ where: { id }, data: { status: 'DELETED' } });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'DELETE',
      module: 'PRODUCTS',
      entityType: 'Product',
      entityId: id,
      details: `Soft-deleted Product: ${existing.name}`,
    });

    return { message: 'Product marked as deleted' };
  }

  // ─── CATEGORIES ──────────────────────────────────────────────────────────

  async getCategories() {
    return this.prisma.productCategory.findMany({
      include: { _count: { select: { products: true } } },
      orderBy: { name: 'asc' },
    });
  }

  async createCategory(dto: { name: string; code: string }) {
    const exists = await this.prisma.productCategory.findFirst({
      where: { OR: [{ name: dto.name }, { code: dto.code }] },
    });
    if (exists) throw new ConflictException('Category name or code already exists');
    return this.prisma.productCategory.create({ data: dto });
  }

  async updateCategory(id: string, dto: any) {
    return this.prisma.productCategory.update({ where: { id }, data: dto });
  }

  // ─── UNITS ───────────────────────────────────────────────────────────────

  async getUnits() {
    return this.prisma.unit.findMany({ orderBy: { name: 'asc' } });
  }

  async createUnit(dto: { name: string; code: string }) {
    const exists = await this.prisma.unit.findFirst({
      where: { OR: [{ name: dto.name }, { code: dto.code }] },
    });
    if (exists) throw new ConflictException('Unit name or code already exists');
    return this.prisma.unit.create({ data: dto });
  }
}
