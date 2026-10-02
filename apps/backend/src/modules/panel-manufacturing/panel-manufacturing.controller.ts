import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { PanelManufacturingService } from './panel-manufacturing.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Panel Manufacturing')
@UseGuards(JwtAuthGuard)
@Controller('api/v1/panel-manufacturing')
export class PanelManufacturingController {
  constructor(private readonly panelService: PanelManufacturingService) {}

  @Get('specs')
  @ApiOperation({ summary: 'List all Panel Specifications & BOMs' })
  async findAll() {
    return this.panelService.findAll();
  }

  @Get('specs/:id')
  @ApiOperation({ summary: 'Get Panel Specification details & BOM breakdown' })
  async findOne(@Param('id') id: string) {
    return this.panelService.findOne(id);
  }

  @Post('specs')
  @ApiOperation({ summary: 'Create new Panel Specification & auto-calculate BOM pricing' })
  async create(@Body() dto: any) {
    return this.panelService.create(dto);
  }
}
