const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const count = await prisma.auditLog.count();
  const sample = await prisma.auditLog.findMany({
    take: 5,
    orderBy: { timestamp: 'desc' },
  });
  console.log('Total audit logs:', count);
  console.log('Sample audit logs:', JSON.stringify(sample, null, 2));
  await prisma.$disconnect();
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
