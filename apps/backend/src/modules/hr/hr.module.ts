import { Module } from '@nestjs/common';
import { HrController } from './hr.controller';
import { HrService } from './hr.service';
import { SequenceService } from '../../core/database/sequence.service';

@Module({
  controllers: [HrController],
  providers: [HrService, SequenceService],
  exports: [HrService],
})
export class HrModule {}
