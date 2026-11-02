import { Injectable, OnModuleInit, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { PrismaService } from '../../core/database/prisma.service';
import { CreateB2bProductDto, UpdateB2bProductDto, CalculateB2bFinancialsDto } from './b2b-trading.dto';

@Injectable()
export class B2bTradingService implements OnModuleInit {
  private readonly logger = new Logger(B2bTradingService.name);

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit() {
    // Non-blocking deferred seed so bootstrap never fails or blocks on connection pool
    setTimeout(async () => {
      try {
        await this.seedDefaultsIfEmpty();
      } catch (err: any) {
        this.logger.warn(`B2bTrading default seed skipped/deferred: ${err?.message || err}`);
      }
    }, 4000);
  }

  // ─── FINANCIALS & MARGIN CALCULATIONS ───────────────────────
  calculateFinancials(dto: CalculateB2bFinancialsDto) {
    const baseCost = Number(dto.baseCost) || 0;
    const brandingFee = Number(dto.brandingFee) || 0;
    const packagingCost = Number(dto.packagingFee ?? dto.sampleShipping) || 0;
    const freightPerUnit = Number(dto.freightPerUnit) || 0;
    const customsDutyPct = Number(dto.customsDutyPct) || 0;
    const customsDutyAmount = (baseCost * customsDutyPct) / 100.0;
    const qualityInspection = Number(dto.qualityInspectionPerUnit) || 0;
    let retailPrice = Number(dto.retailPrice) || 0;
    const targetMargin = Number(dto.targetMarginPct);

    // Domestic & White-Label Landed Cost Formula:
    // Landed_Cost = Base_Cost + Branding_Fee + Packaging_Cost + Freight_Per_Unit + Customs_Duty + Inspection
    let landedCost = Number(
      (baseCost + brandingFee + packagingCost + freightPerUnit + customsDutyAmount + qualityInspection).toFixed(2),
    );

    // Optional International Import Customs & Duty Formula:
    if (dto.exchangeRate && dto.exchangeRate > 0) {
      const procurementInr = baseCost * dto.exchangeRate;
      const freightInr = freightPerUnit * dto.exchangeRate;
      const portChargesInr = Number(dto.portChargesInr) || 0;
      const cifBase = procurementInr + freightInr + portChargesInr;

      const bcdRate = Number(dto.bcdRate) || 7.5;
      const swsRate = Number(dto.swsRate) || 10.0;
      const igstRate = Number(dto.igstRate) || 18.0;

      const bcdAmount = (cifBase * bcdRate) / 100.0;
      const swsAmount = ((cifBase + bcdAmount) * swsRate) / 100.0;
      const igstAmount = ((cifBase + bcdAmount + swsAmount) * igstRate) / 100.0;

      landedCost = Number(
        (cifBase + bcdAmount + swsAmount + igstAmount + brandingFee + packagingCost).toFixed(2),
      );
    }

    // Target Price from Target Margin:
    // Retail_Price = Landed_Cost / (1 - (Target_Margin_Percentage / 100))
    if (!isNaN(targetMargin) && targetMargin > 0 && targetMargin < 100 && retailPrice === 0) {
      retailPrice = Number((landedCost / (1 - targetMargin / 100.0)).toFixed(2));
    }

    // Gross Profit Margin Percentage (%):
    // Margin_Percentage = ((Retail_Price - Landed_Cost) / Retail_Price) * 100
    let marginPct = 0;
    if (retailPrice > 0) {
      marginPct = Number((((retailPrice - landedCost) / retailPrice) * 100.0).toFixed(2));
    }

    const grossProfit = Number((retailPrice - landedCost).toFixed(2));

    return {
      baseCost,
      brandingFee,
      packagingCost,
      freightPerUnit,
      landedCost,
      retailPrice,
      marginPct,
      grossProfit,
      currency: 'INR',
      displayLandedCost: `Rs.${landedCost.toFixed(2)}`,
      displayMargin: `${marginPct.toFixed(2)}%`,
    };
  }

  // ─── PRODUCTS CRUD ──────────────────────────────────────────
  async getProducts(params?: { status?: string; search?: string; category?: string }) {
    const where: any = {};
    if (params?.status && params.status !== 'ALL') {
      where.status = params.status;
    }
    if (params?.category) {
      where.primaryCategory = params.category;
    }
    if (params?.search) {
      const q = params.search.toLowerCase();
      where.OR = [
        { rebrandedName: { contains: q } },
        { rebrandedModel: { contains: q } },
        { originalName: { contains: q } },
        { originalModel: { contains: q } },
        { id: { contains: q } },
      ];
    }

    return this.prisma.b2bProduct.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        supplier: true,
        variants: true,
        documents: true,
      },
    });
  }

  async getPublishedProducts(search?: string) {
    return this.getProducts({ status: 'published', search });
  }

  async getProductById(id: string) {
    const prod = await this.prisma.b2bProduct.findUnique({
      where: { id },
      include: {
        supplier: true,
        variants: true,
        documents: true,
      },
    });
    if (!prod) {
      throw new NotFoundException(`B2B Product with ID ${id} not found`);
    }
    return prod;
  }

  async createProduct(dto: CreateB2bProductDto) {
    const id = dto.id?.trim() || this.generateTimestampId();
    const financials = this.calculateFinancials({
      baseCost: dto.baseCost || 0,
      brandingFee: dto.brandingFee || 0,
      sampleShipping: dto.sampleShipping || 0,
      freightPerUnit: dto.freightPerUnit || 0,
      retailPrice: dto.retailPrice || 0,
    });

    const product = await this.prisma.b2bProduct.create({
      data: {
        id,
        primaryCategory: dto.primaryCategory || 'Domestic',
        subCategory: dto.subCategory,
        internalTag: dto.internalTag,
        originalName: dto.originalName,
        originalModel: dto.originalModel,
        rebrandedName: dto.rebrandedName,
        rebrandedModel: dto.rebrandedModel,
        collection: dto.collection,
        description: dto.description,
        supplierId: dto.supplierId,
        moq: Number(dto.moq || 1),
        sampleCost: Number(dto.sampleCost || 0),
        leadTime: Number(dto.leadTime || 0),
        rating: Number(dto.rating || 5.0),
        material: dto.material,
        dimensions: dto.dimensions,
        weight: dto.weight ? Number(dto.weight) : null,
        hsCode: dto.hsCode,
        logoPath: dto.logoPath,
        insertCardPath: dto.insertCardPath,
        pkgDims: dto.pkgDims,
        printingSpecs: dto.printingSpecs,
        barcodePlacement: dto.barcodePlacement,
        brandCopy: dto.brandCopy,
        seoTitle: dto.seoTitle,
        seoMeta: dto.seoMeta,
        baseCost: financials.baseCost,
        brandingFee: financials.brandingFee,
        sampleShipping: financials.packagingCost,
        freightPerUnit: financials.freightPerUnit,
        landedCost: financials.landedCost,
        retailPrice: financials.retailPrice,
        marginPct: financials.marginPct,
        stock: Number(dto.stock || 0),
        status: dto.status || 'Draft',
        variants: {
          create: (dto.variants || []).map((v) => ({
            sku: v.sku,
            color: v.color,
            size: v.size,
            packageType: v.packageType,
            baseCost: Number(v.baseCost || 0),
            retailPrice: Number(v.retailPrice || 0),
          })),
        },
        documents: {
          create: (dto.documents || []).map((d) => ({
            assetType: d.assetType,
            filePath: d.filePath,
            fileName: d.fileName,
            description: d.description,
          })),
        },
      },
      include: {
        supplier: true,
        variants: true,
        documents: true,
      },
    });

    if (dto.mediaIds && dto.mediaIds.length > 0) {
      await this.prisma.b2bMedia.updateMany({
        where: { id: { in: dto.mediaIds } },
        data: { productId: product.id },
      });
    }

    return this.getProductById(product.id);
  }

  async updateProduct(id: string, dto: UpdateB2bProductDto) {
    const existing = await this.getProductById(id);

    const financials = this.calculateFinancials({
      baseCost: dto.baseCost !== undefined ? dto.baseCost : existing.baseCost,
      brandingFee: dto.brandingFee !== undefined ? dto.brandingFee : existing.brandingFee,
      sampleShipping: dto.sampleShipping !== undefined ? dto.sampleShipping : existing.sampleShipping,
      freightPerUnit: dto.freightPerUnit !== undefined ? dto.freightPerUnit : existing.freightPerUnit,
      retailPrice: dto.retailPrice !== undefined ? dto.retailPrice : existing.retailPrice,
      customsDutyPct: dto.customsDutyPct !== undefined ? dto.customsDutyPct : 0,
      qualityInspectionPerUnit: dto.qualityInspectionPerUnit !== undefined ? dto.qualityInspectionPerUnit : 0,
    });

    if (dto.documents && dto.documents.length > 0) {
      await this.prisma.b2bMedia.deleteMany({ where: { productId: id } });
      await this.prisma.b2bMedia.createMany({
        data: dto.documents.map((d) => ({
          productId: id,
          assetType: d.assetType,
          filePath: d.filePath,
          fileName: d.fileName,
          description: d.description,
        })),
      });
    }

    // Update product & recreate variants/documents if provided
    return this.prisma.b2bProduct.update({
      where: { id },
      data: {
        primaryCategory: dto.primaryCategory,
        subCategory: dto.subCategory,
        internalTag: dto.internalTag,
        originalName: dto.originalName,
        originalModel: dto.originalModel,
        rebrandedName: dto.rebrandedName,
        rebrandedModel: dto.rebrandedModel,
        collection: dto.collection,
        description: dto.description,
        supplierId: dto.supplierId,
        moq: dto.moq !== undefined ? Number(dto.moq) : undefined,
        sampleCost: dto.sampleCost !== undefined ? Number(dto.sampleCost) : undefined,
        leadTime: dto.leadTime !== undefined ? Number(dto.leadTime) : undefined,
        rating: dto.rating !== undefined ? Number(dto.rating) : undefined,
        material: dto.material,
        dimensions: dto.dimensions,
        weight: dto.weight !== undefined ? Number(dto.weight) : undefined,
        hsCode: dto.hsCode,
        logoPath: dto.logoPath,
        insertCardPath: dto.insertCardPath,
        pkgDims: dto.pkgDims,
        printingSpecs: dto.printingSpecs,
        barcodePlacement: dto.barcodePlacement,
        brandCopy: dto.brandCopy,
        seoTitle: dto.seoTitle,
        seoMeta: dto.seoMeta,
        baseCost: financials.baseCost,
        brandingFee: financials.brandingFee,
        sampleShipping: financials.packagingCost,
        freightPerUnit: financials.freightPerUnit,
        landedCost: financials.landedCost,
        retailPrice: financials.retailPrice,
        marginPct: financials.marginPct,
        stock: dto.stock !== undefined ? Number(dto.stock) : undefined,
        status: dto.status,
      },
      include: {
        supplier: true,
        variants: true,
        documents: true,
      },
    });
  }

  async deleteProduct(id: string) {
    await this.getProductById(id);
    return this.prisma.b2bProduct.delete({
      where: { id },
    });
  }

  // ─── MEDIA & FILE STORAGE ───────────────────────────────────
  async uploadMedia(
    file: Express.Multer.File,
    assetType?: string,
    productId?: string,
    description?: string,
  ) {
    if (!file) {
      throw new BadRequestException('No file provided for upload.');
    }

    const basePath = process.env.STORAGE_LOCAL_BASE_PATH
      ? path.resolve(process.env.STORAGE_LOCAL_BASE_PATH)
      : path.resolve(__dirname, '../../../../storage');

    const targetDir = path.join(basePath, 'documents', 'b2b');
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }

    const safeFileName = `${Date.now()}_${file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
    const destinationPath = path.join(targetDir, safeFileName);

    if (file.buffer) {
      fs.writeFileSync(destinationPath, file.buffer);
    } else if (file.path) {
      fs.copyFileSync(file.path, destinationPath);
    }

    const relativePath = path.relative(basePath, destinationPath).replace(/\\/g, '/');
    const fileUrl = `/api/v1/documents/files/${relativePath}`;

    let mediaRecord: any = null;
    if (productId && productId.trim()) {
      const exists = await this.prisma.b2bProduct.findUnique({ where: { id: productId } });
      if (exists) {
        mediaRecord = await this.prisma.b2bMedia.create({
          data: {
            productId,
            assetType: assetType || 'SPEC_SHEET',
            filePath: fileUrl,
            fileName: file.originalname,
            description: description || null,
          },
        });
      }
    }

    return {
      id: mediaRecord?.id || `temp_${Date.now()}`,
      productId: productId || null,
      assetType: assetType || 'SPEC_SHEET',
      fileName: file.originalname,
      filePath: fileUrl,
      fileUrl,
      fileSize: file.size,
      mimeType: file.mimetype,
      description: description || null,
      createdAt: mediaRecord?.createdAt || new Date(),
    };
  }

  async getProductMedia(productId: string) {
    const list = await this.prisma.b2bMedia.findMany({
      where: { productId },
      orderBy: { createdAt: 'desc' },
    });
    return list.map((m) => ({
      ...m,
      fileUrl: m.filePath,
    }));
  }

  async deleteMedia(mediaId: string) {
    if (mediaId.startsWith('temp_')) {
      return { success: true, message: 'Temporary media discarded successfully.' };
    }

    const record = await this.prisma.b2bMedia.findUnique({ where: { id: mediaId } });
    if (!record) {
      return { success: true, message: 'Media record already removed or not found.' };
    }

    const basePath = process.env.STORAGE_LOCAL_BASE_PATH
      ? path.resolve(process.env.STORAGE_LOCAL_BASE_PATH)
      : path.resolve(__dirname, '../../../../storage');

    const cleanPath = record.filePath.replace('/api/v1/documents/files/', '');
    const fullPath = path.resolve(basePath, cleanPath);
    if (fs.existsSync(fullPath)) {
      try {
        fs.unlinkSync(fullPath);
      } catch (err) {}
    }

    await this.prisma.b2bMedia.delete({ where: { id: mediaId } });
    return { success: true, message: 'Media document deleted successfully.' };
  }

  // ─── SUPPLIERS & CATEGORIES ─────────────────────────────────
  async getSuppliers() {
    return this.prisma.b2bSupplier.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async createSupplier(data: {
    id?: string;
    name: string;
    contactPerson?: string;
    country?: string;
    moq?: number;
    sampleCost?: number;
    leadTime?: number;
    rating?: number;
  }) {
    return this.prisma.b2bSupplier.create({
      data: {
        id: data.id || this.generateTimestampId(),
        name: data.name,
        contactPerson: data.contactPerson,
        country: data.country,
        moq: Number(data.moq || 1),
        sampleCost: Number(data.sampleCost || 0),
        leadTime: Number(data.leadTime || 0),
        rating: Number(data.rating || 5.0),
      },
    });
  }

  async getCategories() {
    return this.prisma.b2bCategory.findMany({
      orderBy: { primaryCategory: 'asc' },
    });
  }

  async createCategory(data: {
    primaryCategory: string;
    subCategory?: string;
    internalTag?: string;
  }) {
    return this.prisma.b2bCategory.create({
      data: {
        id: this.generateTimestampId(),
        primaryCategory: data.primaryCategory,
        subCategory: data.subCategory,
        internalTag: data.internalTag,
      },
    });
  }

  // ─── SEED DEFAULT LEGACY PRODUCTS ───────────────────────────
  private async seedDefaultsIfEmpty() {
    const count = await this.prisma.b2bProduct.count();
    if (count > 0) return;

    // 1. Seed Supplier
    const supplier = await this.prisma.b2bSupplier.upsert({
      where: { id: '20260920195156' },
      update: {},
      create: {
        id: '20260920195156',
        supplierCode: 'SUP-B2B-001',
        name: 'XH Manufacturing',
        contactPerson: 'akldsjflk',
        country: 'China',
        moq: 100,
        sampleCost: 5000,
        leadTime: 25,
        rating: 5.0,
      },
    });

    // 2. Seed Categories
    await this.prisma.b2bCategory.createMany({
      data: [
        { id: '20260920194620', primaryCategory: 'domastic', subCategory: 'General', internalTag: 'General' },
        { id: '20260920194645', primaryCategory: 'domastic', subCategory: 'dom1', internalTag: 'Residential' },
        { id: '20260920194653', primaryCategory: 'domastic', subCategory: 'down 2', internalTag: 'Commercial' },
        { id: '20260920194660', primaryCategory: 'Industrial', subCategory: 'Automation', internalTag: 'Factory' },
      ],
    });

    // 3. Seed Published Legacy Product
    await this.prisma.b2bProduct.create({
      data: {
        id: '20260920203658',
        primaryCategory: 'domastic',
        subCategory: 'dom1',
        internalTag: 'Residential',
        originalName: 'sdlkfj',
        originalModel: 'alksdjf;',
        rebrandedName: 'kldsjf',
        rebrandedModel: 'lkjasdlkfjsdkl',
        collection: 'dsfcds',
        description: 'adscdsac High performance commercial white-label valve and pump controller.',
        supplierId: supplier.id,
        moq: 100,
        sampleCost: 5000,
        leadTime: 25,
        rating: 5.0,
        material: 'SS304',
        dimensions: '250x180x90 mm',
        weight: 2.5,
        hsCode: '841370',
        logoPath: 'Not selected',
        insertCardPath: 'Not selected',
        pkgDims: 'Standard Export Carton',
        printingSpecs: 'CMYK 4-Color Print',
        barcodePlacement: 'Side Panel Lower Right',
        brandCopy: 'High Efficiency White-Label Product',
        seoTitle: 'B2B Industrial Sourcing',
        seoMeta: 'industrial, valve, pump, b2b',
        baseCost: 10.00,
        brandingFee: 876.00,
        sampleShipping: 876.00,
        freightPerUnit: 876.00,
        landedCost: 2638.00,
        retailPrice: 87600.00,
        marginPct: 96.99,
        stock: 50,
        status: 'published',
        variants: {
          create: [
            { sku: 'V-001', color: 'Silver', size: '2 Inch', packageType: 'Carton', baseCost: 10.00, retailPrice: 87600.00 },
          ],
        },
      },
    });

    // 4. Seed a couple of Draft Products (matching Screenshot 1 Available Products grid)
    const draftIds = [
      '20260920202437',
      '20260920205301',
      '20260920205346',
      '20260920205854',
    ];

    for (let i = 0; i < draftIds.length; i++) {
      const dId = draftIds[i];
      await this.prisma.b2bProduct.create({
        data: {
          id: dId,
          primaryCategory: 'domastic',
          originalName: `OEM Draft Pump #${i + 1}`,
          originalModel: `OEM-MOD-${i + 100}`,
          rebrandedName: `Saark B2B Product ${i + 1}`,
          rebrandedModel: `SRK-TRD-${i + 200}`,
          collection: 'Standard Line',
          description: 'Draft product under white-label evaluation and sourcing review.',
          supplierId: supplier.id,
          moq: 50,
          sampleCost: 2500,
          leadTime: 20,
          rating: 4.5,
          material: 'Cast Iron',
          dimensions: '300x200x150 mm',
          weight: 4.0,
          hsCode: '841391',
          baseCost: 1200.00,
          brandingFee: 250.00,
          sampleShipping: 150.00,
          freightPerUnit: 300.00,
          landedCost: 1900.00,
          retailPrice: 4500.00,
          marginPct: 57.78,
          stock: 20,
          status: 'Draft',
        },
      });
    }
  }

  private generateTimestampId(): string {
    const d = new Date();
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
  }
}
