# CRM Gap Analysis & Architecture Strategy — SAARK ERP

**System**: Saark Exploration Private Limited ERP  
**Document**: `docs/CRM_GAP_ANALYSIS.md`  
**Architect**: Senior Full-Stack ERP & CRM Architect  
**Date**: October 2026  

---

## 1. Executive Summary & Purpose

This document performs a comprehensive comparative analysis between the **Existing System Capability** and the **Target Production-Ready CRM & Sales Module Requirement**.

The objective is to identify exactly what to **REUSE**, **MODIFY**, **ADD**, **MIGRATE**, **REFACTOR**, or **REMOVE** without duplicating database entities, breaking existing workflows, or destroying historical data.

---

## 2. Comparative Matrix: Existing vs. Required System

| System Area | Existing Capability | Required Target Capability | Gap Status | Action Strategy |
|---|---|---|---|---|
| **Customer Master** | Basic customer directory, GST, address, contacts list, valuation score. | Customer 360 Hub with multi-contact decision maker tags, detailed company size/turnover, rating, credit limit, and timeline. | Partial Match | **MODIFY & EXTEND**: Retain `customers` table; add `customerType`, `tags`, and advanced multi-filter search. |
| **Duplicate Prevention** | `checkDuplicate` endpoint checking GST, email, and phone. | Full duplicate warning UI + interactive Merge workflow (Merge contacts, enquiries, tasks, timeline). | Match | **REUSE & ENHANCE**: Reuse `checkDuplicate` and `mergeCustomers` backend service. |
| **Contacts Management** | `CustomerContact` model with name, designation, phone, email. | Multi-contact support per company with `isDecisionMaker`, `preferredCommunication`, department tags, and activity linkage. | Near Match | **REUSE**: `CustomerContact` already contains decision maker flag and preferred comms. |
| **Product Requirements** | Free-text `productInterest` and `requirement` fields in Leads/Enquiries. | **Dynamic Structured Requirement Builder**: Product-specific schemas (VFD HP, Voltage, Starter Type, HMI, PLC, IP rating) + Template Builder. | Missing Structure | **ADD**: Add `Requirement` and `RequirementTemplate` entities and UI template builder. |
| **Customer Timeline** | basic interaction list in `customer_interactions`. | **Automated Chronological Customer 360 Timeline**: Aggregates Calls, Meetings, Site Visits, Requirements, Quotes, Sales Orders, Invoices. | Partial Match | **REFACTOR & AGGREGATE**: Build unified timeline aggregator query across all activity models. |
| **Activities: Calls & Meetings** | `CrmActivity`, `CrmCall`, `CrmMeeting` basic schemas. | Multi-employee participant calendar, conflict detection, automatic reminder alerts, structured meeting reports. | Partial Match | **MODIFY & EXTEND**: Add `CrmMeetingParticipant` model, calendar conflict validator API, and escalation timer. |
| **Site Visit Management** | `CrmSiteVisit` with location, voltage, pump HP, photo URLs. | Complete site visit workflow: Request -> Assign -> Schedule -> Mobile Check-in -> Inspection Data & Photos -> Manager Signoff. | Near Match | **ENHANCE**: Connect mobile photo upload workflow to `CustomerMedia` and site visit report signoff. |
| **Opportunity & Pipeline** | `Opportunity` model with 7 Kanban stages and probability-weighted revenue. | Kanban board with permission-controlled stage drag-and-drop, mandatory lost reasons, competitor tracking, and quotation request handoff. | Match | **REUSE & CONNECT**: Connect stage changes directly to audit events and Quotation workflow. |
| **Budget Management** | Single `estimatedValue` field. | **Multi-tier Financial Sizing Engine**: Customer Stated Budget, Internal Estimated Cost, Target Price, Expected Margin, Indicative Price, Final Quote Price. | Missing Multi-Tier | **ADD**: Add multi-tier financial fields to `Opportunity` and `PanelSpecification`. Enforce role-based cost visibility. |
| **Quotation & Sales Order Handoff** | Disconnected manual flow. | One-click transition: Opportunity -> Technical Review -> Commercial Validation -> Quotation Request -> Sales Order. | Process Gap | **MODIFY & INTEGRATE**: Link Opportunity stage `QUOTATION_SENT` to `Quotation` entity generation. |
| **Task Integration** | Separate `Task` model. | Automatic task creation from next actions in Meetings, Site Visits, and Follow-ups without data duplication. | Integration Gap | **MODIFY**: Bind CRM next actions directly to `tasks` table with relation metadata. |
| **RBAC & Record-Level Security** | Basic module permissions (`CRM:VIEW`, `CUSTOMERS:VIEW`). | Granular record-level authorization (`OWN`, `ASSIGNED`, `TEAM`, `DEPARTMENT`, `COMPANY`, `ADMIN`). Backend enforcement on every API. | Guard Upgrade Needed | **ENFORCE**: Update NestJS `PermissionsGuard` and service layer to evaluate `req.user` ownership scope. |

---

## 3. Action Strategy Breakdown

### A. REUSE (Do Not Recreate)
1. **`User`, `Staff`, `Role`, `Permission` Models**: Existing RBAC schema forms the foundation.
2. **`Customer` & `CustomerContact` Entities**: Reuse existing schema in `schema.prisma`.
3. **`Lead`, `Enquiry`, `Opportunity` Core Models**: Retain primary keys, status fields, and probability mechanics.
4. **Prisma ORM & SQLite/PostgreSQL Dual Setup**: Maintain existing ORM abstraction layer.
5. **Flutter Material 3 App Shell & Dark Theme**: Reuse primary Saark Orange (#F97316) aesthetics and responsive layout.

### B. MODIFY / EXTEND
1. **`Opportunity` Model**: Add multi-tier pricing fields (`customerBudget`, `internalCost`, `targetPrice`, `marginPercent`, `indicativePrice`).
2. **`CrmMeeting` Model**: Extend to support multi-employee attendance (`CrmMeetingParticipant`) and calendar conflict validation.
3. **`CrmSiteVisit` Model**: Link directly to `CustomerMedia` for structured photo categorization (`SITE_PHOTO`, `SLD_PHOTO`).
4. **CRM Backend Services**: Inject strict record-ownership scoping into all list and detail queries based on user role (`OWN`, `TEAM`, `COMPANY`).

### C. ADD (New Modular Capabilities)
1. **Structured Technical Requirement Engine**:
   - `RequirementTemplate` & `CustomerRequirement` models.
   - Dynamic UI form builders for panel specifications (VFD HP, starter types, IP ratings, PLCs).
2. **Calendar Conflict Detector API**:
   - `POST /api/v1/crm/meetings/check-conflict`: Checks participant availability across overlapping time windows.
3. **Meeting Escalation & Report Timer**:
   - Automated status tracker notifying managers if meeting reports remain pending post-completion.
4. **Advanced Multi-Criteria CRM Search**:
   - Multi-field filter API (`GET /api/v1/crm/search`) supporting saved user filter presets (`CrmSavedFilter`).

### D. REFACTOR
1. **Customer 360 Aggregator**: Refactor timeline queries into a single unified service stream that sorts all historical events chronologically.
2. **Task Integration Hook**: Refactor activity completion handlers to automatically instantiate items in the central `Task` model rather than creating parallel task lists.

---

## 4. Security & Data Privacy Enforcement Matrix

| User Role | Customer Scope | Financials Scope | Internal Cost Scope | Stage Drag-Drop | Merge Records |
|---|---|---|---|---|---|
| **Sales Executive** | Own & Assigned Records | Customer Budget & Indicative Price | **HIDDEN** | Own Opportunities | No |
| **Sales Manager** | Team Records | Budget, Target Price & Expected Margin | Visible | Team Opportunities | Authorized Only |
| **Technical Engineer** | Assigned Requirements & Site Visits | Technical Specs Only | **HIDDEN** | None | No |
| **Super Admin** | Full Company-Wide | Full Commercial Information | Full Access | Full Access | Yes |

---

## 5. Architectural Readiness for PostgreSQL & AWS S3 Migration

- **Database Abstraction**: Prisma ORM schema is maintained with standard datatypes compatible with PostgreSQL without raw SQL vendor dependencies.
- **Storage Abstraction**: File operations utilize the NestJS `StorageService` interface, abstracting local disk path operations to allow seamless transition to `AWS S3` bucket keys.
