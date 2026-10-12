import { Module } from '@nestjs/common';
import { VendorsController } from './vendors.controller';
import { VendorsService } from './vendors.service';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';
import { GstVerificationService } from '../crm/gst-verification.service';

@Module({
  controllers: [VendorsController],
  providers: [VendorsService, PrismaService, AuditService, SequenceService, GstVerificationService],
  exports: [VendorsService],
})
export class VendorsModule {}

