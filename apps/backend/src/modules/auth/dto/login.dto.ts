import { IsNotEmpty, IsString, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class LoginDto {
  @ApiPropertyOptional({
    description: 'Username for user lookup',
    example: 'admin',
  })
  @IsOptional()
  @IsString()
  username?: string;

  @ApiPropertyOptional({
    description: 'Username or email address (backward-compatible identifier)',
    example: 'admin@saark.com',
  })
  @IsOptional()
  @IsString()
  emailOrUsername?: string;

  @ApiProperty({
    description: 'User password (plaintext in transport, hashed in DB)',
    example: 'Saark@2026',
  })
  @IsNotEmpty()
  @IsString()
  password: string;

  @ApiPropertyOptional({
    description: 'Facial biometric data: Base64 image data-url or 128-dimensional numerical embedding array',
    example: 'data:image/jpeg;base64,...',
  })
  @IsOptional()
  face_data?: string | number[];

  @ApiPropertyOptional({
    description: 'Live camera photograph base64 string (alias for face_data)',
  })
  @IsOptional()
  @IsString()
  livePhotoBase64?: string;

  @ApiPropertyOptional({
    description: 'Face image base64 string (alias for face_data)',
  })
  @IsOptional()
  @IsString()
  faceImage?: string;
}

