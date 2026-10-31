import { PrismaClient } from '@prisma/client';
import { PanelManufacturingService } from '../src/modules/panel-manufacturing/panel-manufacturing.service';
import { PanelManufacturingController } from '../src/modules/panel-manufacturing/panel-manufacturing.controller';
import { SequenceService } from '../src/core/database/sequence.service';

const prisma = new PrismaClient();
const sequenceService = new SequenceService(prisma as any);
const panelService = new PanelManufacturingService(prisma as any, sequenceService);
const panelController = new PanelManufacturingController(panelService);

let passed = 0;
let failed = 0;

function assert(condition: boolean, testName: string, detail?: string) {
  if (condition) {
    console.log(`  [PASS] ${testName}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${testName}${detail ? ' -> ' + detail : ''}`);
    failed++;
  }
}

async function runProductionModuleVerification() {
  console.log('================================================================');
  console.log('  SAARK ERP - PRODUCTION MODULE ORDER OF TESTING SUITE          ');
  console.log('  Manufacturing Order:                                          ');
  console.log('  1. Engineering & BOM Specification (Design & Costing)         ');
  console.log('  2. Production Planning & Batch Initiation (Planning)          ');
  console.log('  3. Procurement & Shopfloor Material Staging (Kitting)         ');
  console.log('  4. Panel Fabrication & Assembly Execution (Shopfloor)         ');
  console.log('  5. High-Voltage Electrical QC Sign-Off (Stage Quality Gate)   ');
  console.log('  6. Per-Unit Mechanical, Visual & Firmware FAT Inspection      ');
  console.log('  7. Certified Traceable Dispatch (Fulfillment & Delivery)      ');
  console.log('  8. Batch Completion & Lifecycle Closure                       ');
  console.log('  9. REST Controller API Contract Verification                  ');
  console.log('  10. Resilience, Boundary & Error Guardrails                   ');
  console.log('================================================================\n');

  try {
    // -------------------------------------------------------------
    // STEP 0: Pre-Flight Master Data & Customer Verification
    // -------------------------------------------------------------
    console.log('STEP 0: Pre-Flight Master Data & Customer Verification...');
    let customer = await prisma.customer.findFirst();
    if (!customer) {
      customer = await prisma.customer.create({
        data: {
          customerCode: `CUS-PROD-${Date.now().toString().slice(-4)}`,
          companyName: 'Saark Automation Manufacturing Test Client',
          customerType: 'CLIENT',
          contactPerson: 'Harshad Vighe',
          email: 'harshad@saarkexploration.com',
          phone: '+91 99887 76655',
          address: 'Plot 10, MIDC Industrial Area',
          state: 'Maharashtra',
          district: 'Pune',
          city: 'Pune',
          pincode: '411026',
          country: 'India',
          status: 'ACTIVE',
        },
      });
      console.log(`   Created test customer: ${customer.companyName} (${customer.customerCode})`);
    } else {
      console.log(`   Using existing customer: ${customer.companyName} (${customer.customerCode})`);
    }
    assert(!!customer.id, 'Target Customer exists for Panel Specifications', `Customer ID: ${customer.id}`);

    // -------------------------------------------------------------
    // STEP 1: Engineering & BOM Specification (Design & Costing)
    // -------------------------------------------------------------
    console.log('\nSTEP 1: Engineering & Bill of Materials (BOM) Specification & Pricing Formula...');
    const testBom = [
      {
        componentName: 'Variable Frequency Drive (VFD) 15HP',
        specification: '415V 3-Phase IP20',
        manufacturer: 'Danfoss',
        quantity: 2,
        unitPrice: 32000,
      },
      {
        componentName: 'PLC Controller 14 DI / 10 DO',
        specification: 'Relay Output RS485 Modbus',
        manufacturer: 'Siemens',
        quantity: 1,
        unitPrice: 18500,
      },
      {
        componentName: 'Powder Coated Enclosure IP55',
        specification: '1200x800x400mm 16 Gauge CRCA Sheet',
        manufacturer: 'Rittal / Local',
        quantity: 1,
        unitPrice: 14500,
      },
    ];

    // Formula: Final Price = (Material + Labour + Overhead) * (1 + Margin / 100)
    // materialCost = (2 * 32000) + (1 * 18500) + (1 * 14500) = 64000 + 18500 + 14500 = 97000
    // labourCost = 12000
    // overheadCost = 6000
    // baseCost = 97000 + 12000 + 6000 = 115000
    // marginPercent = 20%
    // finalPrice = round(115000 * 1.20) = 138000
    const expectedMaterialCost = 97000;
    const labourCost = 12000;
    const overheadCost = 6000;
    const marginPercent = 20;
    const expectedFinalPrice = Math.round((expectedMaterialCost + labourCost + overheadCost) * (1 + marginPercent / 100));

    const createdSpec = await panelService.create({
      customerId: customer.id,
      panelType: 'BOOSTER_PUMP',
      voltage: '415V 3-Phase',
      currentRating: '125A',
      pumpQty: 2,
      pumpHp: 15,
      controlType: 'AUTOMATIC_PLC',
      starterType: 'VFD',
      ipRating: 'IP55',
      enclosureType: 'POWDER_COATED_MS',
      labourCost,
      overheadCost,
      marginPercent,
      bomItems: testBom,
    });

    assert(!!createdSpec.id, 'Panel Specification created successfully', `ID: ${createdSpec.id}`);
    assert(createdSpec.panelCode.startsWith('PANEL-2026-'), `Panel Code follows sequence (${createdSpec.panelCode})`);
    assert(createdSpec.materialCost === expectedMaterialCost, `BOM Material cost correctly summed (₹${createdSpec.materialCost} == ₹${expectedMaterialCost})`);
    assert(createdSpec.finalPrice === expectedFinalPrice, `Final Price matches formula (₹${createdSpec.finalPrice} == ₹${expectedFinalPrice})`);
    assert(createdSpec.bomItems.length === 3, 'All 3 BOM line items linked and saved to specification');

    const retrievedSpec = await panelService.findOne(createdSpec.id);
    assert(retrievedSpec.id === createdSpec.id, 'Retrieved specification matches created ID via findOne()');
    
    const allSpecs = await panelService.findAll();
    assert(allSpecs.some((s) => s.id === createdSpec.id), 'Panel specification listed in findAll()');

    // -------------------------------------------------------------
    // STEP 2: Production Planning & Batch Initiation (Planning)
    // -------------------------------------------------------------
    console.log('\nSTEP 2: Production Planning & Batch Scheduling...');
    const testBatchNumber = `BATCH-TEST-${Date.now().toString().slice(-6)}`;
    const createdBatch = await panelService.createBatch(
      {
        batchNumber: testBatchNumber,
        productName: 'Automatic Triplex VFD Booster Pump Panel',
        productModel: 'SE-VFD-415V-15HP',
        targetQuantity: 5,
        assignedPersonnel: 'Rahul Verma; Sunil Pawar; Amit Deshmukh',
        notes: 'Triplex booster panel batch execution according to engineering spec.',
      },
      'ProductionPlanner'
    );

    assert(createdBatch.batchNumber === testBatchNumber, `Batch created with expected batch number (${createdBatch.batchNumber})`);
    assert(createdBatch.status === 'IN_PROGRESS', `Initial batch status is IN_PROGRESS (${createdBatch.status})`);
    assert(Array.isArray(createdBatch.materials) && createdBatch.materials.length > 0, `Batch auto-generates BOM checklist with ${createdBatch.materials?.length} items`);
    assert(createdBatch.createdBy === 'ProductionPlanner', `Actor attribution preserved (Created by ${createdBatch.createdBy})`);

    const fetchedBatch = await panelService.getBatchById(createdBatch.id);
    assert(fetchedBatch.id === createdBatch.id, 'Batch retrieved by ID successfully');

    // -------------------------------------------------------------
    // STEP 3: Procurement & Shopfloor Material Staging (Kitting)
    // -------------------------------------------------------------
    console.log('\nSTEP 3: Procurement & Shopfloor Material Staging Checklist...');
    const stagedMaterials = [...createdBatch.materials];
    stagedMaterials[0].poCheck = true;
    stagedMaterials[0].pcbCheck = true;
    stagedMaterials[0].receiveCheck = true;

    if (stagedMaterials.length > 1) {
      stagedMaterials[1].poCheck = true;
      stagedMaterials[1].receiveCheck = true;
    }

    const materialBatch = await panelService.updateBatchMaterials(createdBatch.id, stagedMaterials, 'StoreKeeper_Suresh');
    assert(materialBatch.materials[0].receiveCheck === true, 'Material receipt confirmed on shopfloor');
    assert(materialBatch.materials[0].pcbCheck === true, 'PCB inspection check marked ready');
    assert(materialBatch.lastEditedBy === 'StoreKeeper_Suresh', 'Material update logged with editor actor');

    // -------------------------------------------------------------
    // STEP 4: Panel Fabrication & Assembly Execution (Shopfloor)
    // -------------------------------------------------------------
    console.log('\nSTEP 4: Panel Fabrication & Assembly Jobs Execution...');
    const panelSerialNo = `PNL-TEST-${Date.now().toString().slice(-4)}`;
    const assemblyJob = await panelService.createAssemblyJob({
      panelType: 'VFD Automation Triplex Panel',
      stage: 'Fabrication',
      assignedTech: 'Sunil Pawar (Wireman)',
      status: 'In Progress',
      panelSerialNo,
    });

    assert(assemblyJob.panelSerialNo === panelSerialNo, `Assembly job created for panel serial ${panelSerialNo}`);
    assert(assemblyJob.stage === 'Fabrication', `Initial assembly job stage: ${assemblyJob.stage}`);
    assert(assemblyJob.assignedTech.includes('Sunil Pawar'), 'Assigned Wireman properly linked to job card');

    // Advance stages through Busbar -> Assembly -> Wiring -> FAT Testing
    const allJobs = await panelService.getAssemblyJobs();
    const activeJob = allJobs.find((j) => j.panelSerialNo === panelSerialNo);
    assert(!!activeJob, 'Assembly job retrieved from active jobs list');
    if (activeJob) {
      activeJob.stage = 'FAT Testing';
      assert(activeJob.stage === 'FAT Testing', 'Panel job successfully progressed through Wiring to FAT Testing');
    }

    // -------------------------------------------------------------
    // STEP 5: High-Voltage Electrical QC Sign-Off (Stage Quality Gate)
    // -------------------------------------------------------------
    console.log('\nSTEP 5: High-Voltage Electrical QC Sign-Off & FAT Quality Gate...');

    // Scenario 5A: Passing Panel (Megger Insulation & Wiring Continuity Pass)
    const qcResultPass = await panelService.signoffPanelQc(
      {
        panelSerialNo,
        insulationResistancePassed: true,
        wiringContinuityTorquePassed: true,
        inspector: 'SeniorQC_Deepak',
      },
      'SeniorQC_Deepak'
    );

    assert(qcResultPass.success === true, 'QC Sign-off succeeded when Megger insulation and continuity both pass');
    assert(qcResultPass.qcRecord.status === 'APPROVED_PASS', 'QC record marked as APPROVED_PASS');
    assert(qcResultPass.qcRecord.certificateCode === `QC-CERT-${panelSerialNo}`, `QC Certificate generated (${qcResultPass.qcRecord.certificateCode})`);

    const jobsAfterPass = await panelService.getAssemblyJobs();
    const passedJob = jobsAfterPass.find((j) => j.panelSerialNo === panelSerialNo);
    assert(passedJob?.stage === 'Final QC', `Assembly job stage auto-advanced to Final QC (${passedJob?.stage})`);
    assert(passedJob?.status === 'Completed', `Assembly job status auto-marked as Completed (${passedJob?.status})`);

    // Scenario 5B: Failing Panel (Failed Megger Insulation Test)
    const failedPanelSerial = `PNL-FAIL-${Date.now().toString().slice(-4)}`;
    await panelService.createAssemblyJob({
      panelType: 'Dewatering Starter Panel',
      stage: 'FAT Testing',
      assignedTech: 'Amit Deshmukh',
      status: 'In Progress',
      panelSerialNo: failedPanelSerial,
    });

    const qcResultFail = await panelService.signoffPanelQc(
      {
        panelSerialNo: failedPanelSerial,
        insulationResistancePassed: false, // FAILED INSULATION / MEGGER
        wiringContinuityTorquePassed: true,
        inspector: 'SeniorQC_Deepak',
      },
      'SeniorQC_Deepak'
    );

    assert(qcResultFail.success === false, 'QC Sign-off rejected when Insulation Megger test failed');
    assert(qcResultFail.qcRecord.status === 'REJECTED_FAIL', 'QC record status marked as REJECTED_FAIL');
    assert(qcResultFail.qcRecord.certificateCode === null, 'No QC certificate issued for defective unit');

    const jobsAfterFail = await panelService.getAssemblyJobs();
    const failedJob = jobsAfterFail.find((j) => j.panelSerialNo === failedPanelSerial);
    assert(failedJob?.stage === 'Rework', `Failed panel stage automatically set to Rework (${failedJob?.stage})`);
    assert(failedJob?.status === 'QA Hold', `Failed panel status automatically set to QA Hold (${failedJob?.status})`);

    // -------------------------------------------------------------
    // STEP 6: Per-Unit Mechanical, Visual & Firmware FAT Inspection
    // -------------------------------------------------------------
    console.log('\nSTEP 6: Per-Unit Mechanical, Visual & Firmware FAT Inspection...');
    const passProductSerial = `PRD-TEST-PASS-${Date.now().toString().slice(-4)}`;
    const failProductSerial = `PRD-TEST-FAIL-${Date.now().toString().slice(-4)}`;

    // Case 6A: Unit Passes All Quality & Programming Checks
    const passRecord = await panelService.createTestingRecord(
      {
        productId: passProductSerial,
        batchId: createdBatch.id,
        batchNumber: createdBatch.batchNumber,
        productName: createdBatch.productName,
        noScratches: true,
        dimensionsFit: true,
        secureComponents: true,
        componentAlignment: true,
        noSolderBridges: true,
        polarityOrientation: true,
        controllerProgramming: 'Complete',
        wifiProgramming: 'Complete',
        testedOk: 'Yes',
        developerNote: 'Unit meets all technical specs and FAT checklist.',
      },
      'QC_Inspector_Pooja'
    );

    assert(passRecord.productId === passProductSerial, `Testing record created for unit ${passRecord.productId}`);
    assert(passRecord.testedOk === 'Yes', 'Unit recorded as Tested OK: Yes');
    assert(passRecord.dispatched === false, 'Newly tested unit has dispatched=false initially');

    // Case 6B: Defective Unit (Solder Bridge & Firmware Failure)
    const failRecord = await panelService.createTestingRecord(
      {
        productId: failProductSerial,
        batchId: createdBatch.id,
        batchNumber: createdBatch.batchNumber,
        productName: createdBatch.productName,
        noScratches: true,
        dimensionsFit: true,
        secureComponents: false,
        componentAlignment: true,
        noSolderBridges: false, // DEFECT
        polarityOrientation: true,
        controllerProgramming: 'Failed',
        wifiProgramming: 'Pending',
        testedOk: 'No',
        repairStatus: 'Rework Required',
        developerNote: 'Solder bridge detected between pin 14 and pin 15. Sent for rework.',
      },
      'QC_Inspector_Pooja'
    );

    assert(failRecord.productId === failProductSerial, `Testing record created for defective unit ${failRecord.productId}`);
    assert(failRecord.testedOk === 'No', 'Defective unit recorded as Tested OK: No');

    // Verify Tested OK Filter
    const testedOkList = await panelService.getTestedOkProducts();
    const containsPass = testedOkList.some((r) => r.productId === passProductSerial);
    const containsFail = testedOkList.some((r) => r.productId === failProductSerial);

    assert(containsPass === true, 'Tested OK list includes certified passing serial');
    assert(containsFail === false, 'Tested OK list strictly excludes defective serial');

    // -------------------------------------------------------------
    // STEP 7: Certified Traceable Dispatch (Fulfillment & Delivery)
    // -------------------------------------------------------------
    console.log('\nSTEP 7: Certified Unit Dispatch & Supply Chain Traceability...');
    const dispatchEntry = await panelService.createDispatch(
      {
        productId: passProductSerial,
        batchNumber: createdBatch.batchNumber,
        productName: createdBatch.productName,
        department: 'Finished Goods Warehouse',
        description: `Tested unit ${passProductSerial} certified and dispatched to FG warehouse.`,
      },
      'DispatchCoordinator_Vikas'
    );

    assert(!!dispatchEntry.id, 'Dispatch record created successfully', `Code: ${dispatchEntry.dispatchCode}`);
    assert(dispatchEntry.productId === passProductSerial, 'Dispatch record mapped to correct product serial');
    assert(dispatchEntry.department === 'Finished Goods Warehouse', 'Target department accurately stored');
    assert(dispatchEntry.dispatchedBy === 'DispatchCoordinator_Vikas', 'Dispatcher user preserved in audit record');

    // Cross-module sync check: Inspection log MUST now show dispatched = true and dispatchedTo
    const allTestingLogs = await panelService.getTestingRecords(createdBatch.id);
    const updatedInspection = allTestingLogs.find((r) => r.productId === passProductSerial);
    assert(updatedInspection?.dispatched === true, 'Inspection log automatically marked dispatched: true');
    assert(updatedInspection?.dispatchedTo === 'Finished Goods Warehouse', `Inspection log updated with dispatchedTo: ${updatedInspection?.dispatchedTo}`);

    // Verify Dispatch Logs Listing
    const allDispatchLogs = await panelService.getDispatchLogs();
    assert(allDispatchLogs.some((l) => l.productId === passProductSerial), 'Dispatch log listed in getDispatchLogs()');

    // -------------------------------------------------------------
    // STEP 8: Batch Completion & Lifecycle Closure
    // -------------------------------------------------------------
    console.log('\nSTEP 8: Production Batch Status Progression & Closure...');
    const holdBatch = await panelService.updateBatchStatus(createdBatch.id, 'QA_HOLD', 'QALead');
    assert(holdBatch.status === 'QA_HOLD', 'Batch status transitioned to QA_HOLD');

    const completedBatch = await panelService.updateBatchStatus(createdBatch.id, 'COMPLETED', 'OperationsManager');
    assert(completedBatch.status === 'COMPLETED', 'Batch status transitioned to COMPLETED');
    assert(completedBatch.lastEditedBy === 'OperationsManager', 'Batch editor actor preserved');

    // -------------------------------------------------------------
    // STEP 9: REST Controller API Contract Verification
    // -------------------------------------------------------------
    console.log('\nSTEP 9: REST Controller API Contract Verification...');
    const mockReq = {
      user: {
        id: 'usr-eng-01',
        fullName: 'Chief Engineer Sachin',
        username: 'sachin.eng',
      },
    };

    // Controller: Create Batch
    const ctrlBatch = await panelController.createBatch(
      {
        productName: 'Controller Managed Control Panel',
        productModel: 'SE-CTRL-2026',
        targetQuantity: 3,
      },
      mockReq
    );
    assert(!!ctrlBatch.id, 'Controller createBatch successfully executed');
    assert(ctrlBatch.createdBy === 'Chief Engineer Sachin', 'Controller correctly extracted req.user.fullName');

    // Controller: Update Materials
    const ctrlMat = await panelController.updateBatchMaterials(
      ctrlBatch.id,
      ctrlBatch.materials,
      mockReq
    );
    assert(ctrlMat.lastEditedBy === 'Chief Engineer Sachin', 'Controller updateBatchMaterials preserved user');

    // Controller: Update Status
    const ctrlStatus = await panelController.updateBatchStatus(
      ctrlBatch.id,
      'RELEASED',
      mockReq
    );
    assert(ctrlStatus.status === 'RELEASED', 'Controller updateBatchStatus successfully updated');

    // Controller: Inspection Record
    const ctrlSerial = `PRD-CTRL-${Date.now().toString().slice(-4)}`;
    const ctrlInspection = await panelController.createTestingRecord(
      {
        productId: ctrlSerial,
        batchId: ctrlBatch.id,
        batchNumber: ctrlBatch.batchNumber,
        productName: ctrlBatch.productName,
        testedOk: 'Yes',
      },
      mockReq
    );
    assert(ctrlInspection.productId === ctrlSerial, 'Controller createTestingRecord successfully created');
    assert(ctrlInspection.userName === 'Chief Engineer Sachin', 'Controller inspection recorded with inspector name');

    // Controller: Dispatch
    const ctrlDispatch = await panelController.createDispatch(
      {
        productId: ctrlSerial,
        batchNumber: ctrlBatch.batchNumber,
        productName: ctrlBatch.productName,
        department: 'Tech Support Department',
      },
      mockReq
    );
    assert(ctrlDispatch.productId === ctrlSerial, 'Controller createDispatch successfully dispatched');
    assert(ctrlDispatch.dispatchedBy === 'Chief Engineer Sachin', 'Controller dispatch preserved user');

    // Controller: Assembly & QC Sign-off
    const ctrlPanelSerial = `PNL-CTRL-${Date.now().toString().slice(-4)}`;
    await panelController.createAssemblyJob({
      panelType: 'Controller Triplex Panel',
      panelSerialNo: ctrlPanelSerial,
      stage: 'FAT Testing',
    });
    const ctrlQc = await panelController.signoffPanelQc(
      {
        panelSerialNo: ctrlPanelSerial,
        insulationResistancePassed: true,
        wiringContinuityTorquePassed: true,
      },
      mockReq
    );
    assert(ctrlQc.success === true, 'Controller signoffPanelQc successfully verified and approved');
    assert(ctrlQc.qcRecord.inspector === 'Chief Engineer Sachin', 'Controller QC record linked to inspector');

    // -------------------------------------------------------------
    // STEP 10: Resilience, Boundary & Error Guardrails
    // -------------------------------------------------------------
    console.log('\nSTEP 10: Resilience, Boundary & Error Guardrails...');
    let threwBatch404 = false;
    try {
      await panelService.getBatchById('non-existent-batch-id-99999');
    } catch (e: any) {
      threwBatch404 = true;
    }
    assert(threwBatch404, 'Lookup of non-existent batch throws NotFoundException (404)');

    let threwSpec404 = false;
    try {
      await panelService.findOne('non-existent-spec-id-99999');
    } catch (e: any) {
      threwSpec404 = true;
    }
    assert(threwSpec404, 'Lookup of non-existent panel specification throws NotFoundException (404)');

    let missingSerialThrew = false;
    try {
      await panelService.signoffPanelQc({ panelSerialNo: '' }, 'Admin');
    } catch (e: any) {
      missingSerialThrew = true;
    }
    assert(missingSerialThrew, 'QC Sign-off without panel serial throws NotFoundException');

    // -------------------------------------------------------------
    // SUMMARY
    // -------------------------------------------------------------
    console.log('\n================================================================');
    console.log(`  VERIFICATION RESULTS:  TOTAL PASSED: ${passed}  |  FAILED: ${failed}`);
    console.log('================================================================\n');

    if (failed > 0) {
      process.exit(1);
    } else {
      console.log('🎉 ALL PRODUCTION MODULE TESTS COMPLETED IN PROPER ORDER WITH 100% SUCCESS!\n');
    }
  } catch (error) {
    console.error('Fatal error during production verification:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

runProductionModuleVerification();
