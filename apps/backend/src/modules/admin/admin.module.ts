import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { DatabaseExplorerController } from './database-explorer.controller';
import { AdminService } from './admin.service';
import { PrismaService } from '../../core/database/prisma.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [AdminController, DatabaseExplorerController],
  providers: [AdminService, PrismaService],
  exports: [AdminService],
})
export class AdminModule {}

