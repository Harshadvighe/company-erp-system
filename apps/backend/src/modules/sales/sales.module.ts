import { Module } from '@nestjs/common';
import { SalesController } from './sales.controller';
import { SalesService } from './sales.service';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';

@Module({
  controllers: [SalesController],
  providers: [SalesService, PrismaService, SequenceService],
  exports: [SalesService],
})
export class SalesModule {}
