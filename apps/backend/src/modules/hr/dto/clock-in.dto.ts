import { IsNotEmpty, IsString, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ClockInDto {
  @ApiProperty({ example: 'EMP_ID' })
  @IsNotEmpty()
  @IsString()
  employeeId: string;

  @ApiPropertyOptional({ example: 'MIDC Industrial Unit' })
  @IsOptional()
  @IsString()
  location?: string;

  @ApiPropertyOptional({ example: 'Starting morning shift' })
  @IsOptional()
  @IsString()
  note?: string;
}

export class ClockOutDto {
  @ApiProperty({ example: 'EMP_ID' })
  @IsNotEmpty()
  @IsString()
  employeeId: string;

  @ApiPropertyOptional({ example: 'Completed daily panel assembly' })
  @IsOptional()
  @IsString()
  note?: string;
}
