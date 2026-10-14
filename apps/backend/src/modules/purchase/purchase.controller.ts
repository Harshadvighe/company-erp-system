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
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('Purchase & Procurement')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/purchase')
export class PurchaseController {
  constructor(private readonly purchaseService: PurchaseService) {}

  // ─── 1. PURCHASE DASHBOARD ───────────────────────────────────────────────

  @Get('dashboard')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'Get Purchase & Procurement dashboard metrics and pending invoices' })
  getDashboard(@Query() query: any) {
    return this.purchaseService.getDashboardSummary(query);
  }

  // ─── 2. VENDOR EXTENDED PROFILE & REGISTRATION ────────────────────────────

  @Get('vendors/:id/profile')
  @RequirePermissions('PURCHASE:VIEW', 'VENDORS:VIEW')
  @ApiOperation({ summary: 'Get full vendor profile with contacts, addresses, banks & history' })
  getVendorProfile(@Param('id') id: string) {
    return this.purchaseService.getVendorFullProfile(id);
  }

  @Post('vendors/:id/contacts')
  @RequirePermissions('PURCHASE:EDIT', 'VENDORS:EDIT')
  @ApiOperation({ summary: 'Add contact to vendor master' })
  addVendorContact(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.addVendorContact(id, dto, req.user?.id);
  }

  @Post('vendors/:id/addresses')
  @RequirePermissions('PURCHASE:EDIT', 'VENDORS:EDIT')
  @ApiOperation({ summary: 'Add address to vendor master' })
  addVendorAddress(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.addVendorAddress(id, dto, req.user?.id);
  }

  @Post('vendors/:id/bank-accounts')
  @RequirePermissions('PURCHASE:EDIT', 'VENDORS:EDIT')
  @ApiOperation({ summary: 'Add bank account to vendor master' })
  addVendorBankAccount(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.addVendorBankAccount(id, dto, req.user?.id);
  }

  // ─── 3. PURCHASE REQUISITIONS (PR) ────────────────────────────────────────

  @Get('requisitions')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'List all Purchase Requisitions with pagination' })
  findAllRequisitions(@Query() query: any) {
    return this.purchaseService.findAllRequisitions(query);
  }

  @Post('requisitions')
  @RequirePermissions('PURCHASE:CREATE')
  @ApiOperation({ summary: 'Create new Purchase Requisition' })
  createRequisition(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createRequisition(dto, req.user?.id, req.user?.fullName);
  }

  @Patch('requisitions/:id/status')
  @RequirePermissions('PURCHASE:APPROVE', 'PURCHASE:EDIT')
  @ApiOperation({ summary: 'Approve, reject or update PR status' })
  updateRequisitionStatus(@Param('id') id: string, @Body('status') status: string, @Req() req: any) {
    return this.purchaseService.updateRequisitionStatus(id, status, req.user?.id);
  }

  // ─── 4. RFQ & VENDOR QUOTATION COMPARISON ─────────────────────────────────

  @Get('rfqs')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'List RFQs with invited vendors and quotes' })
  findAllRFQs(@Query() query: any) {
    return this.purchaseService.findAllRFQs(query);
  }

  @Post('rfqs')
  @RequirePermissions('PURCHASE:CREATE')
  @ApiOperation({ summary: 'Create new RFQ and invite vendors' })
  createRFQ(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createRFQ(dto, req.user?.id);
  }

  @Post('quotations')
  @RequirePermissions('PURCHASE:CREATE')
  @ApiOperation({ summary: 'Record vendor quotation against RFQ' })
  addVendorQuotation(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.addVendorQuotation(dto, req.user?.id);
  }

  @Post('quotations/:id/select')
  @RequirePermissions('PURCHASE:APPROVE', 'PURCHASE:EDIT')
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
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'List Purchase Orders with search & filters' })
  findAllOrders(@Query() query: any) {
    return this.purchaseService.findAllPurchaseOrders(query);
  }

  @Get('orders/:id')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'Get full Purchase Order details and receiving status' })
  findOneOrder(@Param('id') id: string) {
    return this.purchaseService.findOnePurchaseOrder(id);
  }

  @Post('orders')
  @RequirePermissions('PURCHASE:CREATE')
  @ApiOperation({ summary: 'Create Purchase Order' })
  createOrder(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createPurchaseOrder(dto, req.user?.id);
  }

  // ─── 6. INWARD ENTRY / GRN & PARTIAL RECEIVING ────────────────────────────

  @Get('inwards')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'List Inward Entries / GRNs' })
  findAllInwards(@Query() query: any) {
    return this.purchaseService.findAllInwards(query);
  }

  @Get('inwards/:id')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'Get Inward Entry / GRN detail' })
  findOneInward(@Param('id') id: string) {
    return this.purchaseService.findOneInward(id);
  }

  @Post('inwards')
  @RequirePermissions('PURCHASE:CREATE')
  @ApiOperation({ summary: 'Create Inward Entry / GRN (supports partial receiving)' })
  createInward(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createInwardEntry(dto, req.user?.id, req.user?.fullName);
  }

  // ─── 7. QC INTEGRATION & INVENTORY STOCK ACCEPTANCE ───────────────────────

  @Post('inwards/items/:itemId/qc')
  @RequirePermissions('PURCHASE:REVIEW', 'PURCHASE:EDIT')
  @ApiOperation({
    summary:
      'Perform QC Inspection on inward line item. Only accepted qty posts to stock ledger.',
  })
  inspectQCItem(@Param('itemId') itemId: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.inspectQCItem(itemId, dto, req.user?.id);
  }

  // ─── 8. PURCHASE INVOICES ─────────────────────────────────────────────────

  @Get('invoices')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'List Purchase Invoices (filter by pendingOnly, status, vendor)' })
  findAllInvoices(@Query() query: any) {
    return this.purchaseService.findAllInvoices(query);
  }

  @Get('invoices/:id')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'Get Purchase Invoice details and payment trail' })
  findOneInvoice(@Param('id') id: string) {
    return this.purchaseService.findOneInvoice(id);
  }

  @Post('invoices')
  @RequirePermissions('PURCHASE:CREATE')
  @ApiOperation({ summary: 'Create Purchase Invoice against PO, Inward, or Direct' })
  createInvoice(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createPurchaseInvoice(dto, req.user?.id);
  }

  // ─── 9. PAYMENTS & CHEQUE MANAGEMENT ─────────────────────────────────────

  @Post('payments')
  @RequirePermissions('PURCHASE:CREATE', 'PURCHASE:EDIT')
  @ApiOperation({
    summary:
      'Record Purchase Payment. Updates invoice balance. Auto-creates Cheque if mode is CHEQUE.',
  })
  recordPayment(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.recordPurchasePayment(dto, req.user?.id);
  }

  @Get('cheques')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'List Cheque Management records' })
  findAllCheques(@Query() query: any) {
    return this.purchaseService.findAllCheques(query);
  }

  @Patch('cheques/:id/status')
  @RequirePermissions('PURCHASE:APPROVE', 'PURCHASE:EDIT')
  @ApiOperation({
    summary:
      'Update Cheque status (ISSUED, DEPOSITED, CLEARED, BOUNCED, CANCELLED). If BOUNCED, reverses payment.',
  })
  updateChequeStatus(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.purchaseService.updateChequeStatus(id, dto, req.user?.id);
  }

  // ─── 10. OUTWARD DOCUMENTS ────────────────────────────────────────────────

  @Get('outward')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'List Outward Documents (Material, Document, Sample, Repair, etc.)' })
  findAllOutwards(@Query() query: any) {
    return this.purchaseService.findAllOutwardDocuments(query);
  }

  @Post('outward')
  @RequirePermissions('PURCHASE:CREATE')
  @ApiOperation({ summary: 'Create new Outward Document' })
  createOutward(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createOutwardDocument(dto, req.user?.id);
  }

  // ─── 11. PURCHASE RETURNS & STOCK REVERSALS ───────────────────────────────

  @Get('returns')
  @RequirePermissions('PURCHASE:VIEW')
  @ApiOperation({ summary: 'List Purchase Returns' })
  findAllReturns(@Query() query: any) {
    return this.purchaseService.findAllPurchaseReturns(query);
  }

  @Post('returns')
  @RequirePermissions('PURCHASE:CREATE')
  @ApiOperation({
    summary:
      'Create Purchase Return. Posts reversal stock transaction and adjusts invoice.',
  })
  createReturn(@Body() dto: any, @Req() req: any) {
    return this.purchaseService.createPurchaseReturn(dto, req.user?.id);
  }

  // ─── 12. REPORTS & OUTSTANDING PAYABLES ───────────────────────────────────

  @Get('reports/register')
  @RequirePermissions('PURCHASE:VIEW', 'PURCHASE:EXPORT')
  @ApiOperation({ summary: 'Purchase Register Report' })
  getRegister(@Query() query: any) {
    return this.purchaseService.getPurchaseRegister(query);
  }

  @Get('reports/payables')
  @RequirePermissions('PURCHASE:VIEW', 'PURCHASE:EXPORT')
  @ApiOperation({ summary: 'Outstanding Payables Report' })
  getPayables() {
    return this.purchaseService.getOutstandingPayables();
  }
}
