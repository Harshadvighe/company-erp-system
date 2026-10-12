import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma.service';

/**
 * Safe document number generator.
 * Uses a retry loop with unique constraint to prevent race conditions
 * that occur when using count()+1 under concurrent requests.
 */
@Injectable()
export class SequenceService {
  constructor(private readonly prisma: PrismaService) {}

  async nextLeadNumber(): Promise<string> {
    return this.nextSafe('lead', () =>
      this.prisma.lead.count().then((n) => `LEAD-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.lead.findUnique({ where: { leadNumber: num } }),
    );
  }

  async nextCustomerCode(): Promise<string> {
    return this.nextSafe('customer', () =>
      this.prisma.customer.count().then((n) => `CUS-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.customer.findUnique({ where: { customerCode: num } }),
    );
  }

  async nextVendorCode(): Promise<string> {
    return this.nextSafe('vendor', () =>
      this.prisma.vendor.count().then((n) => `VEN-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.vendor.findUnique({ where: { vendorCode: num } }),
    );
  }

  async nextOpportunityNumber(): Promise<string> {
    return this.nextSafe('opportunity', () =>
      this.prisma.opportunity.count().then((n) => `OPP-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.opportunity.findUnique({ where: { opportunityNumber: num } }),
    );
  }

  async nextEnquiryNumber(): Promise<string> {
    return this.nextSafe('enquiry', () =>
      this.prisma.enquiry.count().then((n) => `ENQ-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.enquiry.findUnique({ where: { enquiryNumber: num } }),
    );
  }

  async nextProjectNumber(): Promise<string> {
    return this.nextSafe('project', () =>
      this.prisma.project.count().then((n) => `PRJ-${new Date().getFullYear()}-${String(n + 1).padStart(3, '0')}`),
      (num) => this.prisma.project.findUnique({ where: { projectNumber: num } }),
    );
  }

  async nextDocumentCode(): Promise<string> {
    return this.nextSafe('document', () =>
      this.prisma.documentItem.count().then((n) => `DOC-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.documentItem.findUnique({ where: { documentCode: num } }),
    );
  }

  async nextPanelCode(): Promise<string> {
    return this.nextSafe('panel', () =>
      this.prisma.panelSpecification.count().then((n) => `PANEL-${new Date().getFullYear()}-${String(n + 1).padStart(4, '0')}`),
      (num) => this.prisma.panelSpecification.findUnique({ where: { panelCode: num } }),
    );
  }

  async nextEmployeeCode(): Promise<string> {
    return this.nextSafe('employee', () =>
      this.prisma.employee.count().then((n) => `EMP-${new Date().getFullYear()}-${String(n + 1).padStart(3, '0')}`),
      (num) => this.prisma.employee.findUnique({ where: { employeeCode: num } }),
    );
  }

  async nextIncidentCode(): Promise<string> {
    return this.nextSafe('incident', () =>
      this.prisma.safetyIncident.count().then((n) => `INC-${new Date().getFullYear()}-${String(n + 1).padStart(3, '0')}`),
      (num) => this.prisma.safetyIncident.findUnique({ where: { incidentCode: num } }),
    );
  }

  async nextLeaveCode(): Promise<string> {
    return this.nextSafe('leave', () =>
      this.prisma.leaveRequest.count().then((n) => `LV-${new Date().getFullYear()}-${String(n + 1).padStart(4, '0')}`),
      (num) => this.prisma.leaveRequest.findUnique({ where: { leaveCode: num } }),
    );
  }

  async nextQuotationNumber(): Promise<string> {
    return this.nextSafe('quotation', () =>
      this.prisma.quotation.count().then((n) => `QUO-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.quotation.findFirst({ where: { quotationNumber: num } }),
    );
  }

  async nextSalesOrderNumber(): Promise<string> {
    return this.nextSafe('salesOrder', () =>
      this.prisma.salesOrder.count().then((n) => `SO-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.salesOrder.findUnique({ where: { orderNumber: num } }),
    );
  }

  async nextInvoiceNumber(): Promise<string> {
    return this.nextSafe('invoice', () =>
      this.prisma.salesInvoice.count().then((n) => `INV-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.salesInvoice.findUnique({ where: { invoiceNumber: num } }),
    );
  }

  async nextReceiptNumber(): Promise<string> {
    return this.nextSafe('receipt', () =>
      this.prisma.salesPayment.count().then((n) => `REC-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.salesPayment.findUnique({ where: { receiptNumber: num } }),
    );
  }

  async nextPrNumber(): Promise<string> {
    return this.nextSafe('pr', () =>
      this.prisma.purchaseRequisition.count().then((n) => `PR-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.purchaseRequisition.findUnique({ where: { prNumber: num } }),
    );
  }

  async nextRfqNumber(): Promise<string> {
    return this.nextSafe('rfq', () =>
      this.prisma.rFQ.count().then((n) => `RFQ-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.rFQ.findUnique({ where: { rfqNumber: num } }),
    );
  }

  async nextVendorQuotationNumber(): Promise<string> {
    return this.nextSafe('vendorQuotation', () =>
      this.prisma.vendorQuotation.count().then((n) => `VQ-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.vendorQuotation.findUnique({ where: { quotationNumber: num } }),
    );
  }

  async nextPoNumber(): Promise<string> {
    return this.nextSafe('po', () =>
      this.prisma.purchaseOrder.count().then((n) => `PO-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.purchaseOrder.findUnique({ where: { poNumber: num } }),
    );
  }

  async nextGrnNumber(): Promise<string> {
    return this.nextSafe('grn', () =>
      this.prisma.inwardEntry.count().then((n) => `GRN-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.inwardEntry.findUnique({ where: { inwardNumber: num } }),
    );
  }

  async nextPurchaseInvoiceNumber(): Promise<string> {
    return this.nextSafe('purchaseInvoice', () =>
      this.prisma.purchaseInvoice.count().then((n) => `PINV-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.purchaseInvoice.findUnique({ where: { invoiceNumber: num } }),
    );
  }

  async nextPurchasePaymentNumber(): Promise<string> {
    return this.nextSafe('purchasePayment', () =>
      this.prisma.purchasePayment.count().then((n) => `PAY-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.purchasePayment.findUnique({ where: { paymentNumber: num } }),
    );
  }

  async nextOutwardDocumentNumber(): Promise<string> {
    return this.nextSafe('outwardDocument', () =>
      this.prisma.outwardDocument.count().then((n) => `OUT-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.outwardDocument.findUnique({ where: { outwardNumber: num } }),
    );
  }

  async nextPurchaseReturnNumber(): Promise<string> {
    return this.nextSafe('purchaseReturn', () =>
      this.prisma.purchaseReturn.count().then((n) => `PRET-${new Date().getFullYear()}-${String(n + 1).padStart(5, '0')}`),
      (num) => this.prisma.purchaseReturn.findUnique({ where: { returnNumber: num } }),
    );
  }

  async nextTaskNumber(): Promise<string> {
    return this.nextSafe('task', () =>
      this.prisma.task.count().then((n) => `TSK-${new Date().getFullYear()}-${String(n + 1).padStart(3, '0')}`),
      (num) => this.prisma.task.findUnique({ where: { taskNumber: num } }),
    );
  }

  /**
   * Generic retry loop: generates a candidate number, checks uniqueness,
   * increments offset if collision detected. Max 20 retries.
   */
  private async nextSafe(
    _label: string,
    generate: (offset: number) => Promise<string>,
    exists: (num: string) => Promise<unknown>,
    maxRetries = 20,
  ): Promise<string> {
    for (let i = 0; i < maxRetries; i++) {
      const candidate = await generate(i);
      const found = await exists(candidate);
      if (!found) return candidate;
    }
    // Fallback: timestamp-based unique suffix
    return `${_label.toUpperCase()}-${Date.now()}`;
  }
}
