import { Module } from '@nestjs/common';
import { B2bTradingController } from './b2b-trading.controller';
import { B2bTradingService } from './b2b-trading.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  controllers: [B2bTradingController],
  providers: [B2bTradingService, PrismaService],
  exports: [B2bTradingService],
})
export class B2bTradingModule {}
