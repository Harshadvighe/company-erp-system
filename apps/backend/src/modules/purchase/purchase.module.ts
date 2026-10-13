import { Module } from '@nestjs/common';
import { PurchaseController } from './purchase.controller';
import { PurchaseService } from './purchase.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [PurchaseController],
  providers: [PurchaseService, AuditService, SequenceService],
  exports: [PurchaseService],
})
export class PurchaseModule {}
