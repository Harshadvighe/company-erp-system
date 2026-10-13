import { Module } from '@nestjs/common';
import { BulkImportController } from './bulk-import.controller';
import { BulkImportService } from './bulk-import.service';
import { AuditService } from '../../core/audit/audit.service';
import { SequenceService } from '../../core/database/sequence.service';
import { GstVerificationService } from '../crm/gst-verification.service';
import { CustomersModule } from '../customers/customers.module';

@Module({
  imports: [CustomersModule],
  controllers: [BulkImportController],
  providers: [
    BulkImportService,
    AuditService,
    SequenceService,
    GstVerificationService,
  ],
  exports: [BulkImportService],
})
export class BulkImportModule {}
