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

@Injectable()
export class SupabaseFileStorageService implements FileStorageService {
  private readonly logger = new Logger(SupabaseFileStorageService.name);
  private readonly bucket: string;
  private readonly supabaseUrl: string;
  private readonly serviceRoleKey: string;
  private readonly requestTimeoutMs = 15000;

  constructor() {
    this.bucket = process.env.SUPABASE_STORAGE_BUCKET || 'saark-erp-documents';
    this.supabaseUrl = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
    this.serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

    if (!this.supabaseUrl || !this.serviceRoleKey) {
      this.logger.warn(
        'SupabaseFileStorageService initialized without SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Operations will fail if executed.',
      );
    }
  }

  private validateAndSanitizePath(rawPath: string): string {
    if (!rawPath || typeof rawPath !== 'string') {
      throw new Error('Invalid storage path provided');
    }
    const normalized = rawPath.replace(/\\/g, '/').replace(/^\/+/, '');
    if (normalized.includes('..')) {
      throw new Error('Path traversal sequence detected in storage path');
    }
    return normalized;
  }

  private getAuthHeaders(): Record<string, string> {
    if (!this.serviceRoleKey) {
      throw new Error('Supabase service key is not configured');
    }
    return {
      apikey: this.serviceRoleKey,
      Authorization: `Bearer ${this.serviceRoleKey}`,
    };
  }

  private executeHttpRequest(
    method: string,
    urlStr: string,
    headers: Record<string, string>,
    payload?: Buffer,
  ): Promise<{ statusCode: number; headers: any; body: Buffer }> {
    return new Promise((resolve, reject) => {
      const url = new URL(urlStr);
      const isHttps = url.protocol === 'https:';
      const client = isHttps ? require('https') : require('http');

      const req = client.request(
        url,
        {
          method,
          headers,
          timeout: this.requestTimeoutMs,
        },
        (res: any) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer) => chunks.push(chunk));
          res.on('end', () => {
            resolve({
              statusCode: res.statusCode || 500,
              headers: res.headers,
              body: Buffer.concat(chunks),
            });
          });
        },
      );

      req.on('timeout', () => {
        req.destroy(new Error(`Storage HTTP request timed out after ${this.requestTimeoutMs}ms`));
      });

      req.on('error', (err: any) => {
        reject(err);
      });

      if (payload && payload.length > 0) {
        req.write(payload);
      }
      req.end();
    });
  }

  async uploadFile(file: Express.Multer.File, entityType: string, entityId: string): Promise<StorageResult> {
    if (!this.supabaseUrl) {
      throw new Error('SUPABASE_URL is not configured');
    }

    const safeCleanName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    const safeEntity = entityType.toLowerCase().replace(/[^a-z0-9_-]/g, '_');
    const safeId = entityId.replace(/[^a-zA-Z0-9_-]/g, '_');
    const key = `documents/${safeEntity}/${safeId}/${Date.now()}_${safeCleanName}`;

    const normalizedKey = this.validateAndSanitizePath(key);
    const encodedKey = normalizedKey.split('/').map(encodeURIComponent).join('/');
    const uploadUrl = `${this.supabaseUrl}/storage/v1/object/${this.bucket}/${encodedKey}`;

    const fileBuffer = file.buffer || (file.path ? fs.readFileSync(file.path) : null);
    if (!fileBuffer) {
      throw new Error('File buffer is empty or missing');
    }

    const mimeType = file.mimetype || 'application/octet-stream';

    const headers: Record<string, string> = {
      ...this.getAuthHeaders(),
      'Content-Type': mimeType,
      'Content-Length': fileBuffer.length.toString(),
      'x-upsert': 'false', // Strictly prevent overwriting existing objects
    };

    const response = await this.executeHttpRequest('POST', uploadUrl, headers, fileBuffer);

    if (response.statusCode === 409 || response.statusCode === 400 && response.body.toString().includes('Duplicate')) {
      throw new Error(`Object key '${normalizedKey}' already exists in bucket '${this.bucket}'`);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      const errDetail = response.body.toString('utf8').slice(0, 200);
      throw new Error(`Failed to upload object to Supabase (HTTP ${response.statusCode}): ${errDetail}`);
    }

    this.logger.log(`Uploaded file to Supabase storage key: ${normalizedKey}`);

    const encodedPathForUrl = normalizedKey.split('/').map(encodeURIComponent).join('/');

    return {
      fileName: file.originalname,
      storagePath: normalizedKey,
      mimeType,
      fileSize: fileBuffer.length,
      publicUrl: `/api/v1/documents/files/${encodedPathForUrl}`,
    };
  }

  async downloadFile(filePath: string): Promise<Buffer> {
    if (!this.supabaseUrl) {
      throw new Error('SUPABASE_URL is not configured');
    }

    const normalizedKey = this.validateAndSanitizePath(filePath);
    const encodedKey = normalizedKey.split('/').map(encodeURIComponent).join('/');
    const downloadUrl = `${this.supabaseUrl}/storage/v1/object/authenticated/${this.bucket}/${encodedKey}`;

    const headers: Record<string, string> = {
      ...this.getAuthHeaders(),
    };

    const response = await this.executeHttpRequest('GET', downloadUrl, headers);

    if (response.statusCode === 404 || (response.statusCode === 400 && response.body.toString().includes('NoSuchKey'))) {
      throw new Error(`Object not found in Supabase storage: ${normalizedKey}`);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      const errDetail = response.body.toString('utf8').slice(0, 200);
      throw new Error(`Failed to download object from Supabase (HTTP ${response.statusCode}): ${errDetail}`);
    }

    return response.body;
  }

  async deleteFile(filePath: string): Promise<boolean> {
    if (!this.supabaseUrl) {
      throw new Error('SUPABASE_URL is not configured');
    }

    const normalizedKey = this.validateAndSanitizePath(filePath);
    const deleteUrl = `${this.supabaseUrl}/storage/v1/object/${this.bucket}`;

    const payload = Buffer.from(JSON.stringify({ prefixes: [normalizedKey] }), 'utf8');
    const headers: Record<string, string> = {
      ...this.getAuthHeaders(),
      'Content-Type': 'application/json',
      'Content-Length': payload.length.toString(),
    };

    const response = await this.executeHttpRequest('DELETE', deleteUrl, headers, payload);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      this.logger.warn(`Failed to delete object from Supabase (HTTP ${response.statusCode})`);
      return false;
    }

    return true;
  }
}
