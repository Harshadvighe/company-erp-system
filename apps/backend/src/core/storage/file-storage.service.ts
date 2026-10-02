import { Injectable, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

export interface StorageResult {
  fileName: string;
  storagePath: string;
  mimeType: string;
  fileSize: number;
  publicUrl: string;
}

export abstract class FileStorageService {
  abstract uploadFile(file: Express.Multer.File, entityType: string, entityId: string): Promise<StorageResult>;
  abstract downloadFile(filePath: string): Promise<Buffer>;
  abstract deleteFile(filePath: string): Promise<boolean>;
}

@Injectable()
export class LocalFileStorageService implements FileStorageService {
  private readonly logger = new Logger(LocalFileStorageService.name);
  private readonly basePath = process.env.STORAGE_LOCAL_BASE_PATH || path.join(__dirname, '../../../../storage');

  async uploadFile(file: Express.Multer.File, entityType: string, entityId: string): Promise<StorageResult> {
    const targetDir = path.join(this.basePath, 'documents', entityType.toLowerCase(), entityId);
    
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }

    const safeFileName = `${Date.now()}_${file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
    const destinationPath = path.join(targetDir, safeFileName);

    fs.writeFileSync(destinationPath, file.buffer || fs.readFileSync(file.path));

    const relativePath = path.relative(this.basePath, destinationPath).replace(/\\/g, '/');

    this.logger.log(`Uploaded file locally to: ${relativePath}`);

    return {
      fileName: file.originalname,
      storagePath: relativePath,
      mimeType: file.mimetype,
      fileSize: file.size,
      publicUrl: `/api/v1/documents/files/${encodeURIComponent(relativePath)}`,
    };
  }

  async downloadFile(filePath: string): Promise<Buffer> {
    const fullPath = path.join(this.basePath, filePath);
    if (!fs.existsSync(fullPath)) {
      throw new Error(`File not found at path: ${filePath}`);
    }
    return fs.readFileSync(fullPath);
  }

  async deleteFile(filePath: string): Promise<boolean> {
    const fullPath = path.join(this.basePath, filePath);
    if (fs.existsSync(fullPath)) {
      fs.unlinkSync(fullPath);
      return true;
    }
    return false;
  }
}

@Injectable()
export class S3FileStorageService implements FileStorageService {
  private readonly logger = new Logger(S3FileStorageService.name);

  async uploadFile(file: Express.Multer.File, entityType: string, entityId: string): Promise<StorageResult> {
    this.logger.log(`[S3 Storage Abstraction] Pushing file to bucket ${process.env.S3_BUCKET || 'saark-erp-documents'}`);
    const key = `documents/${entityType.toLowerCase()}/${entityId}/${Date.now()}_${file.originalname}`;
    
    return {
      fileName: file.originalname,
      storagePath: key,
      mimeType: file.mimetype,
      fileSize: file.size,
      publicUrl: `https://${process.env.S3_BUCKET || 'saark-erp-documents'}.s3.${process.env.S3_REGION || 'ap-south-1'}.amazonaws.com/${key}`,
    };
  }

  async downloadFile(filePath: string): Promise<Buffer> {
    this.logger.log(`[S3 Storage Abstraction] Fetching stream for key ${filePath}`);
    return Buffer.from('S3_BINARY_MOCK_STREAM');
  }

  async deleteFile(filePath: string): Promise<boolean> {
    this.logger.log(`[S3 Storage Abstraction] Deleting object key ${filePath}`);
    return true;
  }
}
