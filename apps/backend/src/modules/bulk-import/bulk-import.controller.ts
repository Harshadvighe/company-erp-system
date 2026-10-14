import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Req,
  Res,
  HttpStatus,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { Response } from 'express';
import { BulkImportService } from './bulk-import.service';
import { AuditService } from '../../core/audit/audit.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import {
  ImportTarget,
  ParseAndPreviewDto,
  ExecuteImportDto,
  GenerateErrorReportDto,
} from './dto/bulk-import.dto';

@ApiTags('Bulk Import')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/bulk-import')
export class BulkImportController {
  constructor(
    private readonly bulkImportService: BulkImportService,
    private readonly auditService: AuditService,
  ) {}

  @Post('parse-preview')
  @RequirePermissions('CUSTOMERS:CREATE', 'PURCHASE:CREATE', 'CUSTOMERS:VIEW', 'VENDORS:CREATE')
  @ApiOperation({
    summary: 'Upload Excel/CSV file, auto-detect columns, perform live GST enrichment & return preview',
  })
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data', 'application/json')
  async parseAndPreview(
    @UploadedFile() file: Express.Multer.File | undefined,
    @Body() body: any,
    @Req() req: any,
  ) {
    const target = (body.target as ImportTarget) || ImportTarget.CUSTOMER;
    const fileName = file?.originalname || body.fileName || 'spreadsheet.xlsx';
    const enableGstEnrichment =
      body.enableGstEnrichment !== 'false' && body.enableGstEnrichment !== false;
    const checkDuplicates =
      body.checkDuplicates !== 'false' && body.checkDuplicates !== false;

    let columnMapping: Record<string, string> | undefined;
    if (body.columnMapping) {
      if (typeof body.columnMapping === 'string') {
        try {
          columnMapping = JSON.parse(body.columnMapping);
        } catch (_) {}
      } else {
        columnMapping = body.columnMapping;
      }
    }

    const dto: ParseAndPreviewDto = {
      target,
      fileName,
      fileBase64: body.fileBase64,
      columnMapping,
      enableGstEnrichment,
      checkDuplicates,
    };

    return this.bulkImportService.parseAndPreview(dto, file?.buffer, req.user);
  }

  @Post('execute')
  @RequirePermissions('CUSTOMERS:CREATE', 'PURCHASE:CREATE', 'VENDORS:CREATE')
  @ApiOperation({
    summary: 'Execute bulk import for approved records into database with audit trail',
  })
  async executeImport(@Body() dto: ExecuteImportDto, @Req() req: any) {
    return this.bulkImportService.executeImport(dto, req.user, req.ip);
  }

  @Get('template/:target')
  @RequirePermissions('CUSTOMERS:EXPORT', 'VENDORS:EXPORT', 'PURCHASE:EXPORT', 'CUSTOMERS:VIEW', 'VENDORS:VIEW')
  @ApiOperation({ summary: 'Download standard sample import template CSV' })
  async downloadTemplate(
    @Param('target') targetParam: string,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const target =
      targetParam.toUpperCase() === 'VENDOR'
        ? ImportTarget.VENDOR
        : ImportTarget.CUSTOMER;

    const csvContent = this.bulkImportService.getSampleTemplate(target);
    const fileName = `saark_${target.toLowerCase()}_sample_template.csv`;

    await this.auditService.recordAction({
      req,
      actor: req.user,
      action: 'EXPORT',
      module: 'BULK_IMPORT',
      entityType: 'ImportTemplate',
      outcome: 'SUCCESS',
      details: { target, templateName: fileName },
    });

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
    res.status(HttpStatus.OK).send('\uFEFF' + csvContent);
  }

  @Post('error-report')
  @RequirePermissions('CUSTOMERS:EXPORT', 'VENDORS:EXPORT', 'PURCHASE:EXPORT', 'CUSTOMERS:VIEW', 'VENDORS:VIEW')
  @ApiOperation({ summary: 'Generate and download sanitized CSV error report' })
  async downloadErrorReport(
    @Body() dto: GenerateErrorReportDto,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const csvContent = this.bulkImportService.generateErrorReport(dto);
    const fileName = `saark_${dto.target.toLowerCase()}_import_errors_${Date.now()}.csv`;

    await this.auditService.recordAction({
      req,
      actor: req.user,
      action: 'EXPORT',
      module: 'BULK_IMPORT',
      entityType: 'ErrorReport',
      outcome: 'SUCCESS',
      details: { target: dto.target, errorCount: dto.errors?.length || 0 },
    });

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
    res.status(HttpStatus.OK).send('\uFEFF' + csvContent);
  }
}
