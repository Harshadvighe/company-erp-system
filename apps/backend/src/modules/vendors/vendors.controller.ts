import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { VendorsService } from './vendors.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Vendors')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/vendors')
export class VendorsController {
  constructor(private readonly vendorsService: VendorsService) {}

  @Get()
  @ApiOperation({ summary: 'List vendors with search & pagination' })
  findAll(@Query() query: any) {
    return this.vendorsService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get vendor profile' })
  findOne(@Param('id') id: string) {
    return this.vendorsService.findOne(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create vendor master record' })
  create(@Body() dto: any, @Req() req: any) {
    return this.vendorsService.create(dto, req.user?.id, req.user?.email);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update vendor master record' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.vendorsService.update(id, dto, req.user?.id, req.user?.email);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft-delete vendor' })
  delete(@Param('id') id: string, @Req() req: any) {
    return this.vendorsService.delete(id, req.user?.id, req.user?.email);
  }
}
