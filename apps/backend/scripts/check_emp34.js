const { PrismaService } = require('../dist/src/core/database/prisma.service');
const fs = require('fs');
const path = require('path');

async function main() {
  const prisma = new PrismaService();
  await prisma.$connect();

  const allEmployees = await prisma.employee.findMany({
    select: {
      id: true,
      employeeCode: true,
      firstName: true,
      lastName: true,
      email: true,
      phone: true,
      status: true,
      userId: true,
      user: {
        select: {
          id: true,
          username: true,
          email: true,
        },
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  console.log(`Total employees in database: ${allEmployees.length}`);

  const matchByEmail = allEmployees.filter(
    (e) => e.email && e.email.toLowerCase().includes('sonawane'),
  );
  console.log('\n--- Matched by sonawane ---');
  console.log(JSON.stringify(matchByEmail, null, 2));

  const matchBy34 = allEmployees.filter(
    (e) => e.employeeCode.includes('34') || e.employeeCode.includes('034'),
  );
  console.log('\n--- Matched by 34 ---');
  console.log(JSON.stringify(matchBy34, null, 2));

  // Check mail_logs directory
  const mailLogsDir = path.join(__dirname, '../../storage/mail_logs');
  console.log('\n--- Mail logs directory exists: ---', fs.existsSync(mailLogsDir));
  if (fs.existsSync(mailLogsDir)) {
    const files = fs.readdirSync(mailLogsDir);
    console.log(`Total mail log files: ${files.length}`);
    const sonawaneMails = [];
    for (const file of files) {
      if (file.endsWith('.json')) {
        try {
          const content = JSON.parse(fs.readFileSync(path.join(mailLogsDir, file), 'utf8'));
          if (content.to && content.to.toLowerCase().includes('sonawane')) {
            sonawaneMails.push(content);
          }
        } catch (_) {}
      }
    }
    console.log(`Mails sent to sonawane: ${sonawaneMails.length}`);
    console.log(JSON.stringify(sonawaneMails, null, 2));
  }

  await prisma.$disconnect();
}

main().catch(console.error);
