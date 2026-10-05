import { IsNotEmpty, IsString, IsEmail, IsOptional, IsNumber } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateEmployeeDto {
  @ApiProperty({ example: 'Aditya' })
  @IsNotEmpty()
  @IsString()
  firstName: string;

  @ApiProperty({ example: 'Kulkarni' })
  @IsNotEmpty()
  @IsString()
  lastName: string;

  @ApiProperty({ example: 'aditya.k@saark.in' })
  @IsNotEmpty()
  @IsEmail()
  email: string;

  @ApiProperty({ example: '+91 98200 11223' })
  @IsNotEmpty()
  @IsString()
  phone: string;

  @ApiProperty({ example: 'Junior Design Engineer' })
  @IsNotEmpty()
  @IsString()
  designation: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  departmentId?: string;

  @ApiPropertyOptional({ example: 'FULL_TIME' })
  @IsOptional()
  @IsString()
  employmentType?: string;

  @ApiPropertyOptional({ example: 'PENDING_APPROVAL' })
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional({ example: 650000 })
  @IsOptional()
  @IsNumber()
  salaryCtc?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  bankAccountNo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  bankIfsc?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  panNo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  aadhaarNo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  bloodGroup?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  emergencyPhone?: string;

  @ApiPropertyOptional({ example: 'SHOPFLOOR_TECH' })
  @IsOptional()
  @IsString()
  workerCategory?: string;

  @ApiPropertyOptional({ example: 'LEVEL_2_WIREMAN' })
  @IsOptional()
  @IsString()
  skillLevel?: string;

  @ApiPropertyOptional({ example: 'BAY_4_WIRING' })
  @IsOptional()
  @IsString()
  assignedBay?: string;

  @ApiPropertyOptional({ example: 'SHIFT_G' })
  @IsOptional()
  @IsString()
  shiftCode?: string;

  @ApiPropertyOptional({ example: 'MH-PWD-WIREMAN-8492' })
  @IsOptional()
  @IsString()
  electricalLicenseNo?: string;

  @ApiPropertyOptional({ example: 'Apex Industrial Solutions' })
  @IsOptional()
  @IsString()
  contractorAgency?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  ppeKitIssued?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;
}
