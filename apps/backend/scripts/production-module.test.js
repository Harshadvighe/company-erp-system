const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { after, test } = require('node:test');
const { PanelManufacturingService } = require('../src/modules/panel-manufacturing/panel-manufacturing.service');

const originalStoragePath = process.env.STORAGE_LOCAL_BASE_PATH;

after(() => {
  if (originalStoragePath === undefined) {
    delete process.env.STORAGE_LOCAL_BASE_PATH;
  } else {
    process.env.STORAGE_LOCAL_BASE_PATH = originalStoragePath;
  }
});

function createService(t, prisma = {}) {
  const storagePath = fs.mkdtempSync(path.join(os.tmpdir(), 'saark-production-module-'));
  process.env.STORAGE_LOCAL_BASE_PATH = storagePath;
  t.after(() => fs.rmSync(storagePath, { recursive: true, force: true }));

  return new PanelManufacturingService(prisma, {
    nextPanelCode: async () => 'PANEL-TEST-0001',
  });
}

test('creates a panel specification with calculated BOM cost and final price', async (t) => {
  let createArgs;
  const service = createService(t, {
    panelSpecification: {
      create: async (args) => {
        createArgs = args;
        return { id: 'spec-1', ...args.data };
      },
    },
  });

  const result = await service.create({
    customerId: 'customer-1',
    labourCost: 12000,
    overheadCost: 6000,
    marginPercent: 20,
    bomItems: [
      { componentName: 'Drive', quantity: 2, unitPrice: 32000 },
      { componentName: 'Controller', quantity: 1, unitPrice: 18500 },
    ],
  });

  assert.equal(result.panelCode, 'PANEL-TEST-0001');
  assert.equal(createArgs.data.materialCost, 82500);
  assert.equal(createArgs.data.finalPrice, 120600);
  assert.equal(createArgs.data.bomItems.create.length, 2);
  assert.equal(createArgs.data.bomItems.create[0].totalPrice, 64000);
});

test('persists a production batch and updates its status and materials', async (t) => {
  const service = createService(t);
  const batch = await service.createBatch({
    batchNumber: 'BATCH-TEST-UNIT-001',
    productName: 'Test Control Panel',
    targetQuantity: 4,
    materials: [{ itemNumber: 1, componentName: 'MCCB', received: false }],
  }, 'Test Planner');

  assert.equal(batch.status, 'IN_PROGRESS');
  assert.equal(batch.createdBy, 'Test Planner');
  assert.equal(batch.materials.length, 1);

  const updatedBatch = await service.updateBatchStatus(
    batch.id,
    'QA_HOLD',
    'Test QC',
  );
  assert.equal(updatedBatch.status, 'QA_HOLD');
  assert.equal(updatedBatch.lastEditedBy, 'Test QC');

  const materials = [{ itemNumber: 1, componentName: 'MCCB', received: true }];
  const updatedMaterials = await service.updateBatchMaterials(
    batch.batchNumber,
    materials,
    'Test Storekeeper',
  );
  assert.deepEqual(updatedMaterials.materials, materials);

  const fetchedBatch = await service.getBatchById(batch.id);
  assert.equal(fetchedBatch.status, 'QA_HOLD');
  assert.deepEqual(fetchedBatch.materials, materials);
});

test('returns not found for a missing production batch', async (t) => {
  const service = createService(t);

  await assert.rejects(
    service.getBatchById('missing-batch'),
    (error) => error.status === 404,
  );
});
