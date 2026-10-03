import {
  Controller, Get, Post, Put, Delete,
  Body, Param, Query, UseGuards, Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CustomersService } from './customers.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('Customers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/customers')
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  // ─── CUSTOMER MASTER ──────────────────────────────────────────────────────
  @Get()
  @RequirePermissions('CUSTOMERS:VIEW')
  @ApiOperation({ summary: 'List customers with search, filters & pagination' })
  findAll(@Query() query: any) {
    return this.customersService.findAll(query);
  }

  @Post('check-duplicate')
  @RequirePermissions('CUSTOMERS:VIEW')
  @ApiOperation({ summary: 'Check if GST, phone, or email already exists' })
  checkDuplicate(@Body() dto: { gstin?: string; phone?: string; email?: string; companyName?: string }) {
    return this.customersService.checkDuplicate(dto);
  }

  @Post('merge')
  @RequirePermissions('CRM:MERGE')
  @ApiOperation({ summary: 'Merge duplicate customer into master customer (Admin only)' })
  mergeCustomers(@Body() body: { sourceId: string; targetId: string }, @Req() req: any) {
    return this.customersService.mergeCustomers(body.sourceId, body.targetId, req.user);
  }

  @Get(':id')
  @RequirePermissions('CUSTOMERS:VIEW')
  @ApiOperation({ summary: 'Get full customer profile — contacts, interactions, leads, enquiries' })
  findOne(@Param('id') id: string) {
    return this.customersService.findOne(id);
  }

  @Get(':id/timeline')
  @RequirePermissions('CUSTOMERS:VIEW')
  @ApiOperation({ summary: 'Get Customer 360 chronological timeline (Calls, Meetings, Visits, Quotes)' })
  getTimeline(@Param('id') id: string) {
    return this.customersService.getTimeline(id);
  }

  @Post()
  @RequirePermissions('CUSTOMERS:CREATE')
  @ApiOperation({ summary: 'Create customer master — auto-generates CustomerCode & primary contact' })
  create(@Body() dto: any, @Req() req: any) {
    return this.customersService.create(dto, req.user?.id, req.user?.email);
  }

  @Put(':id')
  @RequirePermissions('CUSTOMERS:EDIT')
  @ApiOperation({ summary: 'Update customer master record' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.customersService.update(id, dto, req.user?.id, req.user?.email);
  }

  @Delete(':id')
  @RequirePermissions('CUSTOMERS:DELETE')
  @ApiOperation({ summary: 'Soft-delete customer (marks status as DELETED)' })
  delete(@Param('id') id: string, @Req() req: any) {
    return this.customersService.delete(id, req.user?.id, req.user?.email);
  }

  // ─── CONTACTS ─────────────────────────────────────────────────────────────
  @Post(':id/contacts')
  @RequirePermissions('CUSTOMERS:CREATE')
  @ApiOperation({ summary: 'Add contact to customer' })
  addContact(@Param('id') customerId: string, @Body() dto: any, @Req() req: any) {
    return this.customersService.addContact(customerId, dto, req.user?.id);
  }

  @Put(':id/contacts/:contactId')
  @RequirePermissions('CUSTOMERS:EDIT')
  @ApiOperation({ summary: 'Update customer contact' })
  updateContact(@Param('contactId') contactId: string, @Body() dto: any) {
    return this.customersService.updateContact(contactId, dto);
  }

  @Delete(':id/contacts/:contactId')
  @RequirePermissions('CUSTOMERS:DELETE')
  @ApiOperation({ summary: 'Delete customer contact (not allowed if primary)' })
  deleteContact(@Param('contactId') contactId: string) {
    return this.customersService.deleteContact(contactId);
  }

  // ─── INTERACTIONS ─────────────────────────────────────────────────────────
  @Get(':id/interactions')
  @RequirePermissions('CUSTOMERS:VIEW')
  @ApiOperation({ summary: 'Get all interactions for a customer' })
  getInteractions(@Param('id') customerId: string, @Query('type') type?: string) {
    return this.customersService.getInteractions(customerId, type);
  }

  @Post(':id/interactions')
  @RequirePermissions('CUSTOMERS:CREATE')
  @ApiOperation({ summary: 'Record customer interaction: Call, Meeting, Email, WhatsApp, Demo, Visit' })
  recordInteraction(@Param('id') customerId: string, @Body() dto: any, @Req() req: any) {
    return this.customersService.recordInteraction(
      customerId,
      dto,
      req.user?.fullName || req.user?.email || 'System',
    );
  }
}
