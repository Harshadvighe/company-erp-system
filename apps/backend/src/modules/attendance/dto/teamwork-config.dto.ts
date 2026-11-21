import { IsString, IsOptional, IsBoolean, IsDateString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class TeamworkConfigDto {
  @ApiProperty({ example: 'https://saark.teamwork.com', description: 'Teamwork site URL' })
  @IsString()
  siteUrl: string;

  @ApiProperty({ example: 'twp_xxxxxxxxxxxxxxxxx', description: 'Teamwork API Key or Personal Access Token' })
  @IsString()
  apiKey: string;

  @ApiPropertyOptional({ example: true, description: 'Enable automatic background polling' })
  @IsOptional()
  @IsBoolean()
  autoSyncEnabled?: boolean;

  @ApiPropertyOptional({ example: 15, description: 'Polling interval in minutes' })
  @IsOptional()
  syncIntervalMinutes?: number;
}

export class TeamworkTestConnectionDto {
  @ApiProperty({ example: 'https://saark.teamwork.com', description: 'Teamwork site URL' })
  @IsString()
  siteUrl: string;

  @ApiProperty({ example: 'twp_xxxxxxxxxxxxxxxxx', description: 'Teamwork API Key' })
  @IsString()
  apiKey: string;
}

export class TeamworkSyncRequestDto {
  @ApiPropertyOptional({ example: '2026-11-21', description: 'Sync from date (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  fromDate?: string;

  @ApiPropertyOptional({ example: '2026-11-21', description: 'Sync to date (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  toDate?: string;
}

export class TeamworkManualPunchDto {
  @ApiProperty({ example: 'EMP-001 or email@domain.com', description: 'Employee code, ID, or email' })
  @IsString()
  employeeIdentifier: string;

  @ApiProperty({ example: '2026-11-21T09:15:00.000Z', description: 'Punch timestamp in ISO format' })
  @IsDateString()
  punchTime: string;

  @ApiPropertyOptional({ example: 'CHECK_IN', enum: ['CHECK_IN', 'CHECK_OUT', 'AUTO'], default: 'AUTO' })
  @IsOptional()
  @IsString()
  punchType?: string;

  @ApiPropertyOptional({ example: 'Manual punch from Teamwork mobile', description: 'Notes or memo' })
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional({ example: 'Plant Operations / Remote', description: 'Punching location' })
  @IsOptional()
  @IsString()
  location?: string;
}

