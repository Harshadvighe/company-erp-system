import {
  Controller, Get, Post, Put, Patch, Delete,
  Body, Param, Query, UseGuards, Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CustomersService } from './customers.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Customers')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/customers')
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  // ─── CUSTOMER MASTER ──────────────────────────────────────────────────────

  @Get()
  @ApiOperation({ summary: 'List customers with search, filters & pagination' })
  findAll(@Query() query: any) {
    return this.customersService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get full customer profile — contacts, interactions, leads, enquiries, panels' })
  findOne(@Param('id') id: string) {
    return this.customersService.findOne(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create customer master — auto-generates CustomerCode, primary contact & valuation' })
  create(@Body() dto: any, @Req() req: any) {
    return this.customersService.create(dto, req.user?.id, req.user?.email);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update customer master record' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.customersService.update(id, dto, req.user?.id, req.user?.email);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Soft-delete customer (marks status as DELETED)' })
  delete(@Param('id') id: string, @Req() req: any) {
    return this.customersService.delete(id, req.user?.id, req.user?.email);
  }

  // ─── CONTACTS ─────────────────────────────────────────────────────────────

  @Post(':id/contacts')
  @ApiOperation({ summary: 'Add contact to customer' })
  addContact(@Param('id') customerId: string, @Body() dto: any, @Req() req: any) {
    return this.customersService.addContact(customerId, dto, req.user?.id);
  }

  @Put(':id/contacts/:contactId')
  @ApiOperation({ summary: 'Update customer contact' })
  updateContact(@Param('contactId') contactId: string, @Body() dto: any) {
    return this.customersService.updateContact(contactId, dto);
  }

  @Delete(':id/contacts/:contactId')
  @ApiOperation({ summary: 'Delete customer contact (not allowed if primary)' })
  deleteContact(@Param('contactId') contactId: string) {
    return this.customersService.deleteContact(contactId);
  }

  // ─── INTERACTIONS ─────────────────────────────────────────────────────────

  @Get(':id/interactions')
  @ApiOperation({ summary: 'Get all interactions for a customer — timeline view' })
  getInteractions(@Param('id') customerId: string, @Query('type') type?: string) {
    return this.customersService.getInteractions(customerId, type);
  }

  @Post(':id/interactions')
  @ApiOperation({ summary: 'Record customer interaction: Call, Meeting, Email, WhatsApp, Demo, Visit' })
  recordInteraction(@Param('id') customerId: string, @Body() dto: any, @Req() req: any) {
    return this.customersService.recordInteraction(
      customerId,
      dto,
      req.user?.fullName || req.user?.email || 'System',
    );
  }
}
