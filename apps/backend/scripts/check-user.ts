import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🔍 Checking Saarkadmin user...');

  const user = await prisma.user.findFirst({
    where: {
      OR: [
        { username: 'Saarkadmin' },
        { email: 'saarkadmin@saark.in' }
      ]
    },
    include: {
      userRoles: {
        include: {
          role: true
        }
      },
      staff: true
    }
  });

  if (user) {
    console.log('✅ User found:');
    console.log('   ID:', user.id);
    console.log('   Username:', user.username);
    console.log('   Email:', user.email);
    console.log('   Full Name:', user.fullName);
    console.log('   Status:', user.status);
    console.log('   Roles:', user.userRoles.map(ur => ur.role.name).join(', '));
    console.log('   Staff ID:', user.staff?.employeeId);
  } else {
    console.log('❌ User NOT found in database');
  }
}

main()
  .catch((e) => {
    console.error('❌ Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
