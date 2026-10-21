import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import { PermissionResolverService } from '../../core/permissions/permission-resolver.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly auditService: AuditService,
    private readonly permissionResolverService: PermissionResolverService,
  ) {}

  async login(dto: LoginDto, ipAddress?: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        OR: [{ email: dto.emailOrUsername }, { username: dto.emailOrUsername }],
      },
      include: {
        department: true,
        staff: true,
      },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials provided');
    }

    if (user.status !== 'ACTIVE') {
      throw new BadRequestException('User account is currently locked or inactive');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials provided');
    }

    const permResult = await this.permissionResolverService.resolveUserPermissions(user.id);

    const payload = { sub: user.id, email: user.email, username: user.username };
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '7d' });

    // Log audit event
    await this.auditService.log({
      userId: user.id,
      userEmail: user.email,
      action: 'LOGIN',
      module: 'AUTH',
      details: `User ${user.fullName} logged in successfully`,
      ipAddress,
    });

    return {
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        phone: user.phone,
        designation: user.designation,
        department: user.department?.name,
        staffId: user.staff?.id,
        employeeId: user.staff?.employeeId,
        roles: permResult.roles,
        permissions: permResult.effectivePermissions,
      },
      tokens: {
        accessToken,
        refreshToken,
        expiresIn: '24h',
      },
    };
  }

  async getCurrentProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        department: true,
        staff: true,
      },
    });

    if (!user) {
      throw new UnauthorizedException('User profile not found');
    }

    const permResult = await this.permissionResolverService.resolveUserPermissions(user.id);

    return {
      id: user.id,
      username: user.username,
      email: user.email,
      fullName: user.fullName,
      phone: user.phone,
      designation: user.designation,
      department: user.department?.name,
      staffId: user.staff?.id,
      employeeId: user.staff?.employeeId,
      roles: permResult.roles,
      permissions: permResult.effectivePermissions,
    };
  }

  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string,
    confirmPassword: string,
  ) {
    if (!newPassword || newPassword.length < 8) {
      throw new BadRequestException('New password must be at least 8 characters.');
    }

    if (newPassword !== confirmPassword) {
      throw new BadRequestException('New password and confirmation do not match.');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User account not found.');
    }

    const isCurrentValid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isCurrentValid) {
      throw new UnauthorizedException('Current password is incorrect.');
    }

    if (await bcrypt.compare(newPassword, user.passwordHash)) {
      throw new BadRequestException('New password must be different from the current password.');
    }

    const newHash = await bcrypt.hash(newPassword, 12);

    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newHash },
    });

    // Audit log — no password values recorded
    await this.auditService.log({
      userId: user.id,
      userEmail: user.email,
      action: 'PASSWORD_CHANGE',
      module: 'AUTH',
      details: `User ${user.fullName} (${user.username}) changed their own password.`,
    });

    return { success: true, message: 'Password updated successfully. Please log in again.' };
  }
}
