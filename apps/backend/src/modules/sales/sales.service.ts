import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';

@Injectable()
export class SalesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
  ) {}

  private isSalesAdminOrManager(user?: any): boolean {
    if (!user) return false;
    const roles: string[] = user.roles || [];
    return (
      roles.includes('ROLE_ADMIN') ||
      roles.includes('ADMIN') ||
      roles.includes('ROLE_SUPER_ADMIN') ||
      roles.includes('ROLE_SALES_MGR') ||
      roles.includes('SALES_MANAGER')
    );
  }

  private assertQuotationAccess(quotation: any, user: any) {
    if (!quotation) throw new NotFoundException('Quotation not found');
    if (this.isSalesAdminOrManager(user)) return;
    if (!user || !user.staffId) {
      throw new ForbiddenException('Access denied: unmapped employee cannot access quotations');
    }
    const isAssigned = quotation.assignedStaffId === user.staffId;
    const isCustomerAssigned = quotation.customer?.assignedStaffId === user.staffId;
    if (!isAssigned && !isCustomerAssigned) {
      throw new ForbiddenException('Access denied: you do not have permission to access this quotation');
    }
  }

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

  async getQuotations(
    query: {
      customerId?: string;
      opportunityId?: string;
      status?: string;
      search?: string;
      page?: number;
      limit?: number;
    },
    user?: any,
  ) {
    const { customerId, opportunityId, status, search, page = 1, limit = 50 } = query;
    const skip = (Number(page) - 1) * Number(limit);
    const take = Number(limit);

    if (!this.isSalesAdminOrManager(user)) {
      if (!user?.staffId) {
        return { items: [], total: 0, page: Number(page), limit: Number(limit), totalPages: 0 };
      }
    }

    const conditions: any[] = [];
    if (!this.isSalesAdminOrManager(user)) {
      conditions.push({ assignedStaffId: user.staffId });
    }

    if (customerId) conditions.push({ customerId });
    if (opportunityId) conditions.push({ opportunityId });
    if (status) conditions.push({ status });
    if (search) {
      conditions.push({
        OR: [
          { quotationNumber: { contains: search } },
          { code: { contains: search } },
          { subject: { contains: search } },
          { customer: { companyName: { contains: search } } },
        ],
      });
    }

    const where: any = conditions.length > 0 ? { AND: conditions } : {};

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

    return { items, total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) };
  }

  async getQuotationById(id: string, user?: any) {
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
    this.assertQuotationAccess(quotation, user);

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

  async createQuotation(dto: any, user?: any) {
    if (!dto.customerId) throw new BadRequestException('customerId is required');

    if (!this.isSalesAdminOrManager(user)) {
      if (!user?.staffId) {
        throw new ForbiddenException('Access denied: unmapped employee cannot create quotations');
      }
      const customer = await this.prisma.customer.findUnique({ where: { id: dto.customerId } });
      if (!customer) throw new NotFoundException('Customer not found');
      if (customer.assignedStaffId !== user.staffId && customer.createdByUserId !== user.id) {
        throw new ForbiddenException('Access denied: cannot generate quotation for unassigned customer');
      }
      if (dto.opportunityId) {
        const opp = await this.prisma.opportunity.findUnique({ where: { id: dto.opportunityId } });
        if (!opp) throw new NotFoundException('Opportunity not found');
        if (opp.assignedStaffId !== user.staffId && opp.salesManagerStaffId !== user.staffId) {
          throw new ForbiddenException('Access denied: cannot generate quotation for unassigned opportunity');
        }
      }
    }

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
    if (!this.isSalesAdminOrManager(user)) {
      assignedStaffId = user?.staffId;
    } else if (!assignedStaffId && user?.staffId) {
      assignedStaffId = user.staffId;
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

  async createFromPanelSpec(panelSpecId: string, dto: any, user?: any) {
    const panelSpec = await this.prisma.panelSpecification.findUnique({
      where: { id: panelSpecId },
      include: { customer: true, bomItems: { include: { product: true } } },
    });

    if (!panelSpec) throw new NotFoundException(`Panel Specification "${panelSpecId}" not found`);

    if (!this.isSalesAdminOrManager(user)) {
      if (!user?.staffId) {
        throw new ForbiddenException('Access denied: unmapped employee cannot create quotations from panel spec');
      }
      if (panelSpec.customer && panelSpec.customer.assignedStaffId !== user.staffId && panelSpec.customer.createdByUserId !== user.id) {
        throw new ForbiddenException('Access denied: cannot generate quotation for unassigned customer');
      }
    }
    const userId = user?.id;

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
    if (!this.isSalesAdminOrManager(user)) {
      assignedStaffId = user?.staffId;
    } else if (!assignedStaffId && userId) {
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

  async createRevision(id: string, dto: any, user?: any) {
    const baseQuotation = await this.prisma.quotation.findUnique({
      where: { id },
      include: { items: true, customer: true },
    });
    if (!baseQuotation) throw new NotFoundException(`Base Quotation with ID "${id}" not found`);
    this.assertQuotationAccess(baseQuotation, user);

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
    if (!this.isSalesAdminOrManager(user)) {
      assignedStaffId = user?.staffId;
    } else if (!assignedStaffId && user?.staffId) {
      assignedStaffId = user.staffId;
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

  async updateQuotationStatus(id: string, dto: { status: string; notes?: string }, user?: any) {
    const quotation = await this.prisma.quotation.findUnique({ where: { id }, include: { customer: true } });
    if (!quotation) throw new NotFoundException(`Quotation with ID "${id}" not found`);

    await this.assertQuotationAccess(quotation, user);

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

  async convertToSalesOrder(quotationId: string, dto: any, user?: any) {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id: quotationId },
      include: { customer: true, items: true },
    });
    if (!quotation) throw new NotFoundException(`Quotation with ID "${quotationId}" not found`);

    await this.assertQuotationAccess(quotation, user);

    const orderNumber = dto.orderNumber || (await this.sequenceService.nextSalesOrderNumber());

    let assignedStaffId = dto.assignedStaffId || quotation.assignedStaffId;
    if (!assignedStaffId && user?.id) {
      const staff = await this.prisma.staff.findFirst({ where: { userId: user.id } });
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
    const { customerId, status, productionStatus, search, page = 1, limit = 50 } = query;
    const skip = (Number(page) - 1) * Number(limit);
    const take = Number(limit);

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

    return { items, total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) };
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
    const { customerId, salesOrderId, status, paymentStatus, search, page = 1, limit = 50 } = query;
    const skip = (Number(page) - 1) * Number(limit);
    const take = Number(limit);

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

    return { items, total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) };
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

    return this.prisma.salesInvoice.create({
      data: {
        invoiceNumber,
        salesOrderId: dto.salesOrderId || null,
        customerId: dto.customerId,
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
}
