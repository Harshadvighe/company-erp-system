import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

export interface CreateNotificationOptions {
  userId: string;
  title: string;
  message: string;
  module: string;
  entityId?: string;
}

@Injectable()
export class NotificationService {
  constructor(private readonly prisma: PrismaService) {}

  async notify(options: CreateNotificationOptions) {
    return this.prisma.notification.create({
      data: {
        userId: options.userId,
        title: options.title,
        message: options.message,
        module: options.module,
        entityId: options.entityId,
      },
    });
  }

  async getUserNotifications(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }

  async markAsRead(notificationId: string, userId: string) {
    return this.prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { isRead: true },
    });
  }
}
