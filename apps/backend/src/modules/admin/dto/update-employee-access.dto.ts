import { IsArray, IsEnum, IsNotEmpty, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export enum PermissionOverrideEffect {
  ALLOW = 'ALLOW',
  DENY = 'DENY',
  INHERIT = 'INHERIT',
}

export class PermissionOverrideItemDto {
  @ApiProperty({ description: 'ID of the permission to override' })
  @IsString()
  @IsNotEmpty()
  permissionId: string;

  @ApiProperty({ enum: PermissionOverrideEffect, description: 'ALLOW, DENY, or INHERIT (revert to role default)' })
  @IsEnum(PermissionOverrideEffect)
  effect: PermissionOverrideEffect;

  @ApiProperty({ required: false, description: 'Optional administrative justification' })
  @IsString()
  @IsOptional()
  reason?: string;
}

export class UpdateEmployeeAccessDto {
  @ApiProperty({ type: [PermissionOverrideItemDto], description: 'List of permission overrides to apply' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PermissionOverrideItemDto)
  overrides: PermissionOverrideItemDto[];

  @ApiProperty({ required: false, description: 'General reason for this permission change' })
  @IsString()
  @IsOptional()
  reason?: string;
}
