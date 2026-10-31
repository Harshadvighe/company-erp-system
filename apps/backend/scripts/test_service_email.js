const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '../.env') });

const { MailService } = require('../dist/src/core/notifications/mail.service');

async function testServiceDispatch() {
  const mailService = new MailService();
  console.log('Testing MailService direct dispatch via Gmail SMTP...');
  
  const result = await mailService.sendWelcomeEmployeeEmail({
    to: 'saarkexploration1@gmail.com',
    fullName: 'Saark exploration exploration',
    username: 'saarkexploration1',
    password: 'Saark@Password2026',
    employeeCode: 'EMP-2026-036',
    designation: 'Junior Design Engineer',
  });

  console.log('Dispatch result (success):', result);
}

testServiceDispatch().catch(console.error);
