import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { ApproveEmployeeRequestDto } from './dto/approve-employee-request.dto';
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
    const employee = await this.prisma.employee.findFirst({
      where: {
        OR: [{ id: employeeId }, { employeeCode: employeeId }],
      },
      include: { department: true },
    });

    if (!employee) throw new NotFoundException(`Employee '${employeeId}' not found`);

    if (employee.userId) {
      throw new BadRequestException('This employee already has a linked user account');
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
}
