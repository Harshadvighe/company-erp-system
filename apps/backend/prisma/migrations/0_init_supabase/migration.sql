-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "username" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "phone" TEXT,
    "designation" TEXT,
    "departmentId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roles" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "description" TEXT,
    "isSystem" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "permissions" (
    "id" TEXT NOT NULL,
    "module" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "description" TEXT,

    CONSTRAINT "permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_roles" (
    "userId" TEXT NOT NULL,
    "roleId" TEXT NOT NULL,

    CONSTRAINT "user_roles_pkey" PRIMARY KEY ("userId","roleId")
);

-- CreateTable
CREATE TABLE "role_permissions" (
    "roleId" TEXT NOT NULL,
    "permissionId" TEXT NOT NULL,

    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("roleId","permissionId")
);

-- CreateTable
CREATE TABLE "companies" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "legalName" TEXT NOT NULL,
    "gstin" TEXT NOT NULL,
    "pan" TEXT NOT NULL,
    "cin" TEXT,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "website" TEXT,
    "address" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'India',
    "pincode" TEXT NOT NULL,
    "logoUrl" TEXT,
    "bankName" TEXT,
    "accountNo" TEXT,
    "ifscCode" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "companies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "departments" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "headStaffId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "departments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "designations" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "designations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "financial_years" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "isCurrent" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "financial_years_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tax_rates" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "percentage" DOUBLE PRECISION NOT NULL,
    "cgst" DOUBLE PRECISION NOT NULL,
    "sgst" DOUBLE PRECISION NOT NULL,
    "igst" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "tax_rates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_modes" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payment_modes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customers" (
    "id" TEXT NOT NULL,
    "customerCode" TEXT NOT NULL,
    "companyName" TEXT NOT NULL,
    "legalName" TEXT,
    "gstin" TEXT,
    "pan" TEXT,
    "customerType" TEXT NOT NULL DEFAULT 'END_CUSTOMER',
    "customerCategory" TEXT NOT NULL DEFAULT 'STANDARD',
    "customerSegment" TEXT DEFAULT 'VFD_PANEL',
    "contactPerson" TEXT NOT NULL,
    "designation" TEXT,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "alternatePhone" TEXT,
    "website" TEXT,
    "address" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'India',
    "state" TEXT NOT NULL,
    "district" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "pincode" TEXT NOT NULL,
    "ownerName" TEXT,
    "staffCount" INTEGER NOT NULL DEFAULT 0,
    "gstStatus" TEXT NOT NULL DEFAULT 'GST_REGISTERED',
    "noGstReason" TEXT,
    "gstVerified" BOOLEAN NOT NULL DEFAULT false,
    "gstVerifiedAt" TIMESTAMP(3),
    "gstProviderRef" TEXT,
    "tradeName" TEXT,
    "companyType" TEXT DEFAULT 'PVT_LTD',
    "numEmployees" INTEGER DEFAULT 0,
    "turnover" TEXT,
    "industry" TEXT,
    "source" TEXT DEFAULT 'DIRECT',
    "customerRating" DOUBLE PRECISION NOT NULL DEFAULT 5.0,
    "creditLimit" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "paymentTerms" TEXT DEFAULT 'NET_30',
    "potentialValue" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "assignedStaffId" TEXT,
    "salesManagerStaffId" TEXT,
    "createdByUserId" TEXT,
    "updatedByUserId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_systems" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT,
    "description" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_systems_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "company_product_interests" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "productSystemId" TEXT NOT NULL,
    "interestLevel" TEXT NOT NULL DEFAULT 'HIGH',
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "company_product_interests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "company_valuation_history" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "oldRating" DOUBLE PRECISION,
    "newRating" DOUBLE PRECISION NOT NULL,
    "oldValueScore" DOUBLE PRECISION,
    "newValueScore" DOUBLE PRECISION NOT NULL,
    "calculatedBy" TEXT NOT NULL,
    "staffId" TEXT,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "company_valuation_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_contacts" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "designation" TEXT,
    "department" TEXT,
    "phone" TEXT,
    "mobile" TEXT NOT NULL,
    "email" TEXT,
    "whatsapp" TEXT,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "isDecisionMaker" BOOLEAN NOT NULL DEFAULT false,
    "isTechnical" BOOLEAN NOT NULL DEFAULT false,
    "isCommercial" BOOLEAN NOT NULL DEFAULT false,
    "isPurchase" BOOLEAN NOT NULL DEFAULT false,
    "preferredCommunication" TEXT NOT NULL DEFAULT 'CALL',
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customer_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_interactions" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "contactId" TEXT,
    "interactionType" TEXT NOT NULL,
    "interactionDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "subject" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "outcome" TEXT,
    "nextFollowUp" TIMESTAMP(3),
    "recordedBy" TEXT NOT NULL,
    "attachmentUrl" TEXT,
    "audioUrl" TEXT,
    "photoUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customer_interactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_valuations" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "vfdWorkScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "dewateringWorkScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "isDealer" BOOLEAN NOT NULL DEFAULT false,
    "isDistributor" BOOLEAN NOT NULL DEFAULT false,
    "ratingScore" DOUBLE PRECISION NOT NULL DEFAULT 5.0,
    "valuablePercentage" DOUBLE PRECISION NOT NULL DEFAULT 50.0,
    "activityCount" INTEGER NOT NULL DEFAULT 0,
    "engagementScore" DOUBLE PRECISION NOT NULL DEFAULT 50.0,
    "lifetimeValue" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "dealerName" TEXT,
    "distributorName" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "customer_valuations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendors" (
    "id" TEXT NOT NULL,
    "vendorCode" TEXT NOT NULL,
    "companyName" TEXT NOT NULL,
    "legalName" TEXT,
    "gstin" TEXT,
    "pan" TEXT,
    "vendorType" TEXT DEFAULT 'MANUFACTURER',
    "vendorCategory" TEXT DEFAULT 'STANDARD',
    "contactPerson" TEXT NOT NULL,
    "designation" TEXT,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "alternatePhone" TEXT,
    "website" TEXT,
    "address" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'India',
    "state" TEXT NOT NULL,
    "district" TEXT,
    "city" TEXT NOT NULL,
    "pincode" TEXT,
    "productsSupplied" TEXT,
    "paymentTerms" TEXT DEFAULT 'NET_30',
    "creditLimit" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "rating" DOUBLE PRECISION NOT NULL DEFAULT 5.0,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "assignedStaffId" TEXT,
    "createdByUserId" TEXT,
    "updatedByUserId" TEXT,
    "constitution" TEXT DEFAULT 'PROPRIETORSHIP',
    "registeredOfficeLocation" TEXT,
    "factoryLocation" TEXT,
    "msmeStatus" TEXT DEFAULT 'NO',
    "approvalStatus" TEXT DEFAULT 'APPROVED',
    "onboardingDate" TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "vendors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_categories" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,

    CONSTRAINT "product_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "units" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,

    CONSTRAINT "units_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "products" (
    "id" TEXT NOT NULL,
    "sku" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "productType" TEXT NOT NULL DEFAULT 'FINISHED_PRODUCT',
    "description" TEXT,
    "unitId" TEXT NOT NULL,
    "taxRateId" TEXT,
    "hsnSac" TEXT,
    "purchasePrice" DOUBLE PRECISION NOT NULL,
    "sellingPrice" DOUBLE PRECISION NOT NULL,
    "minSellingPrice" DOUBLE PRECISION,
    "reorderLevel" INTEGER NOT NULL DEFAULT 10,
    "openingStock" INTEGER NOT NULL DEFAULT 0,
    "currentStock" INTEGER NOT NULL DEFAULT 0,
    "imageUrl" TEXT,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "leads" (
    "id" TEXT NOT NULL,
    "leadNumber" TEXT NOT NULL,
    "companyName" TEXT NOT NULL,
    "contactPerson" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "email" TEXT,
    "source" TEXT DEFAULT 'EXHIBITION',
    "leadType" TEXT DEFAULT 'END_CUSTOMER',
    "productInterest" TEXT,
    "requirement" TEXT,
    "estimatedValue" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "assignedTo" TEXT,
    "assignedStaffId" TEXT,
    "salesManagerStaffId" TEXT,
    "priority" TEXT NOT NULL DEFAULT 'MEDIUM',
    "status" TEXT NOT NULL DEFAULT 'NEW',
    "qualificationStatus" TEXT NOT NULL DEFAULT 'PENDING',
    "bantBudget" DOUBLE PRECISION,
    "bantAuthority" TEXT,
    "bantNeed" TEXT,
    "bantTimeline" TEXT,
    "disqualificationReason" TEXT,
    "customerId" TEXT,
    "nextFollowUp" TIMESTAMP(3),
    "expectedClosureDate" TIMESTAMP(3),
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "leads_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "enquiries" (
    "id" TEXT NOT NULL,
    "enquiryNumber" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "enquiryDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "productInterest" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "requirement" TEXT,
    "expectedValue" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "assignedTo" TEXT,
    "assignedStaffId" TEXT,
    "priority" TEXT NOT NULL DEFAULT 'MEDIUM',
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "followUpDate" TIMESTAMP(3),
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "enquiries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "opportunities" (
    "id" TEXT NOT NULL,
    "opportunityNumber" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "contactId" TEXT,
    "leadId" TEXT,
    "enquiryId" TEXT,
    "assignedStaffId" TEXT NOT NULL,
    "salesManagerStaffId" TEXT,
    "stage" TEXT NOT NULL DEFAULT 'QUALIFICATION',
    "probability" INTEGER NOT NULL DEFAULT 10,
    "estimatedValue" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "weightedValue" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "expectedCloseDate" TIMESTAMP(3),
    "priority" TEXT NOT NULL DEFAULT 'MEDIUM',
    "lostReason" TEXT,
    "lostRemarks" TEXT,
    "competitor" TEXT,
    "poNumber" TEXT,
    "poDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "opportunities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "crm_activities" (
    "id" TEXT NOT NULL,
    "activityType" TEXT NOT NULL,
    "customerId" TEXT,
    "contactId" TEXT,
    "leadId" TEXT,
    "opportunityId" TEXT,
    "staffId" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "description" TEXT,
    "outcome" TEXT,
    "nextActionDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_activities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "crm_calls" (
    "id" TEXT NOT NULL,
    "activityId" TEXT NOT NULL,
    "contactId" TEXT,
    "callType" TEXT NOT NULL DEFAULT 'OUTBOUND',
    "durationSec" INTEGER NOT NULL DEFAULT 0,
    "callOutcome" TEXT NOT NULL DEFAULT 'CONNECTED',
    "recordingUrl" TEXT,
    "dataSent" BOOLEAN NOT NULL DEFAULT false,
    "dataTypes" TEXT,

    CONSTRAINT "crm_calls_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "call_recordings" (
    "id" TEXT NOT NULL,
    "callId" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileUrl" TEXT NOT NULL,
    "durationSec" INTEGER NOT NULL DEFAULT 0,
    "fileSizeBytes" INTEGER NOT NULL DEFAULT 0,
    "mimeType" TEXT DEFAULT 'audio/webm',
    "uploadedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "call_recordings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "crm_meetings" (
    "id" TEXT NOT NULL,
    "activityId" TEXT NOT NULL,
    "meetingType" TEXT NOT NULL DEFAULT 'OFFLINE',
    "location" TEXT,
    "startTime" TIMESTAMP(3) NOT NULL,
    "endTime" TIMESTAMP(3),
    "agenda" TEXT,
    "outcome" TEXT,
    "hostStaffId" TEXT,
    "requestedByStaffId" TEXT,
    "meetingStatus" TEXT NOT NULL DEFAULT 'SCHEDULED',
    "rescheduleReason" TEXT,
    "rescheduleCount" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "crm_meetings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "meeting_schedule_history" (
    "id" TEXT NOT NULL,
    "meetingId" TEXT NOT NULL,
    "previousStartTime" TIMESTAMP(3) NOT NULL,
    "previousEndTime" TIMESTAMP(3),
    "newStartTime" TIMESTAMP(3) NOT NULL,
    "newEndTime" TIMESTAMP(3),
    "changedByStaffId" TEXT NOT NULL,
    "reason" TEXT,
    "statusBefore" TEXT,
    "statusAfter" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "meeting_schedule_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "crm_site_visits" (
    "id" TEXT NOT NULL,
    "activityId" TEXT NOT NULL,
    "location" TEXT NOT NULL,
    "siteCondition" TEXT,
    "voltageReading" TEXT,
    "pumpRatingHp" DOUBLE PRECISION,
    "panelDimensions" TEXT,
    "inspectionNotes" TEXT,
    "photoUrls" TEXT,

    CONSTRAINT "crm_site_visits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "crm_follow_ups" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "customerId" TEXT,
    "opportunityId" TEXT,
    "leadId" TEXT,
    "assignedStaffId" TEXT NOT NULL,
    "followUpNumber" INTEGER,
    "activityType" TEXT NOT NULL DEFAULT 'CALL',
    "subject" TEXT,
    "discussion" TEXT,
    "outcome" TEXT,
    "nextAction" TEXT,
    "interactionDate" TIMESTAMP(3),
    "scheduledDate" TIMESTAMP(3),
    "reminderMinutes" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "priority" TEXT NOT NULL DEFAULT 'MEDIUM',
    "notes" TEXT,
    "completedDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_follow_ups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_documents" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "documentType" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "fileUrl" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileSize" INTEGER NOT NULL DEFAULT 0,
    "mimeType" TEXT,
    "uploadedByStaffId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customer_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_media" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "mediaType" TEXT NOT NULL,
    "title" TEXT,
    "fileUrl" TEXT NOT NULL,
    "durationSec" INTEGER,
    "uploadedByStaffId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customer_media_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "crm_saved_filters" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "filterJson" TEXT NOT NULL,
    "isShared" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_saved_filters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "panel_specifications" (
    "id" TEXT NOT NULL,
    "panelCode" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "panelType" TEXT NOT NULL,
    "voltage" TEXT NOT NULL DEFAULT '415V 3-Phase',
    "currentRating" TEXT NOT NULL DEFAULT '100A',
    "pumpQty" INTEGER NOT NULL DEFAULT 2,
    "pumpHp" DOUBLE PRECISION NOT NULL DEFAULT 7.5,
    "controlType" TEXT NOT NULL DEFAULT 'AUTOMATIC_PLC',
    "starterType" TEXT DEFAULT 'VFD',
    "ipRating" TEXT NOT NULL DEFAULT 'IP55',
    "enclosureType" TEXT NOT NULL DEFAULT 'POWDER_COATED_MS',
    "materialCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "labourCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "overheadCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "marginPercent" DOUBLE PRECISION NOT NULL DEFAULT 15.0,
    "finalPrice" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "panel_specifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "panel_bom_items" (
    "id" TEXT NOT NULL,
    "panelSpecId" TEXT NOT NULL,
    "productId" TEXT,
    "componentName" TEXT NOT NULL,
    "specification" TEXT,
    "manufacturer" TEXT,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unitPrice" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalPrice" DOUBLE PRECISION NOT NULL DEFAULT 0,

    CONSTRAINT "panel_bom_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quotations" (
    "id" TEXT NOT NULL,
    "quotationNumber" TEXT NOT NULL,
    "revisionNumber" INTEGER NOT NULL DEFAULT 0,
    "code" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "opportunityId" TEXT,
    "enquiryId" TEXT,
    "panelSpecId" TEXT,
    "assignedStaffId" TEXT,
    "quotationDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validUntil" TIMESTAMP(3),
    "subject" TEXT NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "subtotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discountPercent" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discountAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxableAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "cgstPercent" DOUBLE PRECISION NOT NULL DEFAULT 9.0,
    "cgstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "sgstPercent" DOUBLE PRECISION NOT NULL DEFAULT 9.0,
    "sgstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "igstPercent" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "igstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "grandTotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "paymentTerms" TEXT DEFAULT '50% Advance, 50% Against Proforma Invoice before Dispatch',
    "deliveryTerms" TEXT DEFAULT '2 to 3 weeks from receipt of PO and technical clearance',
    "freightTerms" TEXT DEFAULT 'Ex-Works Pune. Freight extra at actuals.',
    "warrantyTerms" TEXT DEFAULT '18 months from date of supply or 12 months from commissioning, whichever is earlier.',
    "notes" TEXT,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "approvedByStaffId" TEXT,
    "approvedAt" TIMESTAMP(3),
    "sentAt" TIMESTAMP(3),
    "acceptedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quotations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quotation_items" (
    "id" TEXT NOT NULL,
    "quotationId" TEXT NOT NULL,
    "productId" TEXT,
    "itemCode" TEXT,
    "description" TEXT NOT NULL,
    "hsnSac" TEXT DEFAULT '8537',
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unit" TEXT NOT NULL DEFAULT 'Nos',
    "unitPrice" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discountPercent" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxableAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "gstPercent" DOUBLE PRECISION NOT NULL DEFAULT 18.0,
    "gstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "quotation_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_orders" (
    "id" TEXT NOT NULL,
    "orderNumber" TEXT NOT NULL,
    "quotationId" TEXT,
    "customerId" TEXT NOT NULL,
    "poNumber" TEXT,
    "poDate" TIMESTAMP(3),
    "orderDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deliveryDate" TIMESTAMP(3),
    "assignedStaffId" TEXT,
    "subtotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discountAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxableAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "grandTotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "paymentTerms" TEXT,
    "shippingAddress" TEXT,
    "billingAddress" TEXT,
    "status" TEXT NOT NULL DEFAULT 'CONFIRMED',
    "productionStatus" TEXT NOT NULL DEFAULT 'PENDING',
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sales_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_order_items" (
    "id" TEXT NOT NULL,
    "salesOrderId" TEXT NOT NULL,
    "productId" TEXT,
    "description" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unitPrice" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,

    CONSTRAINT "sales_order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_invoices" (
    "id" TEXT NOT NULL,
    "invoiceNumber" TEXT NOT NULL,
    "salesOrderId" TEXT,
    "customerId" TEXT NOT NULL,
    "financialYear" TEXT DEFAULT '2025-26',
    "invoiceDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dueDate" TIMESTAMP(3),
    "poNumber" TEXT,
    "ewayBillNumber" TEXT,
    "irnNumber" TEXT,
    "subtotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discountAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxableAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "cgstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "sgstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "igstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "grandTotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "paidAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "balanceDue" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "paymentStatus" TEXT NOT NULL DEFAULT 'UNPAID',
    "status" TEXT NOT NULL DEFAULT 'ISSUED',
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sales_invoices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_invoice_items" (
    "id" TEXT NOT NULL,
    "salesInvoiceId" TEXT NOT NULL,
    "productId" TEXT,
    "itemCode" TEXT,
    "description" TEXT NOT NULL,
    "hsnSac" TEXT DEFAULT '8537',
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unit" TEXT NOT NULL DEFAULT 'Nos',
    "unitPrice" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxableAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "gstPercent" DOUBLE PRECISION NOT NULL DEFAULT 18.0,
    "gstAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,

    CONSTRAINT "sales_invoice_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_payments" (
    "id" TEXT NOT NULL,
    "receiptNumber" TEXT NOT NULL,
    "salesInvoiceId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "paymentDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "amount" DOUBLE PRECISION NOT NULL,
    "paymentMode" TEXT NOT NULL,
    "referenceNumber" TEXT,
    "bankName" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sales_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "warehouses" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "location" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "warehouses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_items" (
    "id" TEXT NOT NULL,
    "warehouseId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "currentQuantity" INTEGER NOT NULL DEFAULT 0,
    "reservedQuantity" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "stock_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_contacts" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "contactPerson" TEXT NOT NULL,
    "designation" TEXT,
    "mobile" TEXT NOT NULL,
    "alternateMobile" TEXT,
    "email" TEXT,
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vendor_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_addresses" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "addressType" TEXT NOT NULL DEFAULT 'BILLING',
    "addressLine" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'India',
    "state" TEXT NOT NULL,
    "district" TEXT,
    "city" TEXT NOT NULL,
    "location" TEXT,
    "pincode" TEXT NOT NULL,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vendor_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_bank_accounts" (
    "id" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "accountHolder" TEXT NOT NULL,
    "bankName" TEXT NOT NULL,
    "accountNumber" TEXT NOT NULL,
    "ifscCode" TEXT NOT NULL,
    "branch" TEXT,
    "accountType" TEXT NOT NULL DEFAULT 'CURRENT',
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vendor_bank_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_requisitions" (
    "id" TEXT NOT NULL,
    "prNumber" TEXT NOT NULL,
    "requesterId" TEXT,
    "requesterName" TEXT NOT NULL,
    "departmentId" TEXT,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "requiredDate" TIMESTAMP(3),
    "priority" TEXT NOT NULL DEFAULT 'MEDIUM',
    "purpose" TEXT,
    "estimatedCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'SUBMITTED',
    "approvedBy" TEXT,
    "approvalDate" TIMESTAMP(3),
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "purchase_requisitions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_requisition_items" (
    "id" TEXT NOT NULL,
    "prId" TEXT NOT NULL,
    "productId" TEXT,
    "itemDescription" TEXT NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "estimatedRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "estimatedAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,

    CONSTRAINT "purchase_requisition_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rfqs" (
    "id" TEXT NOT NULL,
    "rfqNumber" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "departmentId" TEXT,
    "requesterName" TEXT NOT NULL,
    "requiredDate" TIMESTAMP(3),
    "closingDate" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "rfqs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rfq_items" (
    "id" TEXT NOT NULL,
    "rfqId" TEXT NOT NULL,
    "productId" TEXT,
    "itemDescription" TEXT NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,

    CONSTRAINT "rfq_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rfq_vendors" (
    "id" TEXT NOT NULL,
    "rfqId" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'INVITED',

    CONSTRAINT "rfq_vendors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_quotations" (
    "id" TEXT NOT NULL,
    "quotationNumber" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "rfqId" TEXT,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "validityDate" TIMESTAMP(3),
    "deliveryTime" TEXT,
    "paymentTerms" TEXT,
    "subtotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "isSelected" BOOLEAN NOT NULL DEFAULT false,
    "selectionReason" TEXT,
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vendor_quotations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_quotation_items" (
    "id" TEXT NOT NULL,
    "quotationId" TEXT NOT NULL,
    "productId" TEXT,
    "itemDescription" TEXT NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "rate" DOUBLE PRECISION NOT NULL,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "vendor_quotation_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_orders" (
    "id" TEXT NOT NULL,
    "poNumber" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "rfqId" TEXT,
    "quotationId" TEXT,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expectedDelivery" TIMESTAMP(3),
    "departmentId" TEXT,
    "warehouseId" TEXT,
    "paymentTerms" TEXT,
    "subtotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "approvedBy" TEXT,
    "approvalDate" TIMESTAMP(3),
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "purchase_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_order_items" (
    "id" TEXT NOT NULL,
    "poId" TEXT NOT NULL,
    "productId" TEXT,
    "itemDescription" TEXT NOT NULL,
    "orderedQuantity" DOUBLE PRECISION NOT NULL,
    "receivedQuantity" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "unit" TEXT NOT NULL,
    "rate" DOUBLE PRECISION NOT NULL,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "purchase_order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inward_entries" (
    "id" TEXT NOT NULL,
    "inwardNumber" TEXT NOT NULL,
    "inwardDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "vendorId" TEXT NOT NULL,
    "purchaseOrderId" TEXT,
    "vendorInvoiceNumber" TEXT NOT NULL,
    "invoiceDate" TIMESTAMP(3),
    "departmentId" TEXT,
    "warehouseId" TEXT,
    "receivedBy" TEXT NOT NULL,
    "transporter" TEXT,
    "vehicleNumber" TEXT,
    "lrNumber" TEXT,
    "deliveryChallanNumber" TEXT,
    "subtotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "grandTotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "remarks" TEXT,
    "attachmentUrl" TEXT,
    "status" TEXT NOT NULL DEFAULT 'RECEIVED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "inward_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inward_entry_items" (
    "id" TEXT NOT NULL,
    "inwardEntryId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "poItemId" TEXT,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "rate" DOUBLE PRECISION NOT NULL,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "amount" DOUBLE PRECISION NOT NULL,
    "batchNumber" TEXT,
    "serialNumber" TEXT,
    "expiryDate" TIMESTAMP(3),
    "qcRequired" BOOLEAN NOT NULL DEFAULT true,
    "qcStatus" TEXT NOT NULL DEFAULT 'PENDING',
    "acceptedQuantity" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "rejectedQuantity" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "rejectionReason" TEXT,
    "inspectedBy" TEXT,
    "inspectionDate" TIMESTAMP(3),
    "stockUpdated" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "inward_entry_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_transactions" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "warehouseId" TEXT NOT NULL,
    "transactionType" TEXT NOT NULL,
    "referenceType" TEXT NOT NULL,
    "referenceId" TEXT,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "unitCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "batchNumber" TEXT,
    "serialNumber" TEXT,
    "transactionDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userId" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stock_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_invoices" (
    "id" TEXT NOT NULL,
    "invoiceNumber" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "purchaseOrderId" TEXT,
    "inwardEntryId" TEXT,
    "departmentId" TEXT,
    "financialYear" TEXT,
    "invoiceDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dueDate" TIMESTAMP(3),
    "subtotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "paidAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "balanceAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'UNPAID',
    "attachmentUrl" TEXT,
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "purchase_invoices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_invoice_items" (
    "id" TEXT NOT NULL,
    "invoiceId" TEXT NOT NULL,
    "productId" TEXT,
    "itemDescription" TEXT NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "rate" DOUBLE PRECISION NOT NULL,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "amount" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "purchase_invoice_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_payments" (
    "id" TEXT NOT NULL,
    "paymentNumber" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "purchaseInvoiceId" TEXT NOT NULL,
    "paymentDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "amount" DOUBLE PRECISION NOT NULL,
    "paymentMode" TEXT NOT NULL,
    "bankAccount" TEXT,
    "referenceNumber" TEXT,
    "transactionNumber" TEXT,
    "remarks" TEXT,
    "attachmentUrl" TEXT,
    "status" TEXT NOT NULL DEFAULT 'COMPLETED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "purchase_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cheques" (
    "id" TEXT NOT NULL,
    "chequeNumber" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "purchaseInvoiceId" TEXT,
    "purchasePaymentId" TEXT NOT NULL,
    "chequeDate" TIMESTAMP(3) NOT NULL,
    "bankName" TEXT NOT NULL,
    "branch" TEXT,
    "amount" DOUBLE PRECISION NOT NULL,
    "payeeName" TEXT NOT NULL,
    "depositDate" TIMESTAMP(3),
    "clearanceDate" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'ISSUED',
    "remarks" TEXT,
    "bounceReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "cheques_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outward_documents" (
    "id" TEXT NOT NULL,
    "outwardNumber" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "outwardType" TEXT NOT NULL,
    "departmentId" TEXT,
    "fromLocation" TEXT NOT NULL,
    "toLocation" TEXT NOT NULL,
    "partyType" TEXT,
    "partyId" TEXT,
    "partyName" TEXT,
    "personName" TEXT,
    "purpose" TEXT,
    "referenceNumber" TEXT,
    "documentNumber" TEXT,
    "vehicleNumber" TEXT,
    "status" TEXT NOT NULL DEFAULT 'DISPATCHED',
    "remarks" TEXT,
    "attachmentUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "outward_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outward_document_items" (
    "id" TEXT NOT NULL,
    "outwardId" TEXT NOT NULL,
    "productId" TEXT,
    "materialName" TEXT NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "remarks" TEXT,

    CONSTRAINT "outward_document_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_returns" (
    "id" TEXT NOT NULL,
    "returnNumber" TEXT NOT NULL,
    "vendorId" TEXT NOT NULL,
    "inwardEntryId" TEXT,
    "purchaseInvoiceId" TEXT,
    "returnDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reason" TEXT NOT NULL,
    "subtotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "grandTotal" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "remarks" TEXT,
    "status" TEXT NOT NULL DEFAULT 'RETURNED',
    "attachmentUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "purchase_returns_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_return_items" (
    "id" TEXT NOT NULL,
    "returnId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" TEXT NOT NULL,
    "rate" DOUBLE PRECISION NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "reason" TEXT,

    CONSTRAINT "purchase_return_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "document_items" (
    "id" TEXT NOT NULL,
    "documentCode" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "documentType" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "fileSize" INTEGER NOT NULL,
    "mimeType" TEXT NOT NULL,
    "storagePath" TEXT NOT NULL,
    "uploadedBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "document_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "module" TEXT NOT NULL,
    "entityId" TEXT,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "userEmail" TEXT,
    "action" TEXT NOT NULL,
    "module" TEXT NOT NULL,
    "entityType" TEXT,
    "entityId" TEXT,
    "details" TEXT,
    "ipAddress" TEXT,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff" (
    "id" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "mobile" TEXT,
    "profilePhoto" TEXT,
    "departmentId" TEXT NOT NULL,
    "designationId" TEXT NOT NULL,
    "reportingManagerId" TEXT,
    "userId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "joiningDate" TIMESTAMP(3),
    "location" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "staff_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "projects" (
    "id" TEXT NOT NULL,
    "projectNumber" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "customerId" TEXT,
    "projectType" TEXT NOT NULL DEFAULT 'Customer Project',
    "projectManagerStaffId" TEXT NOT NULL,
    "startDate" TIMESTAMP(3),
    "endDate" TIMESTAMP(3),
    "priority" TEXT NOT NULL DEFAULT 'MEDIUM',
    "budget" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'PLANNING',
    "health" TEXT NOT NULL DEFAULT 'ON_TRACK',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "projects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "project_members" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "projectRole" TEXT NOT NULL DEFAULT 'Team Member',
    "allocationPercent" INTEGER NOT NULL DEFAULT 100,
    "startDate" TIMESTAMP(3),
    "endDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "project_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "milestones" (
    "id" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "dueDate" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "milestones_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tasks" (
    "id" TEXT NOT NULL,
    "taskNumber" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "projectId" TEXT,
    "milestoneId" TEXT,
    "departmentId" TEXT,
    "teamId" TEXT,
    "assigneeStaffId" TEXT,
    "createdByStaffId" TEXT NOT NULL,
    "assignedByStaffId" TEXT,
    "priority" TEXT NOT NULL DEFAULT 'MEDIUM',
    "status" TEXT NOT NULL DEFAULT 'CREATED',
    "dueDate" TIMESTAMP(3),
    "estimatedHours" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "actualHours" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "progress" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "tasks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "teams" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "departmentId" TEXT,
    "leaderStaffId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "teams_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "team_departments" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "departmentId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "team_departments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "team_members" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'MEMBER',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "team_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "task_comments" (
    "id" TEXT NOT NULL,
    "taskId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "comment" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "task_comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "task_activities" (
    "id" TEXT NOT NULL,
    "taskId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "oldValue" TEXT,
    "newValue" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "task_activities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shift_masters" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "startTime" TEXT NOT NULL,
    "endTime" TEXT NOT NULL,
    "graceMinutes" INTEGER NOT NULL DEFAULT 15,
    "shiftAllowance" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "departmentName" TEXT DEFAULT 'Shopfloor & Plant',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shift_masters_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employees" (
    "id" TEXT NOT NULL,
    "employeeCode" TEXT NOT NULL,
    "userId" TEXT,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "designation" TEXT NOT NULL,
    "departmentId" TEXT,
    "employmentType" TEXT NOT NULL DEFAULT 'FULL_TIME',
    "workerCategory" TEXT NOT NULL DEFAULT 'SHOPFLOOR_TECH',
    "skillLevel" TEXT DEFAULT 'LEVEL_2_WIREMAN',
    "assignedBay" TEXT DEFAULT 'BAY_4_WIRING',
    "shiftCode" TEXT NOT NULL DEFAULT 'SHIFT_G',
    "electricalLicenseNo" TEXT,
    "contractorAgency" TEXT,
    "ppeKitIssued" BOOLEAN NOT NULL DEFAULT true,
    "lastSafetyTraining" TIMESTAMP(3),
    "joiningDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "salaryCtc" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "bankAccountNo" TEXT,
    "bankIfsc" TEXT,
    "panNo" TEXT,
    "aadhaarNo" TEXT,
    "emergencyPhone" TEXT,
    "bloodGroup" TEXT,
    "address" TEXT,
    "avatarUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "employees_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attendances" (
    "id" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "punchDate" TIMESTAMP(3) NOT NULL,
    "punchIn" TIMESTAMP(3),
    "punchOut" TIMESTAMP(3),
    "workHours" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'PRESENT',
    "shiftCode" TEXT NOT NULL DEFAULT 'SHIFT_G',
    "overtimeHours" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "overtimeApproved" BOOLEAN NOT NULL DEFAULT false,
    "assignedBay" TEXT,
    "ppeCompliant" BOOLEAN NOT NULL DEFAULT true,
    "checkInNote" TEXT,
    "checkOutNote" TEXT,
    "location" TEXT DEFAULT 'MIDC Industrial Unit',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "attendances_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "workstation_allocations" (
    "id" TEXT NOT NULL,
    "allocationDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "employeeId" TEXT NOT NULL,
    "bayCode" TEXT NOT NULL,
    "panelCode" TEXT,
    "shiftCode" TEXT NOT NULL DEFAULT 'SHIFT_G',
    "targetHours" DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    "actualHours" DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    "status" TEXT NOT NULL DEFAULT 'IN_PROGRESS',
    "supervisorNote" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "workstation_allocations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "leave_requests" (
    "id" TEXT NOT NULL,
    "leaveCode" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "leaveType" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "daysCount" DOUBLE PRECISION NOT NULL DEFAULT 1,
    "reason" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "approvedBy" TEXT,
    "decisionNote" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "leave_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payroll_records" (
    "id" TEXT NOT NULL,
    "slipNumber" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "month" TEXT NOT NULL,
    "year" INTEGER NOT NULL DEFAULT 2026,
    "monthNumber" INTEGER NOT NULL DEFAULT 10,
    "workingDays" INTEGER NOT NULL DEFAULT 26,
    "presentDays" DOUBLE PRECISION NOT NULL DEFAULT 26,
    "basicSalary" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "hraAllowance" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "specialAllowance" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "overtimeHours" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "overtimePay" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "shiftAllowance" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "productionIncentive" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "grossPay" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "pfDeduction" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxDeduction" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "esiDeduction" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalDeductions" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "netPay" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "paymentStatus" TEXT NOT NULL DEFAULT 'PAID',
    "paymentDate" TIMESTAMP(3),
    "paymentMode" TEXT NOT NULL DEFAULT 'NEFT/RTGS',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "payroll_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "safety_incidents" (
    "id" TEXT NOT NULL,
    "incidentCode" TEXT NOT NULL,
    "reportDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "incidentType" TEXT NOT NULL,
    "severity" TEXT NOT NULL DEFAULT 'LOW',
    "locationBay" TEXT NOT NULL,
    "employeeId" TEXT,
    "description" TEXT NOT NULL,
    "actionTaken" TEXT,
    "status" TEXT NOT NULL DEFAULT 'RESOLVED',
    "reportedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "safety_incidents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "users_status_idx" ON "users"("status");

-- CreateIndex
CREATE INDEX "users_departmentId_idx" ON "users"("departmentId");

-- CreateIndex
CREATE UNIQUE INDEX "roles_name_key" ON "roles"("name");

-- CreateIndex
CREATE UNIQUE INDEX "roles_code_key" ON "roles"("code");

-- CreateIndex
CREATE UNIQUE INDEX "permissions_module_action_key" ON "permissions"("module", "action");

-- CreateIndex
CREATE UNIQUE INDEX "departments_name_key" ON "departments"("name");

-- CreateIndex
CREATE UNIQUE INDEX "departments_code_key" ON "departments"("code");

-- CreateIndex
CREATE UNIQUE INDEX "departments_headStaffId_key" ON "departments"("headStaffId");

-- CreateIndex
CREATE UNIQUE INDEX "designations_name_key" ON "designations"("name");

-- CreateIndex
CREATE UNIQUE INDEX "designations_code_key" ON "designations"("code");

-- CreateIndex
CREATE UNIQUE INDEX "financial_years_name_key" ON "financial_years"("name");

-- CreateIndex
CREATE UNIQUE INDEX "payment_modes_name_key" ON "payment_modes"("name");

-- CreateIndex
CREATE UNIQUE INDEX "payment_modes_code_key" ON "payment_modes"("code");

-- CreateIndex
CREATE UNIQUE INDEX "customers_customerCode_key" ON "customers"("customerCode");

-- CreateIndex
CREATE INDEX "customers_status_idx" ON "customers"("status");

-- CreateIndex
CREATE INDEX "customers_assignedStaffId_idx" ON "customers"("assignedStaffId");

-- CreateIndex
CREATE INDEX "customers_customerType_idx" ON "customers"("customerType");

-- CreateIndex
CREATE UNIQUE INDEX "product_systems_code_key" ON "product_systems"("code");

-- CreateIndex
CREATE UNIQUE INDEX "company_product_interests_customerId_productSystemId_key" ON "company_product_interests"("customerId", "productSystemId");

-- CreateIndex
CREATE UNIQUE INDEX "customer_valuations_customerId_key" ON "customer_valuations"("customerId");

-- CreateIndex
CREATE UNIQUE INDEX "vendors_vendorCode_key" ON "vendors"("vendorCode");

-- CreateIndex
CREATE UNIQUE INDEX "product_categories_name_key" ON "product_categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "product_categories_code_key" ON "product_categories"("code");

-- CreateIndex
CREATE UNIQUE INDEX "units_name_key" ON "units"("name");

-- CreateIndex
CREATE UNIQUE INDEX "units_code_key" ON "units"("code");

-- CreateIndex
CREATE UNIQUE INDEX "products_sku_key" ON "products"("sku");

-- CreateIndex
CREATE UNIQUE INDEX "leads_leadNumber_key" ON "leads"("leadNumber");

-- CreateIndex
CREATE INDEX "leads_status_idx" ON "leads"("status");

-- CreateIndex
CREATE INDEX "leads_assignedStaffId_idx" ON "leads"("assignedStaffId");

-- CreateIndex
CREATE INDEX "leads_customerId_idx" ON "leads"("customerId");

-- CreateIndex
CREATE INDEX "leads_createdAt_idx" ON "leads"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "enquiries_enquiryNumber_key" ON "enquiries"("enquiryNumber");

-- CreateIndex
CREATE UNIQUE INDEX "opportunities_opportunityNumber_key" ON "opportunities"("opportunityNumber");

-- CreateIndex
CREATE INDEX "opportunities_stage_idx" ON "opportunities"("stage");

-- CreateIndex
CREATE INDEX "opportunities_customerId_idx" ON "opportunities"("customerId");

-- CreateIndex
CREATE INDEX "opportunities_assignedStaffId_idx" ON "opportunities"("assignedStaffId");

-- CreateIndex
CREATE INDEX "opportunities_createdAt_idx" ON "opportunities"("createdAt");

-- CreateIndex
CREATE INDEX "crm_activities_customerId_idx" ON "crm_activities"("customerId");

-- CreateIndex
CREATE INDEX "crm_activities_staffId_idx" ON "crm_activities"("staffId");

-- CreateIndex
CREATE INDEX "crm_activities_opportunityId_idx" ON "crm_activities"("opportunityId");

-- CreateIndex
CREATE INDEX "crm_activities_createdAt_idx" ON "crm_activities"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "crm_calls_activityId_key" ON "crm_calls"("activityId");

-- CreateIndex
CREATE UNIQUE INDEX "crm_meetings_activityId_key" ON "crm_meetings"("activityId");

-- CreateIndex
CREATE UNIQUE INDEX "crm_site_visits_activityId_key" ON "crm_site_visits"("activityId");

-- CreateIndex
CREATE INDEX "crm_follow_ups_assignedStaffId_idx" ON "crm_follow_ups"("assignedStaffId");

-- CreateIndex
CREATE INDEX "crm_follow_ups_status_idx" ON "crm_follow_ups"("status");

-- CreateIndex
CREATE INDEX "crm_follow_ups_scheduledDate_idx" ON "crm_follow_ups"("scheduledDate");

-- CreateIndex
CREATE UNIQUE INDEX "crm_follow_ups_customerId_followUpNumber_key" ON "crm_follow_ups"("customerId", "followUpNumber");

-- CreateIndex
CREATE UNIQUE INDEX "panel_specifications_panelCode_key" ON "panel_specifications"("panelCode");

-- CreateIndex
CREATE UNIQUE INDEX "quotations_code_key" ON "quotations"("code");

-- CreateIndex
CREATE INDEX "quotations_customerId_idx" ON "quotations"("customerId");

-- CreateIndex
CREATE INDEX "quotations_status_idx" ON "quotations"("status");

-- CreateIndex
CREATE INDEX "quotations_quotationNumber_idx" ON "quotations"("quotationNumber");

-- CreateIndex
CREATE INDEX "quotations_createdAt_idx" ON "quotations"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "sales_orders_orderNumber_key" ON "sales_orders"("orderNumber");

-- CreateIndex
CREATE INDEX "sales_orders_customerId_idx" ON "sales_orders"("customerId");

-- CreateIndex
CREATE INDEX "sales_orders_status_idx" ON "sales_orders"("status");

-- CreateIndex
CREATE INDEX "sales_orders_productionStatus_idx" ON "sales_orders"("productionStatus");

-- CreateIndex
CREATE INDEX "sales_orders_createdAt_idx" ON "sales_orders"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "sales_invoices_invoiceNumber_key" ON "sales_invoices"("invoiceNumber");

-- CreateIndex
CREATE INDEX "sales_invoices_customerId_idx" ON "sales_invoices"("customerId");

-- CreateIndex
CREATE INDEX "sales_invoices_paymentStatus_idx" ON "sales_invoices"("paymentStatus");

-- CreateIndex
CREATE INDEX "sales_invoices_dueDate_idx" ON "sales_invoices"("dueDate");

-- CreateIndex
CREATE INDEX "sales_invoices_createdAt_idx" ON "sales_invoices"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "sales_payments_receiptNumber_key" ON "sales_payments"("receiptNumber");

-- CreateIndex
CREATE UNIQUE INDEX "warehouses_code_key" ON "warehouses"("code");

-- CreateIndex
CREATE UNIQUE INDEX "stock_items_warehouseId_productId_key" ON "stock_items"("warehouseId", "productId");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_requisitions_prNumber_key" ON "purchase_requisitions"("prNumber");

-- CreateIndex
CREATE UNIQUE INDEX "rfqs_rfqNumber_key" ON "rfqs"("rfqNumber");

-- CreateIndex
CREATE UNIQUE INDEX "rfq_vendors_rfqId_vendorId_key" ON "rfq_vendors"("rfqId", "vendorId");

-- CreateIndex
CREATE UNIQUE INDEX "vendor_quotations_quotationNumber_key" ON "vendor_quotations"("quotationNumber");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_orders_poNumber_key" ON "purchase_orders"("poNumber");

-- CreateIndex
CREATE INDEX "purchase_orders_vendorId_idx" ON "purchase_orders"("vendorId");

-- CreateIndex
CREATE INDEX "purchase_orders_status_idx" ON "purchase_orders"("status");

-- CreateIndex
CREATE INDEX "purchase_orders_createdAt_idx" ON "purchase_orders"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "inward_entries_inwardNumber_key" ON "inward_entries"("inwardNumber");

-- CreateIndex
CREATE INDEX "inward_entries_vendorId_idx" ON "inward_entries"("vendorId");

-- CreateIndex
CREATE INDEX "inward_entries_purchaseOrderId_idx" ON "inward_entries"("purchaseOrderId");

-- CreateIndex
CREATE INDEX "inward_entries_status_idx" ON "inward_entries"("status");

-- CreateIndex
CREATE INDEX "stock_transactions_productId_idx" ON "stock_transactions"("productId");

-- CreateIndex
CREATE INDEX "stock_transactions_warehouseId_idx" ON "stock_transactions"("warehouseId");

-- CreateIndex
CREATE INDEX "stock_transactions_transactionDate_idx" ON "stock_transactions"("transactionDate");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_invoices_invoiceNumber_key" ON "purchase_invoices"("invoiceNumber");

-- CreateIndex
CREATE INDEX "purchase_invoices_vendorId_idx" ON "purchase_invoices"("vendorId");

-- CreateIndex
CREATE INDEX "purchase_invoices_status_idx" ON "purchase_invoices"("status");

-- CreateIndex
CREATE INDEX "purchase_invoices_dueDate_idx" ON "purchase_invoices"("dueDate");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_payments_paymentNumber_key" ON "purchase_payments"("paymentNumber");

-- CreateIndex
CREATE UNIQUE INDEX "outward_documents_outwardNumber_key" ON "outward_documents"("outwardNumber");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_returns_returnNumber_key" ON "purchase_returns"("returnNumber");

-- CreateIndex
CREATE UNIQUE INDEX "document_items_documentCode_key" ON "document_items"("documentCode");

-- CreateIndex
CREATE INDEX "notifications_userId_idx" ON "notifications"("userId");

-- CreateIndex
CREATE INDEX "notifications_isRead_idx" ON "notifications"("isRead");

-- CreateIndex
CREATE INDEX "notifications_createdAt_idx" ON "notifications"("createdAt");

-- CreateIndex
CREATE INDEX "audit_logs_userId_idx" ON "audit_logs"("userId");

-- CreateIndex
CREATE INDEX "audit_logs_module_idx" ON "audit_logs"("module");

-- CreateIndex
CREATE INDEX "audit_logs_timestamp_idx" ON "audit_logs"("timestamp");

-- CreateIndex
CREATE UNIQUE INDEX "staff_employeeId_key" ON "staff"("employeeId");

-- CreateIndex
CREATE UNIQUE INDEX "staff_email_key" ON "staff"("email");

-- CreateIndex
CREATE UNIQUE INDEX "staff_userId_key" ON "staff"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "projects_projectNumber_key" ON "projects"("projectNumber");

-- CreateIndex
CREATE UNIQUE INDEX "project_members_projectId_staffId_key" ON "project_members"("projectId", "staffId");

-- CreateIndex
CREATE UNIQUE INDEX "tasks_taskNumber_key" ON "tasks"("taskNumber");

-- CreateIndex
CREATE INDEX "tasks_assigneeStaffId_idx" ON "tasks"("assigneeStaffId");

-- CreateIndex
CREATE INDEX "tasks_status_idx" ON "tasks"("status");

-- CreateIndex
CREATE INDEX "tasks_projectId_idx" ON "tasks"("projectId");

-- CreateIndex
CREATE INDEX "tasks_teamId_idx" ON "tasks"("teamId");

-- CreateIndex
CREATE INDEX "tasks_dueDate_idx" ON "tasks"("dueDate");

-- CreateIndex
CREATE UNIQUE INDEX "teams_code_key" ON "teams"("code");

-- CreateIndex
CREATE UNIQUE INDEX "teams_name_key" ON "teams"("name");

-- CreateIndex
CREATE INDEX "team_departments_departmentId_idx" ON "team_departments"("departmentId");

-- CreateIndex
CREATE UNIQUE INDEX "team_departments_teamId_departmentId_key" ON "team_departments"("teamId", "departmentId");

-- CreateIndex
CREATE INDEX "team_members_staffId_idx" ON "team_members"("staffId");

-- CreateIndex
CREATE UNIQUE INDEX "team_members_teamId_staffId_key" ON "team_members"("teamId", "staffId");

-- CreateIndex
CREATE UNIQUE INDEX "shift_masters_code_key" ON "shift_masters"("code");

-- CreateIndex
CREATE UNIQUE INDEX "employees_employeeCode_key" ON "employees"("employeeCode");

-- CreateIndex
CREATE UNIQUE INDEX "employees_userId_key" ON "employees"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "employees_email_key" ON "employees"("email");

-- CreateIndex
CREATE INDEX "employees_status_idx" ON "employees"("status");

-- CreateIndex
CREATE INDEX "employees_departmentId_idx" ON "employees"("departmentId");

-- CreateIndex
CREATE INDEX "employees_workerCategory_idx" ON "employees"("workerCategory");

-- CreateIndex
CREATE INDEX "attendances_employeeId_idx" ON "attendances"("employeeId");

-- CreateIndex
CREATE INDEX "attendances_punchDate_idx" ON "attendances"("punchDate");

-- CreateIndex
CREATE INDEX "attendances_status_idx" ON "attendances"("status");

-- CreateIndex
CREATE UNIQUE INDEX "attendances_employeeId_punchDate_key" ON "attendances"("employeeId", "punchDate");

-- CreateIndex
CREATE UNIQUE INDEX "leave_requests_leaveCode_key" ON "leave_requests"("leaveCode");

-- CreateIndex
CREATE UNIQUE INDEX "payroll_records_slipNumber_key" ON "payroll_records"("slipNumber");

-- CreateIndex
CREATE UNIQUE INDEX "safety_incidents_incidentCode_key" ON "safety_incidents"("incidentCode");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_departmentId_fkey" FOREIGN KEY ("departmentId") REFERENCES "departments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_permissionId_fkey" FOREIGN KEY ("permissionId") REFERENCES "permissions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "departments" ADD CONSTRAINT "departments_headStaffId_fkey" FOREIGN KEY ("headStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_updatedByUserId_fkey" FOREIGN KEY ("updatedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_assignedStaffId_fkey" FOREIGN KEY ("assignedStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_salesManagerStaffId_fkey" FOREIGN KEY ("salesManagerStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "company_product_interests" ADD CONSTRAINT "company_product_interests_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "company_product_interests" ADD CONSTRAINT "company_product_interests_productSystemId_fkey" FOREIGN KEY ("productSystemId") REFERENCES "product_systems"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "company_valuation_history" ADD CONSTRAINT "company_valuation_history_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_contacts" ADD CONSTRAINT "customer_contacts_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_interactions" ADD CONSTRAINT "customer_interactions_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_interactions" ADD CONSTRAINT "customer_interactions_contactId_fkey" FOREIGN KEY ("contactId") REFERENCES "customer_contacts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_valuations" ADD CONSTRAINT "customer_valuations_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendors" ADD CONSTRAINT "vendors_assignedStaffId_fkey" FOREIGN KEY ("assignedStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendors" ADD CONSTRAINT "vendors_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendors" ADD CONSTRAINT "vendors_updatedByUserId_fkey" FOREIGN KEY ("updatedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "product_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_unitId_fkey" FOREIGN KEY ("unitId") REFERENCES "units"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_taxRateId_fkey" FOREIGN KEY ("taxRateId") REFERENCES "tax_rates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leads" ADD CONSTRAINT "leads_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leads" ADD CONSTRAINT "leads_assignedStaffId_fkey" FOREIGN KEY ("assignedStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leads" ADD CONSTRAINT "leads_salesManagerStaffId_fkey" FOREIGN KEY ("salesManagerStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "enquiries" ADD CONSTRAINT "enquiries_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "enquiries" ADD CONSTRAINT "enquiries_assignedStaffId_fkey" FOREIGN KEY ("assignedStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunities" ADD CONSTRAINT "opportunities_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunities" ADD CONSTRAINT "opportunities_assignedStaffId_fkey" FOREIGN KEY ("assignedStaffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunities" ADD CONSTRAINT "opportunities_salesManagerStaffId_fkey" FOREIGN KEY ("salesManagerStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunities" ADD CONSTRAINT "opportunities_leadId_fkey" FOREIGN KEY ("leadId") REFERENCES "leads"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunities" ADD CONSTRAINT "opportunities_enquiryId_fkey" FOREIGN KEY ("enquiryId") REFERENCES "enquiries"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_activities" ADD CONSTRAINT "crm_activities_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_activities" ADD CONSTRAINT "crm_activities_contactId_fkey" FOREIGN KEY ("contactId") REFERENCES "customer_contacts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_activities" ADD CONSTRAINT "crm_activities_leadId_fkey" FOREIGN KEY ("leadId") REFERENCES "leads"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_activities" ADD CONSTRAINT "crm_activities_opportunityId_fkey" FOREIGN KEY ("opportunityId") REFERENCES "opportunities"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_activities" ADD CONSTRAINT "crm_activities_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_calls" ADD CONSTRAINT "crm_calls_activityId_fkey" FOREIGN KEY ("activityId") REFERENCES "crm_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_calls" ADD CONSTRAINT "crm_calls_contactId_fkey" FOREIGN KEY ("contactId") REFERENCES "customer_contacts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "call_recordings" ADD CONSTRAINT "call_recordings_callId_fkey" FOREIGN KEY ("callId") REFERENCES "crm_calls"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_meetings" ADD CONSTRAINT "crm_meetings_activityId_fkey" FOREIGN KEY ("activityId") REFERENCES "crm_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_meetings" ADD CONSTRAINT "crm_meetings_hostStaffId_fkey" FOREIGN KEY ("hostStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "meeting_schedule_history" ADD CONSTRAINT "meeting_schedule_history_meetingId_fkey" FOREIGN KEY ("meetingId") REFERENCES "crm_meetings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_site_visits" ADD CONSTRAINT "crm_site_visits_activityId_fkey" FOREIGN KEY ("activityId") REFERENCES "crm_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_follow_ups" ADD CONSTRAINT "crm_follow_ups_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_follow_ups" ADD CONSTRAINT "crm_follow_ups_opportunityId_fkey" FOREIGN KEY ("opportunityId") REFERENCES "opportunities"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_follow_ups" ADD CONSTRAINT "crm_follow_ups_assignedStaffId_fkey" FOREIGN KEY ("assignedStaffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_documents" ADD CONSTRAINT "customer_documents_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_documents" ADD CONSTRAINT "customer_documents_uploadedByStaffId_fkey" FOREIGN KEY ("uploadedByStaffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_media" ADD CONSTRAINT "customer_media_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_media" ADD CONSTRAINT "customer_media_uploadedByStaffId_fkey" FOREIGN KEY ("uploadedByStaffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "crm_saved_filters" ADD CONSTRAINT "crm_saved_filters_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "panel_specifications" ADD CONSTRAINT "panel_specifications_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "panel_bom_items" ADD CONSTRAINT "panel_bom_items_panelSpecId_fkey" FOREIGN KEY ("panelSpecId") REFERENCES "panel_specifications"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "panel_bom_items" ADD CONSTRAINT "panel_bom_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_opportunityId_fkey" FOREIGN KEY ("opportunityId") REFERENCES "opportunities"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_enquiryId_fkey" FOREIGN KEY ("enquiryId") REFERENCES "enquiries"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_panelSpecId_fkey" FOREIGN KEY ("panelSpecId") REFERENCES "panel_specifications"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_assignedStaffId_fkey" FOREIGN KEY ("assignedStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_approvedByStaffId_fkey" FOREIGN KEY ("approvedByStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quotation_items" ADD CONSTRAINT "quotation_items_quotationId_fkey" FOREIGN KEY ("quotationId") REFERENCES "quotations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quotation_items" ADD CONSTRAINT "quotation_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_quotationId_fkey" FOREIGN KEY ("quotationId") REFERENCES "quotations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_assignedStaffId_fkey" FOREIGN KEY ("assignedStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_order_items" ADD CONSTRAINT "sales_order_items_salesOrderId_fkey" FOREIGN KEY ("salesOrderId") REFERENCES "sales_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_order_items" ADD CONSTRAINT "sales_order_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_salesOrderId_fkey" FOREIGN KEY ("salesOrderId") REFERENCES "sales_orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_invoice_items" ADD CONSTRAINT "sales_invoice_items_salesInvoiceId_fkey" FOREIGN KEY ("salesInvoiceId") REFERENCES "sales_invoices"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_invoice_items" ADD CONSTRAINT "sales_invoice_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_payments" ADD CONSTRAINT "sales_payments_salesInvoiceId_fkey" FOREIGN KEY ("salesInvoiceId") REFERENCES "sales_invoices"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales_payments" ADD CONSTRAINT "sales_payments_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_items" ADD CONSTRAINT "stock_items_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "warehouses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_items" ADD CONSTRAINT "stock_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_contacts" ADD CONSTRAINT "vendor_contacts_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_addresses" ADD CONSTRAINT "vendor_addresses_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_bank_accounts" ADD CONSTRAINT "vendor_bank_accounts_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_requisition_items" ADD CONSTRAINT "purchase_requisition_items_prId_fkey" FOREIGN KEY ("prId") REFERENCES "purchase_requisitions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_requisition_items" ADD CONSTRAINT "purchase_requisition_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rfq_items" ADD CONSTRAINT "rfq_items_rfqId_fkey" FOREIGN KEY ("rfqId") REFERENCES "rfqs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rfq_items" ADD CONSTRAINT "rfq_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rfq_vendors" ADD CONSTRAINT "rfq_vendors_rfqId_fkey" FOREIGN KEY ("rfqId") REFERENCES "rfqs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rfq_vendors" ADD CONSTRAINT "rfq_vendors_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_quotations" ADD CONSTRAINT "vendor_quotations_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_quotations" ADD CONSTRAINT "vendor_quotations_rfqId_fkey" FOREIGN KEY ("rfqId") REFERENCES "rfqs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_quotation_items" ADD CONSTRAINT "vendor_quotation_items_quotationId_fkey" FOREIGN KEY ("quotationId") REFERENCES "vendor_quotations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_quotation_items" ADD CONSTRAINT "vendor_quotation_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_poId_fkey" FOREIGN KEY ("poId") REFERENCES "purchase_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inward_entries" ADD CONSTRAINT "inward_entries_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inward_entries" ADD CONSTRAINT "inward_entries_purchaseOrderId_fkey" FOREIGN KEY ("purchaseOrderId") REFERENCES "purchase_orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inward_entries" ADD CONSTRAINT "inward_entries_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "warehouses"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inward_entry_items" ADD CONSTRAINT "inward_entry_items_inwardEntryId_fkey" FOREIGN KEY ("inwardEntryId") REFERENCES "inward_entries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inward_entry_items" ADD CONSTRAINT "inward_entry_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_transactions" ADD CONSTRAINT "stock_transactions_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_transactions" ADD CONSTRAINT "stock_transactions_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "warehouses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_invoices" ADD CONSTRAINT "purchase_invoices_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_invoices" ADD CONSTRAINT "purchase_invoices_purchaseOrderId_fkey" FOREIGN KEY ("purchaseOrderId") REFERENCES "purchase_orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_invoices" ADD CONSTRAINT "purchase_invoices_inwardEntryId_fkey" FOREIGN KEY ("inwardEntryId") REFERENCES "inward_entries"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_invoice_items" ADD CONSTRAINT "purchase_invoice_items_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "purchase_invoices"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_payments" ADD CONSTRAINT "purchase_payments_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_payments" ADD CONSTRAINT "purchase_payments_purchaseInvoiceId_fkey" FOREIGN KEY ("purchaseInvoiceId") REFERENCES "purchase_invoices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cheques" ADD CONSTRAINT "cheques_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cheques" ADD CONSTRAINT "cheques_purchaseInvoiceId_fkey" FOREIGN KEY ("purchaseInvoiceId") REFERENCES "purchase_invoices"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cheques" ADD CONSTRAINT "cheques_purchasePaymentId_fkey" FOREIGN KEY ("purchasePaymentId") REFERENCES "purchase_payments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "outward_document_items" ADD CONSTRAINT "outward_document_items_outwardId_fkey" FOREIGN KEY ("outwardId") REFERENCES "outward_documents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_returns" ADD CONSTRAINT "purchase_returns_vendorId_fkey" FOREIGN KEY ("vendorId") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_returns" ADD CONSTRAINT "purchase_returns_inwardEntryId_fkey" FOREIGN KEY ("inwardEntryId") REFERENCES "inward_entries"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_returns" ADD CONSTRAINT "purchase_returns_purchaseInvoiceId_fkey" FOREIGN KEY ("purchaseInvoiceId") REFERENCES "purchase_invoices"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_return_items" ADD CONSTRAINT "purchase_return_items_returnId_fkey" FOREIGN KEY ("returnId") REFERENCES "purchase_returns"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_return_items" ADD CONSTRAINT "purchase_return_items_productId_fkey" FOREIGN KEY ("productId") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff" ADD CONSTRAINT "staff_departmentId_fkey" FOREIGN KEY ("departmentId") REFERENCES "departments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff" ADD CONSTRAINT "staff_designationId_fkey" FOREIGN KEY ("designationId") REFERENCES "designations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff" ADD CONSTRAINT "staff_reportingManagerId_fkey" FOREIGN KEY ("reportingManagerId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff" ADD CONSTRAINT "staff_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "projects" ADD CONSTRAINT "projects_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "projects" ADD CONSTRAINT "projects_projectManagerStaffId_fkey" FOREIGN KEY ("projectManagerStaffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "project_members" ADD CONSTRAINT "project_members_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "project_members" ADD CONSTRAINT "project_members_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "milestones" ADD CONSTRAINT "milestones_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "projects"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_milestoneId_fkey" FOREIGN KEY ("milestoneId") REFERENCES "milestones"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_departmentId_fkey" FOREIGN KEY ("departmentId") REFERENCES "departments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "teams"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_assigneeStaffId_fkey" FOREIGN KEY ("assigneeStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_createdByStaffId_fkey" FOREIGN KEY ("createdByStaffId") REFERENCES "staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_assignedByStaffId_fkey" FOREIGN KEY ("assignedByStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "teams" ADD CONSTRAINT "teams_departmentId_fkey" FOREIGN KEY ("departmentId") REFERENCES "departments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "teams" ADD CONSTRAINT "teams_leaderStaffId_fkey" FOREIGN KEY ("leaderStaffId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "team_departments" ADD CONSTRAINT "team_departments_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "team_departments" ADD CONSTRAINT "team_departments_departmentId_fkey" FOREIGN KEY ("departmentId") REFERENCES "departments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "team_members" ADD CONSTRAINT "team_members_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "team_members" ADD CONSTRAINT "team_members_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_comments" ADD CONSTRAINT "task_comments_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_comments" ADD CONSTRAINT "task_comments_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_activities" ADD CONSTRAINT "task_activities_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_activities" ADD CONSTRAINT "task_activities_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employees" ADD CONSTRAINT "employees_departmentId_fkey" FOREIGN KEY ("departmentId") REFERENCES "departments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendances" ADD CONSTRAINT "attendances_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workstation_allocations" ADD CONSTRAINT "workstation_allocations_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leave_requests" ADD CONSTRAINT "leave_requests_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payroll_records" ADD CONSTRAINT "payroll_records_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;
