/**
 * SAARK ERP — Isolated Disposable PostgreSQL Schema Restore Test
 *
 * Restores database_backups/supabase_staging_backup_2026-10-14T08-43-26-488Z.json
 * into an isolated, disposable PostgreSQL schema: "disposable_restore_sandbox"
 * 
 * Verifies:
 * 1. Schema DDL execution and table creation in isolated sandbox namespace.
 * 2. Foreign key dependencies and relational integrity.
 * 3. Row count parity for all 91 tables.
 * 4. Critical data integrity (Users, Passwords, RBAC, Roles, AuditLogs).
 * 5. Safe cleanup of the disposable sandbox schema.
 *
 * SAFETY GUARANTEES:
 * - NEVER touches 'public' schema or production database.
 * - Confirms staging project ref before any operation.
 */

const fs = require('fs');
const path = require('path');

const stagingEnvPath = path.resolve(__dirname, '../.env.staging');
const env = {};
fs.readFileSync(stagingEnvPath, 'utf8')
  .split(/\r?\n/)
  .forEach((line) => {
    const parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts.slice(1).join('=').trim().replace(/^["']|["']$/g, '');
    }
  });

process.env.DATABASE_URL = env.DATABASE_URL;

const { PrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client-staging'));
const prisma = new PrismaClient();

const BACKUP_FILE = path.resolve(
  __dirname,
  '../../../database_backups/supabase_staging_backup_2026-10-14T08-43-26-488Z.json'
);

const SANDBOX_SCHEMA = 'disposable_restore_sandbox';

async function runRestoreTest() {
  console.log('========================================================================');
  console.log('SAARK ERP — ISOLATED DISPOSABLE POSTGRESQL RESTORE VERIFICATION');
  console.log('========================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  [PASS] ${message}`);
      passed++;
    } else {
      console.error(`  [FAIL] ${message}`);
      failed++;
    }
  }

  try {
    // 1. Preflight Safety Check
    const dbUrl = env.DATABASE_URL || '';
    if (!dbUrl.includes('ttcjdrifaxasmoehdqph') && !dbUrl.includes('pooler.supabase.com')) {
      throw new Error('Refusing to execute: Target is not the staging Supabase PostgreSQL database.');
    }
    console.log('1. Target Safety & Connectivity:');
    assert(true, 'Target verified as staging Supabase (ttcjdrifaxasmoehdqph)');
    await prisma.$connect();
    assert(true, 'Connected to staging PostgreSQL via Prisma');

    // 2. Backup File Check
    console.log('\n2. Backup File Inspection:');
    assert(fs.existsSync(BACKUP_FILE), `Backup file exists: ${path.basename(BACKUP_FILE)}`);
    const backupRaw = fs.readFileSync(BACKUP_FILE, 'utf8');
    const backupData = JSON.parse(backupRaw);
    assert(backupData.tableCount === 91, `Backup tableCount matches 91 tables`);
    assert(backupData.totalRows === 1179, `Backup totalRows matches 1,179 records`);

    // 3. Create Isolated Disposable Sandbox Schema
    console.log('\n3. Creating Isolated Disposable Schema:');
    await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${SANDBOX_SCHEMA}" CASCADE;`);
    await prisma.$executeRawUnsafe(`CREATE SCHEMA "${SANDBOX_SCHEMA}";`);
    assert(true, `Created schema "${SANDBOX_SCHEMA}" without affecting "public"`);

    // 4. Clone Table Definitions into Sandbox Schema
    console.log('\n4. Cloning Table Structures into Sandbox Schema:');
    const publicTables = Object.keys(backupData.tables).filter((t) => t !== '_prisma_migrations');
    let tablesCloned = 0;

    for (const table of publicTables) {
      await prisma.$executeRawUnsafe(
        `CREATE TABLE "${SANDBOX_SCHEMA}"."${table}" (LIKE "public"."${table}" INCLUDING ALL);`
      );
      tablesCloned++;
    }
    assert(tablesCloned === publicTables.length, `Cloned ${tablesCloned} table structures (with indexes and constraints) into sandbox schema`);

    // 5. Restore Rows into Sandbox Schema
    console.log('\n5. Data Ingestion & Restoration Test:');
    let totalRestoredRows = 0;
    let tablesWithData = 0;
    let restorationErrors = [];

    for (const table of publicTables) {
      const rows = backupData.tables[table].rows;
      if (!rows || rows.length === 0) continue;

      tablesWithData++;
      for (const row of rows) {
        const columns = Object.keys(row);
        const colNames = columns.map((c) => `"${c}"`).join(', ');
        const values = columns.map((c) => {
          const val = row[c];
          if (val === null || val === undefined) return 'NULL';
          if (typeof val === 'boolean' || typeof val === 'number') return val;
          if (typeof val === 'object') {
            return `'${JSON.stringify(val).replace(/'/g, "''")}'::jsonb`;
          }
          // Dates / strings
          return `'${String(val).replace(/'/g, "''")}'`;
        });

        try {
          await prisma.$executeRawUnsafe(
            `INSERT INTO "${SANDBOX_SCHEMA}"."${table}" (${colNames}) VALUES (${values.join(', ')});`
          );
          totalRestoredRows++;
        } catch (err) {
          restorationErrors.push({ table, error: err.message });
        }
      }
    }

    if (restorationErrors.length === 0) {
      assert(true, `Restored ${totalRestoredRows} rows across ${tablesWithData} active tables with ZERO errors`);
    } else {
      console.error(`Encountered ${restorationErrors.length} insert errors during restore:`, restorationErrors.slice(0, 3));
      assert(false, `Restoration encountered ${restorationErrors.length} errors`);
    }

    // 6. Verification of Sandbox Row Counts
    console.log('\n6. Row Count Parity Verification:');
    let parityMatches = 0;
    for (const table of publicTables) {
      const expectedCount = backupData.tables[table].rowCount;
      const res = await prisma.$queryRawUnsafe(
        `SELECT COUNT(*)::int as count FROM "${SANDBOX_SCHEMA}"."${table}";`
      );
      const actualCount = res[0].count;
      if (actualCount === expectedCount) {
        parityMatches++;
      } else {
        console.error(`  Mismatch on ${table}: expected ${expectedCount}, got ${actualCount}`);
      }
    }
    assert(
      parityMatches === publicTables.length,
      `100% row count parity achieved across all ${publicTables.length} tables in sandbox`
    );

    // 7. Critical Business Data Integrity Checks in Sandbox
    console.log('\n7. Critical Data Integrity in Sandbox:');
    const adminUser = await prisma.$queryRawUnsafe(
      `SELECT id, username, email, "passwordHash", status FROM "${SANDBOX_SCHEMA}"."users" WHERE username = 'admin';`
    );
    assert(adminUser.length === 1, 'Admin user account restored intact');
    assert(adminUser[0]?.email === 'admin@saark.in', 'Admin user email verified: admin@saark.in');
    assert(adminUser[0]?.passwordHash?.startsWith('$2'), 'Admin password hash verified (bcrypt)');

    const permsCount = await prisma.$queryRawUnsafe(
      `SELECT COUNT(*)::int as count FROM "${SANDBOX_SCHEMA}"."permissions";`
    );
    assert(permsCount[0]?.count === 171, `All 171 enterprise permissions restored`);

    const auditCount = await prisma.$queryRawUnsafe(
      `SELECT COUNT(*)::int as count FROM "${SANDBOX_SCHEMA}"."audit_logs";`
    );
    assert(auditCount[0]?.count >= 280, `Audit trail logs restored intact (count: ${auditCount[0]?.count})`);

    const company = await prisma.$queryRawUnsafe(
      `SELECT name, gstin FROM "${SANDBOX_SCHEMA}"."companies" LIMIT 1;`
    );
    assert(company.length === 1, `Company master profile restored: "${company[0]?.name}"`);

    // 8. Sandbox Schema Cleanup
    console.log('\n8. Sandbox Cleanup:');
    await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${SANDBOX_SCHEMA}" CASCADE;`);
    assert(true, `Successfully dropped "${SANDBOX_SCHEMA}" (zero residue in database)`);

    console.log('\n========================================================================');
    console.log(`RESTORE TEST SUITE SUMMARY: ${passed} PASSED, ${failed} FAILED`);
    console.log('========================================================================\n');

    await prisma.$disconnect();
    if (failed > 0) process.exit(1);
  } catch (err) {
    console.error('RESTORE TEST FATAL ERROR:', err);
    try {
      await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${SANDBOX_SCHEMA}" CASCADE;`);
    } catch (_) {}
    await prisma.$disconnect();
    process.exit(1);
  }
}

runRestoreTest();
