import { IsNotEmpty, IsString, IsEmail, IsOptional, IsNumber } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateEmployeeDto {
  @ApiProperty({ example: 'Aditya' })
  @IsNotEmpty()
  @IsString()
  firstName: string;

  @ApiPropertyOptional({ example: 'Ramesh' })
  @IsOptional()
  @IsString()
  middleName?: string;

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

  // -------------------------------------------------------------
  // IDENTITY & BIOMETRIC VERIFICATION
  // -------------------------------------------------------------
  @ApiPropertyOptional({ description: 'Passport/profile photo Base64 data URI' })
  @IsOptional()
  @IsString()
  passportPhotoBase64?: string;

  @ApiPropertyOptional({ description: 'Live camera capture Base64 data URI for biometric enrollment' })
  @IsOptional()
  @IsString()
  livePhotoBase64?: string;

  @ApiPropertyOptional({ description: 'Whether face recognition is required for employee login' })
  @IsOptional()
  enableFaceAuth?: boolean;

  // -------------------------------------------------------------
  // LINKED USER ACCOUNT SETUP
  // -------------------------------------------------------------
  @ApiPropertyOptional({ description: 'Create linked user login account concurrently' })
  @IsOptional()
  createUserAccount?: boolean;

  @ApiPropertyOptional({ example: 'aditya.k' })
  @IsOptional()
  @IsString()
  username?: string;

  @ApiPropertyOptional({ example: 'Saark@2026' })
  @IsOptional()
  @IsString()
  password?: string;

  @ApiPropertyOptional({ example: 'ROLE_EMPLOYEE' })
  @IsOptional()
  @IsString()
  roleId?: string;
}

