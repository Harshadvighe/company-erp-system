import { Controller, Post, Body, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { FaceVerifyDto } from './dto/face-verify.dto';
import { FaceAutoLoginDto } from './dto/face-auto-login.dto';
import { VerifyPresenceDto } from './dto/verify-presence.dto';
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

  @Post('face-login')
  @ApiOperation({
    summary: 'Instant 1:N Facial Auto-Login (Camera only)',
    description: 'Scans live camera face photograph, automatically matches against registered biometric templates, and logs in the recognized employee.',
  })
  async faceAutoLogin(@Body() dto: FaceAutoLoginDto, @Req() req: any) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'] || '';
    return this.authService.faceAutoLogin(dto, ip, userAgent);
  }

  @Post('verify-presence')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Periodic 30-Minute Presence Verification',
    description: 'Verifies the live face of the logged-in user to confirm presence without changing pages.',
  })
  async verifyPresence(@Req() req: any, @Body() dto: VerifyPresenceDto) {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    return this.authService.verifyPresence(req.user.id, dto, ip);
  }

  @Get('office-hours-status')
  @ApiOperation({ summary: 'Check if current time is past office hours (6:00 PM cutoff)' })
  async getOfficeHoursStatus() {
    return {
      isPastOfficeHours: this.authService.isPastOfficeHours(),
      cutoffHour: 18,
    };
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

