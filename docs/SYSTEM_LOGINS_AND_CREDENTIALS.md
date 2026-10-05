# Saark Exploration ERP — System Logins & Credentials Directory

**System:** Saark Exploration Private Limited ERP & CRM Platform  
**Environment:** Development / Staging / Internal Testing  
**Default Password for all Seed Accounts:** `Saark@2026`  
**Authentication Type:** Username OR Email Address + Password  

---

## 1. Quick Reference: All Default Logins

You can sign in using **either** the **Username** or the **Email Address** along with the default password.

| # | Full Name | Employee ID | Username | Email Address | Password | Assigned Role | Department |
|---|---|---|---|---|---|---|---|
| 1 | **Vikram Sharma** | `EMP001` | `admin` | `admin@saark.in` | `Saark@2026` | `ROLE_ADMIN` (Super Admin) | Executive / Leadership |
| 2 | **Rahul Patil** | `EMP002` | `rahul.pm` | `pm@saark.in` | `Saark@2026` | `ROLE_PROJECT_MGR` (Project Mgr) | Projects |
| 3 | **Amit Joshi** | `EMP003` | `amit.sales` | `sales@saark.in` | `Saark@2026` | `ROLE_SALES_EXEC` (Sales Exec) | Sales & Marketing |
| 4 | **Sneha More** | `EMP004` | `sneha.eng` | `sneha@saark.in` | `Saark@2026` | `ROLE_EMPLOYEE` (Employee) | R&D / Engineering |
| 5 | **Pooja Patil** | `EMP005` | `purchasemgr` | `purchase@saark.in` | `Saark@2026` | `ROLE_PURCHASE_MGR` (Purchase Mgr) | Purchase / Procurement |
| 6 | **Rohit Shinde** | `EMP006` | `rohit.prod` | `rohit@saark.in` | `Saark@2026` | `ROLE_PRODUCTION_MGR` (Prod Mgr) | Production |
| 7 | **Neha Pawar** | `EMP007` | `neha.qc` | `neha@saark.in` | `Saark@2026` | `ROLE_QC_ENG` (QC Engineer) | Quality |
| 8 | **Rahul Verma** | *Legacy* | `salesmgr` | `sales.mgr@saark.in` | `Saark@2026` | `ROLE_SALES_MGR` (Sales Manager) | Sales & Marketing |
| 9 | **Rajesh Kulkarni** | *Legacy* | `engineer` | `engineer@saark.in` | `Saark@2026` | `ROLE_PRODUCTION_MGR` (Panel Eng) | Engineering / Production |

---

## 2. Detailed Account Profiles & Access Levels

### 2.1 Super Administrator (Full System Control)
- **Name:** Vikram Sharma
- **Employee ID:** `EMP001`
- **Username:** `admin`
- **Email:** `admin@saark.in`
- **Password:** `Saark@2026`
- **Designation:** Managing Director (MD)
- **Department:** Executive / Leadership
- **Location:** Mumbai Head Office
- **Phone:** `+91 98200 00001`
- **Access & Permissions:**
  - Complete, unrestricted access across all 18 modules.
  - Can manage User Accounts, Staff Directory, Roles & Permissions, Company Master.
  - Full CRUD on CRM, Sales, Purchase Orders, Vendors, Inventory, Production, and Financials.
  - System Audit Logs and Executive Analytics.

---

### 2.2 Project Manager
- **Name:** Rahul Patil
- **Employee ID:** `EMP002`
- **Username:** `rahul.pm`
- **Email:** `pm@saark.in`
- **Password:** `Saark@2026`
- **Designation:** Project Manager
- **Department:** Projects
- **Location:** Pune Works
- **Phone:** `+91 98200 00002`
- **Access & Permissions:**
  - Full Project Portfolio management (Create, Edit, Milestones, Auto Health calculation).
  - Task lifecycle control: Assign tasks to team members, Review and Approve/Return tasks.
  - Project Team allocation and Project Budget & Costing view/plan.
  - Customer directory view & Project analytics export.

---

### 2.3 Sales Executive
- **Name:** Amit Joshi
- **Employee ID:** `EMP003`
- **Username:** `amit.sales`
- **Email:** `sales@saark.in`
- **Password:** `Saark@2026`
- **Designation:** Sales Executive
- **Department:** Sales & Marketing
- **Location:** Mumbai Head Office
- **Phone:** `+91 98200 00003`
- **Access & Permissions:**
  - Full CRM pipeline: Leads, Enquiries, BANT Qualification, Atomic Lead-to-Customer conversion.
  - Customer Master: Create and manage clients, customer contacts, interaction logs.
  - Quotation and Proforma Invoice generation.
  - Personal task tracking and assigned project view.

---

### 2.4 Purchase & Procurement Manager
- **Name:** Pooja Patil
- **Employee ID:** `EMP005`
- **Username:** `purchasemgr`
- **Email:** `purchase@saark.in`
- **Password:** `Saark@2026`
- **Designation:** Purchase Executive
- **Department:** Purchase / Procurement
- **Location:** Mumbai Head Office
- **Phone:** `+91 98200 00005`
- **Access & Permissions:**
  - Vendor Master management: Tier classification, payment terms, GSTIN/bank details.
  - Purchase workflow: Requisitions, RFQs, Purchase Orders (Creation, Approval, Printing).
  - Material Inward (MRN), QC inspection linkage, Vendor invoice verification.
  - Store and Stock Ledger overview.

---

### 2.5 Production & Panel Design Engineer
- **Name:** Rohit Shinde
- **Employee ID:** `EMP006`
- **Username:** `rohit.prod`
- **Email:** `rohit@saark.in`
- **Password:** `Saark@2026`
- **Designation:** Production Engineer
- **Department:** Production
- **Location:** MIDC Plant
- **Phone:** `+91 98200 00006`
- **Access & Permissions:**
  - Panel Manufacturing: Technical specifications, Ingress Protection (IP), Enclosure sizing.
  - Panel Bill of Materials (BOM): Electrical component configuration, Switchgear mapping.
  - Shop floor material issues and assembly work orders.

---

### 2.6 Quality Assurance & QC Engineer
- **Name:** Neha Pawar
- **Employee ID:** `EMP007`
- **Username:** `neha.qc`
- **Email:** `neha@saark.in`
- **Password:** `Saark@2026`
- **Designation:** QC Engineer
- **Department:** Quality
- **Location:** MIDC Plant
- **Phone:** `+91 98200 00007`
- **Access & Permissions:**
  - Quality inspection of manufactured electrical panels and incoming vendor materials.
  - Panel QC signoff and FAT (Factory Acceptance Test) certificate approvals.
  - Quality defect reporting and rework tracking.

---

### 2.7 Standard Employee (Personal Workspace Only)
- **Name:** Sneha More
- **Employee ID:** `EMP004`
- **Username:** `sneha.eng`
- **Email:** `sneha@saark.in`
- **Password:** `Saark@2026`
- **Designation:** Lead Engineer
- **Department:** R&D / Engineering
- **Location:** R&D Center, Pune
- **Phone:** `+91 98200 00004`
- **Access & Permissions (Zero Extra UI):**
  - **Visible:** My Work personal dashboard, Assigned Tasks (view and update progress), Assigned Projects view, Staff Directory (read-only).
  - **Hidden / Prohibited:** Admin, Financials, Purchase, PO approvals, CRM leads, and deletion actions.

---

### 2.8 Legacy & Compatibility Accounts
- **Sales Head:**
  - **Username:** `salesmgr`
  - **Email:** `sales.mgr@saark.in`
  - **Password:** `Saark@2026`
  - **Role:** `ROLE_SALES_MGR`
- **Panel Design Engineer:**
  - **Username:** `engineer`
  - **Email:** `engineer@saark.in`
  - **Password:** `Saark@2026`
  - **Role:** `ROLE_PRODUCTION_MGR`

---

## 3. Server Endpoints & Access URLs

### 3.1 Local Environment
- **Backend API Base URL:** `http://localhost:3000` (or `http://127.0.0.1:3000`)
- **API Prefix:** `http://localhost:3000/api/v1`
- **Interactive Swagger Docs:** `http://localhost:3000/api`
- **Database Engine:** SQLite (stored at `storage/saark_erp.db`)

### 3.2 Mobile & Remote Gateway (Cloudflare Tunnel)
- **Tunnel URL:** Check [phone_url.txt](file:///d:/saark/New%20folder%20%282%29/phone_url.txt) for the active tunnel domain.
- **Example Remote API:** `https://<tunnel-subdomain>.trycloudflare.com/api/v1`

---

## 4. How to Authenticate via API

### Login Request
- **Endpoint:** `POST /api/v1/auth/login`
- **Headers:** `Content-Type: application/json`
- **Payload Example (using Username):**
  ```json
  {
    "emailOrUsername": "admin",
    "password": "Saark@2026"
  }
  ```
- **Payload Example (using Email):**
  ```json
  {
    "emailOrUsername": "admin@saark.in",
    "password": "Saark@2026"
  }
  ```

### Response Example
```json
{
  "user": {
    "id": "usr-...",
    "username": "admin",
    "email": "admin@saark.in",
    "fullName": "Vikram Sharma",
    "designation": "Managing Director",
    "department": "Executive / Leadership",
    "employeeId": "EMP001",
    "roles": ["ROLE_ADMIN"],
    "permissions": ["*"]
  },
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1Ni...",
    "refreshToken": "eyJhbGciOiJIUzI1Ni...",
    "expiresIn": "24h"
  }
}
```

---

## 5. Database Re-seeding & Password Reset

If passwords have been altered or test data needs to be restored to clean defaults:

1. Open PowerShell / Command Prompt in `apps/backend`:
   ```bash
   cd apps/backend
   ```
2. Run the database seed script:
   ```bash
   npm run seed
   ```
   *(or run `npx ts-node prisma/seed.ts`)*
3. Verify all accounts and password hashes:
   ```bash
   npx ts-node scripts/verify_system.ts
   ```

> [!IMPORTANT]
> **Production Notice:** All credentials documented above are meant strictly for local development, staging, and automated testing. In production environments, replace default passwords immediately via the Admin Security settings and configure secure environment secrets.
