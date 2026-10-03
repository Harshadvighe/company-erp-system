import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class StaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async findAll(query?: {
    search?: string;
    departmentId?: string;
    designationId?: string;
    status?: string;
  }) {
    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.departmentId) where.departmentId = query.departmentId;
    if (query?.designationId) where.designationId = query.designationId;

    if (query?.search) {
      where.OR = [
        { fullName: { contains: query.search } },
        { employeeId: { contains: query.search } },
        { email: { contains: query.search } },
        { mobile: { contains: query.search } },
      ];
    }

    return this.prisma.staff.findMany({
      where,
      include: {
        department: { select: { id: true, name: true, code: true } },
        designation: { select: { id: true, name: true, code: true } },
        reportingManager: { select: { id: true, fullName: true, employeeId: true } },
        user: { select: { id: true, username: true, email: true, status: true } },
      },
      orderBy: { employeeId: 'asc' },
    });
  }

  async findOne(id: string) {
    const staff = await this.prisma.staff.findUnique({
      where: { id },
      include: {
        department: true,
        designation: true,
        reportingManager: {
          select: { id: true, fullName: true, employeeId: true, email: true },
        },
        subordinates: {
          select: { id: true, fullName: true, employeeId: true, designation: true },
        },
        user: {
          select: {
            id: true,
            username: true,
            email: true,
            status: true,
            userRoles: { select: { role: { select: { id: true, name: true, code: true } } } },
          },
        },
        _count: {
          select: {
            assignedTasks: true,
            managedProjects: true,
            projectMemberships: true,
          },
        },
      },
    });

    if (!staff) throw new NotFoundException('Staff member not found');
    return staff;
  }

  async create(dto: {
    employeeId: string;
    fullName: string;
    email: string;
    mobile?: string;
    profilePhoto?: string;
    departmentId: string;
    designationId: string;
    reportingManagerId?: string;
    userId?: string;
    status?: string;
    joiningDate?: string;
    location?: string;
    notes?: string;
    createUserAccount?: boolean;
    username?: string;
    password?: string;
    roleIds?: string[];
  }, actorId?: string, actorEmail?: string) {
    const existingEmployeeId = await this.prisma.staff.findUnique({
      where: { employeeId: dto.employeeId },
    });
    if (existingEmployeeId) {
      throw new ConflictException(`Employee ID ${dto.employeeId} already exists`);
    }

    const existingEmail = await this.prisma.staff.findUnique({
      where: { email: dto.email },
    });
    if (existingEmail) {
      throw new ConflictException(`Email ${dto.email} is already registered to a staff profile`);
    }

    let linkedUserId = dto.userId;

    // Optional: Create linked user account concurrently
    if (dto.createUserAccount && dto.username && dto.password) {
      const existingUser = await this.prisma.user.findFirst({
        where: { OR: [{ email: dto.email }, { username: dto.username }] },
      });
      if (existingUser) {
        throw new ConflictException('User with this email or username already exists');
      }

      const passwordHash = await bcrypt.hash(dto.password, 10);
      const newUser = await this.prisma.user.create({
        data: {
          username: dto.username,
          email: dto.email,
          fullName: dto.fullName,
          phone: dto.mobile,
          passwordHash,
          departmentId: dto.departmentId,
          status: 'ACTIVE',
        },
      });

      if (dto.roleIds?.length) {
        await this.prisma.userRole.createMany({
          data: dto.roleIds.map((roleId) => ({ userId: newUser.id, roleId })),
        });
      }

      linkedUserId = newUser.id;
    }

    const staff = await this.prisma.staff.create({
      data: {
        employeeId: dto.employeeId,
        fullName: dto.fullName,
        email: dto.email,
        mobile: dto.mobile,
        profilePhoto: dto.profilePhoto,
        departmentId: dto.departmentId,
        designationId: dto.designationId,
        reportingManagerId: dto.reportingManagerId || null,
        userId: linkedUserId || null,
        status: dto.status || 'ACTIVE',
        joiningDate: dto.joiningDate ? new Date(dto.joiningDate) : null,
        location: dto.location,
        notes: dto.notes,
      },
      include: {
        department: true,
        designation: true,
        user: true,
      },
    });

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: 'CREATE',
      module: 'STAFF',
      entityType: 'Staff',
      entityId: staff.id,
      details: `Created staff profile ${staff.employeeId} - ${staff.fullName}`,
    });

    return staff;
  }

  async update(id: string, dto: any, actorId?: string, actorEmail?: string) {
    const existing = await this.prisma.staff.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Staff member not found');

    const updateData: any = {};
    if (dto.fullName) updateData.fullName = dto.fullName;
    if (dto.mobile !== undefined) updateData.mobile = dto.mobile;
    if (dto.profilePhoto !== undefined) updateData.profilePhoto = dto.profilePhoto;
    if (dto.departmentId) updateData.departmentId = dto.departmentId;
    if (dto.designationId) updateData.designationId = dto.designationId;
    if (dto.reportingManagerId !== undefined) updateData.reportingManagerId = dto.reportingManagerId || null;
    if (dto.status) updateData.status = dto.status;
    if (dto.location !== undefined) updateData.location = dto.location;
    if (dto.notes !== undefined) updateData.notes = dto.notes;
    if (dto.joiningDate) updateData.joiningDate = new Date(dto.joiningDate);

    const updated = await this.prisma.staff.update({
      where: { id },
      data: updateData,
      include: {
        department: true,
        designation: true,
        user: true,
      },
    });

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: 'UPDATE',
      module: 'STAFF',
      entityType: 'Staff',
      entityId: updated.id,
      details: `Updated staff profile ${updated.employeeId} - ${updated.fullName}`,
    });

    return updated;
  }

  async updateStatus(id: string, status: string, actorId?: string, actorEmail?: string) {
    const staff = await this.prisma.staff.findUnique({ where: { id } });
    if (!staff) throw new NotFoundException('Staff member not found');

    const updated = await this.prisma.staff.update({
      where: { id },
      data: { status },
    });

    // If staff has a linked user account, sync status
    if (staff.userId) {
      const userStatus = status === 'ACTIVE' ? 'ACTIVE' : 'INACTIVE';
      await this.prisma.user.update({
        where: { id: staff.userId },
        data: { status: userStatus },
      });
    }

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: 'UPDATE_STATUS',
      module: 'STAFF',
      entityType: 'Staff',
      entityId: id,
      details: `Changed staff status from ${staff.status} to ${status}`,
    });

    return updated;
  }
}
