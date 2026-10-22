import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { MaterialsService } from './materials.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import {
  FindMaterialsQueryDto,
  CreateMaterialDto,
  UpdateMaterialDto,
} from './dto/materials.dto';

@ApiTags('Materials')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/materials')
export class MaterialsController {
  constructor(private readonly materialsService: MaterialsService) {}

  private canViewInternalPricing(req: any): boolean {
    if (!req.user) return false;
    const roles: string[] = req.user.roles || [];
    const perms: string[] = req.user.permissions || [];
    const isAdmin =
      req.user.isAdmin === true ||
      roles.some((r) => ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'].includes(r));
    return (
      isAdmin ||
      perms.includes('INTERNAL_PRICING:VIEW') ||
      perms.includes('MATERIALS:VIEW_INTERNAL_PRICING')
    );
  }

  private getActor(req: any) {
    if (!req.user) return undefined;
    return {
      ...req.user,
      requestId: req.headers?.['x-request-id'] || req.headers?.['x-correlation-id'],
      ip: req.ip || req.headers?.['x-forwarded-for'],
    };
  }

  @Get('meta/categories')
  @RequirePermissions('MATERIALS:VIEW', 'INVENTORY:VIEW')
  @ApiOperation({ summary: 'Get list of material categories with item counts' })
  getCategories() {
    return this.materialsService.getCategories();
  }

  @Get('meta/makes')
  @RequirePermissions('MATERIALS:VIEW', 'INVENTORY:VIEW')
  @ApiOperation({ summary: 'Get distinct manufacturers / makes' })
  getMakes() {
    return this.materialsService.getMakes();
  }

  @Get('meta/stats')
  @RequirePermissions('MATERIALS:VIEW', 'INVENTORY:VIEW')
  @ApiOperation({ summary: 'Get material master summary metrics' })
  getStats(@Req() req: any) {
    return this.materialsService.getStats(this.canViewInternalPricing(req));
  }

  @Get()
  @RequirePermissions('MATERIALS:VIEW', 'INVENTORY:VIEW')
  @ApiOperation({
    summary:
      'Search, filter, sort, and paginate material master records with RBAC internal pricing protection',
  })
  findAll(@Query() query: FindMaterialsQueryDto, @Req() req: any) {
    return this.materialsService.findAll(query, this.canViewInternalPricing(req));
  }

  @Get(':id')
  @RequirePermissions('MATERIALS:VIEW', 'INVENTORY:VIEW')
  @ApiOperation({ summary: 'Get material detail by ID or SKU' })
  findOne(@Param('id') id: string, @Req() req: any) {
    return this.materialsService.findOne(id, this.canViewInternalPricing(req));
  }

  @Post()
  @RequirePermissions('MATERIALS:CREATE', 'INVENTORY:CREATE')
  @ApiOperation({ summary: 'Create new material master record' })
  create(@Body() dto: CreateMaterialDto, @Req() req: any) {
    return this.materialsService.create(
      dto,
      req.user?.id,
      req.user?.email,
      this.getActor(req),
    );
  }

  @Put(':id')
  @RequirePermissions('MATERIALS:EDIT', 'INVENTORY:EDIT')
  @ApiOperation({ summary: 'Update material master record' })
  update(
    @Param('id') id: string,
    @Body() dto: UpdateMaterialDto,
    @Req() req: any,
  ) {
    return this.materialsService.update(
      id,
      dto,
      req.user?.id,
      req.user?.email,
      this.getActor(req),
    );
  }

  @Delete(':id')
  @RequirePermissions('MATERIALS:DELETE', 'INVENTORY:DELETE')
  @ApiOperation({ summary: 'Soft-delete material record' })
  delete(@Param('id') id: string, @Req() req: any) {
    return this.materialsService.delete(
      id,
      req.user?.id,
      req.user?.email,
      this.getActor(req),
    );
  }
}
