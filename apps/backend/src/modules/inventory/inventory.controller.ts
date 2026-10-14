import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { InventoryService } from './inventory.service';

@ApiTags('Inventory, Stores & Warehouse Management')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller(['api/v1/inventory', 'inventory'])
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Get('summary')
  @RequirePermissions('INVENTORY:VIEW')
  @ApiOperation({ summary: 'Overall inventory valuation, SKU count, and low stock alert summary' })
  getSummary() {
    return this.inventoryService.getInventorySummary();
  }

  @Get('warehouses')
  @RequirePermissions('INVENTORY:VIEW')
  @ApiOperation({ summary: 'List all storage warehouses, plant locations and their SKU counts' })
  getWarehouses() {
    return this.inventoryService.getWarehouses();
  }

  @Post('warehouses')
  @RequirePermissions('INVENTORY:CREATE')
  @ApiOperation({ summary: 'Create new store or warehouse location' })
  createWarehouse(@Body() dto: { code: string; name: string; location: string }, @Req() req: any) {
    return this.inventoryService.createWarehouse(dto, req.user);
  }

  @Get('stock')
  @RequirePermissions('INVENTORY:VIEW')
  @ApiOperation({ summary: 'List inventory stock items across warehouses with low stock alerts' })
  getStockItems(
    @Query('warehouseId') warehouseId?: string,
    @Query('categoryId') categoryId?: string,
    @Query('lowStockOnly') lowStockOnly?: string,
    @Query('search') search?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.inventoryService.getStockItems({
      warehouseId,
      categoryId,
      lowStockOnly: lowStockOnly === 'true' || lowStockOnly === '1',
      search,
      page,
      limit,
    });
  }

  @Post('adjust')
  @RequirePermissions('INVENTORY:EDIT')
  @ApiOperation({ summary: 'Perform manual stock adjustment (reconciliation, physical count, damage)' })
  adjustStock(
    @Body()
    dto: {
      productId: string;
      warehouseId: string;
      quantity: number;
      adjustmentType: 'INCREASE' | 'DECREASE' | 'CORRECTION';
      reason?: string;
      notes?: string;
    },
    @Req() req: any,
  ) {
    return this.inventoryService.adjustStock(dto, req.user?.id, req.user);
  }

  @Post('transfer')
  @RequirePermissions('INVENTORY:EDIT')
  @ApiOperation({ summary: 'Inter-warehouse stock transfer between stores' })
  transferStock(
    @Body()
    dto: {
      productId: string;
      fromWarehouseId: string;
      toWarehouseId: string;
      quantity: number;
      notes?: string;
    },
    @Req() req: any,
  ) {
    return this.inventoryService.transferStock(dto, req.user?.id, req.user);
  }

  @Get('transactions')
  @RequirePermissions('INVENTORY:VIEW')
  @ApiOperation({ summary: 'Audit ledger of all stock movements (IN/OUT/ADJUSTMENT/TRANSFER)' })
  getTransactions(
    @Query('productId') productId?: string,
    @Query('warehouseId') warehouseId?: string,
    @Query('transactionType') transactionType?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.inventoryService.getTransactions({
      productId,
      warehouseId,
      transactionType,
      page,
      limit,
    });
  }
}
