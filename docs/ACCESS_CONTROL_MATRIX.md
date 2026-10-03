# SAARK ERP — Role-Based Access Control (RBAC) Matrix
**System**: Saark Exploration Private Limited ERP  
**Scope**: Module, Submodule, and Action-Level Authorization Matrix  
**Principle**: Zero Extra UI + Strict Backend Guard Enforcement  
**Date**: October 2026

---

## 1. Core Principles of the Access Control Matrix

1. **Role-Aware, Permission-Driven**: Roles are collections of granular permissions. System behavior is never hardcoded to role string checks alone, but evaluates explicit `MODULE:ACTION` permissions.
2. **Zero Extra UI Rule**:
   - If a user lacks `MODULE:VIEW`, the module **must not appear** in the Sidebar, Topbar, Search, Quick Actions, or Routing.
   - If a user has `MODULE:VIEW` but lacks `MODULE:CREATE`, no `+ Add`, `+ New`, or `+ Create` button is rendered.
   - If a user lacks `MODULE:APPROVE`, no approval action or button is rendered.
   - If a user lacks `MODULE:DELETE`, no delete button or trash icon is rendered.
   - If a user lacks `MODULE:EXPORT`, no export CSV/Excel/PDF button is rendered.
3. **Defense in Depth (Mandatory Backend Enforcement)**:
   - Every API endpoint is guarded by `JwtAuthGuard` and `PermissionsGuard`.
   - Direct HTTP requests to unauthorized endpoints return `403 Forbidden` regardless of UI state.

---

## 2. Granular Permissions Master List

| Module Key | Submodule / Resource | Available Actions | Description |
|------------|----------------------|-------------------|-------------|
| `MY_WORK` | Personal Workspace | `VIEW` | Access personal tasks, projects, meetings, notifications |
| `STAFF` | Staff Directory | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `EXPORT` | Manage employee profiles, departments, designations |
| `ORGANIZATION` | Departments & Designations | `VIEW`, `CREATE`, `EDIT`, `DELETE` | Master setup of organizational structure |
| `USERS` | User Accounts | `VIEW`, `CREATE`, `EDIT`, `DELETE` | Login credentials, lock/unlock accounts |
| `ROLES` | Roles & Permissions | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `ASSIGN` | RBAC management |
| `TASKS` | Task Management | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `ASSIGN`, `REVIEW`, `COMPLETE`, `EXPORT` | Full task lifecycle across projects and teams |
| `PROJECTS` | Project Management | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `APPROVE`, `EXPORT` | Project portfolio, health, costing, milestones |
| `PROJECT_BUDGET` | Project Financials / Costing | `VIEW`, `EDIT` | Project budget, labor, material, expense analysis |
| `PROJECT_TEAM` | Project Team Allocation | `VIEW`, `ASSIGN` | Allocate staff to project roles and percentage |
| `CUSTOMERS` | Customer Master | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `EXPORT` | Customer profiles, contacts, history |
| `CRM` | Leads & Enquiries | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `EXPORT` | Sales pipeline, interaction logging |
| `SALES` | Quotations & Sales Orders | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `APPROVE`, `EXPORT`, `PRINT` | Quotations, proforma invoices, sales orders |
| `PURCHASE` | Procurement & Vendors | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `APPROVE`, `EXPORT`, `PRINT` | Requisitions, RFQs, POs, Inward, Invoices |
| `VENDORS` | Vendor Directory | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `EXPORT` | Vendor profiles, payment terms, bank records |
| `INVENTORY` | Store & Stock Ledger | `VIEW`, `CREATE`, `EDIT`, `ADJUST`, `EXPORT` | Stock ledger, goods issue, min-max alerts |
| `PRODUCTION` | Panel Manufacturing & BOM | `VIEW`, `CREATE`, `EDIT`, `DELETE`, `APPROVE`, `EXPORT` | Panel technical specs, BOM items, QA |
| `REPORTS` | Executive & Departmental Reports | `VIEW`, `EXPORT` | Cross-module analytics and BI |
| `AUDIT` | System Audit Logs | `VIEW`, `EXPORT` | Immutable tracking of user operations |

---

## 3. Comprehensive Role-Permission Mapping Matrix

### Legend:
- **Full**: Full CRUD + Approval + Export (`VIEW`, `CREATE`, `EDIT`, `DELETE`, `APPROVE`, `EXPORT`)
- **Manage**: `VIEW`, `CREATE`, `EDIT`, `ASSIGN`, `REVIEW`, `EXPORT`
- **Assigned / Own**: `VIEW`, `EDIT` (own/assigned records only)
- **View Only**: `VIEW` only
- **None**: No access; UI element completely hidden; API returns `403`

| Module / Submodule | Admin | Project Manager | Purchase Manager | Sales Executive | Production / QC Engineer | Accountant | Employee |
|--------------------|:-----:|:---------------:|:----------------:|:---------------:|:-----------------------:|:----------:|:--------:|
| **My Work** | Full | Full (Team+Own) | Full (Dept+Own) | Full (Own) | Full (Own) | Full (Own) | Own Work Only |
| **Tasks** | Full | Manage + Assign + Review | Manage Dept Tasks | Own Assigned Tasks | Own Assigned Tasks | Own Assigned Tasks | Own Assigned (View/Update/Submit) |
| **Projects — Overview & Milestones** | Full | Full Manage | View (Procurement link) | View (Customer link) | View (Assigned panels) | View (Billing link) | View Assigned Projects Only |
| **Projects — Team Allocation** | Full | Assign & Manage | None | None | None | None | None |
| **Projects — Costing & Budget** | Full | View & Plan | View (Material cost) | None | None | View & Audit | None |
| **Staff Directory** | Full | View All | View All | View All | View All | View All | View Directory Only |
| **Departments & Designations**| Full | None | None | None | None | None | None |
| **User & Role Administration** | Full | None | None | None | None | None | None |
| **Customers Master** | Full | View Only | View Only | Create & Manage | View Only | View Only | None |
| **CRM (Leads & Enquiries)** | Full | None | None | Full Manage | None | None | None |
| **Sales (Quotations & Orders)**| Full | View Linked | None | Create & View | None | View & Invoice | None |
| **Purchase & POs** | Full | View Linked Reqs | Full Manage + Approve | None | View Linked Reqs | View & Verify | None |
| **Vendors Directory** | Full | View Only | Full Manage | None | View Only | View Only | None |
| **Inventory & Stores** | Full | View Materials | Full Manage | None | View & Issue | View | None |
| **Panel Manufacturing & QC** | Full | View Specs | None | View Specs | Full Manage + QC | None | None |
| **Audit Logs** | Full | None | None | None | None | None | None |
| **Company Settings** | Full | None | None | None | None | None | None |

---

## 4. UI Visibility Rules by Role

### A. Employee Experience (Minimal & Focused)
- **Sidebar**:
  - `My Work`
  - `Tasks` (only tasks where `assigneeStaffId == currentStaff.id`)
  - `Projects` (only projects where current staff is in `project_members`)
  - `Staff Directory` (read-only contact lookup)
  - `Notifications`
- **Hidden from Employee UI**:
  - Admin, Users, Roles, Permissions
  - Purchase, Vendors, Inward, POs
  - Accounts, Financials, Project Costing
  - CRM, Leads, Enquiries, Sales
  - Delete buttons, Project Creation buttons, Approval buttons

### B. Project Manager Experience
- **Sidebar**:
  - `My Work`
  - `Projects` (Full project portfolio, Create Project, Health Dashboard)
  - `Tasks` (Project Task Board, Assign to Staff, Milestone assignment, Review/Return)
  - `Customers` (Read-only)
  - `Staff Directory` (To review team capacity and allocate members)
  - `Reports` (Project progress & task burndown)
- **Hidden from PM UI**:
  - System Admin, Roles, Security, System Audit
  - Raw accounts ledger, general purchase approval (outside their project scope)

### C. Purchase Manager Experience
- **Sidebar**:
  - `My Work`
  - `Purchase` (Requisitions, RFQs, POs, Inward inspection, Invoices)
  - `Vendors` (Vendor directory, Bank details, Ratings)
  - `Products & Items` (Item catalog, units, categories)
  - `Inventory`
  - `Staff Directory`
- **Hidden from Purchase Manager UI**:
  - CRM, Sales, System Admin, Roles, Permissions

### D. Administrator Experience
- **Sidebar**:
  - Complete access to all modules, administrative masters, user provisioning, staff management, audit trails, and global configuration.

---

## 5. Tab-Level Visibility Inside Project Details

When viewing a specific project (`/projects/:id`), tabs are rendered conditionally:

| Tab Name | Required Permission | Allowed Roles |
|----------|---------------------|---------------|
| `Overview` | `PROJECTS:VIEW` | Admin, Project Manager, Assigned Members |
| `Tasks` | `TASKS:VIEW` | Admin, Project Manager, Assigned Members |
| `Milestones` | `PROJECTS:VIEW` | Admin, Project Manager, Assigned Members |
| `Team` | `PROJECT_TEAM:VIEW` | Admin, Project Manager |
| `Costing & Budget` | `PROJECT_BUDGET:VIEW` | Admin, Project Manager, Accountant |
| `Purchase Requisitions` | `PURCHASE:VIEW` | Admin, Project Manager, Purchase Manager |
| `Production & Panels` | `PRODUCTION:VIEW` | Admin, Project Manager, Production Engineer |
| `Documents` | `PROJECTS:VIEW` | Admin, Project Manager, Assigned Members |
| `Activity History` | `PROJECTS:VIEW` | Admin, Project Manager |
