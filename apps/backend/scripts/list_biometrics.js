const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany({
    include: { faceBiometric: true }
  });
  console.log(`Total users: ${users.length}`);
  users.forEach(u => {
    console.log(`- ${u.username} (${u.fullName}): faceStatus=${u.faceVerificationStatus}, hasBio=${!!u.faceBiometric}`);
  });

  const biometrics = await prisma.employeeFaceBiometric.findMany({
    include: { employee: true, user: true }
  });
  console.log(`\nTotal registered biometrics: ${biometrics.length}`);
  biometrics.forEach(b => {
    console.log(`- Biometric ${b.id}: userId=${b.userId}, empId=${b.employeeId}, active=${b.isActive}`);
  });
}

main().catch(console.error).finally(() => prisma.$disconnect());
