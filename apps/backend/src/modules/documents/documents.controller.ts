import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Body,
  Req,
  Res,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiConsumes } from '@nestjs/swagger';
import { Response } from 'express';
import * as path from 'path';
import * as fs from 'fs';
import { DocumentsService } from './documents.service';
import { AuditService } from '../../core/audit/audit.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

// Simple mime type resolver without external dependency
function getMimeType(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  const mimeMap: Record<string, string> = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.pdf': 'application/pdf',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.m4a': 'audio/mp4',
    '.ogg': 'audio/ogg',
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.avi': 'video/x-msvideo',
    '.mkv': 'video/x-matroska',
    '.doc': 'application/msword',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls': 'application/vnd.ms-excel',
    '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.txt': 'text/plain',
    '.csv': 'text/csv',
    '.zip': 'application/zip',
  };
  return mimeMap[ext] || 'application/octet-stream';
}

@ApiTags('Documents')
@Controller('api/v1/documents')
export class DocumentsController {
  constructor(
    private readonly documentsService: DocumentsService,
    private readonly auditService: AuditService,
  ) {}

  @Get()
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions('CRM:VIEW', 'CUSTOMERS:VIEW', 'SALES:VIEW', 'DOCUMENTS:VIEW', 'HR:VIEW', 'STAFF:VIEW')
  @ApiOperation({ summary: 'List all documents in global repository' })
  async getAllDocuments(@Req() req: any) {
    const docs = await this.documentsService.getAllDocuments(req.user);
    return docs.map((doc) => {
      const relativePath = doc.storagePath.replace(/\\/g, '/');
      const encodedPath = relativePath.split('/').map(encodeURIComponent).join('/');
      const filePreviewUrl = `/api/v1/documents/files/${encodedPath}`;
      return {
        ...doc,
        filePath: filePreviewUrl,
        fileUrl: filePreviewUrl,
        url: filePreviewUrl,
      };
    });
  }

  @Get('entity')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions('CRM:VIEW', 'CUSTOMERS:VIEW', 'SALES:VIEW', 'DOCUMENTS:VIEW', 'HR:VIEW', 'STAFF:VIEW')
  @ApiOperation({ summary: 'List documents for specific entity (Customer, Product, Project, etc.)' })
  async getByEntity(
    @Query('type') entityType: string,
    @Query('id') entityId: string,
    @Req() req: any,
  ) {

    const docs = await this.documentsService.getDocumentsByEntity(entityType, entityId, req.user);
    return docs.map((doc) => {
      const relativePath = doc.storagePath.replace(/\\/g, '/');
      const encodedPath = relativePath.split('/').map(encodeURIComponent).join('/');
      const filePreviewUrl = `/api/v1/documents/files/${encodedPath}`;
      return {
        ...doc,
        filePath: filePreviewUrl,
        fileUrl: filePreviewUrl,
        url: filePreviewUrl,
      };
    });
  }

  @Get('files/*')
  @ApiOperation({ summary: 'Serve uploaded file by storage path (for media/photo preview)' })
  async serveFile(@Param('0') filePath: string, @Res() res: Response) {
    try {
      const decodedPath = decodeURIComponent(filePath).replace(/\\/g, '/');
      const safeRelativePath = decodedPath.replace(/^\/+/, '').replace(/\.\.\//g, '');
      const provider = (process.env.STORAGE_PROVIDER || 'local').toLowerCase();

      if (provider === 'local') {
        const storageEnvPath = process.env.STORAGE_LOCAL_BASE_PATH;
        const basePath = storageEnvPath
          ? (path.isAbsolute(storageEnvPath) ? storageEnvPath : path.resolve(process.cwd(), storageEnvPath))
          : path.resolve(__dirname, '../../../../../storage');

        const fullPath = path.resolve(basePath, safeRelativePath);
        const normalizedBase = path.resolve(basePath).toLowerCase().replace(/\\/g, '/');
        const normalizedFull = path.resolve(fullPath).toLowerCase().replace(/\\/g, '/');

        // Ensure resolved path is inside basePath (case-insensitive for Windows)
        if (!normalizedFull.startsWith(normalizedBase)) {
          return res.status(403).json({ message: 'Forbidden' });
        }

        if (!fs.existsSync(fullPath)) {
          return res.status(404).json({ message: 'File not found' });
        }

        const mimeType = getMimeType(fullPath);
        res.setHeader('Content-Type', mimeType);
        res.setHeader('Cache-Control', 'public, max-age=86400');
        res.setHeader('Access-Control-Allow-Origin', '*');
        const stream = fs.createReadStream(fullPath);
        return stream.pipe(res);
      }

      // For cloud providers (supabase, s3), fetch buffer through abstracted storage service
      const mimeType = getMimeType(safeRelativePath);
      res.setHeader('Content-Type', mimeType);
      res.setHeader('Cache-Control', 'public, max-age=86400');
      res.setHeader('Access-Control-Allow-Origin', '*');

      const fileBuffer = await this.documentsService.downloadFileByPath(safeRelativePath);
      return res.send(fileBuffer);
    } catch (e: any) {
      if (e?.message && e.message.includes('not found')) {
        return res.status(404).json({ message: 'File not found' });
      }
      return res.status(500).json({ message: 'Error serving file' });
    }
  }

  @Post('upload')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions('CRM:CREATE', 'CRM:EDIT', 'CUSTOMERS:EDIT', 'SALES:CREATE', 'SALES:EDIT', 'DOCUMENTS:CREATE', 'HR:CREATE', 'STAFF:CREATE')
  @ApiOperation({ summary: 'Upload file document using abstracted FileStorageService' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  async uploadFile(
    @UploadedFile() file: Express.Multer.File,
    @Body('entityType') entityType: string,
    @Body('entityId') entityId: string,
    @Body('documentType') documentType: string,
    @Req() req: any,
  ) {
    const doc = await this.documentsService.uploadDocument(
      file,
      entityType || 'GENERAL',
      entityId || 'SYS',
      documentType || 'ATTACHMENT',
      req.user?.fullName || 'System User',
      req.user,
    );
    // Return filePath for use in Flutter app (preview URL)
    const relativePath = doc.storagePath.replace(/\\/g, '/');
    const encodedPath = relativePath.split('/').map(encodeURIComponent).join('/');
    const filePreviewUrl = `/api/v1/documents/files/${encodedPath}`;
    return {
      ...doc,
      filePath: filePreviewUrl,
      fileUrl: filePreviewUrl,
      url: filePreviewUrl,
    };
  }

  @Get(':id/download')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions('DOCUMENTS:EXPORT', 'DOCUMENTS:VIEW', 'CRM:VIEW', 'CUSTOMERS:VIEW', 'SALES:VIEW', 'HR:VIEW', 'STAFF:VIEW')
  @ApiOperation({ summary: 'Download document stream with audit logging' })
  async downloadFile(@Param('id') id: string, @Req() req: any, @Res() res: Response) {
    const { buffer, doc } = await this.documentsService.getFileBuffer(id, req.user);

    await this.auditService.recordAction({
      req,
      actor: req.user,
      action: 'DOWNLOAD',
      module: 'DOCUMENTS',
      entityType: doc.entityType || 'DocumentItem',
      entityId: doc.id,
      outcome: 'SUCCESS',
      details: {
        documentCode: doc.documentCode,
        fileName: doc.fileName,
        fileSize: doc.fileSize,
        mimeType: doc.mimeType,
        documentType: doc.documentType,
      },
    });

    res.setHeader('Content-Type', doc.mimeType);
    res.setHeader('Content-Disposition', `attachment; filename="${doc.fileName}"`);
    res.send(buffer);
  }

  @Put(':id/replace')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions('CRM:EDIT', 'CUSTOMERS:EDIT', 'SALES:EDIT', 'DOCUMENTS:EDIT', 'HR:EDIT', 'STAFF:EDIT')

  @ApiOperation({ summary: 'Replace an existing document file with authorization checks' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  async replaceFile(
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: any,
  ) {
    const doc = await this.documentsService.replaceDocument(id, file, req.user);
    const relativePath = doc.storagePath.replace(/\\/g, '/');
    const encodedPath = relativePath.split('/').map(encodeURIComponent).join('/');
    const filePreviewUrl = `/api/v1/documents/files/${encodedPath}`;
    return {
      ...doc,
      filePath: filePreviewUrl,
      fileUrl: filePreviewUrl,
      url: filePreviewUrl,
    };
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions('CRM:EDIT', 'CUSTOMERS:EDIT', 'SALES:EDIT', 'DOCUMENTS:EDIT')
  @ApiOperation({ summary: 'Replace an existing document' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  async updateFile(
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: any,
  ) {
    return this.replaceFile(id, file, req);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, PermissionsGuard)
  @RequirePermissions('CRM:DELETE', 'CRM:EDIT', 'CUSTOMERS:DELETE', 'CUSTOMERS:EDIT', 'DOCUMENTS:DELETE')
  @ApiOperation({ summary: 'Delete document with authorization check' })
  async deleteDocument(@Param('id') id: string, @Req() req: any) {
    return this.documentsService.deleteDocument(id, req.user);
  }
}
