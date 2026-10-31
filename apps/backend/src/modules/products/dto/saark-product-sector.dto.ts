import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsNumber,
  IsIn,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateSaarkProductSectorDto {
  // ─── SECTION 1: Basic Identity & Description ──────────────────────────────
  @ApiProperty({ description: 'Product Sector name', example: 'Booster Pump Control Panel' })
  @IsString()
  @IsNotEmpty()
  productSector: string;

  @ApiProperty({ description: 'Product Name / Title', example: 'Dual Pump Automatic Booster Control Panel' })
  @IsString()
  @IsNotEmpty()
  productName: string;

  @ApiProperty({ description: 'SKU / Model Number', example: 'SAARK-BP-200' })
  @IsString()
  @IsNotEmpty()
  skuModelNumber: string;

  @ApiPropertyOptional({ description: 'Product Category / Sub-category', example: 'Control Panel' })
  @IsString()
  @IsOptional()
  productCategory?: string;

  @ApiPropertyOptional({ description: 'Short Description or file attachment path' })
  @IsString()
  @IsOptional()
  shortDescriptionFile?: string;

  @ApiPropertyOptional({ description: 'Detailed Description / Features file path' })
  @IsString()
  @IsOptional()
  detailedDescriptionFile?: string;

  @ApiPropertyOptional({ description: 'Target Applications file path' })
  @IsString()
  @IsOptional()
  targetApplicationsFile?: string;

  // ─── SECTION 2: Electrical & Power Specifications ─────────────────────────
  @ApiPropertyOptional({ description: 'Input Voltage', example: '415V 3-Phase' })
  @IsString()
  @IsOptional()
  inputVoltage?: string;

  @ApiPropertyOptional({ description: 'Rated Frequency', example: '50 Hz' })
  @IsString()
  @IsOptional()
  ratedFrequency?: string;

  @ApiPropertyOptional({ description: 'Minimum Power Rating', example: 0.5 })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  minPowerRating?: number;

  @ApiPropertyOptional({ description: 'Maximum Power Rating', example: 10.0 })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  maxPowerRating?: number;

  @ApiPropertyOptional({ description: 'Power Unit', example: 'HP', default: 'HP' })
  @IsString()
  @IsOptional()
  powerRatingUnit?: string;

  @ApiPropertyOptional({ description: 'Starter / Drive Type', example: 'Integrated VFD' })
  @IsString()
  @IsOptional()
  starterDriveType?: string;

  @ApiPropertyOptional({ description: 'Enclosure / IP Protection Rating', example: 'IP55' })
  @IsString()
  @IsOptional()
  enclosureIpRating?: string;

  // ─── SECTION 3: Pump Configuration & Control Parameters ──────────────────
  @ApiPropertyOptional({ description: 'Pump Support Capacity', example: '2 Pumps [1W+1S]' })
  @IsString()
  @IsOptional()
  pumpSupportCapacity?: string;

  @ApiPropertyOptional({
    description: 'Control Modes (Semicolon-separated)',
    example: 'Constant Pressure; Auto-Alternation; Duty/Assist/Standby',
  })
  @IsString()
  @IsOptional()
  controlModes?: string;

  @ApiPropertyOptional({
    description: 'Pressure Sensor Compatibility (Semicolon-separated)',
    example: '4-20 mA; 0-10V; RS-485 Digital',
  })
  @IsString()
  @IsOptional()
  pressureSensorCompatibility?: string;

  @ApiPropertyOptional({ description: 'Minimum Operating Pressure', example: 1.0 })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  minPressure?: number;

  @ApiPropertyOptional({ description: 'Maximum Operating Pressure', example: 16.0 })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  maxPressure?: number;

  @ApiPropertyOptional({ description: 'Pressure Unit', example: 'bar', default: 'bar' })
  @IsString()
  @IsOptional()
  pressureUnit?: string;

  @ApiPropertyOptional({
    description: 'Level Sensor Inputs (Semicolon-separated)',
    example: 'Float Switch; Ultrasonic; Conductive Probes',
  })
  @IsString()
  @IsOptional()
  levelSensorInputs?: string;

  // ─── SECTION 4: Smart Features, Display & Connectivity ───────────────────
  @ApiPropertyOptional({ description: 'User Interface / Display', example: 'Touchscreen HMI' })
  @IsString()
  @IsOptional()
  userInterfaceDisplay?: string;

  @ApiPropertyOptional({
    description: 'Communication Protocols (Semicolon-separated)',
    example: 'RS-485 Modbus RTU; Modbus TCP/IP; BACnet',
  })
  @IsString()
  @IsOptional()
  communicationProtocols?: string;

  @ApiPropertyOptional({
    description: 'IoT / Cloud Features (Semicolon-separated)',
    example: 'GSM/4G Remote Telemetry; Wi-Fi Dashboard; Mobile App Support; SMS Alerts',
  })
  @IsString()
  @IsOptional()
  iotCloudFeatures?: string;

  @ApiPropertyOptional({
    description: 'Data Logging Features (Semicolon-separated)',
    example: 'Historical Fault Log; Run-Hour Meter; Pressure Trends',
  })
  @IsString()
  @IsOptional()
  dataLogging?: string;

  // ─── SECTION 5: Protections & Alarms ──────────────────────────────────────
  @ApiPropertyOptional({
    description: 'Electrical Protections (Semicolon-separated)',
    example: 'Overload; Under/Over-Voltage; Phase Failure; Phase Reversal; Short Circuit',
  })
  @IsString()
  @IsOptional()
  electricalProtections?: string;

  @ApiPropertyOptional({
    description: 'Hydraulic Protections (Semicolon-separated)',
    example: 'Dry Run Protection (Auto-Reset); High/Low Pressure Cutoff; Pipe Burst / Leakage Detection; Anti-Seize Cycling',
  })
  @IsString()
  @IsOptional()
  hydraulicProtections?: string;

  // ─── SECTION 6: Media, Documents & Compliance ─────────────────────────────
  @ApiPropertyOptional({
    description: 'Product Images (Pipe-separated file paths)',
    example: 'uploads/img1.jpg | uploads/img2.jpg',
  })
  @IsString()
  @IsOptional()
  productImages?: string;

  @ApiPropertyOptional({ description: 'Datasheet / Manual file path' })
  @IsString()
  @IsOptional()
  datasheetManual?: string;

  @ApiPropertyOptional({ description: 'Wiring / Single Line Diagram (SLD) file path' })
  @IsString()
  @IsOptional()
  wiringSld?: string;

  @ApiPropertyOptional({
    description: 'Certifications (Semicolon-separated)',
    example: 'CE; RoHS; ISO 9001; CPRI Approved',
  })
  @IsString()
  @IsOptional()
  certifications?: string;

  // ─── SECTION 7: Promotional Material & Operational Videos ────────────────
  @ApiPropertyOptional({ description: 'Promotional video file path / URL' })
  @IsString()
  @IsOptional()
  promotionalVideo?: string;

  @ApiPropertyOptional({ description: 'Photo Name / Caption', example: 'Enclosure Interior Assembly' })
  @IsString()
  @IsOptional()
  photoName?: string;

  @ApiPropertyOptional({ description: 'Photo Description', example: 'IP55 powder-coated enclosure internal component placement' })
  @IsString()
  @IsOptional()
  photoDescription?: string;

  @ApiPropertyOptional({ description: 'Photo Attachment file path' })
  @IsString()
  @IsOptional()
  photoAttachment?: string;

  @ApiPropertyOptional({
    description: 'Setting Video Type',
    example: 'Installation / Setup',
  })
  @IsString()
  @IsOptional()
  settingVideoType?: string;

  @ApiPropertyOptional({ description: 'Setting Video Details / Notes', example: 'Inverter PID tuning and auto-alternation parameter setup' })
  @IsString()
  @IsOptional()
  settingVideoDetails?: string;

  @ApiPropertyOptional({ description: 'Setting Video Attachment file path / URL' })
  @IsString()
  @IsOptional()
  settingVideoAttachment?: string;

  // ─── Status ───────────────────────────────────────────────────────────────
  @ApiPropertyOptional({ description: 'Status', example: 'ACTIVE', default: 'ACTIVE' })
  @IsString()
  @IsOptional()
  @IsIn(['ACTIVE', 'INACTIVE', 'ARCHIVED'])
  status?: string;
}

export class UpdateSaarkProductSectorDto extends PartialType(CreateSaarkProductSectorDto) {}

export class SaarkProductSectorQueryDto {
  @ApiPropertyOptional({ description: 'Search term for name, SKU, or category' })
  @IsString()
  @IsOptional()
  search?: string;

  @ApiPropertyOptional({ description: 'Filter by product sector' })
  @IsString()
  @IsOptional()
  productSector?: string;

  @ApiPropertyOptional({ description: 'Filter by category' })
  @IsString()
  @IsOptional()
  productCategory?: string;

  @ApiPropertyOptional({ description: 'Filter by status' })
  @IsString()
  @IsOptional()
  status?: string;

  @ApiPropertyOptional({ description: 'Page number', default: 1 })
  @IsOptional()
  @Type(() => Number)
  page?: number;

  @ApiPropertyOptional({ description: 'Items per page', default: 25 })
  @IsOptional()
  @Type(() => Number)
  limit?: number;
}
