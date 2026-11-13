import { Injectable, Logger, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { MASTER_NPD_STEPS } from './npd.master-steps';
import {
  CreateNpdProjectDto,
  SignoffStepDto,
  UpdateRegisterMapDto,
  SyncBomDto,
  CreateArtifactDto,
  FactoryTestIngestionDto,
  RegisterMapItem,
} from './npd.dto';

const DEFAULT_REGISTER_MAP: RegisterMapItem[] = [
  {
    pcReg: 'PC_REG_0x0001',
    mbReg: 'MB_REG_30001',
    address: 1,
    name: 'SYS_STATUS',
    dataType: 'UINT16',
    access: 'R',
    defaultVal: '0x0001',
    description: 'System operational status bits (0=Boot, 1=Normal, 2=Fault)',
  },
  {
    pcReg: 'PC_REG_0x0002',
    mbReg: 'MB_REG_30002',
    address: 2,
    name: 'FW_VERSION',
    dataType: 'UINT32',
    access: 'R',
    defaultVal: '0x010000',
    description: 'Firmware major.minor.patch packed word (v1.0.0)',
  },
  {
    pcReg: 'PC_REG_0x0003',
    mbReg: 'MB_REG_30003',
    address: 3,
    name: 'DIE_TEMP_C_X10',
    dataType: 'INT16',
    access: 'R',
    defaultVal: '250',
    description: 'Internal MCU silicon temperature in tenths of deg C (250 = 25.0C)',
  },
  {
    pcReg: 'PC_REG_0x0004',
    mbReg: 'MB_REG_30004',
    address: 4,
    name: 'VRAIL_3V3_MV',
    dataType: 'UINT16',
    access: 'R',
    defaultVal: '3300',
    description: 'Regulated 3.3V rail ADC readout in millivolts',
  },
  {
    pcReg: 'PC_REG_0x0010',
    mbReg: 'MB_REG_40001',
    address: 16,
    name: 'SYSTEM_COMMAND',
    dataType: 'UINT16',
    access: 'RW',
    defaultVal: '0x0000',
    description: 'Host control register: 0x0001=Reboot, 0x0002=Self-Test, 0x00FF=Factory-Reset',
  },
  {
    pcReg: 'PC_REG_0x0011',
    mbReg: 'MB_REG_40002',
    address: 17,
    name: 'HEARTBEAT_INTERVAL_SEC',
    dataType: 'UINT16',
    access: 'RW',
    defaultVal: '10',
    description: 'Watchdog ping and telemetry cadence in seconds',
  },
  {
    pcReg: 'PC_REG_0x0020',
    mbReg: 'MB_REG_40010',
    address: 32,
    name: 'MODBUS_BAUD_RATE',
    dataType: 'UINT32',
    access: 'RW',
    defaultVal: '115200',
    description: 'RS485 baud rate (9600, 19200, 57600, 115200)',
  },
  {
    pcReg: 'PC_REG_0x0022',
    mbReg: 'MB_REG_40012',
    address: 34,
    name: 'ERROR_FAULT_CODE',
    dataType: 'UINT16',
    access: 'R',
    defaultVal: '0x0000',
    description: 'Active hardware fault register (Bit 0=Brownout, 1=Sensor Fail, 2=CRC Error)',
  },
];

@Injectable()
export class NpdService {
  private readonly logger = new Logger(NpdService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── 1. CREATE PROJECT & AUTO-SEED 24 STEPS ──────────────────────────────
  async createProject(dto: CreateNpdProjectDto, user?: any) {
    const count = await this.prisma.npdProject.count();
    const currentYear = new Date().getFullYear();
    const projectCode =
      dto.projectCode || `PRJ-NPD-${currentYear}-${String(count + 1).padStart(4, '0')}`;

    const existing = await this.prisma.npdProject.findUnique({
      where: { projectCode },
    });
    if (existing) {
      throw new ConflictException(`Project code ${projectCode} already exists.`);
    }

    // Interactive transaction with timeout
    const createdProject = await this.prisma.$transaction(
      async (tx) => {
        const project = await tx.npdProject.create({
          data: {
            projectCode,
            projectName: dto.projectName,
            skuId: dto.skuId,
            productCategory: dto.productCategory || 'IoT & Embedded Hardware',
            targetMcu: dto.targetMcu || 'ESP32-S3-WROOM-1',
            operatingVoltage: dto.operatingVoltage || '3.3V / 12V-24V DC',
            formFactor: dto.formFactor || 'DIN Rail 4U',
            complianceTargets: dto.complianceTargets || 'CE, FCC Part 15, RoHS 3, WEEE',
            currentStep: 1,
            currentPhase: 1,
            status: 'ACTIVE',
            registerMap: DEFAULT_REGISTER_MAP as any,
            isRegisterMapFrozen: false,
            targetCompletionDate: dto.targetCompletionDate ? new Date(dto.targetCompletionDate) : null,
            createdByStaffId: user?.id || user?.sub,
            createdByStaffName: user?.fullName || user?.username || 'Engineering Lead',
          },
        });

        // Seed 24 steps
        const stepRecords = MASTER_NPD_STEPS.map((step) => ({
          projectId: project.id,
          stepNumber: step.stepNumber,
          stepTitle: step.stepTitle,
          phaseNumber: step.phaseNumber,
          phaseName: step.phaseName,
          trackType: step.trackType,
          hwDeliverable: step.hwDeliverable,
          swDeliverable: step.swDeliverable,
          gateType: step.gateType,
          status: step.stepNumber === 1 ? 'IN_PROGRESS' : 'PENDING',
        }));

        await tx.npdWorkflowStep.createMany({
          data: stepRecords,
        });

        return project;
      },
      { maxWait: 20000, timeout: 30000 },
    );

    this.logger.log(`Created NPD Project ${createdProject.projectCode} (${createdProject.projectName}) with 24 seeded steps.`);
    return this.getProjectBoard(createdProject.id);
  }

  // ─── 2. LIST PROJECTS ─────────────────────────────────────────────────────
  async getProjects(query?: { status?: string; phase?: number; search?: string }) {
    const where: any = {};
    if (query?.status) where.status = query.status;
    if (query?.phase) where.currentPhase = Number(query.phase);
    if (query?.search) {
      where.OR = [
        { projectCode: { contains: query.search, mode: 'insensitive' } },
        { projectName: { contains: query.search, mode: 'insensitive' } },
        { targetMcu: { contains: query.search, mode: 'insensitive' } },
        { productCategory: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    const projects = await this.prisma.npdProject.findMany({
      where,
      include: {
        steps: {
          select: {
            stepNumber: true,
            status: true,
            gateType: true,
          },
        },
        _count: {
          select: {
            artifacts: true,
            bomLinks: true,
            unitTestLogs: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return projects.map((p) => {
      const signedOffCount = p.steps.filter((s) => s.status === 'SIGNED_OFF').length;
      const progressPct = Math.round((signedOffCount / 24) * 100);
      return {
        ...p,
        signedOffCount,
        progressPct,
      };
    });
  }

  // ─── 3. GET PROJECT BOARD & 24 STEPS ──────────────────────────────────────
  async getProjectBoard(projectId: string) {
    const project = await this.prisma.npdProject.findUnique({
      where: { id: projectId },
      include: {
        steps: {
          orderBy: { stepNumber: 'asc' },
        },
        artifacts: {
          orderBy: { createdAt: 'desc' },
        },
        bomLinks: {
          orderBy: { designator: 'asc' },
        },
        unitTestLogs: {
          orderBy: { testedAt: 'desc' },
          take: 50,
        },
      },
    });

    if (!project) {
      throw new NotFoundException(`NPD Project ${projectId} not found.`);
    }

    const totalSteps = project.steps.length;
    const signedOffSteps = project.steps.filter((s) => s.status === 'SIGNED_OFF').length;
    const progressPct = Math.round((signedOffSteps / (totalSteps || 24)) * 100);

    // BOM RoHS stats
    const totalBomCount = project.bomLinks.length;
    const rohsCompliantCount = project.bomLinks.filter((b) => b.isRohsCompliant).length;
    const rohsCompliantPct = totalBomCount > 0 ? Math.round((rohsCompliantCount / totalBomCount) * 100) : 100;

    // Test stats
    const totalTests = project.unitTestLogs.length;
    const passTests = project.unitTestLogs.filter((t) => t.testStatus === 'PASS').length;
    const failTests = project.unitTestLogs.filter((t) => t.testStatus === 'FAIL').length;

    return {
      project,
      summary: {
        signedOffSteps,
        totalSteps: 24,
        progressPct,
        totalBomCount,
        rohsCompliantCount,
        rohsCompliantPct,
        totalTests,
        passTests,
        failTests,
      },
      steps: project.steps,
      artifacts: project.artifacts,
      bomLinks: project.bomLinks,
      recentTestLogs: project.unitTestLogs,
    };
  }

  // ─── 4. SIGN-OFF WORKFLOW STEP WITH HARD GATES ─────────────────────────────
  async signoffStep(projectId: string, stepNumber: number, dto: SignoffStepDto, user?: any) {
    const project = await this.prisma.npdProject.findUnique({
      where: { id: projectId },
      include: {
        steps: { orderBy: { stepNumber: 'asc' } },
        bomLinks: true,
        unitTestLogs: true,
        artifacts: true,
      },
    });

    if (!project) {
      throw new NotFoundException(`Project ${projectId} not found.`);
    }

    const targetStep = project.steps.find((s) => s.stepNumber === stepNumber);
    if (!targetStep) {
      throw new NotFoundException(`Step ${stepNumber} does not exist in project ${projectId}.`);
    }

    if (targetStep.status === 'SIGNED_OFF') {
      return { message: `Step ${stepNumber} is already signed off.`, step: targetStep };
    }

    // Gate Validation Rules:
    // A. Sequential check (unless bypass is true for admins)
    if (!dto.bypassGate) {
      const incompletePredecessors = project.steps.filter(
        (s) => s.stepNumber < stepNumber && s.status !== 'SIGNED_OFF',
      );
      if (incompletePredecessors.length > 0) {
        const missingSteps = incompletePredecessors.map((s) => s.stepNumber).join(', ');
        throw new BadRequestException(
          `Sequential Gate Blocked: Steps [${missingSteps}] must be signed off before signing off Step ${stepNumber}.`,
        );
      }
    }

    // B. HARD GATES ENFORCEMENT
    // 1. Step 7: Schematic Peer Review & Hard-Stop Gate
    if (stepNumber === 7) {
      if (!dto.signoffComments || dto.signoffComments.trim().length < 5) {
        throw new BadRequestException(
          'Hard-Stop Gate 7: Formal schematic peer-review comments and review sign-off checklist are mandatory.',
        );
      }
    }

    // 2. Step 9: Design Freeze (Gerber & Register Map Freeze)
    if (stepNumber === 9) {
      // Step 9 permanently locks the register map and schematics
      await this.prisma.npdProject.update({
        where: { id: projectId },
        data: {
          isRegisterMapFrozen: true,
          status: 'FROZEN',
        },
      });
      this.logger.log(`Project ${project.projectCode} has entered DESIGN FREEZE at Step 9.`);
    }

    // 3. Step 14: Purchase Order Release & 100% RoHS Verification
    if (stepNumber === 14) {
      const nonRohsItems = project.bomLinks.filter((b) => !b.isRohsCompliant);
      if (nonRohsItems.length > 0) {
        const badDesignators = nonRohsItems.map((b) => `${b.designator} (${b.mpn})`).join(', ');
        throw new BadRequestException(
          `Compliance Stop Gate 14: Sourcing PO release is hard-blocked. All components must be 100% RoHS compliant. Non-compliant components: ${badDesignators}.`,
        );
      }
    }

    // 4. Step 22: Golden Sample Lock & Firmware v1.0.0 Sign-Off
    if (stepNumber === 22) {
      const fwArtifact = project.artifacts.find(
        (a) => a.artifactCategory === 'FIRMWARE_BIN' || a.artifactCategory === 'FIRMWARE_HEX',
      );
      const hash = dto.firmwareHash || fwArtifact?.sha256Hash;
      if (!hash && !dto.bypassGate) {
        throw new BadRequestException(
          'Golden Sample Lock Gate 22: Firmware Release binary SHA-256 hash is required to lock Golden Samples before pilot production.',
        );
      }
    }

    // 5. Step 23: Production Automated Test Fixture (FCT) Ingestion
    if (stepNumber === 23) {
      const hasPassTest = project.unitTestLogs.some((t) => t.testStatus === 'PASS');
      if (!hasPassTest && !dto.bypassGate) {
        throw new BadRequestException(
          'Factory Pass Gate 23: Automated test fixture requires at least one verified PASS test log before sign-off.',
        );
      }
    }

    // Determine next step and phase
    const nextStepNumber = stepNumber + 1;
    let nextPhaseNumber = project.currentPhase;
    if (nextStepNumber >= 1 && nextStepNumber <= 5) nextPhaseNumber = 1;
    else if (nextStepNumber >= 6 && nextStepNumber <= 9) nextPhaseNumber = 2;
    else if (nextStepNumber >= 10 && nextStepNumber <= 20) nextPhaseNumber = 3;
    else if (nextStepNumber >= 21) nextPhaseNumber = 4;

    const isProjectComplete = stepNumber === 24;

    // Update current step to SIGNED_OFF and advance next step to IN_PROGRESS
    const updatedStep = await this.prisma.$transaction(
      async (tx) => {
        const step = await tx.npdWorkflowStep.update({
          where: {
            projectId_stepNumber: {
              projectId,
              stepNumber,
            },
          },
          data: {
            status: 'SIGNED_OFF',
            signedOffAt: new Date(),
            signoffStaffId: user?.id || user?.sub,
            signoffStaffName: user?.fullName || user?.username || 'Engineering Signatory',
            signoffRole: dto.signoffRole || user?.designation || 'Lead Engineer',
            signoffComments: dto.signoffComments,
          },
        });

        if (nextStepNumber <= 24) {
          await tx.npdWorkflowStep.update({
            where: {
              projectId_stepNumber: {
                projectId,
                stepNumber: nextStepNumber,
              },
            },
            data: {
              status: 'IN_PROGRESS',
            },
          });
        }

        await tx.npdProject.update({
          where: { id: projectId },
          data: {
            currentStep: isProjectComplete ? 24 : nextStepNumber,
            currentPhase: nextPhaseNumber,
            status: isProjectComplete ? 'COMPLETED' : project.status === 'FROZEN' ? 'FROZEN' : 'ACTIVE',
          },
        });

        return step;
      },
      { maxWait: 20000, timeout: 30000 },
    );

    return {
      message: `Step ${stepNumber} successfully signed off. Advanced to Step ${isProjectComplete ? 24 : nextStepNumber}.`,
      step: updatedStep,
    };
  }

  // ─── 5. SSOT REGISTER MAP (PC_REG & MB_REG) ───────────────────────────────
  async getRegisterMap(projectId: string) {
    const project = await this.prisma.npdProject.findUnique({
      where: { id: projectId },
      select: {
        id: true,
        projectCode: true,
        projectName: true,
        isRegisterMapFrozen: true,
        registerMap: true,
      },
    });

    if (!project) throw new NotFoundException(`Project ${projectId} not found.`);
    return {
      projectId: project.id,
      projectCode: project.projectCode,
      isFrozen: project.isRegisterMapFrozen,
      registers: (project.registerMap as any) || DEFAULT_REGISTER_MAP,
    };
  }

  async updateRegisterMap(projectId: string, dto: UpdateRegisterMapDto, user?: any) {
    const project = await this.prisma.npdProject.findUnique({
      where: { id: projectId },
    });

    if (!project) throw new NotFoundException(`Project ${projectId} not found.`);

    if (project.isRegisterMapFrozen) {
      throw new BadRequestException(
        'Design Freeze Enforced: The SSOT Register Map is frozen at Step 9 and cannot be modified without formal ECN/ECO sign-off.',
      );
    }

    const updated = await this.prisma.npdProject.update({
      where: { id: projectId },
      data: {
        registerMap: dto.registers as any,
      },
      select: {
        id: true,
        isRegisterMapFrozen: true,
        registerMap: true,
      },
    });

    this.logger.log(`Updated SSOT Register Map for ${project.projectCode} with ${dto.registers.length} entries.`);
    return updated;
  }

  // ─── 6. BOM MANAGEMENT & ROHS VERIFICATION ────────────────────────────────
  async getBomLinks(projectId: string) {
    return this.prisma.npdBomLink.findMany({
      where: { projectId },
      orderBy: { designator: 'asc' },
    });
  }

  async syncBom(projectId: string, dto: SyncBomDto) {
    const project = await this.prisma.npdProject.findUnique({ where: { id: projectId } });
    if (!project) throw new NotFoundException(`Project ${projectId} not found.`);

    // Clear and re-populate or upsert
    await this.prisma.$transaction(
      async (tx) => {
        await tx.npdBomLink.deleteMany({ where: { projectId } });

        const rows = dto.items.map((item) => ({
          projectId,
          designator: item.designator,
          mpn: item.mpn,
          manufacturer: item.manufacturer || 'Generic',
          description: item.description,
          package: item.package || 'SMD',
          quantityPerPcb: item.quantityPerPcb || 1,
          erpItemId: item.erpItemId,
          isRohsCompliant: item.isRohsCompliant ?? true,
          rohsCertificateUrl: item.rohsCertificateUrl,
          lifecycleStatus: item.lifecycleStatus || 'ACTIVE',
          targetUnitCost: item.targetUnitCost || 0,
        }));

        await tx.npdBomLink.createMany({ data: rows });
      },
      { maxWait: 20000, timeout: 30000 },
    );

    return this.getBomLinks(projectId);
  }

  // ─── 7. ARTIFACT VAULT ───────────────────────────────────────────────────
  async getArtifacts(projectId: string) {
    return this.prisma.npdArtifact.findMany({
      where: { projectId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createArtifact(projectId: string, dto: CreateArtifactDto, user?: any) {
    const project = await this.prisma.npdProject.findUnique({ where: { id: projectId } });
    if (!project) throw new NotFoundException(`Project ${projectId} not found.`);

    return this.prisma.npdArtifact.create({
      data: {
        projectId,
        stepNumber: dto.stepNumber,
        artifactCategory: dto.artifactCategory,
        fileName: dto.fileName,
        filePath: dto.filePath,
        fileSizeBytes: dto.fileSizeBytes,
        sha256Hash: dto.sha256Hash,
        versionTag: dto.versionTag || 'v1.0.0',
        isFrozen: dto.isFrozen ?? project.isRegisterMapFrozen,
        uploadedByStaffId: user?.id || user?.sub,
        uploadedByName: user?.fullName || user?.username || 'Hardware Engineer',
      },
    });
  }

  // ─── 8. FACTORY TEST QC LOG INGESTION (STEP 23) ───────────────────────────
  async ingestFactoryTest(dto: FactoryTestIngestionDto) {
    let project = null;
    if (dto.projectId) {
      project = await this.prisma.npdProject.findUnique({ where: { id: dto.projectId } });
    } else if (dto.projectCode) {
      project = await this.prisma.npdProject.findUnique({ where: { projectCode: dto.projectCode } });
    }

    if (!project) {
      // Find latest active project as fallback
      project = await this.prisma.npdProject.findFirst({
        where: { status: { in: ['ACTIVE', 'FROZEN'] } },
        orderBy: { createdAt: 'desc' },
      });
    }

    if (!project) {
      throw new NotFoundException('No active NPD project found for factory test log ingestion.');
    }

    const log = await this.prisma.npdUnitTestLog.create({
      data: {
        projectId: project.id,
        serialNumber: dto.serialNumber,
        batchRunId: dto.batchRunId || `BATCH-${new Date().toISOString().slice(0, 10)}`,
        stepNumber: dto.stepNumber || 23,
        firmwareVersion: dto.firmwareVersion || 'v1.0.0',
        firmwareHash: dto.firmwareHash,
        testStationId: dto.testStationId || 'FCT-RIG-01',
        operatorName: dto.operatorName || 'QC Automation',
        testStatus: dto.testStatus,
        voltageRailsResult: dto.voltageRailsResult || { '3v3': 3.31, '5v0': 5.02, status: 'PASS' },
        currentConsumptionMa: dto.currentConsumptionMa || 85.4,
        rfRssiDbm: dto.rfRssiDbm || -52.0,
        peripheralsTested: dto.peripheralsTested || { i2c: true, spi: true, uart: true, modbus: true },
        rawTerminalLog: dto.rawTerminalLog || `[TEST BOOT] OK. Rails OK. Modbus OK. Result: ${dto.testStatus}`,
        failureReason: dto.failureReason,
      },
    });

    this.logger.log(`Ingested Factory Test Log for Serial ${log.serialNumber} (${log.testStatus}) on Project ${project.projectCode}.`);
    return log;
  }

  async getFactoryTestLogs(projectId: string, serialNumber?: string) {
    const where: any = { projectId };
    if (serialNumber) where.serialNumber = { contains: serialNumber, mode: 'insensitive' };

    return this.prisma.npdUnitTestLog.findMany({
      where,
      orderBy: { testedAt: 'desc' },
      take: 100,
    });
  }
}

