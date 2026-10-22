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
  ForbiddenException,
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
  @RequirePermissions(
    'CUSTOMERS:CREATE',
    'CRM:CREATE',
    'CUSTOMERS:VIEW',
    'CRM:VIEW',
    'PURCHASE:CREATE',
    'PURCHASE:VIEW',
    'VENDORS:CREATE',
    'VENDORS:VIEW',
    'MATERIALS:CREATE',
    'MATERIALS:VIEW',
    'INVENTORY:CREATE',
    'INVENTORY:VIEW',
    'BULK_IMPORT:CREATE',
    'BULK_IMPORT:VIEW',
  )
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

    // Granular PBAC check: ensure caller has permission for the specified target entity
    const userPerms: string[] = req.user?.permissions || [];
    const userRoles: string[] = req.user?.roles || [];
    const isAdmin =
      req.user?.isAdmin === true ||
      userRoles.some((r) => ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r));

    if (!isAdmin) {
      if (target === ImportTarget.CUSTOMER) {
        const canCustomer = userPerms.some((p) =>
          [
            'CUSTOMERS:CREATE',
            'CRM:CREATE',
            'CUSTOMERS:VIEW',
            'CRM:VIEW',
            'BULK_IMPORT:CREATE',
            'BULK_IMPORT:VIEW',
          ].includes(p),
        );
        if (!canCustomer) {
          throw new ForbiddenException(
            'Access Denied: Missing CRM/Customer permission to parse and preview spreadsheet',
          );
        }
      } else if (target === ImportTarget.MATERIAL) {
        const canMaterial = userPerms.some((p) =>
          [
            'MATERIALS:CREATE',
            'MATERIALS:VIEW',
            'INVENTORY:CREATE',
            'INVENTORY:VIEW',
            'BULK_IMPORT:CREATE',
            'BULK_IMPORT:VIEW',
          ].includes(p),
        );
        if (!canMaterial) {
          throw new ForbiddenException(
            'Access Denied: Missing Material/Inventory permission to parse and preview spreadsheet',
          );
        }
      } else {
        const canVendor = userPerms.some((p) =>
          [
            'VENDORS:CREATE',
            'PURCHASE:CREATE',
            'VENDORS:VIEW',
            'PURCHASE:VIEW',
            'BULK_IMPORT:CREATE',
            'BULK_IMPORT:VIEW',
          ].includes(p),
        );
        if (!canVendor) {
          throw new ForbiddenException(
            'Access Denied: Missing Vendor/Purchase permission to parse and preview spreadsheet',
          );
        }
      }
    }

    const fileName = file?.originalname || body.fileName || 'spreadsheet.xlsx';
    const enableGstEnrichment =
      body.enableGstEnrichment !== 'false' && body.enableGstEnrichment !== false;
    const checkDuplicates =
      body.checkDuplicates !== 'false' && body.checkDuplicates !== false;
    const sheetName = body.sheetName ? String(body.sheetName).trim() : undefined;

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
      sheetName,
      columnMapping,
      enableGstEnrichment,
      checkDuplicates,
    };

    return this.bulkImportService.parseAndPreview(dto, file?.buffer, req.user);
  }

  @Post('execute')
  @RequirePermissions(
    'CUSTOMERS:CREATE',
    'CRM:CREATE',
    'VENDORS:CREATE',
    'PURCHASE:CREATE',
    'MATERIALS:CREATE',
    'INVENTORY:CREATE',
    'BULK_IMPORT:CREATE',
  )
  @ApiOperation({
    summary: 'Execute bulk import for approved records into database with audit trail',
  })
  async executeImport(@Body() dto: ExecuteImportDto, @Req() req: any) {
    // Granular PBAC check: ensure caller has creation permission for the specified target entity
    const userPerms: string[] = req.user?.permissions || [];
    const userRoles: string[] = req.user?.roles || [];
    const isAdmin =
      req.user?.isAdmin === true ||
      userRoles.some((r) => ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r));

    if (!isAdmin) {
      if (dto.target === ImportTarget.CUSTOMER) {
        const canCustomer = userPerms.some((p) =>
          ['CUSTOMERS:CREATE', 'CRM:CREATE', 'BULK_IMPORT:CREATE'].includes(p),
        );
        if (!canCustomer) {
          throw new ForbiddenException(
            'Access Denied: Missing CRM:CREATE or CUSTOMERS:CREATE permission to execute import',
          );
        }
      } else if (dto.target === ImportTarget.MATERIAL) {
        const canMaterial = userPerms.some((p) =>
          ['MATERIALS:CREATE', 'INVENTORY:CREATE', 'BULK_IMPORT:CREATE'].includes(p),
        );
        if (!canMaterial) {
          throw new ForbiddenException(
            'Access Denied: Missing MATERIALS:CREATE or INVENTORY:CREATE permission to execute import',
          );
        }
      } else {
        const canVendor = userPerms.some((p) =>
          ['VENDORS:CREATE', 'PURCHASE:CREATE', 'BULK_IMPORT:CREATE'].includes(p),
        );
        if (!canVendor) {
          throw new ForbiddenException(
            'Access Denied: Missing VENDORS:CREATE or PURCHASE:CREATE permission to execute import',
          );
        }
      }
    }

    return this.bulkImportService.executeImport(dto, req.user, req.ip);
  }

  @Get('template/:target')
  @RequirePermissions(
    'CUSTOMERS:EXPORT',
    'CRM:EXPORT',
    'CUSTOMERS:VIEW',
    'CRM:VIEW',
    'VENDORS:EXPORT',
    'PURCHASE:EXPORT',
    'VENDORS:VIEW',
    'PURCHASE:VIEW',
    'MATERIALS:EXPORT',
    'MATERIALS:VIEW',
    'INVENTORY:EXPORT',
    'INVENTORY:VIEW',
    'BULK_IMPORT:VIEW',
  )
  @ApiOperation({ summary: 'Download standard sample import template CSV' })
  async downloadTemplate(
    @Param('target') targetParam: string,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const target =
      targetParam.toUpperCase() === 'MATERIAL'
        ? ImportTarget.MATERIAL
        : targetParam.toUpperCase() === 'VENDOR'
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
  @RequirePermissions(
    'CUSTOMERS:EXPORT',
    'CRM:EXPORT',
    'CUSTOMERS:VIEW',
    'CRM:VIEW',
    'VENDORS:EXPORT',
    'PURCHASE:EXPORT',
    'VENDORS:VIEW',
    'PURCHASE:VIEW',
    'BULK_IMPORT:VIEW',
  )
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

