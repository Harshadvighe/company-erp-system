import { Module } from '@nestjs/common';
import { BulkImportController } from './bulk-import.controller';
import { BulkImportService } from './bulk-import.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';
import { SequenceService } from '../../core/database/sequence.service';
import { GstVerificationService } from '../crm/gst-verification.service';
import { CustomersModule } from '../customers/customers.module';

@Module({
  imports: [CustomersModule],
  controllers: [BulkImportController],
  providers: [
    BulkImportService,
    PrismaService,
    AuditService,
    SequenceService,
    GstVerificationService,
  ],
  exports: [BulkImportService],
})
export class BulkImportModule {}
