# SAARK ERP — Master Implementation Plan
**System**: Saark Exploration Private Limited ERP  
**Scope**: Staff Foundation, RBAC, Task Management, Project Management, and Zero Extra UI  
**Execution Methodology**: Phased, Non-Destructive, Backward-Compatible  
**Date**: October 2026

---

## Overview & Quality Directives

1. **Do Not Rebuild Working Features**: Protect existing CRM, Customers, Vendors, Products, and Purchase modules.
2. **Zero Extra UI Guarantee**: Every module, tab, quick action, and button is strictly permission-checked. Unauthorized UI does not exist in the DOM or widget tree.
3. **Defense in Depth**: Every backend endpoint enforces `JwtAuthGuard` + `PermissionsGuard`.
4. **User vs Staff Separation**: Authentication credentials (`User`) and organizational human profile (`Staff`) are decoupled.

---

## Phase 0: Architecture, Database Foundation & RBAC Hardening

### 0.1 Prisma Schema Enhancements (`apps/backend/prisma/schema.prisma`)
1. **Department Master**: Ensure all 13 standard company departments exist.
2. **Designation Master**: Create `Designation` model (`id`, `name`, `code`, `description`, timestamps).
3. **Staff Entity**:
   - Model `Staff`:
     - `id`: UUID
     - `employeeId`: Unique string (e.g. `EMP001`)
     - `fullName`, `email`, `mobile`: Strings
     - `profilePhoto`: String?
     - `departmentId`: FK -> `Department`
     - `designationId`: FK -> `Designation`
     - `reportingManagerId`: FK -> `Staff`?
     - `userId`: FK -> `User`? (Unique, 1-to-1 optional)
     - `status`: String (`ACTIVE`, `INACTIVE`, `SUSPENDED`)
     - `joiningDate`: DateTime?
     - `location`: String?
     - `notes`: String?
     - Timestamps
4. **Project Entity**:
   - Model `Project`:
     - `id`: UUID
     - `projectNumber`: Unique string (e.g. `PRJ-2026-001`)
     - `name`, `description`: String
     - `customerId`: FK -> `Customer`?
     - `projectType`: String (`Customer Project`, `Panel Manufacturing`, `Engineering / R&D`, `Installation`, `Service`, `IT / Software`, `Internal`, `AMC`, `Other`)
     - `projectManagerStaffId`: FK -> `Staff`
     - `startDate`, `endDate`: DateTime?
     - `priority`: String (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`)
     - `budget`: Float (default 0)
     - `status`: String (`PLANNING`, `ACTIVE`, `ON_HOLD`, `COMPLETED`, `CANCELLED`)
     - `health`: String (`ON_TRACK`, `AT_RISK`, `CRITICAL`)
5. **Project Team & Milestones**:
   - Model `ProjectMember`: `projectId`, `staffId`, `projectRole`, `allocationPercent`, `startDate`, `endDate`.
   - Model `Milestone`: `projectId`, `title`, `description`, `dueDate`, `status`.
6. **Task Manager Entities**:
   - Model `Task`:
     - `id`: UUID
     - `taskNumber`: Unique string (e.g. `TSK-001`)
     - `title`, `description`: String
     - `projectId`: FK -> `Project`?
     - `milestoneId`: FK -> `Milestone`?
     - `departmentId`: FK -> `Department`?
     - `assigneeStaffId`: FK -> `Staff`?
     - `createdByStaffId`: FK -> `Staff`
     - `assignedByStaffId`: FK -> `Staff`?
     - `priority`: String (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`)
     - `status`: String (`CREATED`, `ASSIGNED`, `ACCEPTED`, `IN_PROGRESS`, `REVIEW`, `RETURNED`, `COMPLETED`, `CANCELLED`)
     - `dueDate`: DateTime?
     - `estimatedHours`, `actualHours`: Float
     - `progress`: Int (0-100)
   - Model `TaskComment`: `taskId`, `staffId`, `comment`, timestamps.
   - Model `TaskActivity`: `taskId`, `staffId`, `action`, `oldValue`, `newValue`, timestamps.

### 0.2 Backend Permissions & Guards
1. Implement `PermissionsGuard` in `apps/backend/src/common/guards/permissions.guard.ts`.
2. Extract user permissions from JWT / DB cache and evaluate required permission(s).
3. Throw `403 Forbidden` if user does not possess required permission.
4. Comprehensive Permission Seeding in `apps/backend/prisma/seed.ts` covering all modules and action verbs.

---

## Phase 1: Staff, Organization & Admin UI

### 1.1 Backend Admin & Staff Endpoints
- Implement `StaffModule` (`staff.controller.ts`, `staff.service.ts`).
- Add Designation CRUD to `AdminModule`.
- Seed 13 core departments, standard designations, and dev test staff profiles (EMP001 to EMP007).

### 1.2 Frontend Dynamic Navigation & Staff UI
- Update `AppShell` in Flutter:
  - Dynamically construct navigation list by evaluating `user.canView(module)`.
  - Remove all dead placeholder items (`_comingSoon`).
- Create `StaffDirectoryPage` in `features/staff/presentation/pages/`:
  - Search, filter by department and status.
  - View employee card with designation, department, contact info, and reporting hierarchy.
  - Form dialog for creating/editing staff and linking/unlinking user accounts.

---

## Phase 2: Task Management Module

### 2.1 Backend Task Service & Endpoints
- Implement `TasksModule` (`tasks.controller.ts`, `tasks.service.ts`).
- Endpoints:
  - `GET /api/v1/tasks` (with filters: `projectId`, `assigneeStaffId`, `status`, `priority`).
  - `GET /api/v1/tasks/my-tasks` (personalized assigned tasks for logged-in staff).
  - `POST /api/v1/tasks` (create task, log audit activity, send notification).
  - `PATCH /api/v1/tasks/:id/status` (lifecycle state transitions with role/assignee validation).
  - `POST /api/v1/tasks/:id/comments` (collaborative updates).

### 2.2 Frontend Task Manager UI
- Create `TasksListPage` and `TaskDetailPage` under `features/tasks/`:
  - Status tabs: All, My Tasks, In Progress, Under Review, Completed.
  - Kanban board and List views.
  - Action buttons based on permissions and assignment:
    - Assignee: `Accept`, `Start`, `Submit for Review`.
    - Manager: `Approve / Complete`, `Return for Changes`, `Reassign`.
    - Unauthorized users cannot see edit/delete/approve buttons.

---

## Phase 3: Project Management Module

### 3.1 Backend Project Service & Endpoints
- Implement `ProjectsModule` (`projects.controller.ts`, `projects.service.ts`).
- Endpoints:
  - `GET /api/v1/projects` (with summary stats and calculated health).
  - `GET /api/v1/projects/:id` (full detail including milestones, members, budget utilization).
  - `POST /api/v1/projects`
  - `PUT /api/v1/projects/:id`
  - `POST /api/v1/projects/:id/members`
  - `POST /api/v1/projects/:id/milestones`

### 3.2 Automated Health Calculation
- Implement algorithm in `ProjectsService.calculateHealth(projectId)` evaluating overdue tasks, budget burn rate, and delayed milestones.

### 3.3 Frontend Project UI
- Create `ProjectsListPage` and `ProjectDetailPage` under `features/projects/`:
  - Project Cards with Health indicator chip (Green / Yellow / Red), Progress bar, and Project Manager badge.
  - Tabbed Project Workspace:
    - Overview Tab
    - Tasks Tab (filtered to project tasks)
    - Milestones Tab
    - Team Tab (Staff members with role & allocation %)
    - Costing & Budget Tab (Budget, Purchase Cost, Labor Cost, Remaining)
    - Documents Tab
  - Strict tab-level permission gating.

---

## Phase 4: "My Work" Personalized Workspace

### 4.1 "My Work" Hub
- Create `MyWorkPage` (`features/my_work/presentation/pages/my_work_page.dart`):
  - Employee's home screen upon login.
  - Immediate view of:
    - Assigned Active Tasks (with 1-click status updates)
    - Assigned Projects
    - Pending Approvals (for Managers)
    - Recent Notifications
  - Clean, distraction-free interface matching the "Show Only What I Need" principle.

---

## Phase 5: Verification, Security Testing & Multi-Platform Validation

### 5.1 Verification Checklist
1. **Admin Login Test (`admin@saark.in`)**:
   - Sees all modules, full admin controls, staff directory, projects, tasks.
2. **Project Manager Login Test (`sales.mgr@saark.in` or `pm@saark.in`)**:
   - Sees My Work, Projects, Tasks, Team, Approvals, Staff Directory.
   - Admin master settings, User accounts, and Roles are hidden.
3. **Employee Login Test (`engineer@saark.in`)**:
   - Sees ONLY My Work, My Tasks, Assigned Projects, Staff Directory, Notifications.
   - Purchase, CRM, Accounts, Admin, Delete buttons, and Approval actions are completely invisible.
4. **Direct API Penetration Test**:
   - Call `POST /api/v1/admin/users` with Employee JWT token -> Must receive `403 Forbidden`.
   - Call `POST /api/v1/purchase/orders` with Employee JWT token -> Must receive `403 Forbidden`.
5. **Multi-Platform Build**:
   - Test responsive layout on Desktop, Tablet, and Mobile viewport.
   - Run compilation and ensure zero analyzer errors.
