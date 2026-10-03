# SAARK ERP — CRM & Sales System: Implementation Roadmap & Execution Plan

**Company:** SAARK EXPLORATION PRIVATE LIMITED  
**Document:** `docs/CRM_IMPLEMENTATION_PLAN.md`  
**Architect:** Senior Full-Stack ERP & CRM Architect  
**Date:** October 2026  

---

## 1. Phased Execution Roadmap

```mermaid
gantt
    title SAARK CRM & Sales Module Implementation
    dateFormat  YYYY-MM-DD
    section Phase 0 - Discovery
    Audit & Architecture Docs         :done, p0, 2026-10-01, 2026-10-03
    section Phase 1 - Database
    Prisma Schema Update & Push       :active, p1, 2026-10-03, 2026-10-03
    Seed Data Preservation            :p1b, 2026-10-03, 2026-10-03
    section Phase 2 - Backend
    Guards & Scoping Interceptor      :p2, 2026-10-03, 2026-10-04
    Leads & BANT Engine               :p2b, 2026-10-03, 2026-10-04
    Opportunities & Pipeline Services :p2c, 2026-10-04, 2026-10-04
    Activities & Follow-up Scheduler  :p2d, 2026-10-04, 2026-10-04
    Customer 360 & Timeline Engine    :p2e, 2026-10-04, 2026-10-04
    section Phase 3 - Frontend
    Dynamic Navigation & Permissions  :p3a, 2026-10-04, 2026-10-05
    CRM Dashboard & Analytics Charts  :p3b, 2026-10-04, 2026-10-05
    Sales Pipeline Kanban Board       :p3c, 2026-10-05, 2026-10-05
    Customer 360 & Timeline UI        :p3d, 2026-10-05, 2026-10-06
    Company Sorting & Filters Drawer  :p3e, 2026-10-06, 2026-10-06
    section Phase 4 - Validation
    E2E Automated Security Testing    :p4, 2026-10-06, 2026-10-06
    Production Compilation & Sync     :p4b, 2026-10-06, 2026-10-06
```

---

## 2. Phase-by-Phase Deliverables

### Phase 1: Database Schema Expansion (`schema.prisma`)
* Expand `Customer` and `Lead` models with relational bindings to `Staff`.
* Add `Opportunity`, `CrmActivity`, `CrmCall`, `CrmMeeting`, `CrmSiteVisit`, `CrmFollowUp`, `CustomerDocument`, `CustomerMedia`, and `CrmSavedFilter`.
* Execute `npx prisma db push` and `npx prisma generate` to update types without dropping existing customer data.

### Phase 2: Backend CRM Core Engine (`apps/backend`)
* Implement record-level scoping helper (`getStaffScopeQuery(user)`).
* Implement `OpportunitiesService` and `OpportunitiesController` with pipeline stage aggregation.
* Implement `CrmActivitiesService` for calls, meetings, site visits, and follow-ups.
* Implement atomic `convertLead` transaction linking Customer, Contact, and Opportunity.
* Implement `checkDuplicate` and `mergeCustomers` endpoints.

### Phase 3: Frontend CRM Experience (`apps/mobile`)
* Refactor `app_router.dart` and `app_shell.dart` with dedicated CRM sub-routes:
  * `/crm/dashboard`
  * `/crm/pipeline`
  * `/crm/follow-ups`
  * `/crm/analytics`
  * `/customers/search`
* Build `CrmPipelinePage` (Kanban drag-and-drop).
* Upgrade `CustomerDetailPage` into `Customer360Page` with full chronological timeline and active tabs.
* Build `CrmFollowUpsPage` with Overdue and Today alert badges.
* Build `CrmAnalyticsPage` with interactive product, lead source, and funnel charts.

### Phase 4: Quality Assurance, Security & Deployment
* Run E2E verification test suite (`verify_crm_system.ts`).
* Validate Zero Extra UI: Log in as Sales Executive and confirm Admin/Purchase/Export options are completely absent.
* Compile Flutter Web bundle and sync to `apps/backend/public`.
* Deploy via Git commit and push to Render.
