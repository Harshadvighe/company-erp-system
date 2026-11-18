import { IsNotEmpty, IsString, IsEmail, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RequestPermissionDto {
  @ApiProperty({
    description: 'Email address of the requester seeking edit/change access',
    example: 'developer@saarkexploration.com',
  })
  @IsNotEmpty()
  @IsEmail()
  requesterEmail: string;

  @ApiProperty({
    description: 'Full name or designation of the requester',
    example: 'ERP Development Team',
  })
  @IsNotEmpty()
  @IsString()
  requesterName: string;

  @ApiProperty({
    description: 'Target resource requesting permission for',
    example: 'ARCHITECTURAL_FILE',
    enum: ['ARCHITECTURAL_FILE', 'NEW_MODULE_IMPLEMENTATION', 'CORE_CODE_EDIT'],
  })
  @IsNotEmpty()
  @IsString()
  targetResource: string;

  @ApiPropertyOptional({
    description: 'Reason or summary of proposed changes',
    example: 'Adding architectural documentation and updating register map for NPD module',
  })
  @IsOptional()
  @IsString()
  changeSummary?: string;
}

