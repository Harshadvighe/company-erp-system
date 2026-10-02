# 02. System Architecture Specification

## 1. High-Level Monorepo Architecture

```mermaid
graph TD
    subgraph Client Layer (Flutter Multi-Platform)
        FW[Flutter Web]
        FA[Flutter Android]
        FI[Flutter iOS]
    end

    subgraph API Gateway & Core Application (NestJS Backend)
        API[NestJS REST API Controllers]
        AUTH[JWT / RBAC Enforcer Guard]
        SERVICES[Domain Services Layer]
        PRISMA[Prisma ORM Abstraction]
        FSS[FileStorageService Abstraction]
    end

    subgraph Storage & Persistence Layer
        DB_L[(Current: SQLite Database)]
        DB_P[(Future: PostgreSQL Database)]
        FS_L[Current: Local File System Storage]
        FS_S3[Future: AWS S3 Bucket]
    end

    FW -->|HTTPS / Dio REST| API
    FA -->|HTTPS / Dio REST| API
    FI -->|HTTPS / Dio REST| API

    API --> AUTH
    AUTH --> SERVICES
    SERVICES --> PRISMA
    SERVICES --> FSS

    PRISMA -->|DATABASE_PROVIDER=sqlite| DB_L
    PRISMA -.->|DATABASE_PROVIDER=postgresql| DB_P

    FSS -->|STORAGE_PROVIDER=local| FS_L
    FSS -.->|STORAGE_PROVIDER=s3| FS_S3
```

---

## 2. Abstraction Strategy for Storage & Database

### Database Abstraction:
- Business services consume Prisma Client through a `PrismaService` wrapper.
- All schema models use standard ANSI SQL datatypes compatible with SQLite and PostgreSQL.
- Database switches are handled via `.env` setting `DATABASE_PROVIDER` and Prisma datasource provider configuration.

### File Storage Abstraction:
```typescript
export interface FileStorageService {
  uploadFile(file: Express.Multer.File, entityType: string, entityId: string): Promise<StorageResult>;
  downloadFile(filePath: string): Promise<Buffer>;
  deleteFile(filePath: string): Promise<boolean>;
  getFileUrl(filePath: string): Promise<string>;
}
```
- `LocalFileStorageService` writes files to local `/storage/{entity}/{entityId}/` directory.
- `S3FileStorageService` generates pre-signed upload/download URLs using AWS S3 SDK v3.
- Switching between local and S3 requires zero modification to NestJS controllers or Flutter frontend code.
