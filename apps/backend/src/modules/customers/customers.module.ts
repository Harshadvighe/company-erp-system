import { Module } from '@nestjs/common';
import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [CustomersController],
  providers: [CustomersService, PrismaService, AuditService],
  exports: [CustomersService],
})
export class CustomersModule {}
