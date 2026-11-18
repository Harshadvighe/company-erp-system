import { Module } from '@nestjs/common';
import { GovernanceService } from './governance.service';
import { GovernanceController } from './governance.controller';
import { MailService } from '../../core/notifications/mail.service';
import { AuditService } from '../../core/audit/audit.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  controllers: [GovernanceController],
  providers: [GovernanceService, MailService, AuditService, PrismaService],
  exports: [GovernanceService],
})
export class GovernanceModule {}

