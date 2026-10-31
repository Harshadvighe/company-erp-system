const { PrismaService } = require('../dist/src/core/database/prisma.service');
const { HrService } = require('../dist/src/modules/hr/hr.service');
const { AdminService } = require('../dist/src/modules/admin/admin.service');
const { AuditService } = require('../dist/src/core/audit/audit.service');
const { FaceRecognitionService } = require('../dist/src/core/biometrics/face-recognition.service');
const { MailService } = require('../dist/src/core/notifications/mail.service');
const bcrypt = require('bcryptjs');

async function createEmployeeAndAccount() {
  console.log('================================================================');
  console.log('   CREATING NEW EMPLOYEE ONBOARDING ACCOUNT & CREDENTIALS       ');
  console.log('================================================================\n');

  const prisma = new PrismaService();
  await prisma.$connect();

  const auditService = new AuditService(prisma);
  const faceRecognitionService = new FaceRecognitionService(prisma);
  const mailService = new MailService();
  const hrService = new HrService(prisma, auditService, faceRecognitionService, mailService);
  const adminService = new AdminService(prisma, auditService, mailService);

  const targetEmail = 'poojasonawane05702@gmail.com';
  const targetUsername = 'pooja_sonawane';
  const targetPassword = 'Saark@Password2026';

  // Check if employee already exists with this email
  let existing = await prisma.employee.findUnique({
    where: { email: targetEmail },
    include: { user: true },
  });

  if (existing) {
    console.log(`Found existing record for ${targetEmail}: ${existing.employeeCode}`);
    if (!existing.user) {
      console.log('Provisioning user account for existing employee...');
      await adminService.approveEmployeeRequest(existing.id, {
        username: targetUsername,
        password: targetPassword,
        roleIds: ['ROLE_EMPLOYEE'],
        sendWelcomeEmail: true,
      });
      existing = await prisma.employee.findUnique({
        where: { email: targetEmail },
        include: { user: true },
      });
    }
  } else {
    console.log(`Creating new employee onboarding record for ${targetEmail}...`);
    // Create new employee
    const newEmp = await hrService.createEmployee({
      firstName: 'Pooja',
      lastName: 'Sonawane',
      email: targetEmail,
      phone: '+91 98220 54321',
      designation: 'Senior Automation Engineer',
      workerCategory: 'STAFF',
      skillLevel: 'LEVEL_3_SPECIALIST',
      assignedBay: 'BAY_2_TESTING',
      shiftCode: 'SHIFT_G',
      status: 'PENDING_APPROVAL',
      createUserAccount: false,
    });

    console.log(`Created employee: ${newEmp.employeeCode} (${newEmp.id})`);

    // Admin Approves and provisions login credentials
    console.log('Admin approving request and provisioning login credentials...');
    await adminService.approveEmployeeRequest(newEmp.id, {
      username: targetUsername,
      password: targetPassword,
      roleIds: ['ROLE_EMPLOYEE'],
      sendWelcomeEmail: true,
    });

    existing = await prisma.employee.findUnique({
      where: { id: newEmp.id },
      include: { user: true },
    });
  }

  console.log('\n\x1b[32m✔ ACCOUNT CREATED & PROVISIONED SUCCESSFULLY:\x1b[0m');
  console.log('  - Employee Code: ' + existing.employeeCode);
  console.log('  - Full Name:     ' + existing.firstName + ' ' + existing.lastName);
  console.log('  - Email:         ' + existing.email);
  console.log('  - Status:        ' + existing.status);
  console.log('  - Username:      ' + targetUsername);
  console.log('  - Password:      ' + targetPassword);
  console.log('  - Portal URL:    http://localhost:3000\n');

  await prisma.$disconnect();
}

createEmployeeAndAccount().catch(console.error);
