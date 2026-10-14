import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { VendorsService } from './vendors.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('Vendors')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/vendors')
export class VendorsController {
  constructor(private readonly vendorsService: VendorsService) {}

  @Get()
  @RequirePermissions('VENDORS:VIEW')
  @ApiOperation({ summary: 'List vendors with search & pagination' })
  findAll(@Query() query: any) {
    return this.vendorsService.findAll(query);
  }

  @Get(':id')
  @RequirePermissions('VENDORS:VIEW')
  @ApiOperation({ summary: 'Get vendor profile' })
  findOne(@Param('id') id: string) {
    return this.vendorsService.findOne(id);
  }

  @Post('verify-gst')
  @RequirePermissions('VENDORS:VIEW')
  @ApiOperation({ summary: 'Verify GSTIN and auto-fetch business details from GST Portal' })
  verifyGst(@Body('gstin') gstin: string, @Req() req: any) {
    return this.vendorsService.verifyGst(gstin, req.user, req.ip);
  }

  @Post()
  @RequirePermissions('VENDORS:CREATE')
  @ApiOperation({ summary: 'Create vendor master record' })
  create(@Body() dto: any, @Req() req: any) {
    return this.vendorsService.create(dto, req.user?.id, req.user?.email, req.user);
  }

  @Put(':id')
  @RequirePermissions('VENDORS:EDIT')
  @ApiOperation({ summary: 'Update vendor master record' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.vendorsService.update(id, dto, req.user?.id, req.user?.email, req.user);
  }

  @Delete(':id')
  @RequirePermissions('VENDORS:DELETE')
  @ApiOperation({ summary: 'Soft-delete vendor' })
  delete(@Param('id') id: string, @Req() req: any) {
    return this.vendorsService.delete(id, req.user?.id, req.user?.email, req.user);
  }
}
