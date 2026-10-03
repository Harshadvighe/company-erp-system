# SAARK ERP — CRM & Sales System: Functional & Technical Requirements Specification

**Company:** SAARK EXPLORATION PRIVATE LIMITED  
**Document:** `docs/CRM_REQUIREMENTS.md`  
**Architect:** Senior Full-Stack ERP & CRM Architect  
**Date:** October 2026  

---

## 1. System Vision & Objective
To transform the existing fragmented CRM, Customer, and Enquiry pages into an integrated, role-governed, enterprise-grade Sales & Customer Intelligence system for SAARK Exploration Private Limited. The system governs the entire lifecycle:
$$\text{Lead} \longrightarrow \text{Qualification} \longrightarrow \text{Customer} \longrightarrow \text{Enquiry} \longrightarrow \text{Opportunity} \longrightarrow \text{Quotation Handoff} \longrightarrow \text{Sales Order} \longrightarrow \text{Repeat Business}$$

---

## 2. Core Functional Requirements (Module Breakdown)

### REQ-01: Role-Aware CRM Dashboard
* **KPI Metrics:**
  * Total Leads, New Leads, Qualified Leads.
  * Open Enquiries, Active Opportunities, Pipeline Weighted Value.
  * Won Value, Lost Value, Conversion Rate (%).
  * Follow-ups Today, Overdue Follow-ups, Meetings Scheduled Today.
* **Role Scoping:**
  * `Sales Executive`: Restricts all cards and widgets strictly to records where `assignedStaffId == user.staffId`.
  * `Sales Manager`: Aggregates records across all reporting subordinates in the Sales & Marketing department.
  * `Super Admin`: Company-wide aggregates with branch/location breakdowns.
* **Widgets:** Stage-by-stage Pipeline Funnel, Lead Source Donut, Top Products by Interest, Follow-up Alert Queue.

### REQ-02: Lead Management & BANT Qualification
* **Fields:** Auto-generated `leadNumber` (`LEAD-YYYY-XXXXX`), `companyName`, `contactPerson`, `designation`, `phone`, `email`, `website`, `location`, `city`, `state`, `district`, `country`, `source` (Website, IndiaMART, Reference, Exhibition, Cold Call, etc.), `leadType` (OEM, EPC, End-Customer, Dealer, Govt), `interestedProducts` (multi-select relational to Product Master), `estimatedValue`, `priority` (`LOW`, `MEDIUM`, `HIGH`, `URGENT`), `assignedStaffId`, `salesManagerStaffId`, `expectedClosureDate`, `status`, `notes`.
* **Lead Lifecycle Statuses:**
  * `NEW` → `CONTACTED` → `QUALIFIED` → `REQUIREMENT_IDENTIFIED` → `OPPORTUNITY` → `QUOTATION` → `NEGOTIATION` → `WON` → `LOST` → `DISQUALIFIED`.
* **Qualification Checklist (BANT):**
  * Budget confirmed (Amount & Currency).
  * Authority verified (Key decision-maker identified).
  * Need established (Specific panel/pump/system technical requirement).
  * Timeline identified (Procurement schedule).

### REQ-03: Lead Conversion Engine
* **Atomic Transaction:** One-click conversion of a `QUALIFIED` lead into:
  1. A new or linked `Customer` master record.
  2. A primary `CustomerContact`.
  3. A new `Opportunity` with linked product interests and estimated value.
* **Integrity:** Preserves original `leadId` on the customer and opportunity for end-to-end attribution.

### REQ-04: Customer Master & Multi-Contact Structure
* **Company Identity:** `customerCode` (`CUS-YYYY-XXXXX`), `companyName`, `legalName`, `gstin`, `pan`, `customerType` (`PROSPECT`, `CUSTOMER`, `DEALER`, `DISTRIBUTOR`, `PARTNER`), `customerCategory`, `industry`, `turnover`, `staffCount`, `ownerName`, `website`, `rating` (0–100), `status` (`ACTIVE`, `INACTIVE`, `DORMANT`, `BLOCKED`).
* **Location Data:** Full address, city, district, state, country, pincode.
* **Multi-Contact Hierarchy:**
  * A single customer supports an unlimited number of contacts.
  * Fields: `name`, `designation`, `department`, `mobile`, `alternateMobile`, `email`, `whatsapp`, `isDecisionMaker`, `isPrimary`, `preferredCommunication` (`CALL`, `WHATSAPP`, `EMAIL`).
  * Deleting a primary contact is prevented unless another contact is designated as primary.

### REQ-05: Customer 360 & Chronological Timeline
* **Unified Profile Header:** Company name, code, badges for type and segment, owner avatar, valuation score, and rating stars.
* **Permitted Tab-Level Views:**
  * `Overview`: Company summary, billing addresses, financial overview.
  * `Contacts`: Directory of all linked representatives.
  * `Timeline`: Complete, auto-generated chronological ledger of calls, meetings, site visits, quotations, orders, and emails.
  * `Opportunities`: All open, won, and lost pipeline records.
  * `Enquiries`: Technical requirements and specifications.
  * `Activities`: Calls, meetings, site visits, and general interactions.
  * `Quotations`: Sales quotes linked to this client.
  * `Documents & Media`: Photos, audio recordings, GST/PAN certificates, CAD drawings.

### REQ-06: Activity Management (Calls, Meetings, Site Visits, Follow-ups)
* **Calls:** Date, time, duration, contact person, call type (`INBOUND`, `OUTBOUND`), outcome (`CONNECTED`, `BUSY`, `NO_ANSWER`, `CALL_BACK`, `INTERESTED`, `NOT_INTERESTED`), call notes, next action date.
* **Meetings:** Agenda, online/offline flag, meeting location or video link, start time, end time, participants (internal staff + client contacts), meeting outcome, action items.
* **Site Visits:** Location, client engineering representative, site condition notes, pump/panel dimensions and electrical rating measurements, attached site photos, technical recommendations, next follow-up.
* **Follow-ups:**
  * Mandatory next follow-up date and assigned user for every non-closed activity.
  * Automatic status calculation: `PENDING`, `COMPLETED`, `OVERDUE` (when `scheduledDate < NOW()` and `status != COMPLETED`), `RESCHEDULED`.

### REQ-07: Opportunity Management & Visual Pipeline
* **Opportunity Entity:** `opportunityNumber` (`OPP-YYYY-XXXXX`), `customerId`, `contactId`, `enquiryId`, `title`, `products` (Relational list), `estimatedValue`, `probability` (%), `weightedValue` ($\text{Estimated Value} \times \text{Probability}$), `stage`, `expectedCloseDate`, `assignedStaffId`, `priority`, `lossReason`, `lossRemarks`.
* **Stages:**
  1. `QUALIFICATION` (10%)
  2. `REQUIREMENT_ANALYSIS` (25%)
  3. `TECHNICAL_EVALUATION` (40%)
  4. `QUOTATION_SENT` (60%)
  5. `NEGOTIATION` (80%)
  6. `CLOSED_WON` (100%)
  7. `CLOSED_LOST` (0%)
* **Kanban Board:** Drag-and-drop stage updates with instantaneous permission verification and audit logging.

### REQ-08: Technical Sales Quotation Handoff
* When an Opportunity reaches `QUOTATION_SENT`, the CRM allows one-click generation of a **Quotation Request**:
  * Carries over customer identity, primary contact, BOM / product requirements, and target pricing.
  * Hands off to the Core Sales & Panel Manufacturing module without redundant re-entry.

### REQ-09: Lost Deal Analysis
* Transitioning an opportunity or lead to `LOST` requires selecting a mandatory **Lost Reason**:
  * `PRICE_TOO_HIGH`, `COMPETITOR_CHOSEN`, `BUDGET_CANCELLED`, `TECHNICAL_SPEC_MISMATCH`, `DELIVERY_TIMELINE_LONG`, `CUSTOMER_UNRESPONSIVE`, `OTHER`.
* Feeds into executive lost-deal analysis charts.

### REQ-10: Advanced Company Sorting & Customer Intelligence
* **Multi-Facet Filtering:** Filter customers by Segment (`VFD Panel`, `Dewatering`, `Booster Pump`, `STP`, `BMS`), State, District, Customer Type, Minimum Turnover, Rating range, Assigned Executive, and Active Enquiry status.
* **Saved Filters:** Sales executives can save frequently used query presets (e.g., "My Pune VFD Clients", "Follow-ups Due Today").

### REQ-11: Interactive Graphs & Visual Analytics
* **Charts:**
  * Pipeline Funnel (Count and Value per Stage).
  * Lead Source Effectiveness (Conversion rate per source).
  * Product Demand Breakdown (Booster Pump vs. VFD Panel vs. Sensor Panel).
  * Monthly Trend of Inward Enquiries vs. Won Orders.
  * Geographical Heatmap (Customer count by District & State).
* **Interactivity:** Clicking any chart segment filters the active list to matching records.

### REQ-12: Duplicate Detection & Administrative Merge
* **Real-Time Duplicate Checking:** Evaluates `gstin`, `phone`, `email`, and sanitized `companyName` before saving.
* **Resolution Modal:** Prompts user to view existing record or proceed.
* **Customer Merge (Admin Only):** Merges two customer records into a master customer, migrating all contacts, leads, enquiries, opportunities, interactions, and quotations, with full audit trail.

### REQ-13: Document & Media Management
* **Document Types:** GST Certificate, PAN Card, Purchase Orders, Engineering Drawings, Site Inspection Reports.
* **Photo Categories:** Office, Site Inspection, Panel Installation, Product Failure/Warranty.
* **Audio Recordings:** Audio notes and recorded phone call discussions linked to interactions.

### REQ-14: Import & Export Engine
* **Import:** Step-by-step wizard for CSV/Excel customer imports with automated header mapping, validation error flags, duplicate detection, and import summary.
* **Export:** Role-gated export of filtered customer and lead datasets to CSV and Excel.

---

## 3. Non-Functional & Security Requirements

### NFR-01: Zero Extra UI Architecture
* If a user lacks `CRM_REPORT:VIEW`, the Reports tab/menu is excluded from the DOM.
* If a user lacks `CRM:EXPORT`, the Export button is hidden.
* If a user lacks `CRM:DELETE`, delete menu items are omitted.
* If an executive is not assigned to a customer and lacks `TEAM`/`ALL` scope, the customer is not presented in search or lists.

### NFR-02: Backend Access Control Enforcement
* All API endpoints enforce `@UseGuards(JwtAuthGuard, PermissionsGuard)` and `@RequirePermissions(...)`.
* Direct REST calls by unauthorized users or out-of-scope record access attempts return `403 Forbidden`.

### NFR-03: Performance & Scalability
* Server-side pagination with default page sizes of 25 records.
* Indexed foreign keys (`customerId`, `assignedStaffId`, `status`, `stage`).
* Debounced full-text search with query optimization.
