import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

export interface AuditActorSnapshot {
  userId?: string;
  userEmail?: string;
  employeeId?: string;
  fullName?: string;
  roles?: string[];
}

export interface AuditLogOptions {
  userId?: string;
  userEmail?: string;
  action: string; // CREATE, UPDATE, DELETE, LOGIN, APPROVE, EXPORT, etc.
  module: string; // CRM, SALES, PURCHASE, INVENTORY, PRODUCTION, HR, STAFF, PROJECTS, TASKS, VENDORS, CUSTOMERS, ADMIN, AUDIT, etc.
  entityType?: string;
  entityId?: string;
  details?: string | Record<string, any>;
  ipAddress?: string;
}

export interface DetailedAuditOptions {
  actor?: AuditActorSnapshot | any;
  userId?: string;
  userEmail?: string;
  action: string;
  module: string;
  entityType?: string;
  entityId?: string;
  before?: Record<string, any> | null;
  after?: Record<string, any> | null;
  changedFields?: string[];
  outcome?: 'SUCCESS' | 'FAILED' | 'DENIED';
  reason?: string;
  ipAddress?: string;
  requestId?: string;
  details?: any;
  req?: any;
  tx?: any; // Optional Prisma transaction client
}

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Recursively redacts passwords, tokens, API keys, credentials, and sensitive financial/PII data.
   */
  redact(data: any): any {
    if (data === null || data === undefined) {
      return data;
    }

    if (typeof data === 'string' || typeof data === 'number' || typeof data === 'boolean') {
      return data;
    }

    if (data instanceof Date) {
      return data.toISOString();
    }

    if (Array.isArray(data)) {
      return data.map((item) => this.redact(item));
    }

    if (typeof data === 'object') {
      const sensitiveKeyRegex = /password|hash|token|secret|jwt|bearer|key|authorization|cookie|card|cvv|pin|aadhaar|pan|bankaccount|accountnumber/i;
      const redacted: Record<string, any> = {};

      for (const [key, value] of Object.entries(data)) {
        if (sensitiveKeyRegex.test(key)) {
          redacted[key] = '[REDACTED]';
        } else if (typeof value === 'object' && value !== null) {
          redacted[key] = this.redact(value);
        } else {
          redacted[key] = value;
        }
      }
      return redacted;
    }

    return data;
  }

  /**
   * Computes changed fields and before/after difference maps.
   */
  computeDiff(before: any, after: any): { changedFields: string[]; beforeDiff: Record<string, any>; afterDiff: Record<string, any> } {
    const changedFields: string[] = [];
    const beforeDiff: Record<string, any> = {};
    const afterDiff: Record<string, any> = {};

    if (!before && !after) {
      return { changedFields, beforeDiff, afterDiff };
    }

    const b = before && typeof before === 'object' ? before : {};
    const a = after && typeof after === 'object' ? after : {};

    const allKeys = Array.from(new Set([...Object.keys(b), ...Object.keys(a)]));

    // Exclude noisy internal fields from diff reporting
    const ignoredKeys = new Set(['updatedAt', 'timestamp', 'password', 'passwordHash']);

    for (const key of allKeys) {
      if (ignoredKeys.has(key)) continue;

      const valB = b[key];
      const valA = a[key];

      const strB = typeof valB === 'object' ? JSON.stringify(valB) : String(valB ?? '');
      const strA = typeof valA === 'object' ? JSON.stringify(valA) : String(valA ?? '');

      if (strB !== strA) {
        changedFields.push(key);
        beforeDiff[key] = valB !== undefined ? valB : null;
        afterDiff[key] = valA !== undefined ? valA : null;
      }
    }

    return {
      changedFields,
      beforeDiff: this.redact(beforeDiff),
      afterDiff: this.redact(afterDiff),
    };
  }

  /**
   * Extracts an actor snapshot from a user object or Express request.
   */
  extractActorSnapshot(source?: any): AuditActorSnapshot {
    if (!source) return {};

    const user = source.user || source;
    return {
      userId: user.id || user.userId || user.sub,
      userEmail: user.email || user.userEmail,
      employeeId: user.employeeId || user.staffId,
      fullName: user.fullName || user.name || (user.firstName ? `${user.firstName} ${user.lastName || ''}`.trim() : undefined),
      roles: Array.isArray(user.roles) ? user.roles : user.role ? [user.role] : [],
    };
  }

  /**
   * Primary centralized audit logger recording actor, record diffs, outcome, and request ID.
   */
  async recordAction(options: DetailedAuditOptions) {
    try {
      const actorSource = options.actor || options.req?.user || {
        id: options.userId,
        email: options.userEmail,
      };

      const actorSnapshot = this.extractActorSnapshot(actorSource);

      let ipAddress = options.ipAddress || (actorSource as any)?.ip;
      let requestId = options.requestId || (actorSource as any)?.requestId;

      if (options.req) {
        ipAddress =
          ipAddress ||
          options.req.ip ||
          options.req.headers?.['x-forwarded-for'] ||
          options.req.socket?.remoteAddress ||
          '127.0.0.1';
        requestId =
          requestId ||
          options.req.headers?.['x-request-id'] ||
          options.req.headers?.['x-correlation-id'] ||
          options.req.id;
      }

      // Compute diff if before/after provided
      let changedFields = options.changedFields;
      let beforeData = options.before;
      let afterData = options.after;

      if ((beforeData || afterData) && !changedFields) {
        const diff = this.computeDiff(beforeData, afterData);
        changedFields = diff.changedFields;
        beforeData = diff.beforeDiff;
        afterData = diff.afterDiff;
      } else {
        beforeData = this.redact(beforeData);
        afterData = this.redact(afterData);
      }

      // Prepare structured details JSON
      let rawDetails = options.details;
      if (typeof rawDetails === 'string') {
        try {
          rawDetails = JSON.parse(rawDetails);
        } catch {
          rawDetails = { message: rawDetails };
        }
      }

      const structuredPayload = {
        actor: actorSnapshot,
        outcome: options.outcome || 'SUCCESS',
        requestId: requestId || undefined,
        reason: options.reason || undefined,
        changedFields: changedFields && changedFields.length > 0 ? changedFields : undefined,
        before: beforeData || undefined,
        after: afterData || undefined,
        meta: rawDetails ? this.redact(rawDetails) : undefined,
      };

      const client = options.tx || this.prisma;

      return await client.auditLog.create({
        data: {
          userId: actorSnapshot.userId || options.userId || null,
          userEmail: actorSnapshot.userEmail || options.userEmail || null,
          action: options.action,
          module: options.module,
          entityType: options.entityType || null,
          entityId: options.entityId || null,
          details: JSON.stringify(structuredPayload),
          ipAddress: (typeof ipAddress === 'string' ? ipAddress.split(',')[0].trim() : '127.0.0.1') || '127.0.0.1',
          // timestamp is UTC DateTime @default(now()) in Prisma
        },
      });
    } catch (e) {
      console.error('[AuditService] Failed to record audit action:', e);
      return null;
    }
  }

  /**
   * Backwards-compatible legacy logger method.
   */
  async log(options: AuditLogOptions) {
    return this.recordAction({
      userId: options.userId,
      userEmail: options.userEmail,
      action: options.action,
      module: options.module,
      entityType: options.entityType,
      entityId: options.entityId,
      details: options.details,
      ipAddress: options.ipAddress,
    });
  }

  /**
   * Safe failed authorization logger without recording secrets or sensitive request bodies.
   */
  async logAuthFailure(options: {
    req: any;
    user?: any;
    requiredPermissions?: string[];
    reason?: string;
  }) {
    try {
      const req = options.req || {};
      const user = options.user || req.user;
      const path = req.originalUrl || req.url || req.path || 'UNKNOWN_ROUTE';
      const method = req.method || 'GET';

      const moduleName =
        options.requiredPermissions && options.requiredPermissions.length > 0
          ? options.requiredPermissions[0].split(':')[0]
          : 'SECURITY';

      return await this.recordAction({
        req,
        actor: user,
        action: 'AUTHORIZATION_DENIED',
        module: moduleName,
        entityType: 'ENDPOINT',
        entityId: `${method} ${path}`,
        outcome: 'DENIED',
        reason: options.reason || 'Missing required permission',
        details: {
          method,
          path,
          requiredPermissions: options.requiredPermissions || [],
        },
      });
    } catch (e) {
      console.error('[AuditService] Failed to record authorization failure audit:', e);
      return null;
    }
  }

  /**
   * Helper to construct Prisma where clause for audit filtering across SQLite and PostgreSQL.
   */
  private buildWhereClause(filter: any) {
    const where: any = {};

    if (filter.module && filter.module !== 'ALL') {
      where.module = filter.module.toUpperCase();
    }

    if (filter.action && filter.action !== 'ALL') {
      where.action = filter.action.toUpperCase();
    }

    if (filter.entityId) {
      where.entityId = { contains: filter.entityId };
    }

    if (filter.userId) {
      where.userId = filter.userId;
    }

    if (filter.startDate || filter.endDate) {
      where.timestamp = {};
      if (filter.startDate) {
        where.timestamp.gte = new Date(filter.startDate);
      }
      if (filter.endDate) {
        const end = new Date(filter.endDate);
        if (typeof filter.endDate === 'string' && filter.endDate.length <= 10) {
          end.setHours(23, 59, 59, 999);
        }
        where.timestamp.lte = end;
      }
    }

    if (filter.outcome && filter.outcome !== 'ALL') {
      const outcomeVal = filter.outcome.toUpperCase();
      if (outcomeVal === 'DENIED') {
        where.OR = [
          { action: 'AUTHORIZATION_DENIED' },
          { details: { contains: '"outcome":"DENIED"' } },
        ];
      } else {
        where.details = { contains: `"outcome":"${outcomeVal}"` };
      }
    }

    if (filter.search) {
      const term = filter.search.trim();
      const searchConditions = [
        { userEmail: { contains: term } },
        { entityId: { contains: term } },
        { details: { contains: term } },
        { user: { fullName: { contains: term } } },
      ];
      if (where.OR) {
        where.AND = [{ OR: where.OR }, { OR: searchConditions }];
        delete where.OR;
      } else {
        where.OR = searchConditions;
      }
    }

    return where;
  }

  /**
   * Safe CSV cell escaping complying with RFC 4180.
   */
  private escapeCsvCell(val: any): string {
    if (val === null || val === undefined) return '""';
    const str = String(val).replace(/"/g, '""');
    return `"${str}"`;
  }

  /**
   * Paginated retrieval of audit logs matching rich enterprise filters.
   */
  async getLogs(filter: any = {}) {
    const page = Math.max(1, Number(filter.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(filter.limit) || 25));
    const skip = (page - 1) * limit;

    const where = this.buildWhereClause(filter);

    const [total, records] = await Promise.all([
      this.prisma.auditLog.count({ where }),
      this.prisma.auditLog.findMany({
        where,
        orderBy: { timestamp: 'desc' },
        skip,
        take: limit,
        include: {
          user: {
            select: { id: true, fullName: true, email: true, designation: true },
          },
        },
      }),
    ]);

    const data = records.map((log) => {
      let parsed = null;
      if (log.details) {
        try {
          parsed = JSON.parse(log.details);
        } catch {
          parsed = { raw: log.details };
        }
      }
      return {
        ...log,
        details: parsed,
      };
    });

    return {
      success: true,
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1,
      },
    };
  }

  /**
   * Detailed view of a single audit log event by ID.
   */
  async getLogById(id: string) {
    const log = await this.prisma.auditLog.findUnique({
      where: { id },
      include: {
        user: {
          select: { id: true, fullName: true, email: true, designation: true },
        },
      },
    });

    if (!log) {
      throw new NotFoundException(`Audit log event with ID ${id} not found`);
    }

    let parsed = null;
    if (log.details) {
      try {
        parsed = JSON.parse(log.details);
      } catch {
        parsed = { raw: log.details };
      }
    }

    return {
      success: true,
      data: {
        ...log,
        details: parsed,
      },
    };
  }

  /**
   * Generates CSV export with active filter criteria and records an EXPORT audit event.
   */
  async exportLogsToCsv(filter: any = {}, actor?: any, req?: any): Promise<string> {
    const where = this.buildWhereClause(filter);
    const logs = await this.prisma.auditLog.findMany({
      where,
      orderBy: { timestamp: 'desc' },
      take: 5000,
      include: {
        user: {
          select: { id: true, fullName: true, email: true, designation: true },
        },
      },
    });

    const headers = [
      'Log ID',
      'Timestamp (UTC)',
      'Actor User ID',
      'Actor Email',
      'Actor Name',
      'Actor Roles',
      'Module',
      'Action',
      'Entity Type',
      'Entity ID',
      'Outcome',
      'Request ID',
      'IP Address',
      'Changed Fields',
      'Reason',
    ];

    const rows = [headers.map((h) => this.escapeCsvCell(h)).join(',')];

    for (const log of logs) {
      let parsed: any = {};
      if (log.details) {
        try {
          parsed = JSON.parse(log.details);
        } catch {
          parsed = { raw: log.details };
        }
      }

      const row = [
        log.id,
        log.timestamp.toISOString(),
        parsed.actor?.userId || log.userId || '',
        parsed.actor?.userEmail || log.userEmail || log.user?.email || '',
        parsed.actor?.fullName || log.user?.fullName || '',
        Array.isArray(parsed.actor?.roles)
          ? parsed.actor.roles.join(';')
          : (log.user?.designation || ''),
        log.module,
        log.action,
        log.entityType || '',
        log.entityId || '',
        parsed.outcome || (log.action === 'AUTHORIZATION_DENIED' ? 'DENIED' : 'SUCCESS'),
        parsed.requestId || '',
        log.ipAddress || '',
        Array.isArray(parsed.changedFields) ? parsed.changedFields.join('; ') : '',
        parsed.reason || '',
      ];

      rows.push(row.map((cell) => this.escapeCsvCell(cell)).join(','));
    }

    // Record audit event for export execution
    await this.recordAction({
      req,
      actor: actor || req?.user,
      action: 'EXPORT',
      module: 'AUDIT',
      entityType: 'AuditLog',
      details: {
        filterCriteria: {
          module: filter.module,
          action: filter.action,
          outcome: filter.outcome,
          search: filter.search,
          startDate: filter.startDate,
          endDate: filter.endDate,
        },
        exportedCount: logs.length,
      },
      outcome: 'SUCCESS',
      reason: 'Admin CSV export of audit logs',
    });

    return rows.join('\r\n');
  }

  /**
   * Backward-compatible legacy recent logs fetcher.
   */
  async getRecentLogs(limit = 50) {
    const res = await this.getLogs({ limit });
    return res.data;
  }
}
