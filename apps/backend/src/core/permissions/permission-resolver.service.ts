import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

export interface EffectivePermissionResult {
  userId: string;
  username: string;
  email: string;
  roles: string[];
  inheritedPermissions: string[];
  customAllows: string[];
  explicitDenies: string[];
  effectivePermissions: string[];
}

@Injectable()
export class PermissionResolverService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Resolves the full effective permission profile for a user.
   * Rules:
   * 1. Start with role-inherited permissions from all assigned roles.
   * 2. If user is Super Admin (ROLE_ADMIN, ADMIN, SUPER_ADMIN), base set includes all system permissions.
   * 3. Apply individual custom ALLOW overrides (adds permission if not already present).
   * 4. Apply individual explicit DENY overrides (removes permission, taking precedence over inherited role permissions).
   * 5. Resulting set is sorted, unique effective permissions list.
   */
  async resolveUserPermissions(userId: string): Promise<EffectivePermissionResult> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
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
        userPermissions: {
          include: { permission: true },
        },
      },
    });

    if (!user) {
      throw new NotFoundException(`User with ID ${userId} not found`);
    }

    const roles: string[] = user.userRoles ? user.userRoles.map((ur) => ur.role.code) : [];
    const isAdmin = roles.some((r) => ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r));

    let allSystemPerms: string[] | undefined;
    if (isAdmin) {
      const allPerms = await this.prisma.permission.findMany({
        select: { module: true, action: true },
      });
      allSystemPerms = allPerms.map((p) => `${p.module}:${p.action}`);
    }

    return this.calculateEffective(user, allSystemPerms);
  }

  /**
   * Pure synchronous calculation on an already-loaded user entity.
   */
  calculateEffective(user: any, allSystemPermissions?: string[]): EffectivePermissionResult {
    const roles: string[] = user.userRoles ? user.userRoles.map((ur: any) => ur.role.code) : [];
    const isAdmin = roles.some((r) => ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r));

    const inheritedSet = new Set<string>();

    if (isAdmin && allSystemPermissions && allSystemPermissions.length > 0) {
      for (const p of allSystemPermissions) {
        inheritedSet.add(p);
      }
    } else if (user.userRoles) {
      for (const ur of user.userRoles) {
        if (ur.role?.rolePermissions) {
          for (const rp of ur.role.rolePermissions) {
            if (rp.permission) {
              inheritedSet.add(`${rp.permission.module}:${rp.permission.action}`);
            }
          }
        }
      }
    }

    const customAllows = new Set<string>();
    const explicitDenies = new Set<string>();

    if (user.userPermissions) {
      for (const up of user.userPermissions) {
        if (!up.permission) continue;
        const permCode = `${up.permission.module}:${up.permission.action}`;
        if (up.effect === 'DENY') {
          explicitDenies.add(permCode);
        } else if (up.effect === 'ALLOW') {
          customAllows.add(permCode);
        }
      }
    }

    // Effective: (Inherited + ALLOW) - DENY
    const effectiveSet = new Set<string>(inheritedSet);
    for (const allow of customAllows) {
      effectiveSet.add(allow);
    }
    for (const deny of explicitDenies) {
      effectiveSet.delete(deny);
    }

    return {
      userId: user.id,
      username: user.username,
      email: user.email,
      roles,
      inheritedPermissions: Array.from(inheritedSet).sort(),
      customAllows: Array.from(customAllows).sort(),
      explicitDenies: Array.from(explicitDenies).sort(),
      effectivePermissions: Array.from(effectiveSet).sort(),
    };
  }

  /**
   * Resolves just the list of effective permission strings for a user.
   */
  async resolveEffectivePermissions(userId: string): Promise<string[]> {
    const res = await this.resolveUserPermissions(userId);
    return res.effectivePermissions;
  }

  /**
   * Checks whether a user effectively has a specific permission.
   */
  async hasPermission(userId: string, permission: string): Promise<boolean> {
    const effective = await this.resolveEffectivePermissions(userId);
    return effective.includes(permission);
  }
}

