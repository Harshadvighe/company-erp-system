import { IsString, IsOptional, IsDateString, IsEnum, IsBoolean, IsInt, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum SyncType {
  MANUAL = 'MANUAL',
  AUTO = 'AUTO',
  WEBHOOK = 'WEBHOOK',
}

export enum PunchType {
  CHECK_IN = 'CHECK_IN',
  CHECK_OUT = 'CHECK_OUT',
  BREAK_OUT = 'BREAK_OUT',
  BREAK_IN = 'BREAK_IN',
}

export class SyncAttendanceRequestDto {
  @ApiPropertyOptional({
    enum: SyncType,
    default: SyncType.MANUAL,
    description: 'Type of sync trigger',
  })
  @IsOptional()
  @IsEnum(SyncType)
  syncType?: SyncType;

  @ApiPropertyOptional({
    example: '2026-10-01',
    description: 'Sync from date (YYYY-MM-DD). Defaults to last sync date',
  })
  @IsOptional()
  @IsDateString()
  fromDate?: string;

  @ApiPropertyOptional({
    example: '2026-10-02',
    description: 'Sync to date (YYYY-MM-DD). Defaults to today',
  })
  @IsOptional()
  @IsDateString()
  toDate?: string;

  @ApiPropertyOptional({
    example: true,
    description: 'Create missing attendance records',
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  createMissing?: boolean;

  @ApiPropertyOptional({
    example: true,
    description: 'Update existing records if device data differs',
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  updateExisting?: boolean;
}

export class DevicePunchRecord {
  @ApiProperty({ example: '1001', description: 'Device user ID / employee code' })
  userId: string;

  @ApiProperty({ example: '2026-10-02T03:55:00Z', description: 'Punch timestamp' })
  timestamp: string;

  @ApiProperty({ enum: PunchType, description: 'Type of punch' })
  punchType: PunchType;

  @ApiPropertyOptional({ example: '12345', description: 'Original punch record ID from device' })
  devicePunchId?: string;

  @ApiPropertyOptional({ example: 'VERIFIED', description: 'Verification status from device' })
  verifyCode?: string;

  @ApiPropertyOptional({ example: 0, description: 'Work code from device' })
  workCode?: number;

  @ApiPropertyOptional({ example: 1, description: 'Sensor type (1=FP, 2=Face, etc.)' })
  sensorType?: number;
}

export class SyncResponseDto {
  @ApiProperty({ example: 'SUCCESS', description: 'Overall sync status' })
  status: string;

  @ApiProperty({ example: 'TM-2026-0001', description: 'Device code' })
  deviceCode: string;

  @ApiProperty({ example: 50, description: 'Total records fetched from device' })
  recordsFetched: number;

  @ApiProperty({ example: 45, description: 'New attendance records created' })
  recordsInserted: number;

  @ApiProperty({ example: 5, description: 'Records skipped (duplicates)' })
  recordsSkipped: number;

  @ApiProperty({ example: 0, description: 'Records updated' })
  recordsUpdated: number;

  @ApiPropertyOptional({ description: 'Error message if sync failed' })
  errorMessage?: string;

  @ApiPropertyOptional({ description: 'Duration in milliseconds' })
  durationMs?: number;

  @ApiPropertyOptional({
    type: [Object],
    description: 'Detailed sync results per record',
  })
  details?: any[];
}