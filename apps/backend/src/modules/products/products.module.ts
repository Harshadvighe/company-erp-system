import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [ProductsController],
  providers: [ProductsService, PrismaService, AuditService],
  exports: [ProductsService],
})
export class ProductsModule {}
