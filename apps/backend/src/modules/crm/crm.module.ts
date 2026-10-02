import { Module } from '@nestjs/common';
import { CrmController } from './crm.controller';
import { CrmService } from './crm.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [CrmController],
  providers: [CrmService, PrismaService, AuditService],
  exports: [CrmService],
})
export class CrmModule {}
