import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ProductsService } from './products.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Products')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  // ─── PRODUCTS ─────────────────────────────────────────────────────────────

  @Get()
  @ApiOperation({ summary: 'List products with search, category filter & pagination' })
  findAll(@Query() query: any) {
    return this.productsService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get product detail with stock & category info' })
  findOne(@Param('id') id: string) {
    return this.productsService.findOne(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create new product record' })
  create(@Body() dto: any, @Req() req: any) {
    return this.productsService.create(dto, req.user?.id, req.user?.email);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update product record' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.productsService.update(id, dto, req.user?.id, req.user?.email);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft-delete product' })
  delete(@Param('id') id: string, @Req() req: any) {
    return this.productsService.delete(id, req.user?.id, req.user?.email);
  }

  // ─── CATEGORIES ───────────────────────────────────────────────────────────

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

  // ─── UNITS ────────────────────────────────────────────────────────────────

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
