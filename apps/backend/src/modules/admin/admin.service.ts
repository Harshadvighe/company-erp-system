import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── COMPANY ────────────────────────────────────────────────────────────────

  async getCompanyProfile() {
    const company = await this.prisma.company.findFirst();
    if (!company) throw new NotFoundException('Company master not initialized');
    return company;
  }

  async updateCompanyProfile(dto: any) {
    const existing = await this.prisma.company.findFirst();
    if (!existing) {
      return this.prisma.company.create({ data: dto });
    }
    return this.prisma.company.update({ where: { id: existing.id }, data: dto });
  }

  // ─── DEPARTMENTS ────────────────────────────────────────────────────────────

  async getDepartments() {
    return this.prisma.department.findMany({
      include: { _count: { select: { users: true } } },
      orderBy: { name: 'asc' },
    });
  }

  async createDepartment(dto: { name: string; code: string }) {
    const exists = await this.prisma.department.findFirst({
      where: { OR: [{ name: dto.name }, { code: dto.code }] },
    });
    if (exists) throw new ConflictException('Department with this name or code already exists');
    return this.prisma.department.create({ data: dto });
  }

  async updateDepartment(id: string, dto: { name?: string; code?: string }) {
    const existing = await this.prisma.department.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Department not found');
    return this.prisma.department.update({ where: { id }, data: dto });
  }

  async deleteDepartment(id: string) {
    const existing = await this.prisma.department.findUnique({
      where: { id },
      include: { _count: { select: { users: true } } },
    });
    if (!existing) throw new NotFoundException('Department not found');
    if (existing._count.users > 0) {
      throw new ConflictException('Cannot delete department with active users');
    }
    return this.prisma.department.delete({ where: { id } });
  }

  // ─── FINANCIAL YEARS ────────────────────────────────────────────────────────

  async getFinancialYears() {
    return this.prisma.financialYear.findMany({ orderBy: { startDate: 'desc' } });
  }

  async createFinancialYear(dto: { name: string; startDate: string; endDate: string; isCurrent?: boolean }) {
    if (dto.isCurrent) {
      await this.prisma.financialYear.updateMany({ data: { isCurrent: false } });
    }
    return this.prisma.financialYear.create({
      data: {
        name: dto.name,
        startDate: new Date(dto.startDate),
        endDate: new Date(dto.endDate),
        isCurrent: dto.isCurrent ?? false,
      },
    });
  }

  async setCurrentFinancialYear(id: string) {
    await this.prisma.financialYear.updateMany({ data: { isCurrent: false } });
    return this.prisma.financialYear.update({ where: { id }, data: { isCurrent: true } });
  }

  // ─── TAX RATES ──────────────────────────────────────────────────────────────

  async getTaxRates() {
    return this.prisma.taxRate.findMany({ orderBy: { percentage: 'asc' } });
  }

  async createTaxRate(dto: { name: string; percentage: number; cgst: number; sgst: number; igst: number }) {
    return this.prisma.taxRate.create({ data: dto });
  }

  async updateTaxRate(id: string, dto: any) {
    return this.prisma.taxRate.update({ where: { id }, data: dto });
  }

  // ─── PAYMENT MODES ──────────────────────────────────────────────────────────

  async getPaymentModes() {
    return this.prisma.paymentMode.findMany({ orderBy: { name: 'asc' } });
  }

  async createPaymentMode(dto: { name: string; code: string }) {
    const exists = await this.prisma.paymentMode.findFirst({
      where: { OR: [{ name: dto.name }, { code: dto.code }] },
    });
    if (exists) throw new ConflictException('Payment mode already exists');
    return this.prisma.paymentMode.create({ data: dto });
  }

  // ─── USERS ──────────────────────────────────────────────────────────────────

  async getUsers(query?: { search?: string; status?: string }) {
    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.search) {
      where.OR = [
        { fullName: { contains: query.search } },
        { email: { contains: query.search } },
        { username: { contains: query.search } },
      ];
    }
    return this.prisma.user.findMany({
      where,
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true,
        phone: true,
        designation: true,
        status: true,
        createdAt: true,
        department: { select: { name: true, code: true } },
        userRoles: { select: { role: { select: { name: true, code: true } } } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createUser(dto: {
    username: string;
    email: string;
    password: string;
    fullName: string;
    phone?: string;
    designation?: string;
    departmentId?: string;
    roleIds?: string[];
  }) {
    const existingEmail = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existingEmail) throw new ConflictException('Email already in use');
    const existingUsername = await this.prisma.user.findUnique({ where: { username: dto.username } });
    if (existingUsername) throw new ConflictException('Username already in use');

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        username: dto.username,
        email: dto.email,
        passwordHash,
        fullName: dto.fullName,
        phone: dto.phone,
        designation: dto.designation,
        departmentId: dto.departmentId,
        status: 'ACTIVE',
      },
    });

    if (dto.roleIds?.length) {
      await this.prisma.userRole.createMany({
        data: dto.roleIds.map((roleId) => ({ userId: user.id, roleId })),
      });
    }

    return this.prisma.user.findUnique({
      where: { id: user.id },
      select: {
        id: true, username: true, email: true, fullName: true,
        phone: true, designation: true, status: true, createdAt: true,
        department: { select: { name: true } },
        userRoles: { select: { role: { select: { name: true, code: true } } } },
      },
    });
  }

  async updateUser(id: string, dto: any) {
    const existing = await this.prisma.user.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('User not found');

    const updateData: any = {};
    if (dto.fullName) updateData.fullName = dto.fullName;
    if (dto.phone !== undefined) updateData.phone = dto.phone;
    if (dto.designation !== undefined) updateData.designation = dto.designation;
    if (dto.departmentId !== undefined) updateData.departmentId = dto.departmentId;
    if (dto.status) updateData.status = dto.status;
    if (dto.password) updateData.passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.update({ where: { id }, data: updateData });

    if (dto.roleIds !== undefined) {
      await this.prisma.userRole.deleteMany({ where: { userId: id } });
      if (dto.roleIds.length > 0) {
        await this.prisma.userRole.createMany({
          data: dto.roleIds.map((roleId: string) => ({ userId: id, roleId })),
        });
      }
    }

    return user;
  }

  async toggleUserStatus(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    const newStatus = user.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    return this.prisma.user.update({ where: { id }, data: { status: newStatus } });
  }

  // ─── ROLES & PERMISSIONS ────────────────────────────────────────────────────

  async getRoles() {
    return this.prisma.role.findMany({
      include: {
        _count: { select: { userRoles: true } },
        rolePermissions: { include: { permission: true } },
      },
      orderBy: { name: 'asc' },
    });
  }

  async createRole(dto: { name: string; code: string; description?: string; permissionIds?: string[] }) {
    const exists = await this.prisma.role.findFirst({
      where: { OR: [{ name: dto.name }, { code: dto.code }] },
    });
    if (exists) throw new ConflictException('Role with this name or code already exists');

    const role = await this.prisma.role.create({
      data: { name: dto.name, code: dto.code, description: dto.description },
    });

    if (dto.permissionIds?.length) {
      await this.prisma.rolePermission.createMany({
        data: dto.permissionIds.map((permissionId) => ({ roleId: role.id, permissionId })),
      });
    }

    return this.prisma.role.findUnique({
      where: { id: role.id },
      include: { rolePermissions: { include: { permission: true } } },
    });
  }

  async updateRolePermissions(roleId: string, permissionIds: string[]) {
    const role = await this.prisma.role.findUnique({ where: { id: roleId } });
    if (!role) throw new NotFoundException('Role not found');
    if (role.isSystem) throw new ConflictException('Cannot modify system role permissions');

    await this.prisma.rolePermission.deleteMany({ where: { roleId } });
    if (permissionIds.length > 0) {
      await this.prisma.rolePermission.createMany({
        data: permissionIds.map((permissionId) => ({ roleId, permissionId })),
      });
    }

    return this.prisma.role.findUnique({
      where: { id: roleId },
      include: { rolePermissions: { include: { permission: true } } },
    });
  }

  async getPermissions() {
    return this.prisma.permission.findMany({ orderBy: [{ module: 'asc' }, { action: 'asc' }] });
  }
}
