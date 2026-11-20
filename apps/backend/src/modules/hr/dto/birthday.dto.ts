import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class SendBirthdayWishDto {
  @ApiProperty({ description: 'Target Employee ID to send birthday wish' })
  @IsNotEmpty()
  @IsString()
  employeeId: string;

  @ApiPropertyOptional({ description: 'Custom warm birthday message' })
  @IsOptional()
  @IsString()
  message?: string;
}

export class BroadcastBirthdayWishesDto {
  @ApiPropertyOptional({ description: 'Optional target employee ID if broadcasting for a specific celebrant' })
  @IsOptional()
  @IsString()
  employeeId?: string;

  @ApiPropertyOptional({ description: 'Official company broadcast birthday message' })
  @IsOptional()
  @IsString()
  message?: string;
}

