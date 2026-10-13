import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { SalesService } from './sales.service';

@ApiTags('Sales & Quotations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller(['api/v1/sales', 'sales'])
export class SalesController {
  constructor(private readonly salesService: SalesService) {}

  // ─────────────────────────────────────────────────────────────────────────
  // QUOTATIONS
  // ─────────────────────────────────────────────────────────────────────────

  @Get('quotations')
  @RequirePermissions('SALES:VIEW', 'CRM:VIEW')
  @ApiOperation({ summary: 'List commercial quotations with filters' })
  getQuotations(
    @Query('customerId') customerId?: string,
    @Query('opportunityId') opportunityId?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Req() req?: any,
  ) {
    return this.salesService.getQuotations({
      customerId,
      opportunityId,
      status,
      search,
      page,
      limit,
    }, req?.user);
  }

  @Get('quotations/:id')
  @RequirePermissions('SALES:VIEW', 'CRM:VIEW')
  @ApiOperation({ summary: 'Get quotation detail with items, customer 360 link and revisions' })
  getQuotationById(@Param('id') id: string, @Req() req: any) {
    return this.salesService.getQuotationById(id, req.user);
  }

  @Post('quotations')
  @RequirePermissions('SALES:CREATE', 'CRM:CREATE')
  @ApiOperation({ summary: 'Create new commercial quotation (auto REV-0)' })
  createQuotation(@Body() dto: any, @Req() req: any) {
    return this.salesService.createQuotation(dto, req.user);
  }

  @Post('quotations/from-panel-spec/:specId')
  @RequirePermissions('SALES:CREATE', 'CRM:CREATE')
  @ApiOperation({ summary: 'Auto-build quotation from engineering Panel Specification BOM' })
  createFromPanelSpec(
    @Param('specId') specId: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.createFromPanelSpec(specId, dto, req.user);
  }

  @Post('quotations/:id/revision')
  @RequirePermissions('SALES:CREATE', 'SALES:EDIT')
  @ApiOperation({ summary: 'Create revised quotation (e.g. REV-1, REV-2)' })
  createRevision(
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.createRevision(id, dto, req.user);
  }

  @Post('quotations/:id/revisions')
  @RequirePermissions('SALES:CREATE', 'SALES:EDIT')
  @ApiOperation({ summary: 'Create revised quotation alias' })
  createRevisions(
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.createRevision(id, dto, req.user);
  }

  @Patch('quotations/:id/status')
  @RequirePermissions('SALES:EDIT', 'SALES:APPROVE')
  @ApiOperation({ summary: 'Update quotation status (SENT, ACCEPTED, REJECTED)' })
  updateQuotationStatus(
    @Param('id') id: string,
    @Body() dto: { status: string; notes?: string },
    @Req() req: any,
  ) {
    return this.salesService.updateQuotationStatus(id, dto, req.user);
  }

  @Post('quotations/:id/convert-to-order')
  @RequirePermissions('SALES:EDIT', 'SALES:CREATE')
  @ApiOperation({ summary: '1-Click convert accepted quotation to confirmed Sales Order' })
  convertToSalesOrder(
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.convertToSalesOrder(id, dto, req.user);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SALES ORDERS
  // ─────────────────────────────────────────────────────────────────────────

  @Get('orders')
  @RequirePermissions('SALES:VIEW')
  @ApiOperation({ summary: 'List sales orders with customer and manufacturing statuses' })
  getSalesOrders(
    @Query('customerId') customerId?: string,
    @Query('status') status?: string,
    @Query('productionStatus') productionStatus?: string,
    @Query('search') search?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.salesService.getSalesOrders({
      customerId,
      status,
      productionStatus,
      search,
      page,
      limit,
    });
  }

  @Get('orders/:id')
  @RequirePermissions('SALES:VIEW')
  @ApiOperation({ summary: 'Get sales order detail with items and quotation link' })
  getSalesOrderById(@Param('id') id: string) {
    return this.salesService.getSalesOrderById(id);
  }

  @Patch('orders/:id/status')
  @RequirePermissions('SALES:EDIT')
  @ApiOperation({ summary: 'Update sales order and manufacturing dispatch status' })
  updateSalesOrderStatus(
    @Param('id') id: string,
    @Body() dto: { status?: string; productionStatus?: string; notes?: string },
    @Req() req: any,
  ) {
    return this.salesService.updateSalesOrderStatus(id, dto, req.user?.id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMMERCIAL TAX INVOICES & BILLING
  // ─────────────────────────────────────────────────────────────────────────

  @Get('invoices')
  @RequirePermissions('SALES:VIEW')
  @ApiOperation({ summary: 'List commercial tax invoices with payment status & customer filters' })
  getInvoices(
    @Query('customerId') customerId?: string,
    @Query('salesOrderId') salesOrderId?: string,
    @Query('status') status?: string,
    @Query('paymentStatus') paymentStatus?: string,
    @Query('search') search?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.salesService.getInvoices({
      customerId,
      salesOrderId,
      status,
      paymentStatus,
      search,
      page,
      limit,
    });
  }

  @Get('invoices/:id')
  @RequirePermissions('SALES:VIEW')
  @ApiOperation({ summary: 'Get invoice detail with items, customer and payments' })
  getInvoiceById(@Param('id') id: string) {
    return this.salesService.getInvoiceById(id);
  }

  @Post('invoices')
  @RequirePermissions('SALES:CREATE')
  @ApiOperation({ summary: 'Create new commercial tax invoice' })
  createInvoice(@Body() dto: any, @Req() req: any) {
    return this.salesService.createInvoice(dto, req.user?.id);
  }

  @Post('invoices/from-order/:orderId')
  @RequirePermissions('SALES:CREATE')
  @ApiOperation({ summary: '1-Click generate commercial tax invoice from confirmed Sales Order' })
  createInvoiceFromSalesOrder(
    @Param('orderId') orderId: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.createInvoiceFromSalesOrder(orderId, dto, req.user?.id);
  }

  @Post('invoices/:id/payments')
  @RequirePermissions('SALES:CREATE')
  @ApiOperation({ summary: 'Record customer payment / receipt against commercial tax invoice' })
  recordPayment(
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.recordPayment(id, dto, req.user?.id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCOUNTS & RECEIVABLES
  // ─────────────────────────────────────────────────────────────────────────

  @Get('accounts/summary')
  @RequirePermissions('SALES:VIEW')
  @ApiOperation({ summary: 'Accounts overview: total invoiced, collections, outstanding receivables' })
  getAccountsSummary() {
    return this.salesService.getAccountsSummary();
  }
}

