const nodemailer = require('nodemailer');
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '../.env') });

async function main() {
  const target = process.argv[2] || 'saarkexploration1@gmail.com';
  console.log('Testing Gmail SMTP delivery...');
  console.log('From:', process.env.SMTP_USER);
  console.log('To:', target);
  console.log('Host:', process.env.SMTP_HOST, 'Port:', process.env.SMTP_PORT);

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '465', 10),
    secure: parseInt(process.env.SMTP_PORT || '465', 10) === 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  const info = await transporter.sendMail({
    from: process.env.SMTP_FROM || `"Saark Exploration ERP" <${process.env.SMTP_USER}>`,
    to: target,
    subject: 'Saark Exploration ERP - Account Login Credentials',
    text: `Dear Saark exploration,\n\nYour Saark ERP account is ready.\n\n• Portal URL: http://localhost:3000\n• Username: saarkexploration1\n• Password: Saark@2026\n\n┌────────────────────────────────────────────────────────┐\n│ SAARK EXPLORATION Pvt. Ltd.                            │\n│ WE DEVELOPE HIGH END TECHNOLOGY                        │\n│ 📍 Registered Office & Works:                          │\n│ S NO 46, CHAITNAYA industrial estate, Manaji Nagar,    │\n│ Narhe, Pune, Maharashtra 411041                        │\n│                                                        │\n│ © 2026 Saark Exploration Pvt. Ltd. All rights reserved.│\n│ [THIS MAIL IS AUTO GENERATED • NOT SHAREABLE •         │\n│  SCREENSHOTS NOT ALLOWED • NO REPLY]                   │\n└────────────────────────────────────────────────────────┘`,
    html: `<div style="font-family: Arial; padding: 20px; background: #16181d; color: #fff; border-radius: 8px;">
      <h2 style="color: #F26522;">SAARK EXPLORATION Pvt. Ltd.</h2>
      <p>WE DEVELOPE HIGH END TECHNOLOGY</p>
      <p>Your Saark ERP account is ready.</p>
      <p><strong>Username:</strong> saarkexploration1<br/><strong>Password:</strong> Saark@2026</p>
      <p style="color: #888; font-size: 11px;">📍 S NO 46, CHAITNAYA industrial estate, Manaji Nagar, Narhe, Pune, Maharashtra 411041</p>
    </div>`,
  });

  console.log('✔ Message sent successfully! ID:', info.messageId);
  console.log('Response:', info.response);
}

main().catch(err => {
  console.error('✖ Error sending email:', err);
  process.exit(1);
});
