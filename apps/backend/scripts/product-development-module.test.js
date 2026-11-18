const assert = require('node:assert/strict');
const { test } = require('node:test');
const { MASTER_NPD_STEPS } = require('../src/modules/npd/npd.master-steps');
const { NpdService } = require('../src/modules/npd/npd.service');

function createProjectFixture(overrides = {}) {
  const steps = MASTER_NPD_STEPS.map((step) => ({
    ...step,
    status: step.stepNumber === 1 ? 'IN_PROGRESS' : 'PENDING',
  }));
  return {
    id: 'npd-project-1',
    projectCode: 'PRJ-NPD-TEST-0001',
    projectName: 'Test IoT Gateway',
    currentStep: 1,
    currentPhase: 1,
    status: 'ACTIVE',
    isRegisterMapFrozen: false,
    registerMap: [],
    steps,
    artifacts: [],
    bomLinks: [],
    unitTestLogs: [],
    ...overrides,
  };
}

test('creates a Product Development project and seeds all 24 workflow steps transactionally', async () => {
  const project = createProjectFixture();
  let createdProjectData;
  let createdSteps;
  let transactionCount = 0;
  const prisma = {
    npdProject: {
      count: async () => 0,
      findUnique: async ({ where }) => (
        where.projectCode ? null : project
      ),
    },
    $transaction: async (callback) => {
      transactionCount++;
      return callback({
        npdProject: {
          create: async ({ data }) => {
            createdProjectData = data;
            return project;
          },
        },
        npdWorkflowStep: {
          createMany: async ({ data }) => {
            createdSteps = data;
            return { count: data.length };
          },
        },
      });
    },
  };
  const service = new NpdService(prisma);

  const result = await service.createProject({
    projectName: 'Test IoT Gateway',
    projectCode: 'PRJ-NPD-TEST-0001',
  }, { username: 'Test Engineer' });

  assert.equal(transactionCount, 1);
  assert.equal(createdProjectData.projectName, 'Test IoT Gateway');
  assert.equal(createdProjectData.createdByStaffName, 'Test Engineer');
  assert.equal(createdSteps.length, 24);
  assert.deepEqual(createdSteps.map((step) => step.stepNumber), Array.from({ length: 24 }, (_, i) => i + 1));
  assert.equal(createdSteps[0].status, 'IN_PROGRESS');
  assert.equal(createdSteps[1].status, 'PENDING');
  assert.equal(result.project.id, project.id);
  assert.equal(result.summary.totalSteps, 24);
});

test('rejects duplicate Product Development project codes without writing', async () => {
  let transactionCalled = false;
  const prisma = {
    npdProject: {
      count: async () => 1,
      findUnique: async () => ({ id: 'existing-project' }),
    },
    $transaction: async () => {
      transactionCalled = true;
    },
  };
  const service = new NpdService(prisma);

  await assert.rejects(
    service.createProject({
      projectName: 'Duplicate Project',
      projectCode: 'PRJ-NPD-EXISTING',
    }),
    (error) => error.status === 409,
  );
  assert.equal(transactionCalled, false);
});

test('enforces sequential Product Development step sign-off gates', async () => {
  const project = createProjectFixture({
    steps: createProjectFixture().steps.map((step) => (
      step.stepNumber === 1
        ? { ...step, status: 'SIGNED_OFF' }
        : step
    )),
  });
  let transactionCalled = false;
  const service = new NpdService({
    npdProject: {
      findUnique: async () => project,
    },
    $transaction: async () => {
      transactionCalled = true;
    },
  });

  await assert.rejects(
    service.signoffStep(project.id, 3, {}),
    (error) => error.message.includes('Steps [2]'),
  );
  assert.equal(transactionCalled, false);
});

test('signs off a Product Development step and advances the next step', async () => {
  const project = createProjectFixture();
  const stepUpdates = [];
  let projectUpdate;
  const service = new NpdService({
    npdProject: {
      findUnique: async () => project,
    },
    $transaction: async (callback) => callback({
      npdWorkflowStep: {
        update: async ({ where, data }) => {
          stepUpdates.push({ where, data });
          return { ...project.steps[where.projectId_stepNumber.stepNumber - 1], ...data };
        },
      },
      npdProject: {
        update: async ({ data }) => {
          projectUpdate = data;
          return data;
        },
      },
    }),
  });

  const result = await service.signoffStep(
    project.id,
    1,
    { signoffComments: 'Requirements reviewed' },
    { id: 'staff-1', fullName: 'Test Engineer' },
  );

  assert.equal(result.step.status, 'SIGNED_OFF');
  assert.equal(stepUpdates.length, 2);
  assert.equal(stepUpdates[0].where.projectId_stepNumber.stepNumber, 1);
  assert.equal(stepUpdates[0].data.signoffStaffId, 'staff-1');
  assert.equal(stepUpdates[1].where.projectId_stepNumber.stepNumber, 2);
  assert.equal(stepUpdates[1].data.status, 'IN_PROGRESS');
  assert.equal(projectUpdate.currentStep, 2);
  assert.equal(projectUpdate.status, 'ACTIVE');
});
