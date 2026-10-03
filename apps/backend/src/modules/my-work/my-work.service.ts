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

    const isAdmin =
      user?.roles?.includes('ROLE_ADMIN') ||
      user?.roles?.includes('ADMIN') ||
      user?.roles?.includes('SUPER_ADMIN');

    // 1. My Assigned Tasks
    const myTasks = staffId
      ? await this.prisma.task.findMany({
          where: {
            assigneeStaffId: staffId,
            status: { notIn: ['COMPLETED', 'CANCELLED'] },
          },
          include: {
            project: { select: { id: true, name: true, projectNumber: true } },
            milestone: { select: { id: true, title: true } },
          },
          orderBy: [{ priority: 'desc' }, { dueDate: 'asc' }],
          take: 10,
        })
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
    const taskStats = staffId
      ? {
          assigned: await this.prisma.task.count({
            where: { assigneeStaffId: staffId },
          }),
          inProgress: await this.prisma.task.count({
            where: { assigneeStaffId: staffId, status: 'IN_PROGRESS' },
          }),
          completed: await this.prisma.task.count({
            where: { assigneeStaffId: staffId, status: 'COMPLETED' },
          }),
          pendingReview: await this.prisma.task.count({
            where: { assigneeStaffId: staffId, status: 'REVIEW' },
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
