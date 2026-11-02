import { IsNotEmpty, IsString, IsOptional, IsArray, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ApproveEmployeeRequestDto {
  @ApiProperty({ example: 'aditya.k', description: 'Username for the employee login account' })
  @IsNotEmpty()
  @IsString()
  username: string;

  @ApiProperty({ example: 'Saark@2026', description: 'Password for the employee login account' })
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  password: string;

  @ApiPropertyOptional({ example: 'dept-uuid', description: 'Optional department ID override' })
  @IsOptional()
  @IsString()
  departmentId?: string;

  @ApiPropertyOptional({ example: 'desig-uuid', description: 'Optional designation ID' })
  @IsOptional()
  @IsString()
  designationId?: string;

  @ApiPropertyOptional({ example: ['role-uuid'], description: 'List of role IDs to assign' })
  @IsOptional()
  @IsArray()
  roleIds?: string[];

  @ApiPropertyOptional({ description: 'Array of assigned module keys or JSON string' })
  @IsOptional()
  assignedModules?: string[] | string;

  @ApiPropertyOptional({ example: true, description: 'Whether to dispatch welcome email with login credentials' })
  @IsOptional()
  sendWelcomeEmail?: boolean;
}
