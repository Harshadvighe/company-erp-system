import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🔐 Adding Saarkadmin user with bypass credentials...');

  // Check if user already exists
  const existingUser = await prisma.user.findFirst({
    where: {
      OR: [
        { username: 'Saarkadmin' },
        { email: 'saarkadmin@saark.in' }
      ]
    }
  });

  if (existingUser) {
    console.log('⚠️  User Saarkadmin already exists. Updating password...');
    await prisma.user.update({
      where: { id: existingUser.id },
      data: {
        passwordHash: await bcrypt.hash('12345678', 10)
      }
    });
    console.log('✅ Password updated to 12345678');
  } else {
    // Get ADMIN department and designation
    const dept = await prisma.department.findFirst({
      where: { code: 'EXECUTIVE' }
    });

    const desig = await prisma.designation.findFirst({
      where: { code: 'MD' }
    });

    const role = await prisma.role.findFirst({
      where: { code: 'ROLE_ADMIN' }
    });

    if (!dept || !desig || !role) {
      console.error('❌ Required master data not found. Please run full seed first.');
      return;
    }

    // Create the user
    const user = await prisma.user.create({
      data: {
        username: 'Saarkadmin',
        email: 'saarkadmin@saark.in',
        passwordHash: await bcrypt.hash('12345678', 10),
        fullName: 'Saark Admin',
        designation: desig.name,
        departmentId: dept.id,
        phone: '+91 98200 00000',
        status: 'ACTIVE',
      }
    });

    // Assign admin role
    await prisma.userRole.create({
      data: {
        userId: user.id,
        roleId: role.id
      }
    });

    // Create staff profile
    await prisma.staff.create({
      data: {
        employeeId: 'EMP000',
        fullName: 'Saark Admin',
        email: 'saarkadmin@saark.in',
        mobile: '+91 98200 00000',
        departmentId: dept.id,
        designationId: desig.id,
        userId: user.id,
        location: 'Mumbai Head Office',
        status: 'ACTIVE',
        joiningDate: new Date(),
      }
    });

    console.log('✅ Saarkadmin user created successfully!');
    console.log('   Username: Saarkadmin');
    console.log('   Password: 12345678');
    console.log('   Email: saarkadmin@saark.in');
    console.log('   Face verification: BYPASSED');
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
