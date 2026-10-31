const { PrismaClient } = require('@prisma/client');

async function testConnection(url, label) {
  console.log(`Testing ${label}...`);
  const prisma = new PrismaClient({ datasources: { db: { url } } });
  try {
    const res = await prisma.$queryRaw`SELECT NOW() as current_time`;
    console.log(`✔ ${label} SUCCESS! Result:`, res);
    await prisma.$disconnect();
    return true;
  } catch (err) {
    console.error(`✖ ${label} FAILED:`, err.message);
    try { await prisma.$disconnect(); } catch (_) {}
    return false;
  }
}

async function main() {
  const p5432 = "postgresql://postgres.fvvebmddcpojjqirjgjx:SaarkERP%402026%21@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres?connection_limit=2";
  const p6543 = "postgresql://postgres.fvvebmddcpojjqirjgjx:SaarkERP%402026%21@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=2";
  
  await testConnection(p5432, "Port 5432 (Session Pooler)");
  await testConnection(p6543, "Port 6543 (Transaction Pooler)");
}

main().catch(console.error);
