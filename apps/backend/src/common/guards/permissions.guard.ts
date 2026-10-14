import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { AuditService } from '../../core/audit/audit.service';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private auditService?: AuditService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const req = context.switchToHttp().getRequest();
    const user = req.user;

    if (!user) {
      if (this.auditService) {
        await this.auditService.logAuthFailure({
          req,
          requiredPermissions,
          reason: 'User context missing or unauthenticated',
        });
      }
      throw new ForbiddenException('User context missing or unauthenticated');
    }

    const userPermissions: string[] = user.permissions || [];
    const hasPermission = requiredPermissions.some((perm) => userPermissions.includes(perm));

    if (!hasPermission) {
      if (this.auditService) {
        await this.auditService.logAuthFailure({
          req,
          user,
          requiredPermissions,
          reason: `Access Denied: Missing required permission [${requiredPermissions.join(', ')}]`,
        });
      }

      throw new ForbiddenException(
        `Access Denied: Missing required permission [${requiredPermissions.join(', ')}]`,
      );
    }

    return true;
  }
}
