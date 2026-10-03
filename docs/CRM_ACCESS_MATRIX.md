# SAARK ERP — CRM & Sales System: Access Control & Permissions Matrix

**Company:** SAARK EXPLORATION PRIVATE LIMITED  
**Document:** `docs/CRM_ACCESS_MATRIX.md`  
**Architect:** Senior Full-Stack ERP & CRM Architect  
**Date:** October 2026  

---

## 1. Permission Granularity & Scoping Model

Authorization is enforced at two distinct levels:
1. **Functional Permission (`MODULE:ACTION`):** Determines whether the user possesses the capability to perform an operation (e.g., `CRM:CREATE`, `CRM:EXPORT`).
2. **Data Record Scope (`OWN`, `TEAM`, `ALL`):** Restricts the visible dataset based on organizational ownership:
   * **`OWN`:** Restricted strictly to records where `assignedStaffId == user.staffId` or `createdByStaffId == user.staffId`.
   * **`TEAM`:** Includes records assigned to the user or any staff member reporting directly or indirectly to the user in the departmental hierarchy.
   * **`ALL`:** Unrestricted company-wide access across all branches and staff.

---

## 2. Master RBAC / PBAC Matrix

| CRM Submodule | Action Verb | Super Admin | Sales Manager | Sales Executive | Standard Employee |
|---|---|---|---|---|---|
| **CRM Dashboard** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| **Leads** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `CREATE` | Allowed | Allowed | Allowed | Denied |
| | `EDIT` | ALL | TEAM | OWN | Denied |
| | `DELETE` | Allowed | Denied | Denied | Denied |
| | `ASSIGN` | ALL | TEAM | Denied | Denied |
| | `CONVERT` | ALL | TEAM | OWN | Denied |
| **Customer Master** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `CREATE` | Allowed | Allowed | Allowed | Denied |
| | `EDIT` | ALL | TEAM | OWN | Denied |
| | `DELETE` | Allowed | Denied | Denied | Denied |
| | `MERGE` | Allowed | Denied | Denied | Denied |
| **Contacts** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `CREATE` / `EDIT`| Allowed | Allowed | Allowed | Denied |
| | `DELETE` | Allowed | Denied | Denied | Denied |
| **Enquiries** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `CREATE` / `EDIT`| Allowed | Allowed | Allowed | Denied |
| **Opportunities** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `CREATE` | Allowed | Allowed | Allowed | Denied |
| | `UPDATE_STAGE` | ALL | TEAM | OWN | Denied |
| **Sales Pipeline** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `DRAG_DROP` | ALL | TEAM | OWN | Denied |
| **Calls & Meetings** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `LOG` / `SCHEDULE`| Allowed | Allowed | Allowed | Denied |
| **Follow-ups** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `COMPLETE` | ALL | TEAM | OWN | Denied |
| **Site Visits** | `VIEW` | ALL | TEAM | OWN | NONE (Hidden) |
| | `LOG_VISIT` | Allowed | Allowed | Allowed | Denied |
| **Quotation Handoff**| `SUBMIT_REQUEST`| Allowed | Allowed | Allowed | Denied |
| **Analytics & Graphs**| `VIEW` | ALL | TEAM | Denied (Hidden)| NONE (Hidden) |
| **Company Sorting** | `VIEW` / `SEARCH`| ALL | TEAM | OWN | NONE (Hidden) |
| **Import Data** | `IMPORT` | Allowed | Denied | Denied | Denied |
| **Export Data** | `EXPORT` | Allowed | Allowed | Denied (Hidden)| Denied |
| **Audit Logs** | `VIEW` | ALL | Denied | Denied | Denied |
| **CRM Settings** | `CONFIGURE` | Allowed | Denied | Denied | Denied |

---

## 3. Zero Extra UI Enforcement Directives

1. **Delete Protection:** The "Delete Customer" or "Delete Lead" action menu is completely excluded from the UI unless the user's role is `ROLE_ADMIN` and possesses `CRM:DELETE`.
2. **Export Protection:** If the logged-in user lacks `CRM:EXPORT`, all "Export to CSV" and "Export to Excel" buttons are omitted from table headers.
3. **Merge Protection:** The "Merge Customer" option is only rendered inside the administrative settings panel for Super Administrators.
4. **Manager-Only Assignment:** The "Reassign Lead" / "Reassign Opportunity" dropdown and batch assignment toolbars are invisible to Sales Executives.
5. **Backend Rejection Guarantee:** If an unauthorized user generates a crafted HTTP payload (e.g., `DELETE /api/v1/customers/:id` or `POST /api/v1/crm/merge`), the `PermissionsGuard` terminates the request and returns:
   ```json
   {
     "statusCode": 403,
     "message": "Forbidden resource: Insufficient permissions for CRM:DELETE",
     "error": "Forbidden"
   }
   ```
