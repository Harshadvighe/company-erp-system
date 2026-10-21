import { Injectable, NotFoundException, ConflictException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { PermissionResolverService } from '../../core/permissions/permission-resolver.service';
import { AuditService } from '../../core/audit/audit.service';
import { ApproveEmployeeRequestDto } from './dto/approve-employee-request.dto';
import { UpdateEmployeeAccessDto, PermissionOverrideEffect } from './dto/update-employee-access.dto';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private permissionResolverService?: PermissionResolverService,
    private auditService?: AuditService,
  ) {
    if (!this.permissionResolverService) {
      this.permissionResolverService = new PermissionResolverService(this.prisma);
    }
    if (!this.auditService) {
      this.auditService = new AuditService(this.prisma);
    }
  }

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
      include: {
        headStaff: { select: { id: true, fullName: true, employeeId: true } },
        _count: { select: { users: true, staff: true, teamDepartments: true } },
      },
      orderBy: { name: 'asc' },
    });
  }

  async getOrganizationStructure() {
    const departments = await this.prisma.department.findMany({
      include: {
        headStaff: { select: { id: true, fullName: true, employeeId: true } },
        staff: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            status: true,
            designation: { select: { name: true } },
          },
          orderBy: { fullName: 'asc' },
        },
        teams: {
          include: {
            leader: { select: { id: true, fullName: true, employeeId: true } },
            members: {
              include: {
                staff: { select: { id: true, fullName: true, employeeId: true } },
              },
              orderBy: { staff: { fullName: 'asc' } },
            },
            _count: { select: { tasks: true } },
          },
          orderBy: { name: 'asc' },
        },
        teamDepartments: {
          include: {
            team: {
              include: {
                department: { select: { id: true, name: true } },
                departments: {
                  include: {
                    department: { select: { id: true, name: true } },
                  },
                },
                leader: { select: { id: true, fullName: true, employeeId: true } },
                members: {
                  include: {
                    staff: {
                      select: {
                        id: true,
                        fullName: true,
                        employeeId: true,
                        departmentId: true,
                        department: { select: { id: true, name: true } },
                      },
                    },
                  },
                  orderBy: { staff: { fullName: 'asc' } },
                },
                _count: { select: { tasks: true } },
              },
            },
          },
        },
        _count: { select: { users: true, staff: true, teamDepartments: true } },
      },
      orderBy: { name: 'asc' },
    });
    return departments.map(({ teamDepartments, teams, ...department }) => {
      const teamsById = new Map<string, (typeof teams)[number]>();
      for (const team of teams) teamsById.set(team.id, team);
      for (const link of teamDepartments) {
        teamsById.set(link.team.id, link.team);
      }
      return { ...department, teams: [...teamsById.values()] };
    });
  }

  async updateDepartmentHead(id: string, staffId: string | null) {
    if (staffId !== null && typeof staffId !== 'string') {
      throw new BadRequestException('Department head must be a staff ID or null');
    }
    const department = await this.prisma.department.findUnique({ where: { id } });
    if (!department) throw new NotFoundException('Department not found');

    if (staffId) {
      const staff = await this.prisma.staff.findUnique({ where: { id: staffId } });
      if (!staff || staff.departmentId !== id) {
        throw new BadRequestException('Department head must belong to this department');
      }
      const existingHeadship = await this.prisma.department.findFirst({
        where: { headStaffId: staffId, id: { not: id } },
        select: { id: true },
      });
      if (existingHeadship) {
        throw new ConflictException('This employee is already a department head');
      }
    }
    return this.prisma.department.update({
      where: { id },
      data: { headStaffId: staffId },
      include: { headStaff: { select: { id: true, fullName: true, employeeId: true } } },
    });
  }

  async getTeams(departmentId?: string) {
    return this.prisma.team.findMany({
      where: departmentId
        ? {
            OR: [
              { departments: { some: { departmentId } } },
              { departmentId },
            ],
          }
        : undefined,
      include: {
        department: { select: { id: true, name: true } },
        departments: {
          include: { department: { select: { id: true, name: true } } },
        },
        leader: { select: { id: true, fullName: true, employeeId: true } },
        members: {
          include: {
            staff: { select: { id: true, fullName: true, employeeId: true } },
          },
          orderBy: { staff: { fullName: 'asc' } },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async createTeam(dto: {
    name: string;
    code: string;
    departmentIds?: string[];
    departmentId?: string;
    leaderStaffId?: string | null;
    memberStaffIds?: string[];
  }) {
    this.validateTeamInput(dto, true);
    if (!dto.name.trim() || !dto.code.trim()) {
      throw new BadRequestException('Team name and code are required');
    }
    const duplicate = await this.prisma.team.findFirst({
      where: {
        OR: [
          { name: { equals: dto.name.trim() } },
          { code: { equals: dto.code.trim().toUpperCase() } },
        ],
      },
      select: { id: true },
    });
    if (duplicate) throw new ConflictException('Team name or code already exists');
    const departmentIds = this.teamDepartmentIds(dto);
    const memberStaffIds = [...new Set(dto.memberStaffIds ?? [])];
    if (dto.leaderStaffId && !memberStaffIds.includes(dto.leaderStaffId)) {
      memberStaffIds.push(dto.leaderStaffId);
    }
    if (!memberStaffIds.length) {
      throw new BadRequestException('A team needs at least one member or leader');
    }
    await this.validateTeamMembers(departmentIds, memberStaffIds);

    return this.prisma.team.create({
      data: {
        name: dto.name.trim(),
        code: dto.code.trim().toUpperCase(),
        departmentId: departmentIds[0],
        leaderStaffId: dto.leaderStaffId || null,
        departments: {
          create: departmentIds.map((departmentId) => ({ departmentId })),
        },
        members: {
          create: memberStaffIds.map((staffId) => ({
            staffId,
            role: staffId === dto.leaderStaffId ? 'LEADER' : 'MEMBER',
          })),
        },
      },
      include: {
        department: { select: { id: true, name: true } },
        departments: {
          include: { department: { select: { id: true, name: true } } },
        },
        leader: { select: { id: true, fullName: true, employeeId: true } },
        members: {
          include: { staff: { select: { id: true, fullName: true, employeeId: true } } },
        },
      },
    });
  }

  async updateTeam(
    id: string,
    dto: {
      name?: string;
      code?: string;
      departmentIds?: string[];
      departmentId?: string;
      leaderStaffId?: string | null;
      memberStaffIds?: string[];
    },
  ) {
    this.validateTeamInput(dto, false);
    const existing = await this.prisma.team.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Team not found');
    const existingDepartments = await this.prisma.teamDepartment.findMany({
      where: { teamId: id },
      select: { departmentId: true },
    });
    const currentDepartmentIds = existingDepartments.length
      ? existingDepartments.map((row) => row.departmentId)
      : existing.departmentId
        ? [existing.departmentId]
        : [];
    const departmentIds = this.teamDepartmentIds(dto, currentDepartmentIds);
    if (!departmentIds.length) {
      throw new BadRequestException('Select at least one department for the team');
    }
    const name = dto.name?.trim() ?? existing.name;
    const code = dto.code?.trim().toUpperCase() ?? existing.code;
    if (!name || !code) throw new BadRequestException('Team name and code are required');
    const duplicate = await this.prisma.team.findFirst({
      where: {
        id: { not: id },
        OR: [{ name: { equals: name } }, { code: { equals: code } }],
      },
      select: { id: true },
    });
    if (duplicate) throw new ConflictException('Team name or code already exists');
    const leaderStaffId =
      dto.leaderStaffId === undefined ? existing.leaderStaffId : dto.leaderStaffId;
    const memberStaffIds = [
      ...new Set(dto.memberStaffIds ?? (await this.prisma.teamMember
        .findMany({ where: { teamId: id }, select: { staffId: true } })
        .then((rows) => rows.map((row) => row.staffId)))),
    ];
    if (leaderStaffId && !memberStaffIds.includes(leaderStaffId)) {
      memberStaffIds.push(leaderStaffId);
    }
    if (!memberStaffIds.length) {
      throw new BadRequestException('A team needs at least one member or leader');
    }
    await this.validateTeamMembers(departmentIds, memberStaffIds);

    return this.prisma.$transaction(async (tx) => {
      if (
        dto.departmentIds !== undefined ||
        dto.departmentId !== undefined
      ) {
        await tx.teamDepartment.deleteMany({ where: { teamId: id } });
        await tx.teamDepartment.createMany({
          data: departmentIds.map((departmentId) => ({
            teamId: id,
            departmentId,
          })),
        });
      }
      if (dto.memberStaffIds !== undefined || dto.departmentId !== undefined ||
          dto.departmentIds !== undefined || dto.leaderStaffId !== undefined) {
        await tx.teamMember.deleteMany({ where: { teamId: id } });
        if (memberStaffIds.length) {
          await tx.teamMember.createMany({
            data: memberStaffIds.map((staffId) => ({
              teamId: id,
              staffId,
              role: staffId === leaderStaffId ? 'LEADER' : 'MEMBER',
            })),
          });
        }
      }
      return tx.team.update({
        where: { id },
        data: {
          ...(dto.name !== undefined ? { name } : {}),
          ...(dto.code !== undefined ? { code } : {}),
          ...(dto.departmentIds !== undefined || dto.departmentId !== undefined
            ? { departmentId: departmentIds[0] }
            : {}),
          ...(dto.leaderStaffId !== undefined || dto.departmentId !== undefined
            ? { leaderStaffId: leaderStaffId || null }
            : {}),
        },
        include: {
          department: { select: { id: true, name: true } },
          departments: {
            include: { department: { select: { id: true, name: true } } },
          },
          leader: { select: { id: true, fullName: true, employeeId: true } },
          members: {
            include: { staff: { select: { id: true, fullName: true, employeeId: true } } },
          },
        },
      });
    });
  }

  async deleteTeam(id: string) {
    const team = await this.prisma.team.findUnique({ where: { id } });
    if (!team) throw new NotFoundException('Team not found');
    return this.prisma.team.delete({ where: { id } });
  }

  private teamDepartmentIds(
    dto: { departmentIds?: string[]; departmentId?: string },
    fallback: string[] = [],
  ) {
    return [
      ...new Set(
        dto.departmentIds ??
          (dto.departmentId ? [dto.departmentId] : fallback),
      ),
    ];
  }

  private async validateTeamMembers(departmentIds: string[], staffIds: string[]) {
    if (!departmentIds.length) {
      throw new BadRequestException('Select at least one department for the team');
    }
    const departmentCount = await this.prisma.department.count({
      where: { id: { in: departmentIds } },
    });
    if (departmentCount !== departmentIds.length) {
      throw new BadRequestException('One or more selected departments do not exist');
    }
    if (!staffIds.length) return;
    const count = await this.prisma.staff.count({
      where: {
        id: { in: staffIds },
        departmentId: { in: departmentIds },
        status: 'ACTIVE',
      },
    });
    if (count !== staffIds.length) {
      throw new BadRequestException('Team leader and members must be active staff in the selected department');
    }
  }

  private validateTeamInput(
    dto: {
      name?: string;
      code?: string;
      departmentIds?: string[];
      departmentId?: string;
      leaderStaffId?: string | null;
      memberStaffIds?: string[];
    },
    creating: boolean,
  ) {
    if (!dto || typeof dto !== 'object' || Array.isArray(dto)) {
      throw new BadRequestException('Team details are required');
    }
    if (
      (creating && (typeof dto.name !== 'string' || typeof dto.code !== 'string')) ||
      (dto.name !== undefined && typeof dto.name !== 'string') ||
      (dto.code !== undefined && typeof dto.code !== 'string') ||
      (creating &&
        !(
          (Array.isArray(dto.departmentIds) && dto.departmentIds.length > 0) ||
          (typeof dto.departmentId === 'string' && dto.departmentId)
        )) ||
      (dto.departmentIds !== undefined &&
        (!Array.isArray(dto.departmentIds) ||
          dto.departmentIds.some((departmentId) => typeof departmentId !== 'string'))) ||
      (dto.departmentId !== undefined && typeof dto.departmentId !== 'string') ||
      (dto.leaderStaffId !== undefined &&
        dto.leaderStaffId !== null &&
        typeof dto.leaderStaffId !== 'string') ||
      (dto.memberStaffIds !== undefined &&
        (!Array.isArray(dto.memberStaffIds) ||
          dto.memberStaffIds.some((staffId) => typeof staffId !== 'string')))
    ) {
      throw new BadRequestException('Invalid team details');
    }
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
      include: {
        _count: { select: { users: true, staff: true, teamDepartments: true } },
      },
    });
    if (!existing) throw new NotFoundException('Department not found');
    if (
      existing._count.users > 0 ||
      existing._count.staff > 0 ||
      existing._count.teamDepartments > 0
    ) {
      throw new ConflictException(
        'Cannot delete a department that still has users, staff, or teams',
      );
    }
    return this.prisma.department.delete({ where: { id } });
  }

  // ─── DESIGNATIONS ──────────────────────────────────────────────────────────

  async getDesignations() {
    return this.prisma.designation.findMany({
      include: { _count: { select: { staff: true } } },
      orderBy: { name: 'asc' },
    });
  }

  async createDesignation(dto: { name: string; code: string; description?: string }) {
    const exists = await this.prisma.designation.findFirst({
      where: { OR: [{ name: dto.name }, { code: dto.code }] },
    });
    if (exists) throw new ConflictException('Designation with this name or code already exists');
    return this.prisma.designation.create({ data: dto });
  }

  async updateDesignation(id: string, dto: { name?: string; code?: string; description?: string }) {
    const existing = await this.prisma.designation.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Designation not found');
    return this.prisma.designation.update({ where: { id }, data: dto });
  }

  async deleteDesignation(id: string) {
    const existing = await this.prisma.designation.findUnique({
      where: { id },
      include: { _count: { select: { staff: true } } },
    });
    if (!existing) throw new NotFoundException('Designation not found');
    if (existing._count.staff > 0) {
      throw new ConflictException('Cannot delete designation with active staff members');
    }
    return this.prisma.designation.delete({ where: { id } });
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

  private isAdministratorUser(user?: any): boolean {
    if (!user) return false;
    if (user.username === 'admin' || user.email === 'admin@saark.in') return true;
    const roles: string[] = Array.isArray(user.roles)
      ? user.roles.map((r: any) => (typeof r === 'string' ? r : r.code || r.role?.code || ''))
      : [];
    if (typeof user.role === 'string') roles.push(user.role);
    if (user.role?.code) roles.push(user.role.code);
    if (Array.isArray(user.userRoles)) {
      user.userRoles.forEach((ur: any) => {
        if (ur.role?.code) roles.push(ur.role.code);
      });
    }
    return roles.some((r) => ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r));
  }

  private async assertAdminRoleAssignmentSafe(roleIds: string[] | undefined, currentUser?: any) {
    if (!roleIds || roleIds.length === 0) return;
    const isCurrentAdmin = this.isAdministratorUser(currentUser);
    const targetRoles = await this.prisma.role.findMany({
      where: { id: { in: roleIds } },
    });
    const containsAdminRole = targetRoles.some(
      (r) =>
        ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r.code) ||
        r.isSystem === true,
    );
    if (containsAdminRole && !isCurrentAdmin) {
      throw new ForbiddenException(
        'Privilege escalation denied: Only administrators can assign administrator or system roles.',
      );
    }
  }

  async createUser(
    dto: {
      username: string;
      email: string;
      password: string;
      fullName: string;
      phone?: string;
      designation?: string;
      departmentId?: string;
      roleIds?: string[];
    },
    currentUser?: any,
  ) {
    const existingEmail = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existingEmail) throw new ConflictException('Email already in use');
    const existingUsername = await this.prisma.user.findUnique({ where: { username: dto.username } });
    if (existingUsername) throw new ConflictException('Username already in use');

    if (dto.roleIds?.length) {
      await this.assertAdminRoleAssignmentSafe(dto.roleIds, currentUser);
    }

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

  async updateUser(id: string, dto: any, currentUser?: any) {
    const existing = await this.prisma.user.findUnique({
      where: { id },
      include: { userRoles: { include: { role: true } } },
    });
    if (!existing) throw new NotFoundException('User not found');

    const isCurrentAdmin = this.isAdministratorUser(currentUser);

    // Prevent non-admin user from modifying their own roles (self-privilege elevation)
    if (dto.roleIds !== undefined && currentUser?.id === id && !isCurrentAdmin) {
      throw new ForbiddenException('Privilege escalation denied: Users cannot modify their own roles.');
    }

    // Prevent non-admin user from assigning admin or system roles to anyone
    if (dto.roleIds !== undefined) {
      await this.assertAdminRoleAssignmentSafe(dto.roleIds, currentUser);

      // Prevent non-admin user from modifying or removing roles of an existing administrator
      const targetIsAdmin = existing.userRoles.some((ur) =>
        ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(ur.role.code),
      );
      if (targetIsAdmin && !isCurrentAdmin) {
        throw new ForbiddenException(
          'Privilege escalation denied: Only administrators can modify roles for administrator accounts.',
        );
      }
    }

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

  async toggleUserStatus(id: string, currentUser?: any) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: { userRoles: { include: { role: true } } },
    });
    if (!user) throw new NotFoundException('User not found');

    const isCurrentAdmin = this.isAdministratorUser(currentUser);
    const targetIsAdmin = user.userRoles.some((ur) =>
      ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(ur.role.code),
    );
    if (targetIsAdmin && !isCurrentAdmin) {
      throw new ForbiddenException(
        'Privilege escalation denied: Only administrators can modify status for administrator accounts.',
      );
    }
    if (currentUser?.id === id) {
      throw new ForbiddenException('Cannot modify status of currently active session account.');
    }

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

  async createRole(dto: { name: string; code: string; description?: string; permissionIds?: string[] }, currentUser?: any) {
    if (['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(dto.code?.toUpperCase()) && !this.isAdministratorUser(currentUser)) {
      throw new ForbiddenException('Privilege escalation denied: Only administrators can create administrator roles.');
    }

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

  async updateRolePermissions(roleId: string, permissionIds: string[], currentUser?: any) {
    const role = await this.prisma.role.findUnique({ where: { id: roleId } });
    if (!role) throw new NotFoundException('Role not found');
    if (role.isSystem) throw new ConflictException('Cannot modify system role permissions');
    if (['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(role.code?.toUpperCase()) && !this.isAdministratorUser(currentUser)) {
      throw new ForbiddenException('Privilege escalation denied: Only administrators can modify administrator role permissions.');
    }

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

  // ─── EMPLOYEE ONBOARDING REQUESTS & PROVISIONING ────────────────────────────

  async getEmployeeRequests(query?: { departmentId?: string; status?: string; search?: string }) {
    const where: any = {};
    if (query?.status && query.status !== 'ALL') {
      where.status = query.status;
    } else if (!query?.status) {
      where.status = 'PENDING_APPROVAL';
    }

    if (query?.departmentId && query.departmentId !== 'ALL') {
      where.departmentId = query.departmentId;
    }

    if (query?.search) {
      where.OR = [
        { firstName: { contains: query.search } },
        { lastName: { contains: query.search } },
        { email: { contains: query.search } },
        { employeeCode: { contains: query.search } },
        { designation: { contains: query.search } },
      ];
    }

    return this.prisma.employee.findMany({
      where,
      include: {
        department: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async approveEmployeeRequest(
    employeeId: string,
    dto: ApproveEmployeeRequestDto,
    adminUser?: any,
  ) {
    if (adminUser && !this.isAdministratorUser(adminUser)) {
      throw new ForbiddenException('Only administrators can approve employee onboarding and provision accounts.');
    }

    const employee = await this.prisma.employee.findFirst({
      where: {
        OR: [{ id: employeeId }, { employeeCode: employeeId }],
      },
      include: { department: true },
    });

    if (!employee) throw new NotFoundException(`Employee '${employeeId}' not found`);

    // ── ALREADY-LINKED ACCOUNT: manage existing user instead of blocking ──
    if (employee.userId) {
      const existingLinkedUser = await this.prisma.user.findUnique({
        where: { id: employee.userId },
      });
      if (!existingLinkedUser) {
        // Stale userId pointer — clear it and continue to create a fresh account
        await this.prisma.employee.update({
          where: { id: employee.id },
          data: { userId: null },
        });
      } else {
        // Update the existing linked user account (username, dept, roles)
        // Only re-hash + update password if a new one was explicitly provided
        const targetDeptId = dto.departmentId || employee.departmentId || existingLinkedUser.departmentId;
        const updateData: any = {
          username: dto.username,
          fullName: `${employee.firstName} ${employee.lastName}`.trim(),
          phone: employee.phone,
          designation: employee.designation,
          departmentId: targetDeptId,
          status: 'ACTIVE',
        };

        // Only hash & update password when caller explicitly provides one
        if (dto.password && dto.password.trim().length >= 6) {
          updateData.passwordHash = await bcrypt.hash(dto.password, 12);
        }

        const updatedUser = await this.prisma.user.update({
          where: { id: existingLinkedUser.id },
          data: updateData,
        });

        // Refresh roles
        await this.prisma.userRole.deleteMany({ where: { userId: updatedUser.id } });
        const validRoleIds = (dto.roleIds || []).filter(
          (roleId) => Boolean(roleId) && typeof roleId === 'string' && roleId.trim().length > 0,
        );
        if (validRoleIds.length > 0) {
          await this.assertAdminRoleAssignmentSafe(validRoleIds, adminUser);
          await this.prisma.userRole.createMany({
            data: validRoleIds.map((roleId) => ({ userId: updatedUser.id, roleId })),
          });
        } else {
          const defaultRole = await this.prisma.role.findFirst({ where: { code: 'ROLE_EMPLOYEE' } });
          if (defaultRole) {
            await this.prisma.userRole.create({ data: { userId: updatedUser.id, roleId: defaultRole.id } });
          }
        }

        // Sync employee status to ACTIVE
        const syncedEmployee = await this.prisma.employee.update({
          where: { id: employee.id },
          data: { departmentId: targetDeptId, status: 'ACTIVE' },
          include: { department: true },
        });

        try {
          const auditUserId = adminUser?.id || updatedUser.id;
          await this.prisma.auditLog.create({
            data: {
              userId: auditUserId,
              userEmail: adminUser?.email || updatedUser.email,
              action: 'UPDATE',
              module: 'ADMIN_HR',
              entityType: 'EMPLOYEE',
              entityId: employee.id,
              details: `Admin updated existing linked account for Employee ${employee.employeeCode} (${employee.firstName} ${employee.lastName}). Username set to: ${updatedUser.username}`,
            },
          });
        } catch (e) {
          console.error('Failed to write account-update audit log:', e);
        }

        return {
          success: true,
          message: `Employee ${employee.employeeCode} account updated. Username: ${updatedUser.username}`,
          accountAction: 'UPDATED_EXISTING',
          employee: syncedEmployee,
          user: {
            id: updatedUser.id,
            username: updatedUser.username,
            email: updatedUser.email,
            fullName: updatedUser.fullName,
            status: updatedUser.status,
          },
        };
      }
    }


    const targetDeptId = dto.departmentId || employee.departmentId;
    const passwordHash = await bcrypt.hash(dto.password, 12);
    let user: any;

    const existingEmail = await this.prisma.user.findUnique({ where: { email: employee.email } });
    if (existingEmail) {
      // Check if this user account is already assigned to a DIFFERENT employee
      const otherEmployee = await this.prisma.employee.findFirst({
        where: { userId: existingEmail.id, id: { not: employee.id } },
      });
      if (otherEmployee) {
        throw new ConflictException(
          `User with email "${employee.email}" is already linked to employee ${otherEmployee.employeeCode} (${otherEmployee.firstName} ${otherEmployee.lastName})`,
        );
      }

      // Check if the requested username is taken by a different account
      if (existingEmail.username !== dto.username) {
        const usernameConflict = await this.prisma.user.findUnique({ where: { username: dto.username } });
        if (usernameConflict && usernameConflict.id !== existingEmail.id) {
          throw new ConflictException(`Username "${dto.username}" is already in use by another account`);
        }
      }

      // Update existing unlinked user account with new credentials and department
      user = await this.prisma.user.update({
        where: { id: existingEmail.id },
        data: {
          username: dto.username,
          passwordHash,
          fullName: `${employee.firstName} ${employee.lastName}`.trim(),
          phone: employee.phone,
          designation: employee.designation,
          departmentId: targetDeptId,
          status: 'ACTIVE',
        },
      });
    } else {
      const existingUsername = await this.prisma.user.findUnique({ where: { username: dto.username } });
      if (existingUsername) throw new ConflictException(`Username "${dto.username}" is already in use`);

      user = await this.prisma.user.create({
        data: {
          username: dto.username,
          email: employee.email,
          passwordHash,
          fullName: `${employee.firstName} ${employee.lastName}`.trim(),
          phone: employee.phone,
          designation: employee.designation,
          departmentId: targetDeptId,
          status: 'ACTIVE',
        },
      });
    }

    // Refresh user roles
    await this.prisma.userRole.deleteMany({ where: { userId: user.id } });

    const validRoleIds = (dto.roleIds || []).filter(
      (roleId) => Boolean(roleId) && typeof roleId === 'string' && roleId.trim().length > 0,
    );

    if (validRoleIds.length > 0) {
      await this.assertAdminRoleAssignmentSafe(validRoleIds, adminUser);
      await this.prisma.userRole.createMany({
        data: validRoleIds.map((roleId) => ({ userId: user.id, roleId })),
      });
    } else {
      const defaultRole = await this.prisma.role.findFirst({
        where: { code: 'ROLE_EMPLOYEE' },
      });
      if (defaultRole) {
        await this.prisma.userRole.create({
          data: { userId: user.id, roleId: defaultRole.id },
        });
      }
    }

    let desigId = dto.designationId;
    if (!desigId) {
      const existingDesig = await this.prisma.designation.findFirst({
        where: { name: employee.designation },
      });
      if (existingDesig) {
        desigId = existingDesig.id;
      } else {
        const code = employee.designation.toUpperCase().replace(/[^A-Z0-9]/g, '_').slice(0, 15);
        const createdDesig = await this.prisma.designation.create({
          data: { name: employee.designation, code: `${code}_${Date.now().toString().slice(-4)}` },
        });
        desigId = createdDesig.id;
      }
    }

    let deptId = targetDeptId;
    if (!deptId) {
      const defaultDept = await this.prisma.department.findFirst({ where: { code: 'ADMIN' } });
      if (defaultDept) deptId = defaultDept.id;
    }

    const existingStaff = await this.prisma.staff.findFirst({
      where: { OR: [{ email: employee.email }, { employeeId: employee.employeeCode }] },
    });

    if (existingStaff) {
      await this.prisma.staff.update({
        where: { id: existingStaff.id },
        data: {
          userId: user.id,
          departmentId: deptId || existingStaff.departmentId,
          designationId: desigId || existingStaff.designationId,
          status: 'ACTIVE',
        },
      });
    } else if (deptId && desigId) {
      await this.prisma.staff.create({
        data: {
          employeeId: employee.employeeCode,
          fullName: `${employee.firstName} ${employee.lastName}`.trim(),
          email: employee.email,
          mobile: employee.phone,
          departmentId: deptId,
          designationId: desigId,
          userId: user.id,
          status: 'ACTIVE',
        },
      });
    }

    const updatedEmployee = await this.prisma.employee.update({
      where: { id: employee.id },
      data: {
        userId: user.id,
        departmentId: deptId,
        status: 'ACTIVE',
      },
      include: {
        department: true,
      },
    });

    try {
      let auditUserId = user.id;
      if (adminUser?.id) {
        const adminExists = await this.prisma.user.findUnique({ where: { id: adminUser.id } });
        if (adminExists) auditUserId = adminExists.id;
      }

      await this.prisma.auditLog.create({
        data: {
          userId: auditUserId,
          userEmail: adminUser?.email || user.email,
          action: 'APPROVE',
          module: 'ADMIN_HR',
          entityType: 'EMPLOYEE',
          entityId: employee.id,
          details: `Employee ${employee.employeeCode} (${employee.firstName} ${employee.lastName}) approved by Admin. User account created with username: ${dto.username}`,
        },
      });
    } catch (e) {
      console.error('Failed to write approval audit log:', e);
    }

    return {
      success: true,
      message: `Employee ${employee.employeeCode} successfully approved and provisioned as user ${user.username}`,
      employee: updatedEmployee,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        status: user.status,
      },
    };
  }

  async rejectEmployeeRequest(employeeId: string, reason?: string, adminUser?: any) {
    if (adminUser && !this.isAdministratorUser(adminUser)) {
      throw new ForbiddenException('Only administrators can reject employee onboarding requests.');
    }

    const employee = await this.prisma.employee.findFirst({
      where: {
        OR: [{ id: employeeId }, { employeeCode: employeeId }],
      },
    });

    if (!employee) throw new NotFoundException(`Employee '${employeeId}' not found`);

    const updated = await this.prisma.employee.update({
      where: { id: employee.id },
      data: { status: 'REJECTED' },
      include: { department: true },
    });

    try {
      let auditUserId: string | null = null;
      if (adminUser?.id) {
        const adminExists = await this.prisma.user.findUnique({ where: { id: adminUser.id } });
        if (adminExists) auditUserId = adminExists.id;
      }

      await this.prisma.auditLog.create({
        data: {
          userId: auditUserId,
          userEmail: adminUser?.email,
          action: 'REJECT',
          module: 'ADMIN_HR',
          entityType: 'EMPLOYEE',
          entityId: employee.id,
          details: `Employee ${employee.employeeCode} rejected by Admin. Reason: ${reason || 'N/A'}`,
        },
      });
    } catch (e) {
      console.error('Failed to write rejection audit log:', e);
    }

    return {
      success: true,
      message: `Employee request ${employee.employeeCode} rejected`,
      employee: updated,
    };
  }

  // ─── ADMIN: RESET EMPLOYEE PASSWORD ─────────────────────────────────────────

  async resetEmployeePassword(
    employeeId: string,
    newPassword: string,
    adminUser?: any,
  ) {
    if (adminUser && !this.isAdministratorUser(adminUser)) {
      throw new ForbiddenException('Only administrators can reset employee passwords.');
    }

    if (!newPassword || newPassword.trim().length < 8) {
      throw new BadRequestException('New password must be at least 8 characters.');
    }

    const employee = await this.prisma.employee.findFirst({
      where: { OR: [{ id: employeeId }, { employeeCode: employeeId }] },
    });

    if (!employee) throw new NotFoundException(`Employee '${employeeId}' not found`);

    if (!employee.userId) {
      throw new BadRequestException(
        'This employee does not have a linked user account yet. Approve and provision the account first.',
      );
    }

    const linkedUser = await this.prisma.user.findUnique({ where: { id: employee.userId } });
    if (!linkedUser) {
      throw new NotFoundException('Linked user account not found. The account may have been deleted.');
    }

    const passwordHash = await bcrypt.hash(newPassword.trim(), 12);

    await this.prisma.user.update({
      where: { id: linkedUser.id },
      data: { passwordHash, status: 'ACTIVE' },
    });

    // Audit log — never record the password value
    try {
      const auditUserId = adminUser?.id || linkedUser.id;
      await this.prisma.auditLog.create({
        data: {
          userId: auditUserId,
          userEmail: adminUser?.email || linkedUser.email,
          action: 'PASSWORD_RESET',
          module: 'ADMIN_HR',
          entityType: 'USER',
          entityId: linkedUser.id,
          details: `Password reset by admin for Employee ${employee.employeeCode} (${employee.firstName} ${employee.lastName}), User: ${linkedUser.username}. Initiated by: ${adminUser?.email || 'System Admin'}`,
        },
      });
    } catch (e) {
      console.error('Failed to write password reset audit log:', e);
    }

    return {
      success: true,
      message: `Password successfully reset for ${employee.firstName} ${employee.lastName} (${employee.employeeCode})`,
      userId: linkedUser.id,
      username: linkedUser.username,
    };
  }

  // ─── EMPLOYEE ACCESS MANAGEMENT & PERMISSION OVERRIDES ──────────────────────


  async getEmployeesAccessList(query: {
    search?: string;
    departmentId?: string;
    roleId?: string;
    page?: number | string;
    limit?: number | string;
  }) {
    const page = Math.max(1, Number(query.page) || 1);
    const limit = Math.max(1, Math.min(100, Number(query.limit) || 20));
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query.departmentId && query.departmentId !== 'ALL') {
      where.departmentId = query.departmentId;
    }
    if (query.roleId && query.roleId !== 'ALL') {
      where.userRoles = { some: { roleId: query.roleId } };
    }
    if (query.search) {
      const q = query.search.trim();
      where.OR = [
        { fullName: { contains: q } },
        { email: { contains: q } },
        { username: { contains: q } },
        { staff: { employeeId: { contains: q } } },
      ];
    }

    const [total, users] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        skip,
        take: limit,
        include: {
          department: { select: { id: true, name: true, code: true } },
          staff: { select: { id: true, employeeId: true } },
          userRoles: {
            include: {
              role: {
                include: {
                  rolePermissions: { include: { permission: true } },
                },
              },
            },
          },
          userPermissions: {
            include: { permission: true },
          },
        },
        orderBy: { fullName: 'asc' },
      }),
    ]);

    // Preload system permissions in case of admin user
    const allPerms = await this.prisma.permission.findMany({
      select: { module: true, action: true },
    });
    const allPermCodes = allPerms.map((p) => `${p.module}:${p.action}`);

    const data = users.map((user) => {
      const effective = this.permissionResolverService!.calculateEffective(user, allPermCodes);
      const modules = Array.from(
        new Set(effective.effectivePermissions.map((p) => p.split(':')[0])),
      ).sort();

      return {
        id: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        designation: user.designation,
        status: user.status,
        department: user.department,
        employeeId: user.staff?.employeeId || null,
        staffId: user.staff?.id || null,
        roles: user.userRoles.map((ur) => ({
          id: ur.role.id,
          name: ur.role.name,
          code: ur.role.code,
        })),
        inheritedCount: effective.inheritedPermissions.length,
        customAllowCount: effective.customAllows.length,
        explicitDenyCount: effective.explicitDenies.length,
        effectiveCount: effective.effectivePermissions.length,
        modules,
      };
    });

    return {
      success: true,
      data,
      employees: data,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      },
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  }

  async getEmployeeAccessDetail(id: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        OR: [
          { id },
          { username: id },
          { email: id },
          { staff: { id } },
          { staff: { employeeId: id } },
        ],
      },
      include: {
        department: true,
        staff: {
          include: {
            department: true,
            designation: true,
          },
        },
        userRoles: {
          include: {
            role: {
              include: {
                rolePermissions: { include: { permission: true } },
              },
            },
          },
        },
        userPermissions: {
          include: {
            permission: true,
            grantedBy: { select: { id: true, fullName: true, email: true } },
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException(`Employee / User '${id}' not found`);
    }

    const allPermissions = await this.prisma.permission.findMany({
      orderBy: [{ module: 'asc' }, { action: 'asc' }],
    });
    const allPermCodes = allPermissions.map((p) => `${p.module}:${p.action}`);

    const effective = this.permissionResolverService!.calculateEffective(user, allPermCodes);
    const inheritedSet = new Set(effective.inheritedPermissions);
    const overrideMap = new Map<string, any>();
    for (const up of user.userPermissions) {
      overrideMap.set(up.permissionId, up);
    }

    // Group permissions by module
    const modules: Record<string, any[]> = {};
    for (const p of allPermissions) {
      if (!modules[p.module]) {
        modules[p.module] = [];
      }
      const permCode = `${p.module}:${p.action}`;
      const isInherited = inheritedSet.has(permCode);
      const override = overrideMap.get(p.id);
      const isEffective = effective.effectivePermissions.includes(permCode);

      modules[p.module].push({
        permissionId: p.id,
        module: p.module,
        action: p.action,
        description: p.description,
        inherited: isInherited,
        override: override ? override.effect : null,
        effective: isEffective,
        grantedBy: override?.grantedBy || null,
        reason: override?.reason || null,
        updatedAt: override?.updatedAt || null,
      });
    }

    const moduleList = Object.keys(modules).map((modName) => ({
      name: modName,
      permissions: modules[modName].map((p) => ({
        id: p.permissionId,
        permissionId: p.permissionId,
        module: p.module,
        action: p.action,
        name: p.description || `${p.module}:${p.action}`,
        description: p.description,
        inherited: p.inherited,
        override: p.override,
        effective: p.effective,
        grantedBy: p.grantedBy,
        reason: p.reason,
        updatedAt: p.updatedAt,
      })),
    }));

    return {
      success: true,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        designation: user.designation,
        status: user.status,
        department: user.department,
        employeeId: user.staff?.employeeId || null,
        staffId: user.staff?.id || null,
      },
      employee: {
        id: user.staff?.id || user.id,
        employeeCode: user.staff?.employeeId || user.username,
        fullName: user.fullName || user.staff?.fullName || user.username,
        email: user.email,
        department: user.department?.name || user.staff?.department?.name || 'General',
        designation: user.designation || user.staff?.designation?.name || 'Staff',
        user: {
          id: user.id,
          username: user.username,
        },
      },
      roles: user.userRoles.map((ur) => ({
        id: ur.role.id,
        name: ur.role.name,
        code: ur.role.code,
        description: ur.role.description,
        isSystem: ur.role.isSystem,
      })),
      modules: moduleList,
      modulesMap: modules,
      effectivePermissions: effective.effectivePermissions,
      summary: {
        totalInherited: effective.inheritedPermissions.length,
        totalCustomAllows: effective.customAllows.length,
        totalExplicitDenies: effective.explicitDenies.length,
        totalEffective: effective.effectivePermissions.length,
      },
    };
  }

  async updateEmployeeAccess(
    id: string,
    dto: UpdateEmployeeAccessDto,
    currentUser: any,
  ) {
    if (!currentUser) {
      throw new ForbiddenException('User context missing');
    }

    const isCurrentAdmin = this.isAdministratorUser(currentUser);
    if (!isCurrentAdmin) {
      throw new ForbiddenException(
        'Privilege escalation denied: Only administrators can modify employee access overrides.',
      );
    }

    const targetUser = await this.prisma.user.findFirst({
      where: {
        OR: [
          { id },
          { username: id },
          { email: id },
          { staff: { id } },
          { staff: { employeeId: id } },
        ],
      },
      include: {
        userRoles: { include: { role: true } },
        userPermissions: { include: { permission: true } },
      },
    });

    if (!targetUser) {
      throw new NotFoundException(`Employee / User '${id}' not found`);
    }

    // Prevent non-admin modification of administrator permissions
    const targetIsAdmin = targetUser.userRoles.some((ur) =>
      ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(ur.role.code),
    );
    if (targetIsAdmin && !isCurrentAdmin) {
      throw new ForbiddenException(
        'Privilege escalation denied: Only administrators can modify access for administrator accounts.',
      );
    }

    // Validate permission IDs
    const permissionIds = dto.overrides.map((o) => o.permissionId);
    if (permissionIds.length > 0) {
      const existingPerms = await this.prisma.permission.findMany({
        where: { id: { in: permissionIds } },
      });
      if (existingPerms.length !== permissionIds.length) {
        const foundSet = new Set(existingPerms.map((p) => p.id));
        const missing = permissionIds.filter((pId) => !foundSet.has(pId));
        throw new BadRequestException(`Invalid permission ID(s) provided: ${missing.join(', ')}`);
      }
    }

    // Snapshot previous overrides for audit
    const previousOverrides = targetUser.userPermissions.map((up) => ({
      permissionId: up.permissionId,
      code: `${up.permission.module}:${up.permission.action}`,
      effect: up.effect,
      reason: up.reason,
    }));

    // Atomic transaction for overrides and audit logging
    await this.prisma.$transaction(async (tx) => {
      for (const override of dto.overrides) {
        if (override.effect === PermissionOverrideEffect.INHERIT) {
          await tx.userPermission.deleteMany({
            where: {
              userId: targetUser.id,
              permissionId: override.permissionId,
            },
          });
        } else {
          await tx.userPermission.upsert({
            where: {
              userId_permissionId: {
                userId: targetUser.id,
                permissionId: override.permissionId,
              },
            },
            create: {
              userId: targetUser.id,
              permissionId: override.permissionId,
              effect: override.effect,
              grantedById: currentUser.id || null,
              reason: override.reason || dto.reason || null,
            },
            update: {
              effect: override.effect,
              grantedById: currentUser.id || null,
              reason: override.reason || dto.reason || null,
              updatedAt: new Date(),
            },
          });
        }
      }

      await tx.auditLog.create({
        data: {
          userId: currentUser.id || null,
          userEmail: currentUser.email || 'admin@saark.in',
          action: 'PERMISSION_OVERRIDE',
          module: 'ADMIN_RBAC',
          entityType: 'USER_PERMISSION',
          entityId: targetUser.id,
          details: JSON.stringify({
            targetUserId: targetUser.id,
            targetUsername: targetUser.username,
            targetFullName: targetUser.fullName,
            overridesCount: dto.overrides.length,
            reason: dto.reason || 'Administrative access override update',
            previousOverrides,
            newOverrides: dto.overrides,
          }),
        },
      });
    });

    return this.getEmployeeAccessDetail(targetUser.id);
  }
}
