# 03. Database Design & Entity Relationship Specification

## 1. Relational Schema Architecture

The ERP database follows strict enterprise normalization standards with universal audit metadata columns on primary entity tables:
- `id`: UUID v4 primary key
- `createdAt`: Timestamp ISO 8601
- `updatedAt`: Timestamp ISO 8601
- `createdBy`: Foreign Key (User ID)
- `status`: Entity state flag (`ACTIVE`, `INACTIVE`, `DRAFT`, `APPROVED`, etc.)

---

## 2. Core Entity Definitions

### 2.1 Auth & RBAC
- **users**: `id`, `username`, `email`, `passwordHash`, `fullName`, `designation`, `departmentId`, `status`, `createdAt`, `updatedAt`
- **roles**: `id`, `name`, `code`, `description`, `isSystem`
- **permissions**: `id`, `module`, `action` (e.g. `CUSTOMERS:VIEW`, `CUSTOMERS:CREATE`, `CUSTOMERS:APPROVE`)
- **user_roles**: `userId`, `roleId`
- **role_permissions**: `roleId`, `permissionId`

### 2.2 Master Data
- **companies**: `id`, `name`, `legalName`, `gstin`, `pan`, `cin`, `email`, `phone`, `website`, `address`, `city`, `state`, `pincode`, `logoUrl`
- **departments**: `id`, `name`, `code`, `headUserId`
- **financial_years**: `id`, `name` (e.g. `2026-27`), `startDate`, `endDate`, `isCurrent`
- **customers**: `id`, `customerCode`, `companyName`, `gstin`, `pan`, `customerType`, `customerCategory`, `contactPerson`, `email`, `phone`, `address`, `city`, `state`, `district`, `pincode`, `turnover`, `customerRating`, `status`
- **customer_contacts**: `id`, `customerId`, `name`, `designation`, `email`, `phone`, `mobile`, `isPrimary`
- **customer_interactions**: `id`, `customerId`, `contactId`, `interactionType` (CALL, MEETING, EMAIL, VISIT), `interactionDate`, `subject`, `description`, `outcome`, `nextFollowUpDate`, `attachmentUrl`, `recordedBy`
- **customer_valuations**: `id`, `customerId`, `vfdWorkScore`, `dewateringWorkScore`, `isDealer`, `isDistributor`, `ratingScore`, `valuablePercentage`
- **vendors**: `id`, `vendorCode`, `companyName`, `gstin`, `pan`, `email`, `phone`, `address`, `city`, `state`, `rating`
- **products**: `id`, `sku`, `name`, `category`, `productType` (FINISHED, RAW, SERVICE, COMPONENT), `unit`, `hsnSac`, `gstRate`, `purchasePrice`, `sellingPrice`, `reorderLevel`, `openingStock`

### 2.3 CRM & Sales Operations
- **leads**: `id`, `leadNumber`, `companyName`, `contactPerson`, `phone`, `email`, `source`, `productInterest`, `estimatedValue`, `assignedTo`, `status` (NEW, CONTACTED, QUALIFIED, PROPOSAL, NEGOTIATION, WON, LOST)
- **enquiries**: `id`, `enquiryNumber`, `customerId`, `contactId`, `enquiryDate`, `productInterest`, `quantity`, `expectedValue`, `assignedTo`, `status`
- **panel_specifications**: `id`, `panelCode`, `customerId`, `panelType` (VFD, BOOSTER, STP, HVAC, DEWATERING), `voltage`, `current`, `pumpQty`, `pumpHp`, `controlType`, `ipRating`, `materialCost`, `labourCost`, `overheadCost`, `marginPercent`, `finalPrice`
- **panel_bom_items**: `id`, `panelSpecId`, `productId`, `componentName`, `specification`, `manufacturer`, `quantity`, `unitPrice`, `totalPrice`

### 2.4 Inventory & Documents
- **warehouses**: `id`, `code`, `name`, `location`, `managerUserId`
- **stock_items**: `id`, `warehouseId`, `productId`, `currentQuantity`, `reservedQuantity`
- **documents**: `id`, `documentCode`, `entityType`, `entityId`, `documentType`, `fileName`, `fileSize`, `mimeType`, `storagePath`, `uploadedBy`
- **audit_logs**: `id`, `userId`, `action`, `module`, `entityType`, `entityId`, `oldValuesJson`, `newValuesJson`, `ipAddress`, `timestamp`
- **notifications**: `id`, `userId`, `title`, `message`, `module`, `entityId`, `isRead`, `createdAt`
