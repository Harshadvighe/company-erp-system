import { Controller, Get, Post, Put, Patch, Body, Param, Query, Req, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { PanelManufacturingService } from './panel-manufacturing.service';
import { BoosterPumpCalculatorService, BoosterPumpInputDto } from './booster-pump-calculator.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Panel Manufacturing & Production MES')
@UseGuards(JwtAuthGuard)
@Controller('api/v1/panel-manufacturing')
export class PanelManufacturingController {
  constructor(
    private readonly panelService: PanelManufacturingService,
    private readonly boosterCalculatorService?: BoosterPumpCalculatorService,
  ) {}

  // ─── BOOSTER PUMP CALCULATOR & SIZING ENGINE ───────────────
  @Post('booster-pump/calculate')
  @ApiOperation({ summary: 'Calculate Booster Pump Control Panel sizing, BOM and Dealer Price quote' })
  async calculateBoosterPump(@Body() dto: BoosterPumpInputDto) {
    if (!this.boosterCalculatorService) {
      throw new Error('BoosterPumpCalculatorService not initialized');
    }
    return this.boosterCalculatorService.calculate(dto);
  }

  @Post('booster-pump/save-spec')
  @ApiOperation({ summary: 'Save calculated Booster Pump BOM as official Panel Specification' })
  async saveBoosterPumpSpec(@Body() dto: BoosterPumpInputDto) {
    if (!this.boosterCalculatorService) {
      throw new Error('BoosterPumpCalculatorService not initialized');
    }
    const customerId = dto.customerId || 'default-customer';
    return this.boosterCalculatorService.saveAsPanelSpecification(dto, customerId);
  }

  @Post('booster-pump/quick-customer')
  @ApiOperation({ summary: 'Quick add customer with custom discount/margin percentage for Booster Pump calculations' })
  async quickAddCustomer(@Body() dto: { companyName: string; percentage?: number }) {
    if (!this.boosterCalculatorService) {
      throw new Error('BoosterPumpCalculatorService not initialized');
    }
    return this.boosterCalculatorService.quickAddCustomer(dto);
  }

  // ─── SPECIFICATIONS & BOMS ──────────────────────────────────
  @Get('specs')
  @ApiOperation({ summary: 'List all Panel Specifications & BOMs' })
  async findAll() {
    return this.panelService.findAll();
  }

  @Get('specs/:id')
  @ApiOperation({ summary: 'Get Panel Specification details & BOM breakdown' })
  async findOne(@Param('id') id: string) {
    return this.panelService.findOne(id);
  }

  @Post('specs')
  @ApiOperation({ summary: 'Create new Panel Specification & auto-calculate BOM pricing' })
  async create(@Body() dto: any) {
    return this.panelService.create(dto);
  }

  // ─── PRODUCTION BATCHES ─────────────────────────────────────
  @Get('batches')
  @ApiOperation({ summary: 'List all production batches' })
  async getBatches() {
    return this.panelService.getBatches();
  }

  @Get('batches/:id')
  @ApiOperation({ summary: 'Get production batch by ID or batch number' })
  async getBatchById(@Param('id') id: string) {
    return this.panelService.getBatchById(id);
  }

  @Post('batches')
  @ApiOperation({ summary: 'Start a new production batch (New Production Start)' })
  async createBatch(@Body() dto: any, @Req() req: any) {
    const actor = req.user?.fullName || req.user?.username || 'Admin';
    return this.panelService.createBatch(dto, actor);
  }

  @Patch('batches/:id/status')
  @ApiOperation({ summary: 'Update production batch lifecycle status' })
  async updateBatchStatus(@Param('id') id: string, @Body('status') status: string, @Req() req: any) {
    const actor = req.user?.fullName || req.user?.username || 'Admin';
    return this.panelService.updateBatchStatus(id, status, actor);
  }

  @Put('batches/:id/materials')
  @ApiOperation({ summary: 'Update batch material BOM list & checklist states (PO/PCB/Receive)' })
  async updateBatchMaterials(@Param('id') id: string, @Body('materials') materials: any[], @Req() req: any) {
    const actor = req.user?.fullName || req.user?.username || 'Admin';
    return this.panelService.updateBatchMaterials(id, materials, actor);
  }

  // ─── PRODUCT TESTING & INSPECTION RECORDS ────────────────────
  @Get('testing-records')
  @ApiOperation({ summary: 'List product testing & inspection records' })
  async getTestingRecords(@Query('batchId') batchId?: string) {
    return this.panelService.getTestingRecords(batchId);
  }

  @Get('testing-records/tested-ok')
  @ApiOperation({ summary: 'Get all Tested OK Product IDs ready for dispatch' })
  async getTestedOkProducts() {
    return this.panelService.getTestedOkProducts();
  }

  @Post('testing-records')
  @ApiOperation({ summary: 'Log per-product inspection, programming & testing result' })
  async createTestingRecord(@Body() dto: any, @Req() req: any) {
    const actor = req.user?.fullName || req.user?.username || 'Admin';
    return this.panelService.createTestingRecord(dto, actor);
  }

  // ─── DISPATCH LOG ───────────────────────────────────────────
  @Get('dispatch-logs')
  @ApiOperation({ summary: 'List all dispatch log history records' })
  async getDispatchLogs() {
    return this.panelService.getDispatchLogs();
  }

  @Post('dispatch-logs')
  @ApiOperation({ summary: 'Dispatch Tested OK product to target department' })
  async createDispatch(@Body() dto: any, @Req() req: any) {
    const actor = req.user?.fullName || req.user?.username || 'Admin';
    return this.panelService.createDispatch(dto, actor);
  }

  // ─── PANEL ASSEMBLY & QC ────────────────────────────────────
  @Get('assembly-jobs')
  @ApiOperation({ summary: 'List panel assembly jobs' })
  async getAssemblyJobs() {
    return this.panelService.getAssemblyJobs();
  }

  @Post('assembly-jobs')
  @ApiOperation({ summary: 'Create new panel assembly job' })
  async createAssemblyJob(@Body() dto: any) {
    return this.panelService.createAssemblyJob(dto);
  }

  @Post('panel-qc-signoff')
  @ApiOperation({ summary: 'Sign off panel QC (insulation resistance & continuity/torque verification)' })
  async signoffPanelQc(@Body() dto: any, @Req() req: any) {
    const actor = req.user?.fullName || req.user?.username || 'Admin';
    return this.panelService.signoffPanelQc(dto, actor);
  }
}

