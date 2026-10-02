# File Storage Architecture

## Abstraction Layer

The system uses an abstract `FileStorageService` to handle all file operations. This ensures that the frontend and the core business logic in the backend are completely decoupled from the actual storage provider.

### Interfaces

```typescript
export interface IFileStorageService {
  uploadFile(file: Express.Multer.File, path: string): Promise<string>;
  downloadFile(path: string): Promise<Buffer>;
  deleteFile(path: string): Promise<boolean>;
  fileExists(path: string): Promise<boolean>;
  getSignedUrl(path: string): Promise<string>;
}
```

### Providers

1. **LocalFileStorageService (Current)**
   - Used for development and on-premise deployments.
   - Stores files in the local filesystem (e.g., `/storage/...`).
   - Uses `fs` and `path` modules in Node.js.

2. **S3FileStorageService (Future)**
   - Used for cloud deployments.
   - Stores files in AWS S3 or compatible Object Storage.
   - Configured via environment variables (`S3_BUCKET`, `S3_REGION`, etc.).

### Environment Configuration

The active provider is determined by the `STORAGE_PROVIDER` environment variable.

```env
STORAGE_PROVIDER=local
# STORAGE_PROVIDER=s3
```
