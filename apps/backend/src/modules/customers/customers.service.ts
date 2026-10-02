import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Injectable()
export class CustomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async findAll(query?: {
    search?: string;
    type?: string;
    category?: string;
    status?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.type) where.customerType = query.type;
    if (query?.category) where.customerCategory = query.category;
    if (query?.search) {
      where.OR = [
        { companyName: { contains: query.search } },
        { customerCode: { contains: query.search } },
        { gstin: { contains: query.search } },
        { contactPerson: { contains: query.search } },
        { email: { contains: query.search } },
        { phone: { contains: query.search } },
        { city: { contains: query.search } },
        { state: { contains: query.search } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.customer.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          contacts: { where: { isPrimary: true }, take: 1 },
          valuations: true,
          _count: { select: { interactions: true, enquiries: true, leads: true, panelSpecs: true } },
        },
      }),
      this.prisma.customer.count({ where }),
    ]);

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async findOne(id: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        contacts: { orderBy: { isPrimary: 'desc' } },
        interactions: { orderBy: { interactionDate: 'desc' }, take: 50 },
        valuations: true,
        leads: { orderBy: { createdAt: 'desc' } },
        enquiries: { orderBy: { createdAt: 'desc' } },
        panelSpecs: {
          orderBy: { createdAt: 'desc' },
          include: { bomItems: { include: { product: true } } },
        },
      },
    });

    if (!customer) throw new NotFoundException(`Customer ${id} not found`);
    return customer;
  }

  async create(dto: any, userId?: string, userEmail?: string) {
    // Check GST uniqueness
    if (dto.gstin) {
      const exists = await this.prisma.customer.findFirst({ where: { gstin: dto.gstin } });
      if (exists) throw new ConflictException(`A customer with GSTIN ${dto.gstin} already exists`);
    }

    const count = await this.prisma.customer.count();
    const year = new Date().getFullYear();
    const customerCode = `CUS-${year}-${String(count + 1).padStart(5, '0')}`;

    const customer = await this.prisma.customer.create({
      data: {
        customerCode,
        companyName: dto.companyName,
        gstin: dto.gstin,
        pan: dto.pan,
        customerType: dto.customerType || 'END_CUSTOMER',
        customerCategory: dto.customerCategory || 'STANDARD',
        contactPerson: dto.contactPerson,
        designation: dto.designation,
        email: dto.email,
        phone: dto.phone,
        alternatePhone: dto.alternatePhone,
        website: dto.website,
        address: dto.address,
        country: dto.country || 'India',
        state: dto.state,
        district: dto.district,
        city: dto.city,
        pincode: dto.pincode,
        ownerName: dto.ownerName,
        staffCount: Number(dto.staffCount || 0),
        turnover: dto.turnover,
        industry: dto.industry,
        source: dto.source || 'DIRECT',
        status: 'ACTIVE',
      },
    });

    // Auto-create primary contact from master contact data
    await this.prisma.customerContact.create({
      data: {
        customerId: customer.id,
        name: dto.contactPerson,
        designation: dto.designation,
        mobile: dto.phone,
        email: dto.email,
        whatsapp: dto.phone,
        isPrimary: true,
      },
    });

    // Initialize valuation record
    await this.prisma.customerValuation.create({
      data: {
        customerId: customer.id,
        isDealer: dto.customerType === 'DEALER',
        isDistributor: dto.customerType === 'DISTRIBUTOR',
        ratingScore: 5.0,
        valuablePercentage: 50.0,
        activityCount: 0,
      },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'CREATE',
      module: 'CUSTOMERS',
      entityType: 'Customer',
      entityId: customer.id,
      details: `Created Customer: ${customer.companyName} (${customer.customerCode})`,
    });

    return customer;
  }

  async update(id: string, dto: any, userId?: string, userEmail?: string) {
    const existing = await this.prisma.customer.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Customer not found');

    // GST uniqueness check excluding self
    if (dto.gstin && dto.gstin !== existing.gstin) {
      const dup = await this.prisma.customer.findFirst({
        where: { gstin: dto.gstin, NOT: { id } },
      });
      if (dup) throw new ConflictException(`GSTIN ${dto.gstin} is already assigned to another customer`);
    }

    const updatable: any = {};
    const fields = [
      'companyName', 'gstin', 'pan', 'customerType', 'customerCategory',
      'contactPerson', 'designation', 'email', 'phone', 'alternatePhone',
      'website', 'address', 'country', 'state', 'district', 'city',
      'pincode', 'ownerName', 'staffCount', 'turnover', 'industry',
      'source', 'customerRating', 'status',
    ];
    fields.forEach((f) => { if (dto[f] !== undefined) updatable[f] = dto[f]; });

    const customer = await this.prisma.customer.update({ where: { id }, data: updatable });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'UPDATE',
      module: 'CUSTOMERS',
      entityType: 'Customer',
      entityId: id,
      details: `Updated Customer: ${customer.companyName}`,
    });

    return customer;
  }

  async delete(id: string, userId?: string, userEmail?: string) {
    const existing = await this.prisma.customer.findUnique({
      where: { id },
      include: { _count: { select: { enquiries: true, leads: true } } },
    });
    if (!existing) throw new NotFoundException('Customer not found');

    // Soft delete — mark inactive rather than physical delete
    await this.prisma.customer.update({ where: { id }, data: { status: 'DELETED' } });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'DELETE',
      module: 'CUSTOMERS',
      entityType: 'Customer',
      entityId: id,
      details: `Soft-deleted Customer: ${existing.companyName} (${existing.customerCode})`,
    });

    return { message: 'Customer marked as deleted' };
  }

  // ─── CONTACTS ──────────────────────────────────────────────────────────────

  async addContact(customerId: string, dto: any, userId?: string) {
    const customer = await this.prisma.customer.findUnique({ where: { id: customerId } });
    if (!customer) throw new NotFoundException('Customer not found');

    if (dto.isPrimary) {
      await this.prisma.customerContact.updateMany({
        where: { customerId },
        data: { isPrimary: false },
      });
    }

    return this.prisma.customerContact.create({
      data: {
        customerId,
        name: dto.name,
        designation: dto.designation,
        department: dto.department,
        phone: dto.phone,
        mobile: dto.mobile,
        email: dto.email,
        whatsapp: dto.whatsapp,
        isPrimary: dto.isPrimary ?? false,
        notes: dto.notes,
      },
    });
  }

  async updateContact(contactId: string, dto: any) {
    const existing = await this.prisma.customerContact.findUnique({ where: { id: contactId } });
    if (!existing) throw new NotFoundException('Contact not found');

    if (dto.isPrimary) {
      await this.prisma.customerContact.updateMany({
        where: { customerId: existing.customerId },
        data: { isPrimary: false },
      });
    }

    return this.prisma.customerContact.update({ where: { id: contactId }, data: dto });
  }

  async deleteContact(contactId: string) {
    const existing = await this.prisma.customerContact.findUnique({ where: { id: contactId } });
    if (!existing) throw new NotFoundException('Contact not found');
    if (existing.isPrimary) throw new ConflictException('Cannot delete the primary contact. Assign another primary contact first.');
    return this.prisma.customerContact.delete({ where: { id: contactId } });
  }

  // ─── INTERACTIONS ──────────────────────────────────────────────────────────

  async recordInteraction(customerId: string, dto: any, recordedBy: string) {
    const customer = await this.prisma.customer.findUnique({ where: { id: customerId } });
    if (!customer) throw new NotFoundException('Customer not found');

    const interaction = await this.prisma.customerInteraction.create({
      data: {
        customerId,
        contactId: dto.contactId,
        interactionType: dto.interactionType || 'CALL',
        interactionDate: dto.interactionDate ? new Date(dto.interactionDate) : new Date(),
        subject: dto.subject,
        description: dto.description,
        outcome: dto.outcome,
        nextFollowUp: dto.nextFollowUp ? new Date(dto.nextFollowUp) : null,
        attachmentUrl: dto.attachmentUrl,
        audioUrl: dto.audioUrl,
        recordedBy,
      },
    });

    // Auto-increment activity count in valuation
    await this.prisma.customerValuation.updateMany({
      where: { customerId },
      data: { activityCount: { increment: 1 } },
    });

    return interaction;
  }

  async getInteractions(customerId: string, type?: string) {
    const where: any = { customerId };
    if (type) where.interactionType = type;
    return this.prisma.customerInteraction.findMany({
      where,
      include: { contact: true },
      orderBy: { interactionDate: 'desc' },
    });
  }
}
