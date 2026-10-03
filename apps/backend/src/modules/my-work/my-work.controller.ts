import { Controller, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { MyWorkService } from './my-work.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('My Work')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/my-work')
export class MyWorkController {
  constructor(private readonly myWorkService: MyWorkService) {}

  @Get('summary')
  @ApiOperation({ summary: 'Get personalized dashboard summary for logged-in user' })
  getSummary(@Req() req: any) {
    return this.myWorkService.getSummary(req.user?.staffId, req.user);
  }
}
