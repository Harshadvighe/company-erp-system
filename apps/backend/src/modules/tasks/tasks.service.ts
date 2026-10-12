import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';
import { NotificationService } from '../../core/notifications/notification.service';

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
    private readonly notificationService: NotificationService,
    private readonly sequenceService: SequenceService,
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
        team: { select: { id: true, name: true } },
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

    const staff = await this.prisma.staff.findUnique({
      where: { id: staffId },
      include: {
        headedDepartment: { select: { id: true } },
        ledTeams: { select: { id: true, name: true } },
        teamMemberships: {
          select: {
            role: true,
            team: { select: { id: true, name: true, leaderStaffId: true } },
          },
        },
      },
    });
    if (!staff) return [];

    const teamRoles = new Map<string, string>();
    for (const team of staff.ledTeams) teamRoles.set(team.id, 'LEADER');
    for (const membership of staff.teamMemberships) {
      teamRoles.set(
        membership.team.id,
        membership.team.leaderStaffId === staffId ? 'LEADER' : membership.role,
      );
    }
    const teamIds = [...teamRoles.keys()];
    const departmentIds = staff.headedDepartment ? [staff.headedDepartment.id] : [];
    const tasks = await this.prisma.task.findMany({
      where: {
        OR: [
          { assigneeStaffId: staffId },
          { assignedByStaffId: staffId },
          { createdByStaffId: staffId },
          ...(teamIds.length ? [{ teamId: { in: teamIds } }] : []),
          ...(departmentIds.length
            ? [{ departmentId: { in: departmentIds } }]
            : []),
        ],
      },
      include: {
        project: { select: { id: true, name: true, projectNumber: true } },
        milestone: { select: { id: true, title: true } },
        department: { select: { id: true, name: true } },
        team: { select: { id: true, name: true } },
        creator: { select: { id: true, fullName: true, employeeId: true } },
      },
      orderBy: [{ priority: 'desc' }, { dueDate: 'asc' }],
    });
    return tasks.map((task) => ({
      ...task,
      assignmentScope:
        task.assigneeStaffId === staffId
          ? 'DIRECT'
          : task.teamId && teamRoles.has(task.teamId)
              ? 'TEAM'
              : task.assignedByStaffId === staffId ||
                  task.createdByStaffId === staffId
                ? 'ASSIGNED_BY'
                : 'DEPARTMENT',
      isTaskAssigner:
        task.assignedByStaffId === staffId ||
        task.createdByStaffId === staffId,
      teamRole: task.teamId ? teamRoles.get(task.teamId) ?? null : null,
    }));
  }

  async findMyLedTeams(staffId?: string) {
    if (!staffId) return [];
    return this.prisma.team.findMany({
      where: { leaderStaffId: staffId },
      include: {
        department: { select: { id: true, name: true } },
        departments: {
          include: { department: { select: { id: true, name: true } } },
        },
        leader: { select: { id: true, fullName: true, employeeId: true } },
        members: {
          include: {
            staff: {
              select: {
                id: true,
                fullName: true,
                employeeId: true,
                status: true,
              },
            },
          },
          orderBy: { staff: { fullName: 'asc' } },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async getAssignableStaff(actorStaffId?: string) {
    if (!actorStaffId) {
      throw new ForbiddenException('A staff profile is required to assign tasks');
    }
    const actor = await this.prisma.staff.findFirst({
      where: { id: actorStaffId, status: 'ACTIVE' },
      select: { id: true },
    });
    if (!actor) {
      throw new ForbiddenException('An active staff profile is required to assign tasks');
    }
    return this.prisma.staff.findMany({
      where: { status: 'ACTIVE' },
      select: {
        id: true,
        fullName: true,
        employeeId: true,
        department: { select: { name: true } },
      },
      orderBy: { fullName: 'asc' },
    });
  }

  async findOne(id: string, actorStaffId?: string, actorUser?: any) {
    const task = await this.prisma.task.findUnique({
      where: { id },
      include: {
        project: true,
        milestone: true,
        department: true,
        team: {
          include: {
            leader: { select: { id: true, fullName: true, employeeId: true } },
            members: {
              include: {
                staff: {
                  select: { id: true, fullName: true, employeeId: true },
                },
              },
            },
          },
        },
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
    const hasViewPermission =
      actorUser?.roles?.some((role: string) =>
        ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(role),
      ) ||
      actorUser?.permissions?.includes('TASKS:VIEW');
    let isTeamMember = false;
    if (task.teamId && actorStaffId) {
      isTeamMember = Boolean(
        await this.prisma.teamMember.findFirst({
          where: { teamId: task.teamId, staffId: actorStaffId },
          select: { id: true },
        }),
      );
    }
    const hasTaskAccess =
      hasViewPermission ||
      Boolean(
        actorStaffId &&
          (task.assigneeStaffId === actorStaffId ||
            task.assignedByStaffId === actorStaffId ||
            task.createdByStaffId === actorStaffId ||
            task.team?.leaderStaffId === actorStaffId ||
            task.department?.headStaffId === actorStaffId ||
            isTeamMember),
      );
    if (!hasTaskAccess) {
      throw new ForbiddenException('You do not have access to this task');
    }
    return task;
  }

  async updateProgress(taskId: string, progress: number, actorStaffId?: string) {
    if (!Number.isInteger(progress) || progress < 0 || progress > 100) {
      throw new BadRequestException('Progress must be a whole number from 0 to 100');
    }
    if (!actorStaffId) {
      throw new ForbiddenException('A staff profile is required to update progress');
    }
    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
      select: {
        id: true,
        progress: true,
        status: true,
        assigneeStaffId: true,
        teamId: true,
      },
    });
    if (!task) throw new NotFoundException('Task not found');
    if (task.status === 'COMPLETED' || task.status === 'CANCELLED') {
      throw new BadRequestException('Progress cannot be changed on a closed task');
    }
    if (!['ACCEPTED', 'IN_PROGRESS', 'PENDING', 'RETURNED'].includes(task.status)) {
      throw new BadRequestException(
        'Accept the task before updating its progress',
      );
    }
    let isAssignee = task.assigneeStaffId === actorStaffId;
    if (!isAssignee && task.teamId && !task.assigneeStaffId) {
      isAssignee = Boolean(
        await this.prisma.teamMember.findFirst({
          where: { teamId: task.teamId, staffId: actorStaffId },
          select: { id: true },
        }),
      );
    }
    if (!isAssignee) {
      throw new ForbiddenException('Only the assigned employee can update progress');
    }
    const updated = await this.prisma.task.update({
      where: { id: taskId },
      data: { progress },
    });
    await this.prisma.taskActivity.create({
      data: {
        taskId,
        staffId: actorStaffId,
        action: 'PROGRESS_UPDATED',
        oldValue: `${task.progress}%`,
        newValue: `${progress}%`,
      },
    });
    return updated;
  }

  async create(dto: {
    title: string;
    description?: string;
    projectId?: string;
    milestoneId?: string;
    departmentId?: string;
    teamId?: string;
    assigneeStaffId?: string;
    priority?: string;
    dueDate?: string;
    estimatedHours?: number;
  }, actorStaffId?: string, actorId?: string, actorEmail?: string, actorUser?: any) {
    const isAdmin =
      actorUser?.roles?.includes('ROLE_ADMIN') ||
      actorUser?.roles?.includes('ADMIN') ||
      actorUser?.roles?.includes('SUPER_ADMIN');
    if (!actorStaffId) {
      const staff = await this.prisma.staff.findFirst({ where: { userId: actorId } });
      actorStaffId = staff?.id;
    }
    if (!actorStaffId) {
      throw new ForbiddenException('A staff profile is required to create tasks');
    }
    const actorStaff = await this.prisma.staff.findUnique({
      where: { id: actorStaffId },
      select: { id: true, status: true },
    });
    if (!actorStaff || actorStaff.status !== 'ACTIVE') {
      throw new ForbiddenException('An active staff profile is required to create tasks');
    }

    let departmentId = dto.departmentId || null;
    if (dto.teamId) {
      const team = await this.prisma.team.findUnique({
        where: { id: dto.teamId },
        select: {
          departmentId: true,
          leaderStaffId: true,
          departments: { select: { departmentId: true } },
        },
      });
      if (!team) throw new BadRequestException('Selected team not found');
      const canCreateTasks =
        isAdmin || actorUser?.permissions?.includes('TASKS:CREATE');
      if (!canCreateTasks && team.leaderStaffId !== actorStaffId) {
        throw new ForbiddenException(
          'You can only assign tasks to teams that you lead',
        );
      }
      const teamDepartmentIds = team.departments.length
        ? team.departments.map((item) => item.departmentId)
        : team.departmentId
          ? [team.departmentId]
          : [];
      if (
        departmentId &&
        !teamDepartmentIds.includes(departmentId)
      ) {
        throw new BadRequestException(
          'Task department must be included in the selected team',
        );
      }
      departmentId = null;
      if (dto.assigneeStaffId) {
        await this.validateTeamAssignee(dto.teamId, dto.assigneeStaffId);
      }
    } else if (dto.assigneeStaffId) {
      const assignee = await this.prisma.staff.findFirst({
        where: { id: dto.assigneeStaffId, status: 'ACTIVE' },
        select: { id: true },
      });
      if (!assignee) {
        throw new BadRequestException('The assignee must be active staff');
      }
    }

    const taskNumber = await this.sequenceService.nextTaskNumber();

    const isAssigned = Boolean(dto.assigneeStaffId || dto.teamId);
    const initialStatus = isAssigned ? 'ASSIGNED' : 'CREATED';

    const task = await this.prisma.task.create({
      data: {
        taskNumber,
        title: dto.title,
        description: dto.description,
        projectId: dto.projectId || null,
        milestoneId: dto.milestoneId || null,
        departmentId,
        teamId: dto.teamId || null,
        assigneeStaffId: dto.assigneeStaffId || null,
        createdByStaffId: actorStaffId,
        assignedByStaffId: isAssigned ? actorStaffId : null,
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
        team: {
          include: {
            members: {
              include: { staff: { select: { userId: true } } },
            },
          },
        },
        department: true,
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
    if (dto.teamId && task.team) {
      const notifiedUserIds = new Set<string>();
      for (const member of task.team.members) {
        const userId = member.staff.userId;
        if (!userId || userId === task.assignee?.userId || notifiedUserIds.has(userId)) {
          continue;
        }
        notifiedUserIds.add(userId);
        await this.notificationService.notify({
          userId,
          title: 'Team Task Assigned',
          message: `Your team has been assigned task ${task.taskNumber}: ${task.title}`,
          module: 'TASK',
          entityId: task.id,
        });
      }
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
    if (dto.teamId !== undefined) {
      const teamId = dto.teamId || null;
      if (teamId) {
        const team = await this.prisma.team.findUnique({
          where: { id: teamId },
          select: {
            departmentId: true,
            departments: { select: { departmentId: true } },
          },
        });
        if (!team) throw new BadRequestException('Selected team not found');
        const teamDepartmentIds = team.departments.length
          ? team.departments.map((item) => item.departmentId)
          : team.departmentId
            ? [team.departmentId]
            : [];
        if (
          dto.departmentId &&
          !teamDepartmentIds.includes(dto.departmentId)
        ) {
          throw new BadRequestException(
            'Task department must be included in the selected team',
          );
        }
        updateData.departmentId = null;
      }
      updateData.teamId = teamId;
      const assigneeStaffId =
        dto.assigneeStaffId === undefined
          ? existing.assigneeStaffId
          : dto.assigneeStaffId || null;
      if (teamId && assigneeStaffId) {
        await this.validateTeamAssignee(teamId, assigneeStaffId);
      }
    } else if (dto.departmentId !== undefined && existing.teamId) {
      const team = await this.prisma.team.findUnique({
        where: { id: existing.teamId },
        select: {
          departmentId: true,
          departments: { select: { departmentId: true } },
        },
      });
      const teamDepartmentIds = team?.departments.length
        ? team.departments.map((item) => item.departmentId)
        : team?.departmentId
          ? [team.departmentId]
          : [];
      if (
        team &&
        dto.departmentId &&
        !teamDepartmentIds.includes(dto.departmentId)
      ) {
        throw new BadRequestException(
          'Task department must be included in the selected team',
        );
      }
    }
    if (dto.priority) updateData.priority = dto.priority;
    if (dto.dueDate !== undefined) updateData.dueDate = dto.dueDate ? new Date(dto.dueDate) : null;
    if (dto.estimatedHours !== undefined) updateData.estimatedHours = Number(dto.estimatedHours);
    if (dto.actualHours !== undefined) updateData.actualHours = Number(dto.actualHours);
    if (dto.progress !== undefined) updateData.progress = Number(dto.progress);

    // If reassigned
    if (dto.assigneeStaffId !== undefined && dto.assigneeStaffId !== existing.assigneeStaffId) {
      updateData.assigneeStaffId = dto.assigneeStaffId || null;
      const teamId =
        dto.teamId === undefined ? existing.teamId : dto.teamId || null;
      if (teamId && dto.assigneeStaffId) {
        await this.validateTeamAssignee(teamId, dto.assigneeStaffId);
      }
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
        team: true,
        department: true,
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

  private async validateTeamAssignee(teamId: string, staffId: string) {
    const membership = await this.prisma.teamMember.findFirst({
      where: {
        teamId,
        staffId,
        staff: { status: 'ACTIVE' },
      },
      select: { id: true },
    });
    if (!membership) {
      throw new BadRequestException(
        'The individual assignee must be an active member or leader of the selected team',
      );
    }
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
        assigner: true,
        team: true,
        department: { include: { headStaff: { select: { id: true } } } },
      },
    });

    if (!task) throw new NotFoundException('Task not found');

    const validStatuses = [
      'CREATED',
      'ASSIGNED',
      'ACCEPTED',
      'IN_PROGRESS',
      'PENDING',
      'REVIEW',
      'RETURNED',
      'COMPLETED',
      'CANCELLED',
    ];
    if (!validStatuses.includes(newStatus)) {
      throw new BadRequestException(`Invalid status: ${newStatus}`);
    }

    const oldStatus = task.status;

    const isAdmin =
      actorUser?.roles?.includes('ROLE_ADMIN') ||
      actorUser?.roles?.includes('ADMIN') ||
      actorUser?.roles?.includes('SUPER_ADMIN');
    const isManager =
      actorUser?.roles?.includes('ROLE_PROJECT_MGR') ||
      actorStaffId === task.team?.leaderStaffId ||
      actorStaffId === task.department?.headStaff?.id;
    const isTeamMember = task.teamId && actorStaffId
      ? Boolean(
          await this.prisma.teamMember.findFirst({
            where: { teamId: task.teamId, staffId: actorStaffId },
            select: { id: true },
          }),
        )
      : false;
    const isAssignee = Boolean(
      actorStaffId &&
        (task.assigneeStaffId === actorStaffId ||
          (!task.assigneeStaffId && isTeamMember)),
    );
    const isAssigner = Boolean(
      actorStaffId &&
        (task.assignedByStaffId === actorStaffId ||
          task.createdByStaffId === actorStaffId),
    );
    const canReview = isAdmin || isManager || isAssigner;
    const allowedTransitions: Record<string, string[]> = {
      ASSIGNED: ['ACCEPTED'],
      ACCEPTED: ['IN_PROGRESS'],
      IN_PROGRESS: ['PENDING', 'REVIEW'],
      PENDING: ['IN_PROGRESS', 'REVIEW'],
      RETURNED: ['IN_PROGRESS', 'REVIEW'],
      REVIEW: ['RETURNED', 'COMPLETED'],
    };
    if (!(allowedTransitions[task.status] ?? []).includes(newStatus)) {
      throw new BadRequestException(
        `Cannot move a task from ${task.status} to ${newStatus}`,
      );
    }
    if (
      ['ACCEPTED', 'IN_PROGRESS', 'PENDING', 'REVIEW'].includes(newStatus) &&
      !isAssignee
    ) {
      throw new ForbiddenException(
        'Only the assigned employee can update work status',
      );
    }
    if (
      ['RETURNED', 'COMPLETED'].includes(newStatus) &&
      !canReview
    ) {
      throw new ForbiddenException(
        'Only the task assigner or a manager can review, return, or complete this task',
      );
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
    const reviewer = task.assigner?.userId ? task.assigner : task.creator;
    if (newStatus === 'REVIEW' && reviewer?.userId) {
      await this.notificationService.notify({
        userId: reviewer.userId,
        title: 'Task Submitted for Review',
        message: `Task ${task.taskNumber} has been submitted to you by the assignee for review.`,
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
