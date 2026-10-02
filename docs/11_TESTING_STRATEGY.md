# Testing Strategy

## 1. Unit Testing
- **Backend:** Jest for testing NestJS services, utility functions, and business logic.
- **Frontend:** Flutter `flutter_test` for testing providers, utility classes, and simple widgets.

## 2. Integration Testing
- **Backend:** Supertest for testing API endpoints, database interactions, and authentication flows.
- **Frontend:** Flutter integration tests to verify critical user journeys (e.g., login, creating a lead).

## 3. Critical Workflows to Test
- Authentication (Login, Token Refresh, Logout, Role/Permission validation)
- Master Data Creation (Company, Customer, Vendor, Product)
- CRM Pipeline (Lead -> Enquiry -> Quotation)
- Offline Sync queue processing
- File Upload/Download abstraction
