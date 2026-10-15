import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  IsEnum,
  IsBoolean,
  IsNumber,
  IsArray,
  IsDateString,
} from 'class-validator';

export enum CrmResolveActivityType {
  CALL = 'CALL',
  MEETING = 'MEETING',
  SITE_VISIT = 'SITE_VISIT',
  DEMO = 'DEMO',
  EMAIL = 'EMAIL',
  WHATSAPP = 'WHATSAPP',
}

export class ResolveFollowUpDto {
  @ApiProperty({
    enum: CrmResolveActivityType,
    example: 'CALL',
    description: 'Type of activity performed to resolve follow-up',
  })
  @IsEnum(CrmResolveActivityType)
  activityType: CrmResolveActivityType;

  @ApiPropertyOptional({ example: 'Discussed VFD 75HP panel quote with GM' })
  @IsOptional()
  @IsString()
  subject?: string;

  @ApiPropertyOptional({ example: 'Client agreed on price, requesting drawing SLD' })
  @IsOptional()
  @IsString()
  discussion?: string;

  @ApiPropertyOptional({ example: 'INTERESTED', description: 'Overall resolution outcome' })
  @IsOptional()
  @IsString()
  outcome?: string;

  @ApiPropertyOptional({ example: 'Internal staff notes regarding commercial terms' })
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional({ example: 'Need 415V dual pump auto changeover panel' })
  @IsOptional()
  @IsString()
  customerRequirements?: string;

  @ApiPropertyOptional({
    type: [String],
    example: ['VFD_PANEL', 'BOOSTER_PUMP'],
    description: 'Product or system codes discussed',
  })
  @IsOptional()
  productsDiscussed?: string[] | string;

  @ApiPropertyOptional({
    type: [String],
    example: ['QUOTATION', 'CATALOG'],
    description: 'Document types provided or sent to customer',
  })
  @IsOptional()
  documentsSent?: string[] | string;

  // ── CALL SPECIFICS ──
  @ApiPropertyOptional({ example: 180, description: 'Duration of call in seconds' })
  @IsOptional()
  @IsNumber()
  callDurationSec?: number;

  @ApiPropertyOptional({ example: 'CONNECTED', description: 'Call outcome: CONNECTED, BUSY, NO_ANSWER, etc.' })
  @IsOptional()
  @IsString()
  callOutcome?: string;

  @ApiPropertyOptional({ example: '/api/v1/crm/attachments/stream/...' })
  @IsOptional()
  @IsString()
  callRecordingUrl?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  dataSent?: boolean;

  @ApiPropertyOptional({ type: [String], example: ['QUOTATION'] })
  @IsOptional()
  dataTypes?: string[] | string;

  // ── MEETING SPECIFICS ──
  @ApiPropertyOptional({ example: 'OFFLINE', description: 'OFFLINE, ONLINE_TEAMS, CLIENT_OFFICE' })
  @IsOptional()
  @IsString()
  meetingType?: string;

  @ApiPropertyOptional({ example: 'Saark Factory - Conference Room' })
  @IsOptional()
  @IsString()
  meetingLocation?: string;

  @ApiPropertyOptional({ example: '2026-10-15T15:00:00Z' })
  @IsOptional()
  @IsDateString()
  meetingStartTime?: string;

  @ApiPropertyOptional({ example: '2026-10-15T16:00:00Z' })
  @IsOptional()
  @IsDateString()
  meetingEndTime?: string;

  @ApiPropertyOptional({ example: 'Technical SLD presentation & terms negotiation' })
  @IsOptional()
  @IsString()
  meetingAgenda?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  hostStaffId?: string;

  // ── SITE VISIT SPECIFICS ──
  @ApiPropertyOptional({ example: 'Plot 42, MIDC Bhosari, Pune' })
  @IsOptional()
  @IsString()
  siteLocation?: string;

  @ApiPropertyOptional({ example: 'Foundation complete, cable trench ready' })
  @IsOptional()
  @IsString()
  siteCondition?: string;

  @ApiPropertyOptional({ example: '418V Phase-to-Phase, 239V Phase-to-Neutral' })
  @IsOptional()
  @IsString()
  voltageReading?: string;

  @ApiPropertyOptional({ example: 12.5 })
  @IsOptional()
  @IsNumber()
  pumpRatingHp?: number;

  @ApiPropertyOptional({ example: '1800 x 800 x 600 mm' })
  @IsOptional()
  @IsString()
  panelDimensions?: string;

  @ApiPropertyOptional({ example: 'Earthing pit is within 2 meters of incoming busbar' })
  @IsOptional()
  @IsString()
  inspectionNotes?: string;

  @ApiPropertyOptional({ type: [String], example: ['https://storage.saark.com/photo1.jpg'] })
  @IsOptional()
  photoUrls?: string[] | string;

  // ── NEXT ACTION SCHEDULING ──
  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  scheduleNext?: boolean;

  @ApiPropertyOptional({ example: 'MEETING' })
  @IsOptional()
  @IsString()
  nextActivityType?: string;

  @ApiPropertyOptional({ example: '2026-10-18T11:00:00Z' })
  @IsOptional()
  @IsDateString()
  nextScheduledDate?: string;

  @ApiPropertyOptional({ example: 'Final commercial negotiation & PO confirmation' })
  @IsOptional()
  @IsString()
  nextSubject?: string;

  @ApiPropertyOptional({ example: 'PO confirmation call' })
  @IsOptional()
  @IsString()
  nextAction?: string;

  @ApiPropertyOptional({ example: 'Bring updated revision 2 drawing' })
  @IsOptional()
  @IsString()
  nextNotes?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  nextAssignedStaffId?: string;

  @ApiPropertyOptional({ example: 'HIGH' })
  @IsOptional()
  @IsString()
  nextPriority?: string;

  // ── ATTACHMENT LINKING & IDEMPOTENCY ──
  @ApiPropertyOptional({ type: [String], description: 'UUIDs of pre-uploaded CrmAttachment records' })
  @IsOptional()
  @IsArray()
  attachmentIds?: string[];

  @ApiPropertyOptional({ example: 'idemp-20261015-81726-abc' })
  @IsOptional()
  @IsString()
  idempotencyKey?: string;
}
