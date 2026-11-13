import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { NpdService } from './npd.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import {
  CreateNpdProjectDto,
  SignoffStepDto,
  UpdateRegisterMapDto,
  SyncBomDto,
  CreateArtifactDto,
  FactoryTestIngestionDto,
} from './npd.dto';

@ApiTags('Product Development (NPD / NPI)')
@Controller('api/erp/npd')
export class NpdController {
  constructor(private readonly npdService: NpdService) {}

  // ─── 1. PROJECTS ─────────────────────────────────────────────────────────
  @Post('projects')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create new NPD project and auto-seed 24 dual-track workflow steps' })
  createProject(@Body() dto: CreateNpdProjectDto, @Req() req: any) {
    return this.npdService.createProject(dto, req.user);
  }

  @Get('projects')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List all NPD projects with phase progress and stats' })
  getProjects(@Query() query: { status?: string; phase?: number; search?: string }) {
    return this.npdService.getProjects(query);
  }

  @Get('projects/:id/board')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get full 24-step interactive workflow board, artifacts, BOM and test stats' })
  getProjectBoard(@Param('id') id: string) {
    return this.npdService.getProjectBoard(id);
  }

  // ─── 2. STEP SIGN-OFF & HARD-GATES ───────────────────────────────────────
  @Post('projects/:id/steps/:stepNumber/signoff')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Sign-off a workflow step with hard-gate enforcement (Step 7 Review, Step 9 Freeze, Step 14 RoHS, Step 22 Golden Lock, Step 23 Factory Pass)' })
  signoffStep(
    @Param('id') id: string,
    @Param('stepNumber') stepNumber: string,
    @Body() dto: SignoffStepDto,
    @Req() req: any,
  ) {
    return this.npdService.signoffStep(id, Number(stepNumber), dto, req.user);
  }

  // ─── 3. SSOT REGISTER MAP ────────────────────────────────────────────────
  @Get('projects/:id/register-map')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get Single Source of Truth (SSOT) Register Map (PC_REG & MB_REG)' })
  getRegisterMap(@Param('id') id: string) {
    return this.npdService.getRegisterMap(id);
  }

  @Put('projects/:id/register-map')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update Register Map (Blocked if Step 9 Design Freeze is active)' })
  updateRegisterMap(
    @Param('id') id: string,
    @Body() dto: UpdateRegisterMapDto,
    @Req() req: any,
  ) {
    return this.npdService.updateRegisterMap(id, dto, req.user);
  }

  // ─── 4. BOM LINKS & ROHS ──────────────────────────────────────────────────
  @Get('projects/:id/bom')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get BOM line items with RoHS compliance status' })
  getBomLinks(@Param('id') id: string) {
    return this.npdService.getBomLinks(id);
  }

  @Post('projects/:id/bom-sync')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Sync BOM items with ERP Item Master' })
  syncBom(@Param('id') id: string, @Body() dto: SyncBomDto) {
    return this.npdService.syncBom(id, dto);
  }

  // ─── 5. ARTIFACT VAULT ───────────────────────────────────────────────────
  @Get('projects/:id/artifacts')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get project artifacts (schematics, Gerbers, firmware, hashes)' })
  getArtifacts(@Param('id') id: string) {
    return this.npdService.getArtifacts(id);
  }

  @Post('projects/:id/artifacts')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Record versioned artifact with SHA-256 hash' })
  createArtifact(
    @Param('id') id: string,
    @Body() dto: CreateArtifactDto,
    @Req() req: any,
  ) {
    return this.npdService.createArtifact(id, dto, req.user);
  }

  // ─── 6. FACTORY QC TEST INGESTION (STEP 23) ──────────────────────────────
  @Get('projects/:id/test-logs')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get factory automated test logs' })
  getTestLogs(@Param('id') id: string, @Query('serial') serial?: string) {
    return this.npdService.getFactoryTestLogs(id, serial);
  }

  @Post('factory-test')
  @ApiOperation({ summary: 'Automated test rig ingestion endpoint (Step 23 FCT)' })
  ingestFactoryTest(@Body() dto: FactoryTestIngestionDto) {
    // Open for automated test rigs or SMT line test fixtures
    return this.npdService.ingestFactoryTest(dto);
  }
}

// Controller alias for api/v1/npd to ensure standard v1 compatibility
@ApiTags('Product Development (NPD / NPI) v1 Alias')
@Controller('api/v1/npd')
export class NpdV1Controller extends NpdController {}

