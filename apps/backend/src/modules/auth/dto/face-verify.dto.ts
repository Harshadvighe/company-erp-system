import { IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class FaceVerifyDto {
  @ApiProperty({ description: 'Short-lived session token issued after successful password validation' })
  @IsNotEmpty()
  @IsString()
  faceSessionToken: string;

  @ApiPropertyOptional({ description: 'Base64 data URI of the live camera face capture' })
  @IsOptional()
  @IsString()
  faceImage?: string;

  @ApiPropertyOptional({ description: 'Base64 data URI alias for live camera capture' })
  @IsOptional()
  @IsString()
  livePhotoBase64?: string;
}
