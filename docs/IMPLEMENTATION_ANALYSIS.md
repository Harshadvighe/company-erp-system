# SAARK ERP — Comprehensive Implementation Analysis
**System**: Saark Exploration Private Limited ERP  
**Scope**: Staff Foundation, Dynamic RBAC, Task Management, Project Management, and Zero Extra UI Architecture  
**Date**: October 2026  
**Status**: Architecture Analysis Complete — Pre-Implementation Phase

---

## 1. Existing Architecture
The SAARK ERP is structured as a client-server multi-platform enterprise system:
- **Monorepo Structure**:
  - `apps/backend`: NestJS v10 application providing RESTful APIs, Swagger documentation, Prisma ORM, and JWT authentication.
  - `apps/mobile`: Flutter 3.x client supporting multi-platform deployment (Web, Android APK, and iOS ready), state-managed via Riverpod and routed with GoRouter.
- **Database Engine**: Dual SQLite / PostgreSQL setup via Prisma. Currently SQLite for local/staging simplicity (`prisma/dev.db`), architected for zero-downtime PostgreSQL migration.
- **Storage Subsystem**: Local disk storage mounted in `storage/` for documents, invoices, purchase orders, panel specification PDFs, and attachments.
- **Deployment Topology**:
  - Backend deployed live on Render Cloud (`https://saark-erp-backend.onrender.com`).
  - Mobile client packaged with release APK and Flutter Web served via Cloudflare tunnel / local web dev server.

---

## 2. Existing Frontend
- **Framework & Libraries**: Flutter 3.29, `flutter_riverpod` for declarative state management, `go_router` for route declaration and navigation redirection, `dio` for HTTP networking.
- **Theme & UI System**: Custom dark enterprise theme (`AppTheme`) with Saark signature orange accent (`#FF6B00` / `#FF8800`), slate card containers, Inter font styling, and responsive layout shells (`_DesktopShell`, `_TabletShell`, `_MobileShell`).
- **Implemented Feature Modules in UI**:
  - **Authentication**: `LoginPage` with JWT token persistence via `flutter_secure_storage` / `shared_preferences`.
  - **Dashboard**: `DashboardPage` containing hardcoded KPI grid, hardcoded Quick Actions, recent customer stream, and pending follow-up cards.
  - **Customers & CRM**: `CustomersListPage`, `CustomerDetailPage`, `CustomerFormPage`, `LeadsListPage`, `EnquiriesListPage`.
  - **Vendors & Products**: `VendorsListPage`, `ProductsListPage`.
  - **Purchase Module**: Comprehensive multi-tab procurement suite (`PurchaseDashboardPage`, orders, RFQs, invoices, debit notes, cheque management modal).
  - **Production**: `PanelSpecsListPage`, `PanelSpecDetailPage`, `PanelSpecFormPage`.

---

## 3. Existing Backend
- **Framework**: NestJS modular architecture with TypeScript.
- **Modules Present**:
  - `AuthModule`: Handles user login, password verification (bcrypt), and JWT token minting.
  - `AdminModule`: Provides CRUD endpoints for departments, users, roles, permissions, company metadata, financial years, tax rates, and payment modes.
  - `CustomersModule`: Comprehensive customer master, multi-contact management, interaction logging.
  - `VendorsModule`: Vendor master, payment terms, bank details, category association.
  - `ProductsModule`: Item master, product categories, unit master, pricing.
  - `PurchaseModule`: Purchase requisitions, RFQs, purchase orders, inward goods inspection, vendor invoices, debit notes, cheques.
  - `PanelManufacturingModule`: Technical panel specifications, engineering attributes, panel BOM items.
  - `AuditModule`: Audit service tracking user action, entity type, entity ID, and IP address.
  - `NotificationsModule`: In-app notification creation and delivery.
  - `DocumentsModule`: Attachment uploads and physical file persistence.

---

## 4. Existing Database
- **Prisma Schema (`apps/backend/prisma/schema.prisma`)**:
  - **Auth & Access Control**: `User`, `Role`, `Permission`, `UserRole`, `RolePermission`.
  - **Organization Masters**: `Company`, `Department`, `FinancialYear`, `TaxRate`, `PaymentMode`.
  - **Business Entities**: `Customer`, `CustomerContact`, `Interaction`, `Lead`, `Enquiry`.
  - **Procurement & Inventory**: `Vendor`, `ProductCategory`, `Unit`, `Product`, `PurchaseRequisition`, `RFQ`, `PurchaseOrder`, `InwardDocument`, `PurchaseInvoice`, `DebitNote`, `Cheque`.
  - **Engineering & Production**: `PanelSpec`, `PanelBOMItem`.
  - **Core Utility Models**: `Notification`, `AuditLog`.

---

## 5. Existing Authentication
- **Token Mechanism**: Standard JSON Web Tokens (Access Token 24h expiration, Refresh Token 7-day expiration).
- **Password Security**: Bcrypt hashing with salt rounds.
- **Payload & Response**: Login returns `user` object (`id`, `username`, `email`, `fullName`, `phone`, `designation`, `department`, `roles`, `permissions`) and bearer tokens.
- **Storage**: Client stores tokens securely using `AppStorage` and injects `Authorization: Bearer <token>` in Dio interceptors.

---

## 6. Existing RBAC (Role-Based Access Control)
- **Database Model**: `Role` (`name`, `code`, `isSystem`), `Permission` (`module`, `action`, `description`), join table `RolePermission` (`roleId`, `permissionId`), and `UserRole` (`userId`, `roleId`).
- **Deficiencies Identified in Existing RBAC**:
  1. **Permissions are Unseeded**: `prisma/seed.ts` seeds roles (`ROLE_ADMIN`, `ROLE_SALES_MGR`, `ROLE_PURCHASE_MGR`, etc.), but **never seeds any records in the `Permission` or `RolePermission` tables**. Consequently, non-admin users receive `permissions: []` on login.
  2. **No Backend Guard Enforcement**: Controllers only specify `@UseGuards(JwtAuthGuard)`. There is no `PermissionsGuard` or `@RequirePermission()` enforcement on controller endpoints. Any logged-in user can make HTTP requests to create, delete, or approve data across any module.
  3. **No Submodule & Action Granularity**: Permissions are only flat strings. They lack fine-grained action levels (VIEW, CREATE, EDIT, DELETE, APPROVE, ASSIGN, EXPORT, PRINT).

---

## 7. Existing Task Manager
- **Current State**: Completely missing from backend and database.
- **Frontend State**: Navigation item exists in `AppShell` (`/tasks`), but the route in `app_router.dart` points to a dead placeholder widget: `_comingSoon('Tasks — Phase 2')`.
- **Verdict**: Must be fully implemented as a core collaborative engine linking tasks to Projects, Departments, Staff Assignees, Milestones, and Workflows.

---

## 8. Existing Project Module
- **Current State**: Completely missing from backend and database.
- **Frontend State**: Navigation item exists in `AppShell` (`/projects`), but points to `_comingSoon('Projects — Phase 2')`.
- **Verdict**: Must be implemented with Project entity, auto-calculated health states, staff team allocations, costing/budget tracking, and dynamic tab-level access control.

---

## 9. Existing UI & Navigation Analysis
- **Navigation Shell (`apps/mobile/lib/core/widgets/app_shell.dart`)**:
  - Contains a hardcoded static list `_navItems` displaying 15 modules: Dashboard, CRM, Customers, Sales, Purchase, Inventory, Production, Projects, Tasks, Accounts, HR, Vendors, Products, Reports, Admin.
  - **Violation of Zero Extra UI Rule**: Every user sees all 15 items in the sidebar. Clicking on Sales, Inventory, Projects, Tasks, Accounts, HR, Reports, or Admin displays a dead construction icon placeholder.
- **Dashboard (`apps/mobile/lib/features/dashboard/presentation/pages/dashboard_page.dart`)**:
  - Hardcoded Quick Actions: 'New Customer', 'New Lead', 'New Enquiry', 'New Vendor', 'Products'.
  - Hardcoded KPIs: CRM-specific metrics only.
  - An Employee or Purchase Manager is overwhelmed with irrelevant CRM shortcuts they are not authorized to use.

---

## 10. Existing Problems
1. **No Separation between User and Staff Profile**:
   - `User` table mixes login credentials (`passwordHash`) with profile attributes (`fullName`, `phone`, `designation`).
   - A staff member cannot exist in the company directory without granting them a login account.
2. **Missing Designation Master**:
   - `designation` is stored as an unvalidated raw string inside `User`.
3. **Incomplete Department Master**:
   - Only 6 departments exist in seed data (`ADMIN`, `SALES`, `PURCHASE`, `STORE`, `ENG`, `FINANCE`).
   - Business requires 13 standardized departments including Panel Department, Quality, IT, Customer Service, R&D, Executive / Leadership, etc.
4. **Backend Security Vulnerability**:
   - No route guards verifying permissions. Frontend hiding alone is unsafe.
5. **Dead UI & Broken Links**:
   - Dead placeholder screens for 8 out of 15 navigation routes.

---

## 11. Missing Features
- Separate `Staff` profile entity with `employeeId`, `departmentId`, `designationId`, `reportingManagerId`, `status`, `joiningDate`, `location`, `mobile`, `email`, `profilePhoto`.
- Reusable `Designation` master model with CRUD and role linking.
- Full set of 13 standard company departments.
- Backend `PermissionsGuard` and `RequirePermissions` decorator.
- Dynamic `AppShell` navigation that queries `currentUser.permissions` and displays only authorized modules.
- Dynamic `Dashboard` personalizing KPIs, quick actions, and work streams according to the user's role and department.
- Dedicated "My Work" user-centric hub (My Tasks, My Projects, My Approvals, My Notifications).
- Project Management Module (Project Master, Project Types, Health calculation, Staff Team Allocation, Costing, Milestones).
- Task Management Module (Tasks, Status Workflow, Assignee, Review/Return workflow, Comments, Activity history).

---

## 12. Duplicate Features
- Duplicate naming in `User` vs what belongs in `Staff`.
- Multiple placeholder screens duplicating the `_comingSoon` widget instead of hiding unauthorized routes.

---

## 13. Dependencies
- **Task Module** depends on: `Project`, `Staff`, `Department`, `User`.
- **Project Module** depends on: `Customer`, `Staff` (Project Manager & Team), `Department`.
- **Staff Foundation** depends on: `Department`, `Designation`, `User` (optional one-to-one link).
- **Dynamic Navigation** depends on: `AuthUser.permissions`, `AuthUser.roles`.
- **Backend Authorization** depends on: `PermissionsGuard`, `PrismaService`, `Reflector`.

---

## 14. Risks & Mitigations
- **Risk 1**: Existing login might fail if `User` relations change.
  - *Mitigation*: Keep `User` intact and link `Staff` via optional `userId` (`User?` <-> `Staff?`). Backwards compatibility is preserved.
- **Risk 2**: Prisma migration breaking SQLite database.
  - *Mitigation*: Perform additive schema migrations with nullable foreign keys and seed existing users into corresponding `Staff` records.
- **Risk 3**: Slow navigation rendering if permission checks are unmemoized.
  - *Mitigation*: Compile user permission set into a `Set<String>` upon login and evaluate permissions in O(1) time.

---

## 15. Recommended Architecture
- **Authentication & RBAC**:
  - `User` (Authentication credentials) <-> `Staff` (Human record).
  - `Role` has many `Permissions` (`MODULE:ACTION`).
  - Backend Controller endpoints annotated with `@RequirePermissions('MODULE:ACTION')` enforced by global/scoped `PermissionsGuard`.
- **Dynamic Personalized UI**:
  - `AppShell` receives `AuthUser` from Riverpod and computes `List<_NavItem> authorizedNavItems`.
  - Buttons (`+ Create`, `Edit`, `Delete`, `Approve`, `Export`) wrapped in permission check helpers `canCreate(module)`, `canApprove(module)`, etc.
  - Tabs in Project details conditionally rendered based on submodule permissions.

---

## 16. Recommended User Flows
- **Admin**: Login -> Comprehensive Company Dashboard -> System Administration (Users, Staff Directory, Roles, Permissions, Departments, Designations) -> Full cross-module visibility.
- **Project Manager**: Login -> Project Manager Dashboard / My Work -> Project Portfolio (Health metrics, cost analysis) -> Task Allocation to Staff -> Milestones & Progress Reviews.
- **Employee**: Login -> "My Work" Personal Workspace -> My Assigned Tasks -> Task Status Transition (Accept -> In Progress -> Submit for Review) -> Assigned Projects -> Notifications.

---

## 17. Recommended Permission Model
- **Modules**: `DASHBOARD`, `MY_WORK`, `STAFF`, `DEPARTMENTS`, `DESIGNATIONS`, `USERS`, `ROLES`, `CUSTOMERS`, `CRM`, `SALES`, `PURCHASE`, `VENDORS`, `INVENTORY`, `PRODUCTION`, `PROJECTS`, `TASKS`, `REPORTS`, `AUDIT`.
- **Actions**: `VIEW`, `CREATE`, `EDIT`, `DELETE`, `APPROVE`, `ASSIGN`, `REVIEW`, `EXPORT`, `PRINT`.

---

## 18. Database Changes
1. Create `Staff` model:
   - `id`, `employeeId`, `fullName`, `email`, `mobile`, `profilePhoto`, `departmentId`, `designationId`, `reportingManagerId`, `userId` (unique, nullable), `status` (ACTIVE, INACTIVE, SUSPENDED), `joiningDate`, `location`, `notes`, timestamps.
2. Create `Designation` model:
   - `id`, `name`, `code`, `description`, timestamps.
3. Update `Department` model:
   - Ensure 13 departments are present.
4. Create `Project` model:
   - `id`, `projectNumber`, `name`, `description`, `customerId`, `projectType`, `projectManagerStaffId`, `startDate`, `endDate`, `priority`, `budget`, `status`, `health`, timestamps.
5. Create `ProjectMember` model:
   - `id`, `projectId`, `staffId`, `projectRole`, `allocationPercent`, `startDate`, `endDate`, timestamps.
6. Create `Milestone` model:
   - `id`, `projectId`, `title`, `description`, `dueDate`, `status`, timestamps.
7. Create `Task` model:
   - `id`, `taskNumber`, `title`, `description`, `projectId` (nullable), `milestoneId` (nullable), `departmentId` (nullable), `assigneeStaffId` (nullable), `createdByStaffId`, `assignedByStaffId` (nullable), `priority`, `status`, `dueDate`, `estimatedHours`, `actualHours`, `progress`, timestamps.
8. Create `TaskComment` model:
   - `id`, `taskId`, `staffId`, `comment`, timestamps.
9. Create `TaskActivity` model:
   - `id`, `taskId`, `staffId`, `action`, `oldValue`, `newValue`, timestamps.

---

## 19. API Changes
- New Endpoints in `StaffController`:
  - `GET /api/v1/staff` (Filter by department, status, search)
  - `GET /api/v1/staff/:id`
  - `POST /api/v1/staff`
  - `PUT /api/v1/staff/:id`
  - `PATCH /api/v1/staff/:id/status`
- New Endpoints in `DesignationsController`:
  - `GET /api/v1/admin/designations`
  - `POST /api/v1/admin/designations`
  - `PUT /api/v1/admin/designations/:id`
  - `DELETE /api/v1/admin/designations/:id`
- New Endpoints in `ProjectsController`:
  - `GET /api/v1/projects` (List with filters, health metrics)
  - `GET /api/v1/projects/:id` (Full detail: milestones, team, costing, tasks)
  - `POST /api/v1/projects`
  - `PUT /api/v1/projects/:id`
  - `DELETE /api/v1/projects/:id`
  - `POST /api/v1/projects/:id/members`
  - `DELETE /api/v1/projects/:id/members/:memberId`
  - `POST /api/v1/projects/:id/milestones`
- New Endpoints in `TasksController`:
  - `GET /api/v1/tasks` (Filter by project, department, assignee, status, priority)
  - `GET /api/v1/tasks/my-tasks` (Current user's assigned tasks)
  - `GET /api/v1/tasks/:id`
  - `POST /api/v1/tasks`
  - `PUT /api/v1/tasks/:id`
  - `PATCH /api/v1/tasks/:id/status` (Workflow transition with audit)
  - `POST /api/v1/tasks/:id/comments`
- New Endpoints in `MyWorkController`:
  - `GET /api/v1/my-work/summary` (Aggregated tasks, projects, meetings, notifications)

---

## 20. UI Changes
1. **Dynamic Navigation (`AppShell`)**:
   - Filter sidebar navigation items strictly based on `user.canView(module)`.
   - Remove all dead `_comingSoon` items. If a user cannot access or a feature is not built, do not display it.
2. **Staff Directory Screen (`StaffListPage`, `StaffDetailPage`, `StaffFormDialog`)**:
   - Enterprise data table with department filters, status tags, reporting hierarchy, and user account link.
3. **Task Manager Screens (`TasksListPage`, `TaskDetailPage`, `TaskFormDialog`)**:
   - Kanban board and list view.
   - Action buttons (Accept, Start, Submit Review, Complete, Return) visible only to allowed roles/assignees.
4. **Project Module Screens (`ProjectsListPage`, `ProjectDetailPage`, `ProjectFormDialog`)**:
   - Project cards with health badges (ON TRACK / AT RISK / CRITICAL), budget progress bar, milestone indicators.
   - Detail view with permission-governed tabs (Overview, Tasks, Milestones, Team, Budget & Costing).
5. **Personalized My Work Screen (`MyWorkPage`)**:
   - Default home view for Employees and Managers showing their immediate action items without administrative noise.
