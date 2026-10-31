import { Injectable, NotFoundException, ConflictException, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import {
  CreateSaarkProductSectorDto,
  UpdateSaarkProductSectorDto,
  SaarkProductSectorQueryDto,
} from './dto/saark-product-sector.dto';

@Injectable()
export class ProductsService implements OnModuleInit {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async onModuleInit() {
    await this.seedDefaultSectors();
  }

  // ─── SAARK PRODUCT SECTOR & SPECS (38 FIELDS) ──────────────────────────────

  async findSaarkProducts(query?: SaarkProductSectorQueryDto) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) {
      where.status = query.status;
    } else {
      where.status = { not: 'ARCHIVED' };
    }

    if (query?.productSector && query.productSector !== 'All') {
      where.productSector = query.productSector;
    }

    if (query?.productCategory) {
      where.productCategory = query.productCategory;
    }

    if (query?.search && query.search.trim()) {
      const term = query.search.trim();
      where.OR = [
        { productName: { contains: term } },
        { skuModelNumber: { contains: term } },
        { productSector: { contains: term } },
        { productCategory: { contains: term } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.saarkProductSector.findMany({
        where,
        skip,
        take: limit,
        orderBy: { updatedAt: 'desc' },
      }),
      this.prisma.saarkProductSector.count({ where }),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findSaarkProductById(id: string) {
    const product = await this.prisma.saarkProductSector.findUnique({
      where: { id },
    });
    if (!product) {
      throw new NotFoundException(`Product with ID "${id}" not found`);
    }
    return product;
  }

  async findSaarkProductBySku(sku: string) {
    const product = await this.prisma.saarkProductSector.findUnique({
      where: { skuModelNumber: sku },
    });
    if (!product) {
      throw new NotFoundException(`Product with SKU "${sku}" not found`);
    }
    return product;
  }

  async createSaarkProduct(
    dto: CreateSaarkProductSectorDto,
    userId?: string,
    userEmail?: string,
  ) {
    const existing = await this.prisma.saarkProductSector.findUnique({
      where: { skuModelNumber: dto.skuModelNumber },
    });
    if (existing) {
      throw new ConflictException(
        `Product with SKU / Model Number "${dto.skuModelNumber}" already exists`,
      );
    }

    const record = await this.prisma.saarkProductSector.create({
      data: {
        productSector: dto.productSector,
        productName: dto.productName,
        skuModelNumber: dto.skuModelNumber,
        productCategory: dto.productCategory || null,
        shortDescriptionFile: dto.shortDescriptionFile || null,
        detailedDescriptionFile: dto.detailedDescriptionFile || null,
        targetApplicationsFile: dto.targetApplicationsFile || null,
        inputVoltage: dto.inputVoltage || null,
        ratedFrequency: dto.ratedFrequency || null,
        minPowerRating: dto.minPowerRating !== undefined ? Number(dto.minPowerRating) : null,
        maxPowerRating: dto.maxPowerRating !== undefined ? Number(dto.maxPowerRating) : null,
        powerRatingUnit: dto.powerRatingUnit || 'HP',
        starterDriveType: dto.starterDriveType || null,
        enclosureIpRating: dto.enclosureIpRating || null,
        pumpSupportCapacity: dto.pumpSupportCapacity || null,
        controlModes: dto.controlModes || null,
        pressureSensorCompatibility: dto.pressureSensorCompatibility || null,
        minPressure: dto.minPressure !== undefined ? Number(dto.minPressure) : null,
        maxPressure: dto.maxPressure !== undefined ? Number(dto.maxPressure) : null,
        pressureUnit: dto.pressureUnit || 'bar',
        levelSensorInputs: dto.levelSensorInputs || null,
        userInterfaceDisplay: dto.userInterfaceDisplay || null,
        communicationProtocols: dto.communicationProtocols || null,
        iotCloudFeatures: dto.iotCloudFeatures || null,
        dataLogging: dto.dataLogging || null,
        electricalProtections: dto.electricalProtections || null,
        hydraulicProtections: dto.hydraulicProtections || null,
        productImages: dto.productImages || null,
        datasheetManual: dto.datasheetManual || null,
        wiringSld: dto.wiringSld || null,
        certifications: dto.certifications || null,
        promotionalVideo: dto.promotionalVideo || null,
        photoName: dto.photoName || null,
        photoDescription: dto.photoDescription || null,
        photoAttachment: dto.photoAttachment || null,
        settingVideoType: dto.settingVideoType || null,
        settingVideoDetails: dto.settingVideoDetails || null,
        settingVideoAttachment: dto.settingVideoAttachment || null,
        status: dto.status || 'ACTIVE',
        createdByUserId: userId || null,
        createdByUserEmail: userEmail || null,
      },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'CREATE',
      module: 'PRODUCTS',
      entityType: 'SaarkProductSector',
      entityId: record.id,
      details: `Created Saark Product: ${record.productName} (SKU: ${record.skuModelNumber}, Sector: ${record.productSector})`,
    });

    return record;
  }

  async updateSaarkProduct(
    id: string,
    dto: UpdateSaarkProductSectorDto,
    userId?: string,
    userEmail?: string,
  ) {
    const existing = await this.prisma.saarkProductSector.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException(`Product with ID "${id}" not found`);
    }

    if (dto.skuModelNumber && dto.skuModelNumber !== existing.skuModelNumber) {
      const duplicate = await this.prisma.saarkProductSector.findFirst({
        where: { skuModelNumber: dto.skuModelNumber, NOT: { id } },
      });
      if (duplicate) {
        throw new ConflictException(
          `SKU / Model Number "${dto.skuModelNumber}" is already in use by another product`,
        );
      }
    }

    const updateData: any = {};
    const stringFields = [
      'productSector',
      'productName',
      'skuModelNumber',
      'productCategory',
      'shortDescriptionFile',
      'detailedDescriptionFile',
      'targetApplicationsFile',
      'inputVoltage',
      'ratedFrequency',
      'powerRatingUnit',
      'starterDriveType',
      'enclosureIpRating',
      'pumpSupportCapacity',
      'controlModes',
      'pressureSensorCompatibility',
      'pressureUnit',
      'levelSensorInputs',
      'userInterfaceDisplay',
      'communicationProtocols',
      'iotCloudFeatures',
      'dataLogging',
      'electricalProtections',
      'hydraulicProtections',
      'productImages',
      'datasheetManual',
      'wiringSld',
      'certifications',
      'promotionalVideo',
      'photoName',
      'photoDescription',
      'photoAttachment',
      'settingVideoType',
      'settingVideoDetails',
      'settingVideoAttachment',
      'status',
    ];

    stringFields.forEach((field) => {
      if ((dto as any)[field] !== undefined) {
        updateData[field] = (dto as any)[field];
      }
    });

    if (dto.minPowerRating !== undefined) {
      updateData.minPowerRating = dto.minPowerRating !== null ? Number(dto.minPowerRating) : null;
    }
    if (dto.maxPowerRating !== undefined) {
      updateData.maxPowerRating = dto.maxPowerRating !== null ? Number(dto.maxPowerRating) : null;
    }
    if (dto.minPressure !== undefined) {
      updateData.minPressure = dto.minPressure !== null ? Number(dto.minPressure) : null;
    }
    if (dto.maxPressure !== undefined) {
      updateData.maxPressure = dto.maxPressure !== null ? Number(dto.maxPressure) : null;
    }

    const updated = await this.prisma.saarkProductSector.update({
      where: { id },
      data: updateData,
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'UPDATE',
      module: 'PRODUCTS',
      entityType: 'SaarkProductSector',
      entityId: id,
      details: `Updated Saark Product: ${updated.productName} (SKU: ${updated.skuModelNumber})`,
    });

    return updated;
  }

  async deleteSaarkProduct(id: string, userId?: string, userEmail?: string) {
    const existing = await this.prisma.saarkProductSector.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException(`Product with ID "${id}" not found`);
    }

    await this.prisma.saarkProductSector.delete({
      where: { id },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'DELETE',
      module: 'PRODUCTS',
      entityType: 'SaarkProductSector',
      entityId: id,
      details: `Deleted Saark Product: ${existing.productName} (SKU: ${existing.skuModelNumber})`,
    });

    return { success: true, message: `Product "${existing.productName}" deleted successfully` };
  }

  async getSaarkProductStats() {
    const [total, bySector, byCategory] = await Promise.all([
      this.prisma.saarkProductSector.count(),
      this.prisma.saarkProductSector.groupBy({
        by: ['productSector'],
        _count: { _all: true },
      }),
      this.prisma.saarkProductSector.groupBy({
        by: ['productCategory'],
        _count: { _all: true },
      }),
    ]);

    return {
      totalProducts: total,
      sectors: bySector.map((s) => ({ sector: s.productSector, count: s._count._all })),
      categories: byCategory.map((c) => ({ category: c.productCategory || 'Uncategorized', count: c._count._all })),
    };
  }

  // ─── STANDARD PRODUCTS ──────────────────────────────────────────────────────

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

  // ─── SECTORS (Tab 1: Select / Add Sector) ────────────────────────────────

  private async seedDefaultSectors() {
    const defaultSectors = [
      { name: 'Booster Pump Control Panel', code: 'BOOSTER_PUMP' },
      { name: 'STP Panel', code: 'STP_PANEL' },
      { name: 'Water Meter', code: 'WATER_METER' },
      { name: 'BMS', code: 'BMS' },
      { name: 'Other', code: 'OTHER' },
    ];

    for (const item of defaultSectors) {
      try {
        const existing = await this.prisma.productSector.findFirst({
          where: { OR: [{ name: item.name }, { code: item.code }] },
        });
        if (!existing) {
          await this.prisma.productSector.create({
            data: { name: item.name, code: item.code, isActive: true },
          });
        }
      } catch (_) {}
    }
  }

  async getSectors() {
    try {
      const sectors = await this.prisma.productSector.findMany({
        where: { isActive: true },
        orderBy: { name: 'asc' },
      });
      if (!sectors || sectors.length === 0) {
        await this.seedDefaultSectors();
        return this.prisma.productSector.findMany({
          where: { isActive: true },
          orderBy: { name: 'asc' },
        });
      }
      return sectors;
    } catch (e) {
      return [
        { id: '1', code: 'BOOSTER_PUMP', name: 'Booster Pump Control Panel' },
        { id: '2', code: 'STP_PANEL', name: 'STP Panel' },
        { id: '3', code: 'WATER_METER', name: 'Water Meter' },
        { id: '4', code: 'BMS', name: 'BMS' },
        { id: '5', code: 'OTHER', name: 'Other' },
      ];
    }
  }

  async createSector(name: string) {
    if (!name || !name.trim()) throw new ConflictException('Sector name is required');
    const cleanName = name.trim();
    const code = cleanName.toUpperCase().replace(/[^A-Z0-9]/g, '_');

    const existing = await this.prisma.productSector.findFirst({
      where: { OR: [{ name: cleanName }, { code }] },
    });
    if (existing) return existing;

    return this.prisma.productSector.create({
      data: {
        code,
        name: cleanName,
        isActive: true,
      },
    });
  }

  // ─── PROMOTION MATERIALS (Tab 3: Promotion Material Management) ───────────

  async getPromotions(sector?: string) {
    const where: any = {};
    if (sector && sector !== 'All') where.sector = sector;
    return this.prisma.promotionMaterial.findMany({
      where,
      orderBy: { createdAt: 'desc' },
    });
  }

  async createPromotion(dto: any) {
    return this.prisma.promotionMaterial.create({
      data: {
        sector: dto.sector || 'Booster Pump Control Panel',
        title: dto.title || '',
        materialType: dto.materialType || 'YouTube Video',
        campaignName: dto.campaignName || null,
        platform: dto.platform || 'YouTube',
        publishLink: dto.publishLink || dto.url || null,
        attachmentUrl: dto.attachmentUrl || dto.attachment_path || null,
        notes: dto.notes || null,
      },
    });
  }

  async deletePromotion(id: string) {
    await this.prisma.promotionMaterial.delete({
      where: { id },
    });
    return { success: true, message: 'Promotion material deleted' };
  }
}
