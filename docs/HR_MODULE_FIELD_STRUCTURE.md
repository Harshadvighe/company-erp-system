# HR Module - Complete Field Structure

## Employee Master - Comprehensive Field Organization

The Employee master is organized into **10 logical sections** for comprehensive workforce management in an industrial manufacturing environment.

---

### 1. BASIC INFORMATION

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `id` | String (UUID) | Yes | Primary key | `uuid` |
| `employeeCode` | String | Yes | Unique employee code | `EMP-2026-001` |
| `userId` | String (UUID) | No | Link to User authentication system | `user-uuid` |
| `firstName` | String | Yes | Employee first name | `Aditya` |
| `lastName` | String | Yes | Employee last name | `Kulkarni` |

---

### 2. CONTACT INFORMATION

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `email` | String (Email) | Yes | Unique email address | `aditya.k@saark.in` |
| `phone` | String | Yes | Primary mobile number | `+91 98200 11223` |
| `emergencyPhone` | String | No | Emergency contact number | `+91 98200 11224` |
| `address` | String | No | Full residential address | `Flat 101, Sunrise Apartments, MIDC Road, Chakan, Pune 410501` |

---

### 3. EMPLOYMENT DETAILS

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `designation` | String | Yes | Job title/designation | `Junior Design Engineer` |
| `departmentId` | String (UUID) | No | Foreign key to Department | `department-uuid` |
| `employmentType` | String | No | Employment type | `FULL_TIME`, `PART_TIME`, `CONTRACT`, `INTERN` |
| `joiningDate` | DateTime | No | Date of joining | `2024-01-15` |
| `status` | String | No | Current status | `ACTIVE`, `ON_LEAVE`, `PROBATION`, `RESIGNED` |

---

### 4. WORKFORCE & INDUSTRIAL CLASSIFICATION

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `workerCategory` | String | No | Workforce category | `STAFF_OFFICE`, `SHOPFLOOR_TECH`, `CONTRACT_LABOR`, `APPRENTICE` |
| `skillLevel` | String | No | Technical skill level | `LEVEL_1_TRAINEE`, `LEVEL_2_WIREMAN`, `LEVEL_3_BUSBAR_SPECIALIST`, `LEVEL_4_TESTING_EXPERT`, `STAFF_ENGINEER` |
| `assignedBay` | String | No | Bay assignment | `BAY_1_FABRICATION`, `BAY_2_BUSBAR`, `BAY_3_MOUNTING`, `BAY_4_WIRING`, `BAY_5_FAT_TESTING`, `BAY_6_DISPATCH` |
| `shiftCode` | String | No | Shift assignment | `SHIFT_G`, `SHIFT_A`, `SHIFT_B`, `SHIFT_N` |

---

### 5. FINANCIAL INFORMATION

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `salaryCtc` | Float | No | Annual Cost to Company (CTC) | `650000` |

---

### 6. BANK DETAILS

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `bankAccountNo` | String | No | Bank account number | `1234567890123456` |
| `bankIfsc` | String | No | IFSC code | `SBIN0001234` |

---

### 7. GOVERNMENT IDs & LICENSES

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `panNo` | String | No | PAN card number | `ABCDE1234F` |
| `aadhaarNo` | String | No | Aadhaar card number | `1234-5678-9012` |
| `electricalLicenseNo` | String | No | State wireman license number | `MH-PWD-WIREMAN-8492` |

---

### 8. CONTRACTOR DETAILS

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `contractorAgency` | String | No | Name of contracting agency | `Apex Industrial Solutions` |

---

### 9. SAFETY & MEDICAL INFORMATION

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `ppeKitIssued` | Boolean | No | PPE kit issuance flag | `true` |
| `lastSafetyTraining` | DateTime | No | Date of last safety training | `2024-06-15` |
| `bloodGroup` | String | No | Blood group | `A+`, `B+`, `O+`, `AB+`, `A-`, `B-`, `O-`, `AB-` |

---

### 10. PROFILE & ADDITIONAL

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `avatarUrl` | String | No | Profile photo URL | `https://example.com/avatar.jpg` |

---

## Complete DTO Structure (Backend - NestJS)

```typescript
export class CreateEmployeeDto {
  // 1. BASIC INFORMATION
  userId?: string;
  firstName: string;
  lastName: string;

  // 2. CONTACT INFORMATION
  email: string;
  phone: string;
  emergencyPhone?: string;
  address?: string;

  // 3. EMPLOYMENT DETAILS
  designation: string;
  departmentId?: string;
  employmentType?: string;
  joiningDate?: string;
  status?: string;

  // 4. WORKFORCE & INDUSTRIAL CLASSIFICATION
  workerCategory?: string;
  skillLevel?: string;
  assignedBay?: string;
  shiftCode?: string;

  // 5. FINANCIAL INFORMATION
  salaryCtc?: number;

  // 6. BANK DETAILS
  bankAccountNo?: string;
  bankIfsc?: string;

  // 7. GOVERNMENT IDs & LICENSES
  panNo?: string;
  aadhaarNo?: string;
  electricalLicenseNo?: string;

  // 8. CONTRACTOR DETAILS
  contractorAgency?: string;

  // 9. SAFETY & MEDICAL INFORMATION
  ppeKitIssued?: boolean;
  lastSafetyTraining?: string;
  bloodGroup?: string;

  // 10. PROFILE & ADDITIONAL
  avatarUrl?: string;
}
```

---

## Complete Model Structure (Mobile - Flutter/Dart)

```dart
class Employee {
  // 1. BASIC INFORMATION
  final String id;
  final String employeeCode;
  final String? userId;
  final String firstName;
  final String lastName;

  // 2. CONTACT INFORMATION
  final String email;
  final String phone;
  final String? emergencyPhone;
  final String? address;

  // 3. EMPLOYMENT DETAILS
  final String designation;
  final String? departmentId;
  final String? departmentName;
  final String employmentType;
  final DateTime joiningDate;
  final String status;

  // 4. WORKFORCE & INDUSTRIAL CLASSIFICATION
  final String workerCategory;
  final String? skillLevel;
  final String? assignedBay;
  final String shiftCode;

  // 5. FINANCIAL INFORMATION
  final double salaryCtc;

  // 6. BANK DETAILS
  final String? bankAccountNo;
  final String? bankIfsc;

  // 7. GOVERNMENT IDs & LICENSES
  final String? panNo;
  final String? aadhaarNo;
  final String? electricalLicenseNo;

  // 8. CONTRACTOR DETAILS
  final String? contractorAgency;

  // 9. SAFETY & MEDICAL INFORMATION
  final bool ppeKitIssued;
  final DateTime? lastSafetyTraining;
  final String? bloodGroup;

  // 10. PROFILE & ADDITIONAL
  final String? avatarUrl;
}
```

---

## Database Schema (Prisma)

```prisma
model Employee {
  // 1. BASIC INFORMATION
  id                  String   @id @default(uuid())
  employeeCode        String   @unique
  userId              String?  @unique
  firstName           String
  lastName            String

  // 2. CONTACT INFORMATION
  email               String   @unique
  phone               String
  emergencyPhone      String?
  address             String?

  // 3. EMPLOYMENT DETAILS
  designation         String
  departmentId        String?
  employmentType      String   @default("FULL_TIME")
  joiningDate         DateTime @default(now())
  status              String   @default("ACTIVE")

  // 4. WORKFORCE & INDUSTRIAL CLASSIFICATION
  workerCategory      String   @default("SHOPFLOOR_TECH")
  skillLevel          String?  @default("LEVEL_2_WIREMAN")
  assignedBay         String?  @default("BAY_4_WIRING")
  shiftCode           String   @default("SHIFT_G")

  // 5. FINANCIAL INFORMATION
  salaryCtc           Float    @default(0)

  // 6. BANK DETAILS
  bankAccountNo       String?
  bankIfsc            String?

  // 7. GOVERNMENT IDs & LICENSES
  panNo               String?
  aadhaarNo           String?
  electricalLicenseNo String?

  // 8. CONTRACTOR DETAILS
  contractorAgency    String?

  // 9. SAFETY & MEDICAL INFORMATION
  ppeKitIssued        Boolean  @default(true)
  lastSafetyTraining  DateTime?
  bloodGroup          String?

  // 10. PROFILE & ADDITIONAL
  avatarUrl           String?

  // Relations
  department             Department?              @relation(fields: [departmentId], references: [id])
  attendances            Attendance[]
  leaveRequests          LeaveRequest[]
  payrollRecords         PayrollRecord[]
  workstationAllocations WorkstationAllocation[]

  createdAt           DateTime @default(now())
  updatedAt           DateTime @updatedAt

  @@map("employees")
}
```

---

## Default Values

| Field | Default Value |
|-------|---------------|
| `employmentType` | `FULL_TIME` |
| `workerCategory` | `SHOPFLOOR_TECH` |
| `skillLevel` | `LEVEL_2_WIREMAN` |
| `assignedBay` | `BAY_4_WIRING` |
| `shiftCode` | `SHIFT_G` |
| `salaryCtc` | `0` |
| `joiningDate` | Current date/time |
| `status` | `ACTIVE` |
| `ppeKitIssued` | `true` |

---

## Field Validation Rules

- **Required Fields**: `firstName`, `lastName`, `email`, `phone`, `designation`
- **Unique Fields**: `employeeCode`, `email`, `userId` (if provided)
- **Email Validation**: Standard email format
- **String Lengths**: As per database column constraints
- **Date Format**: ISO 8601 (YYYY-MM-DD)
- **Boolean**: `true` or `false`
- **Float**: Numeric value for salary

---

## Enum Values Reference

### Employment Type
- `FULL_TIME`
- `PART_TIME`
- `CONTRACT`
- `INTERN`

### Worker Category
- `STAFF_OFFICE`
- `SHOPFLOOR_TECH`
- `CONTRACT_LABOR`
- `APPRENTICE`

### Skill Level
- `LEVEL_1_TRAINEE`
- `LEVEL_2_WIREMAN`
- `LEVEL_3_BUSBAR_SPECIALIST`
- `LEVEL_4_TESTING_EXPERT`
- `STAFF_ENGINEER`

### Assigned Bay
- `BAY_1_FABRICATION`
- `BAY_2_BUSBAR`
- `BAY_3_MOUNTING`
- `BAY_4_WIRING`
- `BAY_5_FAT_TESTING`
- `BAY_6_DISPATCH`

### Shift Code
- `SHIFT_G` (General Day: 08:30 – 17:00)
- `SHIFT_A` (Morning Assembly: 06:00 – 14:30)
- `SHIFT_B` (Afternoon Wiring: 14:00 – 22:30)
- `SHIFT_N` (Night Testing: 22:00 – 06:30)

### Status
- `ACTIVE`
- `ON_LEAVE`
- `PROBATION`
- `RESIGNED`

### Blood Group
- `A+`, `A-`
- `B+`, `B-`
- `AB+`, `AB-`
- `O+`, `O-`

---

## Files Modified

1. **Backend DTO**: `apps/backend/src/modules/hr/dto/create-employee.dto.ts`
2. **Backend Service**: `apps/backend/src/modules/hr/hr.service.ts`
3. **Mobile Model**: `apps/mobile/lib/features/hr/models/hr_models.dart`
4. **Documentation**: `docs/12_HR_INDUSTRIAL_WORKFORCE_MODULE.md`
5. **New Reference**: `docs/HR_MODULE_FIELD_STRUCTURE.md` (this file)

---

## Summary

The HR Module now includes **32 fields** organized into **10 logical sections**:

1. Basic Information (5 fields)
2. Contact Information (4 fields)
3. Employment Details (5 fields)
4. Workforce & Industrial Classification (4 fields)
5. Financial Information (1 field)
6. Bank Details (2 fields)
7. Government IDs & Licenses (3 fields)
8. Contractor Details (1 field)
9. Safety & Medical Information (3 fields)
10. Profile & Additional (1 field)

This structure provides comprehensive employee management for industrial manufacturing environments while maintaining proper organization and ease of use.
