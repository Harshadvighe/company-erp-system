const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const nodemailer = require('nodemailer');

dotenv.config({ path: path.join(__dirname, '../.env') });

async function checkAndSendTestEmail() {
  console.log('================================================================');
  console.log('  SAARK ERP - EMAIL DISPATCH & DELIVERY CHECK (ADMIN SIDE)      ');
  console.log('================================================================\n');

  const targetEmail = 'sonawanep968@gmail.com';
  const mailLogsDir = path.resolve(__dirname, '../../../storage/mail_logs');

  console.log(`1. Checking Admin Mail Audit Logs for: ${targetEmail}`);
  if (fs.existsSync(mailLogsDir)) {
    const files = fs.readdirSync(mailLogsDir).filter((f) => f.endsWith('.json'));
    const matched = [];
    for (const f of files) {
      try {
        const data = JSON.parse(fs.readFileSync(path.join(mailLogsDir, f), 'utf8'));
        if (data.to && data.to.toLowerCase() === targetEmail.toLowerCase()) {
          matched.push(data);
        }
      } catch (_) {}
    }

    if (matched.length > 0) {
      console.log(`\x1b[32m✔ FOUND ${matched.length} EMAIL DISPATCH RECORD(S) IN ADMIN LOGS:\x1b[0m\n`);
      for (const m of matched) {
        console.log(`  - Log ID:    ${m.id}`);
        console.log(`  - Timestamp: ${m.timestamp}`);
        console.log(`  - To:        ${m.to}`);
        console.log(`  - Subject:   ${m.subject}`);
        console.log(`  - Status:    ${m.success ? 'DISPATCHED_TO_LOGGER' : 'FAILED'}`);
        console.log(`  - Username & Password details inside content:`);
        const lines = m.text.split('\n').filter((l) => l.includes('Username:') || l.includes('Password:') || l.includes('Portal URL:'));
        lines.forEach((l) => console.log(`      ${l}`));
        console.log('');
      }
    } else {
      console.log('\x1b[33mNo email log found for this address.\x1b[0m');
    }
  }

  console.log('2. SMTP Configuration Check in .env:');
  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = process.env.SMTP_PORT || '587';
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const smtpFrom = process.env.SMTP_FROM || 'no-reply@saarkexploration.com';

  console.log(`  - SMTP_HOST: ${smtpHost || '(NOT SET - running in simulated/audit logging mode)'}`);
  console.log(`  - SMTP_PORT: ${smtpPort}`);
  console.log(`  - SMTP_USER: ${smtpUser || '(NOT SET)'}`);
  console.log(`  - SMTP_PASS: ${smtpPass ? '********' : '(NOT SET)'}`);

  if (!smtpHost || !smtpUser || !smtpPass) {
    console.log('\n\x1b[33m[NOTE] Real outbound internet delivery requires SMTP credentials in apps/backend/.env:\x1b[0m');
    console.log('  For example, using Gmail:');
    console.log('    SMTP_HOST=smtp.gmail.com');
    console.log('    SMTP_PORT=587');
    console.log('    SMTP_USER=your_email@gmail.com');
    console.log('    SMTP_PASS=your_gmail_16_digit_app_password');
    console.log('    SMTP_FROM=your_email@gmail.com');
    return;
  }

  console.log('\n3. Attempting Live SMTP Delivery to ' + targetEmail + '...');
  try {
    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: parseInt(smtpPort, 10),
      secure: smtpPort === '465',
      auth: { user: smtpUser, pass: smtpPass },
    });

    const info = await transporter.sendMail({
      from: `"Saark Exploration ERP" <${smtpFrom}>`,
      to: targetEmail,
      subject: 'Welcome to Saark Exploration - Your ERP Account & Login Credentials',
      text: `Dear pooja sonawane,\n\nYour ERP system account has been provisioned.\nUsername: pooja\nTemporary Password: Saark@2026\nPortal URL: http://localhost:3000\n\nSaark Exploration Operations`,
    });

    console.log(`\x1b[32m✔ SUCCESS! Live email delivered to ${targetEmail}!\x1b[0m`);
    console.log(`  MessageId: ${info.messageId}`);
  } catch (err) {
    console.error(`\x1b[31m✖ SMTP Delivery Failed:\x1b[0m ${err.message}`);
  }
}

checkAndSendTestEmail().catch(console.error);
