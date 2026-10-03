# 01. Project Requirements & Vision Document

## 1. Executive Summary & Product Vision
**Saark Exploration Private Limited** requires an integrated, enterprise-grade ERP system designed to centralize and automate core industrial operations. The platform connects CRM, Sales, Procurement, Warehouse/Inventory Management, Production Planning, Panel Manufacturing, Project Management, Quality Control, Accounts & Finance, HR, Assets, and EHS into a unified master-data-driven application.

### Key Objectives:
- **Single Source of Truth**: Unified master data for Customers, Vendors, Products, Employees, and Financial Entities.
- **End-to-End Traceability**: Workflow continuity from initial Customer Enquiry -> Quotation -> Sales Order -> Panel BOM / Production Plan -> Goods Issue -> Delivery -> Invoicing -> Payment Collection -> Accounting Entry.
- **Provider Abstraction**: Decoupled database (SQLite to PostgreSQL migration) and file storage (Local File System to AWS S3 migration) without breaking business logic.
- **Multi-Platform UI**: High-performance Flutter application supporting Desktop/Web, Tablet, and Mobile devices with responsive Material 3 UI.

---

## 2. Core Functional Requirements Matrix

| Module ID | Module Name | Primary Capabilities | Target User Personas |
|---|---|---|---|
| **MOD-01** | Administration | Company, Branch, Department, Financial Year, Numbering Series, RBAC, User management | System Admin, Super User |
| **MOD-02** | Customer Master | Identity, Tax details, Multiple Contacts, Valuation Rating, Product Interest, Location | Sales Exec, Sales Mgr, Admin |
| **MOD-03** | CRM | Lead Tracking, Enquiry Management, Interaction Logs (Calls, Visits, Photos, Audio), Timeline | Sales Exec, Sales Mgr |
| **MOD-04** | Vendor Master | Vendor Profile, Products Supplied, Credit Terms, Performance Rating, Tax Docs | Purchase Exec, Purchase Mgr |
| **MOD-05** | Product Master | Item Catalog, SKUs, Categories, Units of Measure, GST Rates, Reorder Levels, Pricing | Store Mgr, Purchase Mgr, Admin |
| **MOD-06** | Panel Manufacturing | Panel Specification Design (VFD, Booster, STP, HVAC), Panel BOM Calculator, Price Estimator | Engineering, Production Mgr |
| **MOD-07** | Sales & Procurement | Quotations, Sales Orders, RFQs, Purchase Orders, Goods Receipt Notes (GRN), Invoices | Sales Mgr, Purchase Mgr, Accountant |
| **MOD-08** | Warehouse & Inventory | Multi-Warehouse Stock Ledger, Issue/Transfer, Low Stock Alerts, Stock Adjustments | Store Mgr, Inventory Controller |
| **MOD-09** | Accounts & Finance | Chart of Accounts, Journal Entries, Receivables/Payable tracking, Cash Flow summaries | Accountant, Finance Head |
| **MOD-10** | Document Storage | Central Document Repository, File Uploads, Entity Tags, Access Control | All Staff |
| **MOD-11** | Audit & Security | Operations Audit Trail, JWT Refresh Tokens, Fine-Grained PBAC Enforcer | Admin, Auditor |
| **MOD-12** | Human Resources & Workforce | Employee Directory, Skill Matrix, Shifts, Form 25 Muster Roll, Bay Rostering, Overtime (Sec 59), EHS Safety, Payroll | HR Mgr, Production Mgr, All Staff |

---

## 3. Non-Functional Requirements
- **Performance**: Sub-100ms API response time for master data queries; p95 under 300ms for complex report queries.
- **Offline Readiness**: Flutter client SQLite storage (Drift) with Sync Queue for offline field data collection (Interactions, Tasks).
- **Security**: Argon2/Bcrypt password hashing, JWT Access & Refresh Token rotation, HTTPS/TLS 1.3, strict SQL injection prevention via Prisma ORM.
- **Brand Aesthetic**: Industrial modern theme with Dark Mode (#0F1115 / #181B21) and Light Mode (#F7F8FA) accenting with Saark Orange (#F97316).
