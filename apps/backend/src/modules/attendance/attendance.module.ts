import { Module } from '@nestjs/common';
import { AttendanceSyncController } from './attendance-sync.controller';
import { BiometricDeviceService } from './biometric-device.service';
import { TeamworkSyncService } from './teamwork-sync.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  imports: [],
  controllers: [AttendanceSyncController],
  providers: [BiometricDeviceService, TeamworkSyncService, PrismaService],
  exports: [BiometricDeviceService, TeamworkSyncService],
})
export class AttendanceSyncModule {}