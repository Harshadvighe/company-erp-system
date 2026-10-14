import { Controller, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { MyWorkService } from './my-work.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('My Work')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/my-work')
export class MyWorkController {
  constructor(private readonly myWorkService: MyWorkService) {}

  @Get('summary')
  @RequirePermissions('MY_WORK:VIEW')
  @ApiOperation({ summary: 'Get personalized dashboard summary for logged-in user' })
  getSummary(@Req() req: any) {
    return this.myWorkService.getSummary(req.user?.staffId, req.user);
  }
}
