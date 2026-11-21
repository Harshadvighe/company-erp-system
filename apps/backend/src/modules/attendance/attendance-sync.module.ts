import { Module } from '@nestjs/common';
import { AttendanceController } from './attendance.controller';
import { BiometricDeviceService } from './biometric-device.service';
import { TeamworkSyncService } from './teamwork-sync.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  imports: [],
  controllers: [AttendanceController],
  providers: [BiometricDeviceService, TeamworkSyncService, PrismaService],
  exports: [BiometricDeviceService, TeamworkSyncService],
})
export class AttendanceModule {}