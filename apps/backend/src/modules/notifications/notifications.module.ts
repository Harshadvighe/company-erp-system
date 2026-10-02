import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationService } from '../../core/notifications/notification.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationService, PrismaService],
  exports: [NotificationService],
})
export class NotificationsModule {}
