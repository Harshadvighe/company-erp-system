import { Module } from '@nestjs/common';
import { AttendanceController } from './attendance.controller';
import { BiometricDeviceService } from './biometric-device.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  imports: [],
  controllers: [AttendanceController],
  providers: [BiometricDeviceService, PrismaService],
  exports: [BiometricDeviceService],
})
export class AttendanceModule {}