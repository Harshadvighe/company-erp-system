import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum ImportTarget {
  CUSTOMER = 'CUSTOMER',
  VENDOR = 'VENDOR',
}

export enum GstLookupStatus {
  VERIFIED = 'VERIFIED',
  INVALID = 'INVALID',
  LOOKUP_FAILED = 'LOOKUP_FAILED',
  NOT_APPLICABLE = 'NOT_APPLICABLE',
  PENDING = 'PENDING',
}

export enum RowValidationStatus {
  VALID = 'VALID',
  WARNING = 'WARNING',
  DUPLICATE_EXACT = 'DUPLICATE_EXACT',
  DUPLICATE_POSSIBLE = 'DUPLICATE_POSSIBLE',
  INVALID = 'INVALID',
}

export class ParseAndPreviewDto {
  @ApiProperty({ enum: ImportTarget, example: 'CUSTOMER' })
  @IsEnum(ImportTarget)
  @IsNotEmpty()
  target!: ImportTarget;

  @ApiPropertyOptional({ description: 'File name with extension (.xlsx or .csv)' })
  @IsString()
  @IsOptional()
  fileName?: string;

  @ApiPropertyOptional({ description: 'Base64-encoded file content if not using multipart upload' })
  @IsString()
  @IsOptional()
  fileBase64?: string;

  @ApiPropertyOptional({ description: 'Custom column mapping override: { "Header in Excel": "targetFieldName" }' })
  @IsOptional()
  columnMapping?: Record<string, string>;

  @ApiPropertyOptional({ description: 'Enable automatic GST Portal verification & enrichment', default: true })
  @IsBoolean()
  @IsOptional()
  enableGstEnrichment?: boolean = true;

  @ApiPropertyOptional({ description: 'Check database for duplicate GSTIN/names', default: true })
  @IsBoolean()
  @IsOptional()
  checkDuplicates?: boolean = true;
}

export class ImportRowItemDto {
  @ApiProperty({ description: 'Original Excel row number' })
  @IsInt()
  @Min(1)
  rowNumber!: number;

  @ApiPropertyOptional({ description: 'Mapped customer or vendor data fields' })
  @IsObject()
  @IsNotEmpty()
  data!: Record<string, any>;

  @ApiPropertyOptional({ description: 'Enriched data from GST portal' })
  @IsObject()
  @IsOptional()
  gstData?: Record<string, any>;

  @ApiPropertyOptional({ description: 'GST verification token from backend verification service' })
  @IsString()
  @IsOptional()
  gstVerificationToken?: string;

  @ApiPropertyOptional({ description: 'Whether this row is selected for import', default: true })
  @IsBoolean()
  @IsOptional()
  isIncluded?: boolean = true;
}

export class ExecuteImportDto {
  @ApiProperty({ enum: ImportTarget, example: 'CUSTOMER' })
  @IsEnum(ImportTarget)
  @IsNotEmpty()
  target!: ImportTarget;

  @ApiProperty({ description: 'List of validated rows to import', type: [ImportRowItemDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ImportRowItemDto)
  rows!: ImportRowItemDto[];

  @ApiPropertyOptional({ description: 'Skip rows flagged as duplicates', default: true })
  @IsBoolean()
  @IsOptional()
  skipDuplicates?: boolean = true;

  @ApiPropertyOptional({ description: 'Update existing database record if exact GSTIN match is found (requires admin permissions)', default: false })
  @IsBoolean()
  @IsOptional()
  updateExisting?: boolean = false;

  @ApiPropertyOptional({ description: 'File name or reference for audit trail' })
  @IsString()
  @IsOptional()
  fileName?: string;
}

export class GenerateErrorReportDto {
  @ApiProperty({ enum: ImportTarget, example: 'CUSTOMER' })
  @IsEnum(ImportTarget)
  @IsNotEmpty()
  target!: ImportTarget;

  @ApiProperty({ description: 'List of failed or warning rows' })
  @IsArray()
  errors!: Array<{
    rowNumber: number;
    companyName?: string;
    gstin?: string;
    code: string;
    message: string;
    recommendation?: string;
    rawData?: Record<string, any>;
  }>;
}
