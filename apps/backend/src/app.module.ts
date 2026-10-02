import { Module } from '@nestjs/common';
import { AuthModule } from './modules/auth/auth.module';
import { AdminModule } from './modules/admin/admin.module';
import { CustomersModule } from './modules/customers/customers.module';
import { VendorsModule } from './modules/vendors/vendors.module';
import { ProductsModule } from './modules/products/products.module';
import { CrmModule } from './modules/crm/crm.module';
import { PanelManufacturingModule } from './modules/panel-manufacturing/panel-manufacturing.module';
import { DocumentsModule } from './modules/documents/documents.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { AuditModule } from './modules/audit/audit.module';
import { DashboardModule } from './modules/dashboard/dashboard.module';
import { PurchaseModule } from './modules/purchase/purchase.module';

@Module({
  imports: [
    AuthModule,
    AdminModule,
    CustomersModule,
    VendorsModule,
    ProductsModule,
    CrmModule,
    PanelManufacturingModule,
    DocumentsModule,
    NotificationsModule,
    AuditModule,
    DashboardModule,
    PurchaseModule,
  ],
})
export class AppModule {}
