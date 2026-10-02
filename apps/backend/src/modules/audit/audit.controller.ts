import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AuditService } from '../../core/audit/audit.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Audit Trail')
@UseGuards(JwtAuthGuard)
@Controller('api/v1/audit-logs')
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get()
  @ApiOperation({ summary: 'List recent system audit log events' })
  async getLogs(@Query('limit') limit?: number) {
    return this.auditService.getRecentLogs(limit || 50);
  }
}
