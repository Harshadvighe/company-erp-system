import { Module } from '@nestjs/common';
import { DocumentsController } from './documents.controller';
import { DocumentsService } from './documents.service';
import { PrismaService } from '../../core/database/prisma.service';
import {
  FileStorageService,
  LocalFileStorageService,
  S3FileStorageService,
} from '../../core/storage/file-storage.service';

@Module({
  controllers: [DocumentsController],
  providers: [
    DocumentsService,
    PrismaService,
    {
      provide: FileStorageService,
      useFactory: () => {
        const provider = process.env.STORAGE_PROVIDER || 'local';
        if (provider === 's3') {
          return new S3FileStorageService();
        }
        return new LocalFileStorageService();
      },
    },
  ],
  exports: [DocumentsService],
})
export class DocumentsModule {}
