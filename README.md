# Saark Exploration ERP System

## Project Overview
Integrated Company Management / ERP System for Saark Exploration Private Limited.

## Architecture
- **Frontend:** Flutter (Mobile, Web, Desktop)
- **Backend:** NestJS (Node.js)
- **Database:** SQLite (Current) -> PostgreSQL (Future)
- **File Storage:** Local Filesystem (Current) -> AWS S3 (Future)

## Technology Stack
- Flutter, Dart, Riverpod, GoRouter, Dio
- NestJS, TypeScript, Prisma ORM
- Docker

## Prerequisites
- Node.js (v18+)
- Flutter SDK (v3+)
- SQLite

## Installation
1. Clone the repository.
2. Install Backend dependencies: `cd apps/backend && npm install`
3. Install Frontend dependencies: `cd apps/mobile && flutter pub get`

## Environment Variables
Create `.env` based on `.env.example`.
```env
DATABASE_URL="file:./dev.db"
STORAGE_PROVIDER="local"
JWT_SECRET="your_secret_key"
```

## Database Setup
```bash
cd apps/backend
npm run prisma:migrate
npm run seed
```

## Running Backend
```bash
npm run start:dev
```

## Running Flutter
```bash
cd apps/mobile
flutter run -d chrome  # Web
flutter run -d android # Android
```

## Testing
- Refer to `docs/11_TESTING_STRATEGY.md`

## Default Logins & Test Credentials
- Refer to [`docs/SYSTEM_LOGINS_AND_CREDENTIALS.md`](docs/SYSTEM_LOGINS_AND_CREDENTIALS.md) for all accounts, passwords, and role permissions.
- Default password for all seed accounts: `Saark@2026`

## Folder Structure
- `apps/mobile`: Flutter application
- `apps/backend`: NestJS backend
- `docs/`: Architecture and requirement documentation
- `storage/`: Local file storage (gitignored)

## Deployment
- Refer to `docs/10_DEPLOYMENT_GUIDE.md`
