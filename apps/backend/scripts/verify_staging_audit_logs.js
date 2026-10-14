const path = require('path');
const fs = require('fs');
const { PrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client-staging'));

const env = {};
fs.readFileSync(path.resolve(__dirname, '../.env.staging'), 'utf8')
  .split(/\r?\n/)
  .forEach(line => {
    const parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts.slice(1).join('=').trim().replace(/^["']|["']$/g, '');
    }
  });

process.env.DATABASE_URL = env.DATABASE_URL;

async function check() {
  const p = new PrismaClient();
  try {
    const count = await p.auditLog.count();
    console.log('[PASS] Staging Supabase PostgreSQL audit_logs table exists and is accessible. Total records:', count);
    const sample = await p.auditLog.findFirst({
      orderBy: { timestamp: 'desc' },
      select: { id: true, module: true, action: true, timestamp: true, userEmail: true }
    });
    console.log('[PASS] Latest audit record in staging PostgreSQL:', sample);
  } catch (err) {
    console.error('[FAIL] Staging PostgreSQL audit query error:', err.message);
  } finally {
    await p.$disconnect();
  }
}

check();
