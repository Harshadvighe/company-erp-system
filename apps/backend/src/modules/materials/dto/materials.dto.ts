import {
  IsOptional,
  IsString,
  IsNumber,
  IsInt,
  Min,
  IsIn,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class FindMaterialsQueryDto {
  @ApiPropertyOptional({ description: 'Search across SKU, item name, make, subcategories, supplier, capacity' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ description: 'Filter by category name or ID' })
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({ description: 'Filter by manufacturer / make' })
  @IsOptional()
  @IsString()
  make?: string;

  @ApiPropertyOptional({ description: 'Filter by status (ACTIVE, INACTIVE, DELETED)', default: 'ACTIVE' })
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional({ description: 'Sort column: sku, name, make, category, listPrice, landingPrice, updatedAt', default: 'name' })
  @IsOptional()
  @IsIn(['sku', 'name', 'make', 'category', 'listPrice', 'landingPrice', 'updatedAt'])
  sortBy?: string = 'name';

  @ApiPropertyOptional({ description: 'Sort direction: asc or desc', default: 'asc' })
  @IsOptional()
  @IsIn(['asc', 'desc'])
  sortOrder?: 'asc' | 'desc' = 'asc';

  @ApiPropertyOptional({ description: 'Page number (1-indexed)', default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ description: 'Items per page', default: 25 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number = 25;
}

export class CreateMaterialDto {
  @IsString()
  sku!: string;

  @IsString()
  name!: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @IsString()
  unit?: string;

  @IsOptional()
  @IsString()
  unitId?: string;

  @IsOptional()
  @IsString()
  make?: string;

  @IsOptional()
  @IsString()
  subCategory1?: string;

  @IsOptional()
  @IsString()
  subCategory2?: string;

  @IsOptional()
  @IsString()
  subCategory3?: string;

  @IsOptional()
  @IsString()
  subCategory4?: string;

  @IsOptional()
  @IsString()
  subCategory5?: string;

  @IsOptional()
  @IsString()
  subCategory6?: string;

  @IsOptional()
  @IsString()
  subCategory7?: string;

  @IsOptional()
  @IsString()
  subCategory8?: string;

  @IsOptional()
  @IsString()
  subCategory9?: string;

  @IsOptional()
  @IsString()
  subCategory10?: string;

  @IsOptional()
  @IsString()
  capacity?: string;

  @IsOptional()
  @IsString()
  supplier?: string;

  @IsOptional()
  @IsNumber()
  listPrice?: number;

  @IsOptional()
  @IsNumber()
  dpDiscount?: number;

  @IsOptional()
  @IsNumber()
  dealerPrice?: number;

  @IsOptional()
  @IsNumber()
  lpDiscount?: number;

  @IsOptional()
  @IsNumber()
  landingPrice?: number;

  @IsOptional()
  @IsString()
  hsnSac?: string;

  @IsOptional()
  @IsString()
  specifications?: string;
}

export class UpdateMaterialDto {
  @IsOptional()
  @IsString()
  sku?: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @IsString()
  unit?: string;

  @IsOptional()
  @IsString()
  unitId?: string;

  @IsOptional()
  @IsString()
  make?: string;

  @IsOptional()
  @IsString()
  subCategory1?: string;

  @IsOptional()
  @IsString()
  subCategory2?: string;

  @IsOptional()
  @IsString()
  subCategory3?: string;

  @IsOptional()
  @IsString()
  subCategory4?: string;

  @IsOptional()
  @IsString()
  subCategory5?: string;

  @IsOptional()
  @IsString()
  subCategory6?: string;

  @IsOptional()
  @IsString()
  subCategory7?: string;

  @IsOptional()
  @IsString()
  subCategory8?: string;

  @IsOptional()
  @IsString()
  subCategory9?: string;

  @IsOptional()
  @IsString()
  subCategory10?: string;

  @IsOptional()
  @IsString()
  capacity?: string;

  @IsOptional()
  @IsString()
  supplier?: string;

  @IsOptional()
  @IsNumber()
  listPrice?: number;

  @IsOptional()
  @IsNumber()
  dpDiscount?: number;

  @IsOptional()
  @IsNumber()
  dealerPrice?: number;

  @IsOptional()
  @IsNumber()
  lpDiscount?: number;

  @IsOptional()
  @IsNumber()
  landingPrice?: number;

  @IsOptional()
  @IsString()
  hsnSac?: string;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  specifications?: string;
}
