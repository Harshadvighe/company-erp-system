import { IsNotEmpty, IsString, IsOptional, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class EnrollFaceDto {
  @ApiProperty({ description: 'Live camera capture Base64 data URI' })
  @IsNotEmpty()
  @IsString()
  livePhotoBase64: string;

  @ApiPropertyOptional({ description: 'Optional passport/profile photo Base64' })
  @IsOptional()
  @IsString()
  passportPhotoBase64?: string;

  @ApiPropertyOptional({ description: 'Enable face verification for login' })
  @IsOptional()
  @IsBoolean()
  enableFaceAuth?: boolean;
}

export class UpdateFaceStatusDto {
  @ApiProperty({ description: 'Active biometric status' })
  @IsNotEmpty()
  @IsBoolean()
  isActive: boolean;
}
