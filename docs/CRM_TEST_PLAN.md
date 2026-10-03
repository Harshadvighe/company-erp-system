# SAARK ERP — CRM & Sales System: Quality Assurance & Test Plan

**Company:** SAARK EXPLORATION PRIVATE LIMITED  
**Document:** `docs/CRM_TEST_PLAN.md`  
**Architect:** Senior Full-Stack ERP & CRM Architect  
**Date:** October 2026  

---

## 1. Testing Strategy Overview
The SAARK CRM system requires rigorous verification across four vectors:
1. **Relational & Data Integrity:** Ensuring zero data corruption, foreign key consistency, and atomic transaction rollbacks.
2. **Access Control & Security (RBAC/PBAC):** Verifying backend rejection (`403 Forbidden`) and record-level scoping (`OWN`, `TEAM`, `ALL`).
3. **Business Process Logic:** Validating BANT lead qualification, pipeline stage calculations, and follow-up state machines.
4. **Zero Extra UI Compliance:** Ensuring unauthorized tabs, menus, and actions are completely absent from user interfaces.

---

## 2. Test Scenarios & Acceptance Criteria

### Test Suite 1: Authentication & Record Scoping
* **TC-01: Sales Executive Data Isolation**
  * *Actor:* `amit.sales@saark.in` (`ROLE_SALES_EXEC`).
  * *Action:* Call `GET /api/v1/crm/leads`.
  * *Expected Result:* Returns only leads where `assignedStaffId == amit.staffId`. Leads assigned to other executives are excluded.
* **TC-02: Sales Manager Departmental Aggregation**
  * *Actor:* `pm@saark.in` or Sales Manager.
  * *Action:* Call `GET /api/v1/crm/dashboard`.
  * *Expected Result:* Aggregates pipeline values and leads across all reporting sales executives.
* **TC-03: Unauthorized API Rejection**
  * *Actor:* `sneha@saark.in` (Engineering Employee without CRM permissions).
  * *Action:* Direct HTTP call `POST /api/v1/crm/leads`.
  * *Expected Result:* Backend `PermissionsGuard` terminates request with `403 Forbidden`.

### Test Suite 2: Lead Lifecycle & Conversion
* **TC-04: BANT Qualification**
  * *Action:* Mark lead as qualified with budget and need parameters.
  * *Expected Result:* Status transitions to `QUALIFIED`, and `isQualified` flag is set to `true`.
* **TC-05: Atomic Lead Conversion**
  * *Action:* Call `POST /api/v1/crm/leads/:id/convert`.
  * *Expected Result:*
    1. A new `Customer` record is generated with code `CUS-YYYY-XXXXX`.
    2. A primary `CustomerContact` is created.
    3. A new `Opportunity` is opened with matching estimated value.
    4. Lead status updates to `OPPORTUNITY`.
    5. All three records reference the original `leadId`.

### Test Suite 3: Opportunity Pipeline & Probability Weighting
* **TC-06: Stage Transition Calculation**
  * *Action:* Move an opportunity of value ₹10,00,000 from `QUALIFICATION` (10%) to `QUOTATION_SENT` (60%).
  * *Expected Result:* Weighted value automatically recalculates from ₹1,00,000 to ₹6,00,000.
* **TC-07: Mandatory Lost Reason Enforcement**
  * *Action:* Attempt to transition an opportunity to `CLOSED_LOST` without providing a `lostReason`.
  * *Expected Result:* Request rejected with `400 Bad Request` ("Lost reason is mandatory").

### Test Suite 4: Activity & Follow-up State Engine
* **TC-08: Automatic Overdue Calculation**
  * *Action:* Query pending follow-ups with scheduled date in the past.
  * *Expected Result:* Record status dynamically resolves to `OVERDUE` and triggers high-priority alert badge.
* **TC-09: Site Visit Field Data Capture**
  * *Action:* Log site visit with voltage readings, motor HP, and attached photos.
  * *Expected Result:* Saved in `crm_site_visits` and reflected in Customer 360 chronological timeline.

### Test Suite 5: Duplicate Detection & Administrative Merge
* **TC-10: Pre-creation Conflict Warning**
  * *Action:* Submit customer create payload with duplicate GSTIN or Phone.
  * *Expected Result:* Returns `hasDuplicate: true` with conflicting record details.
* **TC-11: Super Admin Merge**
  * *Action:* Super Admin executes merge of duplicate Customer B into Master Customer A.
  * *Expected Result:* Contacts, interactions, opportunities, and quotations from Customer B are re-parented to Customer A. Customer B marked `MERGED`. Full audit log recorded.

### Test Suite 6: Zero Extra UI Verification
* **TC-12: Delete Button Gating**
  * *Actor:* Sales Executive.
  * *View:* Customer Detail Page.
  * *Expected Result:* Delete button and menu option are omitted from the UI.
* **TC-13: Export Action Gating**
  * *Actor:* User without `CRM:EXPORT`.
  * *View:* Customer and Lead list headers.
  * *Expected Result:* Export icon/button is omitted.

---

## 3. Automated Validation Execution
An automated test runner (`apps/backend/scripts/verify_crm_system.ts`) will be executed upon completion to programmatically test all 13 core test cases against the live Prisma database and REST controllers.
