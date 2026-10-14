import { Controller, Get, Param, Query, Req, Res, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { Response } from 'express';
import { AuditService } from '../../core/audit/audit.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { AuditLogFilterDto } from './dto/audit-query.dto';

@ApiTags('Audit Trail')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/audit-logs')
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get()
  @RequirePermissions('AUDIT:VIEW')
  @ApiOperation({ summary: 'Paginated enterprise audit log query with rich filters' })
  @ApiResponse({ status: 200, description: 'Filtered paginated audit log events' })
  async getLogs(@Query() filter: AuditLogFilterDto) {
    return this.auditService.getLogs(filter);
  }

  @Get('export')
  @RequirePermissions('AUDIT:EXPORT')
  @ApiOperation({ summary: 'Export filtered audit logs to RFC 4180 CSV and audit the export' })
  @ApiResponse({ status: 200, description: 'CSV file attachment' })
  async exportLogs(
    @Query() filter: AuditLogFilterDto,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const csvContent = await this.auditService.exportLogsToCsv(filter, req.user, req);
    const filename = `audit-logs-export-${new Date().toISOString().slice(0, 10)}.csv`;

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.status(200).send(csvContent);
  }

  @Get(':id')
  @RequirePermissions('AUDIT:VIEW')
  @ApiOperation({ summary: 'Get single audit log event details by ID' })
  @ApiResponse({ status: 200, description: 'Detailed audit log record with actor and diffs' })
  @ApiResponse({ status: 404, description: 'Audit log not found' })
  async getLogById(@Param('id') id: string) {
    return this.auditService.getLogById(id);
  }
}
