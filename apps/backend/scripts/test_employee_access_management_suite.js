const path = require('path');
const fs = require('fs');

// Load environment variables from apps/backend/.env
const envPath = path.resolve(__dirname, '../.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf8');
  envContent.split(/\r?\n/).forEach((line) => {
    const t = line.trim();
    if (t && !t.startsWith('#')) {
      const eq = t.indexOf('=');
      if (eq !== -1) {
        const k = t.slice(0, eq).trim();
        let v = t.slice(eq + 1).trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
        process.env[k] = v;
      }
    }
  });
}

const { PrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client'));
const prisma = new PrismaClient();

let passed = 0;
let failed = 0;

function assert(condition, testName, details = '') {
  if (condition) {
    passed++;
    console.log(`  [PASS] ${testName}`);
  } else {
    failed++;
    console.error(`  [FAIL] ${testName} - ${details}`);
  }
}

async function runTestSuite() {
  console.log('========================================================================');
  console.log('SAARK ERP — PHASE 2 & 3: EMPLOYEE ACCESS MANAGEMENT AUTOMATED TEST SUITE');
  console.log('========================================================================\n');

  await prisma.$connect();

  try {
    // ─── TEST 1: Database records & Schema Integrity ─────────────────────────
    console.log('1. Database Schema & Record Integrity Checks:');
    const userCount = await prisma.user.count();
    const staffCount = await prisma.staff.count();
    const permCount = await prisma.permission.count();
    const userPermCount = await prisma.userPermission.count();

    assert(userCount > 0, `Users table populated (count: ${userCount})`);
    assert(staffCount > 0, `Staff table populated (count: ${staffCount})`);
    assert(permCount > 0, `Permissions master table populated (count: ${permCount})`);
    assert(userPermCount >= 0, `UserPermission table accessible and operational (count: ${userPermCount})`);

    // Verify CRM and HR permissions exist
    const crmPerms = await prisma.permission.findMany({ where: { module: 'CRM' } });
    const hrPerms = await prisma.permission.findMany({ where: { module: 'HR' } });
    const invPerms = await prisma.permission.findMany({ where: { module: 'INVENTORY' } });
    assert(crmPerms.length > 0, `CRM permissions active in catalog (count: ${crmPerms.length})`);
    assert(hrPerms.length > 0, `HR permissions active in catalog (count: ${hrPerms.length})`);
    assert(invPerms.length > 0, `Inventory permissions active in catalog (count: ${invPerms.length})`);

    // ─── TEST 2: Effective Permission Resolver Logic ─────────────────────────
    console.log('\n2. Effective Permission Resolver Engine:');
    const { PermissionResolverService } = require(path.resolve(__dirname, '../dist/src/core/permissions/permission-resolver.service'));
    const resolver = new PermissionResolverService(prisma);

    // Find an employee with a non-admin role (e.g. sales rep or standard employee)
    const testUser = await prisma.user.findFirst({
      where: {
        userRoles: {
          some: {
            role: { code: { notIn: ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'] } }
          }
        }
      },
      include: {
        userRoles: { include: { role: true } }
      }
    });

    if (!testUser) {
      throw new Error('No non-admin test user found in database');
    }

    const testStaff = await prisma.staff.findFirst({ where: { userId: testUser.id } });
    console.log(`   Using test user: ${testUser.username} (${testUser.email}), roles: [${testUser.userRoles.map(r => r.role.code).join(', ')}]`);

    // Clean any pre-existing overrides for this test user
    await prisma.userPermission.deleteMany({ where: { userId: testUser.id } });

    // Step A: Role-inherited permissions
    const baseEffective = await resolver.resolveEffectivePermissions(testUser.id);
    console.log(`   Base role permissions count: ${baseEffective.length}`);
    assert(baseEffective.length >= 0, 'Inherited base role permissions calculated successfully');

    // Pick a permission that the user currently DOES NOT have
    const missingPerm = await prisma.permission.findFirst({
      where: {
        NOT: {
          rolePermissions: {
            some: {
              roleId: { in: testUser.userRoles.map(r => r.roleId) }
            }
          }
        }
      }
    });

    assert(missingPerm !== null, `Found missing permission for test: ${missingPerm?.module}:${missingPerm?.action} (${missingPerm?.id})`);

    const hasMissingBefore = await resolver.hasPermission(testUser.id, `${missingPerm.module}:${missingPerm.action}`);
    assert(!hasMissingBefore, `User does not have ${missingPerm.module}:${missingPerm.action} initially`);

    // Step B: Individual ALLOW Override
    console.log('\n3. Individual ALLOW Override Test:');
    await prisma.userPermission.create({
      data: {
        userId: testUser.id,
        permissionId: missingPerm.id,
        effect: 'ALLOW',
        reason: 'Automated Test: Grant missing permission'
      }
    });

    const hasMissingAfterAllow = await resolver.hasPermission(testUser.id, `${missingPerm.module}:${missingPerm.action}`);
    assert(hasMissingAfterAllow, `Individual ALLOW grants ${missingPerm.module}:${missingPerm.action} on next resolution`);

    // Step C: Individual DENY Override
    console.log('\n4. Individual DENY Override Test:');
    // Pick a permission the user inherits from role
    const inheritedPerm = await prisma.permission.findFirst({
      where: {
        rolePermissions: {
          some: {
            roleId: { in: testUser.userRoles.map(r => r.roleId) }
          }
        }
      }
    });

    if (inheritedPerm) {
      const hasInheritedBefore = await resolver.hasPermission(testUser.id, `${inheritedPerm.module}:${inheritedPerm.action}`);
      assert(hasInheritedBefore, `User has inherited permission ${inheritedPerm.module}:${inheritedPerm.action} from role`);

      // Add explicit DENY
      await prisma.userPermission.upsert({
        where: {
          userId_permissionId: {
            userId: testUser.id,
            permissionId: inheritedPerm.id
          }
        },
        create: {
          userId: testUser.id,
          permissionId: inheritedPerm.id,
          effect: 'DENY',
          reason: 'Automated Test: Explicit DENY override'
        },
        update: {
          effect: 'DENY',
          reason: 'Automated Test: Explicit DENY override'
        }
      });

      const hasInheritedAfterDeny = await resolver.hasPermission(testUser.id, `${inheritedPerm.module}:${inheritedPerm.action}`);
      assert(!hasInheritedAfterDeny, `Explicit DENY removes inherited ${inheritedPerm.module}:${inheritedPerm.action}`);

      // Step D: Reverting to INHERIT (deleting override)
      console.log('\n5. Revert Override to INHERIT:');
      await prisma.userPermission.delete({
        where: {
          userId_permissionId: {
            userId: testUser.id,
            permissionId: inheritedPerm.id
          }
        }
      });

      const hasInheritedAfterRevert = await resolver.hasPermission(testUser.id, `${inheritedPerm.module}:${inheritedPerm.action}`);
      assert(hasInheritedAfterRevert, `Reverting to INHERIT restores role permission ${inheritedPerm.module}:${inheritedPerm.action}`);
    }

    // Step E: Admin explicit DENY override
    console.log('\n6. Admin Explicit DENY (Break-Glass & Safeguards):');
    const adminUser = await prisma.user.findFirst({
      where: {
        userRoles: {
          some: {
            role: { code: { in: ['ROLE_ADMIN', 'ADMIN', 'SUPER_ADMIN'] } }
          }
        }
      }
    });

    if (adminUser) {
      console.log(`   Using admin user: ${adminUser.username} (${adminUser.email})`);
      const testAdminPerm = await prisma.permission.findFirst({ where: { module: 'USERS', action: 'DELETE' } });
      if (testAdminPerm) {
        // By default, admin has USERS:DELETE
        const adminHasDeleteBefore = await resolver.hasPermission(adminUser.id, 'USERS:DELETE');
        assert(adminHasDeleteBefore, 'Administrator has USERS:DELETE by default');

        // Apply explicit DENY on USERS:DELETE
        await prisma.userPermission.upsert({
          where: {
            userId_permissionId: {
              userId: adminUser.id,
              permissionId: testAdminPerm.id
            }
          },
          create: {
            userId: adminUser.id,
            permissionId: testAdminPerm.id,
            effect: 'DENY',
            reason: 'Automated Test: Explicit DENY for Admin safeguard'
          },
          update: {
            effect: 'DENY',
            reason: 'Automated Test: Explicit DENY for Admin safeguard'
          }
        });

        const adminHasDeleteAfterDeny = await resolver.hasPermission(adminUser.id, 'USERS:DELETE');
        assert(!adminHasDeleteAfterDeny, 'Explicit DENY successfully revoked USERS:DELETE from administrator');

        // Cleanup admin override
        await prisma.userPermission.delete({
          where: {
            userId_permissionId: {
              userId: adminUser.id,
              permissionId: testAdminPerm.id
            }
          }
        });

        const adminHasDeleteRestored = await resolver.hasPermission(adminUser.id, 'USERS:DELETE');
        assert(adminHasDeleteRestored, 'Administrator USERS:DELETE permission restored upon override removal');
      }
    }

    // ─── TEST 3: Admin Service Security & Privilege Escalation ───────────────
    console.log('\n7. Admin Service Security & Privilege Escalation:');
    const { AdminService } = require(path.resolve(__dirname, '../dist/src/modules/admin/admin.service'));
    const { AuditService } = require(path.resolve(__dirname, '../dist/src/core/audit/audit.service'));
    const auditService = new AuditService(prisma);
    const adminService = new AdminService(prisma, resolver, auditService);

    // Test: Non-admin user attempts to modify permissions
    let escalationBlocked = false;
    try {
      await adminService.updateEmployeeAccess(
        testStaff.id,
        {
          overrides: [{ permissionId: missingPerm.id, effect: 'ALLOW' }],
          reason: 'Escalation attempt'
        },
        { id: testUser.id, roles: ['ROLE_EMPLOYEE'] } // Non-admin caller
      );
    } catch (err) {
      if (err.status === 403 || err.message.includes('Only administrators')) {
        escalationBlocked = true;
      }
    }
    assert(escalationBlocked, 'Non-admin user cannot modify employee permissions (403 Forbidden)');

    // Test: Invalid permission ID is rejected
    let invalidPermRejected = false;
    try {
      await adminService.updateEmployeeAccess(
        testStaff.id,
        {
          overrides: [{ permissionId: 'invalid-non-existent-perm-id-12345', effect: 'ALLOW' }],
          reason: 'Invalid permission test'
        },
        { id: adminUser.id, roles: ['ROLE_ADMIN'] }
      );
    } catch (err) {
      if (err.status === 400 || err.status === 404 || (err.message && (err.message.includes('Invalid permission') || err.message.includes('not found')))) {
        invalidPermRejected = true;
      }
    }
    assert(invalidPermRejected, 'Invalid permission ID is safely rejected with 400 Bad Request');

    // ─── TEST 4: Transactional Updates & Audit Trail ──────────────────────────
    console.log('\n8. Transactional Consistency & Audit Logging:');
    const auditCountBefore = await prisma.auditLog.count({
      where: { action: 'PERMISSION_OVERRIDE' }
    });

    const updateResult = await adminService.updateEmployeeAccess(
      testStaff.id,
      {
        overrides: [
          { permissionId: missingPerm.id, effect: 'ALLOW', reason: 'Audit verification test' }
        ],
        reason: 'Integration test update'
      },
      { id: adminUser.id, roles: ['ROLE_ADMIN'] }
    );

    assert(updateResult && (updateResult.employee || updateResult.success), 'updateEmployeeAccess returned updated access detail');

    const auditCountAfter = await prisma.auditLog.count({
      where: { action: 'PERMISSION_OVERRIDE' }
    });
    assert(auditCountAfter > auditCountBefore, 'Audit event recorded in audit_logs table');

    const latestAudit = await prisma.auditLog.findFirst({
      where: { action: 'PERMISSION_OVERRIDE' },
      orderBy: { timestamp: 'desc' }
    });

    assert(latestAudit.userId === adminUser.id, 'Audit record accurately references acting admin ID');
    assert(latestAudit.entityId === testUser.id, 'Audit record references target user ID');
    const auditDetails = typeof latestAudit.details === 'string' ? JSON.parse(latestAudit.details) : latestAudit.details;
    assert(auditDetails.targetUserId === testUser.id, 'Audit details specify affected user ID');
    assert(auditDetails.overridesCount > 0, 'Audit details record number of applied overrides');

    // Clean up test overrides
    await prisma.userPermission.deleteMany({ where: { userId: testUser.id } });

    // ─── TEST 5: Access Detail & Listing Endpoints ────────────────────────────
    console.log('\n9. Access Management Detail & Listing Endpoints:');
    const accessList = await adminService.getEmployeesAccessList({ page: 1, limit: 10 });
    assert(Array.isArray(accessList.employees), 'getEmployeesAccessList returns employees array');
    assert(accessList.meta.total > 0, `getEmployeesAccessList total count valid: ${accessList.meta.total}`);

    const accessDetail = await adminService.getEmployeeAccessDetail(testStaff.id);
    assert(accessDetail.employee.id === testStaff.id, 'getEmployeeAccessDetail returns correct employee');
    assert(Array.isArray(accessDetail.modules), 'getEmployeeAccessDetail groups permissions by module');
    assert(accessDetail.modules.length > 0, `getEmployeeAccessDetail returns modules (count: ${accessDetail.modules.length})`);
    assert(Array.isArray(accessDetail.effectivePermissions), 'getEmployeeAccessDetail returns effectivePermissions list');

    console.log('\n========================================================================');
    console.log(`TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
    console.log('========================================================================\n');

    if (failed > 0) {
      process.exit(1);
    }
  } catch (error) {
    console.error('Fatal error during test suite:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

runTestSuite();
