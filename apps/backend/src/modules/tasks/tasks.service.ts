import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import { NotificationService } from '../../core/notifications/notification.service';

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly notificationService: NotificationService,
  ) {}

  async findAll(query?: {
    search?: string;
    projectId?: string;
    milestoneId?: string;
    departmentId?: string;
    assigneeStaffId?: string;
    status?: string;
    priority?: string;
  }) {
    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.priority) where.priority = query.priority;
    if (query?.projectId) where.projectId = query.projectId;
    if (query?.milestoneId) where.milestoneId = query.milestoneId;
    if (query?.departmentId) where.departmentId = query.departmentId;
    if (query?.assigneeStaffId) where.assigneeStaffId = query.assigneeStaffId;

    if (query?.search) {
      where.OR = [
        { title: { contains: query.search } },
        { taskNumber: { contains: query.search } },
        { description: { contains: query.search } },
      ];
    }

    return this.prisma.task.findMany({
      where,
      include: {
        project: { select: { id: true, name: true, projectNumber: true } },
        milestone: { select: { id: true, title: true } },
        department: { select: { id: true, name: true, code: true } },
        assignee: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            profilePhoto: true,
            designation: { select: { name: true } },
          },
        },
        creator: { select: { id: true, fullName: true, employeeId: true } },
        _count: { select: { comments: true, activities: true } },
      },
      orderBy: [{ priority: 'desc' }, { dueDate: 'asc' }],
    });
  }

  async findMyTasks(staffId: string) {
    if (!staffId) return [];

    return this.prisma.task.findMany({
      where: { assigneeStaffId: staffId },
      include: {
        project: { select: { id: true, name: true, projectNumber: true } },
        milestone: { select: { id: true, title: true } },
        creator: { select: { id: true, fullName: true, employeeId: true } },
      },
      orderBy: [{ priority: 'desc' }, { dueDate: 'asc' }],
    });
  }

  async findOne(id: string) {
    const task = await this.prisma.task.findUnique({
      where: { id },
      include: {
        project: true,
        milestone: true,
        department: true,
        assignee: {
          include: { department: true, designation: true },
        },
        creator: {
          include: { department: true, designation: true },
        },
        assigner: {
          select: { id: true, fullName: true, employeeId: true },
        },
        comments: {
          include: {
            staff: { select: { id: true, fullName: true, employeeId: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
        activities: {
          include: {
            staff: { select: { id: true, fullName: true, employeeId: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!task) throw new NotFoundException('Task not found');
    return task;
  }

  async create(dto: {
    title: string;
    description?: string;
    projectId?: string;
    milestoneId?: string;
    departmentId?: string;
    assigneeStaffId?: string;
    priority?: string;
    dueDate?: string;
    estimatedHours?: number;
  }, actorStaffId?: string, actorId?: string, actorEmail?: string) {
    if (!actorStaffId) {
      // Find staff profile associated with actor user
      const staff = await this.prisma.staff.findFirst({ where: { userId: actorId } });
      if (staff) {
        actorStaffId = staff.id;
      } else {
        // Fallback to first active staff or fail
        const firstStaff = await this.prisma.staff.findFirst();
        if (!firstStaff) throw new BadRequestException('No staff profile exists to create task');
        actorStaffId = firstStaff.id;
      }
    }

    const year = new Date().getFullYear();
    const count = await this.prisma.task.count();
    const taskNumber = `TSK-${year}-${String(count + 1).padStart(3, '0')}`;

    const initialStatus = dto.assigneeStaffId ? 'ASSIGNED' : 'CREATED';

    const task = await this.prisma.task.create({
      data: {
        taskNumber,
        title: dto.title,
        description: dto.description,
        projectId: dto.projectId || null,
        milestoneId: dto.milestoneId || null,
        departmentId: dto.departmentId || null,
        assigneeStaffId: dto.assigneeStaffId || null,
        createdByStaffId: actorStaffId,
        assignedByStaffId: dto.assigneeStaffId ? actorStaffId : null,
        priority: dto.priority || 'MEDIUM',
        status: initialStatus,
        dueDate: dto.dueDate ? new Date(dto.dueDate) : null,
        estimatedHours: dto.estimatedHours ? Number(dto.estimatedHours) : 0,
        actualHours: 0,
        progress: 0,
      },
      include: {
        assignee: true,
        project: true,
      },
    });

    // Record initial activity
    await this.prisma.taskActivity.create({
      data: {
        taskId: task.id,
        staffId: actorStaffId,
        action: 'TASK_CREATED',
        newValue: initialStatus,
      },
    });

    // Notify assignee if assigned
    if (dto.assigneeStaffId && task.assignee?.userId) {
      await this.notificationService.notify({
        userId: task.assignee.userId,
        title: 'New Task Assigned',
        message: `You have been assigned task ${task.taskNumber}: ${task.title}`,
        module: 'TASK',
        entityId: task.id,
      });
    }

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: 'CREATE',
      module: 'TASKS',
      entityType: 'Task',
      entityId: task.id,
      details: `Created task ${task.taskNumber}: ${task.title}`,
    });

    return task;
  }

  async update(id: string, dto: any, actorStaffId?: string, actorId?: string, actorEmail?: string) {
    const existing = await this.prisma.task.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Task not found');

    const updateData: any = {};
    if (dto.title) updateData.title = dto.title;
    if (dto.description !== undefined) updateData.description = dto.description;
    if (dto.projectId !== undefined) updateData.projectId = dto.projectId || null;
    if (dto.milestoneId !== undefined) updateData.milestoneId = dto.milestoneId || null;
    if (dto.departmentId !== undefined) updateData.departmentId = dto.departmentId || null;
    if (dto.priority) updateData.priority = dto.priority;
    if (dto.dueDate !== undefined) updateData.dueDate = dto.dueDate ? new Date(dto.dueDate) : null;
    if (dto.estimatedHours !== undefined) updateData.estimatedHours = Number(dto.estimatedHours);
    if (dto.actualHours !== undefined) updateData.actualHours = Number(dto.actualHours);
    if (dto.progress !== undefined) updateData.progress = Number(dto.progress);

    // If reassigned
    if (dto.assigneeStaffId !== undefined && dto.assigneeStaffId !== existing.assigneeStaffId) {
      updateData.assigneeStaffId = dto.assigneeStaffId || null;
      updateData.assignedByStaffId = actorStaffId || existing.createdByStaffId;
      if (existing.status === 'CREATED' && dto.assigneeStaffId) {
        updateData.status = 'ASSIGNED';
      }

      if (actorStaffId) {
        await this.prisma.taskActivity.create({
          data: {
            taskId: id,
            staffId: actorStaffId,
            action: 'REASSIGNED',
            oldValue: existing.assigneeStaffId || 'Unassigned',
            newValue: dto.assigneeStaffId || 'Unassigned',
          },
        });
      }
    }

    const updated = await this.prisma.task.update({
      where: { id },
      data: updateData,
      include: {
        assignee: true,
        project: true,
      },
    });

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: 'UPDATE',
      module: 'TASKS',
      entityType: 'Task',
      entityId: id,
      details: `Updated task ${updated.taskNumber}`,
    });

    return updated;
  }

  async updateStatus(
    id: string,
    newStatus: string,
    notes?: string,
    actorStaffId?: string,
    actorUser?: any,
  ) {
    const task = await this.prisma.task.findUnique({
      where: { id },
      include: {
        assignee: true,
        creator: true,
      },
    });

    if (!task) throw new NotFoundException('Task not found');

    const validStatuses = [
      'CREATED',
      'ASSIGNED',
      'ACCEPTED',
      'IN_PROGRESS',
      'REVIEW',
      'RETURNED',
      'COMPLETED',
      'CANCELLED',
    ];
    if (!validStatuses.includes(newStatus)) {
      throw new BadRequestException(`Invalid status: ${newStatus}`);
    }

    const oldStatus = task.status;

    // Check authorization for completion / return
    const isAdmin =
      actorUser?.roles?.includes('ROLE_ADMIN') ||
      actorUser?.roles?.includes('ADMIN') ||
      actorUser?.roles?.includes('SUPER_ADMIN');
    const isManager =
      actorUser?.roles?.includes('ROLE_PROJECT_MGR') ||
      actorStaffId === task.createdByStaffId ||
      actorStaffId === task.assignedByStaffId;

    if (newStatus === 'COMPLETED' && !isAdmin && !isManager) {
      throw new ForbiddenException('Only managers or administrators can approve and complete tasks');
    }

    const updateData: any = { status: newStatus };
    if (newStatus === 'COMPLETED') {
      updateData.progress = 100;
    }

    const updated = await this.prisma.task.update({
      where: { id },
      data: updateData,
    });

    // Record activity
    if (actorStaffId) {
      await this.prisma.taskActivity.create({
        data: {
          taskId: id,
          staffId: actorStaffId,
          action: 'STATUS_CHANGE',
          oldValue: oldStatus,
          newValue: newStatus,
        },
      });
    }

    // Add comment if notes provided
    if (notes && actorStaffId) {
      await this.prisma.taskComment.create({
        data: {
          taskId: id,
          staffId: actorStaffId,
          comment: `[Status changed to ${newStatus}]: ${notes}`,
        },
      });
    }

    // Notify parties
    if (newStatus === 'REVIEW' && task.creator?.userId) {
      await this.notificationService.notify({
        userId: task.creator.userId,
        title: 'Task Submitted for Review',
        message: `Task ${task.taskNumber} has been submitted for review.`,
        module: 'TASK',
        entityId: id,
      });
    } else if (newStatus === 'RETURNED' && task.assignee?.userId) {
      await this.notificationService.notify({
        userId: task.assignee.userId,
        title: 'Task Returned for Changes',
        message: `Task ${task.taskNumber} returned for revision: ${notes || 'See comments'}`,
        module: 'TASK',
        entityId: id,
      });
    } else if (newStatus === 'COMPLETED' && task.assignee?.userId) {
      await this.notificationService.notify({
        userId: task.assignee.userId,
        title: 'Task Approved & Completed',
        message: `Task ${task.taskNumber} has been approved and completed.`,
        module: 'TASK',
        entityId: id,
      });
    }

    return updated;
  }

  async addComment(taskId: string, comment: string, staffId: string) {
    if (!staffId) throw new BadRequestException('Staff profile required to post comment');

    return this.prisma.taskComment.create({
      data: {
        taskId,
        staffId,
        comment,
      },
      include: {
        staff: { select: { id: true, fullName: true, employeeId: true } },
      },
    });
  }
}
