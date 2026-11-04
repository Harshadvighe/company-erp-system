import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    if (!user) {
      throw new ForbiddenException('User context missing or unauthenticated');
    }

    // Super Admin & Admin bypass
    const userRoles: string[] = user.roles || [];
    const username = (user.username || '').toLowerCase();
    if (
      username === 'saarkadmin' ||
      username === 'admin' ||
      userRoles.includes('ROLE_ADMIN') ||
      userRoles.includes('ADMIN') ||
      userRoles.includes('SUPER_ADMIN')
    ) {
      return true;
    }

    // PBAC Check
    const userPermissions: string[] = user.permissions || [];
    if (requiredPermissions.some((perm) => userPermissions.includes(perm))) {
      return true;
    }

    // Assigned Modules Check
    const rawModules: any = user.assignedModules;
    let assignedModules: string[] = [];
    if (Array.isArray(rawModules)) {
      assignedModules = rawModules;
    } else if (typeof rawModules === 'string') {
      try { assignedModules = JSON.parse(rawModules); } catch (_) { assignedModules = [rawModules]; }
    }

    const normalizedModules = assignedModules.map((m) =>
      String(m).toUpperCase().replace(/\s+/g, '_').replace(/&/g, '')
    );

    const moduleMap: Record<string, string[]> = {
      SALES_MARKETING: ['CUSTOMERS', 'CRM', 'SALES', 'QUOTATIONS', 'LEADS'],
      SALES: ['CUSTOMERS', 'CRM', 'SALES', 'QUOTATIONS', 'LEADS'],
      CRM: ['CUSTOMERS', 'CRM', 'SALES', 'QUOTATIONS', 'LEADS'],
      PURCHASE: ['PURCHASE', 'VENDORS'],
      PRODUCTION: ['PRODUCTION', 'INVENTORY', 'PROJECTS'],
      INVENTORY: ['INVENTORY'],
      HR: ['HR', 'STAFF', 'ATTENDANCE'],
      ACCOUNTS: ['ACCOUNTS', 'PAYMENTS', 'INVOICES'],
    };

    const hasModuleAccess = requiredPermissions.some((perm) => {
      const [mod] = perm.split(':');
      for (const assigned of normalizedModules) {
        const allowed = moduleMap[assigned] || [assigned];
        if (allowed.includes(mod)) return true;
      }
      return false;
    });

    if (hasModuleAccess) {
      return true;
    }

    throw new ForbiddenException(
      `Access Denied: Missing required permission [${requiredPermissions.join(', ')}]`,
    );
  }
}
