import { Module } from '@nestjs/common';
import { StaffController } from './staff.controller';
import { StaffService } from './staff.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [StaffController],
  providers: [StaffService, AuditService],
  exports: [StaffService],
})
export class StaffModule {}
