import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Injectable()
export class VendorsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async findAll(query?: {
    search?: string;
    status?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Number(query?.page) || 1;
    const limit = Number(query?.limit) || 25;
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.search) {
      where.OR = [
        { companyName: { contains: query.search } },
        { vendorCode: { contains: query.search } },
        { gstin: { contains: query.search } },
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
      }),
      this.prisma.vendor.count({ where }),
    ]);

    return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  }

  async findOne(id: string) {
    const vendor = await this.prisma.vendor.findUnique({ where: { id } });
    if (!vendor) throw new NotFoundException(`Vendor ${id} not found`);
    return vendor;
  }

  async create(dto: any, userId?: string, userEmail?: string) {
    if (dto.gstin) {
      const exists = await this.prisma.vendor.findFirst({ where: { gstin: dto.gstin } });
      if (exists) throw new ConflictException(`Vendor with GSTIN ${dto.gstin} already exists`);
    }

    const count = await this.prisma.vendor.count();
    const year = new Date().getFullYear();
    const vendorCode = `VEN-${year}-${String(count + 1).padStart(5, '0')}`;

    const vendor = await this.prisma.vendor.create({
      data: {
        vendorCode,
        companyName: dto.companyName,
        gstin: dto.gstin,
        pan: dto.pan,
        contactPerson: dto.contactPerson,
        email: dto.email,
        phone: dto.phone,
        address: dto.address,
        city: dto.city,
        state: dto.state,
        productsSupplied: dto.productsSupplied,
        paymentTerms: dto.paymentTerms || 'NET_30',
        creditLimit: Number(dto.creditLimit || 0),
        rating: Number(dto.rating || 5.0),
        status: 'ACTIVE',
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
      'companyName', 'gstin', 'pan', 'contactPerson', 'email',
      'phone', 'address', 'city', 'state', 'productsSupplied',
      'paymentTerms', 'creditLimit', 'rating', 'status',
    ];
    const updateData: any = {};
    fields.forEach((f) => { if (dto[f] !== undefined) updateData[f] = dto[f]; });

    const vendor = await this.prisma.vendor.update({ where: { id }, data: updateData });

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
