import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { ReportsService } from './reports.service';

@ApiTags('Reports & Executive Analytics')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller(['api/v1/reports', 'reports'])
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('summary')
  @ApiOperation({ summary: 'Consolidated executive ERP summary with financial & operational indicators' })
  getExecutiveSummary() {
    return this.reportsService.getExecutiveSummary();
  }

  @Get('sales')
  @ApiOperation({ summary: 'Commercial sales orders, invoices and customer billing breakdown' })
  getSalesReport() {
    return this.reportsService.getSalesReport();
  }

  @Get('inventory')
  @ApiOperation({ summary: 'Inventory stock valuation, warehouse distribution, and movement trends' })
  getInventoryReport() {
    return this.reportsService.getInventoryReport();
  }

  @Get('production')
  @ApiOperation({ summary: 'Panel manufacturing pipeline, fabrication stages and QC inspection status' })
  getProductionReport() {
    return this.reportsService.getProductionReport();
  }
}
