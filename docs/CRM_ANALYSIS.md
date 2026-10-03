# SAARK ERP — Complete CRM & Sales System: Existing Analysis Report

**Company:** SAARK EXPLORATION PRIVATE LIMITED  
**Document:** `docs/CRM_ANALYSIS.md`  
**Architect:** Senior Full-Stack ERP & CRM Architect  
**Date:** October 2026  

---

## 1. Executive Summary
This document provides a comprehensive audit of the existing CRM, Customer Management, Lead Pipeline, Enquiry Handling, and Sales features in the SAARK ERP application. It examines existing database models, backend NestJS endpoints, Flutter frontend widgets, authentication, RBAC, and data flows, identifying existing strengths, gaps, technical debt, and preserved assets.

---

## 2. Existing Architecture Overview

### 2.1 Backend Architecture
* **Framework:** NestJS 10.x with TypeScript, Prisma ORM 5.x, SQLite (dual-compatible with PostgreSQL).
* **Existing Modules:**
  * `CustomersModule` (`apps/backend/src/modules/customers/`): CRUD for Customer Master, Contacts (`CustomerContact`), Interactions (`CustomerInteraction`), and Valuations (`CustomerValuation`).
  * `CrmModule` (`apps/backend/src/modules/crm/`): Basic Leads (`Lead`) and Enquiries (`Enquiry`) listing, creation, and status patching.
  * `AuthModule` & `StaffModule`: Recently updated with linked `Staff` profiles (`staffId`, `employeeId`, `departmentId`).
* **Authentication & Authorization Status:**
  * Endpoints currently use `@UseGuards(JwtAuthGuard)`.
  * **Gap:** Neither `CustomersController` nor `CrmController` use `@UseGuards(PermissionsGuard)` or `@RequirePermissions()`. Any authenticated user can access any customer, lead, or enquiry.
  * **Gap:** No record-level scoping (`OWN`, `TEAM`, `ALL`). A Sales Executive currently sees all leads in the company or receives no filtering by assignee.

### 2.2 Frontend Architecture
* **Framework:** Flutter 3.x (Web, Android, iOS) with Riverpod 2.x and GoRouter.
* **Existing Screens:**
  * `CustomersListPage` (`/customers`): Search bar, filter chips for type and status, customer cards.
  * `CustomerDetailPage` (`/customers/:id`): Overview, Contacts, Interactions. **Defect:** Enquiries, Leads, and Panels tabs contain dead `_PlaceholderTab` widgets.
  * `CustomerFormPage` (`/customers/new`, `/customers/:id/edit`): Comprehensive form for company identity, GST, turnover, staff count, contact details.
  * `LeadsListPage` (`/crm/leads`): Basic tab bar by status, search, lead creation bottom sheet.
  * `EnquiriesListPage` (`/crm/enquiries`): Tab bar by status, search, enquiry creation bottom sheet.
  * **Gaps:** No Opportunity Management, No Interactive Pipeline / Kanban, No Call / Meeting Scheduler, No Follow-up Engine, No Customer 360 Timeline, No Audio / Document management UI, No Company Sorting / Advanced Filters page, No Graph / Visual Analytics page.

---

## 3. Existing Database & Data Models Audit

### 3.1 Customer Master (`customers`)
* **Existing Fields:** `id`, `customerCode` (CUS-YYYY-XXXXX), `companyName`, `gstin`, `pan`, `customerType`, `customerCategory`, `contactPerson`, `designation`, `email`, `phone`, `alternatePhone`, `website`, `address`, `country`, `state`, `district`, `city`, `pincode`, `ownerName`, `staffCount`, `turnover`, `industry`, `source`, `customerRating`, `status`, timestamps.
* **Preservation Status:** **100% Preserved**. All existing columns and relations remain authoritative.
* **Fields to Add:**
  * `assignedStaffId` (Foreign Key to `staff` for owner / executive assignment).
  * `salesManagerStaffId` (Foreign Key to `staff` for reporting manager scoping).
  * `creditLimit`, `paymentTerms`.
  * `customerSegment` / `businessCategory` (VFD Panel, Dewatering, Booster Pump, STP, BMS).
  * `potentialValue`, `historicalSalesTotal`.

### 3.2 Customer Contacts (`customer_contacts`)
* **Existing Fields:** `id`, `customerId`, `name`, `designation`, `department`, `phone`, `mobile`, `email`, `whatsapp`, `isPrimary`, `notes`, `createdAt`.
* **Preservation Status:** **100% Preserved**. Multi-contact relationship already established.
* **Fields to Add:** `isDecisionMaker`, `preferredCommunication` (`CALL`, `WHATSAPP`, `EMAIL`).

### 3.3 Customer Valuations (`customer_valuations`)
* **Existing Fields:** `id`, `customerId`, `vfdWorkScore`, `dewateringWorkScore`, `isDealer`, `isDistributor`, `ratingScore`, `valuablePercentage`, `activityCount`, `dealerName`, `distributorName`, `updatedAt`.
* **Preservation Status:** **Preserved & Expanded**. Current percentage and score calculations must be maintained and augmented with automated engagement and pipeline metrics.

### 3.4 Customer Interactions (`customer_interactions`)
* **Existing Fields:** `id`, `customerId`, `contactId`, `interactionType`, `interactionDate`, `subject`, `description`, `outcome`, `nextFollowUp`, `recordedBy` (string), `attachmentUrl`, `audioUrl`, `createdAt`.
* **Gaps:**
  * `recordedBy` is an arbitrary string rather than a relational `staffId`.
  * Lacks linkage to `Lead`, `Enquiry`, or `Opportunity`.
  * No structured outcome enumeration or automatic follow-up task generation.

### 3.5 Leads (`leads`)
* **Existing Fields:** `id`, `leadNumber`, `companyName`, `contactPerson`, `phone`, `email`, `source`, `productInterest`, `requirement`, `estimatedValue`, `assignedTo` (string), `priority`, `status`, `customerId`, `nextFollowUp`, `remarks`, timestamps.
* **Gaps:**
  * `assignedTo` is currently a string rather than a `staffId`.
  * No qualification tracking (BANT: Budget, Authority, Need, Timeline).
  * No conversion pipeline to create a Customer + Opportunity + Contact atomically.

### 3.6 Enquiries (`enquiries`)
* **Existing Fields:** `id`, `enquiryNumber`, `customerId`, `enquiryDate`, `productInterest`, `quantity`, `requirement`, `expectedValue`, `assignedTo`, `priority`, `status`, `followUpDate`, `remarks`, timestamps.
* **Gaps:**
  * No items breakdown (`EnquiryItem`).
  * No direct linkage to Quotations or Opportunity pipeline.

---

## 4. Feature Gap Matrix

| Feature Area | Current State | Target Enterprise State | Severity |
|---|---|---|---|
| **RBAC / PBAC** | None on CRM endpoints | `@RequirePermissions('CRM:...')`, `PermissionsGuard`, record-level (`OWN`/`TEAM`/`ALL`) | **CRITICAL** |
| **Zero Extra UI** | Static buttons everywhere | Unauthorized tabs, buttons (+New, Export, Merge) completely hidden | **CRITICAL** |
| **Opportunities** | Non-existent | Full lifecycle: Qualification → Tech Eval → Proposal → Negotiation → Won/Lost | **HIGH** |
| **Sales Pipeline** | None | Visual Kanban with stage columns, card metrics, and audited drag-and-drop | **HIGH** |
| **Follow-up Engine** | Manual datetime field | Automated overdue detection, calendar integration, reminder alerts | **HIGH** |
| **Calls & Meetings** | Shared in generic text | Dedicated modules with durations, agendas, participants, outcomes | **HIGH** |
| **Site Visits** | None | Engineering site inspection log with photos, measurements, requirements | **HIGH** |
| **Customer 360** | 3 working tabs, 3 placeholders | Unified chronological timeline across calls, visits, quotes, orders | **HIGH** |
| **Product Mapping** | Free text `productInterest` | Relational linkage to `products` (Booster Pump, VFD, STP, BMS, etc.) | **MEDIUM** |
| **Company Sorting / Search**| Basic substring filter | Multi-parameter intelligence search (location, turnover, product, rating) | **HIGH** |
| **Graph & Analytics** | None | Interactive charts (Pipeline funnel, lead sources, conversion rates) | **HIGH** |
| **Duplicate & Merge** | GSTIN conflict check only | Comprehensive deduplication (GST, Name, Mobile, Email) + Admin merge | **HIGH** |
| **Import / Export** | None | CSV/XLSX import wizard with column mapping + Excel/PDF export | **MEDIUM** |
| **Media & Audio** | Schema fields exist, no UI | Photo gallery + Audio recording upload/playback support | **MEDIUM** |

---

## 5. Technical Debt & Risks
1. **Unassigned String References:** Existing `assignedTo` fields in `Lead` and `Enquiry` store names or usernames rather than `staffId`. Migration must resolve existing records to valid staff IDs.
2. **Missing Transactional Safety:** Lead conversion must be wrapped in a database transaction (`prisma.$transaction`) to avoid orphaned records if customer creation succeeds but contact creation fails.
3. **Data Preservation:** The existing customers, leads, and panel specifications in `saark_erp.db` must not be deleted or corrupted during schema updates.
