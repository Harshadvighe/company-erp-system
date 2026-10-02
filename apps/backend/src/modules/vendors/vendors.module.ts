import { Module } from '@nestjs/common';
import { VendorsController } from './vendors.controller';
import { VendorsService } from './vendors.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [VendorsController],
  providers: [VendorsService, PrismaService, AuditService],
  exports: [VendorsService],
})
export class VendorsModule {}
