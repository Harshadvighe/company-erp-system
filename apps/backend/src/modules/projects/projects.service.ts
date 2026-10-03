import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Injectable()
export class ProjectsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async findAll(query?: {
    search?: string;
    status?: string;
    priority?: string;
    health?: string;
    projectManagerStaffId?: string;
    customerId?: string;
  }) {
    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.priority) where.priority = query.priority;
    if (query?.health) where.health = query.health;
    if (query?.projectManagerStaffId) where.projectManagerStaffId = query.projectManagerStaffId;
    if (query?.customerId) where.customerId = query.customerId;

    if (query?.search) {
      where.OR = [
        { name: { contains: query.search } },
        { projectNumber: { contains: query.search } },
        { description: { contains: query.search } },
      ];
    }

    return this.prisma.project.findMany({
      where,
      include: {
        customer: { select: { id: true, companyName: true, customerCode: true } },
        projectManager: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            email: true,
            designation: { select: { name: true } },
          },
        },
        _count: {
          select: {
            members: true,
            milestones: true,
            tasks: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const project = await this.prisma.project.findUnique({
      where: { id },
      include: {
        customer: true,
        projectManager: {
          include: {
            department: true,
            designation: true,
          },
        },
        members: {
          include: {
            staff: {
              include: {
                department: true,
                designation: true,
              },
            },
          },
        },
        milestones: {
          include: {
            tasks: {
              select: {
                id: true,
                taskNumber: true,
                title: true,
                status: true,
                priority: true,
                dueDate: true,
              },
            },
          },
          orderBy: { dueDate: 'asc' },
        },
        tasks: {
          include: {
            assignee: { select: { id: true, fullName: true, employeeId: true } },
            department: { select: { id: true, name: true } },
          },
          orderBy: { dueDate: 'asc' },
        },
      },
    });

    if (!project) throw new NotFoundException('Project not found');

    // Calculate dynamic health
    const recalculatedHealth = await this.calculateHealth(id);
    return { ...project, health: recalculatedHealth };
  }

  async calculateHealth(projectId: string): Promise<string> {
    const tasks = await this.prisma.task.findMany({
      where: { projectId },
      select: { status: true, dueDate: true, priority: true },
    });

    if (tasks.length === 0) return 'ON_TRACK';

    const now = new Date();
    const overdueTasks = tasks.filter(
      (t) => t.dueDate && new Date(t.dueDate) < now && t.status !== 'COMPLETED',
    );
    const criticalOverdue = overdueTasks.some((t) => t.priority === 'CRITICAL');

    const overdueRatio = overdueTasks.length / tasks.length;

    let health = 'ON_TRACK';
    if (criticalOverdue || overdueRatio > 0.35) {
      health = 'CRITICAL';
    } else if (overdueRatio > 0.15 || overdueTasks.length > 0) {
      health = 'AT_RISK';
    }

    await this.prisma.project.update({
      where: { id: projectId },
      data: { health },
    });

    return health;
  }

  async create(dto: {
    name: string;
    description?: string;
    customerId?: string;
    projectType?: string;
    projectManagerStaffId: string;
    startDate?: string;
    endDate?: string;
    priority?: string;
    budget?: number;
    status?: string;
  }, actorId?: string, actorEmail?: string) {
    const year = new Date().getFullYear();
    const count = await this.prisma.project.count();
    const projectNumber = `PRJ-${year}-${String(count + 1).padStart(3, '0')}`;

    const project = await this.prisma.project.create({
      data: {
        projectNumber,
        name: dto.name,
        description: dto.description,
        customerId: dto.customerId || null,
        projectType: dto.projectType || 'Customer Project',
        projectManagerStaffId: dto.projectManagerStaffId,
        startDate: dto.startDate ? new Date(dto.startDate) : null,
        endDate: dto.endDate ? new Date(dto.endDate) : null,
        priority: dto.priority || 'MEDIUM',
        budget: dto.budget ? Number(dto.budget) : 0,
        status: dto.status || 'PLANNING',
        health: 'ON_TRACK',
      },
      include: {
        projectManager: true,
        customer: true,
      },
    });

    // Automatically add Project Manager to project members
    await this.prisma.projectMember.create({
      data: {
        projectId: project.id,
        staffId: dto.projectManagerStaffId,
        projectRole: 'Project Manager',
        allocationPercent: 100,
      },
    });

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: 'CREATE',
      module: 'PROJECTS',
      entityType: 'Project',
      entityId: project.id,
      details: `Created project ${project.projectNumber}: ${project.name}`,
    });

    return project;
  }

  async update(id: string, dto: any, actorId?: string, actorEmail?: string) {
    const existing = await this.prisma.project.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Project not found');

    const updateData: any = {};
    if (dto.name) updateData.name = dto.name;
    if (dto.description !== undefined) updateData.description = dto.description;
    if (dto.customerId !== undefined) updateData.customerId = dto.customerId || null;
    if (dto.projectType) updateData.projectType = dto.projectType;
    if (dto.projectManagerStaffId) updateData.projectManagerStaffId = dto.projectManagerStaffId;
    if (dto.startDate !== undefined) updateData.startDate = dto.startDate ? new Date(dto.startDate) : null;
    if (dto.endDate !== undefined) updateData.endDate = dto.endDate ? new Date(dto.endDate) : null;
    if (dto.priority) updateData.priority = dto.priority;
    if (dto.budget !== undefined) updateData.budget = Number(dto.budget);
    if (dto.status) updateData.status = dto.status;

    const updated = await this.prisma.project.update({
      where: { id },
      data: updateData,
      include: {
        projectManager: true,
        customer: true,
      },
    });

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: 'UPDATE',
      module: 'PROJECTS',
      entityType: 'Project',
      entityId: id,
      details: `Updated project ${updated.projectNumber}`,
    });

    return updated;
  }

  async addMember(projectId: string, dto: {
    staffId: string;
    projectRole?: string;
    allocationPercent?: number;
  }) {
    const exists = await this.prisma.projectMember.findUnique({
      where: { projectId_staffId: { projectId, staffId: dto.staffId } },
    });
    if (exists) {
      throw new BadRequestException('Staff member is already assigned to this project');
    }

    return this.prisma.projectMember.create({
      data: {
        projectId,
        staffId: dto.staffId,
        projectRole: dto.projectRole || 'Team Member',
        allocationPercent: dto.allocationPercent || 100,
      },
      include: { staff: { include: { department: true, designation: true } } },
    });
  }

  async removeMember(projectId: string, staffId: string) {
    return this.prisma.projectMember.delete({
      where: { projectId_staffId: { projectId, staffId } },
    });
  }

  async createMilestone(projectId: string, dto: {
    title: string;
    description?: string;
    dueDate?: string;
  }) {
    return this.prisma.milestone.create({
      data: {
        projectId,
        title: dto.title,
        description: dto.description,
        dueDate: dto.dueDate ? new Date(dto.dueDate) : null,
        status: 'PENDING',
      },
    });
  }

  async updateMilestone(id: string, dto: any) {
    const updateData: any = {};
    if (dto.title) updateData.title = dto.title;
    if (dto.description !== undefined) updateData.description = dto.description;
    if (dto.dueDate) updateData.dueDate = new Date(dto.dueDate);
    if (dto.status) updateData.status = dto.status;

    return this.prisma.milestone.update({
      where: { id },
      data: updateData,
    });
  }
}
