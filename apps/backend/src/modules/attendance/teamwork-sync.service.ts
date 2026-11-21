import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import {
  TeamworkConfigDto,
  TeamworkTestConnectionDto,
  TeamworkSyncRequestDto,
  TeamworkManualPunchDto,
} from './dto/teamwork-config.dto';

export interface TeamworkSyncResult {
  success: boolean;
  status: string;
  recordsFetched: number;
  recordsInserted: number;
  recordsUpdated: number;
  recordsSkipped: number;
  message?: string;
  error?: string;
  details?: any[];
}

@Injectable()
export class TeamworkSyncService {
  private readonly logger = new Logger(TeamworkSyncService.name);
  private static readonly DEVICE_CODE = 'TEAMWORK_CLOUD';

  constructor(private readonly prisma: PrismaService) {}

  // ───────────────────────────────────────────────────────────────────────────
  // CONFIGURATION MANAGEMENT
  // ───────────────────────────────────────────────────────────────────────────

  async getConfig() {
    const device = await this.prisma.biometricDevice.findUnique({
      where: { deviceCode: TeamworkSyncService.DEVICE_CODE },
    });

    if (!device) {
      return {
        configured: false,
        siteUrl: '',
        apiKeyMasked: '',
        autoSyncEnabled: false,
        syncIntervalMinutes: 15,
        lastSyncAt: null,
        lastSyncStatus: 'NOT_CONFIGURED',
      };
    }

    const key = device.apiKey || '';
    const masked = key.length > 8 ? `${key.substring(0, 4)}••••${key.substring(key.length - 4)}` : '••••••••';

    return {
      configured: true,
      id: device.id,
      siteUrl: device.apiEndpoint || '',
      apiKeyMasked: masked,
      autoSyncEnabled: device.autoSyncEnabled,
      syncIntervalMinutes: device.syncIntervalMinutes,
      lastSyncAt: device.lastSyncAt,
      lastSyncStatus: device.lastSyncStatus,
      lastSyncRecordCount: device.lastSyncRecordCount,
      lastSyncError: device.lastSyncError,
    };
  }

  async saveConfig(dto: TeamworkConfigDto) {
    const normalizedUrl = this.normalizeUrl(dto.siteUrl);

    // Verify connection first before persisting
    const test = await this.testConnection({ siteUrl: normalizedUrl, apiKey: dto.apiKey });
    if (!test.success) {
      this.logger.warn(`Saving Teamwork config with warning: ${test.error || test.message}`);
    }

    const device = await this.prisma.biometricDevice.upsert({
      where: { deviceCode: TeamworkSyncService.DEVICE_CODE },
      create: {
        deviceCode: TeamworkSyncService.DEVICE_CODE,
        deviceName: 'Teamwork Cloud Punching',
        deviceType: 'CLOUD',
        manufacturer: 'Teamwork',
        model: 'REST-API-v1/v2',
        connectionType: 'CLOUD',
        apiEndpoint: normalizedUrl,
        apiKey: dto.apiKey,
        autoSyncEnabled: dto.autoSyncEnabled ?? true,
        syncIntervalMinutes: dto.syncIntervalMinutes ?? 15,
        location: 'Teamwork Cloud App & Web',
        notes: 'Employee manual punching and shift time tracking integration',
        isActive: true,
        lastSyncStatus: test.success ? 'CONNECTED' : 'CONFIGURED_PENDING_VERIFY',
      },
      update: {
        apiEndpoint: normalizedUrl,
        apiKey: dto.apiKey,
        autoSyncEnabled: dto.autoSyncEnabled ?? true,
        syncIntervalMinutes: dto.syncIntervalMinutes ?? 15,
        isActive: true,
        lastSyncStatus: test.success ? 'CONNECTED' : 'CONFIGURED_PENDING_VERIFY',
      },
    });

    return {
      success: true,
      message: 'Teamwork credentials and sync preferences saved successfully!',
      device: {
        id: device.id,
        deviceCode: device.deviceCode,
        siteUrl: device.apiEndpoint,
        autoSyncEnabled: device.autoSyncEnabled,
        status: device.lastSyncStatus,
      },
      verification: test,
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TEST CONNECTIVITY
  // ───────────────────────────────────────────────────────────────────────────

  async testConnection(dto: TeamworkTestConnectionDto): Promise<{ success: boolean; message: string; data?: any; error?: string }> {
    const siteUrl = this.normalizeUrl(dto.siteUrl);
    const authHeaders = this.buildAuthHeaders(dto.apiKey);

    try {
      // 1. Try Teamwork authenticate.json endpoint
      const authUrl = `${siteUrl}/authenticate.json`;
      this.logger.log(`Pinging Teamwork endpoint: ${authUrl}`);

      const response = await fetch(authUrl, {
        method: 'GET',
        headers: authHeaders,
        signal: AbortSignal.timeout(10000),
      });

      if (response.ok) {
        const json = await response.json().catch(() => ({}));
        const account = json.account || {};
        const user = json.user || {};

        return {
          success: true,
          message: `Successfully connected to Teamwork (${account.name || 'Account Verified'})!`,
          data: {
            accountName: account.name,
            company: account.companyname,
            userEmail: user.emailAddress || user.email,
            userName: `${user.firstName || ''} ${user.lastName || ''}`.trim(),
            avatarUrl: user.avatarUrl,
          },
        };
      }

      // 2. Fallback: try projects.json or me.json
      const projectsUrl = `${siteUrl}/projects.json?pageSize=1`;
      const projRes = await fetch(projectsUrl, {
        method: 'GET',
        headers: authHeaders,
        signal: AbortSignal.timeout(10000),
      });

      if (projRes.ok) {
        return {
          success: true,
          message: 'Connected to Teamwork successfully via API key!',
        };
      }

      const errorText = await response.text().catch(() => '');
      return {
        success: false,
        message: `Teamwork returned HTTP ${response.status} (${response.statusText})`,
        error: errorText.slice(0, 200) || 'Invalid Teamwork credentials or site URL.',
      };
    } catch (err: any) {
      this.logger.error(`Failed to connect to Teamwork at ${siteUrl}`, err);
      return {
        success: false,
        message: 'Could not reach Teamwork server.',
        error: err.message,
      };
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SYNC ATTENDANCE PUNCHES FROM TEAMWORK
  // ───────────────────────────────────────────────────────────────────────────

  async syncPunches(dto?: TeamworkSyncRequestDto): Promise<TeamworkSyncResult> {
    const device = await this.prisma.biometricDevice.findUnique({
      where: { deviceCode: TeamworkSyncService.DEVICE_CODE },
    });

    if (!device || !device.apiEndpoint || !device.apiKey) {
      throw new BadRequestException('Teamwork is not configured yet. Please configure your Site URL and API Key first.');
    }

    const todayStr = this.formatDateOnly(new Date());
    const fromStr = dto?.fromDate ? dto.fromDate.replace(/-/g, '') : todayStr.replace(/-/g, '');
    const toStr = dto?.toDate ? dto.toDate.replace(/-/g, '') : todayStr.replace(/-/g, '');

    const siteUrl = this.normalizeUrl(device.apiEndpoint);
    const authHeaders = this.buildAuthHeaders(device.apiKey);

    // Call Teamwork time_entries API: https://{siteUrl}/time_entries.json?fromdate=YYYYMMDD&todate=YYYYMMDD
    const endpoint = `${siteUrl}/time_entries.json?fromdate=${fromStr}&todate=${toStr}&pageSize=250`;
    this.logger.log(`Fetching Teamwork time entries from: ${endpoint}`);

    let rawEntries: any[] = [];

    try {
      const response = await fetch(endpoint, {
        method: 'GET',
        headers: authHeaders,
        signal: AbortSignal.timeout(15000),
      });

      if (!response.ok) {
        const errText = await response.text().catch(() => '');
        throw new Error(`Teamwork API responded with status ${response.status}: ${errText.slice(0, 150)}`);
      }

      const json = await response.json();
      rawEntries = json['time-entries'] || json.timeEntries || [];
    } catch (err: any) {
      this.logger.error('Failed to fetch time entries from Teamwork API', err);

      await this.prisma.biometricDevice.update({
        where: { id: device.id },
        data: {
          lastSyncAt: new Date(),
          lastSyncStatus: 'FAILED',
          lastSyncError: err.message,
        },
      });

      return {
        success: false,
        status: 'FAILED',
        recordsFetched: 0,
        recordsInserted: 0,
        recordsUpdated: 0,
        recordsSkipped: 0,
        error: err.message,
      };
    }

    // Process and integrate punches into Saark Attendance Ledger
    let inserted = 0;
    let updated = 0;
    let skipped = 0;
    const details: any[] = [];

    // Group entries by employee and date
    for (const entry of rawEntries) {
      try {
        const res = await this.processTeamworkEntry(device, entry);
        details.push(res);
        if (res.action === 'inserted') inserted++;
        else if (res.action === 'updated') updated++;
        else skipped++;
      } catch (e: any) {
        skipped++;
        details.push({ entryId: entry.id, action: 'error', error: e.message });
      }
    }

    const overallStatus = inserted > 0 || updated > 0 ? 'SUCCESS' : rawEntries.length === 0 ? 'NO_NEW_PUNCHES' : 'PARTIAL';

    await this.prisma.biometricDevice.update({
      where: { id: device.id },
      data: {
        lastSyncAt: new Date(),
        lastSyncStatus: overallStatus,
        lastSyncRecordCount: rawEntries.length,
        lastSyncError: null,
      },
    });

    return {
      success: true,
      status: overallStatus,
      recordsFetched: rawEntries.length,
      recordsInserted: inserted,
      recordsUpdated: updated,
      recordsSkipped: skipped,
      message: `Teamwork sync finished: ${rawEntries.length} entries fetched, ${inserted} new records created, ${updated} records updated.`,
      details,
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DIRECT / MANUAL PUNCH INGESTION (FROM APP OR WEBHOOK)
  // ───────────────────────────────────────────────────────────────────────────

  async logManualPunch(dto: TeamworkManualPunchDto) {
    const employee = await this.findEmployee(dto.employeeIdentifier);
    if (!employee) {
      throw new NotFoundException(`Employee '${dto.employeeIdentifier}' not found in Saark ERP`);
    }

    const punchTime = new Date(dto.punchTime);
    if (isNaN(punchTime.getTime())) {
      throw new BadRequestException('Invalid punch timestamp provided');
    }

    const punchDate = new Date(punchTime);
    punchDate.setHours(0, 0, 0, 0);

    const existing = await this.prisma.attendance.findUnique({
      where: {
        employeeId_punchDate: {
          employeeId: employee.id,
          punchDate,
        },
      },
    });

    const isCheckIn = dto.punchType === 'CHECK_IN' || (!existing?.punchIn && dto.punchType !== 'CHECK_OUT');

    if (!existing) {
      // Determine Late status based on shift
      const isLate = await this.isLateAgainstShift(employee.shiftCode || 'SHIFT_G', punchTime);
      const status = isLate ? 'LATE' : 'PRESENT';

      const created = await this.prisma.attendance.create({
        data: {
          employeeId: employee.id,
          punchDate,
          punchIn: isCheckIn ? punchTime : null,
          punchOut: isCheckIn ? null : punchTime,
          workHours: 0,
          status,
          shiftCode: employee.shiftCode || 'SHIFT_G',
          source: 'TEAMWORK',
          checkInNote: dto.notes || 'Punched via Teamwork',
          location: dto.location || 'Teamwork Mobile / Web',
        },
      });

      return {
        action: 'inserted',
        attendanceId: created.id,
        employeeName: `${employee.firstName} ${employee.lastName}`,
        punchIn: created.punchIn,
        punchOut: created.punchOut,
        status: created.status,
      };
    } else {
      const updateData: any = {
        source: 'TEAMWORK',
      };

      if (isCheckIn) {
        if (!existing.punchIn || punchTime < existing.punchIn) {
          updateData.punchIn = punchTime;
        }
      } else {
        if (!existing.punchOut || punchTime > existing.punchOut) {
          updateData.punchOut = punchTime;
        }
      }

      if (dto.notes) {
        updateData.checkOutNote = dto.notes;
      }

      // Calculate work hours if both punchIn and punchOut exist
      const finalIn = updateData.punchIn || existing.punchIn;
      const finalOut = updateData.punchOut || existing.punchOut;

      if (finalIn && finalOut) {
        const diffMs = finalOut.getTime() - finalIn.getTime();
        const hrs = Math.max(0, Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100);
        updateData.workHours = hrs;

        // Overtime check (standard 9 hour shift)
        if (hrs > 9.0) {
          updateData.overtimeHours = Math.round((hrs - 9.0) * 100) / 100;
        }
      }

      const updated = await this.prisma.attendance.update({
        where: {
          employeeId_punchDate: {
            employeeId: employee.id,
            punchDate,
          },
        },
        data: updateData,
      });

      return {
        action: 'updated',
        attendanceId: updated.id,
        employeeName: `${employee.firstName} ${employee.lastName}`,
        punchIn: updated.punchIn,
        punchOut: updated.punchOut,
        workHours: updated.workHours,
        status: updated.status,
      };
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WEBHOOK HANDLER
  // ───────────────────────────────────────────────────────────────────────────

  async handleWebhook(payload: any) {
    this.logger.log(`Received Teamwork webhook: ${JSON.stringify(payload).slice(0, 200)}`);

    const entry = payload.timeEntry || payload['time-entry'] || payload.entry || payload;
    if (!entry) {
      return { success: false, reason: 'No time-entry object in payload' };
    }

    const device = await this.prisma.biometricDevice.findUnique({
      where: { deviceCode: TeamworkSyncService.DEVICE_CODE },
    });

    return this.processTeamworkEntry(device, entry);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPER METHODS
  // ───────────────────────────────────────────────────────────────────────────

  private async processTeamworkEntry(device: any, entry: any) {
    // 1. Resolve employee
    const email = entry['person-email'] || entry.personEmail || entry.email;
    const name = `${entry['person-first-name'] || ''} ${entry['person-last-name'] || ''}`.trim();
    const personId = String(entry['person-id'] || entry.personId || '');

    const employee = await this.findEmployee(email, name, personId);
    if (!employee) {
      return {
        action: 'skipped',
        reason: `Employee not found for Teamwork user: ${name || email || personId}`,
      };
    }

    // 2. Parse date & time
    const rawDateStr = entry.date || entry.createdAt;
    const entryDate = new Date(rawDateStr);
    if (isNaN(entryDate.getTime())) {
      return { action: 'skipped', reason: `Invalid date: ${rawDateStr}` };
    }

    const punchDate = new Date(entryDate);
    punchDate.setHours(0, 0, 0, 0);

    const hours = parseFloat(entry.hours || '0') + parseFloat(entry.minutes || '0') / 60;

    // Check existing
    const existing = await this.prisma.attendance.findUnique({
      where: {
        employeeId_punchDate: {
          employeeId: employee.id,
          punchDate,
        },
      },
    });

    const isLate = await this.isLateAgainstShift(employee.shiftCode || 'SHIFT_G', entryDate);
    const memo = entry.description || 'Punched via Teamwork Cloud';

    if (!existing) {
      const punchIn = entryDate;
      const punchOut = hours > 0 ? new Date(punchIn.getTime() + hours * 3600 * 1000) : null;

      await this.prisma.attendance.create({
        data: {
          employeeId: employee.id,
          punchDate,
          punchIn,
          punchOut,
          workHours: hours,
          status: isLate ? 'LATE' : 'PRESENT',
          shiftCode: employee.shiftCode || 'SHIFT_G',
          deviceId: device?.id,
          devicePunchId: String(entry.id),
          source: 'TEAMWORK',
          checkInNote: memo,
          location: 'Teamwork Cloud Punching',
        },
      });

      return {
        action: 'inserted',
        employeeCode: employee.employeeCode,
        name: `${employee.firstName} ${employee.lastName}`,
        punchDate: this.formatDateOnly(punchDate),
      };
    } else {
      // Update existing record
      const updateData: any = {
        deviceId: device?.id,
        devicePunchId: String(entry.id),
        source: 'TEAMWORK',
      };

      if (!existing.punchIn || entryDate < existing.punchIn) {
        updateData.punchIn = entryDate;
      }

      if (hours > 0) {
        const calculatedOut = new Date(entryDate.getTime() + hours * 3600 * 1000);
        if (!existing.punchOut || calculatedOut > existing.punchOut) {
          updateData.punchOut = calculatedOut;
        }
      }

      const finalIn = updateData.punchIn || existing.punchIn;
      const finalOut = updateData.punchOut || existing.punchOut;

      if (finalIn && finalOut) {
        const diffMs = finalOut.getTime() - finalIn.getTime();
        updateData.workHours = Math.max(0, Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100);
      }

      await this.prisma.attendance.update({
        where: {
          employeeId_punchDate: {
            employeeId: employee.id,
            punchDate,
          },
        },
        data: updateData,
      });

      return {
        action: 'updated',
        employeeCode: employee.employeeCode,
        name: `${employee.firstName} ${employee.lastName}`,
        punchDate: this.formatDateOnly(punchDate),
      };
    }
  }

  private async findEmployee(emailOrCode?: string, name?: string, personId?: string) {
    if (emailOrCode) {
      const byCodeOrEmail = await this.prisma.employee.findFirst({
        where: {
          OR: [
            { employeeCode: emailOrCode },
            { email: { equals: emailOrCode, mode: 'insensitive' } },
            { id: emailOrCode },
          ],
        },
      });
      if (byCodeOrEmail) return byCodeOrEmail;
    }

    if (name) {
      const parts = name.split(' ');
      if (parts.length >= 2) {
        const byName = await this.prisma.employee.findFirst({
          where: {
            firstName: { equals: parts[0], mode: 'insensitive' },
            lastName: { equals: parts.slice(1).join(' '), mode: 'insensitive' },
          },
        });
        if (byName) return byName;
      }
    }

    return null;
  }

  private async isLateAgainstShift(shiftCode: string, punchTime: Date): Promise<boolean> {
    try {
      const shift = await this.prisma.shiftMaster.findUnique({ where: { code: shiftCode } });
      if (shift && shift.startTime) {
        const [hour, min] = shift.startTime.split(':').map(Number);
        const grace = shift.graceMinutes ?? 15;
        const shiftStartMin = hour * 60 + min + grace;
        const punchMin = punchTime.getHours() * 60 + punchTime.getMinutes();
        return punchMin > shiftStartMin;
      }
    } catch {
      // fallback
    }
    // Default 09:30 AM + 15 min grace = 09:45 AM
    return punchTime.getHours() > 9 || (punchTime.getHours() === 9 && punchTime.getMinutes() > 45);
  }

  private normalizeUrl(url: string): string {
    let clean = (url || '').trim().toLowerCase();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = `https://${clean}`;
    }
    return clean.replace(/\/+$/, '');
  }

  private buildAuthHeaders(apiKey: string): Record<string, string> {
    const key = (apiKey || '').trim();
    const basicToken = Buffer.from(`${key}:X`).toString('base64');

    return {
      Authorization: `Basic ${basicToken}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
      'User-Agent': 'Saark-ERP-Attendance-Sync/1.0',
    };
  }

  private formatDateOnly(d: Date): string {
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }
}

