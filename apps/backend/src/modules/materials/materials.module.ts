import { Module } from '@nestjs/common';
import { MaterialsController } from './materials.controller';
import { MaterialsService } from './materials.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [MaterialsController],
  providers: [MaterialsService, AuditService],
  exports: [MaterialsService],
})
export class MaterialsModule {}
