import { Controller, Get, Post, Put, Patch, Delete, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { SalesService } from './sales.service';

@ApiTags('Sales & Quotations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller(['api/v1/sales', 'sales'])
export class SalesController {
  constructor(private readonly salesService: SalesService) {}

  // ─────────────────────────────────────────────────────────────────────────
  // QUOTATIONS
  // ─────────────────────────────────────────────────────────────────────────

  @Get('quotations')
  @ApiOperation({ summary: 'List commercial quotations with filters' })
  getQuotations(
    @Query('customerId') customerId?: string,
    @Query('opportunityId') opportunityId?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.salesService.getQuotations({
      customerId,
      opportunityId,
      status,
      search,
      page,
      limit,
    });
  }

  @Get('quotations/:id')
  @ApiOperation({ summary: 'Get quotation detail with items, customer 360 link and revisions' })
  getQuotationById(@Param('id') id: string) {
    return this.salesService.getQuotationById(id);
  }

  @Post('quotations')
  @ApiOperation({ summary: 'Create new commercial quotation (auto REV-0)' })
  createQuotation(@Body() dto: any, @Req() req: any) {
    return this.salesService.createQuotation(dto, req.user?.id);
  }

  @Post('quotations/from-panel-spec/:specId')
  @ApiOperation({ summary: 'Auto-build quotation from engineering Panel Specification BOM' })
  createFromPanelSpec(
    @Param('specId') specId: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.createFromPanelSpec(specId, dto, req.user?.id);
  }

  @Post('quotations/:id/revision')
  @ApiOperation({ summary: 'Create revised quotation (e.g. REV-1, REV-2)' })
  createRevision(
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.createRevision(id, dto, req.user?.id);
  }

  @Patch('quotations/:id/status')
  @ApiOperation({ summary: 'Update quotation status (SENT, ACCEPTED, REJECTED)' })
  updateQuotationStatus(
    @Param('id') id: string,
    @Body() dto: { status: string; notes?: string },
    @Req() req: any,
  ) {
    return this.salesService.updateQuotationStatus(id, dto, req.user?.id);
  }

  @Post('quotations/:id/convert-to-order')
  @ApiOperation({ summary: '1-Click convert accepted quotation to confirmed Sales Order' })
  convertToSalesOrder(
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.convertToSalesOrder(id, dto, req.user?.id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SALES ORDERS
  // ─────────────────────────────────────────────────────────────────────────

  @Get('orders')
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
  @ApiOperation({ summary: 'Get sales order detail with items and quotation link' })
  getSalesOrderById(@Param('id') id: string) {
    return this.salesService.getSalesOrderById(id);
  }

  @Patch('orders/:id/status')
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
  @ApiOperation({ summary: 'Get invoice detail with items, customer and payments' })
  getInvoiceById(@Param('id') id: string) {
    return this.salesService.getInvoiceById(id);
  }

  @Post('invoices')
  @ApiOperation({ summary: 'Create new commercial tax invoice' })
  createInvoice(@Body() dto: any, @Req() req: any) {
    return this.salesService.createInvoice(dto, req.user?.id);
  }

  @Post('invoices/from-order/:orderId')
  @ApiOperation({ summary: '1-Click generate commercial tax invoice from confirmed Sales Order' })
  createInvoiceFromSalesOrder(
    @Param('orderId') orderId: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.createInvoiceFromSalesOrder(orderId, dto, req.user?.id);
  }

  @Post('invoices/:id/payments')
  @ApiOperation({ summary: 'Record customer payment / receipt against commercial tax invoice' })
  recordPayment(
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.salesService.recordPayment(id, dto, req.user?.id);
  }

  @Put('invoices/:id')
  @ApiOperation({ summary: 'Update commercial tax invoice' })
  updateInvoice(
    @Param('id') id: string,
    @Body() dto: any,
  ) {
    return this.salesService.updateInvoice(id, dto);
  }

  @Delete('invoices/:id')
  @ApiOperation({ summary: 'Delete commercial tax invoice' })
  deleteInvoice(
    @Param('id') id: string,
  ) {
    return this.salesService.deleteInvoice(id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCOUNTS & RECEIVABLES
  // ─────────────────────────────────────────────────────────────────────────

  @Get('accounts/summary')
  @ApiOperation({ summary: 'Accounts overview: total invoiced, collections, outstanding receivables' })
  getAccountsSummary() {
    return this.salesService.getAccountsSummary();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BANK & CASH MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  @Get('bank-cash/accounts')
  @ApiOperation({ summary: 'List all registered bank and cash accounts with live computed balances' })
  getBankAccounts() {
    return this.salesService.getBankAccounts();
  }

  @Post('bank-cash/accounts')
  @ApiOperation({ summary: 'Add or update bank/cash account' })
  saveBankAccount(@Body() dto: any) {
    return this.salesService.saveBankAccount(dto);
  }

  @Delete('bank-cash/accounts/:id')
  @ApiOperation({ summary: 'Delete bank/cash account' })
  deleteBankAccount(@Param('id') id: string) {
    return this.salesService.deleteBankAccount(id);
  }

  @Get('bank-cash/transactions')
  @ApiOperation({ summary: 'List all bank & cash ledger transactions' })
  getBankTransactions() {
    return this.salesService.getBankTransactions();
  }

  @Post('bank-cash/transactions')
  @ApiOperation({ summary: 'Record new bank or cash transaction' })
  saveBankTransaction(@Body() dto: any) {
    return this.salesService.saveBankTransaction(dto);
  }

  @Delete('bank-cash/transactions/:id')
  @ApiOperation({ summary: 'Delete bank or cash transaction' })
  deleteBankTransaction(@Param('id') id: string) {
    return this.salesService.deleteBankTransaction(id);
  }

  @Get('bank-cash/summary')
  @ApiOperation({ summary: 'Bank & Cash total balance and summary metrics' })
  getBankCashSummary() {
    return this.salesService.getBankCashSummary();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPENSES MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  @Get('expenses')
  @ApiOperation({ summary: 'List all operational expenses' })
  getExpenses(@Query() query: any) {
    return this.salesService.getExpenses(query);
  }

  @Post('expenses')
  @ApiOperation({ summary: 'Add or update operational expense entry' })
  saveExpense(@Body() dto: any) {
    return this.salesService.saveExpense(dto);
  }

  @Delete('expenses/:id')
  @ApiOperation({ summary: 'Delete operational expense entry' })
  deleteExpense(@Param('id') id: string) {
    return this.salesService.deleteExpense(id);
  }

  @Get('expenses/summary')
  @ApiOperation({ summary: 'Get total expenses, this month, top category and breakdown' })
  getExpenseSummary() {
    return this.salesService.getExpenseSummary();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OUTWARD DOCUMENTS (OTHER DOCUMENTS)
  // ─────────────────────────────────────────────────────────────────────────

  @Get('outward')
  @ApiOperation({ summary: 'List outward dispatch documents with line items' })
  getOutwardDocuments(@Query() query: any) {
    return this.salesService.getOutwardDocuments(query);
  }

  @Get('outward/next-number')
  @ApiOperation({ summary: 'Generate next smart outward document sequence number' })
  getNextOutwardNumber(
    @Query('type') type?: string,
    @Query('date') date?: string,
  ) {
    return this.salesService.generateNextOutwardNumber(type, date);
  }

  @Get('outward/catalog')
  @ApiOperation({ summary: 'Get product/material catalog for outward document selection' })
  getOutwardCatalog() {
    return this.salesService.getOutwardCatalog();
  }

  @Get('outward/customers')
  @ApiOperation({ summary: 'Get customers list for outward document selection' })
  getOutwardCustomers() {
    return this.salesService.getOutwardCustomers();
  }

  @Post('outward')
  @ApiOperation({ summary: 'Create or update outward document entry and generate documents' })
  saveOutwardDocument(@Body() dto: any) {
    return this.salesService.saveOutwardDocument(dto);
  }

  @Delete('outward/:docNo')
  @ApiOperation({ summary: 'Delete outward document entries by document number' })
  deleteOutwardDocument(@Param('docNo') docNo: string) {
    return this.salesService.deleteOutwardDocument(docNo);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FINANCIAL REPORTS
  // ─────────────────────────────────────────────────────────────────────────

  @Get('financial-reports')
  @ApiOperation({ summary: 'Get consolidated financial reports for Dashboard, P&L, Cash Flow, Balance Sheet, and Outstanding' })
  getFinancialReports(@Query('period') period?: string) {
    return this.salesService.getFinancialReports(period);
  }
}


