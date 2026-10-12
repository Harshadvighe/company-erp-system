import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../core/database/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET,
    });
  }

  async validate(payload: { sub: string; email: string }) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: {
        department: true,
        staff: true,
        userRoles: {
          include: {
            role: {
              include: {
                rolePermissions: {
                  include: { permission: true },
                },
              },
            },
          },
        },
      },
    });

    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User session invalid or account inactive');
    }

    // Flatten permissions list for quick PBAC checks
    const permissions = new Set<string>();
    const roles = user.userRoles.map((ur) => {
      ur.role.rolePermissions.forEach((rp) => {
        permissions.add(`${rp.permission.module}:${rp.permission.action}`);
      });
      return ur.role.code;
    });

    // Resolve staffId — read-only lookup, no writes on every request
    let staffId = user.staff?.id;
    if (!staffId) {
      const existingStaff = await this.prisma.staff.findFirst({
        where: { OR: [{ userId: user.id }, { email: user.email }] },
        select: { id: true, userId: true },
      });
      if (existingStaff) {
        staffId = existingStaff.id;
        // Link userId if missing — one-time fix, fire-and-forget
        if (!existingStaff.userId) {
          this.prisma.staff
            .update({ where: { id: existingStaff.id }, data: { userId: user.id } })
            .catch(() => null);
        }
      }
    }

    return {
      id: user.id,
      username: user.username,
      email: user.email,
      fullName: user.fullName,
      designation: user.designation,
      department: user.department?.name,
      staffId,
      roles,
      permissions: Array.from(permissions),
    };
  }
}
