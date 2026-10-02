import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

export interface AuditLogOptions {
  userId?: string;
  userEmail?: string;
  action: string; // CREATE, UPDATE, DELETE, LOGIN, APPROVE, EXPORT
  module: string; // CUSTOMERS, LEADS, PRODUCTS, PANEL_MFG, AUTH, ADMIN
  entityType?: string;
  entityId?: string;
  details?: string;
  ipAddress?: string;
}

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async log(options: AuditLogOptions) {
    try {
      return await this.prisma.auditLog.create({
        data: {
          userId: options.userId,
          userEmail: options.userEmail,
          action: options.action,
          module: options.module,
          entityType: options.entityType,
          entityId: options.entityId,
          details: options.details,
          ipAddress: options.ipAddress || '127.0.0.1',
        },
      });
    } catch (e) {
      console.error('Failed to log audit event:', e);
    }
  }

  async getRecentLogs(limit = 50) {
    return this.prisma.auditLog.findMany({
      orderBy: { timestamp: 'desc' },
      take: limit,
      include: {
        user: {
          select: { fullName: true, email: true, designation: true },
        },
      },
    });
  }
}
