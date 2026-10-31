import { Module } from '@nestjs/common';
import { PanelManufacturingController } from './panel-manufacturing.controller';
import { PanelManufacturingService } from './panel-manufacturing.service';
import { BoosterPumpCalculatorService } from './booster-pump-calculator.service';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';

@Module({
  controllers: [PanelManufacturingController],
  providers: [PanelManufacturingService, BoosterPumpCalculatorService, PrismaService, SequenceService],
  exports: [PanelManufacturingService, BoosterPumpCalculatorService],
})
export class PanelManufacturingModule {}
