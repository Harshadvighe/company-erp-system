import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { BiometricDeviceService } from './biometric-device.service';
import {
  RegisterDeviceDto,
  UpdateDeviceDto,
  DeviceConnectionType,
  DeviceType,
} from './dto/register-device.dto';
import {
  SyncAttendanceRequestDto,
  SyncResponseDto,
} from './dto/sync-request.dto';

@ApiTags('Attendance Sync - Biometric Punching Device Integration')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/attendance-sync')
export class AttendanceController {
  constructor(
    private readonly deviceService: BiometricDeviceService,
  ) {}

  // =========================================================================
  // DEVICE MANAGEMENT
  // =========================================================================

  @Post('devices')
  @ApiOperation({ summary: 'Register a new biometric punching device' })
  async registerDevice(@Body() dto: RegisterDeviceDto) {
    return this.deviceService.registerDevice(dto);
  }

  @Get('devices')
  @ApiOperation({ summary: 'List all registered biometric devices' })
  async getAllDevices() {
    return this.deviceService.getAllDevices();
  }

  @Get('devices/:id')
  @ApiOperation({ summary: 'Get device details with sync logs and recent attendance' })
  async getDevice(@Param('id') id: string) {
    return this.deviceService.getDeviceById(id);
  }

  @Put('devices/:id')
  @ApiOperation({ summary: 'Update biometric device configuration' })
  async updateDevice(@Param('id') id: string, @Body() dto: UpdateDeviceDto) {
    return this.deviceService.updateDevice(id, dto);
  }

  @Delete('devices/:id')
  @ApiOperation({ summary: 'Delete a biometric device' })
  async deleteDevice(@Param('id') id: string) {
    return this.deviceService.deleteDevice(id);
  }

  @Post('devices/:id/test')
  @ApiOperation({ summary: 'Test connectivity to a biometric device' })
  async testDeviceConnection(@Param('id') id: string) {
    return this.deviceService.testDeviceConnection(id);
  }

  // =========================================================================
  // ATTENDANCE SYNC
  // =========================================================================

  @Post('devices/:id/sync')
  @ApiOperation({ summary: 'Sync attendance punches from a biometric device' })
  async syncDeviceAttendance(
    @Param('id') id: string,
    @Body() dto: SyncAttendanceRequestDto,
  ): Promise<SyncResponseDto> {
    return this.deviceService.syncDeviceAttendance(id, dto);
  }

  @Get('sync-logs')
  @ApiOperation({ summary: 'Get all device sync logs' })
  async getSyncLogs(
    @Query('deviceId') deviceId?: string,
    @Query('status') status?: string,
    @Query('limit') limit?: string,
  ) {
    return this.deviceService.getSyncLogs(deviceId, status, limit ? parseInt(limit) : 50);
  }

  @Get('device-types')
  @ApiOperation({ summary: 'Get supported device types and connection methods' })
  getDeviceTypes() {
    return {
      connectionTypes: Object.values(DeviceConnectionType),
      deviceTypes: Object.values(DeviceType),
      defaultPort: 4370,
      defaultTimezone: 'Asia/Kolkata',
      supportedManufacturers: [
        'TeamOffice',
        'ZKTeco',
        'Suprema',
        'Hikvision',
        'ESSL',
        'Mantra',
        'Other',
      ],
    };
  }
}
export { AttendanceController as AttendanceSyncController };
