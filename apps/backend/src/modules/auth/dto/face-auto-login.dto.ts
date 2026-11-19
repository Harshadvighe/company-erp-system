import { IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class FaceAutoLoginDto {
  @ApiProperty({ description: 'Live face photograph base64 URI or descriptor' })
  @IsNotEmpty()
  face_data: string | number[];

  @ApiPropertyOptional({ description: 'Live camera photograph base64 string alias' })
  @IsOptional()
  @IsString()
  livePhotoBase64?: string;

  @ApiPropertyOptional({ description: 'Optional username or email hint for targeted biometric verification' })
  @IsOptional()
  @IsString()
  username?: string;

  @ApiPropertyOptional({ description: 'Optional identifier (username or email)' })
  @IsOptional()
  @IsString()
  identifier?: string;
}

