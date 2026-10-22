import { Module } from '@nestjs/common';
import { DatabaseModule } from './core/database/database.module';
import { PermissionsModule } from './core/permissions/permissions.module';
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
import { StaffModule } from './modules/staff/staff.module';
import { ProjectsModule } from './modules/projects/projects.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { MyWorkModule } from './modules/my-work/my-work.module';
import { HrModule } from './modules/hr/hr.module';
import { SalesModule } from './modules/sales/sales.module';
import { InventoryModule } from './modules/inventory/inventory.module';
import { ReportsModule } from './modules/reports/reports.module';
import { BulkImportModule } from './modules/bulk-import/bulk-import.module';
import { MaterialsModule } from './modules/materials/materials.module';

@Module({
  imports: [
    DatabaseModule,
    PermissionsModule,
    AuthModule,
    AdminModule,
    CustomersModule,
    VendorsModule,
    ProductsModule,
    MaterialsModule,
    CrmModule,
    SalesModule,
    PanelManufacturingModule,
    DocumentsModule,
    NotificationsModule,
    AuditModule,
    DashboardModule,
    PurchaseModule,
    StaffModule,
    ProjectsModule,
    TasksModule,
    MyWorkModule,
    HrModule,
    InventoryModule,
    ReportsModule,
    BulkImportModule,
  ],
})
export class AppModule {}

