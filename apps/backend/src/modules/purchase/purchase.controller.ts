import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PurchaseService } from './purchase.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Purchase & Procurement')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/purchase')
export class PurchaseController {
  constructor(private readonly purchaseService: PurchaseService) {}

  // ─── 1. PURCHASE DASHBOARD ───────────────────────────────────────────────

  @Get('dashboard')
  @ApiOperation({ summary: 'Get Purchase & Procurement dashboard metrics and pending invoices' })
  getDashboard(@Query() query: any) {
    return this.purchaseService.getDashboardSummary(query);
  }

  // ─── 2. VENDOR EXTENDED PROFILE & REGISTRATION ────────────────────────────

  @Get('vendors/:id/profile')
  @ApiOperation({ summary: 'Get full vendor profile with contacts, addresses, banks & history' })
  getVendorProfile(@Param('id') id: string) {
    return this.purchaseService.getVendorFullProfile(id);
  }

  @Post('vendors/:id/contacts')
  @ApiOperation({ summary: 'Add contact to vendor master' })
  addVendorContact(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.addVendorContact(id, dto, req.user?.id);
  }

  @Post('vendors/:id/addresses')
  @ApiOperation({ summary: 'Add address to vendor master' })
  addVendorAddress(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.addVendorAddress(id, dto, req.user?.id);
  }

  @Post('vendors/:id/bank-accounts')
  @ApiOperation({ summary: 'Add bank account to vendor master' })
  addVendorBankAccount(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.addVendorBankAccount(id, dto, req.user?.id);
  }

  // ─── 3. PURCHASE REQUISITIONS (PR) ────────────────────────────────────────

  @Get('requisitions')
  @ApiOperation({ summary: 'List all Purchase Requisitions with pagination' })
  findAllRequisitions(@Query() query: any) {
    return this.purchaseService.findAllRequisitions(query);
  }

  @Post('requisitions')
  @ApiOperation({ summary: 'Create new Purchase Requisition' })
  createRequisition(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createRequisition(dto, req.user?.id, req.user?.fullName);
  }

  @Patch('requisitions/:id/status')
  @ApiOperation({ summary: 'Approve, reject or update PR status' })
  updateRequisitionStatus(@Param('id') id: string, @Body('status') status: string, @Req() req: any) {
    return this.purchaseService.updateRequisitionStatus(id, status, req.user?.id);
  }

  // ─── 4. RFQ & VENDOR QUOTATION COMPARISON ─────────────────────────────────

  @Get('rfqs')
  @ApiOperation({ summary: 'List RFQs with invited vendors and quotes' })
  findAllRFQs(@Query() query: any) {
    return this.purchaseService.findAllRFQs(query);
  }

  @Post('rfqs')
  @ApiOperation({ summary: 'Create new RFQ and invite vendors' })
  createRFQ(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createRFQ(dto, req.user?.id);
  }

  @Post('quotations')
  @ApiOperation({ summary: 'Record vendor quotation against RFQ' })
  addVendorQuotation(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.addVendorQuotation(dto, req.user?.id);
  }

  @Post('quotations/:id/select')
  @ApiOperation({ summary: 'Select preferred quotation with selection reason' })
  selectQuotation(
    @Param('id') id: string,
    @Body('selectionReason') reason: string,
    @Req() req: any,
  ) {
    return this.purchaseService.selectQuotation(id, reason, req.user?.id);
  }

  // ─── 5. PURCHASE ORDERS (PO) ──────────────────────────────────────────────

  @Get('orders')
  @ApiOperation({ summary: 'List Purchase Orders with search & filters' })
  findAllOrders(@Query() query: any) {
    return this.purchaseService.findAllPurchaseOrders(query);
  }

  @Get('orders/:id')
  @ApiOperation({ summary: 'Get full Purchase Order details and receiving status' })
  findOneOrder(@Param('id') id: string) {
    return this.purchaseService.findOnePurchaseOrder(id);
  }

  @Post('orders')
  @ApiOperation({ summary: 'Create Purchase Order' })
  createOrder(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createPurchaseOrder(dto, req.user?.id);
  }

  // ─── 6. INWARD ENTRY / GRN & PARTIAL RECEIVING ────────────────────────────

  @Get('inwards')
  @ApiOperation({ summary: 'List Inward Entries / GRNs' })
  findAllInwards(@Query() query: any) {
    return this.purchaseService.findAllInwards(query);
  }

  @Get('inwards/:id')
  @ApiOperation({ summary: 'Get Inward Entry / GRN detail' })
  findOneInward(@Param('id') id: string) {
    return this.purchaseService.findOneInward(id);
  }

  @Post('inwards')
  @ApiOperation({ summary: 'Create Inward Entry / GRN (supports partial receiving)' })
  createInward(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createInwardEntry(dto, req.user?.id, req.user?.fullName);
  }

  // ─── 7. QC INTEGRATION & INVENTORY STOCK ACCEPTANCE ───────────────────────

  @Post('inwards/items/:itemId/qc')
  @ApiOperation({
    summary:
      'Perform QC Inspection on inward line item. Only accepted qty posts to stock ledger.',
  })
  inspectQCItem(@Param('itemId') itemId: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.inspectQCItem(itemId, dto, req.user?.id);
  }

  // ─── 8. PURCHASE INVOICES ─────────────────────────────────────────────────

  @Get('invoices')
  @ApiOperation({ summary: 'List Purchase Invoices (filter by pendingOnly, status, vendor)' })
  findAllInvoices(@Query() query: any) {
    return this.purchaseService.findAllInvoices(query);
  }

  @Get('invoices/:id')
  @ApiOperation({ summary: 'Get Purchase Invoice details and payment trail' })
  findOneInvoice(@Param('id') id: string) {
    return this.purchaseService.findOneInvoice(id);
  }

  @Post('invoices')
  @ApiOperation({ summary: 'Create Purchase Invoice against PO, Inward, or Direct' })
  createInvoice(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createPurchaseInvoice(dto, req.user?.id);
  }

  // ─── 9. PAYMENTS & CHEQUE MANAGEMENT ─────────────────────────────────────

  @Post('payments')
  @ApiOperation({
    summary:
      'Record Purchase Payment. Updates invoice balance. Auto-creates Cheque if mode is CHEQUE.',
  })
  recordPayment(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.recordPurchasePayment(dto, req.user?.id);
  }

  @Get('cheques')
  @ApiOperation({ summary: 'List Cheque Management records' })
  findAllCheques(@Query() query: any) {
    return this.purchaseService.findAllCheques(query);
  }

  @Patch('cheques/:id/status')
  @ApiOperation({
    summary:
      'Update Cheque status (ISSUED, DEPOSITED, CLEARED, BOUNCED, CANCELLED). If BOUNCED, reverses payment.',
  })
  updateChequeStatus(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.updateChequeStatus(id, dto, req.user?.id);
  }

  // ─── 10. OUTWARD DOCUMENTS ────────────────────────────────────────────────

  @Get('outward')
  @ApiOperation({ summary: 'List Outward Documents (Material, Document, Sample, Repair, etc.)' })
  findAllOutwards(@Query() query: any) {
    return this.purchaseService.findAllOutwardDocuments(query);
  }

  @Post('outward')
  @ApiOperation({ summary: 'Create new Outward Document' })
  createOutward(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createOutwardDocument(dto, req.user?.id);
  }

  // ─── 11. PURCHASE RETURNS & STOCK REVERSALS ───────────────────────────────

  @Get('returns')
  @ApiOperation({ summary: 'List Purchase Returns' })
  findAllReturns(@Query() query: any) {
    return this.purchaseService.findAllPurchaseReturns(query);
  }

  @Post('returns')
  @ApiOperation({
    summary:
      'Create Purchase Return. Posts reversal stock transaction and adjusts invoice.',
  })
  createReturn(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createPurchaseReturn(dto, req.user?.id);
  }

  // ─── 12. REPORTS & OUTSTANDING PAYABLES ───────────────────────────────────

  @Get('reports/register')
  @ApiOperation({ summary: 'Purchase Register Report' })
  getRegister(@Query() query: any) {
    return this.purchaseService.getPurchaseRegister(query);
  }

  @Get('reports/payables')
  @ApiOperation({ summary: 'Outstanding Payables Report' })
  getPayables() {
    return this.purchaseService.getOutstandingPayables();
  }
}
