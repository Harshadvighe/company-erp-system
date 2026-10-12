import { Module } from '@nestjs/common';
import { HrController } from './hr.controller';
import { HrService } from './hr.service';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';

@Module({
  controllers: [HrController],
  providers: [HrService, PrismaService, SequenceService],
  exports: [HrService],
})
export class HrModule {}
