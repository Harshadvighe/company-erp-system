# SAARK ERP — Staging Release Notes & Verification Freeze

**Release Version:** v1.2.0-staging.crm-fix  
**Target Branch:** `staging/supabase-postgresql-prep`  
**Verified Release HEAD Commit:** `c807f1147284b13daf2e6f07d8035bc6b58006e2`  
**Release Freeze Date:** 2026-10-14  
**Environment:** Supabase PostgreSQL Cloud Staging (`ttcjdrifaxasmoehdqph`)  

---

## 1. Scope & Resolved Issues

### A. CRM Customer Directory 403 Forbidden Resolution (Commits `9d98596` & `c97e910`)
- **Problem:** When an employee (`ROLE_EMPLOYEE`) was granted CRM module access via Employee Access Management, navigating to CRM $\rightarrow$ Customer Directory caused a `DioException [403 Forbidden]`.
- **Root Cause:**
  1. Backend routes in `CustomersController` (`/customers`, `/customers/:id`, `/customers/filter-options`, `/customers/export`) were guarded with `@RequirePermissions('CUSTOMERS:VIEW')`, `@RequirePermissions('CUSTOMERS:CREATE')`, etc.
  2. Employee Access Management grants module-level permissions under the `CRM` prefix (`CRM:VIEW`, `CRM:CREATE`, etc.).
  3. The `PermissionResolverService` returned `CRM:*` permissions, but the controller guards strictly checked for `CUSTOMERS:*`.
- **Solution:**
  - Updated `CustomersController` guards to accept dual aliases: `@RequirePermissions('CUSTOMERS:VIEW', 'CRM:VIEW')`, `@RequirePermissions('CUSTOMERS:CREATE', 'CRM:CREATE')`, etc.
  - Aligned Flutter frontend `app_router.dart` and `customers_list_page.dart` to verify `user.canView('CRM') || user.canView('CUSTOMERS')` for route guards and action buttons.

### B. Flutter Web Dynamic API Base URL Resolution (Commit `c807f11`)
- **Problem:** `app_constants.dart` on Web previously hardcoded port 3000 (`http://$host:3000/api/v1`), causing staging web clients on custom ports (e.g. 3199) to throw `"Unable to connect to backend server"`.
- **Solution:** Updated `AppConstants.baseUrl` to use `Uri.base.origin` (`${Uri.base.origin}/api/v1`) dynamically on web platforms, guaranteeing requests never leak or accidentally target production.
- **Compiled Web Bundle:** Recompiled release bundle via `flutter build web --release` and synchronized with `apps/backend/public/`. SHA-256 verified identical between disk and served HTTP response (`50d6c16f6b80f7e1d16a5a35277706f156987e3d55e7a364dcfa8f7d39354ba2`).

---

## 2. Automated Regression Test Summary

| Test Suite | Script Path | Assertions Passed | Failed | Status |
| :--- | :--- | :--- | :--- | :--- |
| **CRM Employee Access Suite** | `apps/backend/scripts/test_crm_employee_access_suite.js` | 36 / 36 | 0 | **100% PASS** |
| **Live HTTP PBAC Matrix** | `apps/backend/scripts/test_live_http_employee_access.js` | 23 / 23 | 0 | **100% PASS** |
| **Centralized Export & Download Audit** | `apps/backend/scripts/test_export_audit_suite.js` | 48 / 48 | 0 | **100% PASS** |
| **Phase 6 Admin Audit Viewer** | `apps/backend/scripts/test_phase6_audit_viewer_suite.js` | 47 / 47 | 0 | **100% PASS** |
| **Interactive Headless Browser UI (CDP)** | `scratch/test_employee_ui.js` | 7 / 7 flows | 0 | **100% PASS** |

### Verified Security Enforcements
1. **Dynamic PBAC Reflection:** Employee permission overrides (`ALLOW` / `DENY`) take effect immediately on the very next HTTP request without requiring re-login.
2. **CRM:VIEW-Only Protection:** Users with only `CRM:VIEW` are strictly blocked (HTTP 403 Forbidden) from creating (`POST`), editing (`PUT`), deleting (`DELETE`), or exporting (`GET /export`). In the UI, the `+ New Customer` FAB, `Import Excel`, `Export`, and row `Edit`/`Delete` buttons are completely hidden.
3. **Audit Immutability:** Unauthorized attempts automatically log `AUTHORIZATION_DENIED` audit events. Audit logs reject `PUT` and `DELETE` requests (append-only enforcement).

---

## 3. Data Integrity Verification

- **Customer Records:** 8 active customer records remain fully intact. 8 soft-deleted records preserved for compliance. Zero customer record corruption or accidental deletion.
- **Audit Logs:** 494 audit logs intact and continuously logged in Supabase PostgreSQL Cloud staging.

---

## 4. Known Boundaries & Limitations

1. **Remote Git Authentication:** Pushing to GitHub origin requires bypassing corporate schannel SSL inspection or setting `http.sslVerify=false` in sandboxed environments.
2. **Production Freeze:** Production deployment on Render and production migrations remain strictly **HOLD — NOT AUTHORIZED** until explicit sign-off from management.
