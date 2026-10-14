import { Controller, Get, Query, Req, Res, HttpStatus, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Response } from 'express';
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

  @Get('summary/export')
  @RequirePermissions('REPORTS:EXPORT')
  @ApiOperation({ summary: 'Export Executive ERP Summary Report to CSV with audit logging' })
  async exportSummary(@Req() req: any, @Res() res: Response) {
    const result = await this.reportsService.exportExecutiveSummaryCsv(req.user, req);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${result.fileName}"`);
    return res.status(HttpStatus.OK).send('\uFEFF' + result.csvContent);
  }

  @Get('gst/export')
  @RequirePermissions('REPORTS:EXPORT', 'SALES:EXPORT')
  @ApiOperation({ summary: 'Export Indian GST Portal compliant GSTR-1 JSON or CSV data with audit trail' })
  async exportGst(
    @Query('month') month: string,
    @Query('year') year: number,
    @Query('format') format: string,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const result = await this.reportsService.exportGstReport(month, year, format || 'json', req.user, req);
    if (result.format === 'json') {
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', `attachment; filename="${result.fileName}"`);
      return res.status(HttpStatus.OK).json(result.jsonData);
    }
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${result.fileName}"`);
    return res.status(HttpStatus.OK).send('\uFEFF' + result.csvContent);
  }

  @Get('gst-json')
  @RequirePermissions('REPORTS:EXPORT', 'SALES:EXPORT')
  @ApiOperation({ summary: 'Alias for GST GSTR-1 JSON export' })
  async exportGstJson(
    @Query('month') month: string,
    @Query('year') year: number,
    @Req() req: any,
    @Res() res: Response,
  ) {
    return this.exportGst(month, year, 'json', req, res);
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
