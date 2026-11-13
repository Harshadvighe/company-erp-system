import { IsString, IsNotEmpty, IsOptional, IsNumber, IsBoolean, IsArray } from 'class-validator';

export class CreateNpdProjectDto {
  @IsString()
  @IsNotEmpty()
  projectName: string;

  @IsString()
  @IsOptional()
  projectCode?: string;

  @IsString()
  @IsOptional()
  skuId?: string;

  @IsString()
  @IsOptional()
  productCategory?: string;

  @IsString()
  @IsOptional()
  targetMcu?: string;

  @IsString()
  @IsOptional()
  operatingVoltage?: string;

  @IsString()
  @IsOptional()
  formFactor?: string;

  @IsString()
  @IsOptional()
  complianceTargets?: string;

  @IsString()
  @IsOptional()
  targetCompletionDate?: string;
}

export class SignoffStepDto {
  @IsString()
  @IsOptional()
  signoffComments?: string;

  @IsString()
  @IsOptional()
  signoffRole?: string;

  @IsBoolean()
  @IsOptional()
  bypassGate?: boolean;

  @IsString()
  @IsOptional()
  firmwareHash?: string;
}

export interface RegisterMapItem {
  id?: string;
  pcReg: string;
  mbReg: string;
  address: number;
  name: string;
  dataType: string;
  access: 'R' | 'W' | 'RW';
  defaultVal?: string;
  description?: string;
}

export class UpdateRegisterMapDto {
  @IsArray()
  registers: RegisterMapItem[];
}

export interface BomSyncItem {
  designator: string;
  mpn: string;
  manufacturer?: string;
  description?: string;
  package?: string;
  quantityPerPcb?: number;
  erpItemId?: string;
  isRohsCompliant?: boolean;
  rohsCertificateUrl?: string;
  lifecycleStatus?: string;
  targetUnitCost?: number;
}

export class SyncBomDto {
  @IsArray()
  items: BomSyncItem[];
}

export class CreateArtifactDto {
  @IsNumber()
  @IsOptional()
  stepNumber?: number;

  @IsString()
  @IsNotEmpty()
  artifactCategory: string;

  @IsString()
  @IsNotEmpty()
  fileName: string;

  @IsString()
  @IsNotEmpty()
  filePath: string;

  @IsNumber()
  @IsOptional()
  fileSizeBytes?: number;

  @IsString()
  @IsOptional()
  sha256Hash?: string;

  @IsString()
  @IsOptional()
  versionTag?: string;

  @IsBoolean()
  @IsOptional()
  isFrozen?: boolean;
}

export class FactoryTestIngestionDto {
  @IsString()
  @IsOptional()
  projectCode?: string;

  @IsString()
  @IsOptional()
  projectId?: string;

  @IsString()
  @IsNotEmpty()
  serialNumber: string;

  @IsString()
  @IsOptional()
  batchRunId?: string;

  @IsNumber()
  @IsOptional()
  stepNumber?: number;

  @IsString()
  @IsOptional()
  firmwareVersion?: string;

  @IsString()
  @IsOptional()
  firmwareHash?: string;

  @IsString()
  @IsOptional()
  testStationId?: string;

  @IsString()
  @IsOptional()
  operatorName?: string;

  @IsString()
  @IsNotEmpty()
  testStatus: 'PASS' | 'FAIL' | 'IN_PROGRESS';

  @IsOptional()
  voltageRailsResult?: any;

  @IsNumber()
  @IsOptional()
  currentConsumptionMa?: number;

  @IsNumber()
  @IsOptional()
  rfRssiDbm?: number;

  @IsOptional()
  peripheralsTested?: any;

  @IsString()
  @IsOptional()
  rawTerminalLog?: string;

  @IsString()
  @IsOptional()
  failureReason?: string;
}
