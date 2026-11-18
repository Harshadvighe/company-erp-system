import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import * as crypto from 'crypto';
import { MailService } from '../../core/notifications/mail.service';
import { AuditService } from '../../core/audit/audit.service';
import { RequestPermissionDto } from './dto/request-permission.dto';
import { VerifyPermissionOtpDto } from './dto/verify-permission-otp.dto';

interface AccessChallenge {
  otp: string;
  requesterEmail: string;
  requesterName: string;
  targetResource: string;
  changeSummary?: string;
  ipAddress?: string;
  createdAt: Date;
  expiresAt: Date;
  attempts: number;
  authorized: boolean;
  leaseToken?: string;
}

@Injectable()
export class GovernanceService {
  private readonly logger = new Logger(GovernanceService.name);
  public static readonly AUTHOR_EMAIL = 'sonwanep968@gmail.com';

  // Active in-memory permission challenges and leases (keyed by lowercase requesterEmail + targetResource)
  private readonly challenges = new Map<string, AccessChallenge>();
  // Active authorized leases (keyed by leaseToken)
  private readonly activeLeases = new Map<string, AccessChallenge>();

  constructor(
    private readonly mailService: MailService,
    private readonly auditService: AuditService,
  ) {}

  /**
   * Generates a 6-digit OTP and dispatches an authorization challenge email to sonwanep968@gmail.com
   */
  async requestPermissionOtp(
    dto: RequestPermissionDto,
    ipAddress?: string,
  ): Promise<{ success: boolean; message: string; author: string }> {
    const key = `${dto.requesterEmail.toLowerCase().trim()}_${dto.targetResource.toUpperCase().trim()}`;

    // Generate secure 6-digit cryptographic OTP
    const otp = crypto.randomInt(100000, 999999).toString();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 10 * 60 * 1000); // 10 minutes expiry

    const challenge: AccessChallenge = {
      otp,
      requesterEmail: dto.requesterEmail.toLowerCase().trim(),
      requesterName: dto.requesterName.trim(),
      targetResource: dto.targetResource.toUpperCase().trim(),
      changeSummary: dto.changeSummary || 'Architectural documentation or new module edit request',
      ipAddress: ipAddress || '127.0.0.1',
      createdAt: now,
      expiresAt,
      attempts: 0,
      authorized: false,
    };

    this.challenges.set(key, challenge);

    // Dispatch Security OTP Email to primary author: sonwanep968@gmail.com
    const subject = `[URGENT SECURITY] Code/Architecture Edit Permission Requested - OTP: ${otp}`;
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #16181D; color: #FFFFFF; border: 1px solid #2B303A; border-radius: 12px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #F26522, #D44E0E); padding: 24px; text-align: center;">
          <h1 style="margin: 0; font-size: 20px; letter-spacing: 2px; color: #FFFFFF;">SAARK EXPLORATION ERP</h1>
          <p style="margin: 4px 0 0 0; font-size: 12px; color: #FFE8DF; letter-spacing: 1px;">CODEBASE GOVERNANCE & ARCHITECTURAL SHIELD</p>
        </div>
        
        <div style="padding: 28px;">
          <div style="background: #20242C; border-left: 4px solid #F26522; padding: 14px; border-radius: 4px; margin-bottom: 20px;">
            <p style="margin: 0; font-size: 13px; color: #E0E3EA; line-height: 1.5;">
              <strong>Security Alert:</strong> A user has requested permission to modify protected project architecture documentation or implement a new ERP module.
            </p>
          </div>

          <table style="width: 100%; border-collapse: collapse; margin-bottom: 24px; font-size: 13px;">
            <tr>
              <td style="padding: 8px 0; color: #8C96A8; width: 140px;">Primary Author:</td>
              <td style="padding: 8px 0; color: #00E5FF; font-weight: bold;">${GovernanceService.AUTHOR_EMAIL}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #8C96A8;">Requester Name:</td>
              <td style="padding: 8px 0; color: #FFFFFF; font-weight: 600;">${dto.requesterName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #8C96A8;">Requester Email:</td>
              <td style="padding: 8px 0; color: #FFFFFF;">${dto.requesterEmail}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #8C96A8;">Target Resource:</td>
              <td style="padding: 8px 0; color: #FFA726; font-weight: bold;">${dto.targetResource}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #8C96A8;">Proposed Changes:</td>
              <td style="padding: 8px 0; color: #FFFFFF;">${challenge.changeSummary}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #8C96A8;">Client IP Address:</td>
              <td style="padding: 8px 0; color: #8C96A8;">${challenge.ipAddress}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #8C96A8;">Request Timestamp:</td>
              <td style="padding: 8px 0; color: #8C96A8;">${now.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })} IST</td>
            </tr>
          </table>

          <div style="background: #0E1014; border: 1px dashed #F26522; border-radius: 8px; padding: 20px; text-align: center; margin-bottom: 24px;">
            <div style="font-size: 12px; color: #8C96A8; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 6px;">Authorization OTP (Valid for 10 minutes)</div>
            <div style="font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #F26522; font-family: monospace;">${otp}</div>
          </div>

          <p style="font-size: 12px; color: #F87171; line-height: 1.5; margin-bottom: 0;">
            ⚠️ <strong>Notice:</strong> If you did not personally request this change or do not recognize the requester, DO NOT share this OTP. Without this OTP, all changes to the architectural files and module code will remain strictly blocked.
          </p>
        </div>

        <div style="background: #111317; padding: 14px 28px; text-align: center; font-size: 11px; color: #606877; border-top: 1px solid #20242C;">
          © 2026 Saark Exploration Private Limited • Automated Governance System
        </div>
      </div>
    `;

    const text = `SAARK EXPLORATION ERP - CODEBASE GOVERNANCE\n\n` +
      `Edit permission requested for resource: ${dto.targetResource}\n` +
      `Requester: ${dto.requesterName} (${dto.requesterEmail})\n` +
      `Proposed Changes: ${challenge.changeSummary}\n` +
      `Client IP: ${challenge.ipAddress}\n\n` +
      `AUTHORIZATION OTP: ${otp} (Valid for 10 minutes)\n\n` +
      `Do not share this OTP if you did not authorize this action.\n`;

    // Always log secure challenge to server console for authoritative audit
    this.logger.warn(`🔐 [GOVERNANCE OTP] Author Challenge OTP for ${GovernanceService.AUTHOR_EMAIL}: ${otp}`);

    // 1. Attempt direct SMTP delivery to primary author: sonwanep968@gmail.com
    let smtpSuccess = false;
    try {
      if ((this.mailService as any).transporter) {
        await (this.mailService as any).transporter.sendMail({
          from: `"Saark ERP Governance" <${process.env.SMTP_USER || 'pooja.saark@gmail.com'}>`,
          to: GovernanceService.AUTHOR_EMAIL,
          subject,
          text,
          html,
        });
        smtpSuccess = true;
        this.logger.log(`[Governance SMTP] Security OTP email delivered to primary author ${GovernanceService.AUTHOR_EMAIL}`);
      }
    } catch (err: any) {
      this.logger.warn(`[Governance SMTP Notice] Primary SMTP delivery to ${GovernanceService.AUTHOR_EMAIL} deferred: ${err.message}`);
    }

    // 2. Dispatch via Resend Cloud API to pooja.saark@gmail.com as verified gateway recipient
    let resendSuccess = false;
    if (process.env.RESEND_API_KEY) {
      try {
        const resendRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${process.env.RESEND_API_KEY.trim()}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: process.env.EMAIL_FROM || 'Saark ERP <onboarding@resend.dev>',
            to: ['pooja.saark@gmail.com'],
            subject: `[AUTHOR SECURITY COPY] Code Edit OTP: ${otp} (for ${GovernanceService.AUTHOR_EMAIL})`,
            html,
            text,
          }),
        });
        if (resendRes.ok) {
          resendSuccess = true;
          this.logger.log(`[Governance Resend] Security OTP successfully delivered to pooja.saark@gmail.com`);
        }
      } catch (err: any) {
        this.logger.warn(`[Governance Resend Notice] Resend delivery deferred: ${err.message}`);
      }
    }

    await this.auditService.log({
      userEmail: dto.requesterEmail,
      action: 'AUTHOR_PERMISSION_OTP_REQUESTED',
      module: 'GOVERNANCE',
      details: `Permission OTP requested by ${dto.requesterName} (${dto.requesterEmail}) for resource ${dto.targetResource}. Challenge dispatched to primary author ${GovernanceService.AUTHOR_EMAIL}.`,
      ipAddress,
    });

    return {
      success: true,
      message: `Permission challenge initiated. 6-digit authorization OTP has been dispatched to author (${GovernanceService.AUTHOR_EMAIL}). Enter OTP to unlock edit access.`,
      author: GovernanceService.AUTHOR_EMAIL,
    };
  }

  /**
   * Verifies the 6-digit OTP received by sonwanep968@gmail.com and grants temporary lease token
   */
  async verifyPermissionOtp(
    dto: VerifyPermissionOtpDto,
    ipAddress?: string,
  ): Promise<{
    authorized: boolean;
    leaseToken: string;
    expiresAt: string;
    author: string;
    message: string;
  }> {
    const key = `${dto.requesterEmail.toLowerCase().trim()}_${dto.targetResource.toUpperCase().trim()}`;
    const challenge = this.challenges.get(key);

    if (!challenge) {
      throw new BadRequestException(
        'No active authorization challenge found for this email and resource. Please request a new OTP first.',
      );
    }

    if (new Date() > challenge.expiresAt) {
      this.challenges.delete(key);
      throw new UnauthorizedException(
        'The authorization OTP has expired (10-minute limit exceeded). Please request a new OTP.',
      );
    }

    challenge.attempts++;

    if (challenge.attempts > 4) {
      this.challenges.delete(key);
      await this.auditService.log({
        userEmail: dto.requesterEmail,
        action: 'AUTHOR_PERMISSION_LOCKOUT',
        module: 'GOVERNANCE',
        details: `Too many failed OTP attempts for ${dto.requesterEmail}. Challenge destroyed.`,
        ipAddress,
      });
      throw new UnauthorizedException(
        'Too many invalid OTP attempts. Access challenge locked. Please contact the author sonwanep968@gmail.com directly.',
      );
    }

    // Verify OTP against secret
    if (challenge.otp.trim() !== dto.otp.trim()) {
      await this.auditService.log({
        userEmail: dto.requesterEmail,
        action: 'AUTHOR_PERMISSION_OTP_FAILED',
        module: 'GOVERNANCE',
        details: `Invalid OTP attempt (${challenge.attempts}/4) by ${dto.requesterEmail} for resource ${dto.targetResource}.`,
        ipAddress,
      });
      throw new UnauthorizedException(
        `Invalid authorization OTP. Verification failed (Attempt ${challenge.attempts} of 4).`,
      );
    }

    // OTP Validated! Issue 2-hour cryptographic lease token
    const leaseToken = `LEASE-${Date.now().toString(36).toUpperCase()}-${crypto.randomBytes(12).toString('hex')}`;
    const leaseExpiry = new Date(Date.now() + 2 * 60 * 60 * 1000); // 2 hours

    challenge.authorized = true;
    challenge.leaseToken = leaseToken;

    this.activeLeases.set(leaseToken, {
      ...challenge,
      expiresAt: leaseExpiry,
    });
    this.challenges.delete(key);

    await this.auditService.log({
      userEmail: dto.requesterEmail,
      action: 'AUTHOR_PERMISSION_GRANTED',
      module: 'GOVERNANCE',
      details: `Edit permission successfully verified and granted by author ${GovernanceService.AUTHOR_EMAIL} for resource ${dto.targetResource}. Lease token: ${leaseToken}.`,
      ipAddress,
    });

    return {
      authorized: true,
      leaseToken,
      expiresAt: leaseExpiry.toISOString(),
      author: GovernanceService.AUTHOR_EMAIL,
      message: `Authorization confirmed by primary author ${GovernanceService.AUTHOR_EMAIL}. Edit access granted for resource ${dto.targetResource}.`,
    };
  }

  /**
   * Verifies if a given lease token is active and valid for the specified resource
   */
  public isLeaseValid(leaseToken: string, targetResource: string): boolean {
    if (!leaseToken) return false;
    const lease = this.activeLeases.get(leaseToken);
    if (!lease) return false;

    if (new Date() > lease.expiresAt) {
      this.activeLeases.delete(leaseToken);
      return false;
    }

    return (
      lease.authorized &&
      (lease.targetResource === targetResource.toUpperCase() ||
        lease.targetResource === 'CORE_CODE_EDIT')
    );
  }

  /**
   * Returns current governance status and locked resources
   */
  public getGovernanceStatus() {
    return {
      primaryAuthor: GovernanceService.AUTHOR_EMAIL,
      isEnforced: true,
      protectedFiles: [
        'SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md',
        'SAARK_ERP_LINKS_AND_ACCESS.txt',
      ],
      protectedModules: [
        'NPD_PRODUCT_DEVELOPMENT',
        'SALES_MARKETING',
        'PRODUCTION_PANELS',
        'HR_BIOMETRICS',
        'CORE_AUTHENTICATION',
      ],
      activeChallengesCount: this.challenges.size,
      activeLeasesCount: this.activeLeases.size,
      securityPolicy:
        'Zero-trust modification policy. All structural changes require explicit OTP confirmation dispatched to sonwanep968@gmail.com.',
    };
  }
}

