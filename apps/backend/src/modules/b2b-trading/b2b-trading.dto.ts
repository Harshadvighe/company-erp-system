import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsArray,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateB2bProductDto {
  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  id?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  prodId?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  primaryCategory?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  subCategory?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  internalTag?: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  originalName: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  originalModel: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  rebrandedName: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  rebrandedModel: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  collection?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  supplierId?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  moq?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  sampleCost?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  leadTime?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  rating?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  material?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  dimensions?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  weight?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  hsCode?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  logoPath?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  insertCardPath?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  pkgDims?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  printingSpecs?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  barcodePlacement?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  brandCopy?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  seoTitle?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  seoMeta?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  baseCost?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  brandingFee?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  sampleShipping?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  freightPerUnit?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  retailPrice?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  stock?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  status?: string;

  @ApiPropertyOptional()
  @IsArray()
  @IsOptional()
  variants?: Array<{
    sku: string;
    color?: string;
    size?: string;
    packageType?: string;
    baseCost?: number;
    retailPrice?: number;
  }>;

  @ApiPropertyOptional()
  @IsArray()
  @IsOptional()
  documents?: Array<{
    assetType: string;
    filePath: string;
    fileName?: string;
    description?: string;
  }>;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  skuCode?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  supplierName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  factoryLocation?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  supplierRating?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  leadTimeDays?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  portOfOrigin?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  logoPlacement?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  logoUrl?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  warrantyPeriodMonths?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  warrantyCardUrl?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  customsDutyPct?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  qualityInspectionPerUnit?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  landedCost?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  marginPct?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  minOrderQty?: number;

  @ApiPropertyOptional()
  @IsArray()
  @IsOptional()
  mediaIds?: string[];
}

export class UpdateB2bProductDto {
  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  id?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  prodId?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  primaryCategory?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  subCategory?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  internalTag?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  originalName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  originalModel?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  rebrandedName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  rebrandedModel?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  collection?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  supplierId?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  moq?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  sampleCost?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  leadTime?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  rating?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  material?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  dimensions?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  weight?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  hsCode?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  logoPath?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  insertCardPath?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  pkgDims?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  printingSpecs?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  barcodePlacement?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  brandCopy?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  seoTitle?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  seoMeta?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  baseCost?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  brandingFee?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  sampleShipping?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  freightPerUnit?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  retailPrice?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  stock?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  status?: string;

  @ApiPropertyOptional()
  @IsArray()
  @IsOptional()
  variants?: Array<{
    sku: string;
    color?: string;
    size?: string;
    packageType?: string;
    baseCost?: number;
    retailPrice?: number;
  }>;

  @ApiPropertyOptional()
  @IsArray()
  @IsOptional()
  documents?: Array<{
    assetType: string;
    filePath: string;
    fileName?: string;
    description?: string;
  }>;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  skuCode?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  supplierName?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  factoryLocation?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  supplierRating?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  leadTimeDays?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  portOfOrigin?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  logoPlacement?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  logoUrl?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  warrantyPeriodMonths?: number;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  warrantyCardUrl?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  customsDutyPct?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  qualityInspectionPerUnit?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  landedCost?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  marginPct?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  minOrderQty?: number;

  @ApiPropertyOptional()
  @IsArray()
  @IsOptional()
  mediaIds?: string[];
}

export class CalculateB2bFinancialsDto {
  @ApiProperty()
  @IsNumber()
  @IsNotEmpty()
  @Type(() => Number)
  baseCost: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  brandingFee?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  sampleShipping?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  freightPerUnit?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  retailPrice?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  packagingFee?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  customsDutyPct?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  qualityInspectionPerUnit?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  targetMarginPct?: number;

  // Optional Import Customs calculation
  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  exchangeRate?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  portChargesInr?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  bcdRate?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  swsRate?: number;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  igstRate?: number;
}
