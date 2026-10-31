import { Controller, Post, Body, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { FaceVerifyDto } from './dto/face-verify.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Authentication')
@Controller('api/v1/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @ApiOperation({ summary: 'Authenticate user with Credentials & optional unified Face Biometric' })
  async login(@Body() dto: LoginDto, @Req() req: any) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'] || '';
    return this.authService.login(dto, ip, userAgent);
  }

  @Post('login-2fa')
  @ApiOperation({
    summary: 'Strict Dual-Factor Authentication (Username + Password + Facial Biometrics)',
    description: 'Enforces BOTH traditional credential matching AND facial biometric verification in a single atomic request.',
  })
  async loginStrict2FA(@Body() dto: LoginDto, @Req() req: any) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'] || '';
    return this.authService.loginStrict2FA(dto, ip, userAgent);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Logout authenticated user, record logout timestamp, and compute session duration' })
  async logout(@Req() req: any, @Body('sessionId') sessionId?: string) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    return this.authService.logout(req.user.id, sessionId, ip);
  }

  @Post('heartbeat')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Send session heartbeat to keep session active' })
  async heartbeat(@Req() req: any, @Body('sessionId') sessionId?: string) {
    return this.authService.heartbeat(req.user.id, sessionId);
  }

  @Post('face-verify')
  @ApiOperation({ summary: 'Verify live camera face biometric and complete login' })
  async verifyFace(@Body() dto: FaceVerifyDto, @Req() req: any) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    return this.authService.verifyFace(dto, ip);
  }

  @Get('face-config')
  @ApiOperation({ summary: 'Get public face verification security policy' })
  async getFaceConfig() {
    return this.authService.getFaceConfig();
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  @ApiOperation({ summary: 'Get current authenticated user profile' })
  async getProfile(@Req() req: any) {
    return this.authService.getCurrentProfile(req.user.id);
  }
}

