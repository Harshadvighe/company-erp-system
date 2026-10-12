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

### GSTIN Verification

Company forms verify GSTINs only when the user selects **Verify & Fetch**. The
backend uses the GSTIN Portal API; its API key must never be added to Flutter
configuration or sent to the client. Set these backend environment variables
from your deployment secret store:

- `GSTIN_API_KEY`: the GSTIN Portal API key. In local development, set it in
  `apps/backend/.env`.
- `GST_VERIFICATION_TOKEN_SECRET`: a private random secret of at least 32
  characters, used to sign short-lived proof that a GSTIN was provider-verified.

The integration follows the [GSTIN Portal API documentation](https://www.gstinapi.in/docs):
`GET https://www.gstinapi.in/v1/gstin/{gstin}` with the `x-api-key` header.
Provider responses are normalized by the backend. The company form fills only
empty fields, and the API persists verification metadata only when the matching
short-lived verification proof is submitted. Provider errors are handled
explicitly, and rate-limit or temporary gateway failures retry at most three
times with exponential backoff. The backend logs `credits_remaining` returned
by the provider without logging the key or GSTIN.
Run `npm run test:gst` from `apps/backend` to execute the mocked integration
checks without sending requests to the provider.

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

## Folder Structure
- `apps/mobile`: Flutter application
- `apps/backend`: NestJS backend
- `docs/`: Architecture and requirement documentation
- `storage/`: Local file storage (gitignored)

## Deployment
- Refer to `docs/10_DEPLOYMENT_GUIDE.md`
