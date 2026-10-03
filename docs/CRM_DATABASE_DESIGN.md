# SAARK ERP — CRM & Sales System: Database Schema Design

**Company:** SAARK EXPLORATION PRIVATE LIMITED  
**Document:** `docs/CRM_DATABASE_DESIGN.md`  
**Architect:** Senior Full-Stack ERP & CRM Architect  
**Date:** October 2026  

---

## 1. Schema Design Principles
1. **Preservation of Existing Data:** Retains all existing customer, contact, valuation, and interaction rows in `saark_erp.db` without column truncation or destructive dropping.
2. **Relational Integrity:** Eliminates arbitrary text fields (`assignedTo`, `recordedBy`) in favor of authoritative Foreign Keys linking to `Staff` (`staffId`) and `User` (`userId`).
3. **Cross-Module Integration:** Links CRM entities to core ERP modules: Products (`products`), Tasks (`tasks`), Staff (`staff`), and Projects (`projects`).
4. **Dual Engine Compatibility:** Compatible with SQLite for development/testing and PostgreSQL for cloud production.

---

## 2. Updated Existing Models

### 2.1 Customer Master (`customers`)
```prisma
model Customer {
  id                   String   @id @default(uuid())
  customerCode         String   @unique // CUS-YYYY-XXXXX
  companyName          String
  legalName            String?
  gstin                String?
  pan                  String?
  customerType         String   @default("END_CUSTOMER") // PROSPECT, CUSTOMER, DEALER, DISTRIBUTOR, OEM, PARTNER
  customerCategory     String   @default("STANDARD")
  customerSegment      String?  @default("VFD_PANEL") // VFD_PANEL, DEWATERING, BOOSTER_PUMP, STP, BMS, FIRE_PANEL
  contactPerson        String
  designation          String?
  email                String
  phone                String
  alternatePhone       String?
  website              String?
  address              String
  country              String   @default("India")
  state                String
  district             String
  city                 String
  pincode              String
  ownerName            String?
  staffCount           Int      @default(0)
  turnover             String?
  industry             String?
  source               String?  @default("DIRECT")
  customerRating       Float    @default(5.0)
  creditLimit          Float    @default(0)
  paymentTerms         String?  @default("NET_30")
  potentialValue       Float    @default(0)
  status               String   @default("ACTIVE") // ACTIVE, INACTIVE, DORMANT, BLOCKED, DELETED
  assignedStaffId      String?
  salesManagerStaffId  String?
  createdAt            DateTime @default(now())
  updatedAt            DateTime @updatedAt

  assignedStaff        Staff?   @relation("CustomerAssignee", fields: [assignedStaffId], references: [id])
  salesManagerStaff    Staff?   @relation("CustomerManager", fields: [salesManagerStaffId], references: [id])
  contacts             CustomerContact[]
  interactions         CustomerInteraction[]
  valuations           CustomerValuation?
  leads                Lead[]
  enquiries            Enquiry[]
  opportunities        Opportunity[]
  activities           CrmActivity[]
  followUps            CrmFollowUp[]
  documents            CustomerDocument[]
  media                CustomerMedia[]
  panelSpecs           PanelSpecification[]
  projects             Project[]

  @@map("customers")
}
```

### 2.2 Customer Contacts (`customer_contacts`)
```prisma
model CustomerContact {
  id                     String   @id @default(uuid())
  customerId             String
  name                   String
  designation            String?
  department             String?
  phone                  String?
  mobile                 String
  email                  String?
  whatsapp               String?
  isPrimary              Boolean  @default(false)
  isDecisionMaker        Boolean  @default(false)
  preferredCommunication String   @default("CALL") // CALL, WHATSAPP, EMAIL
  notes                  String?
  createdAt              DateTime @default(now())

  customer               Customer @relation(fields: [customerId], references: [id], onDelete: Cascade)
  interactions           CustomerInteraction[]
  activities             CrmActivity[]
  calls                  CrmCall[]
  meetings               CrmMeeting[]

  @@map("customer_contacts")
}
```

### 2.3 Leads (`leads`)
```prisma
model Lead {
  id                     String   @id @default(uuid())
  leadNumber             String   @unique // LEAD-YYYY-XXXXX
  companyName            String
  contactPerson          String
  phone                  String
  email                  String?
  source                 String?  @default("DIRECT")
  leadType               String?  @default("END_CUSTOMER")
  productInterest        String?
  requirement            String?
  estimatedValue         Float    @default(0)
  assignedStaffId        String?
  salesManagerStaffId    String?
  priority               String   @default("MEDIUM") // LOW, MEDIUM, HIGH, URGENT
  status                 String   @default("NEW") // NEW, CONTACTED, QUALIFIED, OPPORTUNITY, WON, LOST, DISQUALIFIED
  qualificationStatus    String   @default("PENDING") // PENDING, QUALIFIED, DISQUALIFIED
  bantBudget             Float?
  bantAuthority          String?
  bantNeed               String?
  bantTimeline           String?
  disqualificationReason String?
  customerId             String?
  nextFollowUp           DateTime?
  expectedClosureDate    DateTime?
  remarks                String?
  createdAt              DateTime @default(now())
  updatedAt              DateTime @updatedAt

  customer               Customer? @relation(fields: [customerId], references: [id])
  assignedStaff          Staff?    @relation("LeadAssignee", fields: [assignedStaffId], references: [id])
  salesManagerStaff      Staff?    @relation("LeadManager", fields: [salesManagerStaffId], references: [id])
  opportunities          Opportunity[]
  activities             CrmActivity[]

  @@map("leads")
}
```

---

## 3. New Enterprise CRM Models

### 3.1 Opportunities (`opportunities`)
```prisma
model Opportunity {
  id                  String   @id @default(uuid())
  opportunityNumber   String   @unique // OPP-YYYY-XXXXX
  title               String
  customerId          String
  contactId           String?
  leadId              String?
  enquiryId           String?
  assignedStaffId     String
  salesManagerStaffId String?
  stage               String   @default("QUALIFICATION") // QUALIFICATION, REQUIREMENT, TECHNICAL_EVALUATION, QUOTATION_SENT, NEGOTIATION, CLOSED_WON, CLOSED_LOST
  probability         Int      @default(10) // 10, 25, 40, 60, 80, 100, 0
  estimatedValue      Float    @default(0)
  weightedValue       Float    @default(0)
  expectedCloseDate   DateTime?
  priority            String   @default("MEDIUM")
  lostReason          String?
  lostRemarks         String?
  competitor          String?
  poNumber            String?
  poDate              DateTime?
  createdAt           DateTime @default(now())
  updatedAt           DateTime @updatedAt

  customer            Customer @relation(fields: [customerId], references: [id], onDelete: Cascade)
  assignedStaff       Staff    @relation("OppAssignee", fields: [assignedStaffId], references: [id])
  lead                Lead?    @relation(fields: [leadId], references: [id])
  enquiry             Enquiry? @relation(fields: [enquiryId], references: [id])
  activities          CrmActivity[]
  followUps           CrmFollowUp[]

  @@map("opportunities")
}
```

### 3.2 CRM Activities (`crm_activities`)
```prisma
model CrmActivity {
  id              String   @id @default(uuid())
  activityType    String   // CALL, MEETING, SITE_VISIT, DEMO, EMAIL, WHATSAPP, QUOTATION_SENT, STATUS_CHANGE, NOTE
  customerId      String?
  contactId       String?
  leadId          String?
  opportunityId   String?
  staffId         String
  subject         String
  description     String?
  outcome         String?
  nextActionDate  DateTime?
  createdAt       DateTime @default(now())

  customer        Customer?        @relation(fields: [customerId], references: [id], onDelete: Cascade)
  contact         CustomerContact? @relation(fields: [contactId], references: [id])
  lead            Lead?            @relation(fields: [leadId], references: [id])
  opportunity     Opportunity?     @relation(fields: [opportunityId], references: [id])
  staff           Staff            @relation(fields: [staffId], references: [id])
  call            CrmCall?
  meeting         CrmMeeting?
  siteVisit       CrmSiteVisit?

  @@map("crm_activities")
}
```

### 3.3 Specialized Activity Records (`calls`, `meetings`, `site_visits`)
```prisma
model CrmCall {
  id          String   @id @default(uuid())
  activityId  String   @unique
  contactId   String?
  callType    String   @default("OUTBOUND") // INBOUND, OUTBOUND
  durationSec Int      @default(0)
  callOutcome String   @default("CONNECTED") // CONNECTED, BUSY, NO_ANSWER, WRONG_NUMBER, CALL_BACK
  recordingUrl String?

  activity    CrmActivity @relation(fields: [activityId], references: [id], onDelete: Cascade)
  contact     CustomerContact? @relation(fields: [contactId], references: [id])

  @@map("crm_calls")
}

model CrmMeeting {
  id          String   @id @default(uuid())
  activityId  String   @unique
  meetingType String   @default("OFFLINE") // OFFLINE, ONLINE_TEAMS, ONLINE_ZOOM, CLIENT_OFFICE
  location    String?
  startTime   DateTime
  endTime     DateTime?
  agenda      String?
  outcome     String?

  activity    CrmActivity @relation(fields: [activityId], references: [id], onDelete: Cascade)

  @@map("crm_meetings")
}

model CrmSiteVisit {
  id              String   @id @default(uuid())
  activityId      String   @unique
  location        String
  siteCondition   String?
  voltageReading  String?
  pumpRatingHp    Float?
  panelDimensions String?
  inspectionNotes String?
  photoUrls       String? // JSON array of photo URLs

  activity        CrmActivity @relation(fields: [activityId], references: [id], onDelete: Cascade)

  @@map("crm_site_visits")
}
```

### 3.4 Follow-ups (`crm_follow_ups`)
```prisma
model CrmFollowUp {
  id             String   @id @default(uuid())
  title          String
  customerId     String?
  opportunityId  String?
  leadId         String?
  assignedStaffId String
  scheduledDate  DateTime
  status         String   @default("PENDING") // PENDING, COMPLETED, OVERDUE, CANCELLED
  priority       String   @default("MEDIUM")
  notes          String?
  completedDate  DateTime?
  createdAt      DateTime @default(now())

  customer       Customer?    @relation(fields: [customerId], references: [id], onDelete: Cascade)
  opportunity    Opportunity? @relation(fields: [opportunityId], references: [id], onDelete: Cascade)
  assignedStaff  Staff        @relation(fields: [assignedStaffId], references: [id])

  @@map("crm_follow_ups")
}
```

### 3.5 Customer Documents & Media (`customer_documents`, `customer_media`)
```prisma
model CustomerDocument {
  id           String   @id @default(uuid())
  customerId   String
  documentType String   // GST_CERTIFICATE, PAN_CARD, PO_COPY, CAD_DRAWING, SLD, CONTRACT, OTHER
  title        String
  fileUrl      String
  fileName     String
  fileSize     Int      @default(0)
  mimeType     String?
  uploadedByStaffId String
  createdAt    DateTime @default(now())

  customer     Customer @relation(fields: [customerId], references: [id], onDelete: Cascade)
  staff        Staff    @relation(fields: [uploadedByStaffId], references: [id])

  @@map("customer_documents")
}

model CustomerMedia {
  id           String   @id @default(uuid())
  customerId   String
  mediaType    String   // PHOTO_SITE, PHOTO_PANEL, PHOTO_OFFICE, AUDIO_CALL, AUDIO_NOTE
  title        String?
  fileUrl      String
  durationSec  Int?     // For audio recordings
  uploadedByStaffId String
  createdAt    DateTime @default(now())

  customer     Customer @relation(fields: [customerId], references: [id], onDelete: Cascade)
  staff        Staff    @relation(fields: [uploadedByStaffId], references: [id])

  @@map("customer_media")
}
```

### 3.6 Saved Searches & Filters (`crm_saved_filters`)
```prisma
model CrmSavedFilter {
  id          String   @id @default(uuid())
  name        String
  staffId     String
  entityType  String   // CUSTOMER, LEAD, OPPORTUNITY, FOLLOW_UP
  filterJson  String   // JSON string of active filter criteria
  isShared    Boolean  @default(false)
  createdAt   DateTime @default(now())

  staff       Staff    @relation(fields: [staffId], references: [id], onDelete: Cascade)

  @@map("crm_saved_filters")
}
```
