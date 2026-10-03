import { Module } from '@nestjs/common';
import { TasksController } from './tasks.controller';
import { TasksService } from './tasks.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import { NotificationService } from '../../core/notifications/notification.service';

@Module({
  controllers: [TasksController],
  providers: [TasksService, PrismaService, AuditService, NotificationService],
  exports: [TasksService],
})
export class TasksModule {}
