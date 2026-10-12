import {
  Controller,
  Get,
  Post,
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
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

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
  constructor(private readonly documentsService: DocumentsService) {}

  @Get()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'List all documents in global repository' })
  async getAllDocuments() {
    const docs = await this.documentsService.getAllDocuments();
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
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'List documents for specific entity (Customer, Product, Project, etc.)' })
  async getByEntity(@Query('type') entityType: string, @Query('id') entityId: string) {
    const docs = await this.documentsService.getDocumentsByEntity(entityType, entityId);
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
      const storageEnvPath = process.env.STORAGE_LOCAL_BASE_PATH;
      const basePath = storageEnvPath
        ? (path.isAbsolute(storageEnvPath) ? storageEnvPath : path.resolve(process.cwd(), storageEnvPath))
        : path.resolve(__dirname, '../../../../../storage');

      const decodedPath = decodeURIComponent(filePath).replace(/\\/g, '/');
      const safeRelativePath = decodedPath.replace(/\.\.\//g, '');
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
      stream.pipe(res);
    } catch (e) {
      res.status(500).json({ message: 'Error serving file' });
    }
  }

  @Post('upload')
  @UseGuards(JwtAuthGuard)
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
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Download document stream' })
  async downloadFile(@Param('id') id: string, @Res() res: Response) {
    const { buffer, doc } = await this.documentsService.getFileBuffer(id);
    res.setHeader('Content-Type', doc.mimeType);
    res.setHeader('Content-Disposition', `attachment; filename="${doc.fileName}"`);
    res.send(buffer);
  }
}
