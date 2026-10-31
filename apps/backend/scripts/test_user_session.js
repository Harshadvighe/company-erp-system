const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const admin = await prisma.user.findFirst({ where: { username: 'admin' } });
  if (!admin) throw new Error('admin not found');

  const session = await prisma.userSession.create({
    data: {
      id: `SES-TEST-${Date.now().toString().slice(-6)}`,
      userId: admin.id,
      username: admin.username,
      fullName: admin.fullName,
      email: admin.email,
      department: 'Corporate Headquarters',
      role: 'Super Administrator',
      ipAddress: '127.0.0.1',
      clientType: 'Flutter Web / Chrome Desktop',
      loginTime: new Date(),
      status: 'ACTIVE',
      loginMethod: 'CREDENTIALS_AND_BIOMETRIC_2FA',
      faceVerified: true,
    },
  });

  console.log('✔ Successfully created session:', session);

  // Now test updating logout
  const updated = await prisma.userSession.update({
    where: { id: session.id },
    data: {
      logoutTime: new Date(Date.now() + 1800000), // 30 mins later
      durationSeconds: 1800,
      status: 'LOGGED_OUT',
      logoutReason: 'USER_LOGOUT',
    },
  });

  console.log('✔ Successfully updated session to LOGGED_OUT:', updated);
  await prisma.$disconnect();
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
