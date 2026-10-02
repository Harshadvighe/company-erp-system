import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { FileStorageService } from '../../core/storage/file-storage.service';

@Injectable()
export class DocumentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fileStorageService: FileStorageService,
  ) {}

  async uploadDocument(file: Express.Multer.File, entityType: string, entityId: string, documentType: string, uploadedBy: string) {
    const storageResult = await this.fileStorageService.uploadFile(file, entityType, entityId);

    const count = await this.prisma.documentItem.count();
    const documentCode = `DOC-2026-${String(count + 1).padStart(5, '0')}`;

    return this.prisma.documentItem.create({
      data: {
        documentCode,
        name: storageResult.fileName,
        documentType: documentType || 'GENERAL',
        entityType,
        entityId,
        fileName: storageResult.fileName,
        fileSize: storageResult.fileSize,
        mimeType: storageResult.mimeType,
        storagePath: storageResult.storagePath,
        uploadedBy,
      },
    });
  }

  async getDocumentsByEntity(entityType: string, entityId: string) {
    return this.prisma.documentItem.findMany({
      where: { entityType, entityId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAllDocuments() {
    return this.prisma.documentItem.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async getFileBuffer(documentId: string) {
    const doc = await this.prisma.documentItem.findUnique({ where: { id: documentId } });
    if (!doc) throw new NotFoundException('Document record not found');
    
    const buffer = await this.fileStorageService.downloadFile(doc.storagePath);
    return { buffer, doc };
  }
}
