import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { StaffService } from './staff.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('Staff')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/staff')
export class StaffController {
  constructor(private readonly staffService: StaffService) {}

  @Get()
  @RequirePermissions('STAFF:VIEW')
  @ApiOperation({ summary: 'List all staff members with department and designation filters' })
  findAll(@Query() query: any) {
    return this.staffService.findAll(query);
  }

  @Get(':id')
  @RequirePermissions('STAFF:VIEW')
  @ApiOperation({ summary: 'Get full staff profile with reporting chain and assignments' })
  findOne(@Param('id') id: string) {
    return this.staffService.findOne(id);
  }

  @Post()
  @RequirePermissions('STAFF:CREATE')
  @ApiOperation({ summary: 'Create new staff profile (with optional user account creation)' })
  create(@Body() dto: any, @Req() req: any) {
    return this.staffService.create(dto, req.user?.id, req.user?.email);
  }

  @Put(':id')
  @RequirePermissions('STAFF:EDIT')
  @ApiOperation({ summary: 'Update staff profile details' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.staffService.update(id, dto, req.user?.id, req.user?.email);
  }

  @Patch(':id/status')
  @RequirePermissions('STAFF:EDIT')
  @ApiOperation({ summary: 'Update staff employment status (ACTIVE, INACTIVE, SUSPENDED)' })
  updateStatus(@Param('id') id: string, @Body('status') status: string, @Req() req: any) {
    return this.staffService.updateStatus(id, status, req.user?.id, req.user?.email);
  }
}
