const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const tables = await prisma.$queryRaw`SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'`;
  console.log('Tables in DB count:', tables.length);
  console.log('Tables:', tables.map(t => t.table_name).sort());
  await prisma.$disconnect();
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
