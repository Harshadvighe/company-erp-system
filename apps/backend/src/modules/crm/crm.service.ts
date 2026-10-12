import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';
import { GstVerificationService } from './gst-verification.service';

@Injectable()
export class CrmService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly gstVerificationService: GstVerificationService,
    private readonly sequenceService: SequenceService,
  ) {}

  // ─── SCOPING HELPER ───────────────────────────────────────────────────────
  private buildScopeFilter(user?: any, staffField = 'assignedStaffId') {
    if (!user) return {};
    const roles: string[] = user.roles || [];
    if (roles.includes('ROLE_ADMIN') || roles.includes('ADMIN')) {
      return {};
    }

    if (roles.includes('ROLE_SALES_EXEC') && user.staffId) {
      return { [staffField]: user.staffId };
    }
    // Sales manager or other roles see team/all
    return {};
  }

  private async nextCustomerFollowUpNumber(
    tx: Prisma.TransactionClient,
    customerId: string,
  ) {
    const existing = await tx.crmFollowUp.findMany({
      where: { customerId },
      select: { id: true, followUpNumber: true },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });

    if (existing.some((followUp) => followUp.followUpNumber == null)) {
      for (const [index, followUp] of existing.entries()) {
        const number = index + 1;
        if (followUp.followUpNumber !== number) {
          await tx.crmFollowUp.update({
            where: { id: followUp.id },
            data: { followUpNumber: number },
          });
        }
      }
      return existing.length + 1;
    }

    return Math.max(
      existing.length,
      ...existing.map((followUp) => followUp.followUpNumber || 0),
    ) + 1;
  }

  private includeComputedFollowUpNumbers(followUps: any[]) {
    const byCustomer = new Map<string, any[]>();
    for (const followUp of followUps) {
      if (!followUp.customerId) continue;
      const customerFollowUps = byCustomer.get(followUp.customerId) || [];
      customerFollowUps.push(followUp);
      byCustomer.set(followUp.customerId, customerFollowUps);
    }

    const numberById = new Map<string, number>();
    for (const customerFollowUps of byCustomer.values()) {
      customerFollowUps.sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
      );
      customerFollowUps.forEach((followUp, index) => {
        numberById.set(followUp.id, followUp.followUpNumber || index + 1);
      });
    }

    return followUps.map((followUp) => ({
      ...followUp,
      followUpNumber: numberById.get(followUp.id) ?? followUp.followUpNumber,
    }));
  }

  // ─── DASHBOARD STATS ──────────────────────────────────────────────────────
  async getDashboardStats(user?: any) {
    const scope = this.buildScopeFilter(user);

    const [
      totalLeads,
      newLeads,
      qualifiedLeads,
      wonLeads,
      lostLeads,
      openEnquiries,
      opportunities,
      pendingFollowUps,
      overdueFollowUps,
      meetingsToday,
      totalCustomers,
      activeCustomers,
      recentMeetings,
      recentFollowUps,
    ] = await Promise.all([
      this.prisma.lead.count({ where: scope }),
      this.prisma.lead.count({ where: { ...scope, status: 'NEW' } }),
      this.prisma.lead.count({ where: { ...scope, status: 'QUALIFIED' } }),
      this.prisma.lead.count({ where: { ...scope, status: 'WON' } }),
      this.prisma.lead.count({ where: { ...scope, status: 'LOST' } }),
      this.prisma.enquiry.count({ where: { status: 'PENDING' } }),
      this.prisma.opportunity.findMany({
        where: scope,
        select: { stage: true, estimatedValue: true, weightedValue: true },
      }),
      this.prisma.crmFollowUp.count({
        where: {
          ...this.buildScopeFilter(user, 'assignedStaffId'),
          status: 'PENDING',
          scheduledDate: { gte: new Date(new Date().setHours(0, 0, 0, 0)) },
        },
      }),
      this.prisma.crmFollowUp.count({
        where: {
          ...this.buildScopeFilter(user, 'assignedStaffId'),
          status: 'PENDING',
          scheduledDate: { lt: new Date() },
        },
      }),
      this.prisma.crmMeeting.count({
        where: {
          startTime: {
            gte: new Date(new Date().setHours(0, 0, 0, 0)),
            lte: new Date(new Date().setHours(23, 59, 59, 999)),
          },
        },
      }),
      this.prisma.customer.count(),
      this.prisma.customer.count({ where: { status: 'ACTIVE' } }),
      this.prisma.crmMeeting.findMany({
        take: 8,
        orderBy: { startTime: 'desc' },
        include: {
          activity: {
            include: {
              customer: { select: { id: true, companyName: true } },
              lead: { select: { id: true, companyName: true } },
            },
          },
        },
      }),
      this.prisma.crmFollowUp.findMany({
        where: {
          ...this.buildScopeFilter(user, 'assignedStaffId'),
          status: 'PENDING',
        },
        take: 8,
        orderBy: { scheduledDate: 'asc' },
        include: {
          customer: { select: { id: true, companyName: true, phone: true } },
          opportunity: { select: { id: true, title: true } },
          assignedStaff: { select: { fullName: true } },
        },
      }),
    ]);

    const pipelineValue = opportunities
      .filter((o) => !['CLOSED_WON', 'CLOSED_LOST'].includes(o.stage))
      .reduce((sum, o) => sum + (o.estimatedValue || 0), 0);

    const weightedPipelineValue = opportunities
      .filter((o) => !['CLOSED_WON', 'CLOSED_LOST'].includes(o.stage))
      .reduce((sum, o) => sum + (o.weightedValue || 0), 0);

    const wonValue = opportunities
      .filter((o) => o.stage === 'CLOSED_WON')
      .reduce((sum, o) => sum + (o.estimatedValue || 0), 0);

    const lostValue = opportunities
      .filter((o) => o.stage === 'CLOSED_LOST')
      .reduce((sum, o) => sum + (o.estimatedValue || 0), 0);

    return {
      totalLeads,
      newLeads,
      qualifiedLeads,
      wonLeads,
      lostLeads,
      openEnquiries,
      openOpportunities: opportunities.filter((o) => !['CLOSED_WON', 'CLOSED_LOST'].includes(o.stage)).length,
      pipelineValue,
      weightedPipelineValue,
      wonValue,
      lostValue,
      conversionRate: totalLeads > 0 ? Math.round((wonLeads / totalLeads) * 100) : 0,
      followUpsToday: pendingFollowUps,
      overdueFollowUps,
      meetingsToday,
      totalCustomers,
      totalCompanies: totalCustomers,
      activeCustomers,
      recentMeetings,
      meetings: recentMeetings,
      recentFollowUps,
    };
  }

  // ─── GLOBAL SEARCH ────────────────────────────────────────────────────────
  async globalSearch(query: string, user?: any) {
    if (!query || typeof query !== 'string' || !query.trim()) {
      return { companies: [], leads: [], enquiries: [], opportunities: [], quotations: [] };
    }
    const q = query.trim();
    const scope = this.buildScopeFilter(user);

    const [companies, leads, enquiries, opportunities, quotations] = await Promise.all([
      this.prisma.customer.findMany({
        where: {
          OR: [
            { companyName: { contains: q } },
            { legalName: { contains: q } },
            { tradeName: { contains: q } },
            { gstin: { contains: q } },
            { pan: { contains: q } },
            { phone: { contains: q } },
            { email: { contains: q } },
            { contactPerson: { contains: q } },
            { city: { contains: q } },
          ],
        },
        take: 8,
        select: {
          id: true,
          companyName: true,
          customerCode: true,
          gstin: true,
          city: true,
          state: true,
          phone: true,
          contactPerson: true,
          customerType: true,
          status: true,
        },
      }),
      this.prisma.lead.findMany({
        where: {
          ...scope,
          OR: [
            { companyName: { contains: q } },
            { contactPerson: { contains: q } },
            { phone: { contains: q } },
            { email: { contains: q } },
          ],
        },
        take: 5,
        select: {
          id: true,
          leadNumber: true,
          companyName: true,
          contactPerson: true,
          phone: true,
          status: true,
          source: true,
        },
      }),
      this.prisma.enquiry.findMany({
        where: {
          OR: [
            { enquiryNumber: { contains: q } },
            { requirement: { contains: q } },
            { customer: { companyName: { contains: q } } },
          ],
        },
        take: 5,
        select: {
          id: true,
          enquiryNumber: true,
          requirement: true,
          status: true,
          customerId: true,
          customer: { select: { companyName: true } },
        },
      }),
      this.prisma.opportunity.findMany({
        where: {
          ...scope,
          OR: [
            { title: { contains: q } },
            { customer: { companyName: { contains: q } } },
          ],
        },
        take: 5,
        select: {
          id: true,
          title: true,
          stage: true,
          estimatedValue: true,
          customerId: true,
          customer: { select: { companyName: true } },
        },
      }),
      this.prisma.quotation.findMany({
        where: {
          OR: [
            { quotationNumber: { contains: q } },
            { subject: { contains: q } },
            { customer: { companyName: { contains: q } } },
          ],
        },
        take: 5,
        select: {
          id: true,
          quotationNumber: true,
          subject: true,
          status: true,
          grandTotal: true,
          customerId: true,
          customer: { select: { companyName: true } },
        },
      }),
    ]);

    return { companies, leads, enquiries, opportunities, quotations };
  }

  // ─── LEADS ────────────────────────────────────────────────────────────────
  async getLeads(query?: any, user?: any) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const scope = this.buildScopeFilter(user);
    const where: any = { ...scope };

    if (query?.status === 'OVERDUE' || query?.due === 'overdue') {
      where.status = 'PENDING';
      where.scheduledDate = { lt: new Date() };
    } else if (query?.status && query.status !== 'ALL') {
      where.status = query.status;
    }
    if (query?.priority) where.priority = query.priority;
    if (query?.source) where.source = query.source;
    if (query?.assignedStaffId) where.assignedStaffId = query.assignedStaffId;
    if (query?.search) {
      where.OR = [
        { leadNumber: { contains: query.search } },
        { companyName: { contains: query.search } },
        { contactPerson: { contains: query.search } },
        { phone: { contains: query.search } },
        { email: { contains: query.search } },
        { productInterest: { contains: query.search } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.lead.findMany({
        where,
        skip,
        take: limit,
        include: {
          customer: { select: { id: true, companyName: true, customerCode: true } },
          assignedStaff: { select: { id: true, fullName: true, employeeId: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.lead.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async getLead(id: string) {
    const lead = await this.prisma.lead.findUnique({
      where: { id },
      include: {
        customer: true,
        assignedStaff: true,
        opportunities: true,
        activities: { include: { staff: true, call: true, meeting: true, siteVisit: true } },
      },
    });
    if (!lead) throw new NotFoundException('Lead not found');
    return lead;
  }

  async createLead(dto: any, user?: any) {
    const leadNumber = await this.sequenceService.nextLeadNumber();

    const lead = await this.prisma.lead.create({
      data: {
        leadNumber,
        companyName: dto.companyName,
        contactPerson: dto.contactPerson,
        phone: dto.phone,
        email: dto.email,
        source: dto.source || 'DIRECT',
        leadType: dto.leadType || 'END_CUSTOMER',
        productInterest: dto.productInterest,
        requirement: dto.requirement,
        estimatedValue: Number(dto.estimatedValue || 0),
        assignedStaffId: dto.assignedStaffId || user?.staffId,
        salesManagerStaffId: dto.salesManagerStaffId,
        priority: dto.priority || 'MEDIUM',
        status: 'NEW',
        customerId: dto.customerId,
        nextFollowUp: dto.nextFollowUp ? new Date(dto.nextFollowUp) : null,
        expectedClosureDate: dto.expectedClosureDate ? new Date(dto.expectedClosureDate) : null,
        remarks: dto.remarks,
      },
      include: { assignedStaff: true },
    });

    await this.auditService.log({
      userId: user?.id,
      userEmail: user?.email,
      action: 'CREATE',
      module: 'CRM',
      entityType: 'Lead',
      entityId: lead.id,
      details: `Created Lead: ${lead.leadNumber} — ${lead.companyName}`,
    });

    return lead;
  }

  async updateLead(id: string, dto: any, user?: any) {
    const existing = await this.prisma.lead.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Lead not found');

    const updateData: any = {};
    const fields = [
      'companyName', 'contactPerson', 'phone', 'email', 'source', 'leadType',
      'productInterest', 'requirement', 'estimatedValue', 'assignedStaffId',
      'salesManagerStaffId', 'priority', 'status', 'customerId', 'remarks',
    ];
    fields.forEach((f) => { if (dto[f] !== undefined) updateData[f] = dto[f]; });

    if (dto.nextFollowUp !== undefined) {
      updateData.nextFollowUp = dto.nextFollowUp ? new Date(dto.nextFollowUp) : null;
    }
    if (dto.expectedClosureDate !== undefined) {
      updateData.expectedClosureDate = dto.expectedClosureDate ? new Date(dto.expectedClosureDate) : null;
    }

    const lead = await this.prisma.lead.update({ where: { id }, data: updateData });

    await this.auditService.log({
      userId: user?.id,
      userEmail: user?.email,
      action: 'UPDATE',
      module: 'CRM',
      entityType: 'Lead',
      entityId: id,
      details: `Updated Lead: ${lead.leadNumber}`,
    });

    return lead;
  }

  async qualifyLead(id: string, dto: any, user?: any) {
    const lead = await this.prisma.lead.findUnique({ where: { id } });
    if (!lead) throw new NotFoundException('Lead not found');

    const isQualified = dto.isQualified === true;
    const updated = await this.prisma.lead.update({
      where: { id },
      data: {
        qualificationStatus: isQualified ? 'QUALIFIED' : 'DISQUALIFIED',
        status: isQualified ? 'QUALIFIED' : 'DISQUALIFIED',
        bantBudget: dto.bantBudget ? Number(dto.bantBudget) : null,
        bantAuthority: dto.bantAuthority,
        bantNeed: dto.bantNeed,
        bantTimeline: dto.bantTimeline,
        disqualificationReason: !isQualified ? dto.disqualificationReason : null,
      },
    });

    await this.auditService.log({
      userId: user?.id,
      userEmail: user?.email,
      action: 'QUALIFY',
      module: 'CRM',
      entityType: 'Lead',
      entityId: id,
      details: `Lead ${lead.leadNumber} qualified: ${isQualified}`,
    });

    return updated;
  }

  // ─── ATOMIC LEAD CONVERSION ───────────────────────────────────────────────
  async convertLead(id: string, dto: any, user?: any) {
    const lead = await this.prisma.lead.findUnique({ where: { id } });
    if (!lead) throw new NotFoundException('Lead not found');

    return this.prisma.$transaction(async (tx) => {
      let customerId = lead.customerId;
      let customer: any = null;

      if (!customerId) {
        const customerCode = await this.sequenceService.nextCustomerCode();

        customer = await tx.customer.create({
          data: {
            customerCode,
            companyName: lead.companyName,
            contactPerson: lead.contactPerson,
            email: lead.email || `${lead.leadNumber.toLowerCase()}@placeholder.in`,
            phone: lead.phone,
            address: dto.address || 'Address pending site verification',
            country: 'India',
            state: dto.state || 'Maharashtra',
            district: dto.district || 'Pune',
            city: dto.city || 'Pune',
            pincode: dto.pincode || '411001',
            customerType: dto.customerType || 'PROSPECT',
            customerSegment: dto.customerSegment || 'VFD_PANEL',
            assignedStaffId: lead.assignedStaffId || user?.staffId,
            source: lead.source,
          },
        });
        customerId = customer.id;

        // Create primary contact
        await tx.customerContact.create({
          data: {
            customerId,
            name: lead.contactPerson,
            mobile: lead.phone,
            email: lead.email,
            isPrimary: true,
          },
        });

        // Create valuation profile
        await tx.customerValuation.create({
          data: {
            customerId,
            ratingScore: 5.0,
            valuablePercentage: 60.0,
            activityCount: 1,
          },
        });
      }

      // Create Opportunity if requested
      let opportunity: any = null;
      if (dto.createOpportunity !== false) {
        const opportunityNumber = await this.sequenceService.nextOpportunityNumber();

        opportunity = await tx.opportunity.create({
          data: {
            opportunityNumber,
            title: dto.opportunityTitle || `${lead.companyName} — ${lead.productInterest || 'Requirement'}`,
            customerId,
            leadId: lead.id,
            assignedStaffId: lead.assignedStaffId || user?.staffId || 'unassigned',
            stage: 'QUALIFICATION',
            probability: 10,
            estimatedValue: lead.estimatedValue || 0,
            weightedValue: (lead.estimatedValue || 0) * 0.1,
            expectedCloseDate: lead.expectedClosureDate,
          },
        });
      }

      // Update lead status
      await tx.lead.update({
        where: { id: lead.id },
        data: {
          status: 'OPPORTUNITY',
          customerId,
        },
      });

      return { customerId, opportunityId: opportunity?.id, leadNumber: lead.leadNumber };
    });
  }

  // ─── OPPORTUNITIES & PIPELINE ─────────────────────────────────────────────
  async getOpportunities(query?: any, user?: any) {
    const scope = this.buildScopeFilter(user);
    const where: any = { ...scope };

    if (query?.stage && query.stage !== 'ALL') where.stage = query.stage;
    if (query?.assignedStaffId) where.assignedStaffId = query.assignedStaffId;
    if (query?.search) {
      where.OR = [
        { opportunityNumber: { contains: query.search } },
        { title: { contains: query.search } },
        { customer: { companyName: { contains: query.search } } },
      ];
    }

    return this.prisma.opportunity.findMany({
      where,
      include: {
        customer: { select: { id: true, companyName: true, customerCode: true } },
        assignedStaff: { select: { id: true, fullName: true, employeeId: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getPipeline(user?: any) {
    const scope = this.buildScopeFilter(user);
    const opps = await this.prisma.opportunity.findMany({
      where: scope,
      include: {
        customer: { select: { id: true, companyName: true, customerCode: true } },
        assignedStaff: { select: { id: true, fullName: true, employeeId: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const stages = [
      'QUALIFICATION',
      'REQUIREMENT',
      'TECHNICAL_EVALUATION',
      'QUOTATION_SENT',
      'NEGOTIATION',
      'CLOSED_WON',
      'CLOSED_LOST',
    ];

    const pipeline: Record<string, { count: number; totalValue: number; items: any[] }> = {};
    stages.forEach((s) => {
      pipeline[s] = { count: 0, totalValue: 0, items: [] };
    });

    opps.forEach((opp) => {
      const stage = opp.stage || 'QUALIFICATION';
      if (!pipeline[stage]) {
        pipeline[stage] = { count: 0, totalValue: 0, items: [] };
      }
      pipeline[stage].items.push(opp);
      pipeline[stage].count++;
      pipeline[stage].totalValue += opp.estimatedValue || 0;
    });

    const columns = stages.map((s) => ({
      stage: s,
      count: pipeline[s]?.count || 0,
      totalValue: pipeline[s]?.totalValue || 0,
      items: pipeline[s]?.items || [],
    }));

    const totalPipelineValue = opps
      .filter((o) => !['CLOSED_WON', 'CLOSED_LOST'].includes(o.stage))
      .reduce((sum, o) => sum + (o.estimatedValue || 0), 0);

    const weightedPipelineValue = opps
      .filter((o) => !['CLOSED_WON', 'CLOSED_LOST'].includes(o.stage))
      .reduce((sum, o) => sum + (o.weightedValue || 0), 0);

    const wonValue = opps
      .filter((o) => o.stage === 'CLOSED_WON')
      .reduce((sum, o) => sum + (o.estimatedValue || 0), 0);

    return {
      ...pipeline,
      columns,
      summary: {
        totalCount: opps.length,
        totalPipelineValue,
        weightedPipelineValue,
        wonValue,
      },
    };
  }

  async createOpportunity(dto: any, user?: any) {
    const opportunityNumber = await this.sequenceService.nextOpportunityNumber();
    const probability = Number(dto.probability || 10);
    const estimatedValue = Number(dto.estimatedValue || 0);

    return this.prisma.opportunity.create({
      data: {
        opportunityNumber,
        title: dto.title,
        customerId: dto.customerId,
        contactId: dto.contactId,
        leadId: dto.leadId,
        enquiryId: dto.enquiryId,
        assignedStaffId: dto.assignedStaffId || user?.staffId,
        salesManagerStaffId: dto.salesManagerStaffId,
        stage: dto.stage || 'QUALIFICATION',
        probability,
        estimatedValue,
        weightedValue: (estimatedValue * probability) / 100,
        expectedCloseDate: dto.expectedCloseDate ? new Date(dto.expectedCloseDate) : null,
        priority: dto.priority || 'MEDIUM',
      },
      include: { customer: true, assignedStaff: true },
    });
  }

  async updateOpportunityStage(id: string, stage: string, probability?: number, user?: any) {
    const opp = await this.prisma.opportunity.findUnique({ where: { id } });
    if (!opp) throw new NotFoundException('Opportunity not found');

    const stageProbabilities: Record<string, number> = {
      QUALIFICATION: 10,
      REQUIREMENT: 25,
      TECHNICAL_EVALUATION: 40,
      QUOTATION_SENT: 60,
      NEGOTIATION: 80,
      CLOSED_WON: 100,
      CLOSED_LOST: 0,
    };

    const newProb = probability !== undefined ? probability : (stageProbabilities[stage] ?? opp.probability);
    const weightedValue = (opp.estimatedValue * newProb) / 100;

    const updated = await this.prisma.opportunity.update({
      where: { id },
      data: { stage, probability: newProb, weightedValue },
    });

    await this.auditService.log({
      userId: user?.id,
      userEmail: user?.email,
      action: 'STAGE_CHANGE',
      module: 'CRM',
      entityType: 'Opportunity',
      entityId: id,
      details: `Opportunity ${opp.opportunityNumber} stage changed: ${opp.stage} → ${stage}`,
    });

    return updated;
  }

  async markOpportunityLost(id: string, lostReason: string, lostRemarks?: string, competitor?: string, user?: any) {
    if (!lostReason) throw new BadRequestException('Lost reason is mandatory');

    const opp = await this.prisma.opportunity.findUnique({ where: { id } });
    if (!opp) throw new NotFoundException('Opportunity not found');

    return this.prisma.opportunity.update({
      where: { id },
      data: {
        stage: 'CLOSED_LOST',
        probability: 0,
        weightedValue: 0,
        lostReason,
        lostRemarks,
        competitor,
      },
    });
  }

  // ─── ACTIVITIES: CALLS, MEETINGS & SITE VISITS ────────────────────────────
  async logCall(dto: any, user?: any) {
    const staffId = user?.staffId || dto.staffId;
    if (!staffId) throw new BadRequestException('Valid staff identification required');

    return this.prisma.$transaction(async (tx) => {
      const activity = await tx.crmActivity.create({
        data: {
          activityType: 'CALL',
          customerId: dto.customerId,
          contactId: dto.contactId,
          leadId: dto.leadId,
          opportunityId: dto.opportunityId,
          staffId,
          subject: dto.subject || 'Phone Call',
          description: dto.description,
          outcome: dto.callOutcome || 'CONNECTED',
          nextActionDate: dto.nextFollowUpDate ? new Date(dto.nextFollowUpDate) : null,
        },
      });

      const call = await tx.crmCall.create({
        data: {
          activityId: activity.id,
          contactId: dto.contactId,
          callType: dto.callType || 'OUTBOUND',
          durationSec: Number(dto.durationSec || 0),
          callOutcome: dto.callOutcome || 'CONNECTED',
          recordingUrl: dto.recordingUrl,
          dataSent: Boolean(dto.dataSent),
          dataTypes: Array.isArray(dto.dataTypes) ? JSON.stringify(dto.dataTypes) : dto.dataTypes || null,
        },
      });

      if (dto.recordingUrl) {
        await tx.callRecording.create({
          data: {
            callId: call.id,
            fileName: dto.recordingFileName || `call_rec_${Date.now()}.webm`,
            fileUrl: dto.recordingUrl,
            durationSec: Number(dto.durationSec || 0),
            fileSizeBytes: Number(dto.recordingSizeBytes || 0),
            mimeType: dto.recordingMimeType || 'audio/webm',
            uploadedBy: user?.fullName || user?.email || 'User',
          },
        });
      }

      // Schedule follow-up if date specified
      if (dto.nextFollowUpDate) {
        await tx.crmFollowUp.create({
          data: {
            title: `Follow-up: ${dto.subject || 'Phone Call'}`,
            customerId: dto.customerId,
            opportunityId: dto.opportunityId,
            leadId: dto.leadId,
            assignedStaffId: staffId,
            scheduledDate: new Date(dto.nextFollowUpDate),
            status: 'PENDING',
          },
        });
      }

      return activity;
    });
  }

  async scheduleMeeting(dto: any, user?: any) {
    // Support both user JWT staffId and explicit assignedStaffId from the DTO
    const staffId = user?.staffId || dto.assignedStaffId || dto.staffId;
    if (!staffId) throw new BadRequestException('Valid staff identification required');

    // Map flexible frontend field names
    const meetingStartTime = dto.meetingDate || dto.startTime || dto.scheduledDate;
    if (!meetingStartTime) throw new BadRequestException('meetingDate is required');

    const subject = dto.purpose || dto.agenda || dto.subject || 'Client Meeting';
    const notes = dto.notes || dto.description;
    const priority = dto.priority || 'MEDIUM';
    const hostStaffId = dto.hostStaffId || staffId;
    const meetingStatus = dto.meetingStatus || (hostStaffId !== staffId ? 'REQUESTED' : 'SCHEDULED');

    return this.prisma.$transaction(async (tx) => {
      const activity = await tx.crmActivity.create({
        data: {
          activityType: 'MEETING',
          customerId: dto.customerId,
          contactId: dto.contactId,
          leadId: dto.leadId,
          opportunityId: dto.opportunityId,
          staffId,
          subject,
          description: notes,
          outcome: dto.outcome,
          nextActionDate: dto.nextFollowUpDate ? new Date(dto.nextFollowUpDate) : null,
        },
      });

      const meeting = await tx.crmMeeting.create({
        data: {
          activityId: activity.id,
          meetingType: dto.meetingType || 'OFFLINE',
          location: dto.location,
          startTime: new Date(meetingStartTime),
          endTime: dto.endTime ? new Date(dto.endTime) : null,
          agenda: subject,
          outcome: dto.outcome,
          hostStaffId,
          requestedByStaffId: staffId,
          meetingStatus,
        },
      });

      // Auto-create a CrmFollowUp so the meeting appears in the follow-up queue
      await tx.crmFollowUp.create({
        data: {
          title: `Meeting: ${subject}`,
          customerId: dto.customerId || null,
          opportunityId: dto.opportunityId || null,
          leadId: dto.leadId || null,
          assignedStaffId: hostStaffId || staffId,
          scheduledDate: new Date(meetingStartTime),
          status: 'PENDING',
          priority,
          notes: [
            dto.location ? `Location: ${dto.location}` : '',
            dto.customerName ? `Customer: ${dto.customerName}` : '',
            notes || '',
          ].filter(Boolean).join(' | '),
        },
      });

      return { ...activity, meeting };
    });
  }

  async createFollowUp(dto: any, user?: any) {
    const staffId = dto.assignedStaffId || user?.staffId;
    if (!staffId) throw new BadRequestException('assignedStaffId is required');

    const mode = dto.mode || (dto.scheduledDate || dto.followUpDate ? 'SCHEDULE' : 'COMPLETE_NOW');
    if (!['COMPLETE_NOW', 'SCHEDULE'].includes(mode)) {
      throw new BadRequestException('mode must be COMPLETE_NOW or SCHEDULE');
    }
    if (!dto.customerId) throw new BadRequestException('customerId is required');
    if (mode === 'SCHEDULE' && !(dto.scheduledDate || dto.followUpDate)) {
      throw new BadRequestException('scheduledDate is required when scheduling a follow-up');
    }
    if (mode === 'COMPLETE_NOW' && !dto.discussion?.trim()) {
      throw new BadRequestException('discussion is required for a completed interaction');
    }
    const activityTypes = ['CALL', 'EMAIL', 'WHATSAPP', 'MEETING', 'SITE_VISIT', 'DEMO', 'OTHER'];
    if (dto.activityType && !activityTypes.includes(dto.activityType)) {
      throw new BadRequestException('activityType is invalid');
    }
    const priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
    if (dto.priority && !priorities.includes(dto.priority)) {
      throw new BadRequestException('priority is invalid');
    }
    if (dto.reminderMinutes != null && (!Number.isInteger(dto.reminderMinutes) || dto.reminderMinutes < 0)) {
      throw new BadRequestException('reminderMinutes must be a non-negative integer');
    }

    const scheduledDateValue = dto.scheduledDate || dto.followUpDate;
    const scheduledDate = scheduledDateValue ? new Date(scheduledDateValue) : null;
    if (scheduledDate && Number.isNaN(scheduledDate.getTime())) {
      throw new BadRequestException('scheduledDate must be a valid date');
    }
    if (mode === 'SCHEDULE' && scheduledDate && scheduledDate <= new Date()) {
      throw new BadRequestException('scheduledDate must be in the future');
    }
    const interactionDate = mode === 'COMPLETE_NOW' ? new Date() : null;
    const status = mode === 'COMPLETE_NOW' ? 'COMPLETED' : 'PENDING';
    const title = dto.subject?.trim() || dto.title?.trim() || dto.activityType || 'Follow-up';

    return this.prisma.$transaction(async (tx) => {
      const customer = await tx.customer.findUnique({
        where: { id: dto.customerId },
        select: { id: true },
      });
      if (!customer) throw new NotFoundException('Company not found');

      const followUpNumber = await this.nextCustomerFollowUpNumber(tx, customer.id);

      return tx.crmFollowUp.create({
        data: {
          title,
          subject: dto.subject?.trim() || null,
          activityType: dto.activityType || 'CALL',
          discussion: dto.discussion?.trim() || null,
          outcome: dto.outcome?.trim() || null,
          nextAction: dto.nextAction?.trim() || null,
          interactionDate,
          followUpNumber,
          customerId: customer.id,
          opportunityId: dto.opportunityId || null,
          leadId: dto.leadId || null,
          assignedStaffId: staffId,
          scheduledDate,
          reminderMinutes: mode === 'SCHEDULE' ? (dto.reminderMinutes ?? null) : null,
          status,
          priority: dto.priority || 'MEDIUM',
          notes: dto.notes?.trim() || null,
          completedDate: status === 'COMPLETED' ? interactionDate : null,
        },
        include: {
          customer: { select: { id: true, companyName: true, phone: true } },
          assignedStaff: { select: { id: true, fullName: true } },
        },
      });
    });
  }

  async logSiteVisit(dto: any, user?: any) {
    const staffId = user?.staffId || dto.staffId;
    if (!staffId) throw new BadRequestException('Valid staff identification required');

    return this.prisma.$transaction(async (tx) => {
      const activity = await tx.crmActivity.create({
        data: {
          activityType: 'SITE_VISIT',
          customerId: dto.customerId,
          contactId: dto.contactId,
          leadId: dto.leadId,
          opportunityId: dto.opportunityId,
          staffId,
          subject: `Site Visit: ${dto.location}`,
          description: dto.inspectionNotes,
          outcome: dto.outcome,
          nextActionDate: dto.nextFollowUpDate ? new Date(dto.nextFollowUpDate) : null,
        },
      });

      await tx.crmSiteVisit.create({
        data: {
          activityId: activity.id,
          location: dto.location,
          siteCondition: dto.siteCondition,
          voltageReading: dto.voltageReading,
          pumpRatingHp: dto.pumpRatingHp ? Number(dto.pumpRatingHp) : null,
          panelDimensions: dto.panelDimensions,
          inspectionNotes: dto.inspectionNotes,
          photoUrls: dto.photoUrls ? JSON.stringify(dto.photoUrls) : null,
        },
      });

      return activity;
    });
  }

  // ─── FOLLOW-UPS ───────────────────────────────────────────────────────────
  async getFollowUps(query?: any, user?: any) {
    const scope = this.buildScopeFilter(user, 'assignedStaffId');
    const where: any = { ...scope };

    if (query?.customerId) where.customerId = query.customerId;
    if (query?.status && query.status !== 'ALL') where.status = query.status;

    if (query?.due === 'today') {
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date();
      endOfDay.setHours(23, 59, 59, 999);
      where.scheduledDate = { gte: startOfDay, lte: endOfDay };
    }

    const followUps = await this.prisma.crmFollowUp.findMany({
      where,
      include: {
        customer: { select: { id: true, companyName: true, phone: true, city: true, gstin: true, email: true, contactPerson: true } },
        opportunity: { select: { id: true, title: true, stage: true } },
        assignedStaff: { select: { id: true, fullName: true, employeeId: true } },
      },
      orderBy: [{ scheduledDate: 'asc' }, { interactionDate: 'desc' }, { createdAt: 'desc' }],
    });

    const now = new Date();
    return this.includeComputedFollowUpNumbers(followUps).map((f) => {
      const isOverdue = f.status === 'PENDING' && !!f.scheduledDate && f.scheduledDate < now;
      return { ...f, isOverdue, displayStatus: isOverdue ? 'OVERDUE' : f.status };
    });
  }

  async getFollowUpCompanies(query?: any, user?: any) {
    const now = new Date();
    const dueTodayStart = new Date(now);
    dueTodayStart.setHours(0, 0, 0, 0);
    const dueTodayEnd = new Date(now);
    dueTodayEnd.setHours(23, 59, 59, 999);
    const staffScope = this.buildScopeFilter(user, 'assignedStaffId');
    const followUpFilter: any = {
      AND: [
        staffScope,
        ...(query?.assignedStaffId ? [{ assignedStaffId: query.assignedStaffId }] : []),
      ],
    };
    const companyWhere: any = { status: { not: 'DELETED' } };
    if (query?.customerId) companyWhere.id = query.customerId;
    const search = query?.search?.trim();

    if (search) {
      companyWhere.OR = [
        { companyName: { contains: search } },
        { gstin: { contains: search } },
        { phone: { contains: search } },
        { alternatePhone: { contains: search } },
        { email: { contains: search } },
        { contactPerson: { contains: search } },
        { ownerName: { contains: search } },
        { contacts: { some: { name: { contains: search } } } },
        { followUps: { some: { ...staffScope, assignedStaff: { fullName: { contains: search } } } } },
      ];
    }
    if (query?.status === 'OVERDUE') {
      companyWhere.followUps = { some: { ...followUpFilter, status: 'PENDING', scheduledDate: { lt: now } } };
    } else if (query?.status === 'TODAY') {
      companyWhere.followUps = { some: { ...followUpFilter, status: 'PENDING', scheduledDate: { gte: dueTodayStart, lte: dueTodayEnd } } };
    } else if (query?.status === 'PENDING') {
      companyWhere.followUps = { some: { ...followUpFilter, status: 'PENDING', scheduledDate: { gte: now } } };
    } else if (query?.status === 'COMPLETED') {
      companyWhere.followUps = { some: { ...followUpFilter, status: 'COMPLETED' } };
    }

    const page = Math.max(Number.parseInt(query?.page, 10) || 1, 1);
    const limit = Math.min(Math.max(Number.parseInt(query?.limit, 10) || 50, 1), 100);
    const [companies, total] = await Promise.all([
      this.prisma.customer.findMany({
        where: companyWhere,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { companyName: 'asc' },
        include: {
          assignedStaff: { select: { id: true, fullName: true } },
          followUps: {
            where: followUpFilter,
            include: { assignedStaff: { select: { id: true, fullName: true } } },
            orderBy: [{ followUpNumber: 'desc' }, { createdAt: 'desc' }],
          },
        },
      }),
      this.prisma.customer.count({ where: companyWhere }),
    ]);

    const data = companies.map((company) => {
      const followUps = this.includeComputedFollowUpNumbers(company.followUps).map((followUp) => {
        const isOverdue = followUp.status === 'PENDING' && !!followUp.scheduledDate && followUp.scheduledDate < now;
        return { ...followUp, isOverdue, displayStatus: isOverdue ? 'OVERDUE' : followUp.status };
      });
      const lastInteraction = followUps
        .filter((followUp) => followUp.interactionDate || followUp.completedDate)
        .sort((a, b) => new Date(b.interactionDate || b.completedDate!).getTime() - new Date(a.interactionDate || a.completedDate!).getTime())[0];
      const nextFollowUp = followUps
        .filter((followUp) => followUp.status === 'PENDING' && followUp.scheduledDate)
        .sort((a, b) => a.scheduledDate!.getTime() - b.scheduledDate!.getTime())[0];
      const latestFollowUp = followUps[0];
      return {
        ...company,
        followUps,
        followUpCount: followUps.length,
        completedCount: followUps.filter((followUp) => followUp.status === 'COMPLETED').length,
        pendingCount: followUps.filter((followUp) => followUp.status === 'PENDING').length,
        overdueCount: followUps.filter((followUp) => followUp.isOverdue).length,
        lastInteraction: lastInteraction?.interactionDate || lastInteraction?.completedDate || null,
        nextFollowUp: nextFollowUp?.scheduledDate || null,
        displayStatus: nextFollowUp
          ? (nextFollowUp.scheduledDate! < now ? 'OVERDUE' : 'PENDING')
          : latestFollowUp?.displayStatus || 'NO_FOLLOW_UP',
      };
    });
    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async completeFollowUp(id: string, dto: any, user?: any) {
    const followUp = await this.prisma.crmFollowUp.findUnique({ where: { id } });
    if (!followUp) throw new NotFoundException('Follow-up not found');
    if (followUp.status === 'COMPLETED') throw new BadRequestException('Follow-up is already completed');
    if (!dto?.discussion?.trim() && !dto?.notes?.trim()) {
      throw new BadRequestException('Discussion is required to complete a follow-up');
    }
    const scheduleNext = dto?.scheduleNext === true;
    const nextScheduledDate = dto?.nextScheduledDate ? new Date(dto.nextScheduledDate) : null;
    if (scheduleNext && (!nextScheduledDate || Number.isNaN(nextScheduledDate.getTime()))) {
      throw new BadRequestException('A valid nextScheduledDate is required to schedule the next follow-up');
    }
    if (scheduleNext && nextScheduledDate && nextScheduledDate <= new Date()) {
      throw new BadRequestException('nextScheduledDate must be in the future');
    }

    return this.prisma.$transaction(async (tx) => {
      const completedAt = new Date();
      const completed = await tx.crmFollowUp.update({
        where: { id },
        data: {
          status: 'COMPLETED',
          completedDate: completedAt,
          interactionDate: completedAt,
          discussion: dto.discussion?.trim() || followUp.discussion,
          outcome: dto.outcome?.trim() || followUp.outcome,
          nextAction: dto.nextAction?.trim() || followUp.nextAction,
          notes: dto.notes?.trim()
            ? `${followUp.notes ? `${followUp.notes}\n` : ''}${dto.notes.trim()}`
            : followUp.notes,
        },
        include: {
          customer: { select: { id: true, companyName: true, phone: true } },
          assignedStaff: { select: { id: true, fullName: true } },
        },
      });

      if (scheduleNext) {
        if (!followUp.customerId) throw new BadRequestException('Only company follow-ups can schedule a next company follow-up');
        const followUpNumber = await this.nextCustomerFollowUpNumber(tx, followUp.customerId);
        await tx.crmFollowUp.create({
          data: {
            title: dto.nextSubject?.trim() || dto.nextAction?.trim() || 'Follow-up',
            subject: dto.nextSubject?.trim() || null,
            activityType: dto.nextActivityType || followUp.activityType,
            customerId: followUp.customerId,
            assignedStaffId: dto.assignedStaffId || followUp.assignedStaffId,
            followUpNumber,
            scheduledDate: nextScheduledDate,
            status: 'PENDING',
            priority: dto.priority || followUp.priority,
            notes: dto.nextNotes?.trim() || null,
          },
        });
      }

      return completed;
    });
  }

  // ─── ANALYTICS ────────────────────────────────────────────────────────────
  async getAnalytics(type: string, user?: any) {
    const scope = this.buildScopeFilter(user);

    if (type === 'pipeline') {
      const opps = await this.prisma.opportunity.groupBy({
        by: ['stage'],
        where: scope,
        _count: { id: true },
        _sum: { estimatedValue: true, weightedValue: true },
      });
      return opps.map((o) => ({
        stage: o.stage,
        count: o._count.id,
        totalValue: o._sum.estimatedValue || 0,
        weightedValue: o._sum.weightedValue || 0,
      }));
    }

    if (type === 'lead-sources') {
      const sources = await this.prisma.lead.groupBy({
        by: ['source'],
        where: scope,
        _count: { id: true },
      });
      return sources.map((s) => ({ source: s.source || 'UNKNOWN', count: s._count.id }));
    }

    if (type === 'product-demand') {
      const leads = await this.prisma.lead.groupBy({
        by: ['productInterest'],
        where: scope,
        _count: { id: true },
        _sum: { estimatedValue: true },
      });
      return leads.map((l) => ({
        product: l.productInterest || 'General Inquiry',
        count: l._count.id,
        totalValue: l._sum.estimatedValue || 0,
      }));
    }

    return [];
  }

  async getAnalyticsOverview(user?: any) {
    const scope = this.buildScopeFilter(user);

    const [oppStages, sources, wonVsLostStats] = await Promise.all([
      this.prisma.opportunity.groupBy({
        by: ['stage'],
        where: scope,
        _count: { id: true },
        _sum: { estimatedValue: true, weightedValue: true },
      }),
      this.prisma.lead.groupBy({
        by: ['source'],
        where: scope,
        _count: { id: true },
      }),
      this.prisma.opportunity.findMany({
        where: {
          ...scope,
          stage: { in: ['CLOSED_WON', 'CLOSED_LOST'] },
        },
        select: { stage: true, estimatedValue: true },
      }),
    ]);

    const wonOpps = wonVsLostStats.filter((o) => o.stage === 'CLOSED_WON');
    const lostOpps = wonVsLostStats.filter((o) => o.stage === 'CLOSED_LOST');

    return {
      opportunityStages: oppStages.map((o) => ({
        stage: o.stage,
        count: o._count.id,
        totalValue: o._sum.estimatedValue || 0,
        weightedValue: o._sum.weightedValue || 0,
      })),
      leadSources: sources.map((s) => ({ source: s.source || 'UNKNOWN', count: s._count.id })),
      wonVsLost: {
        wonCount: wonOpps.length,
        lostCount: lostOpps.length,
        wonValue: wonOpps.reduce((sum, o) => sum + (o.estimatedValue || 0), 0),
        lostValue: lostOpps.reduce((sum, o) => sum + (o.estimatedValue || 0), 0),
      },
    };
  }

  // ─── ENQUIRIES ────────────────────────────────────────────────────────────
  async getEnquiries(query?: any, user?: any) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.customerId) where.customerId = query.customerId;
    if (query?.status && query.status !== 'ALL') where.status = query.status;
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
          customer: { select: { id: true, companyName: true, customerCode: true, phone: true } },
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
      include: { customer: true, opportunities: true },
    });
    if (!enquiry) throw new NotFoundException('Enquiry not found');
    return enquiry;
  }

  async createEnquiry(dto: any, user?: any) {
    const enquiryNumber = await this.sequenceService.nextEnquiryNumber();

    const enquiry = await this.prisma.enquiry.create({
      data: {
        enquiryNumber,
        customerId: dto.customerId,
        productInterest: dto.productInterest,
        quantity: Number(dto.quantity || 1),
        requirement: dto.requirement,
        expectedValue: Number(dto.expectedValue || 0),
        assignedStaffId: dto.assignedStaffId || user?.staffId,
        priority: dto.priority || 'MEDIUM',
        status: dto.status || 'PENDING',
        followUpDate: dto.followUpDate ? new Date(dto.followUpDate) : null,
        remarks: dto.remarks,
      },
      include: { customer: true },
    });

    await this.auditService.log({
      userId: user?.id,
      userEmail: user?.email,
      action: 'CREATE',
      module: 'CRM',
      entityType: 'Enquiry',
      entityId: enquiry.id,
      details: `Created Enquiry: ${enquiry.enquiryNumber}`,
    });

    return enquiry;
  }

  async updateEnquiry(id: string, dto: any, user?: any) {
    const existing = await this.prisma.enquiry.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Enquiry not found');

    const updateData: any = {};
    const fields = ['productInterest', 'quantity', 'requirement', 'expectedValue', 'assignedStaffId', 'priority', 'status', 'remarks'];
    fields.forEach((f) => { if (dto[f] !== undefined) updateData[f] = dto[f]; });
    if (dto.followUpDate !== undefined) {
      updateData.followUpDate = dto.followUpDate ? new Date(dto.followUpDate) : null;
    }

    const enquiry = await this.prisma.enquiry.update({ where: { id }, data: updateData });

    await this.auditService.log({
      userId: user?.id,
      userEmail: user?.email,
      action: 'UPDATE',
      module: 'CRM',
      entityType: 'Enquiry',
      entityId: id,
      details: `Updated Enquiry: ${enquiry.enquiryNumber}`,
    });

    return enquiry;
  }

  // ─── PRODUCT & SYSTEM INTERESTS MASTER ────────────────────────────────────
  async getProductSystems() {
    let systems = await this.prisma.productSystem.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
    });

    if (systems.length === 0) {
      const standardSystems = [
        { code: 'VFD_PANEL', name: 'VFD Control Panels (DOL/Star-Delta/Soft-Starter)', category: 'Automation' },
        { code: 'BOOSTER_PUMP', name: 'Hydro-Pneumatic Booster Pump Systems', category: 'Water Systems' },
        { code: 'STP', name: 'Sewage Treatment Plant (STP) Panels & Automation', category: 'Water Treatment' },
        { code: 'BMS', name: 'Building Management System (BMS) & DDC Panels', category: 'Building Automation' },
        { code: 'HVAC', name: 'HVAC Chiller & AHU Automation', category: 'HVAC' },
        { code: 'DEWATERING', name: 'Submersible Dewatering & Drainage Systems', category: 'Pumping' },
        { code: 'FIRE_PANEL', name: 'Fire Fighting Pump Control Panels', category: 'Fire Safety' },
        { code: 'SOLAR_PUMP', name: 'Solar VFD Pumping Systems', category: 'Renewable' },
        { code: 'RO_PLANT', name: 'Industrial RO Water Treatment Automation', category: 'Water Treatment' },
      ];

      for (const sys of standardSystems) {
        await this.prisma.productSystem.upsert({
          where: { code: sys.code },
          create: sys,
          update: sys,
        });
      }

      systems = await this.prisma.productSystem.findMany({
        where: { isActive: true },
        orderBy: { name: 'asc' },
      });
    }

    return systems;
  }

  // ─── UNIFIED COMPANIES (CUSTOMER / COMPANY 360 MASTER) ───────────────────
  async getCompanies(query?: any, user?: any) {
    const page = Math.max(1, Number(query?.page) || 1);
    const limit = Math.max(1, Math.min(100, Number(query?.limit) || 25));
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.customerType || query?.type) where.customerType = query.customerType || query.type;
    if (query?.customerCategory || query?.category) where.customerCategory = query.customerCategory || query.category;
    if (query?.customerSegment) where.customerSegment = query.customerSegment;
    if (query?.state) where.state = query.state;
    if (query?.assignedStaffId) where.assignedStaffId = query.assignedStaffId;

    if (query?.search) {
      const search = query.search.trim();
      where.OR = [
        { companyName: { contains: search } },
        { customerCode: { contains: search } },
        { legalName: { contains: search } },
        { gstin: { contains: search } },
        { pan: { contains: search } },
        { contactPerson: { contains: search } },
        { email: { contains: search } },
        { phone: { contains: search } },
        { city: { contains: search } },
        { state: { contains: search } },
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
          productInterests: { include: { productSystem: true } },
          valuations: true,
          assignedStaff: { select: { id: true, fullName: true, employeeId: true } },
          _count: {
            select: {
              contacts: true,
              activities: true,
              leads: true,
              enquiries: true,
              opportunities: true,
              followUps: true,
              panelSpecs: true,
              projects: true,
              documents: true,
              media: true,
            },
          },
        },
      }),
      this.prisma.customer.count({ where }),
    ]);

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async getCompany360(id: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        assignedStaff: { select: { id: true, fullName: true, email: true, employeeId: true } },
        salesManagerStaff: { select: { id: true, fullName: true, email: true, employeeId: true } },
        contacts: { orderBy: [{ isPrimary: 'desc' }, { createdAt: 'asc' }] },
        productInterests: { include: { productSystem: true } },
        valuations: true,
        valuationHistory: { orderBy: { createdAt: 'desc' }, take: 20 },
        leads: { orderBy: { createdAt: 'desc' }, take: 20 },
        enquiries: { orderBy: { createdAt: 'desc' }, take: 20 },
        opportunities: {
          orderBy: { createdAt: 'desc' },
          include: { assignedStaff: { select: { id: true, fullName: true } } },
          take: 20,
        },
        activities: {
          orderBy: { createdAt: 'desc' },
          include: {
            staff: { select: { id: true, fullName: true } },
            contact: { select: { id: true, name: true, phone: true, mobile: true } },
            call: { include: { recordings: true } },
            meeting: { include: { hostStaff: { select: { id: true, fullName: true } }, scheduleHistory: true } },
            siteVisit: true,
          },
          take: 50,
        },
        followUps: {
          orderBy: { scheduledDate: 'desc' },
          include: { assignedStaff: { select: { id: true, fullName: true } } },
          take: 30,
        },
        panelSpecs: {
          orderBy: { createdAt: 'desc' },
          include: { bomItems: { include: { product: true } } },
          take: 20,
        },
        projects: {
          orderBy: { createdAt: 'desc' },
          include: { projectManager: { select: { id: true, fullName: true } } },
          take: 20,
        },
        documents: { orderBy: { createdAt: 'desc' }, take: 50 },
        media: { orderBy: { createdAt: 'desc' }, take: 50 },
      },
    });

    if (!customer) throw new NotFoundException(`Company / Customer with ID ${id} not found`);
    return customer;
  }

  async getCompanyTimeline(customerId: string) {
    const [activities, followUps, enquiries, opportunities, panelSpecs, projects, documents, media] = await Promise.all([
      this.prisma.crmActivity.findMany({
        where: { customerId },
        orderBy: { createdAt: 'desc' },
        include: {
          staff: { select: { id: true, fullName: true } },
          contact: { select: { id: true, name: true } },
          call: { include: { recordings: true } },
          meeting: { include: { hostStaff: { select: { id: true, fullName: true } } } },
          siteVisit: true,
        },
        take: 100,
      }),
      this.prisma.crmFollowUp.findMany({
        where: { customerId },
        orderBy: { scheduledDate: 'desc' },
        include: { assignedStaff: { select: { id: true, fullName: true } } },
        take: 50,
      }),
      this.prisma.enquiry.findMany({
        where: { customerId },
        orderBy: { createdAt: 'desc' },
        take: 30,
      }),
      this.prisma.opportunity.findMany({
        where: { customerId },
        orderBy: { createdAt: 'desc' },
        take: 30,
      }),
      this.prisma.panelSpecification.findMany({
        where: { customerId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.project.findMany({
        where: { customerId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.customerDocument.findMany({
        where: { customerId },
        orderBy: { createdAt: 'desc' },
        take: 30,
      }),
      this.prisma.customerMedia.findMany({
        where: { customerId },
        orderBy: { createdAt: 'desc' },
        take: 30,
      }),
    ]);

    const timeline: any[] = [];

    activities.forEach((a) => {
      timeline.push({
        id: a.id,
        type: `ACTIVITY_${a.activityType}`,
        title: a.subject || `${a.activityType} Record`,
        description: a.description,
        outcome: a.outcome,
        timestamp: a.createdAt,
        actor: a.staff?.fullName || 'Staff',
        metadata: {
          call: a.call,
          meeting: a.meeting,
          siteVisit: a.siteVisit,
          contact: a.contact,
        },
      });
    });

    followUps.forEach((f) => {
      timeline.push({
        id: f.id,
        type: 'FOLLOW_UP',
        title: f.title,
        description: f.notes,
        status: f.status,
        priority: f.priority,
        timestamp: f.interactionDate || f.scheduledDate || f.createdAt,
        actor: f.assignedStaff?.fullName || 'Assigned Staff',
        metadata: { isCompleted: f.status === 'COMPLETED' },
      });
    });

    enquiries.forEach((e) => {
      timeline.push({
        id: e.id,
        type: 'ENQUIRY',
        title: `Enquiry: ${e.enquiryNumber}`,
        description: e.requirement || `Interest in ${e.productInterest || 'Products'}`,
        timestamp: e.createdAt,
        actor: 'Customer / Sales',
        metadata: { expectedValue: e.expectedValue, priority: e.priority, status: e.status },
      });
    });

    opportunities.forEach((o) => {
      timeline.push({
        id: o.id,
        type: 'OPPORTUNITY',
        title: `Opportunity: ${o.title} (${o.opportunityNumber})`,
        description: `Stage: ${o.stage} (Probability: ${o.probability}%)`,
        timestamp: o.createdAt,
        actor: 'Sales Pipeline',
        metadata: { estimatedValue: o.estimatedValue, stage: o.stage },
      });
    });

    panelSpecs.forEach((p) => {
      timeline.push({
        id: p.id,
        type: 'PANEL_SPEC',
        title: `Engineering Panel Spec: ${p.panelCode} (${p.panelType})`,
        description: `Rating: ${p.pumpHp} HP | Enclosure: ${p.enclosureType}`,
        timestamp: p.createdAt,
        actor: 'Engineering Team',
        metadata: { status: p.status, finalPrice: p.finalPrice },
      });
    });

    projects.forEach((prj) => {
      timeline.push({
        id: prj.id,
        type: 'PROJECT',
        title: `Project: ${prj.name} (${prj.projectNumber})`,
        description: `Status: ${prj.status} | Priority: ${prj.priority}`,
        timestamp: prj.createdAt,
        actor: 'Project Manager',
        metadata: { budget: prj.budget, health: prj.health },
      });
    });

    documents.forEach((d) => {
      timeline.push({
        id: d.id,
        type: 'DOCUMENT',
        title: `Document: ${d.title} (${d.documentType})`,
        description: d.fileName,
        timestamp: d.createdAt,
        actor: 'Document Store',
        metadata: { fileUrl: d.fileUrl, fileSize: d.fileSize },
      });
    });

    media.forEach((m) => {
      timeline.push({
        id: m.id,
        type: 'MEDIA',
        title: `Media: ${m.title || m.mediaType}`,
        description: `${m.mediaType} (Duration: ${m.durationSec || 0}s)`,
        timestamp: m.createdAt,
        actor: 'Media Gallery',
        metadata: { fileUrl: m.fileUrl, mediaType: m.mediaType },
      });
    });

    // Sort all chronologically descending
    timeline.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

    return timeline;
  }

  async checkCompanyDuplicate(dto: { gstin?: string; phone?: string; email?: string; companyName?: string; domain?: string }) {
    const duplicates: any[] = [];

    if (dto.gstin && dto.gstin.trim()) {
      const byGst = await this.prisma.customer.findFirst({
        where: { gstin: dto.gstin.trim().toUpperCase() },
        select: { id: true, customerCode: true, companyName: true, gstin: true, phone: true, email: true },
      });
      if (byGst) duplicates.push({ matchField: 'gstin', value: dto.gstin, existingCompany: byGst });
    }

    if (dto.phone && dto.phone.trim()) {
      const byPhone = await this.prisma.customer.findFirst({
        where: {
          OR: [{ phone: dto.phone.trim() }, { alternatePhone: dto.phone.trim() }],
        },
        select: { id: true, customerCode: true, companyName: true, phone: true, email: true },
      });
      if (byPhone && !duplicates.some((d) => d.existingCompany.id === byPhone.id)) {
        duplicates.push({ matchField: 'phone', value: dto.phone, existingCompany: byPhone });
      }
    }

    if (dto.email && dto.email.trim()) {
      const byEmail = await this.prisma.customer.findFirst({
        where: { email: { equals: dto.email.trim() } },
        select: { id: true, customerCode: true, companyName: true, phone: true, email: true },
      });
      if (byEmail && !duplicates.some((d) => d.existingCompany.id === byEmail.id)) {
        duplicates.push({ matchField: 'email', value: dto.email, existingCompany: byEmail });
      }
    }

    if (dto.companyName && dto.companyName.trim()) {
      const byName = await this.prisma.customer.findFirst({
        where: { companyName: { equals: dto.companyName.trim() } },
        select: { id: true, customerCode: true, companyName: true, phone: true, email: true },
      });
      if (byName && !duplicates.some((d) => d.existingCompany.id === byName.id)) {
        duplicates.push({ matchField: 'companyName', value: dto.companyName, existingCompany: byName });
      }
    }

    return {
      hasDuplicate: duplicates.length > 0,
      duplicates,
    };
  }

  async verifyGst(gstin: string, user?: any, ipAddress?: string) {
    const maskedGstin = typeof gstin === 'string'
      ? `***********${gstin.trim().toUpperCase().slice(-4)}`
      : 'unavailable';
    try {
      const result = await this.gstVerificationService.verifyAndFetch(gstin, user?.id);
      await this.auditService.log({
        userId: user?.id,
        userEmail: user?.email,
        action: 'GST_VERIFY',
        module: 'CRM',
        entityType: 'GSTIN',
        details: `GSTIN Portal verification succeeded for ${maskedGstin}.`,
        ipAddress,
      });
      return result;
    } catch (error) {
      await this.auditService.log({
        userId: user?.id,
        userEmail: user?.email,
        action: 'GST_VERIFY_FAILED',
        module: 'CRM',
        entityType: 'GSTIN',
        details: `GSTIN Portal verification failed for ${maskedGstin}.`,
        ipAddress,
      });
      throw error;
    }
  }

  async createCompany(dto: any, user?: any) {
    if (dto.pan != null && typeof dto.pan !== 'string') {
      throw new BadRequestException('PAN must be provided as text.');
    }
    const isGstRegistered = dto.gstStatus
      ? dto.gstStatus !== 'NO_GST'
      : Boolean(dto.gstin);
    const cleanGstin = isGstRegistered && typeof dto.gstin === 'string'
      ? dto.gstin.trim().toUpperCase()
      : null;

    if (isGstRegistered && !cleanGstin) {
      throw new BadRequestException('GSTIN is required for a GST-registered company.');
    }

    if (cleanGstin) {
      if (
        !this.gstVerificationService.validateFormat(cleanGstin) ||
        !this.gstVerificationService.validateChecksum(cleanGstin)
      ) {
        throw new BadRequestException('Enter a valid GSTIN, including its checksum digit.');
      }
      if (dto.pan && dto.pan.trim().toUpperCase() !== cleanGstin.substring(2, 12)) {
        throw new BadRequestException('PAN must match the PAN embedded in the GSTIN.');
      }
      const existing = await this.prisma.customer.findFirst({ where: { gstin: cleanGstin } });
      if (existing) {
        throw new ConflictException(
          `Company with GSTIN ${cleanGstin} already exists (${existing.customerCode} — ${existing.companyName})`,
        );
      }
    }

    const verification = this.gstVerificationService.getVerifiedMetadata(
      dto.gstVerificationToken,
      cleanGstin,
      user?.id,
    );
    const customerCode = await this.sequenceService.nextCustomerCode();

    const contactName = dto.contactPerson || dto.contacts?.[0]?.name || dto.companyName;
    const contactPhone = dto.phone || dto.contacts?.[0]?.mobile || '9999999999';
    const contactEmail = dto.email || dto.contacts?.[0]?.email || `${customerCode.toLowerCase()}@saark.in`;

    return this.prisma.$transaction(async (tx) => {
      const customer = await tx.customer.create({
        data: {
          customerCode,
          companyName: dto.companyName,
          legalName: dto.legalName || dto.companyName,
          gstin: cleanGstin,
          pan: dto.pan ? dto.pan.trim().toUpperCase() : cleanGstin ? cleanGstin.substring(2, 12) : null,
          gstStatus: dto.gstStatus || (dto.gstin ? 'GST_REGISTERED' : 'NO_GST'),
          noGstReason: dto.noGstReason || null,
          gstVerified: verification?.gstVerified ?? false,
          gstVerifiedAt: verification?.gstVerifiedAt ?? null,
          gstProviderRef: verification?.gstProviderRef ?? null,
          tradeName: dto.tradeName || null,
          companyType: dto.companyType || 'PVT_LTD',
          numEmployees: Number(dto.numEmployees || dto.staffCount || 0),
          customerType: dto.customerType || 'END_CUSTOMER',
          customerCategory: dto.customerCategory || 'STANDARD',
          customerSegment: dto.customerSegment || 'VFD_PANEL',
          contactPerson: contactName,
          designation: dto.designation || 'Key Contact',
          email: contactEmail,
          phone: contactPhone,
          alternatePhone: dto.alternatePhone || null,
          website: dto.website || null,
          address: dto.address || 'Industrial Area',
          country: dto.country || 'India',
          state: dto.state || 'Maharashtra',
          district: dto.district || 'Pune',
          city: dto.city || 'Pune',
          pincode: dto.pincode || '411026',
          ownerName: dto.ownerName || null,
          staffCount: Number(dto.numEmployees || dto.staffCount || 0),
          turnover: dto.turnover || dto.companyTurnover || null,
          industry: dto.industry || 'Industrial Automation',
          source: dto.source || 'DIRECT',
          customerRating: Number(dto.customerRating || 5.0),
          creditLimit: Number(dto.creditLimit || 0),
          paymentTerms: dto.paymentTerms || 'NET_30',
          potentialValue: Number(dto.potentialValue || 0),
          status: dto.status || 'ACTIVE',
          assignedStaffId: dto.assignedStaffId || user?.staffId || null,
          salesManagerStaffId: dto.salesManagerStaffId || null,
        },
      });

      // Create primary contact
      await tx.customerContact.create({
        data: {
          customerId: customer.id,
          name: contactName,
          designation: dto.designation || 'Primary Contact',
          department: dto.department || 'Management',
          mobile: contactPhone,
          phone: dto.alternatePhone || null,
          email: contactEmail,
          whatsapp: dto.whatsapp || contactPhone,
          isPrimary: true,
          isDecisionMaker: true,
          isTechnical: Boolean(dto.isTechnical),
          isCommercial: Boolean(dto.isCommercial),
          isPurchase: Boolean(dto.isPurchase),
          preferredCommunication: dto.preferredCommunication || 'CALL',
          notes: 'Auto-created primary contact',
        },
      });

      // Create additional contacts if provided
      if (Array.isArray(dto.contacts) && dto.contacts.length > 1) {
        for (let i = 1; i < dto.contacts.length; i++) {
          const c = dto.contacts[i];
          if (c.name && (c.mobile || c.phone)) {
            await tx.customerContact.create({
              data: {
                customerId: customer.id,
                name: c.name,
                designation: c.designation || null,
                department: c.department || null,
                mobile: c.mobile || c.phone,
                phone: c.phone || null,
                email: c.email || null,
                whatsapp: c.whatsapp || null,
                isPrimary: false,
                isDecisionMaker: Boolean(c.isDecisionMaker),
                isTechnical: Boolean(c.isTechnical),
                isCommercial: Boolean(c.isCommercial),
                isPurchase: Boolean(c.isPurchase),
                preferredCommunication: c.preferredCommunication || 'CALL',
                notes: c.notes || null,
              },
            });
          }
        }
      }

      // Link product interests if provided
      if (Array.isArray(dto.productSystemIds) && dto.productSystemIds.length > 0) {
        for (const sysId of dto.productSystemIds) {
          await tx.companyProductInterest.create({
            data: {
              customerId: customer.id,
              productSystemId: sysId,
              interestLevel: 'HIGH',
            },
          });
        }
      }

      // Initial valuation record
      const valScore = Math.min(100, Math.round((Number(dto.customerRating || 5.0) / 5) * 60 + 30));
      await tx.customerValuation.create({
        data: {
          customerId: customer.id,
          ratingScore: Number(dto.customerRating || 5.0),
          valuablePercentage: valScore,
          engagementScore: 50.0,
          vfdWorkScore: 75.0,
          dewateringWorkScore: 50.0,
          isDealer: dto.customerType === 'DEALER',
          isDistributor: dto.customerType === 'DISTRIBUTOR',
          lifetimeValue: Number(dto.potentialValue || 0),
        },
      });

      // Valuation history
      await tx.companyValuationHistory.create({
        data: {
          customerId: customer.id,
          oldRating: null,
          newRating: Number(dto.customerRating || 5.0),
          oldValueScore: null,
          newValueScore: valScore,
          calculatedBy: 'SYSTEM',
          staffId: user?.staffId || null,
          reason: 'Initial company on-boarding valuation',
        },
      });

      await this.auditService.log({
        userId: user?.id,
        userEmail: user?.email,
        action: 'CREATE',
        module: 'CRM',
        entityType: 'Company',
        entityId: customer.id,
        details: `Created Company Master: ${customer.customerCode} — ${customer.companyName}`,
      });

      return customer;
    });
  }

  async updateCompany(id: string, dto: any, user?: any) {
    const existing = await this.prisma.customer.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException(`Company ${id} not found`);
    if (dto.pan != null && typeof dto.pan !== 'string') {
      throw new BadRequestException('PAN must be provided as text.');
    }

    const cleanGstin = dto.gstStatus === 'NO_GST'
      ? null
      : dto.gstin !== undefined
        ? (typeof dto.gstin === 'string' ? dto.gstin.trim().toUpperCase() : null)
        : existing.gstin;
    if (dto.gstStatus === 'GST_REGISTERED' && !cleanGstin) {
      throw new BadRequestException('GSTIN is required for a GST-registered company.');
    }
    if (dto.gstin !== undefined && dto.gstStatus !== 'NO_GST' && !cleanGstin) {
      throw new BadRequestException('GSTIN must be a valid 15-character value.');
    }
    if (cleanGstin) {
      if (
        !this.gstVerificationService.validateFormat(cleanGstin) ||
        !this.gstVerificationService.validateChecksum(cleanGstin)
      ) {
        throw new BadRequestException('Enter a valid GSTIN, including its checksum digit.');
      }
      if (dto.pan && dto.pan.trim().toUpperCase() !== cleanGstin.substring(2, 12)) {
        throw new BadRequestException('PAN must match the PAN embedded in the GSTIN.');
      }
      if (cleanGstin !== existing.gstin) {
        const duplicate = await this.prisma.customer.findFirst({
          where: { gstin: cleanGstin, NOT: { id } },
          select: { customerCode: true, companyName: true },
        });
        if (duplicate) {
          throw new ConflictException(
            `Company with GSTIN ${cleanGstin} already exists (${duplicate.customerCode} — ${duplicate.companyName})`,
          );
        }
      }
    }

    const submittedVerification = this.gstVerificationService.getVerifiedMetadata(
      dto.gstVerificationToken,
      cleanGstin,
      user?.id,
    );
    const verification = submittedVerification ?? (
      cleanGstin && cleanGstin === existing.gstin && existing.gstVerified
        ? {
            gstVerified: true as const,
            gstVerifiedAt: existing.gstVerifiedAt,
            gstProviderRef: existing.gstProviderRef,
          }
        : null
    );

    const updateData: any = {};
    const scalarFields = [
      'companyName', 'legalName', 'pan', 'gstStatus', 'noGstReason',
      'tradeName', 'companyType', 'numEmployees',
      'customerType', 'customerCategory', 'customerSegment', 'contactPerson',
      'designation', 'email', 'phone', 'alternatePhone', 'website', 'address',
      'country', 'state', 'district', 'city', 'pincode', 'ownerName', 'staffCount',
      'turnover', 'industry', 'source', 'customerRating', 'creditLimit', 'paymentTerms',
      'potentialValue', 'status', 'assignedStaffId', 'salesManagerStaffId',
    ];

    scalarFields.forEach((f) => {
      if (dto[f] !== undefined) updateData[f] = dto[f];
    });

    if (dto.gstin !== undefined || dto.gstStatus === 'NO_GST') {
      updateData.gstin = cleanGstin;
    }
    updateData.gstVerified = verification?.gstVerified ?? false;
    updateData.gstVerifiedAt = verification?.gstVerifiedAt ?? null;
    updateData.gstProviderRef = verification?.gstProviderRef ?? null;

    const updated = await this.prisma.customer.update({
      where: { id },
      data: updateData,
      include: {
        contacts: true,
        productInterests: { include: { productSystem: true } },
        valuations: true,
      },
    });

    await this.auditService.log({
      userId: user?.id,
      userEmail: user?.email,
      action: 'UPDATE',
      module: 'CRM',
      entityType: 'Company',
      entityId: id,
      details: `Updated Company Master: ${updated.customerCode} — ${updated.companyName}`,
    });

    return updated;
  }

  async updateCompanyProductInterests(customerId: string, productSystemIds: string[]) {
    const customer = await this.prisma.customer.findUnique({ where: { id: customerId } });
    if (!customer) throw new NotFoundException('Company not found');

    return this.prisma.$transaction(async (tx) => {
      await tx.companyProductInterest.deleteMany({ where: { customerId } });
      for (const sysId of productSystemIds) {
        await tx.companyProductInterest.create({
          data: { customerId, productSystemId: sysId, interestLevel: 'HIGH' },
        });
      }

      return tx.companyProductInterest.findMany({
        where: { customerId },
        include: { productSystem: true },
      });
    });
  }

  async updateCompanyValuation(customerId: string, dto: any, user?: any) {
    const customer = await this.prisma.customer.findUnique({
      where: { id: customerId },
      include: { valuations: true },
    });
    if (!customer) throw new NotFoundException('Company not found');

    const oldRating = customer.customerRating;
    const oldValueScore = customer.valuations?.valuablePercentage || 50.0;
    const newRating = dto.ratingScore !== undefined ? Number(dto.ratingScore) : oldRating;
    const newValueScore = dto.valuablePercentage !== undefined ? Number(dto.valuablePercentage) : oldValueScore;

    return this.prisma.$transaction(async (tx) => {
      await tx.customer.update({
        where: { id: customerId },
        data: { customerRating: newRating },
      });

      const valuation = await tx.customerValuation.upsert({
        where: { customerId },
        create: {
          customerId,
          ratingScore: newRating,
          valuablePercentage: newValueScore,
          engagementScore: dto.engagementScore !== undefined ? Number(dto.engagementScore) : 50.0,
          vfdWorkScore: dto.vfdWorkScore !== undefined ? Number(dto.vfdWorkScore) : 70.0,
          dewateringWorkScore: dto.dewateringWorkScore !== undefined ? Number(dto.dewateringWorkScore) : 50.0,
          isDealer: Boolean(dto.isDealer),
          isDistributor: Boolean(dto.isDistributor),
          lifetimeValue: dto.lifetimeValue !== undefined ? Number(dto.lifetimeValue) : 0,
        },
        update: {
          ratingScore: newRating,
          valuablePercentage: newValueScore,
          engagementScore: dto.engagementScore !== undefined ? Number(dto.engagementScore) : undefined,
          vfdWorkScore: dto.vfdWorkScore !== undefined ? Number(dto.vfdWorkScore) : undefined,
          dewateringWorkScore: dto.dewateringWorkScore !== undefined ? Number(dto.dewateringWorkScore) : undefined,
          isDealer: dto.isDealer !== undefined ? Boolean(dto.isDealer) : undefined,
          isDistributor: dto.isDistributor !== undefined ? Boolean(dto.isDistributor) : undefined,
          lifetimeValue: dto.lifetimeValue !== undefined ? Number(dto.lifetimeValue) : undefined,
        },
      });

      await tx.companyValuationHistory.create({
        data: {
          customerId,
          oldRating,
          newRating,
          oldValueScore,
          newValueScore,
          calculatedBy: dto.calculatedBy || 'STAFF',
          staffId: user?.staffId || null,
          reason: dto.reason || 'Manual valuation adjustment',
        },
      });

      return valuation;
    });
  }

  async respondMeeting(meetingId: string, dto: { action: 'ACCEPT' | 'RESCHEDULE' | 'DECLINE'; newStartTime?: string; newEndTime?: string; reason?: string }, user?: any) {
    const meeting = await this.prisma.crmMeeting.findUnique({
      where: { id: meetingId },
      include: { activity: true },
    });
    if (!meeting) throw new NotFoundException('Meeting not found');

    const staffId = user?.staffId || 'SYSTEM';

    return this.prisma.$transaction(async (tx) => {
      let newStatus = meeting.meetingStatus;
      let newStartTime = meeting.startTime;
      let newEndTime = meeting.endTime;

      if (dto.action === 'ACCEPT') {
        newStatus = 'ACCEPTED';
      } else if (dto.action === 'DECLINE') {
        newStatus = 'DECLINED';
      } else if (dto.action === 'RESCHEDULE') {
        if (!dto.newStartTime) throw new BadRequestException('newStartTime is required for reschedule');
        newStatus = 'RESCHEDULE_PROPOSED';
        newStartTime = new Date(dto.newStartTime);
        newEndTime = dto.newEndTime ? new Date(dto.newEndTime) : null;

        await tx.meetingScheduleHistory.create({
          data: {
            meetingId,
            previousStartTime: meeting.startTime,
            previousEndTime: meeting.endTime,
            newStartTime,
            newEndTime,
            changedByStaffId: staffId,
            reason: dto.reason || 'Rescheduled by participant',
            statusBefore: meeting.meetingStatus,
            statusAfter: newStatus,
          },
        });
      }

      const updatedMeeting = await tx.crmMeeting.update({
        where: { id: meetingId },
        data: {
          meetingStatus: newStatus,
          startTime: newStartTime,
          endTime: newEndTime,
          rescheduleReason: dto.reason || meeting.rescheduleReason,
          rescheduleCount: dto.action === 'RESCHEDULE' ? meeting.rescheduleCount + 1 : meeting.rescheduleCount,
        },
        include: { hostStaff: { select: { id: true, fullName: true } }, scheduleHistory: true },
      });

      return updatedMeeting;
    });
  }

  async uploadCallRecording(callId: string, dto: any, user?: any) {
    const call = await this.prisma.crmCall.findUnique({ where: { id: callId } });
    if (!call) throw new NotFoundException('Call activity not found');

    const recording = await this.prisma.callRecording.create({
      data: {
        callId,
        fileName: dto.fileName || `recording_${Date.now()}.webm`,
        fileUrl: dto.fileUrl,
        durationSec: Number(dto.durationSec || call.durationSec || 0),
        fileSizeBytes: Number(dto.fileSizeBytes || 0),
        mimeType: dto.mimeType || 'audio/webm',
        uploadedBy: user?.fullName || user?.email || 'User',
      },
    });

    await this.prisma.crmCall.update({
      where: { id: callId },
      data: { recordingUrl: dto.fileUrl },
    });

    return recording;
  }

  async getMyWork(user: any) {
    const staffId = user?.staffId;
    const filter = staffId ? { assignedStaffId: staffId } : {};

    const [pendingFollowUps, todayMeetings, openLeads, activeOpportunities] = await Promise.all([
      this.prisma.crmFollowUp.findMany({
        where: {
          ...filter,
          status: 'PENDING',
        },
        orderBy: { scheduledDate: 'asc' },
        include: { customer: { select: { id: true, companyName: true, phone: true } } },
        take: 50,
      }),
      this.prisma.crmMeeting.findMany({
        where: {
          OR: [
            { hostStaffId: staffId },
            { requestedByStaffId: staffId },
            { activity: { staffId } },
          ],
          startTime: {
            gte: new Date(new Date().setHours(0, 0, 0, 0)),
            lte: new Date(new Date().setHours(23, 59, 59, 999)),
          },
        },
        include: {
          activity: {
            include: {
              customer: { select: { id: true, companyName: true, phone: true } },
              contact: { select: { id: true, name: true, phone: true, mobile: true } },
            },
          },
          hostStaff: { select: { id: true, fullName: true } },
        },
      }),
      this.prisma.lead.findMany({
        where: {
          ...filter,
          status: { in: ['NEW', 'CONTACTED', 'QUALIFIED', 'PROPOSAL'] },
        },
        orderBy: { createdAt: 'desc' },
        take: 30,
      }),
      this.prisma.opportunity.findMany({
        where: {
          ...filter,
          stage: { notIn: ['CLOSED_WON', 'CLOSED_LOST'] },
        },
        orderBy: { expectedCloseDate: 'asc' },
        include: { customer: { select: { id: true, companyName: true } } },
        take: 30,
      }),
    ]);

    return {
      pendingFollowUps,
      todayMeetings,
      openLeads,
      activeOpportunities,
      stats: {
        pendingFollowUpsCount: pendingFollowUps.length,
        todayMeetingsCount: todayMeetings.length,
        openLeadsCount: openLeads.length,
        activeOpportunitiesCount: activeOpportunities.length,
      },
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MEETINGS MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  async getMeetings(query: any, user?: any) {
    const { customerId, status, hostStaffId, search, page = 1, limit = 50 } = query;
    const skip = (Number(page) - 1) * Number(limit);
    const take = Number(limit);

    const where: any = {};
    if (customerId) where.activity = { customerId };
    if (status) where.meetingStatus = status;
    if (hostStaffId) where.hostStaffId = hostStaffId;
    if (search) {
      where.OR = [
        { agenda: { contains: search } },
        { location: { contains: search } },
        { activity: { subject: { contains: search } } },
        { activity: { customer: { companyName: { contains: search } } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.crmMeeting.findMany({
        where,
        skip,
        take,
        include: {
          activity: {
            include: {
              customer: { select: { id: true, companyName: true, phone: true, city: true } },
              contact: { select: { id: true, name: true, designation: true, mobile: true } },
              staff: { select: { id: true, fullName: true } },
            },
          },
          hostStaff: { select: { id: true, fullName: true, mobile: true, email: true } },
          scheduleHistory: { orderBy: { createdAt: 'desc' } },
        },
        orderBy: { startTime: 'desc' },
      }),
      this.prisma.crmMeeting.count({ where }),
    ]);

    return { items, total, page: Number(page), limit: Number(limit) };
  }

  async createMeeting(dto: any, user?: any) {
    let staffId = dto.staffId || user?.staffId;
    if (!staffId && user?.id) {
      const staff = await this.prisma.staff.findFirst({ where: { userId: user.id } });
      if (staff) staffId = staff.id;
    }
    if (!staffId) {
      const anyStaff = await this.prisma.staff.findFirst();
      if (anyStaff) staffId = anyStaff.id;
    }

    const startTime = new Date(dto.startTime || Date.now());
    const endTime = dto.endTime ? new Date(dto.endTime) : new Date(startTime.getTime() + 60 * 60 * 1000);

    return this.prisma.$transaction(async (tx) => {
      const activity = await tx.crmActivity.create({
        data: {
          activityType: 'MEETING',
          customerId: dto.customerId || null,
          contactId: dto.contactId || null,
          opportunityId: dto.opportunityId || null,
          staffId: staffId!,
          subject: dto.agenda || `Meeting with ${dto.customerName || 'Client'}`,
          description: dto.notes || dto.agenda,
          outcome: 'SCHEDULED',
        },
      });

      const meeting = await tx.crmMeeting.create({
        data: {
          activityId: activity.id,
          meetingType: dto.meetingType || 'OFFLINE',
          location: dto.location || 'Client Office',
          startTime,
          endTime,
          agenda: dto.agenda,
          hostStaffId: dto.hostStaffId || staffId,
          requestedByStaffId: staffId,
          meetingStatus: dto.hostStaffId && dto.hostStaffId !== staffId ? 'REQUESTED' : 'SCHEDULED',
        },
        include: {
          activity: { include: { customer: true, contact: true } },
          hostStaff: true,
        },
      });

      return meeting;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALLS MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  async getCalls(query: any, user?: any) {
    const { customerId, callOutcome, callType, search, page = 1, limit = 50 } = query;
    const skip = (Number(page) - 1) * Number(limit);
    const take = Number(limit);

    const where: any = {};
    if (customerId) where.activity = { customerId };
    if (callOutcome) where.callOutcome = callOutcome;
    if (callType) where.callType = callType;
    if (search) {
      where.OR = [
        { activity: { subject: { contains: search } } },
        { activity: { description: { contains: search } } },
        { activity: { customer: { companyName: { contains: search } } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.crmCall.findMany({
        where,
        skip,
        take,
        include: {
          activity: {
            include: {
              customer: { select: { id: true, companyName: true, phone: true } },
              contact: { select: { id: true, name: true, mobile: true } },
              staff: { select: { id: true, fullName: true } },
            },
          },
          contact: true,
          recordings: true,
        },
        orderBy: { activity: { createdAt: 'desc' } },
      }),
      this.prisma.crmCall.count({ where }),
    ]);

    return { items, total, page: Number(page), limit: Number(limit) };
  }

  async createCall(dto: any, user?: any) {
    let staffId = dto.staffId || user?.staffId;
    if (!staffId && user?.id) {
      const staff = await this.prisma.staff.findFirst({ where: { userId: user.id } });
      if (staff) staffId = staff.id;
    }
    if (!staffId) {
      const anyStaff = await this.prisma.staff.findFirst();
      if (anyStaff) staffId = anyStaff.id;
    }

    return this.prisma.$transaction(async (tx) => {
      const activity = await tx.crmActivity.create({
        data: {
          activityType: 'CALL',
          customerId: dto.customerId || null,
          contactId: dto.contactId || null,
          opportunityId: dto.opportunityId || null,
          staffId: staffId!,
          subject: dto.subject || `${dto.callType || 'OUTBOUND'} Call - ${dto.callOutcome || 'CONNECTED'}`,
          description: dto.notes || dto.description,
          outcome: dto.callOutcome || 'CONNECTED',
        },
      });

      const call = await tx.crmCall.create({
        data: {
          activityId: activity.id,
          contactId: dto.contactId || null,
          callType: dto.callType || 'OUTBOUND',
          durationSec: Number(dto.durationSec || 0),
          callOutcome: dto.callOutcome || 'CONNECTED',
          recordingUrl: dto.recordingUrl || null,
          dataSent: Boolean(dto.dataSent),
          dataTypes: dto.dataTypes ? JSON.stringify(dto.dataTypes) : null,
        },
        include: {
          activity: { include: { customer: true, contact: true } },
          recordings: true,
        },
      });

      if (dto.recordingUrl) {
        await tx.callRecording.create({
          data: {
            callId: call.id,
            fileName: dto.recordingFileName || `Call_${Date.now()}.webm`,
            fileUrl: dto.recordingUrl,
            durationSec: Number(dto.durationSec || 0),
            uploadedBy: user?.fullName || 'User',
          },
        });
      }

      return call;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SITE VISITS MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  async getSiteVisits(query: any, user?: any) {
    const { customerId, search, page = 1, limit = 50 } = query;
    const skip = (Number(page) - 1) * Number(limit);
    const take = Number(limit);

    const where: any = {};
    if (customerId) where.activity = { customerId };
    if (search) {
      where.OR = [
        { location: { contains: search } },
        { inspectionNotes: { contains: search } },
        { activity: { customer: { companyName: { contains: search } } } },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.crmSiteVisit.findMany({
        where,
        skip,
        take,
        include: {
          activity: {
            include: {
              customer: { select: { id: true, companyName: true, phone: true, city: true } },
              contact: { select: { id: true, name: true, mobile: true } },
              staff: { select: { id: true, fullName: true } },
            },
          },
        },
        orderBy: { activity: { createdAt: 'desc' } },
      }),
      this.prisma.crmSiteVisit.count({ where }),
    ]);

    return { items, total, page: Number(page), limit: Number(limit) };
  }

  async createSiteVisit(dto: any, user?: any) {
    let staffId = dto.staffId || user?.staffId;
    if (!staffId && user?.id) {
      const staff = await this.prisma.staff.findFirst({ where: { userId: user.id } });
      if (staff) staffId = staff.id;
    }
    if (!staffId) {
      const anyStaff = await this.prisma.staff.findFirst();
      if (anyStaff) staffId = anyStaff.id;
    }

    return this.prisma.$transaction(async (tx) => {
      const activity = await tx.crmActivity.create({
        data: {
          activityType: 'SITE_VISIT',
          customerId: dto.customerId || null,
          contactId: dto.contactId || null,
          opportunityId: dto.opportunityId || null,
          staffId: staffId!,
          subject: dto.subject || `Site Inspection at ${dto.location || 'Customer Facility'}`,
          description: dto.inspectionNotes || dto.siteCondition,
          outcome: 'COMPLETED',
        },
      });

      const siteVisit = await tx.crmSiteVisit.create({
        data: {
          activityId: activity.id,
          location: dto.location || 'Customer Facility',
          siteCondition: dto.siteCondition || null,
          voltageReading: dto.voltageReading || null,
          pumpRatingHp: dto.pumpRatingHp ? Number(dto.pumpRatingHp) : null,
          panelDimensions: dto.panelDimensions || null,
          inspectionNotes: dto.inspectionNotes || null,
          photoUrls: dto.photoUrls ? JSON.stringify(dto.photoUrls) : null,
        },
        include: {
          activity: { include: { customer: true, contact: true } },
        },
      });

      return siteVisit;
    });
  }
}
