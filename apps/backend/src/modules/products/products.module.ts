import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [ProductsController],
  providers: [ProductsService, AuditService],
  exports: [ProductsService],
})
export class ProductsModule {}
