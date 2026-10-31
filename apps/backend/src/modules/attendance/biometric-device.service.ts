import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
  InternalServerErrorException,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  RegisterDeviceDto,
  UpdateDeviceDto,
  DeviceConnectionType,
  DeviceType,
  PunchType,
} from './dto/register-device.dto';
import {
  SyncAttendanceRequestDto,
  SyncResponseDto,
  SyncType,
  DevicePunchRecord,
} from './dto/sync-request.dto';
import * as net from 'net';

export interface DeviceConnectionResult {
  success: boolean;
  error?: string;
  data?: any;
}

export interface RawPunchData {
  userId: string;
  timestamp: Date;
  punchType: PunchType;
  devicePunchId?: string;
  verifyCode?: string;
  workCode?: number;
  sensorType?: number;
}

@Injectable()
export class BiometricDeviceService {
  private readonly logger = new Logger(BiometricDeviceService.name);
  private readonly socketTimeout = 10000;

  constructor(private readonly prisma: PrismaService) {}

  // =========================================================================
  // DEVICE MANAGEMENT
  // =========================================================================

  async registerDevice(dto: RegisterDeviceDto) {
    const existing = await this.prisma.biometricDevice.findUnique({
      where: { deviceCode: dto.deviceCode },
    });
    if (existing) {
      throw new BadRequestException(
        `Device with code '${dto.deviceCode}' already exists`,
      );
    }

    if (dto.connectionType === DeviceConnectionType.TCP_IP && dto.ipAddress) {
      const reachable = await this.testTcpConnection(
        dto.ipAddress,
        dto.port || 4370,
      );
      if (!reachable) {
        this.logger.warn(
          `Device ${dto.deviceCode} at ${dto.ipAddress}:${dto.port} is not reachable. Device registered but sync will fail until network is fixed.`,
        );
      }
    }

    const device = await this.prisma.biometricDevice.create({
      data: {
        deviceCode: dto.deviceCode,
        deviceName: dto.deviceName,
        deviceType: dto.deviceType || DeviceType.FINGERPRINT_FACE,
        manufacturer: dto.manufacturer || 'TeamOffice',
        model: dto.model,
        serialNumber: dto.serialNumber,
        ipAddress: dto.ipAddress,
        port: dto.port || 4370,
        connectionType: dto.connectionType || DeviceConnectionType.TCP_IP,
        apiEndpoint: dto.apiEndpoint,
        apiKey: dto.apiKey,
        apiSecret: dto.apiSecret,
        communicationKey: dto.communicationKey,
        autoSyncEnabled: dto.autoSyncEnabled ?? true,
        syncIntervalMinutes: dto.syncIntervalMinutes || 15,
        timezone: dto.timezone || 'Asia/Kolkata',
        location: dto.location,
        notes: dto.notes,
      },
    });

    this.logger.log(
      `Biometric device registered: ${device.deviceCode} (${device.ipAddress}:${device.port})`,
    );

    return {
      success: true,
      message: 'Device registered successfully',
      data: device,
    };
  }

  async getAllDevices() {
    return this.prisma.biometricDevice.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        _count: {
          select: { syncLogs: true, attendances: true },
        },
      },
    });
  }

  async getDeviceById(deviceId: string) {
    const device = await this.prisma.biometricDevice.findUnique({
      where: { id: deviceId },
      include: {
        syncLogs: {
          orderBy: { startedAt: 'desc' },
          take: 10,
        },
        attendances: {
          orderBy: { punchDate: 'desc' },
          take: 50,
        },
      },
    });
    if (!device) {
      throw new NotFoundException(`Device not found: ${deviceId}`);
    }
    return device;
  }

  async updateDevice(deviceId: string, dto: UpdateDeviceDto) {
    const device = await this.prisma.biometricDevice.findUnique({
      where: { id: deviceId },
    });
    if (!device) {
      throw new NotFoundException(`Device not found: ${deviceId}`);
    }

    return this.prisma.biometricDevice.update({
      where: { id: deviceId },
      data: { ...dto },
    });
  }

  async deleteDevice(deviceId: string) {
    const device = await this.prisma.biometricDevice.findUnique({
      where: { id: deviceId },
    });
    if (!device) {
      throw new NotFoundException(`Device not found: ${deviceId}`);
    }

    return this.prisma.biometricDevice.delete({
      where: { id: deviceId },
    });
  }

  // =========================================================================
  // DEVICE COMMUNICATION - TCP/IP (ZKTeco/TeamOffice Protocol)
  // =========================================================================

  async testTcpConnection(ip: string, port: number): Promise<boolean> {
    return new Promise((resolve) => {
      const socket = new net.Socket();
      let timedOut = false;

      const timeoutTimer = setTimeout(() => {
        timedOut = true;
        socket.destroy();
        resolve(false);
      }, this.socketTimeout);

      socket.on('connect', () => {
        if (!timedOut) {
          clearTimeout(timeoutTimer);
          socket.destroy();
          resolve(true);
        }
      });

      socket.on('error', () => {
        if (!timedOut) {
          clearTimeout(timeoutTimer);
          resolve(false);
        }
      });

      socket.connect(port, ip);
    });
  }

  async fetchPunchesFromTcpDevice(
    device: any,
    fromDate?: Date,
    toDate?: Date,
  ): Promise<{ success: boolean; punches?: RawPunchData[]; error?: string }> {
    if (!device.ipAddress) {
      return {
        success: false,
        error: 'Device IP address not configured',
      };
    }

    const port = device.port || 4370;
    const socket = new net.Socket();
    const punches: RawPunchData[] = [];

    return new Promise((resolve) => {
      let done = false;

      const timeoutTimer = setTimeout(() => {
        if (!done) {
          done = true;
          socket.destroy();
          resolve({
            success: false,
            error: `Connection timeout after ${this.socketTimeout}ms`,
          });
        }
      }, this.socketTimeout);

      socket.on('connect', () => {
        this.logger.log(
          `Connected to device ${device.deviceCode} at ${device.ipAddress}:${port}`,
        );
        const command = this.buildZkCommand(1, 0, device.communicationKey || '', '');
        socket.write(command);
      });

      socket.on('data', (chunk: Buffer) => {
        // Simplified: parse ZKLib attendance data from response
        try {
          const hexStr = chunk.toString('hex');
          const parts = hexStr.match(/.{1,8}/g) || [];
          if (parts.length >= 2) {
            const userId = parseInt(parts[0] || '0', 16).toString().padStart(4, '0');
            const timestampSeconds = parseInt(parts[1] || '0', 16);
            const timestamp = new Date(timestampSeconds * 1000);
            const punchTypeByte = parts[2] ? parseInt(parts[2].substring(0, 2), 16) : 0;
            punches.push({
              userId,
              timestamp,
              punchType: this.mapRawPunchType(punchTypeByte),
              devicePunchId: parts[3] ? parseInt(parts[3], 16).toString() : undefined,
            });
          }
        } catch (err) {
          this.logger.warn(`Failed to parse device data chunk: ${err.message}`);
        }
      });

      socket.on('close', () => {
        if (!done) {
          done = true;
          clearTimeout(timeoutTimer);
          resolve({
            success: punches.length > 0,
            punches: punches.length > 0 ? punches : undefined,
            error: punches.length === 0 ? 'No data received from device' : undefined,
          });
        }
      });

      socket.on('error', (err: Error) => {
        if (!done) {
          done = true;
          clearTimeout(timeoutTimer);
          resolve({
            success: false,
            error: `Socket error: ${err.message}`,
          });
        }
      });

      socket.connect(port, device.ipAddress);
    });
  }

  async fetchPunchesFromHttpDevice(
    device: any,
    fromDate?: Date,
    toDate?: Date,
  ): Promise<{ success: boolean; punches?: RawPunchData[]; error?: string }> {
    if (!device.apiEndpoint) {
      return {
        success: false,
        error: 'API endpoint not configured for HTTP device',
      };
    }

    const fromStr = fromDate ? fromDate.toISOString() : '';
    const toStr = toDate ? toDate.toISOString() : '';
    const url = `${device.apiEndpoint}/attendance/logs?from=${fromStr}&to=${toStr}`;

    return new Promise((resolve) => {
      const lib = require(device.apiEndpoint.startsWith('https:') ? 'https' : 'http');
      const options: any = {
        method: 'GET',
        timeout: this.socketTimeout,
        headers: {
          'Content-Type': 'application/json',
          ...(device.apiKey && { Authorization: `Bearer ${device.apiKey}` }),
        },
      };

      const req = lib.request(url, options, (res: any) => {
        let data = '';
        res.on('data', (chunk: string) => (data += chunk));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            const punches: RawPunchData[] = (parsed.punches || parsed.data || []).map(
              (p: any) => ({
                userId: p.userId || p.empId || p.employeeCode || p.uid,
                timestamp: new Date(p.timestamp || p.punchTime || p.time),
                punchType: this.mapPunchType(p.punchType || p.type || p.action),
                devicePunchId: p.devicePunchId || p.punchId || p.id,
                verifyCode: p.verifyCode || p.verification,
                workCode: p.workCode,
                sensorType: p.sensorType,
              }),
            );
            resolve({ success: true, punches });
          } catch (err: any) {
            resolve({
              success: false,
              error: `Failed to parse device response: ${err.message}`,
            });
          }
        });
      });

      req.on('error', (err: Error) => {
        resolve({ success: false, error: `HTTP request error: ${err.message}` });
      });

      req.on('timeout', () => {
        req.destroy();
        resolve({ success: false, error: 'Request timeout' });
      });

      req.end();
    });
  }

  async fetchPunchesFromDevice(
    deviceId: string,
    fromDate?: Date,
    toDate?: Date,
  ): Promise<{ success: boolean; punches?: RawPunchData[]; error?: string }> {
    const device = await this.prisma.biometricDevice.findUnique({
      where: { id: deviceId },
    });
    if (!device) {
      throw new NotFoundException(`Device not found: ${deviceId}`);
    }

    if (!device.isActive) {
      return {
        success: false,
        error: `Device ${device.deviceCode} is not active`,
      };
    }

    switch (device.connectionType) {
      case DeviceConnectionType.TCP_IP:
        return this.fetchPunchesFromTcpDevice(device, fromDate, toDate);
      case DeviceConnectionType.HTTP:
      case DeviceConnectionType.CLOUD:
        return this.fetchPunchesFromHttpDevice(device, fromDate, toDate);
      default:
        return {
          success: false,
          error: `Connection type ${device.connectionType} not supported for automatic fetch`,
        };
    }
  }

  // =========================================================================
  // ZKLib PROTOCOL HELPERS
  // =========================================================================

  private buildZkCommand(
    commandId: number,
    checksum: number,
    sessionId: string,
    data: string,
  ): Buffer {
    const header = Buffer.alloc(16);
    header.writeUInt16BE(0x55aa, 0);
    header.writeUInt16BE(0x0000, 2);
    header.writeUInt32BE(commandId, 4);
    header.writeUInt32BE(checksum, 8);
    header.writeUInt16BE(parseInt(sessionId) || 0, 12);
    header.writeUInt16BE(0, 14);
    const dataBuffer = Buffer.from(data, 'utf8');
    return Buffer.concat([header, dataBuffer]);
  }

  private mapPunchType(value: string | number): PunchType {
    const str = String(value).toUpperCase();
    if (str.includes('IN') || str.includes('CHECK_IN') || str === '0' || str === '1') {
      return PunchType.CHECK_IN;
    }
    if (str.includes('OUT') || str.includes('CHECK_OUT') || str === '2') {
      return PunchType.CHECK_OUT;
    }
    return PunchType.CHECK_IN;
  }

  // =========================================================================
  // ATTENDANCE SYNC
  // =========================================================================

  async syncDeviceAttendance(
    deviceId: string,
    dto: SyncAttendanceRequestDto,
  ): Promise<SyncResponseDto> {
    const device = await this.prisma.biometricDevice.findUnique({
      where: { id: deviceId },
    });
    if (!device) {
      throw new NotFoundException(`Device not found: ${deviceId}`);
    }

    const startTime = Date.now();

    try {
      const toDate = dto.toDate
        ? new Date(dto.toDate)
        : new Date();
      const fromDate = dto.fromDate
        ? new Date(dto.fromDate)
        : device.lastSyncAt || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

      const fetchResult = await this.fetchPunchesFromDevice(
        device.id,
        fromDate,
        toDate,
      );

      if (!fetchResult.success || !fetchResult.punches) {
        await this.prisma.biometricDevice.update({
          where: { id: deviceId },
          data: {
            lastSyncAt: new Date(),
            lastSyncStatus: 'FAILED',
            lastSyncError: fetchResult.error,
          },
        });

        return {
          status: 'FAILED',
          deviceCode: device.deviceCode,
          recordsFetched: 0,
          recordsInserted: 0,
          recordsSkipped: 0,
          recordsUpdated: 0,
          errorMessage: fetchResult.error,
          durationMs: Date.now() - startTime,
        };
      }

      const punches = fetchResult.punches;
      let recordsInserted = 0;
      let recordsSkipped = 0;
      let recordsUpdated = 0;
      const details: any[] = [];

      for (const punch of punches) {
        const result = await this.processPunchRecord(
          device,
          punch,
          dto.createMissing ?? true,
          dto.updateExisting ?? false,
        );
        details.push(result);

        if (result.action === 'inserted') recordsInserted++;
        else if (result.action === 'skipped') recordsSkipped++;
        else if (result.action === 'updated') recordsUpdated++;
      }

      const overallStatus =
        recordsInserted > 0 || recordsUpdated > 0 ? 'SUCCESS' : 'PARTIAL';

      await this.prisma.biometricDevice.update({
        where: { id: deviceId },
        data: {
          lastSyncAt: new Date(),
          lastSyncStatus: overallStatus,
          lastSyncRecordCount: punches.length,
          lastSyncError: null,
        },
      });

      this.logger.log(
        `Sync complete for ${device.deviceCode}: ${recordsInserted} inserted, ${recordsSkipped} skipped, ${recordsUpdated} updated`,
      );

      return {
        status: overallStatus,
        deviceCode: device.deviceCode,
        recordsFetched: punches.length,
        recordsInserted,
        recordsSkipped,
        recordsUpdated,
        durationMs: Date.now() - startTime,
        details,
      };
    } catch (err: any) {
      this.logger.error(`Sync failed for device ${device.deviceCode}`, err);

      await this.prisma.biometricDevice.update({
        where: { id: deviceId },
        data: {
          lastSyncAt: new Date(),
          lastSyncStatus: 'FAILED',
          lastSyncError: err.message,
        },
      });

      return {
        status: 'FAILED',
        deviceCode: device.deviceCode,
        recordsFetched: 0,
        recordsInserted: 0,
        recordsSkipped: 0,
        recordsUpdated: 0,
        errorMessage: err.message,
        durationMs: Date.now() - startTime,
      };
    }
  }

  private async processPunchRecord(
    device: any,
    punch: RawPunchData,
    createMissing: boolean,
    updateExisting: boolean,
  ) {
    const detail: any = {
      devicePunchId: punch.devicePunchId,
      userId: punch.userId,
      timestamp: punch.timestamp,
      action: 'skipped',
      reason: '',
    };

    const employee = await this.prisma.employee.findFirst({
      where: {
        OR: [
          { employeeCode: punch.userId },
          { id: punch.userId },
        ],
      },
    });

    if (!employee) {
      detail.action = 'skipped';
      detail.reason = `Employee not found for user ID: ${punch.userId}`;
      return detail;
    }

    const punchDate = new Date(punch.timestamp);
    punchDate.setHours(0, 0, 0, 0);

    const existing = await this.prisma.attendance.findUnique({
      where: {
        employeeId_punchDate: {
          employeeId: employee.id,
          punchDate,
        },
      },
    });

    const shiftCode = employee.shiftCode || 'SHIFT_G';
    const isCheckIn = punch.punchType === PunchType.CHECK_IN;
    const isCheckOut = punch.punchType === PunchType.CHECK_OUT;

    if (existing) {
      if (updateExisting) {
        const updateData: any = {
          deviceId: device.id,
          devicePunchId: punch.devicePunchId || existing.devicePunchId,
          source: 'DEVICE',
        };

        if (isCheckIn && !existing.punchIn) {
          updateData.punchIn = punch.timestamp;
        }
        if (isCheckOut && !existing.punchOut) {
          updateData.punchOut = punch.timestamp;
        }

        if (updateData.punchIn || updateData.punchOut) {
          const finalPunchIn = updateData.punchIn ?? existing.punchIn;
          const finalPunchOut = updateData.punchOut ?? existing.punchOut;
          if (finalPunchIn && finalPunchOut) {
            const diffMs = finalPunchOut.getTime() - finalPunchIn.getTime();
            updateData.workHours = Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100;
          }
        }

        await this.prisma.attendance.update({
          where: {
            employeeId_punchDate: {
              employeeId: employee.id,
              punchDate,
            },
          },
          data: updateData,
        });

        detail.action = 'updated';
        detail.reason = 'Attendance record updated from device';
      } else {
        detail.action = 'skipped';
        detail.reason = 'Attendance record already exists (updateExisting=false)';
      }
      return detail;
    }

    if (!createMissing) {
      detail.action = 'skipped';
      detail.reason = 'createMissing=false and no existing record';
      return detail;
    }

    const punchIn = isCheckIn ? punch.timestamp : null;
    const punchOut = isCheckOut ? punch.timestamp : null;

    let workHours = 0;
    if (punchIn && punchOut) {
      const diffMs = punchOut.getTime() - punchIn.getTime();
      workHours = Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100;
    }

    const status = this.determineAttendanceStatus(
      punchIn,
      punchOut,
      workHours,
      shiftCode,
    );

    await this.prisma.attendance.create({
      data: {
        employeeId: employee.id,
        punchDate,
        punchIn,
        punchOut,
        workHours,
        status,
        shiftCode,
        deviceId: device.id,
        devicePunchId: punch.devicePunchId,
        source: 'DEVICE',
        location: device.location,
      },
    });

    detail.action = 'inserted';
    detail.reason = 'New attendance record created from device punch';
    return detail;
  }

  private determineAttendanceStatus(
    punchIn: Date | null,
    punchOut: Date | null,
    workHours: number,
    shiftCode: string,
  ): string {
    if (!punchIn && !punchOut) return 'ABSENT';
    if (!punchIn || !punchOut) return 'HALF_DAY';

    const shiftStartTimes: Record<string, { hour: number; minute: number }> = {
      SHIFT_G: { hour: 9, minute: 0 },
      SHIFT_A: { hour: 6, minute: 30 },
      SHIFT_B: { hour: 14, minute: 0 },
      SHIFT_N: { hour: 22, minute: 0 },
    };

    const shiftStart = shiftStartTimes[shiftCode] || shiftStartTimes.SHIFT_G;
    const punchInDate = new Date(punchIn);
    const punchInHour = punchInDate.getHours();
    const punchInMinute = punchInDate.getMinutes();

    const shiftStartMinutes = shiftStart.hour * 60 + shiftStart.minute;
    const punchInMinutes = punchInHour * 60 + punchInMinute;
    const lateMinutes = punchInMinutes - shiftStartMinutes;

    if (lateMinutes > 15) return 'LATE';
    if (workHours < 4) return 'HALF_DAY';
    return 'PRESENT';
  }

  private mapRawPunchType(byteValue: number): PunchType {
    switch (byteValue) {
      case 0:
      case 1:
        return PunchType.CHECK_IN;
      case 2:
        return PunchType.CHECK_OUT;
      case 3:
        return PunchType.BREAK_OUT;
      case 4:
        return PunchType.BREAK_IN;
      default:
        return PunchType.CHECK_IN;
    }
  }

  // =========================================================================
  // AUTO SYNC CRON JOB
  // =========================================================================

  @Cron(CronExpression.EVERY_15_MINUTES)
  async autoSyncAllDevices() {
    this.logger.log('Running automatic biometric device sync...');

    const devices = await this.prisma.biometricDevice.findMany({
      where: {
        isActive: true,
        autoSyncEnabled: true,
      },
    });

    for (const device of devices) {
      try {
        if (device.lastSyncAt) {
          const lastSync = new Date(device.lastSyncAt);
          const now = new Date();
          const minutesSinceLastSync =
            (now.getTime() - lastSync.getTime()) / (1000 * 60);
          if (minutesSinceLastSync < (device.syncIntervalMinutes || 15)) {
            continue;
          }
        }

        const fromDate = device.lastSyncAt
          ? new Date(device.lastSyncAt.getTime() - 60 * 60 * 1000)
          : new Date(Date.now() - 24 * 60 * 60 * 1000);

        await this.syncDeviceAttendance(device.id, {
          syncType: SyncType.AUTO,
          fromDate: fromDate.toISOString(),
          toDate: new Date().toISOString(),
          createMissing: true,
          updateExisting: false,
        });
      } catch (err: any) {
        this.logger.error(
          `Auto-sync failed for device ${device.deviceCode}`,
          err.message,
        );
      }
    }

    this.logger.log('Automatic biometric device sync completed');
  }

  // =========================================================================
  // CONNECTION TEST
  // =========================================================================

  async testDeviceConnection(deviceId: string) {
    const device = await this.prisma.biometricDevice.findUnique({
      where: { id: deviceId },
    });
    if (!device) {
      throw new NotFoundException(`Device not found: ${deviceId}`);
    }

    let result: { success: boolean; message: string; latencyMs?: number };

    switch (device.connectionType) {
      case DeviceConnectionType.TCP_IP:
        const start = Date.now();
        const reachable = await this.testTcpConnection(
          device.ipAddress!,
          device.port,
        );
        result = {
          success: reachable,
          message: reachable
            ? `Device ${device.deviceCode} is reachable at ${device.ipAddress}:${device.port}`
            : `Device ${device.deviceCode} is NOT reachable at ${device.ipAddress}:${device.port}`,
          latencyMs: reachable ? Date.now() - start : undefined,
        };
        break;
      case DeviceConnectionType.HTTP:
      case DeviceConnectionType.CLOUD:
        try {
          const httpStart = Date.now();
          const fetchResult = await this.fetchPunchesFromHttpDevice(
            device,
            new Date(Date.now() - 24 * 60 * 60 * 1000),
            new Date(),
          );
          result = {
            success: fetchResult.success,
            message: fetchResult.success
              ? `HTTP device ${device.deviceCode} responded successfully`
              : `HTTP device ${device.deviceCode} error: ${fetchResult.error}`,
            latencyMs: fetchResult.success ? Date.now() - httpStart : undefined,
          };
        } catch (err: any) {
          result = {
            success: false,
            message: `HTTP device ${device.deviceCode} error: ${err.message}`,
          };
        }
        break;
      default:
        result = {
          success: false,
          message: `Connection type ${device.connectionType} cannot be tested automatically`,
        };
    }

    return result;
  }

  async getSyncLogs(deviceId?: string, status?: string, limit = 50) {
    return this.prisma.deviceSyncLog.findMany({
      where: {
        ...(deviceId && { deviceId }),
        ...(status && { syncStatus: status }),
      },
      orderBy: { startedAt: 'desc' },
      take: limit,
    });
  }

  async onModuleDestroy() {
    this.logger.log('BiometricDeviceService destroyed');
  }