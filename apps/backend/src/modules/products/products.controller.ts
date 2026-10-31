import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { ProductsService } from './products.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import {
  CreateSaarkProductSectorDto,
  UpdateSaarkProductSectorDto,
  SaarkProductSectorQueryDto,
} from './dto/saark-product-sector.dto';

@ApiTags('Products')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  // ─── SAARK PRODUCT SECTOR & TECHNICAL SPECS (38 FIELDS) ────────────────────

  @Get('saark-products')
  @ApiOperation({
    summary: 'List Saark Products with 38 technical specs, sector filtering & search',
  })
  findSaarkProducts(@Query() query: SaarkProductSectorQueryDto) {
    return this.productsService.findSaarkProducts(query);
  }

  @Get('saark-products/stats')
  @ApiOperation({ summary: 'Get Saark product counts grouped by sector and category' })
  getSaarkProductStats() {
    return this.productsService.getSaarkProductStats();
  }

  @Get('saark-products/sku/:sku')
  @ApiOperation({ summary: 'Get Saark product by unique SKU / Model Number' })
  findSaarkProductBySku(@Param('sku') sku: string) {
    return this.productsService.findSaarkProductBySku(sku);
  }

  @Get('saark-products/:id')
  @ApiOperation({ summary: 'Get Saark product technical specification by ID' })
  findSaarkProductById(@Param('id') id: string) {
    return this.productsService.findSaarkProductById(id);
  }

  @Post('saark-products')
  @ApiOperation({
    summary: 'Create a new Saark Product with all 38 technical specifications',
  })
  @ApiResponse({ status: 201, description: 'Product specification record created' })
  createSaarkProduct(@Body() dto: CreateSaarkProductSectorDto, @Req() req: any) {
    return this.productsService.createSaarkProduct(
      dto,
      req.user?.id,
      req.user?.email,
    );
  }

  @Put('saark-products/:id')
  @ApiOperation({ summary: 'Update an existing Saark Product specification' })
  updateSaarkProduct(
    @Param('id') id: string,
    @Body() dto: UpdateSaarkProductSectorDto,
    @Req() req: any,
  ) {
    return this.productsService.updateSaarkProduct(
      id,
      dto,
      req.user?.id,
      req.user?.email,
    );
  }

  @Delete('saark-products/:id')
  @ApiOperation({ summary: 'Delete a Saark Product specification record' })
  deleteSaarkProduct(@Param('id') id: string, @Req() req: any) {
    return this.productsService.deleteSaarkProduct(
      id,
      req.user?.id,
      req.user?.email,
    );
  }

  // ─── SECTOR REGISTRY (Tab 1: Select / Add Sector) ─────────────────────────

  @Get('sectors/list')
  @ApiOperation({ summary: 'List all active Product Sectors' })
  getSectors() {
    return this.productsService.getSectors();
  }

  @Post('sectors')
  @ApiOperation({ summary: 'Register a new Product Sector' })
  createSector(@Body() dto: { name: string }) {
    return this.productsService.createSector(dto.name);
  }

  // ─── PROMOTION MATERIALS (Tab 3: Promotion Material Management) ───────────

  @Get('promotions/list')
  @ApiOperation({ summary: 'List approved corporate promotion materials' })
  getPromotions(@Query('sector') sector?: string) {
    return this.productsService.getPromotions(sector);
  }

  @Post('promotions')
  @ApiOperation({ summary: 'Add a new promotion material link or attachment' })
  createPromotion(@Body() dto: any) {
    return this.productsService.createPromotion(dto);
  }

  @Delete('promotions/:id')
  @ApiOperation({ summary: 'Delete promotion material record' })
  deletePromotion(@Param('id') id: string) {
    return this.productsService.deletePromotion(id);
  }

  // ─── STANDARD INVENTORY / CATALOG PRODUCTS ─────────────────────────────────

  @Get()
  @ApiOperation({ summary: 'List standard ERP products with pagination and stock' })
  findAll(@Query() query: any) {
    return this.productsService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get standard ERP product details' })
  findOne(@Param('id') id: string) {
    return this.productsService.findOne(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create new standard ERP product' })
  create(@Body() dto: any, @Req() req: any) {
    return this.productsService.create(dto, req.user?.id, req.user?.email);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update standard ERP product' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.productsService.update(id, dto, req.user?.id, req.user?.email);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft-delete standard ERP product' })
  delete(@Param('id') id: string, @Req() req: any) {
    return this.productsService.delete(id, req.user?.id, req.user?.email);
  }

  // ─── CATEGORIES & UNITS ───────────────────────────────────────────────────

  @Get('categories/list')
  @ApiOperation({ summary: 'List product categories' })
  getCategories() {
    return this.productsService.getCategories();
  }

  @Post('categories')
  @ApiOperation({ summary: 'Create product category' })
  createCategory(@Body() dto: any) {
    return this.productsService.createCategory(dto);
  }

  @Put('categories/:id')
  @ApiOperation({ summary: 'Update product category' })
  updateCategory(@Param('id') id: string, @Body() dto: any) {
    return this.productsService.updateCategory(id, dto);
  }

  @Get('units/list')
  @ApiOperation({ summary: 'List units of measure' })
  getUnits() {
    return this.productsService.getUnits();
  }

  @Post('units')
  @ApiOperation({ summary: 'Create unit of measure' })
  createUnit(@Body() dto: any) {
    return this.productsService.createUnit(dto);
  }
}
