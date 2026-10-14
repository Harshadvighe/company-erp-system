import { Controller, Get, Post, Body, Param, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
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
