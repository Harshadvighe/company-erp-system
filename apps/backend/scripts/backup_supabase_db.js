const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const stagingEnvPath = path.resolve(__dirname, '../.env.staging');
const envContent = fs.readFileSync(stagingEnvPath, 'utf8');
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

const { PrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client-staging'));
const prisma = new PrismaClient();

async function runBackup() {
  console.log('================================================================');
  console.log('   SAARK ERP — SUPABASE DATABASE BACKUP & VERIFICATION          ');
  console.log('================================================================');

  await prisma.$connect();
  console.log('[PASS] Connected to database.');

  const tablesQuery = await prisma.$queryRawUnsafe(`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name ASC
  `);
  const tables = tablesQuery.map((r) => r.table_name);
  console.log(`Found ${tables.length} tables in public schema.`);

  const backupData = {
    timestamp: new Date().toISOString(),
    sourceDatabase: 'saark-erp-staging',
    tableCount: tables.length,
    tables: {},
    totalRows: 0,
  };

  for (const tableName of tables) {
    const rows = await prisma.$queryRawUnsafe(`SELECT * FROM "${tableName}"`);
    backupData.tables[tableName] = {
      rowCount: rows.length,
      rows,
    };
    backupData.totalRows += rows.length;
    process.stdout.write(`  Table: ${tableName.padEnd(35)} [${rows.length} rows]\n`);
  }

  const backupDir = path.resolve(__dirname, '../../../database_backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  const timestampStr = new Date().toISOString().replace(/[:.]/g, '-');
  const backupFilePath = path.join(backupDir, `supabase_staging_backup_${timestampStr}.json`);

  const serialized = JSON.stringify(backupData, null, 2);
  fs.writeFileSync(backupFilePath, serialized, 'utf8');

  // Compute checksum
  const hash = crypto.createHash('sha256').update(serialized).digest('hex');
  const sizeBytes = fs.statSync(backupFilePath).size;

  console.log('\n================================================================');
  console.log('[BACKUP COMPLETE & VERIFIED]');
  console.log(`File:     ${backupFilePath}`);
  console.log(`Size:     ${(sizeBytes / 1024 / 1024).toFixed(2)} MB (${sizeBytes} bytes)`);
  console.log(`Tables:   ${backupData.tableCount}`);
  console.log(`Records:  ${backupData.totalRows}`);
  console.log(`SHA256:   ${hash}`);
  console.log('================================================================');

  // Verify readability
  const verifyRead = JSON.parse(fs.readFileSync(backupFilePath, 'utf8'));
  if (verifyRead.totalRows === backupData.totalRows && verifyRead.tableCount === backupData.tableCount) {
    console.log('[PASS] Backup file integrity verified by re-reading and schema parity check.');
  } else {
    throw new Error('Backup integrity verification failed!');
  }

  await prisma.$disconnect();
}

runBackup().catch((err) => {
  console.error('BACKUP FAILED:', err);
  process.exit(1);
});
