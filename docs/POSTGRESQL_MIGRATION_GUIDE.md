# SAARK ERP: PostgreSQL Database Architecture & Migration Guide

This document outlines the complete setup, schema definitions, and migration procedures to apply **PostgreSQL** to the **CRM Module**, **HR Module**, **Production Module**, and **Admin Module** in the Saark ERP system.

---

## 1. Quick Switch Commands (Turnkey CLI)

The ERP includes an automated database switcher script:

```bash
# Switch entire ERP system to PostgreSQL
npm run db:postgres

# Switch back to SQLite (for offline/local development)
npm run db:sqlite

# Export existing database data to JSON backup
npm run db:export

# Restore/Import exported data into PostgreSQL
npm run db:import

# Push schema directly to PostgreSQL (creates all tables & indexes)
npm run db:postgres:push
```

---

## 2. PostgreSQL Connection Strings & Configuration

Update `apps/backend/.env`:

```env
# -------------------------------------------------------------
# DATABASE CONFIGURATION: POSTGRESQL
# -------------------------------------------------------------
DATABASE_PROVIDER=postgresql

# Option A: Local / Docker PostgreSQL (default docker-compose credentials)
DATABASE_URL="postgresql://saark:saark_secure_password@localhost:5432/saark_erp_db?schema=public"

# Option B: Standard Local PostgreSQL installation
# DATABASE_URL="postgresql://postgres:postgres@localhost:5432/saark_erp_db?schema=public"

# Option C: Supabase (Transaction Pooler)
# DATABASE_URL="postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres?pgbouncer=true"

# Option D: Neon Serverless PostgreSQL
# DATABASE_URL="postgresql://[user]:[password]@[endpoint].neon.tech/saark_erp_db?sslmode=require"

# Option E: Render / AWS RDS / DigitalOcean Managed Database
# DATABASE_URL="postgresql://[user]:[password]@[host]:5432/[db_name]?sslmode=require"
```

---

## 3. Module-by-Module Code Reference for PostgreSQL

### 3.1. ADMIN & AUTHENTICATION MODULE

#### PostgreSQL Prisma Schema
```prisma
model User {
  id                      String      @id @default(uuid())
  username                String      @unique
  email                   String      @unique
  passwordHash            String
  fullName                String
  phone                   String?
  designation             String?
  departmentId            String?
  status                  String      @default("ACTIVE") // ACTIVE, INACTIVE, LOCKED
  faceVerificationEnabled Boolean     @default(false)
  faceVerificationStatus  String      @default("NOT_ENROLLED")
  faceEnrolledAt          DateTime?
  failedFaceAttempts      Int         @default(0)
  faceLockoutUntil        DateTime?
  createdAt               DateTime    @default(now())
  updatedAt               DateTime    @updatedAt

  department              Department? @relation(fields: [departmentId], references: [id])
  userRoles               UserRole[]
  auditLogs               AuditLog[]
  notifications           Notification[]
  staff                   Staff?
  employee                Employee?

  @@map("users")
  @@index([status])
  @@index([departmentId])
}

model Role {
  id          String           @id @default(uuid())
  name        String           @unique
  code        String           @unique
  description String?
  isSystem    Boolean          @default(false)
  createdAt   DateTime         @default(now())

  userRoles       UserRole[]
  rolePermissions RolePermission[]

  @@map("roles")
}

model Permission {
  id              String           @id @default(uuid())
  module          String
  action          String
  description     String?
  createdAt       DateTime         @default(now())

  rolePermissions RolePermission[]

  @@unique([module, action])
  @@map("permissions")
}

model UserRole {
  userId     String
  roleId     String
  assignedAt DateTime @default(now())

  user       User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  role       Role     @relation(fields: [roleId], references: [id], onDelete: Cascade)

  @@id([userId, roleId])
  @@map("user_roles")
}

model RolePermission {
  roleId       String
  permissionId String
  assignedAt   DateTime   @default(now())

  role         Role       @relation(fields: [roleId], references: [id], onDelete: Cascade)
  permission   Permission @relation(fields: [permissionId], references: [id], onDelete: Cascade)

  @@id([roleId, permissionId])
  @@map("role_permissions")
}

model AuditLog {
  id            String   @id @default(uuid())
  userId        String?
  userEmail     String?
  action        String
  module        String
  entityType    String?
  entityId      String?
  oldValuesJson String?
  newValuesJson String?
  details       String?
  ipAddress     String?
  timestamp     DateTime @default(now())

  user          User?    @relation(fields: [userId], references: [id], onDelete: SetNull)

  @@map("audit_logs")
  @@index([userId])
  @@index([module])
  @@index([timestamp])
}
```

---

### 3.2. CRM MODULE

#### PostgreSQL Prisma Schema
```prisma
model Customer {
  id                     String                    @id @default(uuid())
  customerCode           String                    @unique // CUS-2026-00001
  companyName            String
  legalName              String?
  gstin                  String?
  pan                    String?
  gstStatus              String                    @default("GST_REGISTERED")
  gstVerified            Boolean                   @default(false)
  gstVerifiedAt          DateTime?
  customerType           String                    @default("END_CUSTOMER") // DEALER, DISTRIBUTOR, OEM, PROSPECT
  contactPerson          String
  email                  String
  phone                  String
  city                   String                    @default("Pune")
  state                  String                    @default("Maharashtra")
  pincode                String                    @default("411026")
  status                 String                    @default("ACTIVE")
  assignedStaffId        String?
  createdAt              DateTime                  @default(now())
  updatedAt              DateTime                  @updatedAt

  contacts               CustomerContact[]
  valuations             CustomerValuation[]
  valuationHistories     CompanyValuationHistory[]
  productInterests       CompanyProductInterest[]
  leads                  Lead[]
  enquiries              Enquiry[]
  opportunities          Opportunity[]
  activities             CrmActivity[]
  followUps              CrmFollowUp[]
  panelSpecifications    PanelSpecification[]
  quotations             Quotation[]
  salesOrders            SalesOrder[]

  @@map("customers")
  @@index([customerCode])
  @@index([gstin])
  @@index([status])
  @@index([assignedStaffId])
}

model CustomerContact {
  id                     String       @id @default(uuid())
  customerId             String
  name                   String
  designation            String?
  email                  String?
  mobile                 String
  isPrimary              Boolean      @default(false)
  isDecisionMaker        Boolean      @default(false)
  createdAt              DateTime     @default(now())
  updatedAt              DateTime     @updatedAt

  customer               Customer     @relation(fields: [customerId], references: [id], onDelete: Cascade)

  @@map("customer_contacts")
  @@index([customerId])
}

model Lead {
  id                     String       @id @default(uuid())
  leadNumber             String       @unique // LEAD-2026-00001
  companyName            String
  contactPerson          String
  phone                  String
  email                  String?
  source                 String?      @default("INDIA_MART")
  productInterest        String?
  requirement            String?
  estimatedValue         Float        @default(0)
  status                 String       @default("NEW") // NEW, CONTACTED, QUALIFIED, OPPORTUNITY, WON, LOST
  qualificationStatus    String       @default("PENDING") // PENDING, QUALIFIED, DISQUALIFIED
  bantBudget             Float?
  bantAuthority          String?      // DECISION_MAKER, INFLUENCER
  bantNeed               String?
  bantTimeline           String?
  customerId             String?
  assignedStaffId        String?
  createdAt              DateTime     @default(now())
  updatedAt              DateTime     @updatedAt

  customer               Customer?    @relation(fields: [customerId], references: [id])
  opportunities          Opportunity[]

  @@map("leads")
  @@index([leadNumber])
  @@index([status])
  @@index([assignedStaffId])
}

model Opportunity {
  id                     String       @id @default(uuid())
  opportunityNumber      String       @unique // OPP-2026-00001
  title                  String
  customerId             String
  leadId                 String?
  assignedStaffId        String
  stage                  String       @default("QUALIFICATION") // QUALIFICATION, REQUIREMENT, QUOTATION_SENT, NEGOTIATION, CLOSED_WON, CLOSED_LOST
  probability            Int          @default(10) // 10%, 25%, 60%, 80%, 100%, 0%
  estimatedValue         Float        @default(0)
  weightedValue          Float        @default(0)
  lostReason             String?
  lostRemarks            String?
  competitor             String?
  expectedCloseDate      DateTime?
  createdAt              DateTime     @default(now())
  updatedAt              DateTime     @updatedAt

  customer               Customer     @relation(fields: [customerId], references: [id], onDelete: Cascade)
  lead                   Lead?        @relation(fields: [leadId], references: [id])
  quotations             Quotation[]
  salesOrders            SalesOrder[]

  @@map("opportunities")
  @@index([opportunityNumber])
  @@index([customerId])
  @@index([stage])
}

model CrmFollowUp {
  id                     String       @id @default(uuid())
  followUpNumber         Int?
  title                  String
  subject                String?
  customerId             String?
  opportunityId          String?
  leadId                 String?
  assignedStaffId        String
  activityType           String       @default("CALL") // CALL, MEETING, EMAIL, SITE_VISIT
  scheduledDate          DateTime?
  status                 String       @default("PENDING") // PENDING, COMPLETED, CANCELLED
  priority               String       @default("MEDIUM")  // LOW, MEDIUM, HIGH, URGENT
  discussion             String?
  outcome                String?
  nextAction             String?
  completedDate          DateTime?
  createdAt              DateTime     @default(now())
  updatedAt              DateTime     @updatedAt

  customer               Customer?    @relation(fields: [customerId], references: [id], onDelete: Cascade)

  @@map("crm_follow_ups")
  @@index([customerId])
  @@index([status])
  @@index([scheduledDate])
  @@index([assignedStaffId])
}
```

---

### 3.3. PRODUCTION & PANEL MANUFACTURING MODULE

#### PostgreSQL Prisma Schema
```prisma
model PanelSpecification {
  id                     String                  @id @default(uuid())
  panelCode              String                  @unique // PANEL-2026-0001
  customerId             String
  panelType              String                  // VFD_PANEL, BOOSTER_PUMP, STP_PANEL, HVAC_PANEL, DEWATERING_PANEL
  voltage                String                  @default("415V 3-Phase")
  currentRating          String                  @default("100A")
  pumpQty                Int                     @default(2)
  pumpHp                 Float                   @default(7.5)
  controlType            String                  @default("AUTOMATIC_PLC")
  starterType            String?                 @default("VFD")
  ipRating               String                  @default("IP55")
  enclosureType          String                  @default("POWDER_COATED_MS")
  materialCost           Float                   @default(0)
  labourCost             Float                   @default(0)
  overheadCost           Float                   @default(0)
  marginPercent          Float                   @default(15)
  finalPrice             Float                   @default(0)
  productionStatus       String                  @default("DRAFT") // DRAFT, BOM_FINALIZED, IN_ASSEMBLY, TESTING, DISPATCHED
  createdAt              DateTime                @default(now())
  updatedAt              DateTime                @updatedAt

  customer               Customer                @relation(fields: [customerId], references: [id])
  bomItems               PanelBOMItem[]
  testingInspections     PanelTestingInspection[]
  productionBatches      ProductionBatch[]

  @@map("panel_specifications")
  @@index([panelCode])
  @@index([customerId])
  @@index([panelType])
}

model PanelBOMItem {
  id                     String                  @id @default(uuid())
  panelSpecificationId   String
  productId              String
  componentName          String
  specification          String
  manufacturer           String
  quantity               Int                     @default(1)
  unitPrice              Float                   @default(0)
  totalPrice             Float                   @default(0)
  isApproved             Boolean                 @default(true)
  itemCategory           String                  @default("SWITCHGEAR")
  createdAt              DateTime                @default(now())

  panelSpecification     PanelSpecification      @relation(fields: [panelSpecificationId], references: [id], onDelete: Cascade)
  product                Product                 @relation(fields: [productId], references: [id])

  @@map("panel_bom_items")
  @@index([panelSpecificationId])
  @@index([productId])
}

model ProductionBatch {
  id                     String                  @id @default(uuid())
  batchNumber            String                  @unique // BATCH-2026-001
  panelSpecificationId   String
  salesOrderId           String?
  targetStartDate        DateTime
  targetCompletionDate   DateTime
  actualStartDate        DateTime?
  actualCompletionDate   DateTime?
  status                 String                  @default("PLANNED") // PLANNED, IN_PROGRESS, TESTING, COMPLETED
  assignedSupervisorId   String
  createdAt              DateTime                @default(now())
  updatedAt              DateTime                @updatedAt

  panelSpecification     PanelSpecification      @relation(fields: [panelSpecificationId], references: [id])

  @@map("production_batches")
  @@index([batchNumber])
  @@index([panelSpecificationId])
}
```

---

### 3.4. HUMAN RESOURCES & INDUSTRIAL WORKFORCE MODULE

#### PostgreSQL Prisma Schema
```prisma
model Staff {
  id                     String                  @id @default(uuid())
  employeeId             String                  @unique // EMP001
  fullName               String
  email                  String                  @unique
  mobile                 String?
  departmentId           String
  designationId          String
  userId                 String?                 @unique
  status                 String                  @default("ACTIVE")
  joiningDate            DateTime?
  createdAt              DateTime                @default(now())
  updatedAt              DateTime                @updatedAt

  department             Department              @relation(fields: [departmentId], references: [id])
  designation            Designation             @relation(fields: [designationId], references: [id])
  user                   User?                   @relation(fields: [userId], references: [id])

  @@map("staff")
  @@index([employeeId])
  @@index([email])
}

model ShiftMaster {
  id                     String                  @id @default(uuid())
  code                   String                  @unique // SHIFT_G, SHIFT_A, SHIFT_B, SHIFT_N
  name                   String                  // General Day Shift, Assembly Morning, Night Testing
  startTime              String                  // "08:30"
  endTime                String                  // "17:00"
  graceMinutes           Int                     @default(15)
  shiftAllowance         Float                   @default(0) // Indian Factories Act: Night allowance
  isActive               Boolean                 @default(true)
  createdAt              DateTime                @default(now())

  employees              Employee[]

  @@map("shift_masters")
}

model Employee {
  id                     String                  @id @default(uuid())
  employeeCode           String                  @unique // EMP-2026-001
  userId                 String?                 @unique
  firstName              String
  lastName               String
  email                  String                  @unique
  phone                  String
  designation            String
  departmentId           String
  employmentType         String                  @default("FULL_TIME") // FULL_TIME, CONTRACTOR, TRAINEE
  workerCategory         String                  @default("SHOP_FLOOR")
  skillLevel             String                  @default("SKILLED")   // HELPER, SEMI_SKILLED, SKILLED, MASTER_TECHNICIAN
  assignedBay            String?                 // Bay-1 (Assembly), Bay-2 (Wiring), Bay-3 (Testing)
  shiftCode              String?                 @default("SHIFT_G")
  electricalLicenseNo    String?
  salaryCtc              Float                   @default(0)
  panNo                  String?
  aadhaarNo              String?
  status                 String                  @default("ACTIVE")
  joiningDate            DateTime
  createdAt              DateTime                @default(now())
  updatedAt              DateTime                @updatedAt

  user                   User?                   @relation(fields: [userId], references: [id])
  shiftMaster            ShiftMaster?            @relation(fields: [shiftCode], references: [code])
  faceBiometric          EmployeeFaceBiometric?
  attendances            Attendance[]
  workstationAllocations WorkstationAllocation[]
  leaveRequests          LeaveRequest[]
  payrollRecords         PayrollRecord[]
  safetyIncidents        SafetyIncident[]

  @@map("employees")
  @@index([employeeCode])
  @@index([departmentId])
  @@index([status])
}

model Attendance {
  id                     String                  @id @default(uuid())
  employeeId             String
  punchDate              DateTime                // YYYY-MM-DD
  punchIn                DateTime?
  punchOut               DateTime?
  workHours              Float                   @default(0)
  overtimeHours          Float                   @default(0)
  status                 String                  @default("PRESENT") // PRESENT, HALF_DAY, ABSENT, ON_DUTY
  ppeCompliant           Boolean                 @default(true)
  createdAt              DateTime                @default(now())

  employee               Employee                @relation(fields: [employeeId], references: [id], onDelete: Cascade)

  @@unique([employeeId, punchDate])
  @@map("attendances")
  @@index([employeeId])
  @@index([punchDate])
}

model PayrollRecord {
  id                     String                  @id @default(uuid())
  slipNumber             String                  @unique // PAY-2026-10-001
  employeeId             String
  month                  String                  // October
  year                   Int                     // 2026
  workingDays            Int                     @default(26)
  presentDays            Float                   @default(26)
  basicSalary            Float
  hraAllowance           Float
  specialAllowance       Float                   @default(0)
  overtimePay            Float                   @default(0)
  shiftAllowance         Float                   @default(0)
  grossPay               Float
  pfDeduction            Float                   @default(0)
  esiDeduction           Float                   @default(0)
  taxDeduction           Float                   @default(0)
  totalDeductions        Float                   @default(0)
  netPay                 Float
  paymentStatus          String                  @default("PROCESSED") // PROCESSED, PAID, ON_HOLD
  createdAt              DateTime                @default(now())

  employee               Employee                @relation(fields: [employeeId], references: [id], onDelete: Cascade)

  @@unique([employeeId, month, year])
  @@map("payroll_records")
  @@index([employeeId])
}
```

---

## 4. Step-by-Step Execution Workflow

### Step 1: Export Current Data (Preserve All Records)
```bash
cd apps/backend
npm run db:export
```
*This saves all 1,767+ existing customer, panel, employee, and user records into `storage/saark_erp_export.json`.*

### Step 2: Start PostgreSQL (Docker or Cloud)
- **Local Docker**: Run `docker-compose up -d postgres` or double-click `START_POSTGRES_CONTAINER.bat`.
- **Cloud/External**: Create a database in Supabase, Neon, or AWS RDS, and obtain the connection URL.

### Step 3: Switch ERP Engine to PostgreSQL
```bash
npm run db:postgres
```
*This updates `apps/backend/prisma/schema.prisma` and `.env` to `provider = "postgresql"` and recompiles the Prisma Client.*

### Step 4: Push Schema to PostgreSQL
```bash
npx prisma db push
```
*This connects to PostgreSQL and creates all tables, foreign keys, constraints, and indexes instantly.*

### Step 5: Restore Data into PostgreSQL
```bash
npm run db:import
```
*This reads `storage/saark_erp_export.json` and imports all records in exact relational order into PostgreSQL without data loss!*

### Step 6: Start ERP Backend
```bash
npm run start:dev
```
*The backend is now live connected to PostgreSQL!*
