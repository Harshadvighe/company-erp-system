import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, UploadedFile, UseInterceptors } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiConsumes } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { B2bTradingService } from './b2b-trading.service';
import { CreateB2bProductDto, UpdateB2bProductDto, CalculateB2bFinancialsDto } from './b2b-trading.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('B2B Trading & White-Label Marketplace')
@UseGuards(JwtAuthGuard)
@Controller('api/v1/b2b')
export class B2bTradingController {
  constructor(private readonly b2bService: B2bTradingService) {}

  // ─── PRODUCTS ──────────────────────────────────────────────
  @Get('products')
  @ApiOperation({ summary: 'List all B2B trading products with filters' })
  async getProducts(
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('category') category?: string,
  ) {
    return this.b2bService.getProducts({ status, search, category });
  }

  @Get('products/published')
  @ApiOperation({ summary: 'Buyer catalog of published white-labeled products' })
  async getPublishedProducts(@Query('search') search?: string) {
    return this.b2bService.getPublishedProducts(search);
  }

  @Get('products/:id')
  @ApiOperation({ summary: 'Get full product details including variants, documents, and financials' })
  async getProductById(@Param('id') id: string) {
    return this.b2bService.getProductById(id);
  }

  @Post('products')
  @ApiOperation({ summary: 'Create new B2B product (Draft or published)' })
  async createProduct(@Body() dto: CreateB2bProductDto) {
    return this.b2bService.createProduct(dto);
  }

  @Put('products/:id')
  @ApiOperation({ summary: 'Update existing B2B product' })
  async updateProduct(@Param('id') id: string, @Body() dto: UpdateB2bProductDto) {
    return this.b2bService.updateProduct(id, dto);
  }

  @Delete('products/:id')
  @ApiOperation({ summary: 'Delete B2B product' })
  async deleteProduct(@Param('id') id: string) {
    return this.b2bService.deleteProduct(id);
  }

  // ─── FINANCIAL CALCULATOR ──────────────────────────────────
  @Post('products/calculate-financials')
  @ApiOperation({ summary: 'Calculate Landed Cost, Gross Margin, and Target Retail Price' })
  async calculateFinancials(@Body() dto: CalculateB2bFinancialsDto) {
    return this.b2bService.calculateFinancials(dto);
  }

  // ─── MEDIA & FILE STORAGE ───────────────────────────────────
  @Post('upload')
  @ApiOperation({ summary: 'Upload PDF documents, artworks, or gallery images for B2B platform' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  async uploadMedia(
    @UploadedFile() file: Express.Multer.File,
    @Body('assetType') assetType?: string,
    @Body('productId') productId?: string,
    @Body('description') description?: string,
  ) {
    return this.b2bService.uploadMedia(file, assetType, productId, description);
  }

  @Get('products/:id/media')
  @ApiOperation({ summary: 'List all media attachments for a B2B product' })
  async getProductMedia(@Param('id') id: string) {
    return this.b2bService.getProductMedia(id);
  }

  @Delete('media/:id')
  @ApiOperation({ summary: 'Delete a media attachment' })
  async deleteMedia(@Param('id') id: string) {
    return this.b2bService.deleteMedia(id);
  }

  // ─── SUPPLIERS ─────────────────────────────────────────────
  @Get('suppliers')
  @ApiOperation({ summary: 'List all B2B suppliers' })
  async getSuppliers() {
    return this.b2bService.getSuppliers();
  }

  @Post('suppliers')
  @ApiOperation({ summary: 'Add new B2B supplier' })
  async createSupplier(
    @Body()
    dto: {
      name: string;
      contactPerson?: string;
      country?: string;
      moq?: number;
      sampleCost?: number;
      leadTime?: number;
      rating?: number;
    },
  ) {
    return this.b2bService.createSupplier(dto);
  }

  // ─── CATEGORIES ────────────────────────────────────────────
  @Get('categories')
  @ApiOperation({ summary: 'List all B2B categories' })
  async getCategories() {
    return this.b2bService.getCategories();
  }

  @Post('categories')
  @ApiOperation({ summary: 'Add new B2B category' })
  async createCategory(
    @Body()
    dto: {
      primaryCategory: string;
      subCategory?: string;
      internalTag?: string;
    },
  ) {
    return this.b2bService.createCategory(dto);
  }
}
