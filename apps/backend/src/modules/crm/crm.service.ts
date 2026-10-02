import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Injectable()
export class CrmService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  // ─── DASHBOARD STATS ──────────────────────────────────────────────────────

  async getDashboardStats() {
    const [
      totalLeads,
      newLeads,
      qualifiedLeads,
      wonLeads,
      lostLeads,
      openEnquiries,
      pendingFollowUps,
    ] = await Promise.all([
      this.prisma.lead.count(),
      this.prisma.lead.count({ where: { status: 'NEW' } }),
      this.prisma.lead.count({ where: { status: 'QUALIFIED' } }),
      this.prisma.lead.count({ where: { status: 'WON' } }),
      this.prisma.lead.count({ where: { status: 'LOST' } }),
      this.prisma.enquiry.count({ where: { status: 'PENDING' } }),
      this.prisma.lead.count({
        where: {
          nextFollowUp: { lte: new Date() },
          status: { notIn: ['WON', 'LOST'] },
        },
      }),
    ]);

    return {
      totalLeads,
      newLeads,
      qualifiedLeads,
      wonLeads,
      lostLeads,
      openEnquiries,
      pendingFollowUps,
      conversionRate: totalLeads > 0 ? Math.round((wonLeads / totalLeads) * 100) : 0,
    };
  }

  // ─── LEADS ─────────────────────────────────────────────────────────────────

  async getLeads(query?: {
    status?: string;
    priority?: string;
    assignedTo?: string;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.priority) where.priority = query.priority;
    if (query?.assignedTo) where.assignedTo = { contains: query.assignedTo };
    if (query?.search) {
      where.OR = [
        { leadNumber: { contains: query.search } },
        { companyName: { contains: query.search } },
        { contactPerson: { contains: query.search } },
        { phone: { contains: query.search } },
        { productInterest: { contains: query.search } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.lead.findMany({
        where,
        skip,
        take: limit,
        include: { customer: { select: { companyName: true, customerCode: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.lead.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async getLead(id: string) {
    const lead = await this.prisma.lead.findUnique({
      where: { id },
      include: { customer: true },
    });
    if (!lead) throw new NotFoundException('Lead not found');
    return lead;
  }

  async createLead(dto: any, userId?: string, userEmail?: string) {
    const count = await this.prisma.lead.count();
    const year = new Date().getFullYear();
    const leadNumber = `LEAD-${year}-${String(count + 1).padStart(5, '0')}`;

    const lead = await this.prisma.lead.create({
      data: {
        leadNumber,
        companyName: dto.companyName,
        contactPerson: dto.contactPerson,
        phone: dto.phone,
        email: dto.email,
        source: dto.source || 'DIRECT',
        productInterest: dto.productInterest,
        requirement: dto.requirement,
        estimatedValue: Number(dto.estimatedValue || 0),
        assignedTo: dto.assignedTo,
        priority: dto.priority || 'MEDIUM',
        status: dto.status || 'NEW',
        customerId: dto.customerId,
        nextFollowUp: dto.nextFollowUp ? new Date(dto.nextFollowUp) : null,
        remarks: dto.remarks,
      },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'CREATE',
      module: 'CRM',
      entityType: 'Lead',
      entityId: lead.id,
      details: `Created Lead: ${lead.leadNumber} — ${lead.companyName}`,
    });

    return lead;
  }

  async updateLead(id: string, dto: any, userId?: string, userEmail?: string) {
    const existing = await this.prisma.lead.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Lead not found');

    const fields = [
      'companyName', 'contactPerson', 'phone', 'email', 'source',
      'productInterest', 'requirement', 'estimatedValue', 'assignedTo',
      'priority', 'status', 'customerId', 'remarks',
    ];
    const updateData: any = {};
    fields.forEach((f) => { if (dto[f] !== undefined) updateData[f] = dto[f]; });
    if (dto.nextFollowUp !== undefined) {
      updateData.nextFollowUp = dto.nextFollowUp ? new Date(dto.nextFollowUp) : null;
    }

    const lead = await this.prisma.lead.update({ where: { id }, data: updateData });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'UPDATE',
      module: 'CRM',
      entityType: 'Lead',
      entityId: id,
      details: `Updated Lead ${lead.leadNumber} — status: ${lead.status}`,
    });

    return lead;
  }

  async updateLeadStatus(id: string, status: string, userId?: string, userEmail?: string) {
    const lead = await this.prisma.lead.findUnique({ where: { id } });
    if (!lead) throw new NotFoundException('Lead not found');

    const updated = await this.prisma.lead.update({ where: { id }, data: { status } });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'UPDATE',
      module: 'CRM',
      entityType: 'Lead',
      entityId: id,
      details: `Lead ${lead.leadNumber} status changed: ${lead.status} → ${status}`,
    });

    return updated;
  }

  // ─── ENQUIRIES ─────────────────────────────────────────────────────────────

  async getEnquiries(query?: {
    customerId?: string;
    status?: string;
    priority?: string;
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.customerId) where.customerId = query.customerId;
    if (query?.status) where.status = query.status;
    if (query?.priority) where.priority = query.priority;
    if (query?.search) {
      where.OR = [
        { enquiryNumber: { contains: query.search } },
        { productInterest: { contains: query.search } },
        { requirement: { contains: query.search } },
        { customer: { companyName: { contains: query.search } } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.enquiry.findMany({
        where,
        skip,
        take: limit,
        include: {
          customer: { select: { companyName: true, customerCode: true, phone: true } },
        },
        orderBy: { enquiryDate: 'desc' },
      }),
      this.prisma.enquiry.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async getEnquiry(id: string) {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id },
      include: { customer: true },
    });
    if (!enquiry) throw new NotFoundException('Enquiry not found');
    return enquiry;
  }

  async createEnquiry(dto: any, userId?: string, userEmail?: string) {
    const count = await this.prisma.enquiry.count();
    const year = new Date().getFullYear();
    const enquiryNumber = `ENQ-${year}-${String(count + 1).padStart(5, '0')}`;

    const enquiry = await this.prisma.enquiry.create({
      data: {
        enquiryNumber,
        customerId: dto.customerId,
        productInterest: dto.productInterest,
        quantity: Number(dto.quantity || 1),
        requirement: dto.requirement,
        expectedValue: Number(dto.expectedValue || 0),
        assignedTo: dto.assignedTo,
        priority: dto.priority || 'MEDIUM',
        status: dto.status || 'PENDING',
        followUpDate: dto.followUpDate ? new Date(dto.followUpDate) : null,
        remarks: dto.remarks,
      },
      include: { customer: true },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'CREATE',
      module: 'CRM',
      entityType: 'Enquiry',
      entityId: enquiry.id,
      details: `Created Enquiry: ${enquiry.enquiryNumber}`,
    });

    return enquiry;
  }

  async updateEnquiry(id: string, dto: any, userId?: string, userEmail?: string) {
    const existing = await this.prisma.enquiry.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Enquiry not found');

    const fields = [
      'productInterest', 'quantity', 'requirement', 'expectedValue',
      'assignedTo', 'priority', 'status', 'remarks',
    ];
    const updateData: any = {};
    fields.forEach((f) => { if (dto[f] !== undefined) updateData[f] = dto[f]; });
    if (dto.followUpDate !== undefined) {
      updateData.followUpDate = dto.followUpDate ? new Date(dto.followUpDate) : null;
    }

    const enquiry = await this.prisma.enquiry.update({ where: { id }, data: updateData });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'UPDATE',
      module: 'CRM',
      entityType: 'Enquiry',
      entityId: id,
      details: `Updated Enquiry ${enquiry.enquiryNumber}`,
    });

    return enquiry;
  }

  // ─── PENDING FOLLOW-UPS ────────────────────────────────────────────────────

  async getPendingFollowUps() {
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);

    return this.prisma.lead.findMany({
      where: {
        nextFollowUp: { gte: now, lte: tomorrow },
        status: { notIn: ['WON', 'LOST'] },
      },
      include: { customer: { select: { companyName: true, phone: true } } },
      orderBy: { nextFollowUp: 'asc' },
    });
  }
}
