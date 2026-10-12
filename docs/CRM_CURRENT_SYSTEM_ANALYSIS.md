# CRM Current System Analysis — SAARK ERP

**System**: Saark Exploration Private Limited ERP  
**Document**: `docs/CRM_CURRENT_SYSTEM_ANALYSIS.md`  
**Architect**: Senior Full-Stack ERP & CRM Architect  
**Date**: October 2026  

---

## 1. Executive Summary & Existing CRM Overview

The **SAARK ERP** application already contains a robust foundation for customer relationship management, sales pipeline tracking, and customer master data. This analysis documents the exact existing state of frontend components, backend services, database schema models, APIs, security guards, file handling, and inter-module relationships across the codebase.

---

## 2. Existing Frontend Pages, Components & Routes

### Flutter Client (`apps/mobile/lib/features/`)

#### A. CRM Feature (`apps/mobile/lib/features/crm/presentation/pages/`)
1. **`crm_dashboard_page.dart`**:
   - Visualizes KPI cards (Total Leads, Pipeline Value, Conversion Rate, Overdue Follow-ups).
   - Renders quick-action buttons for creating leads, scheduling meetings, logging calls, and recording site visits.
2. **`leads_list_page.dart`**:
   - Manages lead listings with status filters (`NEW`, `CONTACTED`, `QUALIFIED`, `OPPORTUNITY`, `WON`, `LOST`).
   - Includes BANT Qualification modal and lead conversion trigger.
3. **`enquiries_list_page.dart`**:
   - Lists client technical enquiries linked to products (VFD Panels, Booster Pumps, STP Automation).
   - Filterable by priority (`URGENT`, `HIGH`, `MEDIUM`, `LOW`) and status (`PENDING`, `QUOTED`, `CLOSED_WON`).
4. **`crm_pipeline_page.dart`**:
   - Kanban board view of sales opportunities grouped by stage (`QUALIFICATION`, `REQUIREMENT`, `TECHNICAL_EVALUATION`, `QUOTATION_SENT`, `NEGOTIATION`, `CLOSED_WON`, `CLOSED_LOST`).
   - Supports drag-and-drop or stage transitions with probability calculation.
5. **`crm_follow_ups_page.dart`**:
   - Daily execution view for sales representatives.
   - Categorizes follow-ups into `OVERDUE`, `TODAY`, `UPCOMING`, and `COMPLETED`.
6. **`crm_analytics_page.dart`**:
   - Renders interactive charts for Lead Source distribution, Stage Conversion, and Monthly Pipeline metrics.

#### B. Customers Master Feature (`apps/mobile/lib/features/customers/presentation/pages/`)
1. **`customers_list_page.dart`**:
   - Filterable customer table showing Customer Code, Company Name, Category, Segment, Rating, and Status.
2. **`customer_form_page.dart`**:
   - Form for creating and editing customer master details (GSTIN, PAN, Type, Billing/Shipping address, Credit Limit).
3. **`customer_detail_page.dart`**:
   - Tabbed Customer 360 view (Overview, Contacts, Interactions, Enquiries, Opportunities, Timeline).

---

## 3. Existing Database Schema & Entity Relationships

### Database Engine: SQLite (Migratable to PostgreSQL via Prisma ORM)
Location: `apps/backend/prisma/schema.prisma`

#### Primary CRM Database Models:
1. **`Customer` (`@map("customers")`)**:
   - `id`, `customerCode` (e.g. `CUS-2026-00001`), `companyName`, `legalName`, `gstin`, `pan`, `customerType`, `customerCategory`, `customerSegment`, `contactPerson`, `designation`, `email`, `phone`, `alternatePhone`, `website`, `address`, `country`, `state`, `district`, `city`, `pincode`, `ownerName`, `staffCount`, `turnover`, `industry`, `source`, `customerRating`, `creditLimit`, `paymentTerms`, `potentialValue`, `status`, `assignedStaffId`, `salesManagerStaffId`.
2. **`CustomerContact` (`@map("customer_contacts")`)**:
   - `id`, `customerId`, `name`, `designation`, `department`, `phone`, `mobile`, `email`, `whatsapp`, `isPrimary`, `isDecisionMaker`, `preferredCommunication`, `notes`.
3. **`CustomerInteraction` (`@map("customer_interactions")`)**:
   - `id`, `customerId`, `contactId`, `interactionType`, `interactionDate`, `subject`, `description`, `outcome`, `nextFollowUp`, `recordedBy`, `attachmentUrl`, `audioUrl`.
4. **`CustomerValuation` (`@map("customer_valuations")`)**:
   - `id`, `customerId`, `vfdWorkScore`, `dewateringWorkScore`, `isDealer`, `isDistributor`, `ratingScore`, `valuablePercentage`, `activityCount`, `engagementScore`, `lifetimeValue`.
5. **`Lead` (`@map("leads")`)**:
   - `id`, `leadNumber`, `companyName`, `contactPerson`, `phone`, `email`, `source`, `leadType`, `productInterest`, `requirement`, `estimatedValue`, `assignedStaffId`, `salesManagerStaffId`, `priority`, `status`, `qualificationStatus`, `bantBudget`, `bantAuthority`, `bantNeed`, `bantTimeline`, `disqualificationReason`, `customerId`, `nextFollowUp`, `expectedClosureDate`, `remarks`.
6. **`Enquiry` (`@map("enquiries")`)**:
   - `id`, `enquiryNumber`, `customerId`, `enquiryDate`, `productInterest`, `quantity`, `requirement`, `expectedValue`, `assignedStaffId`, `priority`, `status`, `followUpDate`, `remarks`.
7. **`Opportunity` (`@map("opportunities")`)**:
   - `id`, `opportunityNumber`, `title`, `customerId`, `contactId`, `leadId`, `enquiryId`, `assignedStaffId`, `salesManagerStaffId`, `stage`, `probability`, `estimatedValue`, `weightedValue`, `expectedCloseDate`, `priority`, `lostReason`, `lostRemarks`, `competitor`, `poNumber`, `poDate`.
8. **`CrmActivity` & Activity Subtypes (`crm_activities`, `crm_calls`, `crm_meetings`, `crm_site_visits`)**:
   - Polymorphic relationship linking activities to Customers, Contacts, Leads, and Opportunities.
9. **`CrmFollowUp` (`crm_follow_ups`)**:
   - Scheduled tasks with `title`, `customerId`, `opportunityId`, `leadId`, `assignedStaffId`, `scheduledDate`, `status`, `priority`.
10. **`CustomerDocument` & `CustomerMedia` (`customer_documents`, `customer_media`)**:
    - Centralized file metadata tables tracking GST certificates, SLD drawings, site photos, and audio call notes.

---

## 4. Existing API Endpoints Specification

### NestJS Backend (`apps/backend/src/modules/`)

#### Customer Master API (`/api/v1/customers`):
- `GET /api/v1/customers`: Search, filter & paginate customer directory.
- `POST /api/v1/customers/check-duplicate`: Verify GST, phone, or email to prevent duplicate entities.
- `POST /api/v1/customers/merge`: Merge duplicate customer records into a target master.
- `GET /api/v1/customers/:id`: Get full customer profile with linked contacts and interactions.
- `GET /api/v1/customers/:id/timeline`: Get Customer 360 chronological history.
- `POST /api/v1/customers`: Create customer master record.
- `PUT /api/v1/customers/:id`: Update customer details.
- `DELETE /api/v1/customers/:id`: Soft-delete customer (`status = DELETED`).
- `POST /api/v1/customers/:id/contacts`: Add contact person.
- `POST /api/v1/customers/:id/interactions`: Log customer call, visit, or note.

#### CRM & Pipeline API (`/api/v1/crm`):
- `GET /api/v1/crm/dashboard`: Retrieve dashboard metrics (pipeline value, conversion rates).
- `GET /api/v1/crm/leads`: List leads with filter support.
- `POST /api/v1/crm/leads`: Ingest new lead.
- `POST /api/v1/crm/leads/:id/qualify`: Perform BANT qualification.
- `POST /api/v1/crm/leads/:id/convert`: Convert Lead to Customer + Opportunity.
- `GET /api/v1/crm/opportunities`: List opportunities.
- `GET /api/v1/crm/pipeline`: Retrieve opportunities grouped by Kanban stage.
- `POST /api/v1/crm/opportunities/:id/lost`: Mark opportunity as lost with reason.
- `POST /api/v1/crm/activities/call`: Log call duration and outcome.
- `POST /api/v1/crm/activities/meeting`: Schedule offline/online client meeting.
- `POST /api/v1/crm/activities/site-visit`: Log site inspection measurements and photos.
- `GET /api/v1/crm/follow-ups`: Retrieve scheduled follow-ups with overdue detection.
- `GET /api/v1/crm/analytics`: Retrieve visual analytics and report metrics.

---

## 5. Existing Role-Based Access Control (RBAC) & Security

- **Guards**: `JwtAuthGuard` and `PermissionsGuard` applied to NestJS endpoints.
- **Permissions Master**:
  - `CUSTOMERS:VIEW`, `CUSTOMERS:CREATE`, `CUSTOMERS:EDIT`, `CUSTOMERS:DELETE`
  - `CRM:VIEW`, `CRM:CREATE`, `CRM:EDIT`, `CRM:MERGE`
- **Zero Extra UI Rule**: Flutter UI evaluates `user.permissions` dynamically to show/hide modules, navigation links, and action buttons.

---

## 6. Inter-Module Relationships & Integrations

1. **Staff Directory (`Staff` model)**: Customers, Leads, Opportunities, and Activities link directly to `assignedStaffId` and `salesManagerStaffId`.
2. **Product Catalog (`Product` model)**: Enquiries and Opportunities link to product categories (VFD Panels, Booster Pumps, Dewatering Systems).
3. **Task System (`Task` model)**: Follow-ups and next-action deadlines cross-reference the central Task Management module.
4. **Panel Manufacturing (`PanelSpecification` model)**: Sizing preferences gathered during site visits flow into the Panel Estimator for automated BOM calculation.
5. **Quotations & Sales Orders (`Quotation`, `SalesOrder` models)**: Won opportunities trigger commercial quotation requests and sales order booking.
