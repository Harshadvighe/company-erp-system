import { IsNotEmpty, IsString, IsNumber, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateLeaveDto {
  @ApiProperty({ example: 'EMP_ID' })
  @IsNotEmpty()
  @IsString()
  employeeId: string;

  @ApiProperty({ example: 'CASUAL' })
  @IsNotEmpty()
  @IsString()
  leaveType: string;

  @ApiProperty({ example: '2026-10-15T00:00:00.000Z' })
  @IsNotEmpty()
  @IsString()
  startDate: string;

  @ApiProperty({ example: '2026-10-16T00:00:00.000Z' })
  @IsNotEmpty()
  @IsString()
  endDate: string;

  @ApiProperty({ example: 2 })
  @IsNotEmpty()
  @IsNumber()
  daysCount: number;

  @ApiProperty({ example: 'Attending family function' })
  @IsNotEmpty()
  @IsString()
  reason: string;
}

export class UpdateLeaveStatusDto {
  @ApiProperty({ example: 'APPROVED' })
  @IsNotEmpty()
  @IsString()
  status: 'APPROVED' | 'REJECTED';

  @ApiPropertyOptional({ example: 'Approved by management' })
  @IsOptional()
  @IsString()
  decisionNote?: string;
}
