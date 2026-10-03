# SAARK ERP — Comprehensive User Flows & Lifecycle Workflows
**System**: Saark Exploration Private Limited ERP  
**Scope**: Operational Workflows, User Personas, State Machines, and Authorization Transitions  
**Date**: October 2026

---

## 1. Authentication & UI Personalization Flow

Every user session follows a strict role-and-permission resolution lifecycle:

```
[ User Launches App ]
         │
         ▼
[ Enters Email/Username & Password ]
         │
         ▼
[ POST /api/v1/auth/login ]
         │
         ├─► [ Password Validated with Bcrypt ]
         ├─► [ User Status Checked (Must be ACTIVE) ]
         ├─► [ Load Linked Staff Profile & Department ]
         ├─► [ Load Assigned Roles & Permissions ]
         └─► [ Generate JWT Access & Refresh Tokens ]
         │
         ▼
[ Client Stores Tokens & Profile in Secure Storage ]
         │
         ▼
[ Flutter AppShell Builds Dynamic UI ]
         ├─► Evaluates user.permissions for every Sidebar Module
         ├─► Hides all unauthorized Navigation Items
         ├─► Renders Personalized Dashboard / "My Work" Hub
         └─► Attaches JWT to all HTTP Request Headers
```

---

## 2. Admin Flow

**Goal**: Full operational oversight, company setup, staff directory management, and access governance.

1. **Dashboard Overview**:
   - Company-wide KPIs: Active projects, critical health alerts, department headcounts, monthly procurement total, open invoices.
2. **Staff & Organization Setup**:
   - Navigate to **Admin -> Staff Directory**.
   - Create new Staff record (Employee ID: `EMP008`, Full Name, Department, Designation, Reporting Manager).
   - If user requires system access, click **Create User Account** (Username, Email, Assign Role, Generate Password).
   - Staff member can exist as a non-login profile or as an authenticated user.
3. **Role & Permission Management**:
   - Navigate to **Admin -> Roles & Permissions**.
   - Create custom roles or adjust permission checkboxes across modules and actions.
   - Any permission adjustment is audited with timestamp, actor, and affected role.
4. **Audit Log Inspection**:
   - Review immutable trail of operations, logins, status changes, and sensitive record updates.

---

## 3. Project Manager Flow

**Goal**: Lead projects from inception to completion, allocate staff, track health, and coordinate tasks.

1. **Morning Briefing via "My Work" / Projects Hub**:
   - View assigned projects with automated Health Badges (`ON TRACK`, `AT RISK`, `CRITICAL`).
   - Identify overdue tasks and pending milestone deadlines.
2. **Project Creation & Setup**:
   - Click `+ New Project`.
   - Fill Project Details: Project Name, Customer, Project Type (e.g. *Panel Manufacturing*, *Engineering / R&D*), Priority, Start Date, Target End Date, Total Budget.
   - Set Milestones (e.g., *Design Review*, *BOM Approval*, *Material Procured*, *Fabrication*, *Testing & QC*, *Dispatch*).
3. **Team Allocation**:
   - Go to Project **Team** tab.
   - Select Staff members from Staff Directory (e.g., Lead Design Engineer, Panel Wiring Technician).
   - Assign project roles and allocation percentage (e.g., 50% capacity).
4. **Task Decomposition & Assignment**:
   - Under Project **Tasks** tab, click `+ Add Task`.
   - Specify Task Title, Description, Priority, Due Date, Estimated Hours, and Assignee Staff.
   - Task immediately appears in the Assignee's "My Work" queue.
5. **Monitoring & Review**:
   - When an engineer finishes a task and moves it to `REVIEW`, the PM receives an in-app notification.
   - PM reviews task output:
     - If approved: Click **Approve / Complete** -> Task moves to `COMPLETED`.
     - If changes needed: Click **Return for Changes** with notes -> Task returns to `IN_PROGRESS`.

---

## 4. Employee Flow

**Goal**: Zero friction, zero ERP bloat. Focus entirely on assigned duties.

1. **Login Experience**:
   - Employee logs in and lands directly on **My Work**.
   - **Zero Extra UI**: The sidebar only shows:
     - `My Work`
     - `My Tasks`
     - `Assigned Projects`
     - `Staff Directory` (for internal contact lookup)
     - `Notifications`
   - No Purchase, Accounts, CRM, or Admin clutter.
2. **Executing Daily Tasks**:
   - View assigned tasks ordered by Priority (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`) and Due Date.
   - Select task:
     - If newly assigned (`ASSIGNED`): Click **Accept Task** -> Status becomes `ACCEPTED`.
     - When starting work: Click **Start Work** -> Status becomes `IN_PROGRESS`.
     - Log actual hours and update progress slider (e.g. 70%).
     - Add progress comments or ask questions to the manager.
3. **Submitting for Completion**:
   - When work is done, click **Submit for Review**.
   - Enter completion summary and attach documents/photos if needed.
   - Status updates to `REVIEW`.
   - Task is removed from Employee's active execution list and queued for Manager review.

---

## 5. Task Lifecycle State Machine

```
   [ 1. CREATED ]
         │
         │  (Assigned to Staff Member)
         ▼
   [ 2. ASSIGNED ]
         │
         │  (Assignee acknowledges task)
         ▼
   [ 3. ACCEPTED ]
         │
         │  (Work begins)
         ▼
   [ 4. IN_PROGRESS ] ◄─────────────────────────┐
         │                                       │ (Manager requests changes)
         │  (Assignee submits output)            │
         ▼                                       │
   [ 5. REVIEW ] ────────────────────────────────┘
         │
         │  (Manager / Approver signs off)
         ▼
   [ 6. COMPLETED ]
```

- **Cancellation / On-Hold**:
  - A task can be placed `ON_HOLD` or `CANCELLED` only by the Creator or Manager.
- **Audit Logging**:
  - Every transition creates an immutable record in `task_activities` (`taskId`, `staffId`, `action`, `oldValue`, `newValue`, `timestamp`).

---

## 6. Project Health Calculation Flow

The ERP computes project health dynamically without requiring manual estimation:

```
[ Scheduled Trigger / On Task Update ]
                  │
                  ▼
        Check 3 Key Indicators:
 1. Overdue Tasks:
    - If overdue tasks > 20% of total OR critical task overdue: SCORE -30
 2. Budget Utilization vs Timeline:
    - If (Actual Cost / Budget) > (Elapsed Days / Total Days) + 20%: SCORE -30
 3. Milestone Delays:
    - If any milestone past due date without completion: SCORE -20
                  │
                  ▼
        Aggregate Health Metric:
  - 80 to 100 Score  ──►  🟢 ON TRACK
  - 50 to 79 Score   ──►  🟡 AT RISK
  - Below 50 Score   ──►  🔴 CRITICAL
                  │
                  ▼
  Stored on Project record & Broadcasted to PM Dashboard
```

---

## 7. Approval & Sign-Off Flow

Used for Task Sign-Off, Purchase Requisitions, and Project Milestones:

1. **Initiation**:
   - Submitter clicks `Submit for Approval`.
   - Entity status moves to `PENDING_APPROVAL`.
2. **Notification Delivery**:
   - Designee with `APPROVE` permission receives immediate high-priority Notification badge.
3. **Review & Decision**:
   - Approver opens modal displaying:
     - Full item summary, attachments, cost impact, and change history.
   - Two authorized actions available:
     - **Approve**: Enters approval notes -> Status updates to `APPROVED` -> Downstream workflow proceeds.
     - **Reject / Return**: Mandatory reason input required -> Status updates to `RETURNED` -> Returned to initiator.

---

## 8. Notification Flow

1. **Event Triggers**:
   - `TASK_ASSIGNED`: Sent to assignee staff.
   - `TASK_REVIEW_SUBMITTED`: Sent to project manager / task creator.
   - `TASK_RETURNED`: Sent to task assignee with feedback.
   - `PROJECT_MEMBER_ADDED`: Sent to staff member.
   - `HEALTH_STATUS_CRITICAL`: High-priority alert sent to PM and Admin.
2. **Channel Delivery**:
   - In-app notification bell with unread count.
   - Click-to-navigate directly to the affected Task, Project, or Document.
