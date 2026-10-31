import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AttendanceController } from './attendance.controller';
import { BiometricDeviceService } from './biometric-device.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  imports: [ScheduleModule.forRoot()],
  controllers: [AttendanceController],
  providers: [BiometricDeviceService, PrismaService],
  exports: [BiometricDeviceService],
})
export class AttendanceModule {}