import {
  Injectable,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import {
  FindMaterialsQueryDto,
  CreateMaterialDto,
  UpdateMaterialDto,
} from './dto/materials.dto';

@Injectable()
export class MaterialsService {
  private readonly logger = new Logger(MaterialsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  /**
   * Helper to strip internal purchase pricing when user lacks permission
   */
  private redactInternalPricing<T extends Record<string, any>>(
    item: T,
    canViewInternal: boolean,
  ): T {
    if (canViewInternal) return item;
    const sanitized = { ...item };
    delete (sanitized as any).purchasePrice;
    delete (sanitized as any).dealerPrice;
    delete (sanitized as any).dpDiscount;
    return sanitized;
  }

  /**
   * List material master records with search, filtering, sorting, pagination, and RBAC pricing redaction
   */
  async findAll(query: FindMaterialsQueryDto, canViewInternalPricing = false) {
    const page = Math.max(1, Number(query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(query.limit) || 25));
    const skip = (page - 1) * limit;

    const where: any = {};

    // Status filter (default ACTIVE)
    if (query.status && query.status.toUpperCase() !== 'ALL') {
      where.status = query.status.toUpperCase();
    } else if (!query.status) {
      where.status = { not: 'DELETED' };
    }

    // Category filter
    if (query.category) {
      where.OR = where.OR || [];
      where.category = {
        OR: [
          { id: query.category },
          { name: { contains: query.category } },
          { code: { contains: query.category } },
        ],
      };
    }

    // Make filter
    if (query.make) {
      where.make = { contains: query.make };
    }

    // Global Search across SKU, Item Name, Make, Subcategories, Supplier, Capacity, HSN
    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      where.OR = [
        { sku: { contains: s } },
        { name: { contains: s } },
        { make: { contains: s } },
        { subCategory1: { contains: s } },
        { subCategory2: { contains: s } },
        { subCategory3: { contains: s } },
        { subCategory4: { contains: s } },
        { capacity: { contains: s } },
        { supplier: { contains: s } },
        { hsnSac: { contains: s } },
        { category: { name: { contains: s } } },
      ];
    }

    // Sorting
    const orderBy: any = {};
    const sortField = query.sortBy || 'name';
    const sortOrder = query.sortOrder === 'desc' ? 'desc' : 'asc';

    if (sortField === 'category') {
      orderBy.category = { name: sortOrder };
    } else {
      orderBy[sortField] = sortOrder;
    }

    const [rawItems, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        skip,
        take: limit,
        include: {
          category: { select: { id: true, name: true, code: true } },
          unit: { select: { id: true, name: true, code: true } },
        },
        orderBy,
      }),
      this.prisma.product.count({ where }),
    ]);

    const data = rawItems.map((item) =>
      this.redactInternalPricing(item, canViewInternalPricing),
    );

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        canViewInternalPricing,
      },
    };
  }

  /**
   * Find single material by ID or SKU with RBAC pricing redaction
   */
  async findOne(idOrSku: string, canViewInternalPricing = false) {
    const material = await this.prisma.product.findFirst({
      where: {
        OR: [{ id: idOrSku }, { sku: idOrSku }],
      },
      include: {
        category: true,
        unit: true,
        taxRate: true,
      },
    });

    if (!material) {
      throw new NotFoundException(`Material record "${idOrSku}" not found`);
    }

    return this.redactInternalPricing(material, canViewInternalPricing);
  }

  /**
   * Create a new material record
   */
  async create(dto: CreateMaterialDto, userId?: string, userEmail?: string, actor?: any) {
    const normalizedSku = dto.sku.trim().replace(/\.0+$/, '');
    const existing = await this.prisma.product.findUnique({
      where: { sku: normalizedSku },
    });
    if (existing) {
      throw new ConflictException(`Material with SKU "${normalizedSku}" already exists`);
    }

    // Resolve Category
    let categoryId = dto.categoryId;
    if (!categoryId) {
      const catName = (dto.category || 'General').trim();
      let cat = await this.prisma.productCategory.findFirst({
        where: { name: { equals: catName } },
      });
      if (!cat) {
        const catCode = catName.toUpperCase().replace(/[^A-Z0-9]/g, '_').slice(0, 20) || 'CAT';
        cat = await this.prisma.productCategory.create({
          data: { name: catName, code: `${catCode}_${Date.now().toString().slice(-4)}` },
        });
      }
      categoryId = cat.id;
    }

    // Resolve Unit
    let unitId = dto.unitId;
    if (!unitId) {
      const uName = (dto.unit || 'Nos').trim();
      let u = await this.prisma.unit.findFirst({
        where: { name: { equals: uName } },
      });
      if (!u) {
        const uCode = uName.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10) || 'NOS';
        u = await this.prisma.unit.create({
          data: { name: uName, code: `${uCode}_${Date.now().toString().slice(-4)}` },
        });
      }
      unitId = u.id;
    }

    const material = await this.prisma.product.create({
      data: {
        sku: normalizedSku,
        name: dto.name.trim(),
        categoryId,
        unitId,
        productType: 'RAW_MATERIAL',
        make: dto.make?.trim() || null,
        subCategory1: dto.subCategory1?.trim() || null,
        subCategory2: dto.subCategory2?.trim() || null,
        subCategory3: dto.subCategory3?.trim() || null,
        subCategory4: dto.subCategory4?.trim() || null,
        subCategory5: dto.subCategory5?.trim() || null,
        subCategory6: dto.subCategory6?.trim() || null,
        subCategory7: dto.subCategory7?.trim() || null,
        subCategory8: dto.subCategory8?.trim() || null,
        subCategory9: dto.subCategory9?.trim() || null,
        subCategory10: dto.subCategory10?.trim() || null,
        capacity: dto.capacity?.trim() || null,
        supplier: dto.supplier?.trim() || null,
        listPrice: dto.listPrice !== undefined ? Number(dto.listPrice) : null,
        dpDiscount: dto.dpDiscount !== undefined ? Number(dto.dpDiscount) : null,
        dealerPrice: dto.dealerPrice !== undefined ? Number(dto.dealerPrice) : null,
        lpDiscount: dto.lpDiscount !== undefined ? Number(dto.lpDiscount) : null,
        landingPrice: dto.landingPrice !== undefined ? Number(dto.landingPrice) : null,
        purchasePrice: dto.dealerPrice !== undefined ? Number(dto.dealerPrice) : 0,
        sellingPrice: dto.landingPrice !== undefined ? Number(dto.landingPrice) : (dto.listPrice !== undefined ? Number(dto.listPrice) : 0),
        hsnSac: dto.hsnSac?.trim() || null,
        specifications: dto.specifications || null,
        status: 'ACTIVE',
      },
      include: { category: true, unit: true },
    });

    await this.auditService.recordAction({
      actor: actor || { id: userId, email: userEmail },
      userId,
      userEmail,
      action: 'CREATE',
      module: 'MATERIALS',
      entityType: 'Product',
      entityId: material.id,
      after: material,
      details: { sku: material.sku, name: material.name },
    });

    return material;
  }

  /**
   * Update an existing material record
   */
  async update(id: string, dto: UpdateMaterialDto, userId?: string, userEmail?: string, actor?: any) {
    const existing = await this.prisma.product.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException(`Material record "${id}" not found`);
    }

    if (dto.sku && dto.sku.trim() !== existing.sku) {
      const normSku = dto.sku.trim().replace(/\.0+$/, '');
      const duplicate = await this.prisma.product.findFirst({
        where: { sku: normSku, NOT: { id } },
      });
      if (duplicate) {
        throw new ConflictException(`SKU "${normSku}" is already in use by another material`);
      }
    }

    const updateData: any = {};
    const textFields = [
      'name', 'make', 'subCategory1', 'subCategory2', 'subCategory3',
      'subCategory4', 'subCategory5', 'subCategory6', 'subCategory7',
      'subCategory8', 'subCategory9', 'subCategory10', 'capacity',
      'supplier', 'hsnSac', 'status', 'specifications',
    ];
    textFields.forEach((f) => {
      if ((dto as any)[f] !== undefined) updateData[f] = (dto as any)[f];
    });

    if (dto.sku) updateData.sku = dto.sku.trim().replace(/\.0+$/, '');
    if (dto.categoryId) updateData.categoryId = dto.categoryId;
    if (dto.unitId) updateData.unitId = dto.unitId;

    if (dto.listPrice !== undefined) updateData.listPrice = Number(dto.listPrice);
    if (dto.dpDiscount !== undefined) updateData.dpDiscount = Number(dto.dpDiscount);
    if (dto.dealerPrice !== undefined) {
      updateData.dealerPrice = Number(dto.dealerPrice);
      updateData.purchasePrice = Number(dto.dealerPrice);
    }
    if (dto.lpDiscount !== undefined) updateData.lpDiscount = Number(dto.lpDiscount);
    if (dto.landingPrice !== undefined) {
      updateData.landingPrice = Number(dto.landingPrice);
      updateData.sellingPrice = Number(dto.landingPrice);
    }

    const updated = await this.prisma.product.update({
      where: { id },
      data: updateData,
      include: { category: true, unit: true },
    });

    await this.auditService.recordAction({
      actor: actor || { id: userId, email: userEmail },
      userId,
      userEmail,
      action: 'UPDATE',
      module: 'MATERIALS',
      entityType: 'Product',
      entityId: id,
      before: existing,
      after: updated,
      details: { sku: updated.sku, name: updated.name },
    });

    return updated;
  }

  /**
   * Soft-delete material record
   */
  async delete(id: string, userId?: string, userEmail?: string, actor?: any) {
    const existing = await this.prisma.product.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException(`Material record "${id}" not found`);
    }

    const updated = await this.prisma.product.update({
      where: { id },
      data: { status: 'DELETED' },
    });

    await this.auditService.recordAction({
      actor: actor || { id: userId, email: userEmail },
      userId,
      userEmail,
      action: 'DELETE',
      module: 'MATERIALS',
      entityType: 'Product',
      entityId: id,
      before: existing,
      after: updated,
      details: { sku: existing.sku, name: existing.name },
    });

    return { message: `Material ${existing.sku} marked as deleted` };
  }

  /**
   * Categories list for filter chips / dropdowns
   */
  async getCategories() {
    return this.prisma.productCategory.findMany({
      include: { _count: { select: { products: true } } },
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Distinct makes for filter chips / dropdowns
   */
  async getMakes() {
    const products = await this.prisma.product.findMany({
      where: { make: { not: null }, status: { not: 'DELETED' } },
      select: { make: true },
      distinct: ['make'],
    });

    return products
      .map((p) => p.make)
      .filter((m): m is string => Boolean(m && m.trim().length > 0))
      .sort();
  }

  /**
   * Summary metrics for Material Master dashboard/header
   */
  async getStats(canViewInternalPricing = false) {
    const [totalMaterials, activeMaterials, categoriesCount, makesCount] = await Promise.all([
      this.prisma.product.count({ where: { status: { not: 'DELETED' } } }),
      this.prisma.product.count({ where: { status: 'ACTIVE' } }),
      this.prisma.productCategory.count(),
      this.prisma.product.findMany({
        where: { make: { not: null }, status: { not: 'DELETED' } },
        select: { make: true },
        distinct: ['make'],
      }).then((res) => res.length),
    ]);

    return {
      totalMaterials,
      activeMaterials,
      categoriesCount,
      makesCount,
      canViewInternalPricing,
    };
  }
}
