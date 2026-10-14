import { Global, Module } from '@nestjs/common';
import { PermissionResolverService } from './permission-resolver.service';
import { PermissionsGuard } from '../../common/guards/permissions.guard';

@Global()
@Module({
  providers: [PermissionResolverService, PermissionsGuard],
  exports: [PermissionResolverService, PermissionsGuard],
})
export class PermissionsModule {}
