import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';

@Injectable()
export class SalesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
  ) {}

  private getCurrentFinancialYear(): string {
    const now = new Date();
    const year = now.getFullYear();
    return now.getMonth() >= 3
      ? `${year}-${String(year + 1).slice(2)}`
      : `${year - 1}-${String(year).slice(2)}`;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. QUOTATIONS LIST & DETAILS
  // ─────────────────────────────────────────────────────────────────────────────

  async getQuotations(query: {
    customerId?: string;
    opportunityId?: string;
    status?: string;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const pageNum = Number(query.page) > 0 ? Number(query.page) : 1;
    const limitNum = Number(query.limit) > 0 ? Number(query.limit) : 50;
    const skip = (pageNum - 1) * limitNum;
    const take = limitNum;
    const { customerId, opportunityId, status, search } = query;

    const where: any = {};
    if (customerId) where.customerId = customerId;
    if (opportunityId) where.opportunityId = opportunityId;
    if (status) where.status = status;
    if (search) {
      where.OR = [
        { quotationNumber: { contains: search } },
        { code: { contains: search } },
        { subject: { contains: search } },
        { customer: { companyName: { contains: search } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.quotation.findMany({
        where,
        skip,
        take,
        include: {
          customer: {
            select: { id: true, customerCode: true, companyName: true, gstin: true, city: true, state: true, phone: true, email: true },
          },
          opportunity: { select: { id: true, title: true, stage: true, estimatedValue: true } },
          panelSpec: { select: { id: true, panelCode: true, panelType: true, voltage: true, finalPrice: true } },
          assignedStaff: { select: { id: true, fullName: true } },
          items: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.quotation.count({ where }),
    ]);

    return { items, total, page: pageNum, limit: limitNum, totalPages: Math.ceil(total / limitNum) };
  }

  async getQuotationById(id: string) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id },
      include: {
        customer: { include: { contacts: true } },
        opportunity: true,
        enquiry: true,
        panelSpec: { include: { bomItems: true } },
        assignedStaff: { select: { id: true, fullName: true, email: true, mobile: true } },
        approvedByStaff: { select: { id: true, fullName: true } },
        items: { include: { product: true }, orderBy: { sortOrder: 'asc' } },
        salesOrders: true,
      },
    });

    if (!quotation) throw new NotFoundException(`Quotation with ID "${id}" not found`);

    const revisions = await this.prisma.quotation.findMany({
      where: { quotationNumber: quotation.quotationNumber },
      select: { id: true, quotationNumber: true, revisionNumber: true, code: true, status: true, grandTotal: true, createdAt: true, validUntil: true },
      orderBy: { revisionNumber: 'desc' },
    });

    return { ...quotation, revisions };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. CREATE QUOTATION
  // ─────────────────────────────────────────────────────────────────────────────

  async createQuotation(dto: any, userId?: string) {
    if (!dto.customerId) throw new BadRequestException('customerId is required');

    const quotationNumber = dto.quotationNumber || (await this.sequenceService.nextQuotationNumber());
    const revisionNumber = dto.revisionNumber ?? 0;
    const code = `${quotationNumber}-REV-${revisionNumber}`;

    const rawItems: any[] = dto.items || [];
    let subtotal = 0;
    let totalDiscount = 0;
    let taxableAmount = 0;
    let cgstAmount = 0;
    let sgstAmount = 0;
    let igstAmount = 0;

    const itemsToCreate = rawItems.map((item, idx) => {
      const qty = Number(item.quantity) || 1;
      const unitPrice = Number(item.unitPrice) || 0;
      const itemDiscountPercent = Number(item.discountPercent) || 0;
      const lineSubtotal = qty * unitPrice;
      const lineDiscount = lineSubtotal * (itemDiscountPercent / 100);
      const lineTaxable = lineSubtotal - lineDiscount;
      const rawGst = item.gstPercent ?? item.taxPercent ?? dto.taxPercent ?? 18.0;
      const gstRate = !isNaN(Number(rawGst)) ? Number(rawGst) : 18.0;
      const lineGst = lineTaxable * (gstRate / 100);
      const lineTotal = lineTaxable + lineGst;

      subtotal += lineSubtotal;
      totalDiscount += lineDiscount;
      taxableAmount += lineTaxable;

      const mappedItem: any = {
        itemCode: item.itemCode || `ITM-${idx + 1}`,
        description: item.description || 'Custom Engineered Item',
        hsnSac: item.hsnSac || '8537',
        quantity: qty,
        unit: item.unit || 'Nos',
        unitPrice,
        discountPercent: itemDiscountPercent,
        taxableAmount: lineTaxable,
        gstPercent: gstRate,
        gstAmount: lineGst,
        totalAmount: lineTotal,
        sortOrder: idx,
      };
      if (item.productId) mappedItem.productId = item.productId;
      return mappedItem;
    });

    const isInterState = Boolean(dto.isInterState);
    if (isInterState) {
      igstAmount = taxableAmount * 0.18;
    } else {
      cgstAmount = taxableAmount * 0.09;
      sgstAmount = taxableAmount * 0.09;
    }

    const overallDiscountAmount = Number(dto.discountAmount) || 0;
    const grandTotal = taxableAmount + cgstAmount + sgstAmount + igstAmount - overallDiscountAmount;

    let assignedStaffId = dto.assignedStaffId;
    if (!assignedStaffId && userId) {
      const staff = await this.prisma.staff.findFirst({ where: { userId } });
      if (staff) assignedStaffId = staff.id;
    }

    const quotation = await this.prisma.quotation.create({
      data: {
        quotationNumber,
        revisionNumber,
        code,
        customerId: dto.customerId,
        opportunityId: dto.opportunityId || null,
        enquiryId: dto.enquiryId || null,
        panelSpecId: dto.panelSpecId || null,
        assignedStaffId,
        quotationDate: dto.quotationDate ? new Date(dto.quotationDate) : new Date(),
        validUntil: dto.validUntil ? new Date(dto.validUntil) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        subject: dto.subject || 'Commercial Offer for Control Panel & Automation Systems',
        currency: dto.currency || 'INR',
        subtotal,
        discountPercent: Number(dto.discountPercent) || 0,
        discountAmount: totalDiscount + overallDiscountAmount,
        taxableAmount,
        cgstPercent: isInterState ? 0 : 9.0,
        cgstAmount,
        sgstPercent: isInterState ? 0 : 9.0,
        sgstAmount,
        igstPercent: isInterState ? 18.0 : 0,
        igstAmount,
        grandTotal,
        paymentTerms: dto.paymentTerms || '50% Advance, 50% Against Proforma Invoice before Dispatch',
        deliveryTerms: dto.deliveryTerms || '2 to 3 weeks from receipt of PO and technical clearance',
        freightTerms: dto.freightTerms || 'Ex-Works Pune. Freight extra at actuals.',
        warrantyTerms: dto.warrantyTerms || '18 months from date of supply or 12 months from commissioning.',
        notes: dto.notes || null,
        status: dto.status || 'DRAFT',
        items: { create: itemsToCreate },
      },
      include: { customer: true, items: true },
    });

    if (assignedStaffId) {
      await this.prisma.crmActivity.create({
        data: {
          activityType: 'QUOTATION_SENT',
          customerId: dto.customerId,
          opportunityId: dto.opportunityId || null,
          staffId: assignedStaffId,
          subject: `Quotation ${code} generated for ₹${grandTotal.toLocaleString('en-IN')}`,
          description: `Commercial Quotation created with ${itemsToCreate.length} line items. Status: ${quotation.status}`,
          outcome: 'QUOTATION_CREATED',
        },
      });
    }

    return quotation;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. AUTO-BUILD QUOTATION FROM PANEL SPECIFICATION
  // ─────────────────────────────────────────────────────────────────────────────

  async createFromPanelSpec(panelSpecId: string, dto: any, userId?: string) {
    const panelSpec = await this.prisma.panelSpecification.findUnique({
      where: { id: panelSpecId },
      include: { customer: true, bomItems: { include: { product: true } } },
    });

    if (!panelSpec) throw new NotFoundException(`Panel Specification "${panelSpecId}" not found`);

    const quotationNumber = dto?.quotationNumber || (await this.sequenceService.nextQuotationNumber());
    const code = `${quotationNumber}-REV-0`;

    const mainUnitPrice = panelSpec.finalPrice > 0
      ? panelSpec.finalPrice
      : (panelSpec.materialCost + panelSpec.labourCost + panelSpec.overheadCost) * (1 + panelSpec.marginPercent / 100);
    const mainGst = mainUnitPrice * 0.18;
    const mainTotal = mainUnitPrice + mainGst;

    const itemsToCreate: any[] = [{
      productId: null,
      itemCode: panelSpec.panelCode,
      description: `${panelSpec.panelType.replace(/_/g, ' ')} - ${panelSpec.voltage}, ${panelSpec.currentRating}, ${panelSpec.pumpQty}x ${panelSpec.pumpHp}HP, Starter: ${panelSpec.starterType || 'VFD'}, Enclosure: ${panelSpec.enclosureType} (${panelSpec.ipRating})`,
      hsnSac: '8537',
      quantity: 1,
      unit: 'Set',
      unitPrice: mainUnitPrice,
      discountPercent: 0,
      taxableAmount: mainUnitPrice,
      gstPercent: 18.0,
      gstAmount: mainGst,
      totalAmount: mainTotal,
      sortOrder: 0,
    }];

    if (dto?.includeBomDetails && panelSpec.bomItems.length > 0) {
      panelSpec.bomItems.forEach((bom, idx) => {
        const itemTaxable = bom.totalPrice || (bom.quantity * bom.unitPrice);
        const itemGst = itemTaxable * 0.18;
        itemsToCreate.push({
          productId: bom.productId || null,
          itemCode: `BOM-${idx + 1}`,
          description: `${bom.componentName} (${bom.specification || bom.manufacturer || 'Standard'}) - Qty: ${bom.quantity}`,
          hsnSac: '8537',
          quantity: bom.quantity,
          unit: 'Nos',
          unitPrice: bom.unitPrice,
          discountPercent: 0,
          taxableAmount: itemTaxable,
          gstPercent: 18.0,
          gstAmount: itemGst,
          totalAmount: itemTaxable + itemGst,
          sortOrder: idx + 1,
        });
      });
    }

    const subtotal = itemsToCreate.reduce((acc, itm) => acc + itm.taxableAmount, 0);
    const cgstAmount = subtotal * 0.09;
    const sgstAmount = subtotal * 0.09;
    const grandTotal = subtotal + cgstAmount + sgstAmount;

    let assignedStaffId = dto?.assignedStaffId;
    if (!assignedStaffId && userId) {
      const staff = await this.prisma.staff.findFirst({ where: { userId } });
      if (staff) assignedStaffId = staff.id;
    }

    const quotation = await this.prisma.quotation.create({
      data: {
        quotationNumber,
        revisionNumber: 0,
        code,
        customerId: panelSpec.customerId,
        panelSpecId: panelSpec.id,
        assignedStaffId,
        subject: dto?.subject || `Commercial Proposal for ${panelSpec.panelCode} (${panelSpec.panelType.replace(/_/g, ' ')})`,
        subtotal,
        discountPercent: 0,
        discountAmount: 0,
        taxableAmount: subtotal,
        cgstPercent: 9.0,
        cgstAmount,
        sgstPercent: 9.0,
        sgstAmount,
        igstPercent: 0,
        igstAmount: 0,
        grandTotal,
        paymentTerms: '50% Advance, 50% Against Proforma Invoice before Dispatch',
        deliveryTerms: '3 to 4 weeks from approved engineering drawings',
        status: 'DRAFT',
        items: { create: itemsToCreate },
      },
      include: { customer: true, items: true, panelSpec: true },
    });

    await this.prisma.panelSpecification.update({ where: { id: panelSpecId }, data: { status: 'APPROVED' } });

    return quotation;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. REVISION CONTROL
  // ─────────────────────────────────────────────────────────────────────────────

  async createRevision(id: string, dto: any, userId?: string) {
    const baseQuotation = await this.prisma.quotation.findUnique({ where: { id }, include: { items: true } });
    if (!baseQuotation) throw new NotFoundException(`Base Quotation with ID "${id}" not found`);

    const latest = await this.prisma.quotation.findFirst({
      where: { quotationNumber: baseQuotation.quotationNumber },
      orderBy: { revisionNumber: 'desc' },
    });

    const newRevisionNumber = (latest ? latest.revisionNumber : baseQuotation.revisionNumber) + 1;
    const newCode = `${baseQuotation.quotationNumber}-REV-${newRevisionNumber}`;

    const rawItems = dto.items || baseQuotation.items;
    let subtotal = 0;
    let totalDiscount = 0;
    let taxableAmount = 0;

    const itemsToCreate = rawItems.map((item: any, idx: number) => {
      const qty = Number(item.quantity) || 1;
      const unitPrice = Number(item.unitPrice) || 0;
      const itemDiscountPercent = Number(item.discountPercent) || 0;
      const lineSubtotal = qty * unitPrice;
      const lineDiscount = lineSubtotal * (itemDiscountPercent / 100);
      const lineTaxable = lineSubtotal - lineDiscount;
      const rawGst = item.gstPercent ?? item.taxPercent ?? (baseQuotation.cgstPercent ? baseQuotation.cgstPercent * 2 : 18.0);
      const gstRate = !isNaN(Number(rawGst)) ? Number(rawGst) : 18.0;
      const lineGst = lineTaxable * (gstRate / 100);

      subtotal += lineSubtotal;
      totalDiscount += lineDiscount;
      taxableAmount += lineTaxable;

      const mappedItem: any = {
        itemCode: item.itemCode || `ITM-${idx + 1}`,
        description: item.description,
        hsnSac: item.hsnSac || '8537',
        quantity: qty,
        unit: item.unit || 'Nos',
        unitPrice,
        discountPercent: itemDiscountPercent,
        taxableAmount: lineTaxable,
        gstPercent: gstRate,
        gstAmount: lineGst,
        totalAmount: lineTaxable + lineGst,
        sortOrder: idx,
      };
      if (item.productId) mappedItem.productId = item.productId;
      return mappedItem;
    });

    const isInterState = baseQuotation.igstAmount > 0 || Boolean(dto.isInterState);
    let cgstAmount = 0;
    let sgstAmount = 0;
    let igstAmount = 0;

    if (isInterState) {
      igstAmount = taxableAmount * 0.18;
    } else {
      cgstAmount = taxableAmount * 0.09;
      sgstAmount = taxableAmount * 0.09;
    }

    const overallDiscountAmount = Number(dto.discountAmount) || 0;
    const grandTotal = taxableAmount + cgstAmount + sgstAmount + igstAmount - overallDiscountAmount;

    let assignedStaffId = dto.assignedStaffId || baseQuotation.assignedStaffId;
    if (!assignedStaffId && userId) {
      const staff = await this.prisma.staff.findFirst({ where: { userId } });
      if (staff) assignedStaffId = staff.id;
    }

    return this.prisma.quotation.create({
      data: {
        quotationNumber: baseQuotation.quotationNumber,
        revisionNumber: newRevisionNumber,
        code: newCode,
        customerId: baseQuotation.customerId,
        opportunityId: baseQuotation.opportunityId,
        enquiryId: baseQuotation.enquiryId,
        panelSpecId: baseQuotation.panelSpecId,
        assignedStaffId,
        quotationDate: new Date(),
        validUntil: dto.validUntil ? new Date(dto.validUntil) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        subject: dto.subject || `${baseQuotation.subject} (Rev ${newRevisionNumber})`,
        currency: baseQuotation.currency,
        subtotal,
        discountPercent: Number(dto.discountPercent) || 0,
        discountAmount: totalDiscount + overallDiscountAmount,
        taxableAmount,
        cgstPercent: isInterState ? 0 : 9.0,
        cgstAmount,
        sgstPercent: isInterState ? 0 : 9.0,
        sgstAmount,
        igstPercent: isInterState ? 18.0 : 0,
        igstAmount,
        grandTotal,
        paymentTerms: dto.paymentTerms || baseQuotation.paymentTerms,
        deliveryTerms: dto.deliveryTerms || baseQuotation.deliveryTerms,
        freightTerms: dto.freightTerms || baseQuotation.freightTerms,
        warrantyTerms: dto.warrantyTerms || baseQuotation.warrantyTerms,
        notes: dto.notes || `Revised from ${baseQuotation.code}`,
        status: 'DRAFT',
        items: { create: itemsToCreate },
      },
      include: { customer: true, items: true },
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. STATUS UPDATE & CRM TIMELINE SYNC
  // ─────────────────────────────────────────────────────────────────────────────

  async updateQuotationStatus(id: string, dto: { status: string; notes?: string }, userId?: string) {
    const quotation = await this.prisma.quotation.findUnique({ where: { id }, include: { customer: true } });
    if (!quotation) throw new NotFoundException(`Quotation with ID "${id}" not found`);

    const updated = await this.prisma.quotation.update({
      where: { id },
      data: {
        status: dto.status,
        sentAt: dto.status === 'SENT' ? new Date() : undefined,
        acceptedAt: dto.status === 'ACCEPTED' ? new Date() : undefined,
        notes: dto.notes ? `${quotation.notes || ''}\n[${dto.status}]: ${dto.notes}` : quotation.notes,
      },
    });

    if (quotation.opportunityId) {
      let nextStage: string | null = null;
      if (dto.status === 'SENT') nextStage = 'QUOTATION_SENT';
      if (dto.status === 'ACCEPTED') nextStage = 'NEGOTIATION';
      if (nextStage) {
        await this.prisma.opportunity.update({ where: { id: quotation.opportunityId }, data: { stage: nextStage } });
      }
    }

    return updated;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. CONVERT TO SALES ORDER
  // ─────────────────────────────────────────────────────────────────────────────

  async convertToSalesOrder(quotationId: string, dto: any, userId?: string) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id: quotationId },
      include: { customer: true, items: true },
    });
    if (!quotation) throw new NotFoundException(`Quotation with ID "${quotationId}" not found`);

    const orderNumber = dto.orderNumber || (await this.sequenceService.nextSalesOrderNumber());

    let assignedStaffId = dto.assignedStaffId || quotation.assignedStaffId;
    if (!assignedStaffId && userId) {
      const staff = await this.prisma.staff.findFirst({ where: { userId } });
      if (staff) assignedStaffId = staff.id;
    }

    const salesOrder = await this.prisma.salesOrder.create({
      data: {
        orderNumber,
        quotationId: quotation.id,
        customerId: quotation.customerId,
        poNumber: dto.poNumber || null,
        poDate: dto.poDate ? new Date(dto.poDate) : null,
        orderDate: dto.orderDate ? new Date(dto.orderDate) : new Date(),
        deliveryDate: dto.deliveryDate ? new Date(dto.deliveryDate) : new Date(Date.now() + 21 * 24 * 60 * 60 * 1000),
        assignedStaffId,
        subtotal: quotation.subtotal,
        discountAmount: quotation.discountAmount,
        taxableAmount: quotation.taxableAmount,
        taxAmount: quotation.cgstAmount + quotation.sgstAmount + quotation.igstAmount,
        grandTotal: quotation.grandTotal,
        paymentTerms: dto.paymentTerms || quotation.paymentTerms,
        shippingAddress: dto.shippingAddress || quotation.customer.address,
        billingAddress: dto.billingAddress || quotation.customer.address,
        status: 'CONFIRMED',
        productionStatus: 'PENDING',
        notes: dto.notes || `Generated from Quotation ${quotation.code}`,
        items: {
          create: quotation.items.map((item) => {
            const orderItem: any = {
              description: item.description,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              taxAmount: item.gstAmount,
              totalAmount: item.totalAmount,
            };
            if (item.productId) orderItem.productId = item.productId;
            return orderItem;
          }),
        },
      },
      include: { customer: true, items: true, quotation: true },
    });

    await this.prisma.quotation.update({ where: { id: quotationId }, data: { status: 'CONVERTED' } });

    if (quotation.opportunityId) {
      await this.prisma.opportunity.update({
        where: { id: quotation.opportunityId },
        data: { stage: 'CLOSED_WON', probability: 100, poNumber: dto.poNumber || orderNumber, poDate: new Date() },
      });
    }

    return salesOrder;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. SALES ORDERS LIST & DETAILS
  // ─────────────────────────────────────────────────────────────────────────────

  async getSalesOrders(query: {
    customerId?: string;
    status?: string;
    productionStatus?: string;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const pageNum = Number(query.page) > 0 ? Number(query.page) : 1;
    const limitNum = Number(query.limit) > 0 ? Number(query.limit) : 50;
    const skip = (pageNum - 1) * limitNum;
    const take = limitNum;
    const { customerId, status, productionStatus, search } = query;

    const where: any = {};
    if (customerId) where.customerId = customerId;
    if (status) where.status = status;
    if (productionStatus) where.productionStatus = productionStatus;
    if (search) {
      where.OR = [
        { orderNumber: { contains: search } },
        { poNumber: { contains: search } },
        { customer: { companyName: { contains: search } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.salesOrder.findMany({
        where,
        skip,
        take,
        include: {
          customer: { select: { id: true, customerCode: true, companyName: true, city: true, state: true, phone: true } },
          quotation: { select: { id: true, code: true, quotationNumber: true, subject: true } },
          assignedStaff: { select: { id: true, fullName: true } },
          items: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.salesOrder.count({ where }),
    ]);

    return { items, total, page: pageNum, limit: limitNum, totalPages: Math.ceil(total / limitNum) };
  }

  async getSalesOrderById(id: string) {
    const order = await this.prisma.salesOrder.findUnique({
      where: { id },
      include: {
        customer: { include: { contacts: true } },
        quotation: { include: { panelSpec: true } },
        assignedStaff: { select: { id: true, fullName: true, email: true, mobile: true } },
        items: { include: { product: true } },
      },
    });
    if (!order) throw new NotFoundException(`Sales Order with ID "${id}" not found`);
    return order;
  }

  async updateSalesOrderStatus(id: string, dto: { status?: string; productionStatus?: string; notes?: string }, userId?: string) {
    const order = await this.prisma.salesOrder.findUnique({ where: { id } });
    if (!order) throw new NotFoundException('Sales Order not found');

    return this.prisma.salesOrder.update({
      where: { id },
      data: {
        status: dto.status || order.status,
        productionStatus: dto.productionStatus || order.productionStatus,
        notes: dto.notes ? `${order.notes || ''}\n${dto.notes}` : order.notes,
      },
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. INVOICES
  // ─────────────────────────────────────────────────────────────────────────────

  async getInvoices(query: {
    customerId?: string;
    salesOrderId?: string;
    status?: string;
    paymentStatus?: string;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const pageNum = Number(query.page) > 0 ? Number(query.page) : 1;
    const limitNum = Number(query.limit) > 0 ? Number(query.limit) : 50;
    const skip = (pageNum - 1) * limitNum;
    const take = limitNum;
    const { customerId, salesOrderId, status, paymentStatus, search } = query;

    const where: any = {};
    if (customerId) where.customerId = customerId;
    if (salesOrderId) where.salesOrderId = salesOrderId;
    if (status) where.status = status;
    if (paymentStatus) where.paymentStatus = paymentStatus;
    if (search) {
      where.OR = [
        { invoiceNumber: { contains: search } },
        { poNumber: { contains: search } },
        { ewayBillNumber: { contains: search } },
        { customer: { companyName: { contains: search } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.salesInvoice.findMany({
        where,
        skip,
        take,
        include: {
          customer: { select: { id: true, customerCode: true, companyName: true, gstin: true, city: true, phone: true } },
          salesOrder: { select: { id: true, orderNumber: true, poNumber: true } },
          items: true,
          payments: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.salesInvoice.count({ where }),
    ]);

    return { items, total, page: pageNum, limit: limitNum, totalPages: Math.ceil(total / limitNum) };
  }

  async getInvoiceById(id: string) {
    const invoice = await this.prisma.salesInvoice.findUnique({
      where: { id },
      include: {
        customer: { include: { contacts: true } },
        salesOrder: { include: { quotation: true } },
        items: { include: { product: true } },
        payments: { orderBy: { paymentDate: 'desc' } },
      },
    });
    if (!invoice) throw new NotFoundException(`Invoice with ID "${id}" not found`);
    return invoice;
  }

  async createInvoice(dto: any, userId?: string) {
    const invoiceNumber = dto.invoiceNumber || (await this.sequenceService.nextInvoiceNumber());

    const rawItems = dto.items || [];
    let subtotal = 0;
    let taxableAmount = 0;
    let taxAmount = 0;

    const itemsToCreate = rawItems.map((item: any, idx: number) => {
      const qty = Number(item.quantity) || 1;
      const unitPrice = Number(item.unitPrice) || 0;
      const lineTaxable = qty * unitPrice;
      const rawGst = item.gstPercent ?? item.taxPercent ?? dto.taxPercent ?? 18.0;
      const gstRate = !isNaN(Number(rawGst)) ? Number(rawGst) : 18.0;
      const lineGst = lineTaxable * (gstRate / 100);

      subtotal += lineTaxable;
      taxableAmount += lineTaxable;
      taxAmount += lineGst;

      const mappedItem: any = {
        itemCode: item.itemCode || `ITM-${idx + 1}`,
        description: item.description,
        hsnSac: item.hsnSac || '8537',
        quantity: qty,
        unit: item.unit || 'Nos',
        unitPrice,
        taxableAmount: lineTaxable,
        gstPercent: gstRate,
        gstAmount: lineGst,
        totalAmount: lineTaxable + lineGst,
      };
      if (item.productId) mappedItem.productId = item.productId;
      return mappedItem;
    });

    const isInterState = Boolean(dto.isInterState);
    const cgstAmount = isInterState ? 0 : taxAmount / 2;
    const sgstAmount = isInterState ? 0 : taxAmount / 2;
    const igstAmount = isInterState ? taxAmount : 0;
    const grandTotal = taxableAmount + taxAmount;

    let customerId = dto.customerId;
    if (!customerId && (dto.customerName || dto.customer)) {
      const searchName = dto.customerName || dto.customer;
      const found = await this.prisma.customer.findFirst({
        where: { companyName: { contains: searchName } },
      });
      if (found) customerId = found.id;
    }
    if (!customerId) {
      const firstCust = await this.prisma.customer.findFirst({
        where: { status: 'ACTIVE' },
      });
      if (firstCust) customerId = firstCust.id;
    }

    return this.prisma.salesInvoice.create({
      data: {
        invoiceNumber,
        salesOrderId: dto.salesOrderId || null,
        customerId,
        financialYear: dto.financialYear || this.getCurrentFinancialYear(),
        invoiceDate: dto.invoiceDate ? new Date(dto.invoiceDate) : new Date(),
        dueDate: dto.dueDate ? new Date(dto.dueDate) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        poNumber: dto.poNumber || null,
        ewayBillNumber: dto.ewayBillNumber || null,
        irnNumber: dto.irnNumber || null,
        subtotal,
        discountAmount: Number(dto.discountAmount) || 0,
        taxableAmount,
        cgstAmount,
        sgstAmount,
        igstAmount,
        taxAmount,
        grandTotal,
        paidAmount: 0,
        balanceDue: grandTotal,
        paymentStatus: 'UNPAID',
        status: dto.status || 'ISSUED',
        notes: dto.notes || null,
        items: { create: itemsToCreate },
      },
      include: { customer: true, items: true },
    });
  }

  async createInvoiceFromSalesOrder(orderId: string, dto: any, userId?: string) {
    const order = await this.prisma.salesOrder.findUnique({
      where: { id: orderId },
      include: { customer: true, items: true },
    });
    if (!order) throw new NotFoundException(`Sales Order with ID "${orderId}" not found`);

    const invoiceNumber = dto.invoiceNumber || (await this.sequenceService.nextInvoiceNumber());

    const itemsToCreate = order.items.map((item, idx) => {
      const mappedItem: any = {
        itemCode: `ITM-${idx + 1}`,
        description: item.description,
        hsnSac: '8537',
        quantity: item.quantity,
        unit: 'Nos',
        unitPrice: item.unitPrice,
        taxableAmount: item.quantity * item.unitPrice,
        gstPercent: 18.0,
        gstAmount: item.taxAmount,
        totalAmount: item.totalAmount,
      };
      if (item.productId) mappedItem.productId = item.productId;
      return mappedItem;
    });

    return this.prisma.salesInvoice.create({
      data: {
        invoiceNumber,
        salesOrderId: order.id,
        customerId: order.customerId,
        financialYear: dto.financialYear || this.getCurrentFinancialYear(),
        invoiceDate: dto.invoiceDate ? new Date(dto.invoiceDate) : new Date(),
        dueDate: dto.dueDate ? new Date(dto.dueDate) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        poNumber: order.poNumber,
        ewayBillNumber: dto.ewayBillNumber || null,
        irnNumber: dto.irnNumber || null,
        subtotal: order.subtotal,
        discountAmount: order.discountAmount,
        taxableAmount: order.taxableAmount,
        cgstAmount: order.taxAmount / 2,
        sgstAmount: order.taxAmount / 2,
        igstAmount: 0,
        taxAmount: order.taxAmount,
        grandTotal: order.grandTotal,
        paidAmount: 0,
        balanceDue: order.grandTotal,
        paymentStatus: 'UNPAID',
        status: 'ISSUED',
        notes: dto.notes || `Tax Invoice generated against Sales Order ${order.orderNumber}`,
        items: { create: itemsToCreate },
      },
      include: { customer: true, items: true },
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 9. RECORD PAYMENT
  // ─────────────────────────────────────────────────────────────────────────────

  async recordPayment(invoiceId: string, dto: any, userId?: string) {
    const invoice = await this.prisma.salesInvoice.findUnique({ where: { id: invoiceId } });
    if (!invoice) throw new NotFoundException(`Invoice with ID "${invoiceId}" not found`);

    const amount = Number(dto.amount) || 0;
    if (amount <= 0) throw new BadRequestException('Payment amount must be greater than 0');

    const receiptNumber = dto.receiptNumber || (await this.sequenceService.nextReceiptNumber());

    const payment = await this.prisma.salesPayment.create({
      data: {
        receiptNumber,
        salesInvoiceId: invoice.id,
        customerId: invoice.customerId,
        paymentDate: dto.paymentDate ? new Date(dto.paymentDate) : new Date(),
        amount,
        paymentMode: dto.paymentMode || 'NEFT',
        referenceNumber: dto.referenceNumber || null,
        bankName: dto.bankName || null,
        notes: dto.notes || null,
      },
    });

    const newPaidAmount = invoice.paidAmount + amount;
    const newBalanceDue = Math.max(0, invoice.grandTotal - newPaidAmount);
    const newPaymentStatus = newBalanceDue === 0 ? 'PAID' : newPaidAmount === 0 ? 'UNPAID' : 'PARTIALLY_PAID';

    await this.prisma.salesInvoice.update({
      where: { id: invoiceId },
      data: { paidAmount: newPaidAmount, balanceDue: newBalanceDue, paymentStatus: newPaymentStatus },
    });

    return payment;
  }

  async updateInvoice(id: string, dto: any) {
    const invoice = await this.prisma.salesInvoice.findUnique({ where: { id } });
    if (!invoice) throw new NotFoundException(`Invoice with ID "${id}" not found`);

    const grandTotal = dto.grandTotal !== undefined ? Number(dto.grandTotal) : invoice.grandTotal;
    const paidAmount = dto.paidAmount !== undefined ? Number(dto.paidAmount) : invoice.paidAmount;
    const balanceDue = Math.max(0, grandTotal - paidAmount);
    const paymentStatus = balanceDue === 0 ? 'PAID' : paidAmount === 0 ? 'UNPAID' : 'PARTIALLY_PAID';

    return this.prisma.salesInvoice.update({
      where: { id },
      data: {
        invoiceNumber: dto.invoiceNumber ?? invoice.invoiceNumber,
        customerId: dto.customerId ?? invoice.customerId,
        invoiceDate: dto.invoiceDate ? new Date(dto.invoiceDate) : invoice.invoiceDate,
        grandTotal,
        subtotal: grandTotal,
        taxableAmount: grandTotal,
        paidAmount,
        balanceDue,
        paymentStatus,
        notes: dto.notes !== undefined ? dto.notes : invoice.notes,
      },
      include: { customer: true, items: true },
    });
  }

  async deleteInvoice(id: string) {
    const invoice = await this.prisma.salesInvoice.findUnique({ where: { id } });
    if (!invoice) throw new NotFoundException(`Invoice with ID "${id}" not found`);

    await this.prisma.salesPayment.deleteMany({ where: { salesInvoiceId: id } });
    await this.prisma.salesInvoiceItem.deleteMany({ where: { salesInvoiceId: id } });
    return this.prisma.salesInvoice.delete({ where: { id } });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 10. ACCOUNTS & RECEIVABLES SUMMARY
  // ─────────────────────────────────────────────────────────────────────────────

  async getAccountsSummary() {
    const [invoices, payments] = await Promise.all([
      this.prisma.salesInvoice.findMany({
        include: { customer: { select: { companyName: true, customerCode: true } } },
      }),
      this.prisma.salesPayment.findMany({
        take: 10,
        orderBy: { paymentDate: 'desc' },
        include: {
          customer: { select: { companyName: true } },
          invoice: { select: { invoiceNumber: true } },
        },
      }),
    ]);

    let totalInvoiced = 0;
    let totalCollected = 0;
    let totalOutstanding = 0;
    let overdueAmount = 0;
    const now = new Date();
    const statusCounts: Record<string, number> = { PAID: 0, PARTIALLY_PAID: 0, UNPAID: 0, OVERDUE: 0 };
    const customerBalancesMap = new Map<string, { customerId: string; companyName: string; customerCode: string; totalInvoiced: number; totalPaid: number; balanceDue: number; invoicesCount: number }>();

    invoices.forEach((inv) => {
      totalInvoiced += inv.grandTotal;
      totalCollected += inv.paidAmount;
      totalOutstanding += inv.balanceDue;

      const isOverdue = inv.balanceDue > 0 && inv.dueDate && new Date(inv.dueDate) < now;
      if (isOverdue) {
        overdueAmount += inv.balanceDue;
        statusCounts['OVERDUE'] = (statusCounts['OVERDUE'] || 0) + 1;
      } else {
        statusCounts[inv.paymentStatus] = (statusCounts[inv.paymentStatus] || 0) + 1;
      }

      if (inv.customerId) {
        if (!customerBalancesMap.has(inv.customerId)) {
          customerBalancesMap.set(inv.customerId, {
            customerId: inv.customerId,
            companyName: inv.customer?.companyName || 'Unknown',
            customerCode: inv.customer?.customerCode || '',
            totalInvoiced: 0,
            totalPaid: 0,
            balanceDue: 0,
            invoicesCount: 0,
          });
        }
        const cData = customerBalancesMap.get(inv.customerId)!;
        cData.totalInvoiced += inv.grandTotal;
        cData.totalPaid += inv.paidAmount;
        cData.balanceDue += inv.balanceDue;
        cData.invoicesCount += 1;
      }
    });

    return {
      totalInvoiced,
      totalCollected,
      totalOutstanding,
      overdueAmount,
      totalInvoicesCount: invoices.length,
      statusCounts,
      recentPayments: payments,
      customerBalances: Array.from(customerBalancesMap.values()).sort((a, b) => b.balanceDue - a.balanceDue),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BANK & CASH MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  private bankAccounts: any[] = [
    {
      id: 'acc-1',
      accountName: 'HDFC Current',
      bankName: 'HDFC Bank',
      accountNumber: '50200012345678',
      openingBalance: 150000.00,
      notes: 'MIDC Chakan Branch, IFSC: HDFC0001234',
    },
    {
      id: 'acc-2',
      accountName: 'Cash in Hand',
      bankName: 'Cash',
      accountNumber: 'CASH-MAIN-01',
      openingBalance: 25000.00,
      notes: 'Main Office Petty Cash Register',
    },
    {
      id: 'acc-3',
      accountName: 'SBI Operations',
      bankName: 'State Bank of India',
      accountNumber: '38192038475',
      openingBalance: 85000.00,
      notes: 'Bhosari Industrial Branch, IFSC: SBIN0004512',
    },
  ];

  private bankTransactions: any[] = [
    {
      id: 'tx-1',
      date: '2026-10-10',
      accountName: 'HDFC Current',
      type: 'Deposit',
      amount: 54000.00,
      description: 'Payment receipt against INV-2026-081',
      reference: 'CMS-NEFT-99182',
      notes: 'Customer: Satyam Engineering',
    },
    {
      id: 'tx-2',
      date: '2026-10-12',
      accountName: 'HDFC Current',
      type: 'Withdrawal',
      amount: 22000.00,
      description: 'Vendor payment for Copper Busbars',
      reference: 'RTGS-00291-VND',
      notes: 'Vendor: Metal Craft Supplies',
    },
    {
      id: 'tx-3',
      date: '2026-10-14',
      accountName: 'Cash in Hand',
      type: 'Cash Out',
      amount: 3500.00,
      description: 'Workshop maintenance & consumable tools',
      reference: 'VCH-8812',
      notes: 'Admin Petty Voucher',
    },
    {
      id: 'tx-4',
      date: '2026-10-15',
      accountName: 'HDFC Current',
      type: 'Bank Charge',
      amount: 590.00,
      description: 'Quarterly bank ledger maintenance & GST',
      reference: 'BNK-CHG-Q2',
      notes: 'Auto Debit',
    },
    {
      id: 'tx-5',
      date: '2026-10-15',
      accountName: 'SBI Operations',
      type: 'Deposit',
      amount: 30000.00,
      description: 'Advance received for Solar Control Panel',
      reference: 'IMPS-20261015-812',
      notes: 'Client: Apex Solar Solutions',
    },
  ];

  async getBankAccounts() {
    return this.bankAccounts.map((acc) => {
      const balance = this.calculateAccountBalance(acc);
      return {
        ...acc,
        currentBalance: balance,
      };
    });
  }

  async saveBankAccount(dto: any) {
    if (dto.id) {
      const idx = this.bankAccounts.findIndex((a) => a.id === dto.id);
      if (idx >= 0) {
        this.bankAccounts[idx] = {
          ...this.bankAccounts[idx],
          ...dto,
          openingBalance: Number(dto.openingBalance) || 0,
        };
        return this.bankAccounts[idx];
      }
    }
    const newAcc = {
      id: dto.id || `acc-${Date.now()}`,
      accountName: dto.accountName || 'New Account',
      bankName: dto.bankName || 'Bank',
      accountNumber: dto.accountNumber || '',
      openingBalance: Number(dto.openingBalance) || 0,
      notes: dto.notes || '',
    };
    this.bankAccounts.push(newAcc);
    return newAcc;
  }

  async deleteBankAccount(id: string) {
    const idx = this.bankAccounts.findIndex((a) => a.id === id);
    if (idx >= 0) {
      const removed = this.bankAccounts.splice(idx, 1);
      return { success: true, removed: removed[0] };
    }
    return { success: false, message: 'Account not found' };
  }

  async getBankTransactions() {
    return this.bankTransactions;
  }

  async saveBankTransaction(dto: any) {
    if (dto.id) {
      const idx = this.bankTransactions.findIndex((t) => t.id === dto.id);
      if (idx >= 0) {
        this.bankTransactions[idx] = {
          ...this.bankTransactions[idx],
          ...dto,
          amount: Number(dto.amount) || 0,
        };
        return this.bankTransactions[idx];
      }
    }
    const newTx = {
      id: dto.id || `tx-${Date.now()}`,
      date: dto.date || new Date().toISOString().split('T')[0],
      accountName: dto.accountName,
      type: dto.type || 'Deposit',
      amount: Number(dto.amount) || 0,
      description: dto.description || '',
      reference: dto.reference || '',
      notes: dto.notes || '',
    };
    this.bankTransactions.unshift(newTx);
    return newTx;
  }

  async deleteBankTransaction(id: string) {
    const idx = this.bankTransactions.findIndex((t) => t.id === id);
    if (idx >= 0) {
      const removed = this.bankTransactions.splice(idx, 1);
      return { success: true, removed: removed[0] };
    }
    return { success: false, message: 'Transaction not found' };
  }

  calculateAccountBalance(acc: any): number {
    const creditTypes = new Set(['Deposit', 'Cash In']);
    const debitTypes = new Set(['Withdrawal', 'Cash Out', 'Bank Charge']);
    let bal = Number(acc.openingBalance) || 0;
    for (const tx of this.bankTransactions) {
      if (tx.accountName?.toLowerCase().trim() === acc.accountName?.toLowerCase().trim()) {
        const amt = Number(tx.amount) || 0;
        if (creditTypes.has(tx.type)) bal += amt;
        else if (debitTypes.has(tx.type)) bal -= amt;
      }
    }
    return bal;
  }

  async getBankCashSummary() {
    const accountsWithBalance = await this.getBankAccounts();
    const totalBalance = accountsWithBalance.reduce((sum, a) => sum + a.currentBalance, 0);
    return {
      totalBalance,
      accountsCount: this.bankAccounts.length,
      transactionsCount: this.bankTransactions.length,
      accounts: accountsWithBalance,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // EXPENSES MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────────

  private expenses: any[] = [
    {
      id: 'exp-1',
      date: '2026-10-01',
      category: 'Rent',
      description: 'Factory and corporate office monthly premises lease',
      amount: 45000.00,
      paymentMethod: 'Bank Transfer',
      paidTo: 'Chakan Industrial Estates Ltd',
      notes: 'Monthly Lease Agreement, Voucher #VCH-1001',
    },
    {
      id: 'exp-2',
      date: '2026-10-05',
      category: 'Electricity',
      description: 'MSEDCL industrial electrical connection power tariff',
      amount: 18450.00,
      paymentMethod: 'UPI',
      paidTo: 'Maharashtra State Electricity Board',
      notes: 'Meter #MTR-88192-IND',
    },
    {
      id: 'exp-3',
      date: '2026-10-08',
      category: 'Internet / Mobile',
      description: 'Tata Tele broadband fiber and staff corporate CUG lines',
      amount: 4200.00,
      paymentMethod: 'Credit Card',
      paidTo: 'Tata Teleservices Ltd',
      notes: 'Bill ref: TT-OCT-2026',
    },
    {
      id: 'exp-4',
      date: '2026-10-10',
      category: 'Salary',
      description: 'Staff advance and fabrication team overtime disbursements',
      amount: 32000.00,
      paymentMethod: 'Bank Transfer',
      paidTo: 'Operations & Fabrication Staff',
      notes: 'Pay Sheet Reference: PS-2026-10A',
    },
    {
      id: 'exp-5',
      date: '2026-10-12',
      category: 'Travel',
      description: 'Client site technical survey & commissioning trip to Nashik',
      amount: 6800.00,
      paymentMethod: 'Cash',
      paidTo: 'Sunil Jagtap (Site Engineer)',
      notes: 'Toll receipts & fuel vouchers attached',
    },
    {
      id: 'exp-6',
      date: '2026-10-14',
      category: 'Repairs',
      description: 'CNC bending tool calibrator and hydraulic pump servicing',
      amount: 8500.00,
      paymentMethod: 'UPI',
      paidTo: 'Apex Tooling Works',
      notes: 'Warranty maintenance check',
    },
  ];

  async getExpenses(query?: { category?: string; search?: string }) {
    let result = [...this.expenses];
    if (query?.category && query.category !== 'All') {
      result = result.filter((e) => e.category === query.category);
    }
    if (query?.search) {
      const q = query.search.toLowerCase();
      result = result.filter(
        (e) =>
          e.description?.toLowerCase().includes(q) ||
          e.paidTo?.toLowerCase().includes(q) ||
          e.notes?.toLowerCase().includes(q) ||
          e.category?.toLowerCase().includes(q)
      );
    }
    return result;
  }

  async saveExpense(dto: any) {
    if (dto.id) {
      const idx = this.expenses.findIndex((e) => e.id === dto.id);
      if (idx >= 0) {
        this.expenses[idx] = {
          ...this.expenses[idx],
          ...dto,
          amount: Number(dto.amount) || 0,
        };
        return this.expenses[idx];
      }
    }
    const newExp = {
      id: dto.id || `exp-${Date.now()}`,
      date: dto.date || new Date().toISOString().split('T')[0],
      category: dto.category || 'Other',
      description: dto.description || '',
      amount: Number(dto.amount) || 0,
      paymentMethod: dto.paymentMethod || 'Cash',
      paidTo: dto.paidTo || '',
      notes: dto.notes || '',
    };
    this.expenses.unshift(newExp);
    return newExp;
  }

  async deleteExpense(id: string) {
    const idx = this.expenses.findIndex((e) => e.id === id);
    if (idx >= 0) {
      const removed = this.expenses.splice(idx, 1);
      return { success: true, removed: removed[0] };
    }
    return { success: false, message: 'Expense record not found' };
  }

  async getExpenseSummary() {
    const totalExpenses = this.expenses.reduce((sum, e) => sum + (Number(e.amount) || 0), 0);

    const now = new Date();
    const currentYearMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const thisMonthExpenses = this.expenses
      .filter((e) => e.date && e.date.startsWith(currentYearMonth))
      .reduce((sum, e) => sum + (Number(e.amount) || 0), 0);

    // Category distribution
    const categoryTotals: Record<string, number> = {};
    for (const exp of this.expenses) {
      const cat = exp.category || 'Other';
      categoryTotals[cat] = (categoryTotals[cat] || 0) + (Number(exp.amount) || 0);
    }

    let topCategory = '—';
    let maxCatTotal = 0;
    for (const [cat, total] of Object.entries(categoryTotals)) {
      if (total > maxCatTotal) {
        maxCatTotal = total;
        topCategory = cat;
      }
    }

    const categoryBreakdown = Object.entries(categoryTotals)
      .map(([cat, subtotal]) => ({
        category: cat,
        subtotal,
        percentage: totalExpenses > 0 ? (subtotal / totalExpenses) * 100 : 0,
      }))
      .sort((a, b) => b.subtotal - a.subtotal);

    return {
      totalExpenses,
      thisMonthExpenses,
      topCategory,
      totalCount: this.expenses.length,
      categoryBreakdown,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // OUTWARD DOCUMENTS MANAGEMENT (OTHER DOCUMENTS)
  // ─────────────────────────────────────────────────────────────────────────────

  private outwardEntries: any[] = [
    {
      id: 'out-1',
      documentType: 'Quotation',
      documentDate: '2026-08-22',
      documentNo: 'Q-20260822-001',
      customer: 'Naga Pumps Private Limited',
      department: 'Office',
      itemDescription: 'HMI CONTROLLER STP 6 Nos',
      quantity: 1,
      rate: 70000.00,
      amount: 70000.00,
      notes: 'Standard Quotation for Municipal Water project',
      createdAt: '2026-08-22T10:00:00.000Z',
    },
    {
      id: 'out-2',
      documentType: 'Delivery Challan',
      documentDate: '2026-09-25',
      documentNo: 'DC-20260925-001',
      customer: 'Win Win Distribution Pvt Ltd',
      department: 'Panel Department',
      itemDescription: 'AI-PCU02 WITH HMI DISPLAY 1 Nos',
      quantity: 1,
      rate: 50000.00,
      amount: 50000.00,
      notes: 'Direct factory dispatch via SafeXpress',
      createdAt: '2026-09-25T14:30:00.000Z',
    },
  ];

  generateNextOutwardNumber(documentType: string = 'Quotation', documentDate?: string): { documentNo: string; prefix: string; sequence: number } {
    const matches = documentType.match(/[A-Za-z]+/g) || ['DOC'];
    const typeCode = matches.map((w) => w[0].toUpperCase()).join('') || 'DOC';

    let dateCode = '';
    if (documentDate) {
      dateCode = documentDate.replace(/[^0-9]/g, '');
    }
    if (!dateCode || dateCode.length < 8) {
      const now = new Date();
      dateCode = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
    } else {
      dateCode = dateCode.substring(0, 8);
    }

    const prefix = `${typeCode}-${dateCode}-`;
    let highest = 0;
    for (const entry of this.outwardEntries) {
      const docNo = (entry.documentNo || '').trim();
      if (docNo.startsWith(prefix)) {
        const suffix = docNo.substring(prefix.length);
        const parsed = parseInt(suffix, 10);
        if (!isNaN(parsed) && parsed > highest) {
          highest = parsed;
        }
      }
    }
    const sequence = highest + 1;
    const documentNo = `${prefix}${String(sequence).padStart(3, '0')}`;
    return { documentNo, prefix, sequence };
  }

  async getOutwardDocuments(query?: { documentType?: string; search?: string }) {
    let result = [...this.outwardEntries];
    if (query?.documentType && query.documentType !== 'All') {
      result = result.filter((e) => e.documentType === query.documentType);
    }
    if (query?.search) {
      const q = query.search.toLowerCase();
      result = result.filter(
        (e) =>
          e.documentNo?.toLowerCase().includes(q) ||
          e.customer?.toLowerCase().includes(q) ||
          e.itemDescription?.toLowerCase().includes(q) ||
          e.department?.toLowerCase().includes(q) ||
          e.notes?.toLowerCase().includes(q)
      );
    }
    return result;
  }

  async saveOutwardDocument(dto: {
    documentType: string;
    documentDate: string;
    documentNo: string;
    customer: string;
    department?: string;
    items: Array<{
      itemDescription: string;
      quantity: number;
      rate: number;
      amount?: number;
    }>;
    notes?: string;
  }) {
    if (!dto.documentNo || !dto.documentNo.trim()) {
      throw new BadRequestException('Document number is required');
    }
    if (!dto.customer || !dto.customer.trim()) {
      throw new BadRequestException('Customer name is required');
    }
    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('At least one product / material item is required');
    }

    const docNo = dto.documentNo.trim();
    // Remove existing entries with the same document number if updating
    this.outwardEntries = this.outwardEntries.filter((e) => e.documentNo !== docNo);

    const savedEntries: any[] = [];
    let grandTotal = 0;

    for (let i = 0; i < dto.items.length; i++) {
      const item = dto.items[i];
      const qty = Number(item.quantity) || 1;
      const rate = Number(item.rate) || 0;
      const amt = Number(item.amount) || (qty * rate);
      grandTotal += amt;

      const entry = {
        id: `out-${Date.now()}-${i + 1}`,
        documentType: dto.documentType || 'Quotation',
        documentDate: dto.documentDate || new Date().toISOString().split('T')[0],
        documentNo: docNo,
        customer: dto.customer.trim(),
        department: dto.department || 'Panel Department',
        itemDescription: item.itemDescription || '',
        quantity: qty,
        rate: rate,
        amount: amt,
        notes: dto.notes || '',
        createdAt: new Date().toISOString(),
      };
      this.outwardEntries.unshift(entry);
      savedEntries.push(entry);
    }

    return {
      success: true,
      documentNo: docNo,
      documentType: dto.documentType,
      itemCount: savedEntries.length,
      totalAmount: grandTotal,
      entries: savedEntries,
    };
  }

  async deleteOutwardDocument(docNo: string) {
    const beforeCount = this.outwardEntries.length;
    this.outwardEntries = this.outwardEntries.filter((e) => e.documentNo !== docNo);
    const deletedCount = beforeCount - this.outwardEntries.length;
    return {
      success: deletedCount > 0,
      deletedCount,
      message: deletedCount > 0 ? `Deleted outward document ${docNo}` : 'Document not found',
    };
  }

  async getOutwardCustomers() {
    const dbCustomers = await this.prisma.customer.findMany({
      select: { companyName: true },
      take: 50,
    });
    const names = new Set<string>();
    names.add('Win Win Distribution Pvt Ltd');
    names.add('Naga Pumps Private Limited');
    names.add('TechMech Automation');
    names.add('Apex Solar Solutions');
    names.add('Satyam Infotech');
    names.add('Shree Ganesh Engineering');
    names.add('Revolve Engineers');
    names.add('RKS Engineering Company');
    names.add('AJANI COMPAY');
    for (const c of dbCustomers) {
      if (c.companyName?.trim()) names.add(c.companyName.trim());
    }
    return Array.from(names).sort();
  }

  async getOutwardCatalog() {
    const dbProducts = await this.prisma.product.findMany({
      select: { id: true, name: true, sku: true, sellingPrice: true, description: true, unit: true },
      take: 50,
    });
    const catalog = [
      {
        id: 'cat-1',
        name: 'AI-PCU02 WITH HMI DISPLAY',
        capacity: '1 Nos',
        supplier: 'Saark Exploration Pvt Ltd',
        price: 50000,
        label: 'AI-PCU02 WITH HMI DISPLAY | 1 Nos | Saark Exploration Pvt Ltd',
      },
      {
        id: 'cat-2',
        name: 'AI-PCU02 WITH HMI DISPLAY',
        capacity: '2 Nos',
        supplier: 'Saark Exploration Pvt Ltd',
        price: 39000,
        label: 'AI-PCU02 WITH HMI DISPLAY | 2 Nos | Saark Exploration Pvt Ltd',
      },
      {
        id: 'cat-3',
        name: 'AIPCU HMI CONTROLLER MULTIVFD',
        capacity: '3 Nos',
        supplier: 'Saark Exploration Pvt Ltd',
        price: 80000,
        label: 'AIPCU HMI CONTROLLER MULTIVFD | 3 Nos | Saark Exploration Pvt Ltd',
      },
      {
        id: 'cat-4',
        name: 'AIPCU HMI CONTROLLER MULTIVFD',
        capacity: '4 Nos',
        supplier: 'Saark Exploration Pvt Ltd',
        price: 60000,
        label: 'AIPCU HMI CONTROLLER MULTIVFD | 4 Nos | Saark Exploration Pvt Ltd',
      },
      {
        id: 'cat-5',
        name: 'HMI CONTROLLER STP',
        capacity: '6 Nos',
        supplier: 'Saark Exploration Pvt Ltd',
        price: 70000,
        label: 'HMI CONTROLLER STP | 6 Nos | Saark Exploration Pvt Ltd',
      },
    ];
    for (const p of dbProducts) {
      const unitStr = typeof (p as any).unit === 'string' ? (p as any).unit : ((p as any).unit?.name || '1 Nos');
      catalog.push({
        id: p.id,
        name: p.name,
        capacity: unitStr,
        supplier: 'Saark Exploration Pvt Ltd',
        price: Number(p.sellingPrice) || 0,
        label: `${p.name} | ${unitStr} | Saark Exploration Pvt Ltd`,
      });
    }
    return catalog;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FINANCIAL REPORTS AGGREGATOR
  // ─────────────────────────────────────────────────────────────────────────────

  async getFinancialReports(period?: string) {
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    const currentMonth = period && period.trim() ? period.trim() : `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

    // 1. Sales / Invoices
    const dbInvoices = await this.prisma.salesInvoice.findMany({
      include: { customer: { select: { companyName: true } } },
      orderBy: { createdAt: 'desc' },
    });

    let todaySales = 0;
    let monthlySales = 0;
    let totalReceived = 0;

    const salesLedger = [
      {
        id: 'si-1',
        date: '2026-10-02',
        customerName: 'Win Win Distribution Pvt Ltd',
        invoiceNumber: 'INV-2026-1001',
        productService: 'Solar Pump Controller VFD 5HP',
        invoiceAmount: 145000.00,
        amountReceived: 100000.00,
        pendingAmount: 45000.00,
        dueDate: '2026-10-25',
        status: 'Partial',
      },
      {
        id: 'si-2',
        date: '2026-10-08',
        customerName: 'Naga Pumps Private Limited',
        invoiceNumber: 'INV-2026-1002',
        productService: 'Water Level Automation Panel',
        invoiceAmount: 85000.00,
        amountReceived: 85000.00,
        pendingAmount: 0.00,
        dueDate: '2026-10-20',
        status: 'Paid',
      },
      {
        id: 'si-3',
        date: today,
        customerName: 'TechMech Automation',
        invoiceNumber: 'INV-2026-1003',
        productService: 'PLC Panel MultiVFD 10HP',
        invoiceAmount: 65000.00,
        amountReceived: 30000.00,
        pendingAmount: 35000.00,
        dueDate: '2026-11-05',
        status: 'Partial',
      },
      {
        id: 'si-4',
        date: '2026-09-18',
        customerName: 'Revolve Engineers',
        invoiceNumber: 'INV-2026-0915',
        productService: 'Custom MCC Electrical Panel',
        invoiceAmount: 120000.00,
        amountReceived: 50000.00,
        pendingAmount: 70000.00,
        dueDate: '2026-10-10',
        status: 'Overdue',
      },
    ];

    for (const s of salesLedger) {
      if (s.date === today) todaySales += s.invoiceAmount;
      if (!currentMonth || currentMonth === 'All' || s.date.startsWith(currentMonth)) {
        monthlySales += s.invoiceAmount;
        totalReceived += s.amountReceived;
      }
    }

    for (const inv of dbInvoices) {
      const invDate = inv.createdAt.toISOString().split('T')[0];
      const amt = Number(inv.grandTotal) || 0;
      if (invDate === today) todaySales += amt;
      if (!currentMonth || currentMonth === 'All' || invDate.startsWith(currentMonth)) {
        monthlySales += amt;
        if (inv.status === 'PAID') totalReceived += amt;
      }
    }

    // 2. Bank & Cash Liquidity
    const bankSummary = await this.getBankCashSummary();
    const bankBalance = bankSummary.accounts
      .filter((a: any) => a.accountType === 'Bank' || a.accountType === 'Current' || a.accountType === 'Savings')
      .reduce((sum: number, a: any) => sum + (Number(a.currentBalance) || 0), 0);
    const cashBalance = bankSummary.accounts
      .filter((a: any) => a.accountType === 'Cash')
      .reduce((sum: number, a: any) => sum + (Number(a.currentBalance) || 0), 0);

    // 3. Customer Outstanding (AR)
    const customerPending = salesLedger
      .filter((s) => s.pendingAmount > 0 && s.status !== 'Paid')
      .map((s) => ({
        customer: s.customerName,
        invoiceNumber: s.invoiceNumber,
        invoiceDate: s.date,
        dueDate: s.dueDate,
        invoiceAmount: s.invoiceAmount,
        amountReceived: s.amountReceived,
        pendingAmount: s.pendingAmount,
        status: s.status,
      }));
    const customerOutstanding = customerPending.reduce((sum, p) => sum + p.pendingAmount, 0);

    // 4. Vendor Outstanding (AP)
    const vendorPending = [
      {
        vendor: 'Apex Copper Conductors Ltd',
        billNumber: 'BILL-2026-881',
        billDate: '2026-09-28',
        dueDate: '2026-10-15',
        billAmount: 68000.00,
        amountPaid: 20000.00,
        pendingAmount: 48000.00,
        status: 'Overdue',
      },
      {
        vendor: 'Siemens Switchgear Agencies',
        billNumber: 'BILL-2026-904',
        billDate: '2026-10-05',
        dueDate: '2026-10-28',
        billAmount: 92000.00,
        amountPaid: 45000.00,
        pendingAmount: 47000.00,
        status: 'Partial',
      },
      {
        vendor: 'Schneider Electric Components',
        billNumber: 'BILL-2026-920',
        billDate: '2026-10-10',
        dueDate: '2026-11-05',
        billAmount: 38000.00,
        amountPaid: 0.00,
        pendingAmount: 38000.00,
        status: 'Unpaid',
      },
    ];
    const vendorOutstanding = vendorPending.reduce((sum, p) => sum + p.pendingAmount, 0);

    // 5. Monthly Expenses & Category breakdown
    const filteredExpenses = this.expenses.filter((e) => !currentMonth || currentMonth === 'All' || (e.date && e.date.startsWith(currentMonth)));
    const monthlyExpense = filteredExpenses.reduce((sum, e) => sum + (Number(e.amount) || 0), 0);
    const expenseByCategory: Record<string, number> = {};
    for (const e of filteredExpenses) {
      const cat = e.category || 'Other';
      expenseByCategory[cat] = (expenseByCategory[cat] || 0) + (Number(e.amount) || 0);
    }

    // 6. Monthly Profit / Loss
    const monthlyProfit = monthlySales - monthlyExpense;

    // 7. GST Payable (Output sales liability - Input tax credit)
    const outputGst = monthlySales * 0.18;
    const inputGst = (vendorOutstanding * 0.18) + 12500.00;
    const gstPayable = Math.max(outputGst - inputGst, 0.0);

    // 8. Inventory Stock Valuation
    const products = await this.prisma.product.findMany({ select: { currentStock: true, purchasePrice: true } });
    let inventoryValue = products.reduce((sum, p) => sum + ((p.currentStock || 0) * (Number(p.purchasePrice) || 0)), 0);
    if (inventoryValue <= 0) inventoryValue = 345000.00;

    // 9. Salary Payable
    const salaryPayable = 28500.00;

    // P&L Sections
    const plIncomeRows = [
      { category: 'Sales', description: 'Total Sales / Revenue', amount: monthlySales },
      { category: 'Sales', description: 'Amount Received', amount: totalReceived },
      { category: 'Sales', description: 'Pending Receivable', amount: Math.max(monthlySales - totalReceived, 0) },
    ];
    const plExpenseRows = Object.entries(expenseByCategory).map(([cat, amt]) => ({
      category: 'Expense',
      description: cat,
      amount: amt,
    }));
    if (salaryPayable > 0) {
      plExpenseRows.push({ category: 'Expense', description: 'Salary Payable', amount: salaryPayable });
    }
    const totalPlExpenses = monthlyExpense + salaryPayable;
    const netOperatingProfit = monthlySales - totalPlExpenses;

    // Cash Flow Sections
    const cfInflowRows = [
      { section: 'Operating', description: 'Cash received from customers', amount: totalReceived },
      { section: 'Financing', description: 'Bank deposits / Cash in', amount: 50000.00 },
    ];
    const cfTotalIn = totalReceived + 50000.00;
    const cfOutflowRows = [
      { section: 'Operating', description: 'Business Expenses', amount: monthlyExpense },
      { section: 'Operating', description: 'Vendor / Supplier Payments', amount: 65000.00 },
      { section: 'Payroll', description: 'Salary Paid', amount: 32000.00 },
    ];
    const cfTotalOut = monthlyExpense + 65000.00 + 32000.00;
    const netCashFlow = cfTotalIn - cfTotalOut;

    // Balance Sheet Sections
    const totalAssets = bankBalance + cashBalance + customerOutstanding + inventoryValue;
    const totalLiabilities = vendorOutstanding + salaryPayable + gstPayable;
    const ownerEquity = totalAssets - totalLiabilities;

    const bsAssetRows = [
      { section: 'Current Assets', item: 'Bank Balance', amount: bankBalance },
      { section: 'Current Assets', item: 'Cash in Hand', amount: cashBalance },
      { section: 'Current Assets', item: 'Accounts Receivable (AR)', amount: customerOutstanding },
      { section: 'Current Assets', item: 'Inventory / Stock Value', amount: inventoryValue },
    ];
    const bsLiabilityRows = [
      { section: 'Current Liabilities', item: 'Accounts Payable (AP)', amount: vendorOutstanding },
      { section: 'Current Liabilities', item: 'Salary Payable', amount: salaryPayable },
      { section: 'Current Liabilities', item: 'GST Payable', amount: gstPayable },
    ];
    const bsEquityRows = [
      { section: "Owner's Equity", item: 'Net Company Capital', amount: ownerEquity },
    ];

    return {
      period: currentMonth,
      dashboard: {
        todaySales,
        monthlySales,
        bankBalance,
        cashBalance,
        customerOutstanding,
        vendorOutstanding,
        monthlyExpense,
        monthlyProfit,
        gstPayable,
      },
      profitAndLoss: {
        incomeRows: plIncomeRows,
        expenseRows: plExpenseRows,
        totalIncome: monthlySales,
        totalExpenses: totalPlExpenses,
        netProfit: netOperatingProfit,
      },
      cashFlow: {
        inflowRows: cfInflowRows,
        outflowRows: cfOutflowRows,
        totalInflow: cfTotalIn,
        totalOutflow: cfTotalOut,
        netCashFlow,
      },
      balanceSheet: {
        assetRows: bsAssetRows,
        liabilityRows: bsLiabilityRows,
        equityRows: bsEquityRows,
        totalAssets,
        totalLiabilities,
        totalEquity: ownerEquity,
      },
      outstanding: {
        totalCustomerOutstanding: customerOutstanding,
        totalVendorOutstanding: vendorOutstanding,
        customerPending,
        vendorPending,
      },
    };
  }
}
