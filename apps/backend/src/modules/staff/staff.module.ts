import { Module } from '@nestjs/common';
import { StaffController } from './staff.controller';
import { StaffService } from './staff.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [StaffController],
  providers: [StaffService, PrismaService, AuditService],
  exports: [StaffService],
})
export class StaffModule {}
