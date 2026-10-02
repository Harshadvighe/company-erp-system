import { Module } from '@nestjs/common';
import { PurchaseController } from './purchase.controller';
import { PurchaseService } from './purchase.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [PurchaseController],
  providers: [PurchaseService, PrismaService, AuditService],
  exports: [PurchaseService],
})
export class PurchaseModule {}
