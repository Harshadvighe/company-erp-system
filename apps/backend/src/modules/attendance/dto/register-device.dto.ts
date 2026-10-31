import {
  IsString,
  IsOptional,
  IsEnum,
  IsIP,
  IsPort,
  IsBoolean,
  IsInt,
  Min,
  Max,
  Matches,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum DeviceConnectionType {
  TCP_IP = 'TCP_IP',
  HTTP = 'HTTP',
  USB = 'USB',
  SERIAL = 'SERIAL',
  CLOUD = 'CLOUD',
}

export enum DeviceType {
  FINGERPRINT = 'FINGERPRINT',
  FACE = 'FACE',
  RFID = 'RFID',
  FINGERPRINT_FACE = 'FINGERPRINT_FACE',
  CARD = 'CARD',
}

export class RegisterDeviceDto {
  @ApiProperty({ example: 'TM-2026-0001', description: 'Unique device code' })
  @IsString()
  deviceCode: string;

  @ApiProperty({ example: 'Main Gate Entry', description: 'Human-readable device name' })
  @IsString()
  deviceName: string;

  @ApiPropertyOptional({
    enum: DeviceType,
    default: DeviceType.FINGERPRINT_FACE,
    description: 'Type of biometric capture',
  })
  @IsOptional()
  @IsEnum(DeviceType)
  deviceType?: DeviceType;

  @ApiPropertyOptional({
    example: 'TeamOffice',
    description: 'Manufacturer name',
    default: 'TeamOffice',
  })
  @IsOptional()
  @IsString()
  manufacturer?: string;

  @ApiPropertyOptional({ example: 'TM-700', description: 'Device model number' })
  @IsOptional()
  @IsString()
  model?: string;

  @ApiPropertyOptional({ example: 'SN123456', description: 'Device serial number' })
  @IsOptional()
  @IsString()
  serialNumber?: string;

  @ApiPropertyOptional({
    example: '192.168.1.100',
    description: 'Device IP address (for TCP_IP/HTTP)',
  })
  @IsOptional()
  @IsIP()
  ipAddress?: string;

  @ApiPropertyOptional({
    example: 4370,
    description: 'TCP port (default 4370 for ZKTeco/TeamOffice)',
    default: 4370,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  port?: number;

  @ApiPropertyOptional({
    enum: DeviceConnectionType,
    default: DeviceConnectionType.TCP_IP,
    description: 'Connection method',
  })
  @IsOptional()
  @IsEnum(DeviceConnectionType)
  connectionType?: DeviceConnectionType;

  @ApiPropertyOptional({
    example: 'http://192.168.1.100:8080/api',
    description: 'HTTP API base URL (for HTTP/CLOUD connection)',
  })
  @IsOptional()
  @IsString()
  apiEndpoint?: string;

  @ApiPropertyOptional({ description: 'API key for HTTP/Cloud authentication' })
  @IsOptional()
  @IsString()
  apiKey?: string;

  @ApiPropertyOptional({ description: 'API secret for HTTP/Cloud authentication' })
  @IsOptional()
  @IsString()
  apiSecret?: string;

  @ApiPropertyOptional({
    description: 'Device communication key (vendor-specific)',
  })
  @IsOptional()
  @IsString()
  communicationKey?: string;

  @ApiPropertyOptional({
    example: true,
    description: 'Enable automatic periodic sync',
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  autoSyncEnabled?: boolean;

  @ApiPropertyOptional({
    example: 15,
    description: 'Auto-sync interval in minutes',
    default: 15,
    minimum: 1,
    maximum: 1440,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1440)
  syncIntervalMinutes?: number;

  @ApiPropertyOptional({
    example: 'Asia/Kolkata',
    description: 'Device timezone',
    default: 'Asia/Kolkata',
  })
  @IsOptional()
  @IsString()
  timezone?: string;

  @ApiPropertyOptional({ example: 'Plant Main Gate', description: 'Device location' })
  @IsOptional()
  @IsString()
  location?: string;

  @ApiPropertyOptional({ description: 'Additional notes' })
  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpdateDeviceDto {
  @IsOptional()
  @IsString()
  deviceName?: string;

  @IsOptional()
  @IsEnum(DeviceType)
  deviceType?: DeviceType;

  @IsOptional()
  @IsString()
  manufacturer?: string;

  @IsOptional()
  @IsString()
  model?: string;

  @IsOptional()
  @IsString()
  serialNumber?: string;

  @IsOptional()
  @IsIP()
  ipAddress?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  port?: number;

  @IsOptional()
  @IsEnum(DeviceConnectionType)
  connectionType?: DeviceConnectionType;

  @IsOptional()
  @IsString()
  apiEndpoint?: string;

  @IsOptional()
  @IsString()
  apiKey?: string;

  @IsOptional()
  @IsString()
  apiSecret?: string;

  @IsOptional()
  @IsString()
  communicationKey?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsBoolean()
  autoSyncEnabled?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1440)
  syncIntervalMinutes?: number;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}