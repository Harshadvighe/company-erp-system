import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Injectable()
export class CrmService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
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
        take: 5,
        orderBy: { startTime: 'desc' },
        include: {
          activity: {
            include: {
              customer: { select: { companyName: true } },
              lead: { select: { companyName: true } },
            },
          },
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
      activeCustomers,
      recentMeetings,
      meetings: recentMeetings,
    };
  }

  // ─── LEADS ────────────────────────────────────────────────────────────────
  async getLeads(query?: any, user?: any) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const scope = this.buildScopeFilter(user);
    const where: any = { ...scope };

    if (query?.status && query.status !== 'ALL') where.status = query.status;
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
        const custCount = await tx.customer.count();
        const year = new Date().getFullYear();
        const customerCode = `CUS-${year}-${String(custCount + 1).padStart(5, '0')}`;

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
        const oppCount = await tx.opportunity.count();
        const year = new Date().getFullYear();
        const opportunityNumber = `OPP-${year}-${String(oppCount + 1).padStart(5, '0')}`;

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
    const count = await this.prisma.opportunity.count();
    const year = new Date().getFullYear();
    const opportunityNumber = `OPP-${year}-${String(count + 1).padStart(5, '0')}`;
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

      await tx.crmCall.create({
        data: {
          activityId: activity.id,
          contactId: dto.contactId,
          callType: dto.callType || 'OUTBOUND',
          durationSec: Number(dto.durationSec || 0),
          callOutcome: dto.callOutcome || 'CONNECTED',
          recordingUrl: dto.recordingUrl,
        },
      });

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
    const staffId = user?.staffId || dto.staffId;
    if (!staffId) throw new BadRequestException('Valid staff identification required');

    return this.prisma.$transaction(async (tx) => {
      const activity = await tx.crmActivity.create({
        data: {
          activityType: 'MEETING',
          customerId: dto.customerId,
          contactId: dto.contactId,
          leadId: dto.leadId,
          opportunityId: dto.opportunityId,
          staffId,
          subject: dto.agenda || 'Client Meeting',
          description: dto.description,
          outcome: dto.outcome,
          nextActionDate: dto.nextFollowUpDate ? new Date(dto.nextFollowUpDate) : null,
        },
      });

      await tx.crmMeeting.create({
        data: {
          activityId: activity.id,
          meetingType: dto.meetingType || 'OFFLINE',
          location: dto.location,
          startTime: new Date(dto.startTime),
          endTime: dto.endTime ? new Date(dto.endTime) : null,
          agenda: dto.agenda,
          outcome: dto.outcome,
        },
      });

      return activity;
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

    if (query?.status && query.status !== 'ALL') where.status = query.status;

    const followUps = await this.prisma.crmFollowUp.findMany({
      where,
      include: {
        customer: { select: { id: true, companyName: true, phone: true } },
        opportunity: { select: { id: true, title: true, stage: true } },
        assignedStaff: { select: { id: true, fullName: true } },
      },
      orderBy: { scheduledDate: 'asc' },
    });

    // Mark dynamic overdue state
    const now = new Date();
    return followUps.map((f) => {
      const isOverdue = f.status === 'PENDING' && new Date(f.scheduledDate) < now;
      return { ...f, isOverdue };
    });
  }

  async completeFollowUp(id: string, notes?: string, user?: any) {
    const followUp = await this.prisma.crmFollowUp.findUnique({ where: { id } });
    if (!followUp) throw new NotFoundException('Follow-up not found');

    return this.prisma.crmFollowUp.update({
      where: { id },
      data: {
        status: 'COMPLETED',
        completedDate: new Date(),
        notes: notes ? `${followUp.notes ? followUp.notes + '\n' : ''}${notes}` : followUp.notes,
      },
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
}
