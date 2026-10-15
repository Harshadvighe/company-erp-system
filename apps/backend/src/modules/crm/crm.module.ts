import { Module } from '@nestjs/common';
import { CrmController } from './crm.controller';
import { CrmService } from './crm.service';
import { CrmSchedulerService } from './crm-scheduler.service';
import { GstVerificationService } from './gst-verification.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';
import { NotificationService } from '../../core/notifications/notification.service';
import {
  FileStorageService,
  LocalFileStorageService,
  S3FileStorageService,
  SupabaseFileStorageService,
} from '../../core/storage/file-storage.service';

@Module({
  controllers: [CrmController],
  providers: [
    CrmService,
    CrmSchedulerService,
    NotificationService,
    GstVerificationService,
    AuditService,
    SequenceService,
    {
      provide: FileStorageService,
      useFactory: () => {
        const driver = process.env.STORAGE_DRIVER || process.env.STORAGE_PROVIDER || 'local';
        if (driver === 'supabase') return new SupabaseFileStorageService();
        if (driver === 's3') return new S3FileStorageService();
        return new LocalFileStorageService();
      },
    },
  ],
  exports: [CrmService, CrmSchedulerService, GstVerificationService, FileStorageService],
})
export class CrmModule {}

