import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AttendanceSyncController } from './attendance-sync.controller';
import { BiometricDeviceService } from './biometric-device.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  imports: [ScheduleModule.forRoot()],
  controllers: [AttendanceSyncController],
  providers: [BiometricDeviceService, PrismaService],
  exports: [BiometricDeviceService],
})
export class AttendanceSyncModule {}