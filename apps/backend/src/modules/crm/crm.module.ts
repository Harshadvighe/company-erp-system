import { Module } from '@nestjs/common';
import { CrmController } from './crm.controller';
import { CrmService } from './crm.service';
import { GstVerificationService } from './gst-verification.service';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [CrmController],
  providers: [CrmService, GstVerificationService, PrismaService, AuditService, SequenceService],
  exports: [CrmService, GstVerificationService],
})
export class CrmModule {}
