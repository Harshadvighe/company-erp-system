import { IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class VerifyPresenceDto {
  @ApiProperty({ description: 'Live face photograph base64 URI or descriptor' })
  @IsNotEmpty()
  face_data: string | number[];

  @ApiPropertyOptional({ description: 'Live camera photograph base64 string alias' })
  @IsOptional()
  @IsString()
  livePhotoBase64?: string;

  @ApiPropertyOptional({ description: 'Current active module or route in frontend' })
  @IsOptional()
  @IsString()
  currentRoute?: string;
}

