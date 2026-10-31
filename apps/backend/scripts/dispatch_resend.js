const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.join(__dirname, '../.env') });

async function dispatchLiveEmail() {
  const apiKey = (process.env.RESEND_API_KEY || '').trim();
  const target = process.argv[2] || 'pooja.saark@gmail.com';

  console.log('Dispatching live email via Resend Cloud API...');
  console.log('To:', target);
  console.log('API Key:', apiKey.substring(0, 7) + '...');

  const htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0e1013; color: #dcdcdc; margin: 0; padding: 20px; }
    .card { max-width: 520px; margin: 0 auto; background-color: #16181d; border-radius: 8px; border: 1px solid #2a2d35; overflow: hidden; }
    .top-bar { background: #111317; padding: 18px 20px; text-align: center; border-bottom: 2px solid #F26522; }
    .top-bar h1 { margin: 6px 0 0 0; color: #ffffff; font-size: 18px; font-weight: 700; letter-spacing: 0.5px; }
    .top-bar p { margin: 3px 0 0 0; color: #F26522; font-size: 10px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; }
    .body { padding: 20px 24px; }
    .salutation { font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 12px; }
    .subtext { font-size: 13px; line-height: 1.5; color: #b0b4be; margin-bottom: 16px; }
    .cred-card { background: #1e2129; border: 1px solid #2d313c; border-left: 4px solid #F26522; border-radius: 6px; padding: 14px 18px; margin-bottom: 20px; }
    .row { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; }
    .row:last-child { margin-bottom: 0; }
    .lbl { color: #8a909d; font-weight: 500; }
    .val { color: #ffffff; font-weight: 600; font-family: 'Consolas', monospace; }
    .action { text-align: center; margin: 18px 0; }
    .btn { background-color: #F26522; color: #ffffff !important; text-decoration: none; padding: 10px 26px; border-radius: 5px; font-weight: 600; font-size: 13px; display: inline-block; }
    .tip { font-size: 11px; color: #8a909d; text-align: center; margin-bottom: 16px; }
    .footer { padding: 16px 20px; text-align: center; background-color: #111317; border-top: 1px solid #22252c; }
    .box { font-family: 'Consolas', 'Courier New', monospace; white-space: pre; font-size: 10.5px; line-height: 1.4; color: #b5b9c2; background-color: #0b0c0f; border: 1px solid #2c303a; border-radius: 5px; padding: 12px 14px; text-align: left; display: inline-block; max-width: 100%; box-sizing: border-box; overflow-x: auto; }
  </style>
</head>
<body>
  <div class="card">
    <div class="top-bar">
      <h1>SAARK EXPLORATION Pvt. Ltd.</h1>
      <p>WE DEVELOPE HIGH END TECHNOLOGY</p>
    </div>
    <div class="body">
      <div class="salutation">Dear pooja sonawane Staff,</div>
      <div class="subtext">
        Your ERP system account (EMP-2026-034) is ready. Please use the credentials below to log in:
      </div>

      <div class="cred-card">
        <div class="row"><span class="lbl">Portal URL:</span><span class="val">http://localhost:3000</span></div>
        <div class="row"><span class="lbl">Username:</span><span class="val">pooja</span></div>
        <div class="row"><span class="lbl">Password:</span><span class="val">Saark@2026</span></div>
        <div class="row"><span class="lbl">Designation:</span><span class="val">Junior Design Engineer</span></div>
      </div>

      <div class="action">
        <a href="http://localhost:3000" class="btn">Sign In to ERP Portal</a>
      </div>

      <div class="tip">
        * Note: Camera face scan verification is required upon first login.
      </div>
    </div>
    <div class="footer">
      <div class="box">┌────────────────────────────────────────────────────────┐
│ SAARK EXPLORATION Pvt. Ltd.                            │
│ WE DEVELOPE HIGH END TECHNOLOGY                        │
│ 📍 Registered Office & Works:                          │
│ S NO 46, CHAITNAYA industrial estate, Manaji Nagar,    │
│ Narhe, Pune, Maharashtra 411041                        │
│                                                        │
│ © 2026 Saark Exploration Pvt. Ltd. All rights reserved.│
│ [THIS MAIL IS AUTO GENERATED • NOT SHAREABLE •         │
│  SCREENSHOTS NOT ALLOWED • NO REPLY]                   │
└────────────────────────────────────────────────────────┘</div>
    </div>
  </div>
</body>
</html>
  `.trim();

  const textContent = `
Dear pooja sonawane Staff,

Your Saark ERP account (EMP-2026-034) is ready:

• Portal URL : http://localhost:3000
• Username   : pooja
• Password   : Saark@2026
• Role       : Junior Design Engineer

* Note: Camera face scan verification is required upon login.

┌────────────────────────────────────────────────────────┐
│ SAARK EXPLORATION Pvt. Ltd.                            │
│ WE DEVELOPE HIGH END TECHNOLOGY                        │
│ 📍 Registered Office & Works:                          │
│ S NO 46, CHAITNAYA industrial estate, Manaji Nagar,    │
│ Narhe, Pune, Maharashtra 411041                        │
│                                                        │
│ © 2026 Saark Exploration Pvt. Ltd. All rights reserved.│
│ [THIS MAIL IS AUTO GENERATED • NOT SHAREABLE •         │
│  SCREENSHOTS NOT ALLOWED • NO REPLY]                   │
└────────────────────────────────────────────────────────┘
  `.trim();

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'Saark ERP <onboarding@resend.dev>',
      to: [target],
      subject: 'Welcome to Saark Exploration - Your ERP Account & Login Credentials',
      html: htmlContent,
      text: textContent,
    }),
  });

  const data = await response.json();
  console.log('HTTP Status:', response.status);
  console.log('Response Payload:', JSON.stringify(data, null, 2));

  if (response.ok) {
    console.log('\n\x1b[32m✔ SUCCESS: Email dispatched to ' + target + ' with Message ID: ' + data.id + '\x1b[0m');
  } else {
    console.error('\n\x1b[31m✖ FAILED: ' + (data.message || JSON.stringify(data)) + '\x1b[0m');
  }
}

dispatchLiveEmail().catch(console.error);
