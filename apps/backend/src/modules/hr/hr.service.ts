import { Injectable, NotFoundException, BadRequestException, ConflictException, UnauthorizedException, Logger } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';
import { FaceRecognitionService } from '../../core/biometrics/face-recognition.service';
import { MailService } from '../../core/notifications/mail.service';
import * as bcrypt from 'bcryptjs';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { CreateLeaveDto, UpdateLeaveStatusDto } from './dto/create-leave.dto';
import { ClockInDto, ClockOutDto } from './dto/clock-in.dto';
import { AllocateWorkstationDto, LogOvertimeDto, ReportSafetyIncidentDto } from './dto/industrial.dto';

@Injectable()
export class HrService {
  private readonly logger = new Logger(HrService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly sequenceService: SequenceService,
    private readonly auditService: AuditService,
    private readonly faceRecognitionService: FaceRecognitionService,
    private readonly mailService: MailService,
  ) {}

  // -------------------------------------------------------------
  // 1. HR INDUSTRIAL DASHBOARD & EXECUTIVE METRICS
  // -------------------------------------------------------------
  async getDashboardMetrics() {
    const now = new Date();
    const totalEmployees = await this.prisma.employee.count();
    const activeEmployees = await this.prisma.employee.count({ where: { status: 'ACTIVE' } });
    const onLeaveEmployees = await this.prisma.employee.count({ where: { status: 'ON_LEAVE' } });

    // Workforce Category Breakdown (Industrial Perspective)
    const staffCount = await this.prisma.employee.count({ where: { workerCategory: 'STAFF_OFFICE' } });
    const shopfloorCount = await this.prisma.employee.count({ where: { workerCategory: 'SHOPFLOOR_TECH' } });
    const contractCount = await this.prisma.employee.count({ where: { workerCategory: 'CONTRACT_LABOR' } });
    const apprenticeCount = await this.prisma.employee.count({ where: { workerCategory: 'APPRENTICE' } });

    // Today's attendance
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayAttendances = await this.prisma.attendance.findMany({
      where: { punchDate: today },
    });

    const presentCount = todayAttendances.filter((a) => a.status === 'PRESENT' || a.status === 'LATE').length;
    const lateCount = todayAttendances.filter((a) => a.status === 'LATE').length;
    const attendanceRate = totalEmployees > 0 ? Math.round((presentCount / totalEmployees) * 100) : 0;

    // Shift Breakdown Today
    const shiftGCount = todayAttendances.filter((a) => a.shiftCode === 'SHIFT_G' && a.punchIn !== null).length;
    const shiftACount = todayAttendances.filter((a) => a.shiftCode === 'SHIFT_A' && a.punchIn !== null).length;
    const shiftBCount = todayAttendances.filter((a) => a.shiftCode === 'SHIFT_B' && a.punchIn !== null).length;
    const shiftNCount = todayAttendances.filter((a) => a.shiftCode === 'SHIFT_N' && a.punchIn !== null).length;

    // Overtime Metrics (Indian Factories Act Section 59 - 2x Wage Rate)
    const overtimeRecords = await this.prisma.attendance.findMany({
      where: {
        punchDate: { gte: new Date(today.getFullYear(), today.getMonth(), 1) },
        overtimeHours: { gt: 0 },
      },
    });
    const monthlyOtHours = overtimeRecords.reduce((sum, r) => sum + r.overtimeHours, 0);
    const pendingOtApprovals = overtimeRecords.filter((r) => !r.overtimeApproved).length;

    // Workstation / Shopfloor Bay Distribution
    const activeAllocations = await this.prisma.workstationAllocation.findMany({
      where: {
        allocationDate: { gte: today },
      },
      include: {
        employee: {
          select: { firstName: true, middleName: true, lastName: true, designation: true, employeeCode: true, skillLevel: true },
        },
      },
    });

    // Safety & EHS Metrics (Factories Act Compliance)
    const totalIncidents = await this.prisma.safetyIncident.count();
    const openIncidents = await this.prisma.safetyIncident.count({ where: { status: { not: 'RESOLVED' } } });
    const ppeCompliantCount = todayAttendances.filter((a) => a.ppeCompliant).length;
    const ppeComplianceRate = presentCount > 0 ? Math.round((ppeCompliantCount / presentCount) * 100) : 100;

    // Pending Leaves
    const pendingLeaves = await this.prisma.leaveRequest.count({
      where: { status: 'PENDING' },
    });

    // Monthly Payroll — use current month/year
    const currentMonth = now.getMonth() + 1;
    const currentYear = now.getFullYear();
    const payrollRecords = await this.prisma.payrollRecord.findMany({
      where: { monthNumber: currentMonth, year: currentYear },
    });
    const totalMonthlyPayroll = payrollRecords.reduce((sum, r) => sum + r.netPay, 0);

    // Department Breakdown
    const departments = await this.prisma.department.findMany({
      include: {
        _count: {
          select: { employees: true },
        },
      },
    });

    const departmentStats = departments.map((d) => ({
      name: d.name,
      code: d.code,
      count: d._count.employees,
    }));

    // Recent Leave Requests
    const recentLeaves = await this.prisma.leaveRequest.findMany({
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: {
        employee: {
          select: { firstName: true, middleName: true, lastName: true, designation: true, employeeCode: true },
        },
      },
    });

    // Recent Clock-ins today
    const recentClockIns = await this.prisma.attendance.findMany({
      where: { punchDate: today, punchIn: { not: null } },
      take: 6,
      orderBy: { punchIn: 'desc' },
      include: {
        employee: {
          select: { firstName: true, middleName: true, lastName: true, designation: true, employeeCode: true, assignedBay: true, shiftCode: true },
        },
      },
    });

    return {
      totalEmployees,
      activeEmployees,
      onLeaveEmployees,
      workforceBreakdown: {
        staffOffice: staffCount,
        shopfloorTechs: shopfloorCount,
        contractLabor: contractCount,
        apprentices: apprenticeCount,
      },
      shiftBreakdown: {
        shiftG: shiftGCount,
        shiftA: shiftACount,
        shiftB: shiftBCount,
        shiftN: shiftNCount,
      },
      overtimeSummary: {
        monthlyOtHours,
        pendingApprovals: pendingOtApprovals,
        estimatedOtPayout: Math.round(monthlyOtHours * 450), // Approx 2x factory technician rate
      },
      safetyKpis: {
        totalIncidents,
        openIncidents,
        ppeComplianceRate,
      },
      bayAllocationsCount: activeAllocations.length,
      todayStats: {
        presentCount,
        lateCount,
        absentCount: Math.max(0, totalEmployees - presentCount - onLeaveEmployees),
        attendanceRate,
      },
      pendingLeaves,
      totalMonthlyPayroll,
      departmentStats,
      recentLeaves,
      recentClockIns,
    };
  }

  // -------------------------------------------------------------
  // 2. SHIFTS MANAGEMENT (FACTORIES ACT 1948)
  // -------------------------------------------------------------
  async getShifts() {
    let shifts = await this.prisma.shiftMaster.findMany({
      orderBy: { startTime: 'asc' },
    });

    if (shifts.length === 0) {
      // Seed default manufacturing plant shifts
      await this.prisma.shiftMaster.createMany({
        data: [
          {
            code: 'SHIFT_G',
            name: 'General Plant Day Shift',
            startTime: '08:30',
            endTime: '17:00',
            graceMinutes: 15,
            shiftAllowance: 0,
            departmentName: 'Plant & Engineering',
          },
          {
            code: 'SHIFT_A',
            name: 'Morning Assembly Shift',
            startTime: '06:00',
            endTime: '14:30',
            graceMinutes: 10,
            shiftAllowance: 75,
            departmentName: 'Fabrication & Assembly',
          },
          {
            code: 'SHIFT_B',
            name: 'Afternoon Wiring & Busbar Shift',
            startTime: '14:00',
            endTime: '22:30',
            graceMinutes: 10,
            shiftAllowance: 120,
            departmentName: 'Electrical Wiring Bay',
          },
          {
            code: 'SHIFT_N',
            name: 'Night Testing & Commissioning Shift',
            startTime: '22:00',
            endTime: '06:30',
            graceMinutes: 10,
            shiftAllowance: 250,
            departmentName: 'Testing & Quality Bay',
          },
        ],
      });
      shifts = await this.prisma.shiftMaster.findMany({ orderBy: { startTime: 'asc' } });
    }

    return shifts;
  }

  // -------------------------------------------------------------
  // 3. WORKSTATION & SHOPFLOOR BAY ALLOCATION
  // -------------------------------------------------------------
  async getWorkstationAllocations(dateStr?: string) {
    const targetDate = dateStr ? new Date(dateStr) : new Date();
    targetDate.setHours(0, 0, 0, 0);

    return this.prisma.workstationAllocation.findMany({
      where: {
        allocationDate: {
          gte: targetDate,
          lt: new Date(targetDate.getTime() + 24 * 60 * 60 * 1000),
        },
      },
      include: {
        employee: {
          include: { department: true },
        },
      },
      orderBy: { bayCode: 'asc' },
    });
  }

  async allocateWorkstation(dto: AllocateWorkstationDto) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Also update employee's assignedBay
    await this.prisma.employee.update({
      where: { id: dto.employeeId },
      data: { assignedBay: dto.bayCode, shiftCode: dto.shiftCode || 'SHIFT_G' },
    });

    return this.prisma.workstationAllocation.create({
      data: {
        allocationDate: today,
        employeeId: dto.employeeId,
        bayCode: dto.bayCode,
        panelCode: dto.panelCode || null,
        shiftCode: dto.shiftCode || 'SHIFT_G',
        targetHours: dto.targetHours || 8.0,
        supervisorNote: dto.supervisorNote || 'Assigned by Plant Supervisor',
        status: 'IN_PROGRESS',
      },
      include: {
        employee: { include: { department: true } },
      },
    });
  }

  // -------------------------------------------------------------
  // 4. OVERTIME (FACTORIES ACT SEC 59 - 2X RATE)
  // -------------------------------------------------------------
  async logOvertime(dto: LogOvertimeDto) {
    const record = await this.prisma.attendance.findUnique({
      where: { id: dto.attendanceId },
      include: { employee: true },
    });
    if (!record) throw new NotFoundException('Attendance record not found');

    return this.prisma.attendance.update({
      where: { id: dto.attendanceId },
      data: {
        overtimeHours: dto.overtimeHours,
        overtimeApproved: dto.approved ?? true,
      },
      include: { employee: true },
    });
  }

  async approveOvertime(id: string, approved: boolean) {
    return this.prisma.attendance.update({
      where: { id },
      data: { overtimeApproved: approved },
      include: { employee: true },
    });
  }

  // -------------------------------------------------------------
  // 5. SAFETY & EHS MANAGEMENT
  // -------------------------------------------------------------
  async getSafetyIncidents() {
    return this.prisma.safetyIncident.findMany({
      orderBy: { reportDate: 'desc' },
    });
  }

  async reportSafetyIncident(dto: ReportSafetyIncidentDto, reporter: string) {
    const code = await this.sequenceService.nextIncidentCode();

    return this.prisma.safetyIncident.create({
      data: {
        incidentCode: code,
        incidentType: dto.incidentType,
        severity: dto.severity,
        locationBay: dto.locationBay,
        employeeId: dto.employeeId || null,
        description: dto.description,
        actionTaken: dto.actionTaken || null,
        status: 'RESOLVED',
        reportedBy: reporter,
      },
    });
  }

  // -------------------------------------------------------------
  // 6. FACTORIES ACT FORM 25 MUSTER ROLL REPORT
  // -------------------------------------------------------------
  async getMusterRoll(month?: string, year?: number) {
    const currentYear = year || new Date().getFullYear();
    const currentMonth = month ? Number(month) : new Date().getMonth() + 1;

    const employees = await this.prisma.employee.findMany({
      include: {
        department: true,
        attendances: {
          where: {
            punchDate: {
              gte: new Date(currentYear, currentMonth - 1, 1),
              lt: new Date(currentYear, currentMonth, 1),
            },
          },
        },
      },
      orderBy: [{ workerCategory: 'desc' }, { employeeCode: 'asc' }],
    });

    return employees.map((emp) => {
      const totalPresent = emp.attendances.filter((a) => a.status === 'PRESENT' || a.status === 'LATE').length;
      const totalOt = emp.attendances.reduce((acc, a) => acc + a.overtimeHours, 0);
      const totalLate = emp.attendances.filter((a) => a.status === 'LATE').length;

      return {
        id: emp.id,
        employeeCode: emp.employeeCode,
        fullName: [emp.firstName, emp.middleName, emp.lastName].filter(Boolean).join(' '),
        designation: emp.designation,
        department: emp.department?.name || 'Plant Ops',
        workerCategory: emp.workerCategory,
        skillLevel: emp.skillLevel,
        assignedBay: emp.assignedBay,
        shiftCode: emp.shiftCode,
        contractorAgency: emp.contractorAgency,
        electricalLicenseNo: emp.electricalLicenseNo,
        presentDays: totalPresent,
        lateDays: totalLate,
        overtimeHours: totalOt,
        otEarnings: Math.round(totalOt * ((emp.salaryCtc / 12 / 26 / 8) * 2)), // 2x ordinary rate
      };
    });
  }

  // -------------------------------------------------------------
  // 6.5 DESIGNATIONS MASTER
  // -------------------------------------------------------------
  async getDesignations() {
    return this.prisma.designation.findMany({
      orderBy: { name: 'asc' },
    });
  }

  // -------------------------------------------------------------
  // 7. EMPLOYEES DIRECTORY & PROFILE
  // -------------------------------------------------------------
  async getEmployees(search?: string, departmentId?: string, status?: string, workerCategory?: string) {
    const where: any = {};
    if (departmentId) where.departmentId = departmentId;
    if (status) where.status = status;
    if (workerCategory) where.workerCategory = workerCategory;
    if (search) {
      where.OR = [
        { firstName: { contains: search } },
        { middleName: { contains: search } },
        { lastName: { contains: search } },
        { email: { contains: search } },
        { employeeCode: { contains: search } },
        { designation: { contains: search } },
        { electricalLicenseNo: { contains: search } },
        { contractorAgency: { contains: search } },
      ];
    }

    return this.prisma.employee.findMany({
      where,
      include: {
        department: true,
        faceBiometric: {
          select: { id: true, isActive: true, enrolledAt: true },
        },
        user: {
          select: {
            id: true,
            username: true,
            email: true,
            status: true,
            faceVerificationEnabled: true,
            faceVerificationStatus: true,
          },
        },
      },
      orderBy: { employeeCode: 'asc' },
    });
  }

  async getEmployeeById(idOrCode: string) {
    const employee = await this.prisma.employee.findFirst({
      where: {
        OR: [{ id: idOrCode }, { employeeCode: idOrCode }],
      },
      include: {
        department: true,
        faceBiometric: {
          select: {
            id: true,
            isActive: true,
            enrolledAt: true,
            updatedAt: true,
            faceModel: true,
            embeddingVersion: true,
            passportPhotoPath: true,
            enrollmentPhotoPath: true,
          },
        },
        user: {
          select: {
            id: true,
            username: true,
            email: true,
            status: true,
            faceVerificationEnabled: true,
            faceVerificationStatus: true,
            faceEnrolledAt: true,
            failedFaceAttempts: true,
            faceLockoutUntil: true,
          },
        },
        attendances: {
          take: 30,
          orderBy: { punchDate: 'desc' },
        },
        workstationAllocations: {
          take: 10,
          orderBy: { allocationDate: 'desc' },
        },
        leaveRequests: {
          take: 10,
          orderBy: { createdAt: 'desc' },
        },
        payrollRecords: {
          take: 6,
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!employee) throw new NotFoundException(`Employee record '${idOrCode}' not found`);
    return employee;
  }

  async createEmployee(
    dto: CreateEmployeeDto,
    actorId?: string,
    actorEmail?: string,
    ipAddress?: string,
  ) {
    // Comprehensive Validation for First Name, Middle Name, Last Name & Critical Fields
    if (!dto.firstName || dto.firstName.trim().length < 2) {
      throw new BadRequestException('First Name is required and must contain at least 2 characters.');
    }
    if (!dto.lastName || dto.lastName.trim().length < 1) {
      throw new BadRequestException('Last Name is required.');
    }
    if (!dto.email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(dto.email.trim())) {
      throw new BadRequestException('A valid corporate work email address is required.');
    }
    if (!dto.phone || dto.phone.trim().length < 7) {
      throw new BadRequestException('A valid phone number is required.');
    }

    const normalizedEmail = dto.email.trim();

    // Check for existing employee with the same email
    const existingEmail = await this.prisma.employee.findUnique({
      where: { email: normalizedEmail },
    });
    if (existingEmail) {
      throw new ConflictException(
        `Employee with email '${normalizedEmail}' already exists (${existingEmail.employeeCode} - ${existingEmail.firstName} ${existingEmail.lastName}). Please edit that record or use a different email.`,
      );
    }

    const employeeCode = await this.sequenceService.nextEmployeeCode();

    // Process Passport/Profile Photo if supplied
    let avatarUrl: string | undefined = undefined;
    let passportStoragePath: string | undefined = undefined;
    let passportDescriptor: number[] | null = null;
    if (dto.passportPhotoBase64) {
      const parsedPassport = this.faceRecognitionService.parseBase64Image(dto.passportPhotoBase64);
      // Validate that passport photo contains a valid face and extract descriptor
      const extractedPassport = await this.faceRecognitionService.validateAndExtractFace(parsedPassport.buffer);
      passportDescriptor = extractedPassport.descriptor;
      const savedPassport = await this.faceRecognitionService.saveBiometricPhoto(
        parsedPassport.buffer,
        employeeCode,
        'passport',
      );
      avatarUrl = savedPassport.publicUrl;
      passportStoragePath = savedPassport.relativePath;
    }

    // Process Live Biometric Photo if supplied
    let liveBiometricDescriptor: number[] | null = null;
    let liveStoragePath: string | undefined = undefined;
    if (dto.livePhotoBase64) {
      const parsedLive = this.faceRecognitionService.parseBase64Image(dto.livePhotoBase64);
      const extractedLive = await this.faceRecognitionService.validateAndExtractFace(parsedLive.buffer);
      liveBiometricDescriptor = extractedLive.descriptor;

      const savedLive = await this.faceRecognitionService.saveBiometricPhoto(
        parsedLive.buffer,
        employeeCode,
        'live',
      );
      liveStoragePath = savedLive.relativePath;
    }

    // VERIFICATION AT PROFILE CREATION:
    // If BOTH Live Photo and Passport Photo are supplied, compare and log similarity for audit trail
    if (liveBiometricDescriptor && passportDescriptor) {
      const settings = await this.faceRecognitionService.getFaceAuthSettings();
      const match = this.faceRecognitionService.compareFaces(
        liveBiometricDescriptor,
        passportDescriptor,
        settings.matchThreshold || 0.55,
      );
      this.logger.log(
        `Employee face biometric comparison: Live Photo vs Passport Photo (Distance: ${match.distance}, Similarity: ${match.similarity}, Match: ${match.isMatch})`,
      );
    }

    // Resolve departmentId to ensure it is a valid UUID that exists in DB
    let validDepartmentId: string | null = null;
    if (dto.departmentId && dto.departmentId.trim().length > 0) {
      try {
        const dept = await this.prisma.department.findFirst({
          where: {
            OR: [
              { id: dto.departmentId.trim() },
              { code: dto.departmentId.trim() },
              { name: { equals: dto.departmentId.trim(), mode: 'insensitive' } },
            ],
          },
        });
        validDepartmentId = dept?.id || null;
      } catch (_) {
        validDepartmentId = null;
      }
    }

    // Optional: Create linked User Account concurrently
    let linkedUserId: string | null = null;
    const shouldCreateUser = dto.createUserAccount || Boolean(dto.username && dto.password);
    if (shouldCreateUser && dto.username && dto.password) {
      const existingUser = await this.prisma.user.findFirst({
        where: { OR: [{ email: normalizedEmail }, { username: dto.username.trim() }] },
      });
      if (existingUser) {
        throw new ConflictException(`User with username '${dto.username}' or email '${normalizedEmail}' already exists.`);
      }

      const passwordHash = await bcrypt.hash(dto.password, 10);
      const hasBiometric = Boolean(liveBiometricDescriptor);
      const newUser = await this.prisma.user.create({
        data: {
          username: dto.username.trim(),
          email: normalizedEmail,
          fullName: [dto.firstName.trim(), dto.middleName?.trim(), dto.lastName.trim()].filter(Boolean).join(' '),
          phone: dto.phone,
          designation: dto.designation,
          departmentId: validDepartmentId,
          passwordHash,
          status: 'ACTIVE',
          faceVerificationEnabled: hasBiometric ? (dto.enableFaceAuth ?? true) : false,
          faceVerificationStatus: hasBiometric ? 'ENROLLED' : 'NOT_ENROLLED',
          faceEnrolledAt: hasBiometric ? new Date() : null,
        },
      });

      // Role assignment
      const targetRoleId = dto.roleId;
      if (targetRoleId) {
        const role = await this.prisma.role.findFirst({
          where: { OR: [{ id: targetRoleId }, { code: targetRoleId }] },
        });
        if (role) {
          await this.prisma.userRole.create({
            data: { userId: newUser.id, roleId: role.id },
          });
        }
      } else {
        const empRole = await this.prisma.role.findFirst({ where: { code: 'ROLE_EMPLOYEE' } });
        if (empRole) {
          await this.prisma.userRole.create({
            data: { userId: newUser.id, roleId: empRole.id },
          });
        }
      }

      linkedUserId = newUser.id;
    }

    // Create Employee record
    const employee = await this.prisma.employee.create({
      data: {
        employeeCode,
        userId: linkedUserId,
        firstName: dto.firstName.trim(),
        middleName: dto.middleName ? dto.middleName.trim() : null,
        lastName: dto.lastName.trim(),
        email: normalizedEmail,
        phone: dto.phone,
        designation: dto.designation,
        departmentId: validDepartmentId,
        status: dto.status || 'PENDING_APPROVAL',
        employmentType: dto.employmentType || 'FULL_TIME',
        workerCategory: dto.workerCategory || 'SHOPFLOOR_TECH',
        skillLevel: dto.skillLevel || 'LEVEL_2_WIREMAN',
        assignedBay: dto.assignedBay || 'BAY_4_WIRING',
        shiftCode: dto.shiftCode || 'SHIFT_G',
        electricalLicenseNo: dto.electricalLicenseNo || null,
        contractorAgency: dto.contractorAgency || null,
        ppeKitIssued: dto.ppeKitIssued ?? true,
        salaryCtc: dto.salaryCtc || 0,
        bankAccountNo: dto.bankAccountNo,
        bankIfsc: dto.bankIfsc,
        panNo: dto.panNo,
        aadhaarNo: dto.aadhaarNo,
        bloodGroup: dto.bloodGroup,
        emergencyPhone: dto.emergencyPhone,
        address: dto.address,
        avatarUrl: avatarUrl || undefined,
      },
      include: { department: true },
    });

    // Save Biometrics record if live biometric was captured
    if (liveBiometricDescriptor) {
      const encrypted = this.faceRecognitionService.encryptEmbedding(liveBiometricDescriptor);
      await this.prisma.employeeFaceBiometric.create({
        data: {
          employeeId: employee.id,
          userId: linkedUserId,
          encryptedEmbedding: encrypted.encryptedEmbedding,
          embeddingIv: encrypted.embeddingIv,
          embeddingAuthTag: encrypted.embeddingAuthTag,
          embeddingVersion: encrypted.embeddingVersion,
          faceModel: encrypted.faceModel,
          passportPhotoPath: passportStoragePath || null,
          enrollmentPhotoPath: liveStoragePath || null,
          isActive: true,
        },
      });

      await this.auditService.log({
        userId: actorId,
        userEmail: actorEmail,
        action: 'FACE_ENROLLMENT',
        module: 'HR',
        entityType: 'Employee',
        entityId: employee.id,
        details: `Face biometric successfully enrolled for employee ${employee.employeeCode} (${employee.firstName} ${employee.lastName})`,
        ipAddress,
      });
    }

    return employee;
  }

  async enrollEmployeeFace(
    idOrCode: string,
    dto: { livePhotoBase64: string; passportPhotoBase64?: string; enableFaceAuth?: boolean },
    actorId?: string,
    actorEmail?: string,
    ipAddress?: string,
  ) {
    const employee = await this.prisma.employee.findFirst({
      where: { OR: [{ id: idOrCode }, { employeeCode: idOrCode }] },
      include: { faceBiometric: true },
    });

    if (!employee) {
      throw new NotFoundException(`Employee record '${idOrCode}' not found`);
    }

    if (!dto.livePhotoBase64) {
      throw new BadRequestException('Live face photograph is required for biometric enrollment.');
    }

    const parsedLive = this.faceRecognitionService.parseBase64Image(dto.livePhotoBase64);
    const extractedLive = await this.faceRecognitionService.validateAndExtractFace(parsedLive.buffer);
    const liveBiometricDescriptor = extractedLive.descriptor;

    const savedLive = await this.faceRecognitionService.saveBiometricPhoto(
      parsedLive.buffer,
      employee.employeeCode,
      'live',
    );

    let passportPath = employee.faceBiometric?.passportPhotoPath;
    let avatarUrl = employee.avatarUrl;
    let passportDescriptor: number[] | null = null;
    if (dto.passportPhotoBase64) {
      const parsedPassport = this.faceRecognitionService.parseBase64Image(dto.passportPhotoBase64);
      const extractedPassport = await this.faceRecognitionService.validateAndExtractFace(parsedPassport.buffer);
      passportDescriptor = extractedPassport.descriptor;
      const savedPassport = await this.faceRecognitionService.saveBiometricPhoto(
        parsedPassport.buffer,
        employee.employeeCode,
        'passport',
      );
      passportPath = savedPassport.relativePath;
      avatarUrl = savedPassport.publicUrl;
      await this.prisma.employee.update({
        where: { id: employee.id },
        data: { avatarUrl },
      });
    }

    // VERIFICATION ON ENROLLMENT:
    if (liveBiometricDescriptor && passportDescriptor) {
      const settings = await this.faceRecognitionService.getFaceAuthSettings();
      const match = this.faceRecognitionService.compareFaces(
        liveBiometricDescriptor,
        passportDescriptor,
        settings.matchThreshold || 0.55,
      );
      this.logger.log(
        `Employee face biometric enrollment: Live Photo vs Passport Photo (Distance: ${match.distance}, Similarity: ${match.similarity}, Match: ${match.isMatch})`,
      );
    }

    const encrypted = this.faceRecognitionService.encryptEmbedding(liveBiometricDescriptor);
    const isReEnrollment = Boolean(employee.faceBiometric);

    await this.prisma.employeeFaceBiometric.upsert({
      where: { employeeId: employee.id },
      update: {
        encryptedEmbedding: encrypted.encryptedEmbedding,
        embeddingIv: encrypted.embeddingIv,
        embeddingAuthTag: encrypted.embeddingAuthTag,
        enrollmentPhotoPath: savedLive.relativePath,
        passportPhotoPath: passportPath,
        isActive: true,
        updatedAt: new Date(),
      },
      create: {
        employeeId: employee.id,
        userId: employee.userId,
        encryptedEmbedding: encrypted.encryptedEmbedding,
        embeddingIv: encrypted.embeddingIv,
        embeddingAuthTag: encrypted.embeddingAuthTag,
        embeddingVersion: encrypted.embeddingVersion,
        faceModel: encrypted.faceModel,
        passportPhotoPath: passportPath || null,
        enrollmentPhotoPath: savedLive.relativePath,
        isActive: true,
      },
    });

    if (employee.userId) {
      await this.prisma.user.update({
        where: { id: employee.userId },
        data: {
          faceVerificationEnabled: dto.enableFaceAuth ?? true,
          faceVerificationStatus: 'ENROLLED',
          faceEnrolledAt: new Date(),
          failedFaceAttempts: 0,
          faceLockoutUntil: null,
        },
      });
    }

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: isReEnrollment ? 'FACE_RE_ENROLLMENT' : 'FACE_ENROLLMENT',
      module: 'HR',
      entityType: 'Employee',
      entityId: employee.id,
      details: `Face biometric ${isReEnrollment ? 're-enrolled' : 'enrolled'} for employee ${employee.employeeCode} (${employee.firstName} ${employee.lastName})`,
      ipAddress,
    });

    return {
      success: true,
      message: `Face biometric successfully ${isReEnrollment ? 're-enrolled' : 'enrolled'} for ${employee.employeeCode}`,
      employeeId: employee.id,
      employeeCode: employee.employeeCode,
      avatarUrl,
      faceVerificationEnabled: dto.enableFaceAuth ?? true,
      enrolledAt: new Date(),
    };
  }

  async disableEmployeeFace(
    idOrCode: string,
    actorId?: string,
    actorEmail?: string,
    ipAddress?: string,
  ) {
    const employee = await this.prisma.employee.findFirst({
      where: { OR: [{ id: idOrCode }, { employeeCode: idOrCode }] },
      include: { faceBiometric: true },
    });

    if (!employee) throw new NotFoundException(`Employee record '${idOrCode}' not found`);

    if (employee.faceBiometric) {
      await this.prisma.employeeFaceBiometric.update({
        where: { id: employee.faceBiometric.id },
        data: { isActive: false },
      });
    }

    if (employee.userId) {
      await this.prisma.user.update({
        where: { id: employee.userId },
        data: {
          faceVerificationEnabled: false,
          faceVerificationStatus: 'DISABLED',
        },
      });
    }

    await this.auditService.log({
      userId: actorId,
      userEmail: actorEmail,
      action: 'FACE_VERIFICATION_DISABLED',
      module: 'HR',
      entityType: 'Employee',
      entityId: employee.id,
      details: `Face biometric verification disabled for ${employee.employeeCode}`,
      ipAddress,
    });

    return {
      success: true,
      message: `Face verification disabled for ${employee.employeeCode}`,
    };
  }

  async getEmployeeFaceStatus(idOrCode: string) {
    const employee = await this.prisma.employee.findFirst({
      where: { OR: [{ id: idOrCode }, { employeeCode: idOrCode }] },
      include: {
        faceBiometric: {
          select: {
            id: true,
            isActive: true,
            enrolledAt: true,
            updatedAt: true,
            faceModel: true,
            embeddingVersion: true,
            passportPhotoPath: true,
            enrollmentPhotoPath: true,
          },
        },
        user: {
          select: {
            id: true,
            username: true,
            faceVerificationEnabled: true,
            faceVerificationStatus: true,
            faceEnrolledAt: true,
            failedFaceAttempts: true,
            faceLockoutUntil: true,
          },
        },
      },
    });

    if (!employee) throw new NotFoundException(`Employee record '${idOrCode}' not found`);

    return {
      employeeId: employee.id,
      employeeCode: employee.employeeCode,
      fullName: [employee.firstName, employee.middleName, employee.lastName].filter(Boolean).join(' ').trim(),
      hasBiometric: Boolean(employee.faceBiometric),
      isActive: employee.faceBiometric?.isActive ?? false,
      enrolledAt: employee.faceBiometric?.enrolledAt ?? null,
      faceModel: employee.faceBiometric?.faceModel ?? 'None',
      faceVerificationEnabled: employee.user?.faceVerificationEnabled ?? false,
      verificationStatus: employee.user?.faceVerificationStatus ?? (employee.faceBiometric ? 'ENROLLED' : 'NOT_ENROLLED'),
      isLocked: Boolean(employee.user?.faceLockoutUntil && new Date(employee.user.faceLockoutUntil) > new Date()),
      avatarUrl: employee.avatarUrl,
    };
  }

  async updateEmployee(idOrCode: string, dto: Partial<CreateEmployeeDto>) {
    const existing = await this.prisma.employee.findFirst({
      where: {
        OR: [{ id: idOrCode }, { employeeCode: idOrCode }],
      },
      include: {
        faceBiometric: true,
        user: true,
      },
    });
    if (!existing) {
      throw new NotFoundException(`Employee record '${idOrCode}' not found`);
    }

    // If email is changing, verify it is not already taken by another employee
    if (dto.email && dto.email.trim() !== existing.email) {
      const normalizedEmail = dto.email.trim();
      const emailConflict = await this.prisma.employee.findUnique({
        where: { email: normalizedEmail },
      });
      if (emailConflict && emailConflict.id !== existing.id) {
        throw new ConflictException(
          `Email '${normalizedEmail}' is already in use by employee ${emailConflict.employeeCode} (${emailConflict.firstName} ${emailConflict.lastName}).`,
        );
      }
    }

    // Resolve valid departmentId if supplied
    let validDepartmentId: string | null | undefined = undefined;
    if (dto.departmentId !== undefined) {
      if (dto.departmentId && dto.departmentId.trim().length > 0) {
        try {
          const dept = await this.prisma.department.findFirst({
            where: {
              OR: [
                { id: dto.departmentId.trim() },
                { code: dto.departmentId.trim() },
                { name: { equals: dto.departmentId.trim(), mode: 'insensitive' } },
              ],
            },
          });
          validDepartmentId = dept?.id || null;
        } catch (_) {
          validDepartmentId = null;
        }
      } else {
        validDepartmentId = null;
      }
    }

    // ─── SYNC USER ACCOUNT CREDENTIALS (USERNAME / PASSWORD / ROLE) ─────────────
    let updatedUserId = existing.userId;
    let credentialsChanged = false;
    let finalUsername = existing.user?.username || '';
    const newPassword = dto.password && dto.password.trim().length > 0 ? dto.password : undefined;

    if (existing.userId && existing.user) {
      const userUpdates: any = {};
      const newUsername = dto.username?.trim();

      if (newUsername && newUsername !== existing.user.username) {
        const uConflict = await this.prisma.user.findFirst({
          where: { username: newUsername, id: { not: existing.user.id } },
        });
        if (uConflict) {
          throw new ConflictException(`Username '${newUsername}' is already taken by another account`);
        }
        userUpdates.username = newUsername;
        finalUsername = newUsername;
        credentialsChanged = true;
      }

      if (newPassword) {
        userUpdates.passwordHash = await bcrypt.hash(newPassword, 10);
        credentialsChanged = true;
      }

      if (dto.email && dto.email.trim() !== existing.user.email) {
        userUpdates.email = dto.email.trim();
      }

      if (dto.firstName || dto.lastName || dto.middleName !== undefined) {
        userUpdates.fullName = [
          dto.firstName ?? existing.firstName,
          dto.middleName !== undefined ? dto.middleName : existing.middleName,
          dto.lastName ?? existing.lastName,
        ].filter(Boolean).join(' ').trim();
      }

      if (dto.phone) userUpdates.phone = dto.phone;
      if (dto.designation) userUpdates.designation = dto.designation;
      if (validDepartmentId !== undefined) userUpdates.departmentId = validDepartmentId;

      if (Object.keys(userUpdates).length > 0) {
        await this.prisma.user.update({
          where: { id: existing.user.id },
          data: userUpdates,
        });
      }

      // Re-assign role if provided
      if (dto.roleId) {
        const targetRole = await this.prisma.role.findFirst({
          where: { OR: [{ id: dto.roleId }, { code: dto.roleId }] },
        });
        if (targetRole) {
          await this.prisma.userRole.deleteMany({ where: { userId: existing.user.id } });
          await this.prisma.userRole.create({
            data: { userId: existing.user.id, roleId: targetRole.id },
          });
        }
      }

      // If credentials (username or password) changed, dispatch notification email
      if (credentialsChanged) {
        try {
          await this.mailService.sendCredentialsUpdatedEmail({
            to: (dto.email || existing.email).trim(),
            fullName: `${dto.firstName ?? existing.firstName} ${dto.lastName ?? existing.lastName}`.trim(),
            username: finalUsername || existing.user.username,
            newPassword: newPassword,
          });
        } catch (mErr: any) {
          console.warn(`Could not dispatch credential change email: ${mErr.message}`);
        }
      }
    } else if (dto.createUserAccount || (dto.username && dto.password)) {
      // Provision user account for an employee without one
      const reqUsername = dto.username?.trim() || (dto.email || existing.email).split('@')[0];
      const existingUser = await this.prisma.user.findFirst({
        where: { OR: [{ email: (dto.email || existing.email).trim() }, { username: reqUsername }] },
      });
      if (existingUser) {
        throw new ConflictException(`User with username '${reqUsername}' or email already exists.`);
      }

      const rawPass = dto.password || 'Saark@2026';
      const passwordHash = await bcrypt.hash(rawPass, 10);
      const newUser = await this.prisma.user.create({
        data: {
          username: reqUsername,
          email: (dto.email || existing.email).trim(),
          fullName: `${dto.firstName ?? existing.firstName} ${dto.lastName ?? existing.lastName}`.trim(),
          phone: dto.phone ?? existing.phone,
          designation: dto.designation ?? existing.designation,
          departmentId: validDepartmentId !== undefined ? validDepartmentId : existing.departmentId,
          passwordHash,
          status: 'ACTIVE',
          faceVerificationEnabled: Boolean(existing.faceBiometric?.isActive),
          faceVerificationStatus: existing.faceBiometric?.isActive ? 'ENROLLED' : 'NOT_ENROLLED',
          faceEnrolledAt: existing.faceBiometric?.enrolledAt ?? null,
        },
      });

      // Role
      const targetRoleId = dto.roleId;
      const role = await this.prisma.role.findFirst({
        where: targetRoleId ? { OR: [{ id: targetRoleId }, { code: targetRoleId }] } : { code: 'ROLE_EMPLOYEE' },
      });
      if (role) {
        await this.prisma.userRole.create({
          data: { userId: newUser.id, roleId: role.id },
        });
      }

      updatedUserId = newUser.id;

      // Link biometric if exists
      if (existing.faceBiometric) {
        await this.prisma.employeeFaceBiometric.update({
          where: { id: existing.faceBiometric.id },
          data: { userId: newUser.id },
        });
      }

      // Send welcome email
      try {
        await this.mailService.sendWelcomeEmployeeEmail({
          to: (dto.email || existing.email).trim(),
          fullName: `${dto.firstName ?? existing.firstName} ${dto.lastName ?? existing.lastName}`.trim(),
          username: reqUsername,
          password: rawPass,
          employeeCode: existing.employeeCode,
          designation: dto.designation ?? existing.designation,
        });
      } catch (mErr: any) {
        console.warn(`Could not dispatch welcome email: ${mErr.message}`);
      }
    }

    return this.prisma.employee.update({
      where: { id: existing.id },
      data: {
        userId: updatedUserId,
        ...(dto.firstName !== undefined && { firstName: dto.firstName.trim() }),
        ...(dto.middleName !== undefined && { middleName: dto.middleName ? dto.middleName.trim() : null }),
        ...(dto.lastName !== undefined && { lastName: dto.lastName.trim() }),
        ...(dto.email !== undefined && { email: dto.email.trim() }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
        ...(dto.designation !== undefined && { designation: dto.designation }),
        ...(validDepartmentId !== undefined && { departmentId: validDepartmentId }),
        ...(dto.status !== undefined && { status: dto.status }),
        ...(dto.employmentType !== undefined && { employmentType: dto.employmentType }),
        ...(dto.workerCategory !== undefined && { workerCategory: dto.workerCategory }),
        ...(dto.skillLevel !== undefined && { skillLevel: dto.skillLevel }),
        ...(dto.assignedBay !== undefined && { assignedBay: dto.assignedBay }),
        ...(dto.shiftCode !== undefined && { shiftCode: dto.shiftCode }),
        ...(dto.electricalLicenseNo !== undefined && { electricalLicenseNo: dto.electricalLicenseNo }),
        ...(dto.contractorAgency !== undefined && { contractorAgency: dto.contractorAgency }),
        ...(dto.ppeKitIssued !== undefined && { ppeKitIssued: dto.ppeKitIssued }),
        ...(dto.salaryCtc !== undefined && { salaryCtc: dto.salaryCtc }),
        ...(dto.bankAccountNo !== undefined && { bankAccountNo: dto.bankAccountNo }),
        ...(dto.bankIfsc !== undefined && { bankIfsc: dto.bankIfsc }),
        ...(dto.panNo !== undefined && { panNo: dto.panNo }),
        ...(dto.aadhaarNo !== undefined && { aadhaarNo: dto.aadhaarNo }),
        ...(dto.bloodGroup !== undefined && { bloodGroup: dto.bloodGroup }),
        ...(dto.emergencyPhone !== undefined && { emergencyPhone: dto.emergencyPhone }),
        ...(dto.address !== undefined && { address: dto.address }),
      },
      include: {
        department: true,
        faceBiometric: true,
        user: {
          select: {
            id: true,
            username: true,
            email: true,
            status: true,
            faceVerificationEnabled: true,
            faceVerificationStatus: true,
          },
        },
      },
    });
  }

  // -------------------------------------------------------------
  // 8. ATTENDANCE TRACKER
  // -------------------------------------------------------------
  async getAttendance(dateStr?: string) {
    const targetDate = dateStr ? new Date(dateStr) : new Date();
    targetDate.setHours(0, 0, 0, 0);

    const attendances = await this.prisma.attendance.findMany({
      where: { punchDate: targetDate },
      include: {
        employee: {
          include: { department: true },
        },
      },
      orderBy: { employee: { employeeCode: 'asc' } },
    });

    const allEmployees = await this.prisma.employee.findMany({
      where: { status: { in: ['ACTIVE', 'ON_LEAVE'] } },
      include: { department: true },
    });

    const punchMap = new Map(attendances.map((a) => [a.employeeId, a]));

    const fullList = allEmployees.map((emp) => {
      const existing = punchMap.get(emp.id);
      if (existing) return existing;

      return {
        id: `virtual-${emp.id}`,
        employeeId: emp.id,
        punchDate: targetDate,
        punchIn: null,
        punchOut: null,
        workHours: 0,
        shiftCode: emp.shiftCode,
        overtimeHours: 0,
        overtimeApproved: false,
        assignedBay: emp.assignedBay,
        ppeCompliant: true,
        status: emp.status === 'ON_LEAVE' ? 'ON_LEAVE' : 'NOT_PUNCHED',
        checkInNote: null,
        checkOutNote: null,
        location: null,
        employee: emp,
      };
    });

    return {
      date: targetDate,
      summary: {
        total: allEmployees.length,
        punched: attendances.filter((a) => a.punchIn !== null).length,
        onLeave: allEmployees.filter((e) => e.status === 'ON_LEAVE').length,
        totalOtHours: attendances.reduce((acc, a) => acc + a.overtimeHours, 0),
      },
      records: fullList,
    };
  }

  async clockIn(dto: ClockInDto) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const now = new Date();

    const emp = await this.prisma.employee.findUnique({ where: { id: dto.employeeId } });
    if (!emp) {
      throw new NotFoundException(`Employee record '${dto.employeeId}' not found`);
    }

    // Determine late status from shift-specific start time
    const shiftCode = emp.shiftCode || 'SHIFT_G';
    const shift = await this.prisma.shiftMaster.findUnique({ where: { code: shiftCode } });
    let isLate = false;
    if (shift) {
      const [shiftHour, shiftMin] = shift.startTime.split(':').map(Number);
      const graceMinutes = shift.graceMinutes ?? 15;
      const shiftStartMs = shiftHour * 60 + shiftMin + graceMinutes;
      const nowMs = now.getHours() * 60 + now.getMinutes();
      isLate = nowMs > shiftStartMs;
    } else {
      // Fallback: 9:30 + 15 min grace = 9:45
      isLate = now.getHours() > 9 || (now.getHours() === 9 && now.getMinutes() > 45);
    }

    let isBiometricFaceVerified = false;
    if (dto.livePhotoBase64) {
      const biometric = await this.prisma.employeeFaceBiometric.findUnique({
        where: { employeeId: dto.employeeId },
      });

      if (!biometric || !biometric.isActive) {
        throw new BadRequestException('No active face biometric profile enrolled for this employee');
      }

      // Extract descriptor from live capture
      const extraction = await this.faceRecognitionService.validateAndExtractFace(dto.livePhotoBase64);
      if (!extraction.faceDetected) {
        throw new BadRequestException('No face detected in live photo capture');
      }

      // Decrypt enrolled biometric template
      const enrolledVector = this.faceRecognitionService.decryptEmbedding(
        biometric.encryptedEmbedding,
        biometric.embeddingIv,
        biometric.embeddingAuthTag,
      );

      // Compare vectors
      const matchResult = this.faceRecognitionService.compareFaces(
        extraction.descriptor,
        enrolledVector,
        0.55,
      );

      if (!matchResult.isMatch) {
        if (emp.userId) {
          await this.auditService.log({
            userId: emp.userId,
            action: 'ATTENDANCE_FACE_MISMATCH',
            module: 'HR_ATTENDANCE',
            entityType: 'Attendance',
            entityId: dto.employeeId,
            details: `Face verification rejected during clock-in: distance ${matchResult.distance.toFixed(4)} exceeds threshold 0.55`,
          });
        }
        throw new UnauthorizedException('Biometric face verification failed. Identity does not match enrolled employee.');
      }

      isBiometricFaceVerified = true;
      if (emp.userId) {
        await this.auditService.log({
          userId: emp.userId,
          action: 'ATTENDANCE_FACE_VERIFIED',
          module: 'HR_ATTENDANCE',
          entityType: 'Attendance',
          entityId: dto.employeeId,
          details: `Biometric clock-in verified successfully: distance ${matchResult.distance.toFixed(4)}`,
        });
      }
    }

    const noteText = isBiometricFaceVerified
      ? `${dto.note ? dto.note + ' | ' : ''}Biometric Face Verified`
      : (dto.note || 'Biometric / Mobile Punch');

    return this.prisma.attendance.upsert({
      where: { employeeId_punchDate: { employeeId: dto.employeeId, punchDate: today } },
      update: {
        punchIn: now,
        status: isLate ? 'LATE' : 'PRESENT',
        shiftCode: emp.shiftCode || 'SHIFT_G',
        assignedBay: emp.assignedBay || 'BAY_4_WIRING',
        location: dto.location || 'MIDC Industrial Unit',
        checkInNote: noteText,
      },
      create: {
        employeeId: dto.employeeId,
        punchDate: today,
        punchIn: now,
        status: isLate ? 'LATE' : 'PRESENT',
        shiftCode: emp.shiftCode || 'SHIFT_G',
        assignedBay: emp.assignedBay || 'BAY_4_WIRING',
        location: dto.location || 'MIDC Industrial Unit',
        checkInNote: noteText,
      },
      include: { employee: true },
    });
  }

  async clockOut(dto: ClockOutDto) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const now = new Date();
    const existing = await this.prisma.attendance.findUnique({
      where: { employeeId_punchDate: { employeeId: dto.employeeId, punchDate: today } },
    });

    if (!existing || !existing.punchIn) {
      throw new BadRequestException('Employee has not clocked in today yet');
    }

    const diffHours = (now.getTime() - existing.punchIn.getTime()) / (1000 * 60 * 60);
    const standardHours = 8.5;
    const otHours = diffHours > standardHours ? Math.round((diffHours - standardHours) * 10) / 10 : 0;

    return this.prisma.attendance.update({
      where: { id: existing.id },
      data: {
        punchOut: now,
        workHours: Math.round(diffHours * 100) / 100,
        overtimeHours: otHours,
        overtimeApproved: otHours > 0, // Auto pre-flag for supervisor signoff
        checkOutNote: dto.note || 'Shift ended',
      },
      include: { employee: true },
    });
  }

  // -------------------------------------------------------------
  // 9. LEAVE MANAGEMENT
  // -------------------------------------------------------------
  async getLeaveRequests(status?: string) {
    const where: any = {};
    if (status) where.status = status;

    return this.prisma.leaveRequest.findMany({
      where,
      include: {
        employee: {
          include: { department: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createLeaveRequest(dto: CreateLeaveDto) {
    const leaveCode = await this.sequenceService.nextLeaveCode();

    return this.prisma.leaveRequest.create({
      data: {
        leaveCode,
        employeeId: dto.employeeId,
        leaveType: dto.leaveType,
        startDate: new Date(dto.startDate),
        endDate: new Date(dto.endDate),
        daysCount: dto.daysCount,
        reason: dto.reason,
        status: 'PENDING',
      },
      include: {
        employee: {
          include: { department: true },
        },
      },
    });
  }

  async updateLeaveStatus(id: string, dto: UpdateLeaveStatusDto, approverName: string) {
    const leave = await this.prisma.leaveRequest.findUnique({ where: { id } });
    if (!leave) throw new NotFoundException('Leave request not found');

    const updated = await this.prisma.leaveRequest.update({
      where: { id },
      data: {
        status: dto.status,
        approvedBy: approverName,
        decisionNote: dto.decisionNote,
      },
      include: {
        employee: true,
      },
    });

    if (dto.status === 'APPROVED') {
      const now = new Date();
      if (now >= leave.startDate && now <= leave.endDate) {
        await this.prisma.employee.update({
          where: { id: leave.employeeId },
          data: { status: 'ON_LEAVE' },
        });
      }
    }

    return updated;
  }

  // -------------------------------------------------------------
  // 10. PAYROLL & STATUTORY FACTORY REGISTER
  // -------------------------------------------------------------
  async getPayrollRecords(month?: string, year?: number) {
    const where: any = {};
    if (month) where.month = month;
    if (year) where.year = Number(year);

    return this.prisma.payrollRecord.findMany({
      where,
      include: {
        employee: {
          include: { department: true },
        },
      },
      orderBy: { slipNumber: 'asc' },
    });
  }
}
