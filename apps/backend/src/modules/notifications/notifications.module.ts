import { Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationService } from '../../core/notifications/notification.service';
import { MailService } from '../../core/notifications/mail.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationService, MailService, PrismaService],
  exports: [NotificationService, MailService],
})
export class NotificationsModule {}
