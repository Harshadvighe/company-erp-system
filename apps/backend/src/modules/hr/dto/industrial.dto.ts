import { IsNotEmpty, IsString, IsOptional, IsNumber, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AllocateWorkstationDto {
  @ApiProperty({ example: 'EMP_ID' })
  @IsNotEmpty()
  @IsString()
  employeeId: string;

  @ApiProperty({ example: 'BAY_4_WIRING' })
  @IsNotEmpty()
  @IsString()
  bayCode: string;

  @ApiPropertyOptional({ example: 'PANEL-2026-0001' })
  @IsOptional()
  @IsString()
  panelCode?: string;

  @ApiPropertyOptional({ example: 'SHIFT_G' })
  @IsOptional()
  @IsString()
  shiftCode?: string;

  @ApiPropertyOptional({ example: 8.0 })
  @IsOptional()
  @IsNumber()
  targetHours?: number;

  @ApiPropertyOptional({ example: 'Control wiring of 15HP Booster Pump' })
  @IsOptional()
  @IsString()
  supervisorNote?: string;
}

export class LogOvertimeDto {
  @ApiProperty({ example: 'ATTENDANCE_ID' })
  @IsNotEmpty()
  @IsString()
  attendanceId: string;

  @ApiProperty({ example: 2.5 })
  @IsNotEmpty()
  @IsNumber()
  overtimeHours: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  approved?: boolean;
}

export class ReportSafetyIncidentDto {
  @ApiProperty({ example: 'NEAR_MISS' })
  @IsNotEmpty()
  @IsString()
  incidentType: string;

  @ApiProperty({ example: 'LOW' })
  @IsNotEmpty()
  @IsString()
  severity: string;

  @ApiProperty({ example: 'BAY_2_BUSBAR' })
  @IsNotEmpty()
  @IsString()
  locationBay: string;

  @ApiPropertyOptional({ example: 'EMP_ID' })
  @IsOptional()
  @IsString()
  employeeId?: string;

  @ApiProperty({ example: 'Spark observed during hydraulic busbar shearing; guard was adjusted' })
  @IsNotEmpty()
  @IsString()
  description: string;

  @ApiPropertyOptional({ example: 'Inspected shearing blade alignment and retrained operator' })
  @IsOptional()
  @IsString()
  actionTaken?: string;
}
