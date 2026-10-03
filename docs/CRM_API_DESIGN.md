# SAARK ERP — CRM & Sales System: REST API Specifications

**Company:** SAARK EXPLORATION PRIVATE LIMITED  
**Document:** `docs/CRM_API_DESIGN.md`  
**Architect:** Senior Full-Stack ERP & CRM Architect  
**Date:** October 2026  

---

## 1. Security & Common Architecture
* **Base URL:** `/api/v1`
* **Authentication:** All endpoints require `Authorization: Bearer <JWT_TOKEN>`.
* **Guard Stack:** `@UseGuards(JwtAuthGuard, PermissionsGuard)`.
* **Standard Scoping Header / Context:** The `req.user` object provides:
  * `id`: User UUID
  * `staffId`: Linked staff identifier
  * `roles`: Role code array (e.g., `['ROLE_SALES_EXEC']`)
  * `permissions`: Active permission claims array.

---

## 2. API Endpoints Catalog

### 2.1 CRM Dashboard & Analytics

#### `GET /api/v1/crm/dashboard`
* **Permission:** `CRM:VIEW`
* **Scope Resolution:** If caller is `ROLE_SALES_EXEC`, restricts all calculations to `assignedStaffId == user.staffId`. If `ROLE_SALES_MGR`, includes reporting subordinates.
* **Response (200 OK):**
  ```json
  {
    "totalLeads": 48,
    "newLeads": 12,
    "qualifiedLeads": 18,
    "openEnquiries": 15,
    "openOpportunities": 11,
    "pipelineValue": 4850000.0,
    "weightedPipelineValue": 2425000.0,
    "wonValue": 1820000.0,
    "lostValue": 450000.0,
    "conversionRate": 38,
    "followUpsToday": 4,
    "overdueFollowUps": 2,
    "meetingsToday": 1
  }
  ```

#### `GET /api/v1/crm/analytics/pipeline`
* **Permission:** `CRM_REPORT:VIEW`
* **Response (200 OK):**
  ```json
  [
    { "stage": "QUALIFICATION", "count": 5, "totalValue": 1200000.0 },
    { "stage": "REQUIREMENT", "count": 3, "totalValue": 950000.0 },
    { "stage": "TECHNICAL_EVALUATION", "count": 4, "totalValue": 1400000.0 },
    { "stage": "QUOTATION_SENT", "count": 6, "totalValue": 2100000.0 },
    { "stage": "NEGOTIATION", "count": 2, "totalValue": 800000.0 },
    { "stage": "CLOSED_WON", "count": 8, "totalValue": 2900000.0 }
  ]
  ```

---

### 2.2 Lead Management & Qualification

#### `GET /api/v1/crm/leads`
* **Permission:** `CRM:VIEW`
* **Query Parameters:** `status`, `priority`, `source`, `assignedStaffId`, `search`, `page`, `limit`.
* **Response (200 OK):** Paginated leads array with linked customer and assignee objects.

#### `POST /api/v1/crm/leads`
* **Permission:** `CRM:CREATE`
* **Request Body:**
  ```json
  {
    "companyName": "Kalyani Technoforge Ltd",
    "contactPerson": "Ramesh Deshmukh",
    "phone": "+91 98220 11223",
    "email": "ramesh.d@kalyanitech.com",
    "source": "INDIAMART",
    "productInterest": "VFD_PANEL",
    "requirement": "45kW VFD Panel for water recirculation with bypass",
    "estimatedValue": 350000,
    "priority": "HIGH",
    "assignedStaffId": "staff-uuid-001"
  }
  ```
* **Response (201 Created):** Newly created lead with auto-generated `leadNumber` (`LEAD-2026-00014`).

#### `POST /api/v1/crm/leads/:id/qualify`
* **Permission:** `CRM:EDIT`
* **Request Body:**
  ```json
  {
    "bantBudget": 350000,
    "bantAuthority": "Technical Purchase Committee Head",
    "bantNeed": "Replace burned DOL starter with VFD to stop water hammer",
    "bantTimeline": "Immediate delivery within 2 weeks",
    "isQualified": true
  }
  ```

#### `POST /api/v1/crm/leads/:id/convert`
* **Permission:** `CRM:EDIT`
* **Request Body:**
  ```json
  {
    "createOpportunity": true,
    "opportunityTitle": "Kalyani 45kW Recirculation VFD Panel",
    "customerType": "CUSTOMER",
    "customerSegment": "VFD_PANEL"
  }
  ```
* **Response (201 Created):** Returns `{ customer, contact, opportunity }` created in a single database transaction.

---

### 2.3 Customer 360 & Master Endpoints

#### `GET /api/v1/customers`
* **Permission:** `CRM:VIEW`
* **Query Parameters:** `search`, `type`, `segment`, `district`, `state`, `ratingMin`, `assignedStaffId`, `page`, `limit`.

#### `POST /api/v1/customers/check-duplicate`
* **Permission:** `CRM:VIEW`
* **Request Body:** `{ "gstin": "27AAECK1234F1Z5", "phone": "+91 98220 11223", "companyName": "Kalyani" }`
* **Response (200 OK):**
  ```json
  {
    "hasDuplicate": true,
    "matches": [
      { "id": "uuid", "companyName": "Kalyani Technoforge", "customerCode": "CUS-2026-00042", "gstin": "27AAECK1234F1Z5" }
    ]
  }
  ```

#### `GET /api/v1/customers/:id/timeline`
* **Permission:** `CRM:VIEW`
* **Response (200 OK):** Chronologically unified event stream (Calls, Meetings, Site Visits, Quotations, Orders).

#### `POST /api/v1/customers/merge`
* **Permission:** `CRM:MERGE` (Super Admin Only)
* **Request Body:**
  ```json
  {
    "primaryCustomerId": "customer-uuid-master",
    "secondaryCustomerId": "customer-uuid-duplicate"
  }
  ```

---

### 2.4 Opportunities & Sales Pipeline

#### `GET /api/v1/crm/opportunities/pipeline`
* **Permission:** `CRM:VIEW`
* **Response (200 OK):** Map of stages containing lists of opportunity cards with stage totals.

#### `PATCH /api/v1/crm/opportunities/:id/stage`
* **Permission:** `CRM:EDIT`
* **Request Body:**
  ```json
  {
    "stage": "NEGOTIATION",
    "probability": 80
  }
  ```

#### `POST /api/v1/crm/opportunities/:id/lost`
* **Permission:** `CRM:EDIT`
* **Request Body:**
  ```json
  {
    "lostReason": "PRICE_TOO_HIGH",
    "competitor": "L&T Electricals",
    "lostRemarks": "Client had budget constraint of ₹2.8L; our quote was ₹3.4L."
  }
  ```

---

### 2.5 Activities, Follow-ups, and Field Visits

#### `POST /api/v1/crm/calls`
* **Permission:** `CRM:CREATE`
* **Request Body:**
  ```json
  {
    "customerId": "uuid",
    "contactId": "uuid",
    "callType": "OUTBOUND",
    "durationSec": 240,
    "callOutcome": "INTERESTED",
    "subject": "Follow up on VFD panel quotation revision",
    "description": "Client requested Schneider Altivar 610 drive instead of ABB.",
    "nextFollowUpDate": "2026-10-06T10:00:00.000Z"
  }
  ```

#### `POST /api/v1/crm/site-visits`
* **Permission:** `CRM:CREATE`
* **Request Body:**
  ```json
  {
    "customerId": "uuid",
    "location": "Bhosari MIDC, Pune - Plant 2",
    "pumpRatingHp": 45,
    "voltageReading": "418V Phase-to-Phase",
    "inspectionNotes": "Adequate ventilation available. Cable entry from bottom required.",
    "photoUrls": ["https://storage.saark.in/site-photos/bhosari-01.jpg"],
    "nextFollowUpDate": "2026-10-08T11:00:00.000Z"
  }
  ```

#### `GET /api/v1/crm/follow-ups/pending`
* **Permission:** `CRM:VIEW`
* **Response (200 OK):** List of upcoming and overdue follow-up tasks scoped to user/team.
