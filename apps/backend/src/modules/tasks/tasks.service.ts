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

  private sanitizeText(input?: string): string | undefined {
    if (!input) return input;
    return input.replace(/<[^>]*>/g, '').trim();
  }

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
            department: { select: { name: true } },
          },
        },
        creator: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            designation: { select: { name: true } },
          },
        },
        assigner: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            designation: { select: { name: true } },
          },
        },
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
        assignee: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            designation: { select: { name: true } },
            department: { select: { name: true } },
          },
        },
        creator: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            designation: { select: { name: true } },
          },
        },
        assigner: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            designation: { select: { name: true } },
          },
        },
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
        designation: { select: { name: true } },
      },
      orderBy: { fullName: 'asc' },
    });
  }

  async getFormOptions(actorStaffId?: string, actorUser?: any) {
    const userRole = actorUser?.role?.name?.toUpperCase() || '';
    const isAdmin = Boolean(actorUser?.isSuperAdmin || userRole === 'ADMIN' || userRole === 'SUPER_ADMIN');

    let currentUserStaff: any = null;
    if (actorStaffId) {
      currentUserStaff = await this.prisma.staff.findUnique({
        where: { id: actorStaffId },
        select: {
          id: true,
          fullName: true,
          employeeId: true,
          department: { select: { id: true, name: true } },
          designation: { select: { id: true, name: true } },
        },
      });
    }

    const [staffList, projects, departments, teams] = await Promise.all([
      this.prisma.staff.findMany({
        where: { status: 'ACTIVE' },
        select: {
          id: true,
          fullName: true,
          employeeId: true,
          department: { select: { id: true, name: true } },
          designation: { select: { id: true, name: true } },
        },
        orderBy: { fullName: 'asc' },
      }),
      this.prisma.project.findMany({
        select: {
          id: true,
          name: true,
          projectNumber: true,
          status: true,
          milestones: {
            select: { id: true, title: true, status: true },
            orderBy: { createdAt: 'asc' },
          },
        },
        orderBy: { name: 'asc' },
      }),
      this.prisma.department.findMany({
        select: { id: true, name: true, code: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.team.findMany({
        select: {
          id: true,
          name: true,
          code: true,
          departmentId: true,
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
                  department: { select: { name: true } },
                  designation: { select: { name: true } },
                },
              },
            },
          },
        },
        orderBy: { name: 'asc' },
      }),
    ]);

    return {
      currentUser: {
        staffId: currentUserStaff?.id || actorStaffId || '',
        fullName: currentUserStaff?.fullName || actorUser?.fullName || 'Current User',
        employeeId: currentUserStaff?.employeeId || '',
        designation: currentUserStaff?.designation?.name || 'Staff',
        department: currentUserStaff?.department?.name || '',
        isAdmin,
      },
      staffList,
      projects,
      departments,
      teams,
    };
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

  async updateProgress(taskId: string, progress: number, actorStaffId?: string, actorUser?: any) {
    if (!Number.isInteger(progress) || progress < 0 || progress > 100) {
      throw new BadRequestException('Progress must be a whole number from 0 to 100');
    }

    // Resolve actor staff profile if not provided
    if (!actorStaffId && (actorUser?.id || actorUser?.email)) {
      const staff = await this.prisma.staff.findFirst({
        where: {
          OR: [
            ...(actorUser.id ? [{ userId: actorUser.id }] : []),
            ...(actorUser.email ? [{ email: actorUser.email }] : []),
          ],
        },
      });
      actorStaffId = staff?.id;
    }

    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
      select: {
        id: true,
        progress: true,
        status: true,
        assigneeStaffId: true,
        assignedByStaffId: true,
        createdByStaffId: true,
        teamId: true,
      },
    });
    if (!task) throw new NotFoundException('Task not found');
    if (task.status === 'COMPLETED' || task.status === 'CANCELLED') {
      throw new BadRequestException('Progress cannot be changed on a closed task');
    }

    const isAdmin =
      actorUser?.roles?.some((role: string) =>
        ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN', 'ROLE_PROJECT_MGR', 'MANAGER'].includes(role),
      ) ||
      actorUser?.permissions?.includes('TASKS:UPDATE') ||
      actorUser?.permissions?.includes('TASKS:CREATE');

    const isAssignerOrCreator = Boolean(
      actorStaffId &&
        (task.assignedByStaffId === actorStaffId ||
          task.createdByStaffId === actorStaffId),
    );

    let isAssignee = Boolean(actorStaffId && task.assigneeStaffId === actorStaffId);
    if (!isAssignee && task.teamId && !task.assigneeStaffId && actorStaffId) {
      isAssignee = Boolean(
        await this.prisma.teamMember.findFirst({
          where: { teamId: task.teamId, staffId: actorStaffId },
          select: { id: true },
        }),
      );
    }

    if (!isAssignee && !isAdmin && !isAssignerOrCreator) {
      throw new ForbiddenException('Only the assigned employee or manager can update progress');
    }

    // Determine target status:
    // When progress > 0 and task is in CREATED, ASSIGNED, or PENDING, automatically advance to IN_PROGRESS
    // When progress == 100, advance to COMPLETED
    let newStatus = task.status;
    if (progress > 0 && ['CREATED', 'ASSIGNED', 'PENDING', 'ACCEPTED'].includes(task.status)) {
      newStatus = 'IN_PROGRESS';
    } else if (progress === 100 && ['IN_PROGRESS', 'REVIEW', 'ACCEPTED', 'CREATED', 'ASSIGNED'].includes(task.status)) {
      newStatus = 'COMPLETED';
    }

    const updated = await this.prisma.task.update({
      where: { id: taskId },
      data: {
        progress,
        ...(newStatus !== task.status ? { status: newStatus } : {}),
      },
    });

    const effectiveStaffId = actorStaffId || task.createdByStaffId || task.assignedByStaffId;
    if (effectiveStaffId) {
      await this.prisma.taskActivity.create({
        data: {
          taskId,
          staffId: effectiveStaffId,
          action: 'PROGRESS_UPDATED',
          oldValue: `${task.progress}%`,
          newValue: `${progress}%`,
        },
      });

      if (newStatus !== task.status) {
        await this.prisma.taskActivity.create({
          data: {
            taskId,
            staffId: effectiveStaffId,
            action: 'STATUS_CHANGE',
            oldValue: task.status,
            newValue: newStatus,
          },
        });
      }
    }

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
    assignedByStaffId?: string;
    priority?: string;
    dueDate?: string;
    estimatedHours?: number | string;
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
      select: { id: true, status: true, fullName: true, employeeId: true },
    });
    if (!actorStaff || actorStaff.status !== 'ACTIVE') {
      throw new ForbiddenException('An active staff profile is required to create tasks');
    }

    // 1. Title Validation & Sanitization
    const rawTitle = dto.title?.trim();
    if (!rawTitle || rawTitle.length < 3) {
      throw new BadRequestException('Task title is required and must be at least 3 characters');
    }
    if (rawTitle.length > 150) {
      throw new BadRequestException('Task title cannot exceed 150 characters');
    }
    const title = this.sanitizeText(rawTitle)!;

    // 2. Description Sanitization
    const description = dto.description ? this.sanitizeText(dto.description) : null;
    if (description && description.length > 3000) {
      throw new BadRequestException('Task description cannot exceed 3000 characters');
    }

    // 3. Priority Validation
    const validPriorities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
    const priority = (dto.priority || 'MEDIUM').toUpperCase();
    if (!validPriorities.includes(priority)) {
      throw new BadRequestException('Invalid priority level. Allowed values: LOW, MEDIUM, HIGH, CRITICAL');
    }

    // 4. Due Date Validation (Must not be in the past)
    let dueDate: Date | null = null;
    if (dto.dueDate) {
      dueDate = new Date(dto.dueDate);
      if (isNaN(dueDate.getTime())) {
        throw new BadRequestException('Invalid due date format');
      }
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const checkDue = new Date(dueDate);
      checkDue.setHours(0, 0, 0, 0);
      if (checkDue < today) {
        throw new BadRequestException('Due date cannot be set in the past for a new task');
      }
    }

    // 5. Estimated Hours Validation
    let estimatedHours = 0;
    if (dto.estimatedHours !== undefined && dto.estimatedHours !== null && dto.estimatedHours !== '') {
      estimatedHours = Number(dto.estimatedHours);
      if (isNaN(estimatedHours) || estimatedHours < 0 || estimatedHours > 1000) {
        throw new BadRequestException('Estimated hours must be a number between 0 and 1000');
      }
    }

    // 6. Project & Milestone Validation
    if (dto.projectId) {
      const project = await this.prisma.project.findUnique({
        where: { id: dto.projectId },
        select: { id: true, name: true },
      });
      if (!project) throw new BadRequestException('Selected project not found');
      if (dto.milestoneId) {
        const milestone = await this.prisma.milestone.findFirst({
          where: { id: dto.milestoneId, projectId: dto.projectId },
          select: { id: true },
        });
        if (!milestone) {
          throw new BadRequestException('Selected milestone is not associated with the selected project');
        }
      }
    }

    // 7. Assigned From / Delegator Security
    let assignedByStaffId = actorStaffId;
    if (dto.assignedByStaffId && dto.assignedByStaffId !== actorStaffId) {
      if (!isAdmin) {
        throw new ForbiddenException('Only administrators or project managers can delegate tasks on behalf of another issuer');
      }
      const assignerStaff = await this.prisma.staff.findFirst({
        where: { id: dto.assignedByStaffId, status: 'ACTIVE' },
        select: { id: true },
      });
      if (!assignerStaff) {
        throw new BadRequestException('The specified delegating assigner must be active staff');
      }
      assignedByStaffId = assignerStaff.id;
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
        title,
        description,
        projectId: dto.projectId || null,
        milestoneId: dto.milestoneId || null,
        departmentId,
        teamId: dto.teamId || null,
        assigneeStaffId: dto.assigneeStaffId || null,
        createdByStaffId: actorStaffId,
        assignedByStaffId: isAssigned ? assignedByStaffId : null,
        priority,
        status: initialStatus,
        dueDate,
        estimatedHours,
        actualHours: 0,
        progress: 0,
      },
      include: {
        assignee: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            designation: { select: { name: true } },
            department: { select: { name: true } },
          },
        },
        creator: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            designation: { select: { name: true } },
          },
        },
        assigner: {
          select: {
            id: true,
            fullName: true,
            employeeId: true,
            designation: { select: { name: true } },
          },
        },
        project: true,
        milestone: true,
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
    if (dto.assigneeStaffId && (task.assignee as any)?.userId) {
      await this.notificationService.notify({
        userId: (task.assignee as any).userId,
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
        if (!userId || userId === (task.assignee as any)?.userId || notifiedUserIds.has(userId)) {
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
      details: `Created task ${task.taskNumber}: ${task.title} (Priority: ${task.priority})`,
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

    // Resolve actor staff profile if not provided
    if (!actorStaffId && (actorUser?.id || actorUser?.email)) {
      const staff = await this.prisma.staff.findFirst({
        where: {
          OR: [
            ...(actorUser.id ? [{ userId: actorUser.id }] : []),
            ...(actorUser.email ? [{ email: actorUser.email }] : []),
          ],
        },
      });
      actorStaffId = staff?.id;
    }

    const oldStatus = task.status;

    const isAdmin =
      actorUser?.roles?.some((role: string) =>
        ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN', 'ROLE_PROJECT_MGR'].includes(role),
      ) ||
      actorUser?.permissions?.includes('TASKS:UPDATE') ||
      actorUser?.permissions?.includes('TASKS:CREATE');

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
      CREATED: ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'REVIEW', 'COMPLETED', 'CANCELLED'],
      ASSIGNED: ['ACCEPTED', 'IN_PROGRESS', 'CANCELLED'],
      ACCEPTED: ['IN_PROGRESS', 'REVIEW', 'CANCELLED'],
      IN_PROGRESS: ['PENDING', 'REVIEW', 'COMPLETED', 'CANCELLED'],
      PENDING: ['IN_PROGRESS', 'REVIEW', 'CANCELLED'],
      RETURNED: ['IN_PROGRESS', 'REVIEW', 'CANCELLED'],
      REVIEW: ['RETURNED', 'COMPLETED', 'IN_PROGRESS', 'CANCELLED'],
      COMPLETED: ['IN_PROGRESS'],
    };
    if (!isAdmin && !(allowedTransitions[task.status] ?? []).includes(newStatus)) {
      throw new BadRequestException(
        `Cannot move a task from ${task.status} to ${newStatus}`,
      );
    }
    if (
      ['ACCEPTED', 'IN_PROGRESS', 'PENDING', 'REVIEW'].includes(newStatus) &&
      !isAssignee && !isAdmin && !isAssigner && !isManager
    ) {
      throw new ForbiddenException(
        'Only the assigned employee or manager can update work status',
      );
    }
    if (
      ['RETURNED', 'COMPLETED', 'CANCELLED'].includes(newStatus) &&
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

    const effectiveStaffId = actorStaffId || task.createdByStaffId || task.assignedByStaffId;

    // Record activity
    if (effectiveStaffId) {
      await this.prisma.taskActivity.create({
        data: {
          taskId: id,
          staffId: effectiveStaffId,
          action: 'STATUS_CHANGE',
          oldValue: oldStatus,
          newValue: newStatus,
        },
      });
    }

    // Add comment if notes provided
    if (notes && effectiveStaffId) {
      await this.prisma.taskComment.create({
        data: {
          taskId: id,
          staffId: effectiveStaffId,
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

  async addComment(taskId: string, comment: string, staffId?: string, actorUser?: any) {
    if (!staffId && (actorUser?.id || actorUser?.email)) {
      const staff = await this.prisma.staff.findFirst({
        where: {
          OR: [
            ...(actorUser.id ? [{ userId: actorUser.id }] : []),
            ...(actorUser.email ? [{ email: actorUser.email }] : []),
          ],
        },
      });
      staffId = staff?.id;
    }
    const task = await this.prisma.task.findUnique({
      where: { id: taskId },
      select: { createdByStaffId: true, assignedByStaffId: true },
    });
    const effectiveStaffId = staffId || task?.createdByStaffId || task?.assignedByStaffId;
    if (!effectiveStaffId) throw new BadRequestException('Staff profile required to post comment');

    return this.prisma.taskComment.create({
      data: {
        taskId,
        staffId: effectiveStaffId,
        comment,
      },
      include: {
        staff: { select: { id: true, fullName: true, employeeId: true } },
      },
    });
  }

  async remove(id: string, actorStaffId?: string, actorUser?: any) {
    const task = await this.prisma.task.findUnique({
      where: { id },
      include: { creator: true, assigner: true },
    });
    if (!task) throw new NotFoundException('Task not found');

    const isAdmin =
      actorUser?.roles?.some((role: string) =>
        ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(role),
      ) || actorUser?.permissions?.includes('TASKS:DELETE');

    const isCreatorOrAssigner =
      actorStaffId &&
      (task.createdByStaffId === actorStaffId ||
        task.assignedByStaffId === actorStaffId);

    if (!isAdmin && !isCreatorOrAssigner) {
      throw new ForbiddenException(
        'Only administrators or task creators can delete this task',
      );
    }

    // Cascade delete comments and activities
    await this.prisma.taskComment.deleteMany({ where: { taskId: id } });
    await this.prisma.taskActivity.deleteMany({ where: { taskId: id } });
    await this.prisma.task.delete({ where: { id } });

    await this.auditService.log({
      userId: actorUser?.id,
      userEmail: actorUser?.email,
      action: 'DELETE',
      module: 'TASKS',
      entityType: 'Task',
      entityId: id,
      details: `Deleted task ${task.taskNumber}: ${task.title}`,
    });

    return {
      success: true,
      message: `Task ${task.taskNumber} deleted successfully`,
    };
  }

  async logHours(
    id: string,
    hours: number,
    notes?: string,
    actorStaffId?: string,
    actorUser?: any,
  ) {
    if (!hours || hours <= 0) {
      throw new BadRequestException('Logged hours must be greater than zero');
    }

    const task = await this.prisma.task.findUnique({ where: { id } });
    if (!task) throw new NotFoundException('Task not found');

    if (!actorStaffId && (actorUser?.id || actorUser?.email)) {
      const staff = await this.prisma.staff.findFirst({
        where: {
          OR: [
            ...(actorUser.id ? [{ userId: actorUser.id }] : []),
            ...(actorUser.email ? [{ email: actorUser.email }] : []),
          ],
        },
      });
      actorStaffId = staff?.id;
    }

    const updated = await this.prisma.task.update({
      where: { id },
      data: {
        actualHours: { increment: Number(hours) },
      },
    });

    const effectiveStaffId = actorStaffId || task.createdByStaffId || task.assignedByStaffId;
    if (effectiveStaffId) {
      await this.prisma.taskActivity.create({
        data: {
          taskId: id,
          staffId: effectiveStaffId,
          action: 'LOG_HOURS',
          oldValue: `${task.actualHours} hrs`,
          newValue: `${updated.actualHours} hrs (+${hours} hrs)${notes ? ': ' + notes : ''}`,
        },
      });
    }

    return updated;
  }


  async getTaskStats(staffId?: string) {
    const now = new Date();
    const allTasks = await this.prisma.task.findMany({
      select: {
        id: true,
        status: true,
        priority: true,
        dueDate: true,
        progress: true,
        assigneeStaffId: true,
        createdByStaffId: true,
        assignedByStaffId: true,
      },
    });

    const total = allTasks.length;
    const completed = allTasks.filter((t) => t.status === 'COMPLETED').length;
    const inProgress = allTasks.filter((t) =>
      ['IN_PROGRESS', 'PENDING', 'ACCEPTED'].includes(t.status),
    ).length;
    const review = allTasks.filter((t) =>
      ['REVIEW', 'RETURNED'].includes(t.status),
    ).length;
    const overdue = allTasks.filter(
      (t) =>
        t.status !== 'COMPLETED' &&
        t.status !== 'CANCELLED' &&
        t.dueDate &&
        new Date(t.dueDate) < now,
    ).length;
    const critical = allTasks.filter(
      (t) =>
        (t.priority === 'CRITICAL' || t.priority === 'HIGH') &&
        t.status !== 'COMPLETED',
    ).length;

    let myTotal = 0;
    let myCompleted = 0;
    let myPending = 0;
    let myOverdue = 0;

    if (staffId) {
      const myTasks = allTasks.filter((t) => t.assigneeStaffId === staffId);
      myTotal = myTasks.length;
      myCompleted = myTasks.filter((t) => t.status === 'COMPLETED').length;
      myPending = myTasks.filter((t) => t.status !== 'COMPLETED').length;
      myOverdue = myTasks.filter(
        (t) =>
          t.status !== 'COMPLETED' && t.dueDate && new Date(t.dueDate) < now,
      ).length;
    }

    return {
      total,
      inProgress,
      review,
      completed,
      overdue,
      critical,
      completionRate: total > 0 ? Math.round((completed / total) * 100) : 0,
      myStats: {
        total: myTotal,
        completed: myCompleted,
        pending: myPending,
        overdue: myOverdue,
      },
    };
  }
}
