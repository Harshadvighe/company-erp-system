# 04. REST API Specification & Response Envelope Standard

## 1. Universal Standard API Envelope

All HTTP endpoints return responses formatted with standard structural metadata:

### Success Response:
```json
{
  "success": true,
  "message": "Customer created successfully",
  "data": {
    "id": "c7b3a190-8e12-421d-93f0-4561280911aa",
    "customerCode": "CUS-2026-00001",
    "companyName": "Apex Water Works Ltd",
    "gstin": "27AAACA1234A1Z5",
    "status": "ACTIVE"
  },
  "meta": {
    "timestamp": "2026-10-02T10:30:00.000Z",
    "requestId": "req_88192312"
  }
}
```

### Paginated List Response:
```json
{
  "success": true,
  "message": "Customers retrieved successfully",
  "data": [ ... ],
  "meta": {
    "page": 1,
    "limit": 25,
    "total": 142,
    "totalPages": 6
  }
}
```

### Error Response:
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    "gstin must be a valid GSTIN format",
    "email must be a valid email address"
  ],
  "meta": {
    "timestamp": "2026-10-02T10:30:00.000Z",
    "path": "/api/v1/customers"
  }
}
```

---

## 2. API Endpoints Map

### Auth & User Management
- `POST /api/v1/auth/login`: Authenticate user & return JWT + Refresh Token
- `POST /api/v1/auth/refresh`: Refresh JWT access token
- `GET /api/v1/auth/me`: Fetch current logged-in user profile & permissions
- `GET /api/v1/users`: List system users
- `GET /api/v1/roles`: List system roles & permissions

### Master Data
- `GET /api/v1/admin/company`: Fetch Saark Exploration company profile
- `GET /api/v1/admin/departments`: List departments
- `GET /api/v1/admin/financial-years`: List financial years
- `GET /api/v1/customers`: List customers (Search, Filter, Paginate)
- `POST /api/v1/customers`: Create customer
- `GET /api/v1/customers/:id`: Fetch customer details with contacts, timeline, valuation
- `PUT /api/v1/customers/:id`: Update customer details
- `POST /api/v1/customers/:id/interactions`: Record interaction (Call, Visit, Photo, Audio)
- `GET /api/v1/vendors`: List vendors
- `GET /api/v1/products`: List product catalog with SKU search

### CRM & Panel Manufacturing
- `GET /api/v1/crm/leads`: List leads (Kanban/List view)
- `POST /api/v1/crm/leads`: Create lead
- `GET /api/v1/crm/enquiries`: List enquiries
- `POST /api/v1/crm/enquiries`: Create enquiry
- `POST /api/v1/panel-manufacturing/specs`: Create panel specification & auto-calculate BOM
- `GET /api/v1/panel-manufacturing/specs/:id`: Fetch panel spec details

### Storage, Audit & Dashboard
- `POST /api/v1/documents/upload`: Upload file via abstracted `FileStorageService`
- `GET /api/v1/documents/:id/download`: Stream file or pre-signed S3 URL
- `GET /api/v1/notifications`: List user notifications
- `GET /api/v1/audit-logs`: List audit trail log records
- `GET /api/v1/dashboard/metrics`: Return role-based dashboard KPIs & recent activity
