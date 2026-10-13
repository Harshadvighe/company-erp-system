import { Module } from '@nestjs/common';
import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [CustomersController],
  providers: [CustomersService, AuditService, SequenceService],
  exports: [CustomersService],
})
export class CustomersModule {}
