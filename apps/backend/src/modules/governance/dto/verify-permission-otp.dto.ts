import { IsNotEmpty, IsString, IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyPermissionOtpDto {
  @ApiProperty({
    description: 'Email of the requester who initiated the authorization challenge',
    example: 'developer@saarkexploration.com',
  })
  @IsNotEmpty()
  @IsEmail()
  requesterEmail: string;

  @ApiProperty({
    description: '6-digit OTP dispatched to primary author sonwanep968@gmail.com',
    example: '849201',
  })
  @IsNotEmpty()
  @IsString()
  otp: string;

  @ApiProperty({
    description: 'Target resource being unlocked',
    example: 'ARCHITECTURAL_FILE',
  })
  @IsNotEmpty()
  @IsString()
  targetResource: string;
}

