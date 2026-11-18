import { Controller, Post, Body, Get, Req } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { GovernanceService } from './governance.service';
import { RequestPermissionDto } from './dto/request-permission.dto';
import { VerifyPermissionOtpDto } from './dto/verify-permission-otp.dto';

@ApiTags('Codebase Governance & Author Protection')
@Controller('api/v1/governance')
export class GovernanceController {
  constructor(private readonly governanceService: GovernanceService) {}

  @Get('status')
  @ApiOperation({
    summary: 'Get Governance Policy & Author Protection Status',
    description: 'Returns the primary author (sonwanep968@gmail.com) and list of locked architectural files/modules.',
  })
  async getStatus() {
    return this.governanceService.getGovernanceStatus();
  }

  @Post('request-access')
  @ApiOperation({
    summary: 'Request Edit Permission for Protected File or Module (Triggers OTP)',
    description: 'Generates a secure 6-digit OTP and sends an urgent email challenge to primary author sonwanep968@gmail.com.',
  })
  async requestAccess(@Body() dto: RequestPermissionDto, @Req() req: any) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    return this.governanceService.requestPermissionOtp(dto, ip);
  }

  @Post('verify-access')
  @ApiOperation({
    summary: 'Verify Author OTP & Receive Edit Lease Token',
    description: 'Validates the 6-digit OTP dispatched to sonwanep968@gmail.com and issues a 2-hour cryptographic lease token.',
  })
  async verifyAccess(@Body() dto: VerifyPermissionOtpDto, @Req() req: any) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    return this.governanceService.verifyPermissionOtp(dto, ip);
  }
}
