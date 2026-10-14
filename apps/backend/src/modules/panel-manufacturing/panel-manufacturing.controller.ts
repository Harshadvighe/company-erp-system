import { Controller, Get, Post, Body, Param, Query, UseGuards, Req, Res, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Response } from 'express';
import { PanelManufacturingService } from './panel-manufacturing.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('Panel Manufacturing')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/panel-manufacturing')
export class PanelManufacturingController {
  constructor(private readonly panelService: PanelManufacturingService) {}

  @Get('specs')
  @RequirePermissions('PRODUCTION:VIEW')
  @ApiOperation({ summary: 'List all Panel Specifications & BOMs' })
  async findAll() {
    return this.panelService.findAll();
  }

  @Get('specs/:id/bom/export')
  @RequirePermissions('PRODUCTION:EXPORT', 'PRODUCTION:VIEW')
  @ApiOperation({ summary: 'Export Panel BOM Specification (CSV/JSON) with audit logging' })
  async exportBom(
    @Param('id') id: string,
    @Query('format') format: string,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const result = await this.panelService.exportBom(id, format || 'csv', req.user, req);
    if (result.format === 'json') {
      return res.status(HttpStatus.OK).json(result.data);
    }
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${result.fileName}"`);
    return res.status(HttpStatus.OK).send('\uFEFF' + result.csvContent);
  }

  @Get('specs/:id')
  @RequirePermissions('PRODUCTION:VIEW')
  @ApiOperation({ summary: 'Get Panel Specification details & BOM breakdown' })
  async findOne(@Param('id') id: string) {
    return this.panelService.findOne(id);
  }

  @Post('specs')
  @RequirePermissions('PRODUCTION:CREATE')
  @ApiOperation({ summary: 'Create new Panel Specification & auto-calculate BOM pricing' })
  async create(@Body() dto: any, @Req() req: any) {
    return this.panelService.create(dto, req.user);
  }
}
