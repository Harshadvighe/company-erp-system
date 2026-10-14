import { Module } from '@nestjs/common';
import { PanelManufacturingController } from './panel-manufacturing.controller';
import { PanelManufacturingService } from './panel-manufacturing.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [PanelManufacturingController],
  providers: [PanelManufacturingService, SequenceService, AuditService],
  exports: [PanelManufacturingService],
})
export class PanelManufacturingModule {}
