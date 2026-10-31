import { Module } from '@nestjs/common';
import { AttendanceSyncController } from './attendance-sync.controller';
import { BiometricDeviceService } from './biometric-device.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  imports: [],
  controllers: [AttendanceSyncController],
  providers: [BiometricDeviceService, PrismaService],
  exports: [BiometricDeviceService],
})
export class AttendanceSyncModule {}