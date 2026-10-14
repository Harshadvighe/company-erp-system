import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ProductsService } from './products.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('Products')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  // ─── PRODUCTS ─────────────────────────────────────────────────────────────

  @Get()
  @RequirePermissions('INVENTORY:VIEW')
  @ApiOperation({ summary: 'List products with search, category filter & pagination' })
  findAll(@Query() query: any) {
    return this.productsService.findAll(query);
  }

  @Get(':id')
  @RequirePermissions('INVENTORY:VIEW')
  @ApiOperation({ summary: 'Get product detail with stock & category info' })
  findOne(@Param('id') id: string) {
    return this.productsService.findOne(id);
  }

  private getActor(req: any) {
    if (!req.user) return undefined;
    return {
      ...req.user,
      requestId: req.headers?.['x-request-id'] || req.headers?.['x-correlation-id'],
      ip: req.ip || req.headers?.['x-forwarded-for'],
    };
  }

  @Post()
  @RequirePermissions('INVENTORY:CREATE')
  @ApiOperation({ summary: 'Create new product record' })
  create(@Body() dto: any, @Req() req: any) {
    return this.productsService.create(dto, req.user?.id, req.user?.email, this.getActor(req));
  }

  @Put(':id')
  @RequirePermissions('INVENTORY:EDIT')
  @ApiOperation({ summary: 'Update product record' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.productsService.update(id, dto, req.user?.id, req.user?.email, this.getActor(req));
  }

  @Delete(':id')
  @RequirePermissions('INVENTORY:DELETE')
  @ApiOperation({ summary: 'Soft-delete product' })
  delete(@Param('id') id: string, @Req() req: any) {
    return this.productsService.delete(id, req.user?.id, req.user?.email, this.getActor(req));
  }

  // ─── CATEGORIES ───────────────────────────────────────────────────────────

  @Get('categories/list')
  @RequirePermissions('INVENTORY:VIEW')
  @ApiOperation({ summary: 'List product categories' })
  getCategories() {
    return this.productsService.getCategories();
  }

  @Post('categories')
  @RequirePermissions('INVENTORY:CREATE')
  @ApiOperation({ summary: 'Create product category' })
  createCategory(@Body() dto: any, @Req() req: any) {
    return this.productsService.createCategory(dto, req.user);
  }

  @Put('categories/:id')
  @RequirePermissions('INVENTORY:EDIT')
  @ApiOperation({ summary: 'Update product category' })
  updateCategory(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.productsService.updateCategory(id, dto, req.user);
  }

  // ─── UNITS ────────────────────────────────────────────────────────────────

  @Get('units/list')
  @RequirePermissions('INVENTORY:VIEW')
  @ApiOperation({ summary: 'List units of measure' })
  getUnits() {
    return this.productsService.getUnits();
  }

  @Post('units')
  @RequirePermissions('INVENTORY:CREATE')
  @ApiOperation({ summary: 'Create unit of measure' })
  createUnit(@Body() dto: any, @Req() req: any) {
    return this.productsService.createUnit(dto, req.user);
  }
}
