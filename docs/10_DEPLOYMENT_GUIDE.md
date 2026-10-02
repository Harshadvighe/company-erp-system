# 10. Deployment & Infrastructure Guide

## 1. Local Development Setup
1. Prerequisites: Node.js >= 20.x, NPM >= 10.x, Flutter SDK >= 3.x
2. Clone repository & configure `.env`:
   ```bash
   cp .env.example .env
   ```
3. Initialize NestJS Backend:
   ```bash
   cd apps/backend
   npm install
   npx prisma migrate dev --name init
   npm run seed
   npm run start:dev
   ```
4. Initialize Flutter Web/Mobile Application:
   ```bash
   cd apps/mobile
   flutter pub get
   flutter run -d chrome
   ```

---

## 2. Docker Containerization
- **Backend Dockerfile**: Multistage Node 20 Alpine build generating optimized production bundle.
- **Docker Compose**: Orchestrates NestJS container, SQLite/Postgres persistence volume, and local file storage volume.

---

# 11. Testing Strategy Document

## 1. Automated Test Plan
- **Unit Testing (NestJS)**: Jest unit tests for domain services, authorization guards, and panel BOM calculator logic.
- **API Integration Testing (NestJS)**: Supertest E2E specs testing Auth login, Customer CRUD, CRM flow, and File Upload API endpoints.
- **Widget & State Tests (Flutter)**: Flutter test suite verifying Riverpod state providers, Login screen validation, and Customer detail navigation flows.
