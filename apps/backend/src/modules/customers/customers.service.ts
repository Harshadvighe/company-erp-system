import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import { SequenceService } from '../../core/database/sequence.service';

@Injectable()
export class CustomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly sequenceService: SequenceService,
  ) {}

  async findAll(query?: {
    search?: string;
    type?: string;
    category?: string;
    status?: string;
    page?: number;
    limit?: number;
    productSystemIds?: string;
    valuation?: string;
    activity?: string;
    nextMeetingEnabled?: string;
    meetingFrom?: string;
    meetingTo?: string;
    enquiry?: string;
    enquiryType?: string;
    website?: string;
    state?: string;
    district?: string;
    ratingAbove?: string;
    distributor?: string;
    dealer?: string;
    sortBy?: string;
  }) {
    const page = Math.max(1, Number(query?.page) || 1);
    const limit = Math.max(1, Math.min(100, Number(query?.limit) || 25));
    const skip = (page - 1) * limit;
    const conditions: Prisma.CustomerWhereInput[] = [
      { status: query?.status || { not: 'DELETED' } },
    ];
    if (query?.type) conditions.push({ customerType: query.type });
    if (query?.category) conditions.push({ customerCategory: query.category });

    if (query?.search?.trim()) {
      const search = query.search.trim();
      conditions.push({
        OR: [
          { companyName: { contains: search } },
          { customerCode: { contains: search } },
          { gstin: { contains: search } },
          { contactPerson: { contains: search } },
          { email: { contains: search } },
          { phone: { contains: search } },
          { city: { contains: search } },
          { state: { contains: search } },
        ],
      });
    }

    const productSystemIds = query?.productSystemIds
      ?.split(',')
      .map((id) => id.trim())
      .filter(Boolean);
    if (productSystemIds?.length) {
      conditions.push({
        productInterests: { some: { productSystemId: { in: productSystemIds } } },
      });
    }

    if (query?.valuation) {
      const valuationRanges: Record<string, Prisma.CustomerValuationWhereInput> = {
        HIGH: { valuablePercentage: { gte: 70 } },
        MEDIUM: { valuablePercentage: { gte: 40, lt: 70 } },
        LOW: { valuablePercentage: { lt: 40 } },
      };
      const range = valuationRanges[query.valuation.toUpperCase()];
      if (!range) throw new BadRequestException('Invalid company valuation category');
      conditions.push({ valuations: { is: range } });
    }

    const now = new Date();
    if (query?.activity === 'ACTIVE') {
      const recentDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      conditions.push({
        OR: [
          { activities: { some: { createdAt: { gte: recentDate } } } },
          { interactions: { some: { interactionDate: { gte: recentDate } } } },
        ],
      });
    } else if (query?.activity === 'NO_ACTIVITY') {
      conditions.push({ activities: { none: {} }, interactions: { none: {} } });
    } else if (query?.activity === 'FOLLOW_UP_OVERDUE') {
      conditions.push({
        followUps: { some: { status: 'PENDING', scheduledDate: { lt: now } } },
      });
    } else if (query?.activity === 'FOLLOW_UP_DUE') {
      conditions.push({
        followUps: { some: { status: 'PENDING', scheduledDate: { gte: now } } },
      });
    } else if (query?.activity && query.activity !== 'ALL') {
      throw new BadRequestException('Invalid activity filter');
    }

    if (query?.nextMeetingEnabled === 'true') {
      if (!query.meetingFrom || !query.meetingTo) {
        throw new BadRequestException('Both meetingFrom and meetingTo are required');
      }
      const from = new Date(query.meetingFrom);
      const to = new Date(query.meetingTo);
      if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime()) || from > to) {
        throw new BadRequestException('Invalid next meeting date range');
      }
      to.setHours(23, 59, 59, 999);
      conditions.push({
        activities: {
          some: {
            activityType: 'MEETING',
            meeting: { is: { startTime: { gte: from, lte: to } } },
          },
        },
      });
    }

    if (query?.enquiry === 'YES') conditions.push({ enquiries: { some: {} } });
    if (query?.enquiry === 'NO') conditions.push({ enquiries: { none: {} } });
    if (query?.enquiryType?.trim()) {
      conditions.push({
        enquiries: { some: { productInterest: { contains: query.enquiryType.trim() } } },
      });
    }
    if (query?.website === 'AVAILABLE') {
      conditions.push({ website: { not: null }, NOT: { website: '' } });
    } else if (query?.website === 'NOT_AVAILABLE') {
      conditions.push({ OR: [{ website: null }, { website: '' }] });
    }
    if (query?.state) conditions.push({ state: query.state });
    if (query?.district) conditions.push({ district: query.district });

    if (query?.ratingAbove !== undefined && query.ratingAbove !== '') {
      const rating = Number(query.ratingAbove);
      if (!Number.isFinite(rating)) throw new BadRequestException('Rating threshold must be numeric');
      conditions.push({ customerRating: { gt: rating } });
    }
    if (query?.distributor === 'YES') {
      conditions.push({
        OR: [
          { customerType: 'DISTRIBUTOR' },
          { valuations: { is: { isDistributor: true } } },
        ],
      });
    } else if (query?.distributor === 'NO') {
      conditions.push({
        AND: [
          { customerType: { not: 'DISTRIBUTOR' } },
          { OR: [{ valuations: { is: { isDistributor: false } } }, { valuations: null }] },
        ],
      });
    }
    if (query?.dealer === 'YES') {
      conditions.push({
        OR: [{ customerType: 'DEALER' }, { valuations: { is: { isDealer: true } } }],
      });
    } else if (query?.dealer === 'NO') {
      conditions.push({
        AND: [
          { customerType: { not: 'DEALER' } },
          { OR: [{ valuations: { is: { isDealer: false } } }, { valuations: null }] },
        ],
      });
    }

    const where: Prisma.CustomerWhereInput = { AND: conditions };
    const sortBy = query?.sortBy || 'RECENTLY_ADDED';
    const computedSorts = [
      'LAST_CONTACTED',
      'NEXT_MEETING',
      'NEXT_FOLLOW_UP',
      'MOST_ACTIVITIES',
      'LEAST_ACTIVITIES',
    ];
    let orderBy: Prisma.CustomerOrderByWithRelationInput | undefined;
    switch (sortBy) {
      case 'COMPANY_NAME_AZ':
        orderBy = { companyName: 'asc' };
        break;
      case 'COMPANY_NAME_ZA':
        orderBy = { companyName: 'desc' };
        break;
      case 'RECENTLY_ADDED':
        orderBy = { createdAt: 'desc' };
        break;
      case 'OLDEST_ADDED':
        orderBy = { createdAt: 'asc' };
        break;
      case 'RECENTLY_UPDATED':
        orderBy = { updatedAt: 'desc' };
        break;
      case 'HIGHEST_RATING':
        orderBy = { customerRating: 'desc' };
        break;
      case 'LOWEST_RATING':
        orderBy = { customerRating: 'asc' };
        break;
      case 'HIGHEST_VALUATION':
        orderBy = { valuations: { valuablePercentage: 'desc' } };
        break;
      case 'LOWEST_VALUATION':
        orderBy = { valuations: { valuablePercentage: 'asc' } };
        break;
      case 'MOST_ACTIVITIES':
        orderBy = { activities: { _count: 'desc' } };
        break;
      case 'LEAST_ACTIVITIES':
        orderBy = { activities: { _count: 'asc' } };
        break;
    }
    if (!orderBy && !computedSorts.includes(sortBy)) {
      throw new BadRequestException('Invalid company sort option');
    }

    const [total, systemTotal] = await Promise.all([
      this.prisma.customer.count({ where }),
      this.prisma.customer.count({ where: { status: { not: 'DELETED' } } }),
    ]);
    const include: Prisma.CustomerInclude = {
      contacts: { where: { isPrimary: true }, take: 1 },
      productInterests: { include: { productSystem: true } },
      valuations: true,
      assignedStaff: { select: { id: true, fullName: true, email: true, employeeId: true } },
      createdByUser: { select: { id: true, fullName: true, email: true } },
      updatedByUser: { select: { id: true, fullName: true, email: true } },
      _count: { select: { interactions: true, activities: true, enquiries: true, leads: true, panelSpecs: true, followUps: true } },
    };

    let data: Awaited<ReturnType<typeof this.prisma.customer.findMany>>;
    if (computedSorts.includes(sortBy)) {
      const candidates = await this.prisma.customer.findMany({
        where,
        select: { id: true, companyName: true },
      });
      const ids = candidates.map(({ id }) => id);
      const dateByCustomer = new Map<string, Date>();
      const countByCustomer = new Map<string, number>();
      const recordDate = (customerId: string, date: Date, direction: 'latest' | 'earliest') => {
        const previous = dateByCustomer.get(customerId);
        if (!previous || (direction === 'latest' ? date > previous : date < previous)) {
          dateByCustomer.set(customerId, date);
        }
      };

      if (ids.length > 0 && (sortBy === 'MOST_ACTIVITIES' || sortBy === 'LEAST_ACTIVITIES')) {
        const [activities, interactions] = await Promise.all([
          this.prisma.crmActivity.groupBy({
            by: ['customerId'],
            where: { customerId: { in: ids } },
            _count: { _all: true },
          }),
          this.prisma.customerInteraction.groupBy({
            by: ['customerId'],
            where: { customerId: { in: ids } },
            _count: { _all: true },
          }),
        ]);
        activities.forEach(({ customerId, _count }) => {
          if (customerId) countByCustomer.set(customerId, _count._all);
        });
        interactions.forEach(({ customerId, _count }) => {
          countByCustomer.set(
            customerId,
            (countByCustomer.get(customerId) || 0) + _count._all,
          );
        });
      } else if (ids.length > 0 && sortBy === 'LAST_CONTACTED') {
        const [activities, interactions] = await Promise.all([
          this.prisma.crmActivity.findMany({
            where: { customerId: { in: ids } },
            select: { customerId: true, createdAt: true },
          }),
          this.prisma.customerInteraction.findMany({
            where: { customerId: { in: ids } },
            select: { customerId: true, interactionDate: true },
          }),
        ]);
        activities.forEach((activity) => {
          if (activity.customerId) recordDate(activity.customerId, activity.createdAt, 'latest');
        });
        interactions.forEach((interaction) =>
          recordDate(interaction.customerId, interaction.interactionDate, 'latest'),
        );
      } else if (ids.length > 0 && sortBy === 'NEXT_MEETING') {
        const meetings = await this.prisma.crmActivity.findMany({
          where: {
            customerId: { in: ids },
            activityType: 'MEETING',
            meeting: { is: { startTime: { gte: now } } },
          },
          select: { customerId: true, meeting: { select: { startTime: true } } },
        });
        meetings.forEach((activity) => {
          if (activity.customerId && activity.meeting) {
            recordDate(activity.customerId, activity.meeting.startTime, 'earliest');
          }
        });
      } else if (ids.length > 0) {
        const followUps = await this.prisma.crmFollowUp.findMany({
          where: {
            customerId: { in: ids },
            status: 'PENDING',
            scheduledDate: { gte: now },
          },
          select: { customerId: true, scheduledDate: true },
        });
        followUps.forEach((followUp) => {
          if (followUp.customerId && followUp.scheduledDate) {
            recordDate(followUp.customerId, followUp.scheduledDate, 'earliest');
          }
        });
      }

      const descending =
        sortBy === 'LAST_CONTACTED' || sortBy === 'MOST_ACTIVITIES';
      candidates.sort((a, b) => {
        if (sortBy === 'MOST_ACTIVITIES' || sortBy === 'LEAST_ACTIVITIES') {
          const difference =
            (countByCustomer.get(a.id) || 0) - (countByCustomer.get(b.id) || 0);
          return (sortBy === 'MOST_ACTIVITIES' ? -difference : difference) ||
            a.companyName.localeCompare(b.companyName);
        }
        const aDate = dateByCustomer.get(a.id);
        const bDate = dateByCustomer.get(b.id);
        if (!aDate && !bDate) return a.companyName.localeCompare(b.companyName);
        if (!aDate) return 1;
        if (!bDate) return -1;
        const difference = aDate.getTime() - bDate.getTime();
        return (descending ? -difference : difference) || a.companyName.localeCompare(b.companyName);
      });
      const pageIds = candidates.slice(skip, skip + limit).map(({ id }) => id);
      const pageData = pageIds.length
        ? await this.prisma.customer.findMany({ where: { id: { in: pageIds } }, include })
        : [];
      const recordsById = new Map(pageData.map((customer) => [customer.id, customer]));
      data = pageIds.map((id) => recordsById.get(id)!).filter(Boolean);
    } else {
      data = await this.prisma.customer.findMany({
        where,
        skip,
        take: limit,
        orderBy,
        include,
      });
    }

    return {
      data,
      meta: {
        page,
        limit,
        total,
        systemTotal,
        totalPages: Math.max(1, Math.ceil(total / limit)),
      },
    };
  }

  async getCompanyFilterOptions(state?: string) {
    const stateWhere: Prisma.CustomerWhereInput = { status: { not: 'DELETED' } };
    const districtWhere: Prisma.CustomerWhereInput = {
      status: { not: 'DELETED' },
      ...(state ? { state } : {}),
    };
    const [states, districts, productSystems, enquiryTypes] = await Promise.all([
      this.prisma.customer.findMany({
        where: stateWhere,
        distinct: ['state'],
        select: { state: true },
        orderBy: { state: 'asc' },
      }),
      this.prisma.customer.findMany({
        where: districtWhere,
        distinct: ['district'],
        select: { district: true },
        orderBy: { district: 'asc' },
      }),
      this.prisma.productSystem.findMany({
        where: { isActive: true },
        select: { id: true, name: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.enquiry.findMany({
        distinct: ['productInterest'],
        select: { productInterest: true },
        orderBy: { productInterest: 'asc' },
      }),
    ]);
    return {
      states: states.map(({ state: stateName }) => stateName).filter(Boolean),
      districts: districts.map(({ district }) => district).filter(Boolean),
      productSystems,
      enquiryTypes: enquiryTypes.map(({ productInterest }) => productInterest).filter(Boolean),
    };
  }

  async findOne(id: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        contacts: { orderBy: { isPrimary: 'desc' } },
        interactions: { orderBy: { interactionDate: 'desc' }, take: 50 },
        valuations: true,
        assignedStaff: { select: { id: true, fullName: true, email: true, employeeId: true, mobile: true } },
        createdByUser: { select: { id: true, fullName: true, email: true } },
        updatedByUser: { select: { id: true, fullName: true, email: true } },
        productInterests: { include: { productSystem: true } },
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

    const customer = await this.prisma.$transaction((tx) =>
      this.createInTransaction(tx, dto, userId),
    );

    if (dto.productSystemIds && Array.isArray(dto.productSystemIds)) {
      for (const sysId of dto.productSystemIds) {
        try {
          await this.prisma.companyProductInterest.create({
            data: { customerId: customer.id, productSystemId: sysId },
          });
        } catch (_) {}
      }
    }

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

  async createInTransaction(
    tx: Prisma.TransactionClient,
    dto: any,
    userId?: string,
  ) {
    const customerCode = await this.sequenceService.nextCustomerCode();

    let assignedStaffId = dto.assignedStaffId;
    let ownerName = dto.ownerName;
    if (!assignedStaffId && userId) {
      const userStaff = await this.prisma.staff.findFirst({ where: { userId } });
      if (userStaff) {
        assignedStaffId = userStaff.id;
        if (!ownerName) ownerName = userStaff.fullName;
      }
    }

    const customer = await tx.customer.create({
      data: {
        customerCode,
        companyName: dto.companyName,
        legalName: dto.legalName || dto.companyName,
        tradeName: dto.tradeName,
        gstin: dto.gstin,
        pan: dto.pan,
        customerType: dto.customerType || 'END_CUSTOMER',
        customerCategory: dto.customerCategory || 'STANDARD',
        customerSegment: dto.customerSegment ?? 'VFD_PANEL',
        contactPerson: dto.contactPerson,
        designation: dto.designation,
        email:
          dto.source === 'EXCEL_IMPORT'
            ? dto.email ?? ''
            : dto.email,
        phone: dto.phone,
        alternatePhone: dto.alternatePhone,
        website: dto.website,
        address: dto.address,
        country: dto.country || 'India',
        state: dto.state,
        district: dto.district,
        city: dto.city,
        pincode: dto.pincode,
        ownerName: ownerName,
        assignedStaffId: assignedStaffId,
        createdByUserId: userId,
        updatedByUserId: userId,
        gstStatus: dto.gstStatus || (dto.gstin ? 'GST_REGISTERED' : 'NO_GST'),
        noGstReason: dto.noGstReason,
        gstVerified: dto.gstVerified === true || Boolean(dto.gstVerificationToken),
        gstVerifiedAt: dto.gstVerifiedAt || null,
        gstProviderRef: dto.gstProviderRef,
        companyType: dto.companyType,
        staffCount: Number(dto.staffCount || dto.numEmployees || 0),
        numEmployees: Number(dto.numEmployees || dto.staffCount || 0),
        turnover: dto.turnover,
        industry: dto.industry,
        creditLimit: Number(dto.creditLimit || 0),
        paymentTerms: dto.paymentTerms || 'NET_30',
        source: dto.source || 'DIRECT',
        status: 'ACTIVE',
      },
    });

    // Auto-create primary contact from master contact data
    await tx.customerContact.create({
      data: {
        customerId: customer.id,
        name: dto.contactPerson,
        designation: dto.designation,
        mobile: dto.phone,
        email: dto.email,
        whatsapp: dto.whatsapp || dto.phone,
        isPrimary: true,
      },
    });

    // Initialize valuation record
    await tx.customerValuation.create({
      data: {
        customerId: customer.id,
        isDealer: dto.customerType === 'DEALER',
        isDistributor: dto.customerType === 'DISTRIBUTOR',
        ratingScore: 5.0,
        valuablePercentage: 50.0,
        activityCount: 0,
      },
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

    const updatable: any = { updatedByUserId: userId };
    const fields = [
      'companyName', 'legalName', 'tradeName', 'gstin', 'pan', 'customerType', 'customerCategory',
      'customerSegment', 'contactPerson', 'designation', 'email', 'phone', 'alternatePhone',
      'website', 'address', 'country', 'state', 'district', 'city',
      'pincode', 'ownerName', 'assignedStaffId', 'staffCount', 'numEmployees', 'turnover', 'industry',
      'source', 'customerRating', 'gstStatus', 'noGstReason', 'status',
    ];
    fields.forEach((f) => { if (dto[f] !== undefined) updatable[f] = dto[f]; });

    const customer = await this.prisma.customer.update({
      where: { id },
      data: updatable,
      include: {
        assignedStaff: { select: { id: true, fullName: true, email: true } },
        createdByUser: { select: { id: true, fullName: true, email: true } },
        updatedByUser: { select: { id: true, fullName: true, email: true } },
      },
    });

    if (dto.productSystemIds && Array.isArray(dto.productSystemIds)) {
      await this.prisma.companyProductInterest.deleteMany({ where: { customerId: id } });
      for (const sysId of dto.productSystemIds) {
        try {
          await this.prisma.companyProductInterest.create({
            data: { customerId: id, productSystemId: sysId },
          });
        } catch (_) {}
      }
    }

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

    const documentIds = [
      dto.attachmentDocumentId,
      dto.audioDocumentId,
      dto.photoDocumentId,
    ].filter((id): id is string => typeof id === 'string' && id.length > 0);
    const uniqueDocumentIds = [...new Set(documentIds)];

    return this.prisma.$transaction(async (tx) => {
      const interaction = await tx.customerInteraction.create({
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
          photoUrl: dto.photoUrl,
          recordedBy,
        },
      });

      if (uniqueDocumentIds.length > 0) {
        const linkedDocuments = await tx.documentItem.updateMany({
          where: {
            id: { in: uniqueDocumentIds },
            entityType: 'CUSTOMER_INTERACTION_PENDING',
            entityId: customerId,
          },
          data: {
            entityType: 'CUSTOMER_INTERACTION',
            entityId: interaction.id,
          },
        });
        if (linkedDocuments.count !== uniqueDocumentIds.length) {
          throw new BadRequestException('One or more uploaded files do not belong to this customer interaction');
        }
      }

      await tx.customerValuation.updateMany({
        where: { customerId },
        data: { activityCount: { increment: 1 } },
      });

      return interaction;
    });
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

  // ─── DUPLICATE DETECTION ──────────────────────────────────────────────────
  async checkDuplicate(dto: { gstin?: string; phone?: string; email?: string; companyName?: string }) {
    const orConditions: any[] = [];

    if (dto.gstin && dto.gstin.trim().length > 3) {
      orConditions.push({ gstin: dto.gstin.trim() });
    }
    if (dto.phone && dto.phone.trim().length > 5) {
      orConditions.push({ phone: dto.phone.trim() });
    }
    if (dto.email && dto.email.trim().length > 5) {
      orConditions.push({ email: dto.email.trim() });
    }
    if (dto.companyName && dto.companyName.trim().length > 2) {
      orConditions.push({ companyName: { contains: dto.companyName.trim() } });
    }

    if (orConditions.length === 0) {
      return { hasDuplicate: false, matches: [] };
    }

    const matches = await this.prisma.customer.findMany({
      where: { OR: orConditions, status: { not: 'DELETED' } },
      select: {
        id: true,
        companyName: true,
        customerCode: true,
        gstin: true,
        phone: true,
        email: true,
        city: true,
      },
      take: 5,
    });

    return {
      hasDuplicate: matches.length > 0,
      matches,
    };
  }

  // ─── CUSTOMER 360 CHRONOLOGICAL TIMELINE ──────────────────────────────────
  async getTimeline(customerId: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id: customerId },
      include: {
        interactions: { include: { contact: true } },
        activities: { include: { staff: true, call: true, meeting: true, siteVisit: true } },
        opportunities: { select: { id: true, title: true, stage: true, estimatedValue: true, createdAt: true, updatedAt: true } },
        leads: { select: { id: true, leadNumber: true, status: true, source: true, createdAt: true } },
        enquiries: { select: { id: true, enquiryNumber: true, productInterest: true, status: true, createdAt: true } },
      },
    });

    if (!customer) throw new NotFoundException('Customer not found');

    const interactionDocuments = customer.interactions.length
      ? await this.prisma.documentItem.findMany({
          where: {
            entityType: 'CUSTOMER_INTERACTION',
            entityId: { in: customer.interactions.map((interaction) => interaction.id) },
          },
          select: {
            entityId: true,
            fileName: true,
            documentType: true,
            mimeType: true,
            storagePath: true,
          },
        })
      : [];
    const unlinkedInteractionDocuments = await this.prisma.documentItem.findMany({
      where: {
        entityType: 'CUSTOMER_INTERACTION_PENDING',
        entityId: customerId,
      },
      select: {
        id: true,
        fileName: true,
        documentType: true,
        mimeType: true,
        storagePath: true,
        uploadedBy: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
    const documentsByInteraction = new Map<string, typeof interactionDocuments>();
    for (const document of interactionDocuments) {
      const documents = documentsByInteraction.get(document.entityId) || [];
      documents.push(document);
      documentsByInteraction.set(document.entityId, documents);
    }

    const timelineEvents: Array<{
      id: string;
      type: string;
      title: string;
      description?: string;
      actor: string;
      timestamp: Date;
      metadata?: any;
    }> = [];

    // 1. Interactions
    customer.interactions.forEach((i) => {
      const interactionMedia = [
        { type: 'DOCUMENT', title: 'Document', url: i.attachmentUrl },
        { type: 'AUDIO', title: 'Audio recording', url: i.audioUrl },
        { type: 'PHOTO', title: 'Photo', url: i.photoUrl },
      ].filter((item) => item.url);
      const uploadedMedia = (documentsByInteraction.get(i.id) || []).map((document) => {
        const documentType = document.documentType.toUpperCase();
        const type =
          documentType === 'PHOTO' || document.mimeType.startsWith('image/')
            ? 'PHOTO'
            : documentType === 'AUDIO' || document.mimeType.startsWith('audio/')
              ? 'AUDIO'
              : 'DOCUMENT';
        const storagePath = document.storagePath.replace(/\\/g, '/');
        const url = `/api/v1/documents/files/${storagePath
          .split('/')
          .map(encodeURIComponent)
          .join('/')}`;
        return { type, title: document.fileName, url };
      });
      const media = [
        ...interactionMedia,
        ...uploadedMedia.filter(
          (uploaded) => !interactionMedia.some((item) => item.url === uploaded.url),
        ),
      ];

      timelineEvents.push({
        id: i.id,
        type: i.interactionType || 'INTERACTION',
        title: `${i.interactionType || 'Interaction'}: ${i.subject}`,
        description: i.description,
        actor: i.recordedBy || 'Sales Executive',
        timestamp: i.interactionDate,
        metadata: {
          outcome: i.outcome,
          nextFollowUp: i.nextFollowUp,
          media,
        },
      });
    });

    // 2. CRM Activities (Calls, Meetings, Site Visits)
    customer.activities.forEach((a) => {
      let desc = a.description || '';
      if (a.call) {
        desc = `Call Outcome: ${a.call.callOutcome} (${Math.round(a.call.durationSec / 60)} mins) — ${desc}`;
      } else if (a.meeting) {
        desc = `Meeting: ${a.meeting.meetingType} at ${a.meeting.location || 'Client Office'} — ${desc}`;
      } else if (a.siteVisit) {
        desc = `Site Inspection: ${a.siteVisit.location} (Voltage: ${a.siteVisit.voltageReading || 'N/A'}, HP: ${a.siteVisit.pumpRatingHp || 'N/A'}) — ${desc}`;
      }

      timelineEvents.push({
        id: a.id,
        type: a.activityType,
        title: a.subject,
        description: desc,
        actor: a.staff?.fullName || 'Staff',
        timestamp: a.createdAt,
        metadata: { outcome: a.outcome, nextActionDate: a.nextActionDate },
      });
    });

    // 3. Opportunities
    customer.opportunities.forEach((o) => {
      timelineEvents.push({
        id: o.id,
        type: 'OPPORTUNITY',
        title: `Opportunity: ${o.title} (₹${(o.estimatedValue || 0).toLocaleString()})`,
        description: `Stage: ${o.stage}`,
        actor: 'Sales Pipeline',
        timestamp: o.updatedAt,
      });
    });

    // 4. Enquiries
    customer.enquiries.forEach((e) => {
      timelineEvents.push({
        id: e.id,
        type: 'ENQUIRY',
        title: `Enquiry ${e.enquiryNumber}: ${e.productInterest}`,
        description: `Status: ${e.status}`,
        actor: 'Customer Inquiry',
        timestamp: e.createdAt,
      });
    });

    // Older clients may have uploaded these files before unwrapping the upload response
    // and therefore never sent the document IDs when recording the interaction.
    unlinkedInteractionDocuments.forEach((document) => {
      const documentType = document.documentType.toUpperCase();
      const type =
        documentType === 'PHOTO' || document.mimeType.startsWith('image/')
          ? 'PHOTO'
          : documentType === 'AUDIO' || document.mimeType.startsWith('audio/')
            ? 'AUDIO'
            : 'DOCUMENT';
      const storagePath = document.storagePath.replace(/\\/g, '/');
      const url = `/api/v1/documents/files/${storagePath
        .split('/')
        .map(encodeURIComponent)
        .join('/')}`;

      timelineEvents.push({
        id: document.id,
        type: 'ATTACHMENT',
        title: `Interaction upload: ${document.fileName}`,
        description: 'Uploaded from Record Interaction',
        actor: document.uploadedBy || 'Staff',
        timestamp: document.createdAt,
        metadata: {
          media: [{ type, title: document.fileName, url }],
        },
      });
    });

    // Sort descending by timestamp
    timelineEvents.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

    return timelineEvents;
  }

  // ─── CUSTOMER MERGE (SUPER ADMIN ONLY) ────────────────────────────────────
  async mergeCustomers(sourceId: string, targetId: string, user?: any) {
    if (sourceId === targetId) {
      throw new BadRequestException('Source and target customer cannot be the same');
    }

    const [source, target] = await Promise.all([
      this.prisma.customer.findUnique({ where: { id: sourceId } }),
      this.prisma.customer.findUnique({ where: { id: targetId } }),
    ]);

    if (!source || !target) {
      throw new NotFoundException('Both source and target customers must exist');
    }

    return this.prisma.$transaction(async (tx) => {
      // Re-parent Contacts
      await tx.customerContact.updateMany({
        where: { customerId: sourceId },
        data: { customerId: targetId, isPrimary: false },
      });

      // Re-parent Opportunities
      await tx.opportunity.updateMany({
        where: { customerId: sourceId },
        data: { customerId: targetId },
      });

      // Re-parent Leads
      await tx.lead.updateMany({
        where: { customerId: sourceId },
        data: { customerId: targetId },
      });

      // Re-parent Enquiries
      await tx.enquiry.updateMany({
        where: { customerId: sourceId },
        data: { customerId: targetId },
      });

      // Re-parent Activities & Interactions
      await tx.crmActivity.updateMany({
        where: { customerId: sourceId },
        data: { customerId: targetId },
      });
      await tx.customerInteraction.updateMany({
        where: { customerId: sourceId },
        data: { customerId: targetId },
      });

      // Mark source as MERGED
      await tx.customer.update({
        where: { id: sourceId },
        data: { status: 'MERGED' },
      });

      await this.auditService.log({
        userId: user?.id,
        userEmail: user?.email,
        action: 'MERGE',
        module: 'CUSTOMERS',
        entityType: 'Customer',
        entityId: targetId,
        details: `Merged duplicate Customer ${source.companyName} (${source.customerCode}) into Master ${target.companyName} (${target.customerCode})`,
      });

      return {
        message: 'Customer merged successfully',
        masterCustomer: target,
      };
    });
  }
}
