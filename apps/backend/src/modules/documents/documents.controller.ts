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
import { DocumentsService } from './documents.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Documents')
@UseGuards(JwtAuthGuard)
@Controller('api/v1/documents')
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @Get()
  @ApiOperation({ summary: 'List all documents in global repository' })
  async getAllDocuments() {
    return this.documentsService.getAllDocuments();
  }

  @Get('entity')
  @ApiOperation({ summary: 'List documents for specific entity (Customer, Product, Project, etc.)' })
  async getByEntity(@Query('type') entityType: string, @Query('id') entityId: string) {
    return this.documentsService.getDocumentsByEntity(entityType, entityId);
  }

  @Post('upload')
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
    return this.documentsService.uploadDocument(
      file,
      entityType || 'GENERAL',
      entityId || 'SYS',
      documentType || 'ATTACHMENT',
      req.user?.fullName || 'System User',
    );
  }

  @Get(':id/download')
  @ApiOperation({ summary: 'Download document stream' })
  async downloadFile(@Param('id') id: string, @Res() res: Response) {
    const { buffer, doc } = await this.documentsService.getFileBuffer(id);
    res.setHeader('Content-Type', doc.mimeType);
    res.setHeader('Content-Disposition', `attachment; filename="${doc.fileName}"`);
    res.send(buffer);
  }
}
