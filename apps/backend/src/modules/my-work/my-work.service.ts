import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';

@Injectable()
export class MyWorkService {
  constructor(private readonly prisma: PrismaService) {}

  async getSummary(staffId?: string, user?: any) {
    if (!staffId) {
      // Try to find staff by user id
      const staff = await this.prisma.staff.findFirst({ where: { userId: user?.id } });
      if (staff) staffId = staff.id;
    }
    const currentStaff = staffId
      ? await this.prisma.staff.findUnique({
          where: { id: staffId },
          include: {
            headedDepartment: { select: { id: true } },
            ledTeams: { select: { id: true } },
            teamMemberships: {
              select: {
                role: true,
                team: { select: { id: true, leaderStaffId: true } },
              },
            },
          },
        })
      : null;

    const isAdmin =
      user?.roles?.includes('ROLE_ADMIN') ||
      user?.roles?.includes('ADMIN') ||
      user?.roles?.includes('SUPER_ADMIN');

    // 1. My Assigned Tasks
    const teamRoles = new Map<string, string>();
    for (const team of currentStaff?.ledTeams ?? []) {
      teamRoles.set(team.id, 'LEADER');
    }
    for (const membership of currentStaff?.teamMemberships ?? []) {
      teamRoles.set(
        membership.team.id,
        membership.team.leaderStaffId === staffId ? 'LEADER' : membership.role,
      );
    }
    const teamIds = [...teamRoles.keys()];
    const departmentIds = currentStaff?.headedDepartment
      ? [currentStaff.headedDepartment.id]
      : [];
    const taskScope = staffId
      ? {
          OR: [
            { assigneeStaffId: staffId },
            ...(teamIds.length ? [{ teamId: { in: teamIds } }] : []),
            ...(departmentIds.length
              ? [{ departmentId: { in: departmentIds } }]
              : []),
          ],
        }
      : undefined;
    const myTasks = taskScope
      ? (await this.prisma.task.findMany({
          where: {
            ...taskScope,
            status: { notIn: ['COMPLETED', 'CANCELLED'] },
          },
          include: {
            project: { select: { id: true, name: true, projectNumber: true } },
            milestone: { select: { id: true, title: true } },
            department: { select: { id: true, name: true } },
            team: {
              select: {
                id: true,
                name: true,
                departments: {
                  select: { department: { select: { id: true, name: true } } },
                },
              },
            },
          },
          orderBy: [{ priority: 'desc' }, { dueDate: 'asc' }],
          take: 10,
        })).map((task) => ({
          ...task,
          assignmentScope:
            task.assigneeStaffId === staffId
              ? 'DIRECT'
              : task.teamId && teamRoles.has(task.teamId)
                  ? 'TEAM'
                  : 'DEPARTMENT',
          teamRole: task.teamId ? teamRoles.get(task.teamId) ?? null : null,
        }))
      : [];

    // 2. My Projects
    const myProjects = staffId
      ? await this.prisma.project.findMany({
          where: {
            OR: [
              { projectManagerStaffId: staffId },
              { members: { some: { staffId } } },
            ],
            status: { notIn: ['COMPLETED', 'CANCELLED'] },
          },
          include: {
            customer: { select: { companyName: true } },
            projectManager: { select: { fullName: true } },
            _count: { select: { tasks: true, members: true } },
          },
          orderBy: { createdAt: 'desc' },
          take: 5,
        })
      : [];

    // 3. Pending Approvals (For managers and admins)
    let pendingApprovals: any[] = [];
    if (isAdmin) {
      pendingApprovals = await this.prisma.task.findMany({
        where: { status: 'REVIEW' },
        include: {
          project: { select: { name: true, projectNumber: true } },
          assignee: { select: { fullName: true, employeeId: true } },
        },
        orderBy: { updatedAt: 'desc' },
        take: 10,
      });
    } else if (staffId) {
      pendingApprovals = await this.prisma.task.findMany({
        where: {
          status: 'REVIEW',
          OR: [
            { createdByStaffId: staffId },
            { assignedByStaffId: staffId },
            { project: { projectManagerStaffId: staffId } },
          ],
        },
        include: {
          project: { select: { name: true, projectNumber: true } },
          assignee: { select: { fullName: true, employeeId: true } },
        },
        orderBy: { updatedAt: 'desc' },
        take: 10,
      });
    }

    // 4. Task Counts
    const taskStats = staffId && taskScope
      ? {
          assigned: await this.prisma.task.count({
            where: taskScope,
          }),
          inProgress: await this.prisma.task.count({
            where: { ...taskScope, status: 'IN_PROGRESS' },
          }),
          completed: await this.prisma.task.count({
            where: { ...taskScope, status: 'COMPLETED' },
          }),
          pendingReview: await this.prisma.task.count({
            where: { ...taskScope, status: 'REVIEW' },
          }),
        }
      : { assigned: 0, inProgress: 0, completed: 0, pendingReview: 0 };

    return {
      myTasks,
      myProjects,
      pendingApprovals,
      taskStats,
    };
  }
}
