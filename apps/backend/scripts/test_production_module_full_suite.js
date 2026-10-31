const http = require('http');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'saark_erp_production_jwt_secret_key_2026_x98123';
const BASE_URL = 'http://localhost:3000';

let authToken = '';

function request(method, pathName, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(pathName, BASE_URL);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Authorization': `Bearer ${authToken}`,
        ...headers,
      },
    };

    let bodyData = null;
    if (data && typeof data === 'object') {
      bodyData = JSON.stringify(data);
      options.headers['Content-Type'] = 'application/json';
      options.headers['Content-Length'] = Buffer.byteLength(bodyData);
    }

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : null;
          resolve({ status: res.statusCode, headers: res.headers, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, raw: body });
        }
      });
    });

    req.on('error', reject);
    if (bodyData) req.write(bodyData);
    req.end();
  });
}

async function runSuite() {
  console.log('================================================================');
  console.log('SAARK ERP: PRODUCTION MODULE FULL VERIFICATION SUITE');
  console.log('================================================================');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✅ PASS: ${message}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${message}`);
      failed++;
    }
  }

  try {
    const adminUser = await prisma.user.findFirst({
      where: { email: 'admin@saark.in' },
    });
    if (!adminUser) throw new Error('Admin user not found');
    authToken = jwt.sign(
      { sub: adminUser.id, email: adminUser.email, username: adminUser.username },
      JWT_SECRET,
      { expiresIn: '1h' }
    );

    // TEST 1: Get Existing Batches
    console.log('\n--- 1. Existing Production Batches Directory ---');
    const batchesRes = await request('GET', '/api/v1/panel-manufacturing/batches');
    assert(batchesRes.status === 200, 'Batches endpoint returned HTTP 200');
    const batchList = batchesRes.data?.data || batchesRes.data;
    assert(Array.isArray(batchList) && batchList.length > 0, `Batches retrieved: ${batchList.length} batches`);

    // TEST 2: + New Production Start (Batch Initialization)
    console.log('\n--- 2. + New Production Start (Batch Initialization) ---');
    const timestamp = Date.now();
    const newBatchNo = `BATCH-TEST-${timestamp.toString().slice(-6)}`;
    const createBatchRes = await request('POST', '/api/v1/panel-manufacturing/batches', {
      batchNumber: newBatchNo,
      productName: 'Automatic Triplex VFD Booster Pump Panel',
      productModel: 'SE-VFD-415V-15HP',
      productFeatures: 'Triplex VFD Automation, IP55 Enclosure, Modbus RS485 & Wi-Fi IoT Gateway, Phase Reversal Protection',
      startDate: '2026-10-23 09:30:00',
      expectedCompletionDate: '2026-10-30',
      meetingDate: '2026-10-23',
      assignedPersonnel: 'Rahul Verma; Sunil Pawar; Amit Deshmukh',
      notes: 'High-priority manufacturing batch. Ensure wiring torque standards and FAT isolation verification.',
      targetQuantity: 5,
    });
    assert(createBatchRes.status === 201 || createBatchRes.status === 200, `Batch created HTTP ${createBatchRes.status}`);
    const createdBatch = createBatchRes.data?.data || createBatchRes.data;
    assert(createdBatch?.batchNumber === newBatchNo, `Created batch matches number: ${newBatchNo}`);

    // TEST 3: BOM Checklist & Component Readiness Tracking
    console.log('\n--- 3. BOM Checklist & Component Readiness Tracking ---');
    const updatedMaterials = [
      {
        itemNumber: 1,
        componentName: 'Variable Frequency Drive (VFD) 11kW',
        description: 'Fuji / ABB 11kW 415V 3-Phase Inverter',
        qty: 3,
        unit: 'NOS',
        poPlaced: true,
        pcbOrdered: true,
        received: true,
      },
      {
        itemNumber: 2,
        componentName: 'Molded Case Circuit Breaker (MCCB) 63A',
        description: 'Schneider 4P 63A 36kA Incomer',
        qty: 1,
        unit: 'NOS',
        poPlaced: true,
        pcbOrdered: false,
        received: true,
      },
      {
        itemNumber: 3,
        componentName: 'IoT Gateway Controller PCB Rev 2.4',
        description: 'ESP32 Wi-Fi + RS485 Modbus Telemetry Board',
        qty: 1,
        unit: 'NOS',
        poPlaced: true,
        pcbOrdered: true,
        received: false,
      },
    ];
    const updateMaterialsRes = await request('PUT', `/api/v1/panel-manufacturing/batches/${createdBatch.id}/materials`, {
      materials: updatedMaterials,
    });
    assert(updateMaterialsRes.status === 200, 'BOM materials updated HTTP 200');
    const matList = updateMaterialsRes.data?.data?.materials || updateMaterialsRes.data?.materials;
    assert(Array.isArray(matList) && matList.length === 3, 'All 3 BOM components stored with checklist states');

    // TEST 4: production Details & 6-Stage State Machine Transition
    console.log('\n--- 4. production Details Lifecycle State Machine ---');
    const updateStatusRes = await request('PATCH', `/api/v1/panel-manufacturing/batches/${createdBatch.id}/status`, {
      status: 'IN_PROGRESS',
    });
    assert(updateStatusRes.status === 200, 'Batch status transitioned to IN_PROGRESS HTTP 200');

    // TEST 5: 6-Point Factory Acceptance Test (FAT) & Tested OK Registration
    console.log('\n--- 5. 6-Point Factory Acceptance Test (FAT) & Quality Gateway ---');
    const testRecordRes = await request('POST', '/api/v1/panel-manufacturing/testing-records', {
      batchId: createdBatch.id,
      batchNumber: newBatchNo,
      productId: `PRD-${newBatchNo}-01`,
      productName: 'Automatic Triplex VFD Booster Pump Panel',
      productModel: 'SE-VFD-415V-15HP',
      testerName: 'Senior QC Eng. Aditya Kulkarni',
      testDate: '2026-10-23 10:00:00',
      status: 'PASS',
      insulationResistanceMOhm: 85.5,
      testVoltageV: 415,
      frequencyHz: 50.0,
      currentA: 21.4,
      visualInspectionOk: true,
      continuityPassed: true,
      trippingResponseTimeMs: 14.5,
      controllerProgrammed: true,
      firmwareVersion: 'v2.4.1-iot',
      wifiMacAddress: 'A4:CF:12:88:B9:32',
      notes: 'Passed comprehensive 6-point FAT test protocol without remarks.',
    });
    assert(testRecordRes.status === 201 || testRecordRes.status === 200, 'FAT test record logged HTTP 200/201');

    // TEST 6: Test OK Product ID List Query
    console.log('\n--- 6. Test OK Product ID List Query ---');
    const testedOkRes = await request('GET', '/api/v1/panel-manufacturing/testing-records/tested-ok');
    assert(testedOkRes.status === 200, 'Tested OK products query HTTP 200');
    const testedList = testedOkRes.data?.data || testedOkRes.data;
    assert(Array.isArray(testedList) && testedList.length > 0, `Tested OK list contains ${testedList.length} verified units`);
    const verifiedUnit = testedList.find((u) => u.productId === `PRD-${newBatchNo}-01`);
    assert(!!verifiedUnit, `Newly verified unit PRD-${newBatchNo}-01 exists in Tested OK list`);

    // TEST 7: Dispatch Log & Departmental Routing
    console.log('\n--- 7. Dispatch Log & Departmental Routing ---');
    const dispatchRes = await request('POST', '/api/v1/panel-manufacturing/dispatch-logs', {
      productId: `PRD-${newBatchNo}-01`,
      batchNumber: newBatchNo,
      department: 'Panel Dept',
      description: 'Dispatched to Panel Dept for final cable gland fitting and packaging before outward transit.',
      outwardDcNumber: 'DC-2026-OCT-0941',
    });
    assert(dispatchRes.status === 201 || dispatchRes.status === 200, 'Unit dispatch logged HTTP 200/201');
    const dispatchRecord = dispatchRes.data?.data || dispatchRes.data;
    assert(dispatchRecord?.dispatchCode && dispatchRecord?.department === 'Panel Dept', `Dispatch code ${dispatchRecord?.dispatchCode} generated for Panel Dept`);

    // TEST 8: Verify Dispatch Audit Ledger
    console.log('\n--- 8. Dispatch Audit Ledger ---');
    const dispatchLogsRes = await request('GET', '/api/v1/panel-manufacturing/dispatch-logs');
    assert(dispatchLogsRes.status === 200, 'Dispatch logs retrieved HTTP 200');
    const allDispatches = dispatchLogsRes.data?.data || dispatchLogsRes.data;
    assert(Array.isArray(allDispatches) && allDispatches.some((d) => d.productId === `PRD-${newBatchNo}-01`), 'New dispatch ledger record verified in audit trail');

    // TEST 9: Panel QC Sign-off
    console.log('\n--- 9. Panel QC Sign-off Gateway ---');
    const qcSignoffRes = await request('POST', '/api/v1/panel-manufacturing/panel-qc-signoff', {
      panelSerialNo: `PNL-${timestamp.toString().slice(-4)}`,
      inspector: 'Vikram Sharma',
      insulationResistancePassed: true,
      wiringContinuityTorquePassed: true,
    });
    assert(qcSignoffRes.status === 200 || qcSignoffRes.status === 201, 'Panel QC sign-off completed HTTP 200/201');
    const qcResult = qcSignoffRes.data?.data?.qcRecord || qcSignoffRes.data?.qcRecord || qcSignoffRes.data?.data || qcSignoffRes.data;
    assert(qcResult?.status === 'APPROVED_PASS', `QC sign-off status: ${qcResult?.status}`);

    console.log('\n================================================================');
    console.log(`VERIFICATION COMPLETE: ${passed} PASSED, ${failed} FAILED`);
    console.log('================================================================');
  } catch (err) {
    console.error('Fatal error during test suite execution:', err);
  } finally {
    await prisma.$disconnect();
  }
}

runSuite();
