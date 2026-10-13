import { Module } from '@nestjs/common';
import { DocumentsController } from './documents.controller';
import { DocumentsService } from './documents.service';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import {
  FileStorageService,
  LocalFileStorageService,
  S3FileStorageService,
  SupabaseFileStorageService,
} from '../../core/storage/file-storage.service';

@Module({
  controllers: [DocumentsController],
  providers: [
    DocumentsService,
    PrismaService,
    SequenceService,
    {
      provide: FileStorageService,
      useFactory: () => {
        const provider = (process.env.STORAGE_PROVIDER || 'local').toLowerCase();
        if (provider === 'supabase') {
          return new SupabaseFileStorageService();
        }
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
