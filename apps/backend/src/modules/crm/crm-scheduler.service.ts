import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { NotificationService } from '../../core/notifications/notification.service';

export const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

export function getISTDateParts(date: Date = new Date()): {
  year: number;
  month: number; // 0-indexed
  day: number;
  dayOfWeek: number; // 0=Sun, 1=Mon, ..., 6=Sat
  hours: number;
  minutes: number;
  seconds: number;
  dateStr: string; // YYYY-MM-DD
} {
  const istTime = new Date(date.getTime() + IST_OFFSET_MS);
  const year = istTime.getUTCFullYear();
  const month = istTime.getUTCMonth();
  const day = istTime.getUTCDate();
  const dayOfWeek = istTime.getUTCDay();
  const hours = istTime.getUTCHours();
  const minutes = istTime.getUTCMinutes();
  const seconds = istTime.getUTCSeconds();
  const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

  return { year, month, day, dayOfWeek, hours, minutes, seconds, dateStr };
}

export function calculateNextWorkingDayIST(fromDate: Date = new Date()): Date {
  const ist = getISTDateParts(fromDate);

  // Business day rules:
  // Friday (5) -> Next Monday (+3 days)
  // Saturday (6) -> Next Monday (+2 days)
  // Sunday (0) -> Next Monday (+1 day)
  // Monday-Thursday (1-4) -> Next day (+1 day)
  let daysToAdd = 1;
  if (ist.dayOfWeek === 5) {
    daysToAdd = 3;
  } else if (ist.dayOfWeek === 6) {
    daysToAdd = 2;
  } else if (ist.dayOfWeek === 0) {
    daysToAdd = 1;
  } else {
    daysToAdd = 1;
  }

  // Create target date by adding days
  const baseIstMs = Date.UTC(ist.year, ist.month, ist.day);
  const targetIstMs = baseIstMs + daysToAdd * 24 * 60 * 60 * 1000;
  const targetDateObj = new Date(targetIstMs);
  const targetYear = targetDateObj.getUTCFullYear();
  const targetMonth = targetDateObj.getUTCMonth();
  const targetDate = targetDateObj.getUTCDate();

  // 11:00:00 AM Asia/Kolkata is 05:30:00 UTC (11:00 - 5:30)
  return new Date(Date.UTC(targetYear, targetMonth, targetDate, 5, 30, 0, 0));
}

export function formatISTTime(date: Date): string {
  const ist = getISTDateParts(date);
  const hr12 = ist.hours % 12 || 12;
  const ampm = ist.hours >= 12 ? 'PM' : 'AM';
  const minStr = String(ist.minutes).padStart(2, '0');
  return `${ist.dateStr} ${hr12}:${minStr} ${ampm} IST`;
}

@Injectable()
export class CrmSchedulerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(CrmSchedulerService.name);
  private timer: NodeJS.Timeout | null = null;
  private isProcessingTick = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationService: NotificationService,
  ) {}

  onModuleInit() {
    this.logger.log('Starting CRM Scheduler background tick service (Asia/Kolkata)');
    // Run background tick every 60 seconds
    this.timer = setInterval(() => {
      this.tick().catch((err) => {
        this.logger.error(`Error during scheduler tick: ${err.message}`, err.stack);
      });
    }, 60000);
  }

  onModuleDestroy() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
      this.logger.log('CRM Scheduler stopped');
    }
  }

  /**
   * Periodic scheduler tick.
   * Checks due reminders, 09:00 AM My Day digest, and 06:00 PM overdue escalation.
   */
  async tick() {
    if (this.isProcessingTick) return;
    this.isProcessingTick = true;
    try {
      const now = new Date();
      const ist = getISTDateParts(now);

      // 1. Due reminders (run on every tick)
      await this.checkAndDispatchDueReminders();

      // 2. Daily My Day Digest at 09:00 AM IST (window: 9:00 - 9:59 AM)
      if (ist.hours === 9) {
        await this.dispatchDailyDigest(ist.dateStr, false);
      }

      // 3. Overdue Escalation at 06:00 PM IST (window: 18:00 - 18:59 IST)
      if (ist.hours === 18) {
        await this.checkAndDispatchOverdueEscalations(false);
      }
    } finally {
      this.isProcessingTick = false;
    }
  }

  /**
   * Helper: Suggests next working day callback at 11:00 AM Asia/Kolkata.
   */
  getNextWorkingDayCallback(fromDate?: Date) {
    const suggestedDate = calculateNextWorkingDayIST(fromDate || new Date());
    const istParts = getISTDateParts(suggestedDate);
    const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return {
      suggestedDate,
      suggestedDateIso: suggestedDate.toISOString(),
      formattedIST: formatISTTime(suggestedDate),
      dayOfWeek: dayNames[istParts.dayOfWeek],
      timezone: 'Asia/Kolkata',
    };
  }

  /**
   * Step 2.B — Due Reminders
   * Dispatches reminders for pending follow-ups that have scheduledDate approaching.
   */
  async checkAndDispatchDueReminders(): Promise<{ checked: number; sent: number }> {
    const now = new Date();
    // Default reminder window: up to 15 minutes in advance, and not older than 24 hours
    const maxLookaheadMinutes = 60;
    const futureLimit = new Date(now.getTime() + maxLookaheadMinutes * 60 * 1000);
    const pastLimit = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // Find candidate follow-ups
    const candidates = await this.prisma.crmFollowUp.findMany({
      where: {
        status: 'PENDING',
        completedActivityId: null,
        scheduledDate: {
          not: null,
          lte: futureLimit,
          gte: pastLimit,
        },
        reminderSentAt: null,
      },
      include: {
        customer: { select: { id: true, companyName: true } },
        assignedStaff: { select: { id: true, userId: true, fullName: true, status: true } },
      },
      take: 50,
    });

    let sent = 0;
    for (const item of candidates) {
      if (!item.scheduledDate) continue;

      const reminderMinutes = item.reminderMinutes != null ? item.reminderMinutes : 15;
      const reminderTriggerTime = new Date(item.scheduledDate.getTime() - reminderMinutes * 60 * 1000);

      // Only dispatch if current time has reached the reminder trigger threshold
      if (now < reminderTriggerTime) {
        continue;
      }

      // Atomic claim to guarantee idempotency across concurrent workers / server restarts
      const updated = await this.prisma.crmFollowUp.updateMany({
        where: {
          id: item.id,
          reminderSentAt: null,
          status: 'PENDING',
        },
        data: {
          reminderSentAt: now,
        },
      });

      if (updated.count === 0) {
        // Another instance/process already claimed this reminder
        continue;
      }

      // Dispatch notification
      const staff = item.assignedStaff;
      if (staff && staff.userId && staff.status === 'ACTIVE') {
        const customerName = item.customer?.companyName || 'Client';
        const formattedTime = formatISTTime(item.scheduledDate);
        try {
          await this.notificationService.notify({
            userId: staff.userId,
            title: `Reminder: Follow-up ${item.followUpNumber} is Due`,
            message: `Follow-up with ${customerName} is scheduled for ${formattedTime}. Subject: ${item.subject || item.title || 'Follow-up'}`,
            module: 'CRM',
            entityId: item.id,
          });
          sent++;
        } catch (err: any) {
          this.logger.error(`Failed to send due reminder notification for follow-up ${item.id}: ${err.message}`);
        }
      }
    }

    return { checked: candidates.length, sent };
  }

  /**
   * Step 2.C — Daily My Day Digest
   * Dispatches summary at 09:00 AM Asia/Kolkata with due, overdue, and scheduled activities.
   * Multi-instance safe and idempotent via unique constraint in `crm_digest_logs`.
   */
  async dispatchDailyDigest(
    targetDateStr?: string,
    enforceTimeWindow: boolean = false,
  ): Promise<{ staffProcessed: number; digestsSent: number }> {
    const now = new Date();
    const ist = getISTDateParts(now);

    if (enforceTimeWindow && ist.hours !== 9) {
      return { staffProcessed: 0, digestsSent: 0 };
    }

    const digestDate = targetDateStr || ist.dateStr;

    // Calculate IST day bounds for targetDate
    // Format: YYYY-MM-DD
    const [yStr, mStr, dStr] = digestDate.split('-');
    const year = parseInt(yStr, 10);
    const month = parseInt(mStr, 10) - 1;
    const day = parseInt(dStr, 10);

    // 00:00:00 IST is previous UTC day 18:30:00
    const startOfIstDayUtc = new Date(Date.UTC(year, month, day, 0, 0, 0, 0) - IST_OFFSET_MS);
    // 23:59:59.999 IST
    const endOfIstDayUtc = new Date(startOfIstDayUtc.getTime() + 24 * 60 * 60 * 1000 - 1);

    // Find all active staff who have an associated user account
    const staffList = await this.prisma.staff.findMany({
      where: {
        status: 'ACTIVE',
        userId: { not: null },
      },
      select: {
        id: true,
        userId: true,
        fullName: true,
        employeeId: true,
      },
    });

    let digestsSent = 0;

    for (const staff of staffList) {
      if (!staff.userId) continue;

      // Check if already dispatched for this date & staff
      const existing = await this.prisma.crmDigestLog.findUnique({
        where: {
          digestDate_staffId: {
            digestDate,
            staffId: staff.id,
          },
        },
      });
      if (existing) continue;

      // Query staff follow-ups
      const followUps = await this.prisma.crmFollowUp.findMany({
        where: {
          assignedStaffId: staff.id,
          status: { in: ['PENDING', 'OVERDUE'] },
          completedActivityId: null,
          customer: { status: { not: 'DELETED' } },
        },
        select: {
          id: true,
          scheduledDate: true,
          status: true,
          priority: true,
          followUpNumber: true,
          subject: true,
        },
      });

      // Filter due today vs overdue
      const dueToday = followUps.filter(
        (f) => f.scheduledDate && f.scheduledDate >= startOfIstDayUtc && f.scheduledDate <= endOfIstDayUtc,
      );
      const overdue = followUps.filter(
        (f) => (f.scheduledDate && f.scheduledDate < startOfIstDayUtc) || f.status === 'OVERDUE',
      );

      // Attempt atomic reservation in crm_digest_logs
      try {
        await this.prisma.crmDigestLog.create({
          data: {
            digestDate,
            staffId: staff.id,
            userId: staff.userId,
            activityCount: followUps.length,
            dispatchedAt: now,
          },
        });
      } catch (err: any) {
        if (err.code === 'P2002' || err.message?.includes('Unique constraint')) {
          // Another worker claimed this dispatch
          continue;
        }
        throw err;
      }

      // Dispatch digest notification
      try {
        const message = `Good morning, ${staff.fullName}! You have ${dueToday.length} follow-up(s) scheduled for today and ${overdue.length} overdue task(s).`;
        await this.notificationService.notify({
          userId: staff.userId,
          title: `My Day Digest — ${digestDate}`,
          message,
          module: 'CRM',
          entityId: staff.id,
        });
        digestsSent++;
      } catch (err: any) {
        this.logger.error(`Failed to send My Day digest to staff ${staff.id}: ${err.message}`);
      }
    }

    return { staffProcessed: staffList.length, digestsSent };
  }

  /**
   * Step 2.D — Overdue Escalation (24 Hours Overdue)
   * Dispatches escalation notification to Sales Manager at 06:00 PM Asia/Kolkata.
   * Resolves manager from staff hierarchy / customer manager / sales leadership.
   */
  async checkAndDispatchOverdueEscalations(
    enforceTimeWindow: boolean = false,
  ): Promise<{ checked: number; escalated: number }> {
    const now = new Date();
    const ist = getISTDateParts(now);

    if (enforceTimeWindow && ist.hours !== 18) {
      return { checked: 0, escalated: 0 };
    }

    // 24 hours overdue threshold
    const overdueThreshold = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const candidates = await this.prisma.crmFollowUp.findMany({
      where: {
        status: { in: ['PENDING', 'OVERDUE'] },
        completedActivityId: null,
        scheduledDate: {
          not: null,
          lte: overdueThreshold,
        },
        escalatedAt: null,
      },
      include: {
        customer: {
          select: {
            id: true,
            companyName: true,
            salesManagerStaffId: true,
            salesManagerStaff: {
              select: { id: true, userId: true, fullName: true, status: true },
            },
          },
        },
        assignedStaff: {
          select: {
            id: true,
            fullName: true,
            reportingManagerId: true,
            reportingManager: {
              select: { id: true, userId: true, fullName: true, status: true },
            },
          },
        },
      },
      take: 50,
    });

    let escalated = 0;

    for (const item of candidates) {
      // Resolve the Sales Manager:
      // 1. Customer's designated salesManagerStaff
      // 2. Assigned staff's reportingManager
      // 3. Any active Sales Manager staff in company
      let managerStaff =
        item.customer?.salesManagerStaff?.userId && item.customer.salesManagerStaff.status === 'ACTIVE'
          ? item.customer.salesManagerStaff
          : null;

      if (!managerStaff && item.assignedStaff?.reportingManager?.userId && item.assignedStaff.reportingManager.status === 'ACTIVE') {
        managerStaff = item.assignedStaff.reportingManager;
      }

      if (!managerStaff) {
        // Fallback: look for staff with Manager designation or Sales department head
        const fallbackManager = await this.prisma.staff.findFirst({
          where: {
            status: 'ACTIVE',
            userId: { not: null },
            OR: [
              { designation: { name: { contains: 'Manager' } } },
              { department: { code: 'SALES' } },
            ],
          },
          select: { id: true, userId: true, fullName: true, status: true },
        });
        if (fallbackManager?.userId) {
          managerStaff = fallbackManager;
        }
      }

      if (!managerStaff || !managerStaff.userId) {
        this.logger.warn(`No active manager found with userId to escalate follow-up ${item.id}`);
        continue;
      }

      // Atomic reservation to prevent double escalation
      const updated = await this.prisma.crmFollowUp.updateMany({
        where: {
          id: item.id,
          escalatedAt: null,
          status: { in: ['PENDING', 'OVERDUE'] },
        },
        data: {
          status: 'OVERDUE',
          escalatedAt: now,
          escalatedToStaffId: managerStaff.id,
        },
      });

      if (updated.count === 0) {
        // Already escalated by another worker
        continue;
      }

      // Send escalation notification
      const customerName = item.customer?.companyName || 'Client';
      const staffName = item.assignedStaff?.fullName || 'Assigned Staff';
      try {
        await this.notificationService.notify({
          userId: managerStaff.userId,
          title: `CRM Escalation: Overdue Follow-up (${item.followUpNumber})`,
          message: `Follow-up ${item.followUpNumber} for ${customerName} (assigned to ${staffName}) is overdue by more than 24 hours.`,
          module: 'CRM',
          entityId: item.id,
        });
        escalated++;
      } catch (err: any) {
        this.logger.error(`Failed to send escalation notification for follow-up ${item.id}: ${err.message}`);
      }
    }

    return { checked: candidates.length, escalated };
  }
}
