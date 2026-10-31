import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class PanelManufacturingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
  ) {}

  async findAll() {
    return this.prisma.panelSpecification.findMany({
      include: {
        customer: { select: { companyName: true, customerCode: true } },
        bomItems: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const spec = await this.prisma.panelSpecification.findUnique({
      where: { id },
      include: {
        customer: true,
        bomItems: { include: { product: true } },
      },
    });
    if (!spec) throw new NotFoundException('Panel specification not found');
    return spec;
  }

  async create(dto: any) {
    const panelCode = await this.sequenceService.nextPanelCode();

    // Auto calculate BOM costs
    let calculatedMaterialCost = 0;
    const bomItemsData: any[] = [];

    if (Array.isArray(dto.bomItems)) {
      for (const item of dto.bomItems) {
        const qty = Number(item.quantity || 1);
        const unitPrice = Number(item.unitPrice || 0);
        const total = qty * unitPrice;
        calculatedMaterialCost += total;

        bomItemsData.push({
          productId: item.productId,
          componentName: item.componentName,
          specification: item.specification,
          manufacturer: item.manufacturer,
          quantity: qty,
          unitPrice,
          totalPrice: total,
        });
      }
    }

    const materialCost = Number(dto.materialCost) || calculatedMaterialCost;
    const labourCost = Number(dto.labourCost || 10000);
    const overheadCost = Number(dto.overheadCost || 5000);
    const marginPercent = Number(dto.marginPercent || 15);

    // FORMULA: Final Price = (Material + Labour + Overhead) * (1 + Margin / 100)
    const baseCost = materialCost + labourCost + overheadCost;
    const finalPrice = Math.round(baseCost * (1 + marginPercent / 100));

    return this.prisma.panelSpecification.create({
      data: {
        panelCode,
        customerId: dto.customerId,
        panelType: dto.panelType || 'VFD_PANEL',
        voltage: dto.voltage || '415V 3-Phase',
        currentRating: dto.currentRating || '100A',
        pumpQty: Number(dto.pumpQty || 2),
        pumpHp: Number(dto.pumpHp || 7.5),
        controlType: dto.controlType || 'AUTOMATIC_PLC',
        starterType: dto.starterType || 'VFD',
        ipRating: dto.ipRating || 'IP55',
        enclosureType: dto.enclosureType || 'POWDER_COATED_MS',
        materialCost,
        labourCost,
        overheadCost,
        marginPercent,
        finalPrice,
        status: dto.status || 'DRAFT',
        bomItems: {
          create: bomItemsData,
        },
      },
      include: { bomItems: true },
    });
  }

  // -------------------------------------------------------------
  // PRODUCTION MANAGEMENT & MES WORKFLOW (batches, testing, dispatch)
  // -------------------------------------------------------------

  private getStoragePath(fileName: string): string {
    const basePath = process.env.STORAGE_LOCAL_BASE_PATH || path.join(__dirname, '../../../../storage');
    const prodDir = path.join(basePath, 'production');
    if (!fs.existsSync(prodDir)) {
      fs.mkdirSync(prodDir, { recursive: true });
    }
    return path.join(prodDir, fileName);
  }

  private readJsonFile<T>(fileName: string, fallback: T): T {
    const filePath = this.getStoragePath(fileName);
    try {
      if (fs.existsSync(filePath)) {
        const raw = fs.readFileSync(filePath, 'utf-8');
        return JSON.parse(raw);
      }
    } catch (e) {
      // fallback
    }
    return fallback;
  }

  private writeJsonFile<T>(fileName: string, data: T): void {
    const filePath = this.getStoragePath(fileName);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8');
  }

  // ─── 1. PRODUCTION BATCHES ───────────────────────────────────

  async getBatches() {
    let batches = this.readJsonFile<any[]>('batches.json', []);
    if (batches.length === 0) {
      batches = this.getInitialSampleBatches();
      this.writeJsonFile('batches.json', batches);
    }
    return batches;
  }

  async getBatchById(id: string) {
    const batches = await this.getBatches();
    const batch = batches.find((b) => b.id === id || b.batchNumber === id);
    if (!batch) throw new NotFoundException(`Batch with identifier ${id} not found`);
    return batch;
  }

  async createBatch(dto: any, actorName = 'Admin') {
    const batches = await this.getBatches();

    // Auto-generate Batch Number: BATCH-YYYYMMDD_HHMMSS
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    const ymd = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}`;
    const hms = `${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
    const generatedBatchNumber = dto.batchNumber || `BATCH-${ymd}_${hms}`;

    const newBatch = {
      id: `batch-${Date.now()}`,
      batchNumber: generatedBatchNumber,
      productId: dto.productId || null,
      productName: dto.productName || 'Smart Industrial Control Panel (VFD)',
      productModel: dto.productModel || 'SE-VFD-415V-15HP',
      productFeatures: dto.productFeatures || '',
      startDate: dto.startDate || `${now.toISOString().split('T')[0]} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`,
      expectedCompletionDate: dto.expectedCompletionDate || new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0],
      meetingDate: dto.meetingDate || now.toISOString().split('T')[0],
      assignedPersonnel: dto.assignedPersonnel || 'Rahul Verma; Sunil Pawar; Amit Deshmukh',
      notes: dto.notes || 'High-priority manufacturing batch. Ensure wiring torque standards and FAT isolation verification.',
      attachedDocument: dto.attachedDocument || null,
      status: 'IN_PROGRESS', // DRAFT -> SCHEDULED -> READY -> IN_PROGRESS -> QA_HOLD -> COMPLETED -> RELEASED
      targetQuantity: Number(dto.targetQuantity || 10),
      completedQuantity: 0,
      materials: dto.materials && dto.materials.length > 0 ? dto.materials : this.getDefaultMaterialList(),
      createdBy: actorName,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
    };

    batches.unshift(newBatch);
    this.writeJsonFile('batches.json', batches);
    return newBatch;
  }

  async updateBatchStatus(id: string, status: string, actorName = 'Admin') {
    const batches = await this.getBatches();
    const idx = batches.findIndex((b) => b.id === id || b.batchNumber === id);
    if (idx === -1) throw new NotFoundException('Batch not found');

    batches[idx].status = status;
    batches[idx].updatedAt = new Date().toISOString();
    batches[idx].lastEditedBy = actorName;
    this.writeJsonFile('batches.json', batches);
    return batches[idx];
  }

  async updateBatchMaterials(id: string, materials: any[], actorName = 'Admin') {
    const batches = await this.getBatches();
    const idx = batches.findIndex((b) => b.id === id || b.batchNumber === id);
    if (idx === -1) throw new NotFoundException('Batch not found');

    batches[idx].materials = materials;
    batches[idx].updatedAt = new Date().toISOString();
    batches[idx].lastEditedBy = actorName;
    this.writeJsonFile('batches.json', batches);
    return batches[idx];
  }

  // ─── 2. PRODUCT INSPECTION & TESTING LOG ───────────────────────

  async getTestingRecords(batchId?: string) {
    let records = this.readJsonFile<any[]>('testing_logs.json', []);
    if (records.length === 0) {
      records = this.getInitialSampleTestingRecords();
      this.writeJsonFile('testing_logs.json', records);
    }
    if (batchId) {
      return records.filter((r) => r.batchId === batchId || r.batchNumber === batchId);
    }
    return records;
  }

  async createTestingRecord(dto: any, actorName = 'Admin') {
    const records = await this.getTestingRecords();
    const now = new Date();

    const productId = dto.productId || `PRD-${Date.now().toString().slice(-6)}`;
    const existingIdx = records.findIndex((r) => r.productId === productId);

    const recordData = {
      id: existingIdx !== -1 ? records[existingIdx].id : `test-${Date.now()}`,
      productId: productId,
      batchId: dto.batchId || 'batch-1',
      batchNumber: dto.batchNumber || 'BATCH-20261005_110000',
      productName: dto.productName || 'Smart Industrial Control Panel',
      userName: actorName,
      timestamp: now.toISOString().replace('T', ' ').substring(0, 19),
      lastEditedBy: actorName,
      // 6 visual checklist checks
      noScratches: dto.noScratches ?? true,
      dimensionsFit: dto.dimensionsFit ?? true,
      secureComponents: dto.secureComponents ?? true,
      componentAlignment: dto.componentAlignment ?? true,
      noSolderBridges: dto.noSolderBridges ?? true,
      polarityOrientation: dto.polarityOrientation ?? true,
      // Conditionals
      manualSolderingRequired: dto.manualSolderingRequired || 'No',
      componentDamageDetails: dto.componentDamageDetails || 'None',
      developerNote: dto.developerNote || 'None',
      // Programming & tests
      controllerProgramming: dto.controllerProgramming || 'Complete',
      wifiProgramming: dto.wifiProgramming || 'Complete',
      testedOk: dto.testedOk || 'Yes', // 'Yes', 'No', 'No - Note: ...'
      repairStatus: dto.repairStatus || 'No',
      frontPhoto: dto.frontPhoto || 'front_view.jpg',
      backPhoto: dto.backPhoto || 'back_view.jpg',
      dispatched: false,
      dispatchedTo: null,
      updatedAt: now.toISOString(),
    };

    if (existingIdx !== -1) {
      records[existingIdx] = recordData;
    } else {
      records.unshift(recordData);
    }

    this.writeJsonFile('testing_logs.json', records);
    return recordData;
  }

  async getTestedOkProducts() {
    const records = await this.getTestingRecords();
    return records.filter((r) => {
      const ok = (r.testedOk || '').toString().toLowerCase();
      return ok === 'yes' || ok === 'y' || ok === 'passed' || ok === 'pass' || ok === 'complete';
    });
  }

  // ─── 3. DISPATCH LOG ──────────────────────────────────────────

  async getDispatchLogs() {
    let logs = this.readJsonFile<any[]>('dispatch_logs.json', []);
    if (logs.length === 0) {
      logs = this.getInitialSampleDispatchLogs();
      this.writeJsonFile('dispatch_logs.json', logs);
    }
    return logs;
  }

  async createDispatch(dto: any, actorName = 'Admin') {
    const logs = await this.getDispatchLogs();
    const now = new Date();
    const count = logs.length + 1;
    const dispatchCode = `DSP-2026-${String(count).padStart(4, '0')}`;

    const newLog = {
      id: `disp-${Date.now()}`,
      dispatchCode,
      productId: dto.productId,
      batchNumber: dto.batchNumber || 'BATCH-20261005_110000',
      productName: dto.productName || 'Smart Industrial Control Panel',
      department: dto.department || 'Panel Department', // 'Panel Department', 'Tech Support Department', 'Finished Goods', 'Client Site'
      dispatchTime: now.toISOString().replace('T', ' ').substring(0, 19),
      dispatchedBy: actorName,
      description: dto.description || `Tested OK unit ${dto.productId} certified and routed to ${dto.department || 'Panel Department'}. Visual & Functional Pass.`,
      status: 'DISPATCHED',
      notes: dto.notes || '',
      createdAt: now.toISOString(),
    };

    logs.unshift(newLog);
    this.writeJsonFile('dispatch_logs.json', logs);

    // Mark testing record as dispatched
    const testingRecords = await this.getTestingRecords();
    const tIdx = testingRecords.findIndex((r) => r.productId === dto.productId);
    if (tIdx !== -1) {
      testingRecords[tIdx].dispatched = true;
      testingRecords[tIdx].dispatchedTo = dto.department || 'Panel Department';
      this.writeJsonFile('testing_logs.json', testingRecords);
    }

    return newLog;
  }

  // ─── 4. PANEL MANUFACTURING ASSEMBLY JOBS & QC ────────────────

  async getAssemblyJobs() {
    let jobs = this.readJsonFile<any[]>('assembly_jobs.json', []);
    if (jobs.length === 0) {
      jobs = this.getInitialSampleAssemblyJobs();
      this.writeJsonFile('assembly_jobs.json', jobs);
    }
    return jobs;
  }

  async createAssemblyJob(dto: any) {
    const jobs = await this.getAssemblyJobs();
    const count = jobs.length + 1;
    const jobId = dto.jobId || `JOB-2026-${String(count).padStart(3, '0')}`;

    const newJob = {
      id: `job-${Date.now()}`,
      jobId,
      panelType: dto.panelType || 'VFD Automation Triplex Panel',
      stage: dto.stage || 'Assembly', // Fabrication, Busbar, Assembly, Wiring, FAT Testing, Final QC
      assignedTech: dto.assignedTech || 'Sunil Pawar (Panel Wireman)',
      status: dto.status || 'In Progress',
      targetDate: dto.targetDate || new Date(Date.now() + 5 * 86400000).toISOString().split('T')[0],
      panelSerialNo: dto.panelSerialNo || `PNL-2026-${String(count).padStart(4, '0')}`,
      createdAt: new Date().toISOString(),
    };

    jobs.unshift(newJob);
    this.writeJsonFile('assembly_jobs.json', jobs);
    return newJob;
  }

  async signoffPanelQc(dto: any, actorName = 'Admin') {
    const { panelSerialNo, insulationResistancePassed, wiringContinuityTorquePassed, inspector } = dto;
    if (!panelSerialNo) {
      throw new NotFoundException('Panel Serial Number is required for QC Sign-off');
    }

    const isApproved = Boolean(insulationResistancePassed && wiringContinuityTorquePassed);

    const qcRecord = {
      id: `qc-${Date.now()}`,
      panelSerialNo,
      inspector: inspector || actorName,
      insulationResistancePassed: Boolean(insulationResistancePassed),
      wiringContinuityTorquePassed: Boolean(wiringContinuityTorquePassed),
      status: isApproved ? 'APPROVED_PASS' : 'REJECTED_FAIL',
      signoffDate: new Date().toISOString().replace('T', ' ').substring(0, 19),
      certificateCode: isApproved ? `QC-CERT-${panelSerialNo}` : null,
    };

    // Update corresponding job if exists
    const jobs = await this.getAssemblyJobs();
    const job = jobs.find((j) => j.panelSerialNo === panelSerialNo);
    if (job) {
      job.stage = isApproved ? 'Final QC' : 'Rework';
      job.status = isApproved ? 'Completed' : 'QA Hold';
      job.qcRecord = qcRecord;
      this.writeJsonFile('assembly_jobs.json', jobs);
    }

    return {
      success: isApproved,
      message: isApproved
        ? `Panel ${panelSerialNo} passed Insulation & Continuity QC. Approved by ${qcRecord.inspector}.`
        : `Panel ${panelSerialNo} failed QC criteria. Returned for wiring/insulation rectification.`,
      qcRecord,
    };
  }

  // ─── INITIAL PRELOADED DATA ───────────────────────────────────

  private getInitialSampleBatches() {
    return [
      {
        id: 'batch-1',
        batchNumber: 'BATCH-20261005_110000',
        productName: 'Automatic Triplex VFD Booster Pump Panel',
        productModel: 'SE-VFD-415V-15HP',
        startDate: '2026-10-05 11:00:00',
        expectedCompletionDate: '2026-10-12',
        meetingDate: '2026-10-05',
        assignedPersonnel: 'Rahul Verma; Sunil Pawar; Amit Deshmukh',
        notes: 'Triplex booster panel for Mahindra Horizon Towers. Strict IP55 compliance and Megger isolation required.',
        attachedDocument: 'BOM_VFD_Triplex_Rev3.xlsx',
        status: 'IN_PROGRESS',
        targetQuantity: 5,
        completedQuantity: 3,
        materials: this.getDefaultMaterialList(),
        createdBy: 'Admin',
        createdAt: '2026-10-05T11:00:00.000Z',
        updatedAt: '2026-10-07T09:00:00.000Z',
      },
      {
        id: 'batch-2',
        batchNumber: 'BATCH-20261006_143000',
        productName: 'Submersible STP Dual Automation Panel',
        productModel: 'SE-STP-PLC-10HP',
        startDate: '2026-10-06 14:30:00',
        expectedCompletionDate: '2026-10-14',
        meetingDate: '2026-10-06',
        assignedPersonnel: 'Deepak Patil; Vikram Shinde',
        notes: 'STP Panel with level controller integration and RS485 energy monitor.',
        attachedDocument: null,
        status: 'READY',
        targetQuantity: 8,
        completedQuantity: 2,
        materials: this.getDefaultMaterialList(),
        createdBy: 'Admin',
        createdAt: '2026-10-06T14:30:00.000Z',
        updatedAt: '2026-10-06T14:30:00.000Z',
      },
      {
        id: 'batch-3',
        batchNumber: 'BATCH-20261007_091500',
        productName: 'Smart IoT PLC Gateway Unit (DIN Rail)',
        productModel: 'SE-IOT-GATEWAY-V2',
        startDate: '2026-10-07 09:15:00',
        expectedCompletionDate: '2026-10-10',
        meetingDate: '2026-10-07',
        assignedPersonnel: 'Aditya Kulkarni; Kavita Nair',
        notes: 'Firmware flashing v2.4 with 4G LTE fallback. Visual soldering inspection critical.',
        attachedDocument: null,
        status: 'SCHEDULED',
        targetQuantity: 25,
        completedQuantity: 0,
        materials: this.getDefaultMaterialList(),
        createdBy: 'Admin',
        createdAt: '2026-10-07T09:15:00.000Z',
        updatedAt: '2026-10-07T09:15:00.000Z',
      },
    ];
  }

  private getDefaultMaterialList() {
    return [
      {
        srNo: 1,
        category: 'Switchgear',
        partName: '4-Pole Main Incomer MCB',
        value: '63A 10kA C-Curve',
        package: 'DIN Rail 4-Module',
        tolerance: '1%',
        quantity: 5,
        qty: 5,
        rate: 1850,
        totalPrice: 9250,
        make: 'Schneider Electric',
        poSelect: true,
        pcbCheck: false,
        receiveCheck: true,
      },
      {
        srNo: 2,
        category: 'Drives',
        partName: 'Variable Frequency Drive (VFD)',
        value: '7.5 kW / 10 HP 415V',
        package: 'Panel Mount IP20',
        tolerance: '1%',
        quantity: 15,
        qty: 15,
        rate: 28500,
        totalPrice: 427500,
        make: 'Danfoss / ABB',
        poSelect: true,
        pcbCheck: false,
        receiveCheck: true,
      },
      {
        srNo: 3,
        category: 'Switchgear',
        partName: 'Power Contactor 3-Pole',
        value: '18A AC-3 230V Coil',
        package: 'DIN Rail',
        tolerance: '1%',
        quantity: 15,
        qty: 15,
        rate: 1420,
        totalPrice: 21300,
        make: 'L&T',
        poSelect: true,
        pcbCheck: false,
        receiveCheck: true,
      },
      {
        srNo: 4,
        category: 'Control & Automation',
        partName: 'Programmable Logic Controller (PLC)',
        value: '14 DI / 10 DO Relay RS485',
        package: 'DIN Rail Mount',
        tolerance: '1%',
        quantity: 5,
        qty: 5,
        rate: 16500,
        totalPrice: 82500,
        make: 'Delta / Siemens',
        poSelect: true,
        pcbCheck: true,
        receiveCheck: true,
      },
      {
        srNo: 5,
        category: 'Power Supply',
        partName: 'SMPS 24V DC Power Supply',
        value: '24V DC 5A 120W',
        package: 'Metal DIN Rail',
        tolerance: '1%',
        quantity: 5,
        qty: 5,
        rate: 2200,
        totalPrice: 11000,
        make: 'MeanWell',
        poSelect: true,
        pcbCheck: true,
        receiveCheck: true,
      },
      {
        srNo: 6,
        category: 'Instrumentation',
        partName: 'Digital Multifunction Energy Meter',
        value: 'Class 1.0 RS485 Modbus',
        package: '96x96mm Flush Mount',
        tolerance: '1%',
        quantity: 5,
        qty: 5,
        rate: 4500,
        totalPrice: 22500,
        make: 'Schneider Conzerv',
        poSelect: true,
        pcbCheck: false,
        receiveCheck: false,
      },
      {
        srNo: 7,
        category: 'Terminals',
        partName: 'Feed-Through Terminal Blocks',
        value: '4 sq mm 32A Grey',
        package: 'DIN 35 Rail',
        tolerance: '1%',
        quantity: 150,
        qty: 150,
        rate: 28,
        totalPrice: 4200,
        make: 'Wago / Elmex',
        poSelect: true,
        pcbCheck: false,
        receiveCheck: true,
      },
      {
        srNo: 8,
        category: 'Indications & Controls',
        partName: 'LED Pilot Indicating Lamps 22mm',
        value: '230V AC R/Y/B/G',
        package: '22.5mm Cutout',
        tolerance: '1%',
        quantity: 30,
        qty: 30,
        rate: 110,
        totalPrice: 3300,
        make: 'Teknic',
        poSelect: true,
        pcbCheck: false,
        receiveCheck: true,
      },
    ];
  }

  private getInitialSampleTestingRecords() {
    return [
      {
        id: 'test-1',
        productId: 'PRD-2026-VFD-0101',
        batchId: 'batch-1',
        batchNumber: 'BATCH-20261005_110000',
        productName: 'Automatic Triplex VFD Booster Pump Panel',
        userName: 'Pooja Sonawane (Admin)',
        timestamp: '2026-10-06 16:20:10',
        lastEditedBy: 'Pooja Sonawane',
        noScratches: true,
        dimensionsFit: true,
        secureComponents: true,
        componentAlignment: true,
        noSolderBridges: true,
        polarityOrientation: true,
        manualSolderingRequired: 'No',
        componentDamageDetails: 'None',
        developerNote: 'Passed FAT bench testing with simulated 3-pump load profile.',
        controllerProgramming: 'Complete',
        wifiProgramming: 'Complete',
        testedOk: 'Yes',
        repairStatus: 'No',
        frontPhoto: 'front_view.jpg',
        backPhoto: 'back_view.jpg',
        dispatched: true,
        dispatchedTo: 'Panel Department',
        updatedAt: '2026-10-06T16:20:10.000Z',
      },
      {
        id: 'test-2',
        productId: 'PRD-2026-VFD-0102',
        batchId: 'batch-1',
        batchNumber: 'BATCH-20261005_110000',
        productName: 'Automatic Triplex VFD Booster Pump Panel',
        userName: 'Deepak Patil',
        timestamp: '2026-10-07 10:15:42',
        lastEditedBy: 'Deepak Patil',
        noScratches: true,
        dimensionsFit: true,
        secureComponents: true,
        componentAlignment: true,
        noSolderBridges: true,
        polarityOrientation: true,
        manualSolderingRequired: 'No',
        componentDamageDetails: 'None',
        developerNote: 'Firmware flashed cleanly. Torque tested at 2.5 N-m.',
        controllerProgramming: 'Complete',
        wifiProgramming: 'Complete',
        testedOk: 'Yes',
        repairStatus: 'No',
        frontPhoto: 'front_view.jpg',
        backPhoto: 'back_view.jpg',
        dispatched: false,
        dispatchedTo: null,
        updatedAt: '2026-10-07T10:15:42.000Z',
      },
      {
        id: 'test-3',
        productId: 'PRD-2026-VFD-0103',
        batchId: 'batch-1',
        batchNumber: 'BATCH-20261005_110000',
        productName: 'Automatic Triplex VFD Booster Pump Panel',
        userName: 'Sunil Pawar',
        timestamp: '2026-10-07 11:45:00',
        lastEditedBy: 'Sunil Pawar',
        noScratches: true,
        dimensionsFit: true,
        secureComponents: true,
        componentAlignment: true,
        noSolderBridges: true,
        polarityOrientation: true,
        manualSolderingRequired: 'No',
        componentDamageDetails: 'None',
        developerNote: 'Ready for customer FAT inspection.',
        controllerProgramming: 'Complete',
        wifiProgramming: 'Complete',
        testedOk: 'Yes',
        repairStatus: 'No',
        frontPhoto: 'front_view.jpg',
        backPhoto: 'back_view.jpg',
        dispatched: false,
        dispatchedTo: null,
        updatedAt: '2026-10-07T11:45:00.000Z',
      },
      {
        id: 'test-4',
        productId: 'PRD-2026-STP-0201',
        batchId: 'batch-2',
        batchNumber: 'BATCH-20261006_143000',
        productName: 'Submersible STP Dual Automation Panel',
        userName: 'Amit Deshmukh',
        timestamp: '2026-10-07 14:10:20',
        lastEditedBy: 'Amit Deshmukh',
        noScratches: true,
        dimensionsFit: true,
        secureComponents: true,
        componentAlignment: true,
        noSolderBridges: true,
        polarityOrientation: true,
        manualSolderingRequired: 'No',
        componentDamageDetails: 'None',
        developerNote: 'All contactors calibrated.',
        controllerProgramming: 'Complete',
        wifiProgramming: 'Complete',
        testedOk: 'Yes',
        repairStatus: 'No',
        frontPhoto: 'front_view.jpg',
        backPhoto: 'back_view.jpg',
        dispatched: false,
        dispatchedTo: null,
        updatedAt: '2026-10-07T14:10:20.000Z',
      },
    ];
  }

  private getInitialSampleDispatchLogs() {
    return [
      {
        id: 'disp-1',
        dispatchCode: 'DSP-2026-0001',
        productId: 'PRD-2026-VFD-0101',
        batchNumber: 'BATCH-20261005_110000',
        productName: 'Automatic Triplex VFD Booster Pump Panel',
        department: 'Panel Department',
        dispatchTime: '2026-10-06 17:05:00',
        dispatchedBy: 'Pooja Sonawane',
        description: 'Unit PRD-2026-VFD-0101 Tested OK. Dispatched to Panel Department for final enclosure powder-coat inspection & gland plate fitting.',
        status: 'DISPATCHED',
        createdAt: '2026-10-06T17:05:00.000Z',
      },
      {
        id: 'disp-2',
        dispatchCode: 'DSP-2026-0002',
        productId: 'PRD-2026-IOT-099',
        batchNumber: 'BATCH-20261004_093000',
        productName: 'Smart IoT PLC Gateway Unit',
        department: 'Tech Support Department',
        dispatchTime: '2026-10-05 15:30:00',
        dispatchedBy: 'Aditya Kulkarni',
        description: 'Unit PRD-2026-IOT-099 tested OK. Dispatched to Tech Support Department for cloud registration and client telemetry provisioning.',
        status: 'DISPATCHED',
        createdAt: '2026-10-05T15:30:00.000Z',
      },
    ];
  }

  private getInitialSampleAssemblyJobs() {
    return [
      {
        id: 'job-1',
        jobId: 'JOB-2026-001',
        panelType: 'Triplex VFD Booster Control Panel',
        stage: 'Assembly',
        assignedTech: 'Sunil Pawar (Senior Wireman)',
        status: 'In Progress',
        targetDate: '2026-10-12',
        panelSerialNo: 'PNL-2026-0081',
        createdAt: '2026-10-05T10:00:00.000Z',
      },
      {
        id: 'job-2',
        jobId: 'JOB-2026-002',
        panelType: 'Submersible Sewage Pump Automation Panel',
        stage: 'Wiring',
        assignedTech: 'Amit Deshmukh (Wireman)',
        status: 'In Progress',
        targetDate: '2026-10-14',
        panelSerialNo: 'PNL-2026-0082',
        createdAt: '2026-10-06T11:00:00.000Z',
      },
      {
        id: 'job-3',
        jobId: 'JOB-2026-003',
        panelType: 'HVAC Air Handling Unit Control Panel',
        stage: 'FAT Testing',
        assignedTech: 'Deepak Patil (QC Engineer)',
        status: 'In Progress',
        targetDate: '2026-10-10',
        panelSerialNo: 'PNL-2026-0083',
        createdAt: '2026-10-04T09:00:00.000Z',
      },
    ];
  }
}

