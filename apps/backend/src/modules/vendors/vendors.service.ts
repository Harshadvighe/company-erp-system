import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import { SequenceService } from '../../core/database/sequence.service';
import { GstVerificationService } from '../crm/gst-verification.service';

@Injectable()
export class VendorsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly sequenceService: SequenceService,
    private readonly gstVerificationService: GstVerificationService,
  ) {}

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
        module: 'VENDORS',
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
        module: 'VENDORS',
        entityType: 'GSTIN',
        details: `GSTIN Portal verification failed for ${maskedGstin}.`,
        ipAddress,
      });
      throw error;
    }
  }


  async findAll(query?: {
    search?: string;
    status?: string;
    category?: string;
    gstStatus?: string;
    state?: string;
    city?: string;
    approvalStatus?: string;
    addedBy?: string;
    vendorOwner?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = { status: query?.status || { not: 'DELETED' } };
    if (query?.category) where.vendorCategory = query.category;
    if (query?.approvalStatus) where.approvalStatus = query.approvalStatus;
    if (query?.state) where.state = query.state;
    if (query?.city) where.city = query.city;
    if (query?.addedBy) where.createdByUserId = query.addedBy;
    if (query?.vendorOwner) where.assignedStaffId = query.vendorOwner;
    if (query?.gstStatus === 'YES') {
      where.AND = [{ gstin: { not: null } }, { gstin: { not: '' } }];
    } else if (query?.gstStatus === 'NO') {
      where.OR = [{ gstin: null }, { gstin: '' }];
    }

    if (query?.search) {
      where.OR = [
        { companyName: { contains: query.search } },
        { legalName: { contains: query.search } },
        { vendorCode: { contains: query.search } },
        { gstin: { contains: query.search } },
        { pan: { contains: query.search } },
        { contactPerson: { contains: query.search } },
        { email: { contains: query.search } },
        { phone: { contains: query.search } },
        { city: { contains: query.search } },
        { state: { contains: query.search } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.vendor.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          assignedStaff: { select: { id: true, fullName: true, email: true, employeeId: true } },
          createdByUser: { select: { id: true, fullName: true, email: true } },
          updatedByUser: { select: { id: true, fullName: true, email: true } },
        },
      }),
      this.prisma.vendor.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async findOne(id: string) {
    const vendor = await this.prisma.vendor.findUnique({
      where: { id },
      include: {
        contacts: true,
        addresses: true,
        bankAccounts: true,
        assignedStaff: { select: { id: true, fullName: true, email: true, employeeId: true, mobile: true } },
        createdByUser: { select: { id: true, fullName: true, email: true } },
        updatedByUser: { select: { id: true, fullName: true, email: true } },
      },
    });
    if (!vendor) throw new NotFoundException(`Vendor ${id} not found`);
    return vendor;
  }

  async create(dto: any, userId?: string, userEmail?: string) {
    if (dto.gstin) {
      const exists = await this.prisma.vendor.findFirst({ where: { gstin: dto.gstin } });
      if (exists) throw new ConflictException(`Vendor with GSTIN ${dto.gstin} already exists`);
    }

    const vendorCode = await this.sequenceService.nextVendorCode();

    let assignedStaffId = dto.assignedStaffId;
    if (!assignedStaffId && userId) {
      const userStaff = await this.prisma.staff.findFirst({ where: { userId } });
      if (userStaff) assignedStaffId = userStaff.id;
    }

    const vendor = await this.prisma.vendor.create({
      data: {
        vendorCode,
        companyName: dto.companyName,
        legalName: dto.legalName || dto.companyName,
        gstin: dto.gstin,
        pan: dto.pan,
        vendorType: dto.vendorType || 'MANUFACTURER',
        vendorCategory: dto.vendorCategory || 'STANDARD',
        constitution: dto.constitution || 'PROPRIETORSHIP',
        contactPerson: dto.contactPerson,
        designation: dto.designation,
        email: dto.email,
        phone: dto.phone,
        alternatePhone: dto.alternatePhone,
        website: dto.website,
        address: dto.address,
        registeredOfficeLocation: dto.registeredOfficeLocation || dto.address,
        factoryLocation: dto.factoryLocation,
        country: dto.country || 'India',
        state: dto.state,
        district: dto.district,
        city: dto.city,
        pincode: dto.pincode,
        msmeStatus: dto.msmeStatus || 'NO',
        productsSupplied: dto.productsSupplied,
        paymentTerms: dto.paymentTerms || 'NET_30',
        creditLimit: Number(dto.creditLimit || 0),
        rating: Number(dto.rating || 5.0),
        approvalStatus: dto.approvalStatus || 'APPROVED',
        onboardingDate: dto.onboardingDate ? new Date(dto.onboardingDate) : new Date(),
        assignedStaffId,
        createdByUserId: userId,
        updatedByUserId: userId,
        status: 'ACTIVE',
      },
      include: {
        assignedStaff: { select: { id: true, fullName: true, email: true } },
        createdByUser: { select: { id: true, fullName: true, email: true } },
      },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'CREATE',
      module: 'VENDORS',
      entityType: 'Vendor',
      entityId: vendor.id,
      details: `Created Vendor: ${vendor.companyName} (${vendor.vendorCode})`,
    });

    return vendor;
  }

  async update(id: string, dto: any, userId?: string, userEmail?: string) {
    const existing = await this.prisma.vendor.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Vendor not found');

    if (dto.gstin && dto.gstin !== existing.gstin) {
      const dup = await this.prisma.vendor.findFirst({
        where: { gstin: dto.gstin, NOT: { id } },
      });
      if (dup) throw new ConflictException(`GSTIN ${dto.gstin} already in use`);
    }

    const fields = [
      'companyName', 'legalName', 'gstin', 'pan', 'vendorType', 'vendorCategory',
      'constitution', 'contactPerson', 'designation', 'email', 'phone', 'alternatePhone',
      'website', 'address', 'registeredOfficeLocation', 'factoryLocation', 'country',
      'state', 'district', 'city', 'pincode', 'msmeStatus', 'productsSupplied',
      'paymentTerms', 'creditLimit', 'rating', 'approvalStatus', 'assignedStaffId', 'status',
    ];
    const updateData: any = { updatedByUserId: userId };
    fields.forEach((f) => { if (dto[f] !== undefined) updateData[f] = dto[f]; });

    const vendor = await this.prisma.vendor.update({
      where: { id },
      data: updateData,
      include: {
        assignedStaff: { select: { id: true, fullName: true, email: true } },
        createdByUser: { select: { id: true, fullName: true, email: true } },
        updatedByUser: { select: { id: true, fullName: true, email: true } },
      },
    });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'UPDATE',
      module: 'VENDORS',
      entityType: 'Vendor',
      entityId: id,
      details: `Updated Vendor: ${vendor.companyName}`,
    });

    return vendor;
  }

  async delete(id: string, userId?: string, userEmail?: string) {
    const existing = await this.prisma.vendor.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Vendor not found');

    await this.prisma.vendor.update({ where: { id }, data: { status: 'DELETED' } });

    await this.auditService.log({
      userId,
      userEmail,
      action: 'DELETE',
      module: 'VENDORS',
      entityType: 'Vendor',
      entityId: id,
      details: `Soft-deleted Vendor: ${existing.companyName}`,
    });

    return { message: 'Vendor marked as deleted' };
  }
}
