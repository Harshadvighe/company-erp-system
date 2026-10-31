import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import * as fs from 'fs';
import * as path from 'path';

export interface SendWelcomeEmailOptions {
  to: string;
  fullName: string;
  username: string;
  password?: string;
  employeeCode: string;
  departmentName?: string;
  designation?: string;
  portalUrl?: string;
}

export interface SendCredentialsUpdatedEmailOptions {
  to: string;
  fullName: string;
  username: string;
  newPassword?: string;
  portalUrl?: string;
}

export interface MailLogEntry {
  id: string;
  timestamp: string;
  to: string;
  subject: string;
  type: 'WELCOME_ONBOARDING' | 'CREDENTIALS_UPDATED';
  success: boolean;
  contentSnippet: string;
  filePath?: string;
}

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;
  private readonly mailLogsDir: string;
  private readonly portalBaseUrl: string;

  constructor() {
    this.portalBaseUrl = process.env.PORTAL_URL || 'http://localhost:3000';
    this.mailLogsDir = path.join(
      process.env.STORAGE_LOCAL_BASE_PATH || path.join(__dirname, '../../../../storage'),
      'mail_logs',
    );

    if (!fs.existsSync(this.mailLogsDir)) {
      try {
        fs.mkdirSync(this.mailLogsDir, { recursive: true });
      } catch (err: any) {
        this.logger.warn(`Could not create mail logs directory: ${err.message}`);
      }
    }

    this.initTransporter();
  }

  public initTransporter() {
    let smtpHost = process.env.SMTP_HOST;
    let smtpPort = parseInt(process.env.SMTP_PORT || '587', 10);
    let smtpUser = process.env.SMTP_USER;
    let smtpPass = process.env.SMTP_PASS;

    // Check storage/settings.json
    try {
      const storageDir =
        process.env.STORAGE_LOCAL_BASE_PATH || path.join(__dirname, '../../../../storage');
      const settingsPath = path.join(storageDir, 'settings.json');
      if (fs.existsSync(settingsPath)) {
        const fileContent = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
        if (fileContent.smtpHost) smtpHost = fileContent.smtpHost;
        if (fileContent.smtpPort) smtpPort = parseInt(fileContent.smtpPort, 10);
        if (fileContent.smtpUser) smtpUser = fileContent.smtpUser;
        if (fileContent.smtpPass) smtpPass = fileContent.smtpPass;
      }
    } catch (_) {}

    if (smtpHost && smtpUser && smtpPass) {
      try {
        this.transporter = nodemailer.createTransport({
          host: smtpHost,
          port: smtpPort,
          secure: smtpPort === 465,
          auth: {
            user: smtpUser,
            pass: smtpPass,
          },
        });
        this.logger.log(`SMTP Mail Transporter initialized with host: ${smtpHost}:${smtpPort} (User: ${smtpUser})`);
      } catch (err: any) {
        this.logger.error(`Failed to initialize SMTP transporter: ${err.message}`);
        this.transporter = null;
      }
    } else {
      this.logger.log(
        'SMTP credentials not fully configured in environment or settings. Using Audit Mail Delivery Logger.',
      );
      this.transporter = null;
    }
  }

  public isSmtpConfigured(): boolean {
    return this.transporter !== null || Boolean(process.env.RESEND_API_KEY);
  }

  public async sendDirectTestEmail(to: string): Promise<{ success: boolean; message: string }> {
    const subject = 'Saark Exploration ERP - Test Email';
    const text = `This is a test notification from Saark Exploration ERP confirming that automatic email dispatch is operational.\n\nTimestamp: ${new Date().toISOString()}`;
    const html = `<div style="font-family: Arial; padding: 20px; background: #1a1c20; color: #fff; border-radius: 8px;">
      <h2 style="color: #F26522;">Saark Exploration ERP</h2>
      <p>Automatic email dispatch test successful!</p>
      <p><strong>Timestamp:</strong> ${new Date().toISOString()}</p>
    </div>`;
    const sent = await this.dispatchEmail(to, subject, html, text, 'WELCOME_ONBOARDING');
    return {
      success: sent,
      message: sent
        ? (this.isSmtpConfigured() ? `Live email delivered via API/SMTP to ${to}` : `Email logged to audit log for ${to}`)
        : `Failed to deliver email to ${to}`,
    };
  }

  /**
   * Sends or logs an email, saving an audit copy to storage/mail_logs
   */
  private async dispatchEmail(
    to: string,
    subject: string,
    html: string,
    text: string,
    type: 'WELCOME_ONBOARDING' | 'CREDENTIALS_UPDATED',
  ): Promise<boolean> {
    const fromAddress = process.env.SMTP_FROM || process.env.EMAIL_FROM || 'no-reply@saarkexploration.com';
    const logId = `mail_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const timestamp = new Date().toISOString();

    let success = false;
    let errorMsg = '';

    // 1. Direct SMTP Transporter (unrestricted, sends to any recipient)
    if (this.transporter) {
      try {
        await this.transporter.sendMail({
          from: fromAddress.includes('<') ? fromAddress : `"Saark Exploration ERP" <${fromAddress}>`,
          to,
          subject,
          text,
          html,
        });
        success = true;
        this.logger.log(`[SMTP Sent] Email dispatched successfully to ${to} (Subject: ${subject})`);
      } catch (err: any) {
        errorMsg = `SMTP error: ${err.message}`;
        this.logger.error(`[SMTP Failed] Error sending email to ${to}: ${err.message}`);
      }
    }

    // 2. Direct REST Email API (Resend fallback if SMTP not used or failed)
    const resendApiKey = process.env.RESEND_API_KEY;
    if (!success && resendApiKey) {
      try {
        const response = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${resendApiKey.trim()}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: process.env.EMAIL_FROM || 'Saark ERP <onboarding@resend.dev>',
            to: [to],
            subject,
            html,
            text,
          }),
        });

        const data: any = await response.json();
        if (response.ok) {
          success = true;
          this.logger.log(`[Resend API Sent] Email dispatched successfully to ${to} (Message ID: ${data.id})`);
        } else {
          errorMsg = (errorMsg ? errorMsg + ' | ' : '') + (data.message || JSON.stringify(data));
          this.logger.error(`[Resend API Failed] Error sending to ${to}: ${errorMsg}`);
        }
      } catch (err: any) {
        errorMsg = (errorMsg ? errorMsg + ' | ' : '') + err.message;
        this.logger.error(`[Resend API Error] ${err.message}`);
      }
    } else if (!success && !this.transporter && !resendApiKey) {
      // In development or when SMTP isn't set, simulated delivery logs cleanly
      success = true;
      this.logger.log(`[Mail Logger] Outgoing mail generated for <${to}>: "${subject}"`);
    }

    // Persist mail record to storage/mail_logs for full auditability
    try {
      const logFile = path.join(this.mailLogsDir, `${logId}.json`);
      const logData = {
        id: logId,
        timestamp,
        to,
        from: fromAddress,
        subject,
        type,
        success,
        errorMsg: errorMsg || null,
        text,
        html,
      };
      fs.writeFileSync(logFile, JSON.stringify(logData, null, 2), 'utf8');
    } catch (saveErr: any) {
      this.logger.warn(`Could not save mail log file: ${saveErr.message}`);
    }

    return success;
  }

  /**
   * Helper to retrieve base64 data URI of company logo for email embedding
   */
  private getCompanyLogoBase64(): string {
    try {
      const candidates = [
        path.join(process.cwd(), 'storage', 'company_logo.jpg'),
        path.join(__dirname, '../../../../storage', 'company_logo.jpg'),
        path.join(process.cwd(), 'public', 'assets', 'saark_logo.jpg'),
      ];
      for (const p of candidates) {
        if (fs.existsSync(p)) {
          return `data:image/jpeg;base64,${fs.readFileSync(p).toString('base64')}`;
        }
      }
    } catch (_) {}
    return '';
  }

  /**
   * 1. Auto-generated Welcome & Account Confirmation Mail after Admin Approval
   */
  public async sendWelcomeEmployeeEmail(options: SendWelcomeEmailOptions): Promise<boolean> {
    const portalUrl = options.portalUrl || this.portalBaseUrl;
    const subject = 'Saark Exploration ERP - Account Login Credentials';
    const logoImg = this.getCompanyLogoBase64();

    const html = `
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
      ${logoImg ? `<img src="${logoImg}" alt="Logo" style="max-height: 52px; width: auto; max-width: 180px; object-fit: contain; background: #ffffff; padding: 4px 8px; border-radius: 4px; margin-bottom: 6px;" /><br/>` : ''}
      <h1>SAARK EXPLORATION Pvt. Ltd.</h1>
      <p>WE DEVELOPE HIGH END TECHNOLOGY</p>
    </div>
    <div class="body">
      <div class="salutation">Dear ${options.fullName},</div>
      <div class="subtext">
        Your ERP system account (${options.employeeCode}) is ready. Please use the credentials below to log in:
      </div>

      <div class="cred-card">
        <div class="row"><span class="lbl">Portal URL:</span><span class="val">${portalUrl}</span></div>
        <div class="row"><span class="lbl">Username:</span><span class="val">${options.username}</span></div>
        ${options.password ? `<div class="row"><span class="lbl">Password:</span><span class="val">${options.password}</span></div>` : ''}
        ${options.designation ? `<div class="row"><span class="lbl">Designation:</span><span class="val">${options.designation}</span></div>` : ''}
      </div>

      <div class="action">
        <a href="${portalUrl}" class="btn">Sign In to ERP Portal</a>
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

    const text = `
Dear ${options.fullName},

Your Saark ERP account (${options.employeeCode}) is ready:

• Portal URL : ${portalUrl}
• Username   : ${options.username}
${options.password ? `• Password   : ${options.password}` : ''}
${options.designation ? `• Role       : ${options.designation}` : ''}

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

    return this.dispatchEmail(options.to, subject, html, text, 'WELCOME_ONBOARDING');
  }

  /**
   * 2. Auto-generated Notification Mail when Username or Password is Changed by HR / Admin
   */
  public async sendCredentialsUpdatedEmail(
    options: SendCredentialsUpdatedEmailOptions,
  ): Promise<boolean> {
    const portalUrl = options.portalUrl || this.portalBaseUrl;
    const subject = 'Saark Exploration ERP - Account Credentials Updated';
    const logoImg = this.getCompanyLogoBase64();

    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0e1013; color: #dcdcdc; margin: 0; padding: 20px; }
    .card { max-width: 520px; margin: 0 auto; background-color: #16181d; border-radius: 8px; border: 1px solid #2a2d35; overflow: hidden; }
    .top-bar { background: #111317; padding: 18px 20px; text-align: center; border-bottom: 2px solid #1976D2; }
    .top-bar h1 { margin: 6px 0 0 0; color: #ffffff; font-size: 18px; font-weight: 700; letter-spacing: 0.5px; }
    .top-bar p { margin: 3px 0 0 0; color: #64b5f6; font-size: 10px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; }
    .body { padding: 20px 24px; }
    .salutation { font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 12px; }
    .subtext { font-size: 13px; line-height: 1.5; color: #b0b4be; margin-bottom: 16px; }
    .cred-card { background: #1e2129; border: 1px solid #2d313c; border-left: 4px solid #1976D2; border-radius: 6px; padding: 14px 18px; margin-bottom: 20px; }
    .row { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; }
    .row:last-child { margin-bottom: 0; }
    .lbl { color: #8a909d; font-weight: 500; }
    .val { color: #ffffff; font-weight: 600; font-family: 'Consolas', monospace; }
    .action { text-align: center; margin: 18px 0; }
    .btn { background-color: #1976D2; color: #ffffff !important; text-decoration: none; padding: 10px 26px; border-radius: 5px; font-weight: 600; font-size: 13px; display: inline-block; }
    .tip { font-size: 11px; color: #ffa726; text-align: center; margin-bottom: 16px; }
    .footer { padding: 16px 20px; text-align: center; background-color: #111317; border-top: 1px solid #22252c; }
    .box { font-family: 'Consolas', 'Courier New', monospace; white-space: pre; font-size: 10.5px; line-height: 1.4; color: #b5b9c2; background-color: #0b0c0f; border: 1px solid #2c303a; border-radius: 5px; padding: 12px 14px; text-align: left; display: inline-block; max-width: 100%; box-sizing: border-box; overflow-x: auto; }
  </style>
</head>
<body>
  <div class="card">
    <div class="top-bar">
      ${logoImg ? `<img src="${logoImg}" alt="Logo" style="max-height: 52px; width: auto; max-width: 180px; object-fit: contain; background: #ffffff; padding: 4px 8px; border-radius: 4px; margin-bottom: 6px;" /><br/>` : ''}
      <h1>SAARK EXPLORATION Pvt. Ltd.</h1>
      <p>Security &amp; Account Update Notice</p>
    </div>
    <div class="body">
      <div class="salutation">Dear ${options.fullName},</div>
      <div class="subtext">
        Your ERP system account credentials have been updated by Administration:
      </div>

      <div class="cred-card">
        <div class="row"><span class="lbl">Portal URL:</span><span class="val">${portalUrl}</span></div>
        <div class="row"><span class="lbl">Username:</span><span class="val">${options.username}</span></div>
        <div class="row"><span class="lbl">Password:</span><span class="val">${options.newPassword || '[Password Unchanged]'}</span></div>
      </div>

      <div class="action">
        <a href="${portalUrl}" class="btn">Log In with Updated Details</a>
      </div>

      <div class="tip">
        * If you did not request this change, please alert HR or IT Helpdesk immediately.
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

    const text = `
Dear ${options.fullName},

Your Saark ERP login credentials have been updated by Administration:

• Portal URL : ${portalUrl}
• Username   : ${options.username}
• Password   : ${options.newPassword || '[Password Unchanged]'}

* If you did not request this change, please alert HR immediately.

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

    return this.dispatchEmail(options.to, subject, html, text, 'CREDENTIALS_UPDATED');
  }

  /**
   * Returns recent mail logs for admin audit inspection
   */
  public async getRecentMailLogs(): Promise<MailLogEntry[]> {
    try {
      if (!fs.existsSync(this.mailLogsDir)) return [];
      const files = fs.readdirSync(this.mailLogsDir).filter((f) => f.endsWith('.json'));
      const logs: MailLogEntry[] = [];

      for (const f of files.slice(-30)) {
        try {
          const content = JSON.parse(
            fs.readFileSync(path.join(this.mailLogsDir, f), 'utf8'),
          );
          logs.push({
            id: content.id,
            timestamp: content.timestamp,
            to: content.to,
            subject: content.subject,
            type: content.type,
            success: content.success,
            contentSnippet: content.text?.slice(0, 100) || '',
            filePath: path.join(this.mailLogsDir, f),
          });
        } catch (_) {}
      }

      return logs.sort((a, b) => b.timestamp.localeCompare(a.timestamp));
    } catch (err: any) {
      this.logger.warn(`Could not read mail logs: ${err.message}`);
      return [];
    }
  }
}
