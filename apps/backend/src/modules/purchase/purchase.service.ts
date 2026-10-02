import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

function round2(val: number): number {
  return Math.round((Number(val) || 0) * 100) / 100;
}

@Injectable()
export class PurchaseService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  // ══════════════════════════════════════════════════════════════════════════════
  // 1. PURCHASE DASHBOARD & SUMMARY METRICS
  // ══════════════════════════════════════════════════════════════════════════════

  async getDashboardSummary(query?: {
    financialYear?: string;
    fromDate?: string;
    toDate?: string;
    vendorId?: string;
    departmentId?: string;
  }) {
    const inwardWhere: any = {};
    const invoiceWhere: any = {};

    if (query?.vendorId) {
      inwardWhere.vendorId = query.vendorId;
      invoiceWhere.vendorId = query.vendorId;
    }
    if (query?.departmentId) {
      inwardWhere.departmentId = query.departmentId;
      invoiceWhere.departmentId = query.departmentId;
    }
    if (query?.financialYear) {
      invoiceWhere.financialYear = query.financialYear;
    }
    if (query?.fromDate || query?.toDate) {
      inwardWhere.inwardDate = {};
      invoiceWhere.invoiceDate = {};
      if (query?.fromDate) {
        inwardWhere.inwardDate.gte = new Date(query.fromDate);
        invoiceWhere.invoiceDate.gte = new Date(query.fromDate);
      }
      if (query?.toDate) {
        inwardWhere.inwardDate.lte = new Date(query.toDate);
        invoiceWhere.invoiceDate.lte = new Date(query.toDate);
      }
    }

    // Product Lines count (distinct products inwarded)
    const inwardItems = await this.prisma.inwardEntryItem.findMany({
      where: { inwardEntry: inwardWhere },
      select: { productId: true },
    });
    const uniqueProductIds = new Set(inwardItems.map((i) => i.productId));
    const productLines = uniqueProductIds.size;

    // Total Inward Amount
    const inwards = await this.prisma.inwardEntry.findMany({
      where: inwardWhere,
      select: { grandTotal: true },
    });
    const totalInwardAmount = round2(
      inwards.reduce((acc, curr) => acc + (curr.grandTotal || 0), 0),
    );

    // Pending Amount from Invoices (balanceAmount of unpaid/partially paid)
    const pendingInvoicesData = await this.prisma.purchaseInvoice.findMany({
      where: {
        ...invoiceWhere,
        balanceAmount: { gt: 0 },
        status: { notIn: ['CANCELLED', 'PAID'] },
      },
      select: { balanceAmount: true },
    });
    const pendingAmount = round2(
      pendingInvoicesData.reduce((acc, curr) => acc + (curr.balanceAmount || 0), 0),
    );

    // Counts for overview badges
    const [
      openRequisitions,
      pendingOrders,
      pendingQCInwards,
      pendingChequesCount,
    ] = await Promise.all([
      this.prisma.purchaseRequisition.count({ where: { status: 'SUBMITTED' } }),
      this.prisma.purchaseOrder.count({
        where: { status: { in: ['SUBMITTED', 'PENDING_APPROVAL', 'APPROVED'] } },
      }),
      this.prisma.inwardEntryItem.count({ where: { qcStatus: 'PENDING' } }),
      this.prisma.cheque.count({ where: { status: 'ISSUED' } }),
    ]);

    // Pending Invoices List (top 15 for dashboard)
    const pendingInvoices = await this.prisma.purchaseInvoice.findMany({
      where: {
        ...invoiceWhere,
        balanceAmount: { gt: 0 },
        status: { notIn: ['CANCELLED', 'PAID'] },
      },
      include: {
        vendor: { select: { id: true, companyName: true, vendorCode: true } },
      },
      orderBy: { invoiceDate: 'desc' },
      take: 15,
    });

    // Recent Inward Entries (top 10 for dashboard)
    const recentInwards = await this.prisma.inwardEntry.findMany({
      where: inwardWhere,
      include: {
        vendor: { select: { id: true, companyName: true, vendorCode: true } },
        items: {
          include: {
            product: { select: { id: true, name: true, sku: true } },
          },
        },
      },
      orderBy: { inwardDate: 'desc' },
      take: 10,
    });

    return {
      summary: {
        productLines,
        totalInwardAmount,
        pendingAmount,
        openRequisitions,
        pendingOrders,
        pendingQCInwards,
        pendingChequesCount,
      },
      pendingInvoices: pendingInvoices.map((inv) => ({
        id: inv.id,
        invoiceNumber: inv.invoiceNumber,
        vendor: inv.vendor?.companyName ?? 'Unknown Vendor',
        vendorCode: inv.vendor?.vendorCode ?? '',
        department: inv.departmentId ?? 'General',
        invoiceTotal: inv.totalAmount,
        paid: inv.paidAmount,
        pendingBalance: inv.balanceAmount,
        status: inv.status,
        dueDate: inv.dueDate,
        invoiceDate: inv.invoiceDate,
      })),
      recentInwards,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 2. VENDOR EXTENDED REGISTRATION & DETAILS
  // ══════════════════════════════════════════════════════════════════════════════

  async addVendorContact(vendorId: string, dto: any, userId?: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId } });
    if (!vendor) throw new NotFoundException(`Vendor ${vendorId} not found`);

    if (dto.isPrimary) {
      await this.prisma.vendorContact.updateMany({
        where: { vendorId },
        data: { isPrimary: false },
      });
    }

    const contact = await this.prisma.vendorContact.create({
      data: {
        vendorId,
        contactPerson: dto.contactPerson,
        designation: dto.designation,
        mobile: dto.mobile,
        alternateMobile: dto.alternateMobile,
        email: dto.email,
        isPrimary: dto.isPrimary ?? false,
      },
    });

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'VENDORS',
      entityType: 'VendorContact',
      entityId: contact.id,
      details: `Added contact ${contact.contactPerson} to vendor ${vendor.companyName}`,
    });

    return contact;
  }

  async addVendorAddress(vendorId: string, dto: any, userId?: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId } });
    if (!vendor) throw new NotFoundException(`Vendor ${vendorId} not found`);

    if (dto.isDefault) {
      await this.prisma.vendorAddress.updateMany({
        where: { vendorId },
        data: { isDefault: false },
      });
    }

    const address = await this.prisma.vendorAddress.create({
      data: {
        vendorId,
        addressType: dto.addressType || 'BILLING',
        addressLine: dto.addressLine,
        country: dto.country || 'India',
        state: dto.state,
        district: dto.district,
        city: dto.city,
        location: dto.location,
        pincode: dto.pincode,
        isDefault: dto.isDefault ?? false,
      },
    });

    return address;
  }

  async addVendorBankAccount(vendorId: string, dto: any, userId?: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId } });
    if (!vendor) throw new NotFoundException(`Vendor ${vendorId} not found`);

    if (dto.isPrimary) {
      await this.prisma.vendorBankAccount.updateMany({
        where: { vendorId },
        data: { isPrimary: false },
      });
    }

    const account = await this.prisma.vendorBankAccount.create({
      data: {
        vendorId,
        accountHolder: dto.accountHolder,
        bankName: dto.bankName,
        accountNumber: dto.accountNumber,
        ifscCode: dto.ifscCode,
        branch: dto.branch,
        accountType: dto.accountType || 'CURRENT',
        isPrimary: dto.isPrimary ?? false,
      },
    });

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'VENDORS',
      entityType: 'VendorBankAccount',
      entityId: account.id,
      details: `Added bank account ${account.accountNumber} (${account.bankName}) for vendor ${vendor.companyName}`,
    });

    return account;
  }

  async getVendorFullProfile(vendorId: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id: vendorId },
      include: {
        contacts: true,
        addresses: true,
        bankAccounts: true,
        purchaseOrders: { take: 10, orderBy: { createdAt: 'desc' } },
        inwardEntries: { take: 10, orderBy: { createdAt: 'desc' } },
        purchaseInvoices: { take: 10, orderBy: { createdAt: 'desc' } },
      },
    });
    if (!vendor) throw new NotFoundException(`Vendor ${vendorId} not found`);
    return vendor;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 3. PURCHASE REQUISITIONS (PR)
  // ══════════════════════════════════════════════════════════════════════════════

  async findAllRequisitions(query?: any) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.search) {
      where.OR = [
        { prNumber: { contains: query.search } },
        { requesterName: { contains: query.search } },
        { purpose: { contains: query.search } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.purchaseRequisition.findMany({
        where,
        skip,
        take: limit,
        include: { items: { include: { product: true } } },
        orderBy: { date: 'desc' },
      }),
      this.prisma.purchaseRequisition.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async createRequisition(dto: any, userId?: string, userName?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.purchaseRequisition.count();
    const prNumber = `PR-${year}-${String(count + 1).padStart(5, '0')}`;

    let totalEstimated = 0;
    const itemsData = (dto.items || []).map((it: any) => {
      const qty = Number(it.quantity) || 1;
      const rate = Number(it.estimatedRate) || 0;
      const amount = round2(qty * rate);
      totalEstimated += amount;
      return {
        productId: it.productId,
        itemDescription: it.itemDescription || it.productName || 'Purchase Item',
        quantity: qty,
        unit: it.unit || 'Nos',
        estimatedRate: rate,
        estimatedAmount: amount,
      };
    });

    const pr = await this.prisma.purchaseRequisition.create({
      data: {
        prNumber,
        requesterId: userId,
        requesterName: userName || dto.requesterName || 'Admin User',
        departmentId: dto.departmentId,
        date: dto.date ? new Date(dto.date) : new Date(),
        requiredDate: dto.requiredDate ? new Date(dto.requiredDate) : null,
        priority: dto.priority || 'MEDIUM',
        purpose: dto.purpose,
        estimatedCost: round2(totalEstimated),
        status: dto.status || 'SUBMITTED',
        remarks: dto.remarks,
        items: { create: itemsData },
      },
      include: { items: true },
    });

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'PURCHASE',
      entityType: 'PurchaseRequisition',
      entityId: pr.id,
      details: `Created PR ${pr.prNumber} with estimated amount ₹${pr.estimatedCost}`,
    });

    return pr;
  }

  async updateRequisitionStatus(id: string, status: string, userId?: string) {
    const pr = await this.prisma.purchaseRequisition.findUnique({ where: { id } });
    if (!pr) throw new NotFoundException('Requisition not found');

    const updated = await this.prisma.purchaseRequisition.update({
      where: { id },
      data: {
        status,
        approvedBy: status === 'APPROVED' ? userId : pr.approvedBy,
        approvalDate: status === 'APPROVED' ? new Date() : pr.approvalDate,
      },
    });

    await this.auditService.log({
      userId,
      action: 'UPDATE',
      module: 'PURCHASE',
      entityType: 'PurchaseRequisition',
      entityId: id,
      details: `Updated PR ${pr.prNumber} status to ${status}`,
    });

    return updated;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 4. RFQ & VENDOR QUOTATION COMPARISON
  // ══════════════════════════════════════════════════════════════════════════════

  async findAllRFQs(query?: any) {
    const where: any = {};
    if (query?.status) where.status = query.status;

    return this.prisma.rFQ.findMany({
      where,
      include: {
        items: { include: { product: true } },
        vendors: { include: { vendor: true } },
        quotations: { include: { vendor: true, items: true } },
      },
      orderBy: { date: 'desc' },
    });
  }

  async createRFQ(dto: any, userId?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.rFQ.count();
    const rfqNumber = `RFQ-${year}-${String(count + 1).padStart(5, '0')}`;

    const items = (dto.items || []).map((i: any) => ({
      productId: i.productId,
      itemDescription: i.itemDescription || 'Material Item',
      quantity: Number(i.quantity) || 1,
      unit: i.unit || 'Nos',
    }));

    const vendorIds = (dto.vendorIds || []).map((vId: string) => ({
      vendorId: vId,
      status: 'INVITED',
    }));

    const rfq = await this.prisma.rFQ.create({
      data: {
        rfqNumber,
        date: dto.date ? new Date(dto.date) : new Date(),
        departmentId: dto.departmentId,
        requesterName: dto.requesterName || 'Procurement Officer',
        requiredDate: dto.requiredDate ? new Date(dto.requiredDate) : null,
        closingDate: dto.closingDate ? new Date(dto.closingDate) : null,
        remarks: dto.remarks,
        items: { create: items },
        vendors: { create: vendorIds },
      },
      include: { items: true, vendors: true },
    });

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'PURCHASE',
      entityType: 'RFQ',
      entityId: rfq.id,
      details: `Created RFQ ${rfq.rfqNumber}`,
    });

    return rfq;
  }

  async addVendorQuotation(dto: any, userId?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.vendorQuotation.count();
    const quotationNumber = dto.quotationNumber || `VQ-${year}-${String(count + 1).padStart(5, '0')}`;

    let subtotal = 0;
    let taxAmount = 0;

    const items = (dto.items || []).map((it: any) => {
      const qty = Number(it.quantity) || 1;
      const rate = Number(it.rate) || 0;
      const discount = Number(it.discount) || 0;
      const base = round2(qty * rate - discount);
      const taxRate = Number(it.taxRate) || 0;
      const tax = round2((base * taxRate) / 100);
      const itemTotal = round2(base + tax);

      subtotal += base;
      taxAmount += tax;

      return {
        productId: it.productId,
        itemDescription: it.itemDescription || 'Item',
        quantity: qty,
        unit: it.unit || 'Nos',
        rate,
        discount,
        taxRate,
        taxAmount: tax,
        totalAmount: itemTotal,
      };
    });

    const totalAmount = round2(subtotal + taxAmount);

    const quotation = await this.prisma.vendorQuotation.create({
      data: {
        quotationNumber,
        vendorId: dto.vendorId,
        rfqId: dto.rfqId,
        date: dto.date ? new Date(dto.date) : new Date(),
        validityDate: dto.validityDate ? new Date(dto.validityDate) : null,
        deliveryTime: dto.deliveryTime,
        paymentTerms: dto.paymentTerms || 'NET_30',
        subtotal: round2(subtotal),
        discount: Number(dto.discount || 0),
        taxAmount: round2(taxAmount),
        totalAmount,
        remarks: dto.remarks,
        items: { create: items },
      },
      include: { items: true, vendor: true },
    });

    return quotation;
  }

  async selectQuotation(quotationId: string, selectionReason: string, userId?: string) {
    const quote = await this.prisma.vendorQuotation.findUnique({
      where: { id: quotationId },
    });
    if (!quote) throw new NotFoundException('Quotation not found');

    if (quote.rfqId) {
      await this.prisma.vendorQuotation.updateMany({
        where: { rfqId: quote.rfqId },
        data: { isSelected: false },
      });
    }

    const updated = await this.prisma.vendorQuotation.update({
      where: { id: quotationId },
      data: { isSelected: true, selectionReason },
    });

    await this.auditService.log({
      userId,
      action: 'APPROVE',
      module: 'PURCHASE',
      entityType: 'VendorQuotation',
      entityId: quotationId,
      details: `Selected Quotation ${quote.quotationNumber}. Reason: ${selectionReason}`,
    });

    return updated;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 5. PURCHASE ORDERS (PO)
  // ══════════════════════════════════════════════════════════════════════════════

  async findAllPurchaseOrders(query?: any) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.vendorId) where.vendorId = query.vendorId;
    if (query?.search) {
      where.OR = [
        { poNumber: { contains: query.search } },
        { vendor: { companyName: { contains: query.search } } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.purchaseOrder.findMany({
        where,
        skip,
        take: limit,
        include: {
          vendor: true,
          items: { include: { product: true } },
          inwardEntries: { select: { id: true, inwardNumber: true, status: true } },
        },
        orderBy: { date: 'desc' },
      }),
      this.prisma.purchaseOrder.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async findOnePurchaseOrder(id: string) {
    const po = await this.prisma.purchaseOrder.findUnique({
      where: { id },
      include: {
        vendor: true,
        items: { include: { product: true } },
        inwardEntries: {
          include: {
            items: true,
          },
        },
        purchaseInvoices: true,
      },
    });
    if (!po) throw new NotFoundException(`Purchase Order ${id} not found`);
    return po;
  }

  async createPurchaseOrder(dto: any, userId?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.purchaseOrder.count();
    const poNumber = `PO-${year}-${String(count + 1).padStart(5, '0')}`;

    let subtotal = 0;
    let taxAmount = 0;
    const items = (dto.items || []).map((it: any) => {
      const qty = Number(it.orderedQuantity || it.quantity) || 1;
      if (qty <= 0) throw new BadRequestException('Ordered quantity must be greater than 0');
      const rate = Number(it.rate) || 0;
      const discount = Number(it.discount) || 0;
      const base = round2(qty * rate - discount);
      const taxRate = Number(it.taxRate) || 0;
      const tax = round2((base * taxRate) / 100);
      const total = round2(base + tax);

      subtotal += base;
      taxAmount += tax;

      return {
        productId: it.productId,
        itemDescription: it.itemDescription || it.productName || 'Purchase Order Item',
        orderedQuantity: qty,
        receivedQuantity: 0,
        unit: it.unit || 'Nos',
        rate,
        discount,
        taxRate,
        taxAmount: tax,
        totalAmount: total,
      };
    });

    const totalAmount = round2(subtotal + taxAmount);

    const po = await this.prisma.purchaseOrder.create({
      data: {
        poNumber,
        vendorId: dto.vendorId,
        rfqId: dto.rfqId,
        quotationId: dto.quotationId,
        date: dto.date ? new Date(dto.date) : new Date(),
        expectedDelivery: dto.expectedDelivery ? new Date(dto.expectedDelivery) : null,
        departmentId: dto.departmentId,
        warehouseId: dto.warehouseId,
        paymentTerms: dto.paymentTerms || 'NET_30',
        subtotal: round2(subtotal),
        discount: Number(dto.discount || 0),
        taxAmount: round2(taxAmount),
        totalAmount,
        status: dto.status || 'APPROVED',
        remarks: dto.remarks,
        items: { create: items },
      },
      include: { items: true, vendor: true },
    });

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'PURCHASE',
      entityType: 'PurchaseOrder',
      entityId: po.id,
      details: `Created Purchase Order ${po.poNumber} for vendor ${po.vendor.companyName}, Total: ₹${po.totalAmount}`,
    });

    return po;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 6. INWARD ENTRY / GRN & PARTIAL RECEIVING WORKFLOW
  // ══════════════════════════════════════════════════════════════════════════════

  async findAllInwards(query?: any) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.vendorId) where.vendorId = query.vendorId;
    if (query?.status) where.status = query.status;
    if (query?.search) {
      where.OR = [
        { inwardNumber: { contains: query.search } },
        { vendorInvoiceNumber: { contains: query.search } },
        { vendor: { companyName: { contains: query.search } } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.inwardEntry.findMany({
        where,
        skip,
        take: limit,
        include: {
          vendor: true,
          purchaseOrder: { select: { poNumber: true } },
          warehouse: { select: { name: true } },
          items: { include: { product: true } },
        },
        orderBy: { inwardDate: 'desc' },
      }),
      this.prisma.inwardEntry.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async findOneInward(id: string) {
    const inward = await this.prisma.inwardEntry.findUnique({
      where: { id },
      include: {
        vendor: true,
        purchaseOrder: { include: { items: true } },
        warehouse: true,
        items: { include: { product: true } },
        purchaseInvoices: true,
      },
    });
    if (!inward) throw new NotFoundException(`Inward Entry ${id} not found`);
    return inward;
  }

  async createInwardEntry(dto: any, userId?: string, userName?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.inwardEntry.count();
    const inwardNumber = `GRN-${year}-${String(count + 1).padStart(5, '0')}`;

    if (!dto.vendorId) throw new BadRequestException('Vendor is required for Inward Entry');
    if (!dto.vendorInvoiceNumber) {
      throw new BadRequestException('Vendor Invoice Number is required');
    }

    let subtotal = 0;
    let taxAmount = 0;

    const items = (dto.items || []).map((it: any) => {
      const qty = Number(it.quantity) || 0;
      if (qty <= 0) throw new BadRequestException('Inward quantity must be greater than 0');
      const rate = Number(it.rate) || 0;
      const discount = Number(it.discount) || 0;
      const base = round2(qty * rate - discount);
      const taxRate = Number(it.taxRate) || 0;
      const tax = round2((base * taxRate) / 100);
      const amount = round2(base + tax);

      subtotal += base;
      taxAmount += tax;

      const qcRequired = it.qcRequired ?? true;
      return {
        productId: it.productId,
        poItemId: it.poItemId,
        quantity: qty,
        unit: it.unit || 'Nos',
        rate,
        discount,
        taxRate,
        taxAmount: tax,
        amount,
        batchNumber: it.batchNumber,
        serialNumber: it.serialNumber,
        expiryDate: it.expiryDate ? new Date(it.expiryDate) : null,
        qcRequired,
        qcStatus: qcRequired ? 'PENDING' : 'ACCEPTED',
        acceptedQuantity: qcRequired ? 0 : qty,
        rejectedQuantity: 0,
        stockUpdated: false,
      };
    });

    const grandTotal = round2(subtotal + taxAmount);

    const inward = await this.prisma.inwardEntry.create({
      data: {
        inwardNumber,
        inwardDate: dto.inwardDate ? new Date(dto.inwardDate) : new Date(),
        vendorId: dto.vendorId,
        purchaseOrderId: dto.purchaseOrderId,
        vendorInvoiceNumber: dto.vendorInvoiceNumber,
        invoiceDate: dto.invoiceDate ? new Date(dto.invoiceDate) : null,
        departmentId: dto.departmentId,
        warehouseId: dto.warehouseId,
        receivedBy: userName || dto.receivedBy || 'Store Incharge',
        transporter: dto.transporter,
        vehicleNumber: dto.vehicleNumber,
        lrNumber: dto.lrNumber,
        deliveryChallanNumber: dto.deliveryChallanNumber,
        subtotal: round2(subtotal),
        discount: Number(dto.discount || 0),
        taxAmount: round2(taxAmount),
        grandTotal,
        remarks: dto.remarks,
        attachmentUrl: dto.attachmentUrl,
        status: items.some((i) => i.qcRequired) ? 'QC_PENDING' : 'QC_COMPLETED',
        items: { create: items },
      },
      include: { items: true, vendor: true },
    });

    // Partial receiving updates on Purchase Order items
    if (dto.purchaseOrderId) {
      await this.updatePOReceivedStatus(dto.purchaseOrderId, inward.items);
    }

    // Auto-update stock for items where QC is NOT required
    const warehouseId = dto.warehouseId || (await this.getDefaultWarehouseId());
    for (const item of inward.items) {
      if (!item.qcRequired && !item.stockUpdated) {
        await this.postStockIn(
          item.productId,
          warehouseId,
          item.quantity,
          item.unit,
          item.rate,
          'INWARD',
          inward.id,
          userId,
          `Direct GRN ${inward.inwardNumber} (No QC)`,
        );
        await this.prisma.inwardEntryItem.update({
          where: { id: item.id },
          data: { stockUpdated: true },
        });
      }
    }

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'INWARD_MANAGE',
      entityType: 'InwardEntry',
      entityId: inward.id,
      details: `Created Inward Entry ${inward.inwardNumber} with ${inward.items.length} items. Total: ₹${inward.grandTotal}`,
    });

    return inward;
  }

  private async updatePOReceivedStatus(poId: string, inwardItems: any[]) {
    const po = await this.prisma.purchaseOrder.findUnique({
      where: { id: poId },
      include: { items: true },
    });
    if (!po) return;

    for (const invItem of inwardItems) {
      if (invItem.poItemId) {
        const poItem = po.items.find((p) => p.id === invItem.poItemId);
        if (poItem) {
          const newRec = poItem.receivedQuantity + invItem.quantity;
          await this.prisma.purchaseOrderItem.update({
            where: { id: poItem.id },
            data: { receivedQuantity: newRec },
          });
        }
      }
    }

    // Check if entire PO is completed
    const updatedPo = await this.prisma.purchaseOrder.findUnique({
      where: { id: poId },
      include: { items: true },
    });
    if (updatedPo) {
      const allCompleted = updatedPo.items.every(
        (i) => i.receivedQuantity >= i.orderedQuantity,
      );
      const anyReceived = updatedPo.items.some((i) => i.receivedQuantity > 0);

      await this.prisma.purchaseOrder.update({
        where: { id: poId },
        data: {
          status: allCompleted
            ? 'COMPLETED'
            : anyReceived
            ? 'PARTIALLY_RECEIVED'
            : updatedPo.status,
        },
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 7. QC INTEGRATION & INVENTORY STOCK POSTING
  // ══════════════════════════════════════════════════════════════════════════════

  async inspectQCItem(
    itemId: string,
    dto: {
      qcStatus: 'ACCEPTED' | 'PARTIALLY_ACCEPTED' | 'REJECTED';
      acceptedQuantity: number;
      rejectedQuantity: number;
      rejectionReason?: string;
      inspectorName?: string;
    },
    userId?: string,
  ) {
    const item = await this.prisma.inwardEntryItem.findUnique({
      where: { id: itemId },
      include: { inwardEntry: true },
    });
    if (!item) throw new NotFoundException('Inward item not found');

    const totalInspected =
      Number(dto.acceptedQuantity) + Number(dto.rejectedQuantity);
    if (totalInspected > item.quantity) {
      throw new BadRequestException(
        `Accepted (${dto.acceptedQuantity}) + Rejected (${dto.rejectedQuantity}) cannot exceed received quantity (${item.quantity})`,
      );
    }

    const updatedItem = await this.prisma.inwardEntryItem.update({
      where: { id: itemId },
      data: {
        qcStatus: dto.qcStatus,
        acceptedQuantity: Number(dto.acceptedQuantity),
        rejectedQuantity: Number(dto.rejectedQuantity),
        rejectionReason: dto.rejectionReason,
        inspectedBy: dto.inspectorName || 'QC Inspector',
        inspectionDate: new Date(),
      },
    });

    // RULE: If acceptedQuantity > 0, post to Stock Ledger!
    // Rejected material MUST NOT become available stock.
    if (dto.acceptedQuantity > 0 && !item.stockUpdated) {
      const warehouseId =
        item.inwardEntry.warehouseId || (await this.getDefaultWarehouseId());
      await this.postStockIn(
        item.productId,
        warehouseId,
        dto.acceptedQuantity,
        item.unit,
        item.rate,
        'INWARD',
        item.inwardEntryId,
        userId,
        `GRN QC Passed: ${item.inwardEntry.inwardNumber}`,
      );

      await this.prisma.inwardEntryItem.update({
        where: { id: itemId },
        data: { stockUpdated: true },
      });
    }

    // Check if entire inward is QC completed
    const allInwardItems = await this.prisma.inwardEntryItem.findMany({
      where: { inwardEntryId: item.inwardEntryId },
    });
    const allDone = allInwardItems.every((i) => i.qcStatus !== 'PENDING');
    if (allDone) {
      await this.prisma.inwardEntry.update({
        where: { id: item.inwardEntryId },
        data: { status: 'QC_COMPLETED' },
      });
    }

    await this.auditService.log({
      userId,
      action: 'UPDATE',
      module: 'INWARD_MANAGE',
      entityType: 'InwardEntryItem',
      entityId: itemId,
      details: `QC Inspection: Item ${item.productId} -> ${dto.qcStatus}. Accepted: ${dto.acceptedQuantity}, Rejected: ${dto.rejectedQuantity}`,
    });

    return updatedItem;
  }

  private async postStockIn(
    productId: string,
    warehouseId: string,
    quantity: number,
    unit: string,
    unitCost: number,
    referenceType: string,
    referenceId: string,
    userId?: string,
    notes?: string,
  ) {
    const totalCost = round2(quantity * unitCost);

    // 1. Create Stock Transaction Ledger record
    await this.prisma.stockTransaction.create({
      data: {
        productId,
        warehouseId,
        transactionType: 'INWARD_GRN',
        referenceType,
        referenceId,
        quantity,
        unit,
        unitCost,
        totalCost,
        userId,
        notes,
      },
    });

    // 2. Increase currentStock in Product
    await this.prisma.product.update({
      where: { id: productId },
      data: { currentStock: { increment: Math.round(quantity) } },
    });

    // 3. Upsert StockItem in Warehouse
    await this.prisma.stockItem.upsert({
      where: { warehouseId_productId: { warehouseId, productId } },
      create: {
        warehouseId,
        productId,
        currentQuantity: Math.round(quantity),
      },
      update: {
        currentQuantity: { increment: Math.round(quantity) },
      },
    });
  }

  private async getDefaultWarehouseId(): Promise<string> {
    let wh = await this.prisma.warehouse.findFirst();
    if (!wh) {
      wh = await this.prisma.warehouse.create({
        data: {
          code: 'WH-MAIN',
          name: 'Main Plant Warehouse',
          location: 'Pune Facility',
        },
      });
    }
    return wh.id;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 8. PURCHASE INVOICES & PENDING BALANCES
  // ══════════════════════════════════════════════════════════════════════════════

  async findAllInvoices(query?: any) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.vendorId) where.vendorId = query.vendorId;
    if (query?.pendingOnly === 'true') {
      where.balanceAmount = { gt: 0 };
      where.status = { notIn: ['PAID', 'CANCELLED'] };
    }
    if (query?.search) {
      where.OR = [
        { invoiceNumber: { contains: query.search } },
        { vendor: { companyName: { contains: query.search } } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.purchaseInvoice.findMany({
        where,
        skip,
        take: limit,
        include: {
          vendor: true,
          purchaseOrder: { select: { poNumber: true } },
          inwardEntry: { select: { inwardNumber: true } },
          payments: true,
          items: true,
        },
        orderBy: { invoiceDate: 'desc' },
      }),
      this.prisma.purchaseInvoice.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async findOneInvoice(id: string) {
    const invoice = await this.prisma.purchaseInvoice.findUnique({
      where: { id },
      include: {
        vendor: true,
        purchaseOrder: true,
        inwardEntry: { include: { items: true } },
        items: true,
        payments: { include: { cheques: true } },
        cheques: true,
        purchaseReturns: true,
      },
    });
    if (!invoice) throw new NotFoundException(`Invoice ${id} not found`);
    return invoice;
  }

  async createPurchaseInvoice(dto: any, userId?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.purchaseInvoice.count();
    const invoiceNumber = dto.invoiceNumber || `PINV-${year}-${String(count + 1).padStart(5, '0')}`;

    let subtotal = 0;
    let taxAmount = 0;

    const items = (dto.items || []).map((it: any) => {
      const qty = Number(it.quantity) || 1;
      const rate = Number(it.rate) || 0;
      const discount = Number(it.discount) || 0;
      const base = round2(qty * rate - discount);
      const taxRate = Number(it.taxRate) || 0;
      const tax = round2((base * taxRate) / 100);
      const amount = round2(base + tax);

      subtotal += base;
      taxAmount += tax;

      return {
        productId: it.productId,
        itemDescription: it.itemDescription || it.productName || 'Material Line',
        quantity: qty,
        unit: it.unit || 'Nos',
        rate,
        discount,
        taxRate,
        taxAmount: tax,
        amount,
      };
    });

    const totalAmount = round2(subtotal + taxAmount);

    const invoice = await this.prisma.purchaseInvoice.create({
      data: {
        invoiceNumber,
        vendorId: dto.vendorId,
        purchaseOrderId: dto.purchaseOrderId,
        inwardEntryId: dto.inwardEntryId,
        departmentId: dto.departmentId,
        financialYear: dto.financialYear || `${year}-${String(year + 1).slice(2)}`,
        invoiceDate: dto.invoiceDate ? new Date(dto.invoiceDate) : new Date(),
        dueDate: dto.dueDate ? new Date(dto.dueDate) : null,
        subtotal: round2(subtotal),
        discount: Number(dto.discount || 0),
        taxAmount: round2(taxAmount),
        totalAmount,
        paidAmount: 0,
        balanceAmount: totalAmount,
        status: 'UNPAID',
        attachmentUrl: dto.attachmentUrl,
        remarks: dto.remarks,
        items: { create: items },
      },
      include: { items: true, vendor: true },
    });

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'PURCHASE',
      entityType: 'PurchaseInvoice',
      entityId: invoice.id,
      details: `Created Purchase Invoice ${invoice.invoiceNumber}, Amount: ₹${invoice.totalAmount}`,
    });

    return invoice;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 9. PURCHASE PAYMENTS & CHEQUE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════════

  async recordPurchasePayment(dto: any, userId?: string) {
    const invoice = await this.prisma.purchaseInvoice.findUnique({
      where: { id: dto.purchaseInvoiceId },
      include: { vendor: true },
    });
    if (!invoice) throw new NotFoundException('Purchase Invoice not found');

    const paymentAmount = round2(Number(dto.amount));
    if (paymentAmount <= 0) {
      throw new BadRequestException('Payment amount must be greater than 0');
    }

    // Validation: Cannot exceed pending balance unless explicitly authorized
    if (paymentAmount > invoice.balanceAmount && !dto.allowOverpayment) {
      throw new BadRequestException(
        `Payment amount (₹${paymentAmount}) exceeds pending invoice balance (₹${invoice.balanceAmount})`,
      );
    }

    const year = new Date().getFullYear();
    const count = await this.prisma.purchasePayment.count();
    const paymentNumber = `PAY-${year}-${String(count + 1).padStart(5, '0')}`;

    // 1. Create Payment record
    const payment = await this.prisma.purchasePayment.create({
      data: {
        paymentNumber,
        vendorId: invoice.vendorId,
        purchaseInvoiceId: invoice.id,
        paymentDate: dto.paymentDate ? new Date(dto.paymentDate) : new Date(),
        amount: paymentAmount,
        paymentMode: dto.paymentMode || 'BANK_TRANSFER',
        bankAccount: dto.bankAccount,
        referenceNumber: dto.referenceNumber,
        transactionNumber: dto.transactionNumber,
        remarks: dto.remarks,
        attachmentUrl: dto.attachmentUrl,
        status: 'COMPLETED',
      },
    });

    // 2. If Payment Mode is CHEQUE, automatically register the cheque
    let chequeRecord = null;
    if (dto.paymentMode === 'CHEQUE' && dto.chequeNumber) {
      chequeRecord = await this.prisma.cheque.create({
        data: {
          chequeNumber: dto.chequeNumber,
          vendorId: invoice.vendorId,
          purchaseInvoiceId: invoice.id,
          purchasePaymentId: payment.id,
          chequeDate: dto.chequeDate ? new Date(dto.chequeDate) : new Date(),
          bankName: dto.bankName || 'HDFC Bank',
          branch: dto.branch,
          amount: paymentAmount,
          payeeName: dto.payeeName || invoice.vendor.companyName,
          depositDate: dto.depositDate ? new Date(dto.depositDate) : null,
          status: 'ISSUED',
          remarks: dto.remarks,
        },
      });
    }

    // 3. Update Invoice: Paid Amount, Pending Balance, and Status
    const newPaidAmount = round2(invoice.paidAmount + paymentAmount);
    const newBalance = round2(Math.max(0, invoice.totalAmount - newPaidAmount));
    const newStatus =
      newBalance === 0 ? 'PAID' : newPaidAmount > 0 ? 'PARTIALLY_PAID' : 'UNPAID';

    await this.prisma.purchaseInvoice.update({
      where: { id: invoice.id },
      data: {
        paidAmount: newPaidAmount,
        balanceAmount: newBalance,
        status: newStatus,
      },
    });

    await this.auditService.log({
      userId,
      action: 'PAYMENT',
      module: 'PURCHASE_PAYMENT',
      entityType: 'PurchasePayment',
      entityId: payment.id,
      details: `Recorded payment ${payment.paymentNumber} of ₹${paymentAmount} against Invoice ${invoice.invoiceNumber}. Remaining balance: ₹${newBalance}`,
    });

    return { payment, cheque: chequeRecord, updatedBalance: newBalance, status: newStatus };
  }

  async findAllCheques(query?: any) {
    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.vendorId) where.vendorId = query.vendorId;

    return this.prisma.cheque.findMany({
      where,
      include: {
        vendor: { select: { companyName: true, vendorCode: true } },
        purchaseInvoice: { select: { invoiceNumber: true, totalAmount: true } },
      },
      orderBy: { chequeDate: 'desc' },
    });
  }

  async updateChequeStatus(
    chequeId: string,
    dto: { status: 'ISSUED' | 'DEPOSITED' | 'CLEARED' | 'BOUNCED' | 'CANCELLED'; bounceReason?: string },
    userId?: string,
  ) {
    const cheque = await this.prisma.cheque.findUnique({
      where: { id: chequeId },
      include: { purchasePayment: true, purchaseInvoice: true },
    });
    if (!cheque) throw new NotFoundException('Cheque not found');

    const oldStatus = cheque.status;
    const newStatus = dto.status;

    // RULE: If Cheque BOUNCED or CANCELLED, reverse the payment on the invoice!
    if (
      (newStatus === 'BOUNCED' || newStatus === 'CANCELLED') &&
      oldStatus !== 'BOUNCED' &&
      oldStatus !== 'CANCELLED' &&
      cheque.purchaseInvoice
    ) {
      const inv = cheque.purchaseInvoice;
      const reversedPaid = round2(Math.max(0, inv.paidAmount - cheque.amount));
      const reversedBalance = round2(inv.totalAmount - reversedPaid);
      const reversedStatus =
        reversedPaid === 0 ? 'UNPAID' : 'PARTIALLY_PAID';

      await this.prisma.purchaseInvoice.update({
        where: { id: inv.id },
        data: {
          paidAmount: reversedPaid,
          balanceAmount: reversedBalance,
          status: reversedStatus,
        },
      });

      await this.auditService.log({
        userId,
        action: 'UPDATE',
        module: 'CHEQUE_MANAGE',
        entityType: 'Cheque',
        entityId: cheque.id,
        details: `Cheque ${cheque.chequeNumber} BOUNCED/CANCELLED. Reversing ₹${cheque.amount} on Invoice ${inv.invoiceNumber}. New balance: ₹${reversedBalance}`,
      });
    }

    const updated = await this.prisma.cheque.update({
      where: { id: chequeId },
      data: {
        status: newStatus,
        bounceReason: dto.bounceReason,
        clearanceDate: newStatus === 'CLEARED' ? new Date() : cheque.clearanceDate,
      },
    });

    return updated;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 10. OUTWARD DOCUMENTS
  // ══════════════════════════════════════════════════════════════════════════════

  async findAllOutwardDocuments(query?: any) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.outwardType) where.outwardType = query.outwardType;
    if (query?.status) where.status = query.status;
    if (query?.search) {
      where.OR = [
        { outwardNumber: { contains: query.search } },
        { partyName: { contains: query.search } },
        { personName: { contains: query.search } },
        { vehicleNumber: { contains: query.search } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.outwardDocument.findMany({
        where,
        skip,
        take: limit,
        include: { items: true },
        orderBy: { date: 'desc' },
      }),
      this.prisma.outwardDocument.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async createOutwardDocument(dto: any, userId?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.outwardDocument.count();
    const outwardNumber = `OUT-${year}-${String(count + 1).padStart(5, '0')}`;

    const items = (dto.items || []).map((i: any) => ({
      productId: i.productId,
      materialName: i.materialName || i.name || 'Outward Item',
      quantity: Number(i.quantity) || 1,
      unit: i.unit || 'Nos',
      remarks: i.remarks,
    }));

    const outward = await this.prisma.outwardDocument.create({
      data: {
        outwardNumber,
        date: dto.date ? new Date(dto.date) : new Date(),
        outwardType: dto.outwardType || 'MATERIAL_OUTWARD',
        departmentId: dto.departmentId,
        fromLocation: dto.fromLocation || 'Saark Main Plant',
        toLocation: dto.toLocation || 'Client/Vendor Site',
        partyType: dto.partyType || 'VENDOR',
        partyId: dto.partyId,
        partyName: dto.partyName,
        personName: dto.personName,
        purpose: dto.purpose,
        referenceNumber: dto.referenceNumber,
        documentNumber: dto.documentNumber,
        vehicleNumber: dto.vehicleNumber,
        status: dto.status || 'DISPATCHED',
        remarks: dto.remarks,
        attachmentUrl: dto.attachmentUrl,
        items: { create: items },
      },
      include: { items: true },
    });

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'PURCHASE',
      entityType: 'OutwardDocument',
      entityId: outward.id,
      details: `Created Outward Document ${outward.outwardNumber} (${outward.outwardType})`,
    });

    return outward;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 11. PURCHASE RETURNS & STOCK REVERSALS
  // ══════════════════════════════════════════════════════════════════════════════

  async findAllPurchaseReturns(query?: any) {
    const where: any = {};
    if (query?.vendorId) where.vendorId = query.vendorId;

    return this.prisma.purchaseReturn.findMany({
      where,
      include: {
        vendor: true,
        items: { include: { product: true } },
        inwardEntry: { select: { inwardNumber: true } },
      },
      orderBy: { returnDate: 'desc' },
    });
  }

  async createPurchaseReturn(dto: any, userId?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.purchaseReturn.count();
    const returnNumber = `PRET-${year}-${String(count + 1).padStart(5, '0')}`;

    let subtotal = 0;
    const items = (dto.items || []).map((it: any) => {
      const qty = Number(it.quantity) || 1;
      const rate = Number(it.rate) || 0;
      const amount = round2(qty * rate);
      subtotal += amount;

      return {
        productId: it.productId,
        quantity: qty,
        unit: it.unit || 'Nos',
        rate,
        amount,
        reason: it.reason || dto.reason,
      };
    });

    const taxAmount = round2(subtotal * 0.18); // Default GST or calculated
    const grandTotal = round2(subtotal + taxAmount);

    const purchaseReturn = await this.prisma.purchaseReturn.create({
      data: {
        returnNumber,
        vendorId: dto.vendorId,
        inwardEntryId: dto.inwardEntryId,
        purchaseInvoiceId: dto.purchaseInvoiceId,
        returnDate: dto.returnDate ? new Date(dto.returnDate) : new Date(),
        reason: dto.reason || 'Quality Rejection / Damaged Goods',
        subtotal: round2(subtotal),
        taxAmount,
        grandTotal,
        remarks: dto.remarks,
        status: 'RETURNED',
        attachmentUrl: dto.attachmentUrl,
        items: { create: items },
      },
      include: { items: true, vendor: true },
    });

    // RULE: Create a reversal Stock Transaction (negative quantity)
    // Do NOT delete historical stock transactions!
    const defaultWh = await this.getDefaultWarehouseId();
    for (const item of purchaseReturn.items) {
      await this.prisma.stockTransaction.create({
        data: {
          productId: item.productId,
          warehouseId: defaultWh,
          transactionType: 'PURCHASE_RETURN',
          referenceType: 'PURCHASE_RETURN',
          referenceId: purchaseReturn.id,
          quantity: -item.quantity, // Negative for stock out
          unit: item.unit,
          unitCost: item.rate,
          totalCost: -item.amount,
          userId,
          notes: `Purchase Return ${purchaseReturn.returnNumber}: ${purchaseReturn.reason}`,
        },
      });

      // Decrement current stock in Product
      await this.prisma.product.update({
        where: { id: item.productId },
        data: { currentStock: { decrement: Math.round(item.quantity) } },
      });
    }

    // Financial adjustment on linked invoice if applicable
    if (dto.purchaseInvoiceId) {
      const inv = await this.prisma.purchaseInvoice.findUnique({
        where: { id: dto.purchaseInvoiceId },
      });
      if (inv) {
        const adjustedTotal = round2(Math.max(0, inv.totalAmount - grandTotal));
        const adjustedBalance = round2(Math.max(0, inv.balanceAmount - grandTotal));
        await this.prisma.purchaseInvoice.update({
          where: { id: inv.id },
          data: {
            totalAmount: adjustedTotal,
            balanceAmount: adjustedBalance,
            status: adjustedBalance === 0 ? 'PAID' : inv.status,
          },
        });
      }
    }

    await this.auditService.log({
      userId,
      action: 'CREATE',
      module: 'PURCHASE_RETURN_MANAGE',
      entityType: 'PurchaseReturn',
      entityId: purchaseReturn.id,
      details: `Created Purchase Return ${purchaseReturn.returnNumber} for vendor ${purchaseReturn.vendor.companyName}, Amount: ₹${purchaseReturn.grandTotal}`,
    });

    return purchaseReturn;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 12. PURCHASE REPORTS & AUDIT TRAIL
  // ══════════════════════════════════════════════════════════════════════════════

  async getPurchaseRegister(query?: any) {
    const where: any = {};
    if (query?.fromDate || query?.toDate) {
      where.invoiceDate = {};
      if (query?.fromDate) where.invoiceDate.gte = new Date(query.fromDate);
      if (query?.toDate) where.invoiceDate.lte = new Date(query.toDate);
    }

    return this.prisma.purchaseInvoice.findMany({
      where,
      include: { vendor: true, payments: true },
      orderBy: { invoiceDate: 'desc' },
    });
  }

  async getOutstandingPayables() {
    const pendingInvoices = await this.prisma.purchaseInvoice.findMany({
      where: { balanceAmount: { gt: 0 }, status: { notIn: ['PAID', 'CANCELLED'] } },
      include: { vendor: true },
      orderBy: { dueDate: 'asc' },
    });

    const totalOutstanding = round2(
      pendingInvoices.reduce((sum, inv) => sum + inv.balanceAmount, 0),
    );

    return {
      totalOutstanding,
      count: pendingInvoices.length,
      invoices: pendingInvoices,
    };
  }
}
