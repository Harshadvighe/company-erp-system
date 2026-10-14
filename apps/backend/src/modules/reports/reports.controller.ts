import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { ReportsService } from './reports.service';

@ApiTags('Reports & Executive Analytics')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller(['api/v1/reports', 'reports'])
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('summary')
  @RequirePermissions('REPORTS:VIEW')
  @ApiOperation({ summary: 'Consolidated executive ERP summary with financial & operational indicators' })
  getExecutiveSummary() {
    return this.reportsService.getExecutiveSummary();
  }

  @Get('sales')
  @RequirePermissions('REPORTS:VIEW', 'SALES:VIEW')
  @ApiOperation({ summary: 'Commercial sales orders, invoices and customer billing breakdown' })
  getSalesReport() {
    return this.reportsService.getSalesReport();
  }

  @Get('inventory')
  @RequirePermissions('REPORTS:VIEW', 'INVENTORY:VIEW')
  @ApiOperation({ summary: 'Inventory stock valuation, warehouse distribution, and movement trends' })
  getInventoryReport() {
    return this.reportsService.getInventoryReport();
  }

  @Get('production')
  @RequirePermissions('REPORTS:VIEW', 'PRODUCTION:VIEW')
  @ApiOperation({ summary: 'Panel manufacturing pipeline, fabrication stages and QC inspection status' })
  getProductionReport() {
    return this.reportsService.getProductionReport();
  }
}
