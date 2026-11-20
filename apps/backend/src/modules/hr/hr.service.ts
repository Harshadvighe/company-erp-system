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
import { CreateExpenseDto, ReviewExpenseDto, ApproveExpenseDto } from './dto/expense.dto';

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

    const employees = await this.prisma.employee.findMany({
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
            assignedModules: true,
          },
        },
      },
      orderBy: { employeeCode: 'asc' },
    });

    return employees.map((emp) => {
      if (!emp.assignedModules && emp.user?.assignedModules) {
        return {
          ...emp,
          assignedModules: emp.user.assignedModules,
        };
      }
      return emp;
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

    const parsedDob = dto.dateOfBirth && !isNaN(new Date(dto.dateOfBirth).getTime())
      ? new Date(dto.dateOfBirth)
      : null;

    const serializedModules = dto.assignedModules
      ? (typeof dto.assignedModules === 'string' ? dto.assignedModules : JSON.stringify(dto.assignedModules))
      : null;

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
          assignedModules: serializedModules,
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
        dateOfBirth: parsedDob,
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
        assignedModules: serializedModules,
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
    const parsedUpdateDob = dto.dateOfBirth !== undefined
      ? (dto.dateOfBirth && !isNaN(new Date(dto.dateOfBirth).getTime()) ? new Date(dto.dateOfBirth) : null)
      : undefined;

    let serializedModules = dto.assignedModules !== undefined
      ? (dto.assignedModules ? (typeof dto.assignedModules === 'string' ? dto.assignedModules : JSON.stringify(dto.assignedModules)) : null)
      : undefined;

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
      if (serializedModules !== undefined) userUpdates.assignedModules = serializedModules;

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
    } else {
      // Find if user already exists for this employee
      const reqUsername = dto.username?.trim() || (dto.email || existing.email).split('@')[0];
      const existingUser = await this.prisma.user.findFirst({
        where: { OR: [{ email: (dto.email || existing.email).trim() }, { username: reqUsername }] },
      });

      if (existingUser) {
        // Link employee to existing user account and sync modules/details
        updatedUserId = existingUser.id;
        const userUpdates: any = {};
        if (serializedModules !== undefined) userUpdates.assignedModules = serializedModules;
        if (dto.designation) userUpdates.designation = dto.designation;
        if (validDepartmentId !== undefined) userUpdates.departmentId = validDepartmentId;
        if (newPassword) userUpdates.passwordHash = await bcrypt.hash(newPassword, 10);
        if (Object.keys(userUpdates).length > 0) {
          await this.prisma.user.update({
            where: { id: existingUser.id },
            data: userUpdates,
          });
        }
      } else if (dto.createUserAccount || (dto.username && dto.password)) {

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
          assignedModules: serializedModules !== undefined ? serializedModules : existing.assignedModules,
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
  }

    const updated = await this.prisma.employee.update({
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
        ...(parsedUpdateDob !== undefined && { dateOfBirth: parsedUpdateDob }),
        ...(serializedModules !== undefined && { assignedModules: serializedModules }),
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
            assignedModules: true,
          },
        },
      },
    });

    if (!updated.assignedModules && updated.user?.assignedModules) {
      return {
        ...updated,
        assignedModules: updated.user.assignedModules,
      };
    }
    return updated;
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

  // -------------------------------------------------------------
  // 11. WORKFLOW 4: OFFICE EXPENSE (HR / ADMIN) LIFECYCLE
  // -------------------------------------------------------------
  async getExpenses(status?: string, category?: string, search?: string) {
    let query = `SELECT * FROM office_expenses WHERE 1=1`;
    const params: any[] = [];

    if (status && status !== 'ALL') {
      params.push(status);
      query += ` AND status = $${params.length}`;
    }
    if (category && category !== 'ALL') {
      params.push(category);
      query += ` AND category = $${params.length}`;
    }
    if (search) {
      params.push(`%${search}%`);
      query += ` AND (title ILIKE $${params.length} OR voucher_number ILIKE $${params.length} OR staff_name ILIKE $${params.length} OR description ILIKE $${params.length})`;
    }
    query += ` ORDER BY created_at DESC`;

    return this.prisma.$queryRawUnsafe(query, ...params);
  }

  async getExpenseSummary() {
    const rows: any[] = await this.prisma.$queryRawUnsafe(`
      SELECT 
        COUNT(*)::int as total_vouchers,
        COALESCE(SUM(amount), 0)::float as total_amount,
        COUNT(*) FILTER (WHERE status = 'SUBMITTED')::int as pending_review,
        COUNT(*) FILTER (WHERE status = 'REVIEWED')::int as pending_approval,
        COUNT(*) FILTER (WHERE status IN ('APPROVED', 'PAID'))::int as approved_count,
        COALESCE(SUM(amount) FILTER (WHERE status IN ('APPROVED', 'PAID')), 0)::float as approved_amount
      FROM office_expenses;
    `);

    const byCategory: any[] = await this.prisma.$queryRawUnsafe(`
      SELECT category, COUNT(*)::int as count, COALESCE(SUM(amount), 0)::float as total
      FROM office_expenses
      GROUP BY category
      ORDER BY total DESC;
    `);

    return {
      summary: rows[0] || {},
      byCategory,
    };
  }

  async createExpense(dto: CreateExpenseDto, user: any) {
    const countRes: any[] = await this.prisma.$queryRawUnsafe(`SELECT COUNT(*)::int as cnt FROM office_expenses;`);
    const nextSeq = (countRes[0]?.cnt || 0) + 1;
    const voucherNumber = `EXP-2026-${String(nextSeq).padStart(5, '0')}`;
    const id = `exp-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`;

    const staffId = user?.id || null;
    const staffName = dto.staffName || user?.fullName || user?.name || user?.username || 'Saark Staff';
    const staffEmail = user?.email || (user?.username ? `${user.username}@saark.in` : 'staff@saark.in');
    const department = dto.department || user?.department || 'Operations';
    const expenseDate = dto.expenseDate ? new Date(dto.expenseDate) : new Date();

    await this.prisma.$executeRawUnsafe(
      `INSERT INTO office_expenses (
        id, voucher_number, title, category, amount, expense_date, description,
        receipt_url, status, staff_id, staff_name, staff_email, department, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'SUBMITTED', $9, $10, $11, $12, NOW(), NOW())`,
      id,
      voucherNumber,
      dto.title,
      dto.category,
      Number(dto.amount),
      expenseDate,
      dto.description || null,
      dto.receiptUrl || null,
      staffId,
      staffName,
      staffEmail,
      department,
    );

    this.logger.log(`[OfficeExpense] Created voucher ${voucherNumber} (₹${dto.amount}) by ${staffName}`);

    return {
      id,
      voucherNumber,
      title: dto.title,
      category: dto.category,
      amount: dto.amount,
      status: 'SUBMITTED',
      message: 'Expense voucher submitted successfully. Forwarded to Department / HR Admin for review.',
    };
  }

  async reviewExpense(id: string, dto: ReviewExpenseDto, reviewer: string) {
    const existing: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT * FROM office_expenses WHERE id = $1`,
      id,
    );
    if (!existing || existing.length === 0) {
      throw new NotFoundException(`Expense voucher with ID ${id} not found`);
    }

    const newStatus = dto.status === 'REVIEWED' ? 'REVIEWED' : 'REJECTED';

    await this.prisma.$executeRawUnsafe(
      `UPDATE office_expenses SET
        status = $1,
        reviewed_by = $2,
        reviewed_at = NOW(),
        review_notes = $3,
        updated_at = NOW()
      WHERE id = $4`,
      newStatus,
      reviewer,
      dto.reviewNotes || null,
      id,
    );

    this.logger.log(`[OfficeExpense] Voucher ${existing[0].voucher_number} marked as ${newStatus} by ${reviewer}`);

    return {
      id,
      voucherNumber: existing[0].voucher_number,
      status: newStatus,
      reviewedBy: reviewer,
      message: newStatus === 'REVIEWED'
        ? 'Voucher reviewed & verified. Forwarded to Managing Director (Saarkadmin) for final approval.'
        : 'Voucher rejected during Department Admin review.',
    };
  }

  async approveExpense(id: string, dto: ApproveExpenseDto, approver: string) {
    const existing: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT * FROM office_expenses WHERE id = $1`,
      id,
    );
    if (!existing || existing.length === 0) {
      throw new NotFoundException(`Expense voucher with ID ${id} not found`);
    }

    if (dto.status === 'REJECTED') {
      await this.prisma.$executeRawUnsafe(
        `UPDATE office_expenses SET
          status = 'REJECTED',
          approved_by = $1,
          approved_at = NOW(),
          approval_notes = $2,
          updated_at = NOW()
        WHERE id = $3`,
        approver,
        dto.approvalNotes || null,
        id,
      );

      return {
        id,
        voucherNumber: existing[0].voucher_number,
        status: 'REJECTED',
        approvedBy: approver,
        message: 'Expense voucher rejected by Managing Director.',
      };
    }

    // Step 4.2 & 4.3: Managing Director Approval & Ledger Posting
    const markPaid = dto.markPaid !== false;
    const finalStatus = markPaid ? 'PAID' : 'APPROVED';
    const paymentMode = dto.paymentMode || 'PETTY_CASH';
    const ledgerRef = `JV-2026-${Math.floor(1000 + Math.random() * 9000)}`;

    await this.prisma.$executeRawUnsafe(
      `UPDATE office_expenses SET
        status = $1,
        approved_by = $2,
        approved_at = NOW(),
        approval_notes = $3,
        payment_mode = $4,
        ledger_account = 'OFFICE_EXPENSE_LEDGER',
        ledger_ref = $5,
        paid_at = ${markPaid ? 'NOW()' : 'NULL'},
        updated_at = NOW()
      WHERE id = $6`,
      finalStatus,
      approver,
      dto.approvalNotes || 'Approved by Managing Director',
      paymentMode,
      ledgerRef,
      id,
    );

    this.logger.log(`[OfficeExpense] Voucher ${existing[0].voucher_number} APPROVED by MD ${approver}. Posted to Ledger (${ledgerRef}, Mode: ${paymentMode})`);

    return {
      id,
      voucherNumber: existing[0].voucher_number,
      status: finalStatus,
      approvedBy: approver,
      paymentMode,
      ledgerAccount: 'OFFICE_EXPENSE_LEDGER',
      ledgerRef,
      message: `Voucher approved by Managing Director. Automatically debited Office Expense Ledger and credited ${paymentMode} (${ledgerRef}).`,
    };
  }

  // -------------------------------------------------------------
  // 12. USER IDLE SECURITY & INACTIVITY LOCKOUT ACCESS FACILITY
  // -------------------------------------------------------------
  async getAllUsersIdleStatus(search?: string, lockedOnly?: boolean) {
    const where: any = {};
    if (lockedOnly) {
      where.OR = [
        { isIdleLocked: true },
        { idleLogoutCount: { gte: 10 } },
      ];
    }
    if (search && search.trim().length > 0) {
      const q = search.trim();
      where.AND = [
        ...(where.AND || []),
        {
          OR: [
            { username: { contains: q, mode: 'insensitive' } },
            { fullName: { contains: q, mode: 'insensitive' } },
            { email: { contains: q, mode: 'insensitive' } },
            { designation: { contains: q, mode: 'insensitive' } },
          ],
        },
      ];
    }

    const users = await this.prisma.user.findMany({
      where,
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true,
        phone: true,
        designation: true,
        status: true,
        idleLogoutCount: true,
        isIdleLocked: true,
        idleLockedAt: true,
        lastActivityAt: true,
        faceVerificationEnabled: true,
        faceVerificationStatus: true,
        department: {
          select: {
            id: true,
            name: true,
            code: true,
          },
        },
        userRoles: {
          select: {
            role: {
              select: {
                id: true,
                name: true,
                code: true,
              },
            },
          },
        },
      },
      orderBy: [
        { isIdleLocked: 'desc' },
        { idleLogoutCount: 'desc' },
        { fullName: 'asc' },
      ],
    });

    const totalUsers = users.length;
    const lockedCount = users.filter((u) => u.isIdleLocked || (u.idleLogoutCount ?? 0) >= 10).length;
    const atRiskCount = users.filter((u) => (u.idleLogoutCount ?? 0) >= 5 && !u.isIdleLocked).length;

    return {
      users,
      stats: {
        totalUsers,
        lockedCount,
        atRiskCount,
        maxLimit: 10,
        inactivityPeriodMinutes: 30,
      },
    };
  }

  async resetUserIdleLimit(targetUserId: string, hrAdmin: any, ipAddress?: string) {
    const targetUser = await this.prisma.user.findUnique({
      where: { id: targetUserId },
    });

    if (!targetUser) {
      throw new NotFoundException(`User with ID ${targetUserId} not found`);
    }

    const previousCount = targetUser.idleLogoutCount ?? 0;
    const wasLocked = targetUser.isIdleLocked;

    const updatedUser = await this.prisma.user.update({
      where: { id: targetUserId },
      data: {
        idleLogoutCount: 0,
        isIdleLocked: false,
        idleLockedAt: null,
      },
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true,
        idleLogoutCount: true,
        isIdleLocked: true,
        idleLockedAt: true,
      },
    });

    const adminName = hrAdmin?.fullName || hrAdmin?.username || 'HR Administrator';

    await this.auditService.log({
      userId: hrAdmin?.id || targetUserId,
      userEmail: hrAdmin?.email,
      action: 'HR_RESET_IDLE_LOCKOUT',
      module: 'HR_SECURITY',
      entityType: 'USER',
      entityId: targetUserId,
      details: `HR Administrator ${adminName} granted login access and reset inactivity counter (was ${previousCount}/10, locked: ${wasLocked}) for user ${targetUser.fullName} (${targetUser.username}).`,
      ipAddress,
    });

    this.logger.log(
      `[IdleSecurity] Reset inactivity lockout for user ${targetUser.username} by ${adminName}`,
    );

    return {
      success: true,
      message: `Login access granted! Inactivity counter for ${targetUser.fullName} (${targetUser.username}) has been successfully reset to 0 / 10.`,
      user: updatedUser,
    };
  }

  // -------------------------------------------------------------
  // 13. AUTOMATED BIRTHDAY NOTIFICATIONS & CELEBRATION SYSTEM
  // -------------------------------------------------------------
  async getTodayBirthdays(currentUserId?: string, currentUserEmail?: string) {
    const now = new Date();
    // Indian Standard Time (IST)
    const istString = now.toLocaleString('en-US', { timeZone: 'Asia/Kolkata' });
    const istDate = new Date(istString);
    const currentMonth = istDate.getMonth() + 1; // 1 to 12
    const currentDay = istDate.getDate(); // 1 to 31

    const employees = await this.prisma.employee.findMany({
      where: { status: 'ACTIVE' },
      include: {
        department: true,
        user: {
          select: {
            id: true,
            username: true,
            email: true,
            fullName: true,
          },
        },
      },
    });

    const todayCelebrants: any[] = [];
    const upcoming: any[] = [];

    for (const emp of employees) {
      if (!emp.dateOfBirth) continue;
      const dob = new Date(emp.dateOfBirth);
      const dobMonth = dob.getUTCMonth() + 1;
      const dobDay = dob.getUTCDate();

      const isToday =
        (dobMonth === currentMonth && dobDay === currentDay) ||
        (dob.getMonth() + 1 === currentMonth && dob.getDate() === currentDay);

      const birthYear = dob.getFullYear();
      const age = istDate.getFullYear() - birthYear;

      if (isToday) {
        // Fetch wishes sent today
        const wishes: any[] = await this.prisma.$queryRawUnsafe(
          `SELECT id, sender_name, sender_user_id, message, created_at
           FROM birthday_wishes
           WHERE employee_id = $1
           ORDER BY created_at DESC`,
          emp.id,
        );

        const hasSentWish = wishes.some(
          (w: any) => w.sender_user_id === currentUserId,
        );

        todayCelebrants.push({
          id: emp.id,
          userId: emp.userId,
          employeeCode: emp.employeeCode,
          fullName: `${emp.firstName} ${emp.lastName}`.trim(),
          firstName: emp.firstName,
          lastName: emp.lastName,
          email: emp.email,
          phone: emp.phone,
          designation: emp.designation,
          department: emp.department?.name || 'General Operations',
          workerCategory: emp.workerCategory,
          avatarUrl: emp.avatarUrl,
          dateOfBirth: emp.dateOfBirth,
          age: age > 0 ? age : null,
          wishesCount: wishes.length,
          wishes,
          hasSentWish,
        });
      } else {
        // Calculate days remaining until next birthday
        let nextBday = new Date(istDate.getFullYear(), dobMonth - 1, dobDay);
        if (nextBday < istDate) {
          nextBday = new Date(istDate.getFullYear() + 1, dobMonth - 1, dobDay);
        }
        const diffMs = nextBday.getTime() - istDate.getTime();
        const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
        if (diffDays > 0 && diffDays <= 30) {
          upcoming.push({
            id: emp.id,
            fullName: `${emp.firstName} ${emp.lastName}`.trim(),
            designation: emp.designation,
            department: emp.department?.name || 'General Operations',
            dateOfBirth: emp.dateOfBirth,
            daysAway: diffDays,
            birthdayFormatted: `${dobDay} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dobMonth - 1]}`,
          });
        }
      }
    }

    upcoming.sort((a, b) => a.daysAway - b.daysAway);

    const myCelebration = todayCelebrants.find((c) => {
      return (
        (c.userId && c.userId === currentUserId) ||
        (c.email && currentUserEmail && c.email.toLowerCase() === currentUserEmail.toLowerCase())
      );
    });
    const isMyBirthday = Boolean(myCelebration);

    return {
      hasCelebrantsToday: todayCelebrants.length > 0,
      isMyBirthday,
      myCelebration: myCelebration || null,
      celebrants: todayCelebrants,
      upcoming,
      totalWishesToday: todayCelebrants.reduce((acc, c) => acc + (c.wishesCount || 0), 0),
    };
  }

  async sendBirthdayWish(dto: { employeeId: string; message?: string }, currentUser: any) {
    const emp = await this.prisma.employee.findUnique({
      where: { id: dto.employeeId },
      include: { user: true, department: true },
    });

    if (!emp) {
      throw new NotFoundException(`Employee with ID ${dto.employeeId} not found`);
    }

    const senderName = currentUser?.fullName || currentUser?.username || 'Saark Team Member';
    const defaultWish = `🎂 Wishing you a very Happy Birthday, ${emp.firstName}! May your year be filled with immense happiness, robust health, and continued success! 🎉 — With warm regards from ${senderName}`;
    const message = (dto.message && dto.message.trim().length > 0) ? dto.message.trim() : defaultWish;

    const wishId = `wish-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`;

    await this.prisma.$executeRawUnsafe(
      `INSERT INTO birthday_wishes (
        id, employee_id, sender_user_id, sender_name, sender_avatar,
        recipient_name, recipient_email, message, wish_date, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CURRENT_DATE, NOW())`,
      wishId,
      emp.id,
      currentUser.id,
      senderName,
      null,
      `${emp.firstName} ${emp.lastName}`.trim(),
      emp.email,
      message,
    );

    // In-app Notification for the birthday celebrant
    if (emp.userId) {
      try {
        await this.prisma.notification.create({
          data: {
            userId: emp.userId,
            title: `🎉 Happy Birthday Wish from ${senderName}! 🎂`,
            message,
            module: 'HR',
            entityId: wishId,
          },
        });
      } catch (_) {}
    }

    // Log security audit record
    await this.auditService.log({
      userId: currentUser.id,
      userEmail: currentUser.email,
      action: 'BIRTHDAY_WISH_SENT',
      module: 'HR',
      entityType: 'EMPLOYEE',
      entityId: emp.id,
      details: `${senderName} sent birthday wishes to ${emp.firstName} ${emp.lastName} (${emp.employeeCode})`,
    });

    // Send celebration email to the celebrant
    if (emp.email) {
      try {
        await this.mailService.sendBirthdayEmail({
          to: emp.email,
          fullName: `${emp.firstName} ${emp.lastName}`.trim(),
          senderName,
          message,
        });
      } catch (mailErr: any) {
        this.logger.warn(`Could not dispatch birthday wish email to ${emp.email}: ${mailErr.message}`);
      }
    }

    this.logger.log(`[BirthdayCelebration] Wish sent from ${senderName} to ${emp.firstName} ${emp.lastName}`);

    return {
      success: true,
      message: `Your warm birthday wish has been delivered to ${emp.firstName}! 🎂🎉`,
      wish: {
        id: wishId,
        senderName,
        recipientName: `${emp.firstName} ${emp.lastName}`.trim(),
        message,
        createdAt: new Date(),
      },
    };
  }

  async broadcastBirthdayWishes(dto: { message?: string }, currentUser: any) {
    const todayData = await this.getTodayBirthdays(currentUser.id, currentUser.email);
    if (!todayData.celebrants || todayData.celebrants.length === 0) {
      return { success: false, message: 'No employees have birthdays today to broadcast to.' };
    }

    const broadcasterName = currentUser?.fullName || currentUser?.username || 'Executive Management';
    const results: any[] = [];

    for (const cel of todayData.celebrants) {
      const msg = dto.message && dto.message.trim().length > 0
        ? dto.message.trim()
        : `🎈 Saark Exploration Private Limited wishes you a joyful and splendid Happy Birthday, ${cel.firstName}! Thank you for your dedication and contributions to our team. 🎂🎉 — ${broadcasterName}`;

      const res = await this.sendBirthdayWish({ employeeId: cel.id, message: msg }, currentUser);
      results.push(res);
    }

    // Notify ALL other users in the system about the celebration!
    const allUsers = await this.prisma.user.findMany({
      where: { status: 'ACTIVE' },
      select: { id: true },
    });

    const celebrantNames = todayData.celebrants.map((c: any) => c.fullName).join(', ');
    for (const u of allUsers) {
      try {
        await this.prisma.notification.create({
          data: {
            userId: u.id,
            title: `🎂 Today's Birthday Celebration: ${celebrantNames}! 🎉`,
            message: `Today is ${celebrantNames}'s birthday! Join Saark Exploration in sending your warmest wishes and blessings!`,
            module: 'HR',
          },
        });
      } catch (_) {}
    }

    return {
      success: true,
      message: `Company-wide birthday broadcast completed for ${celebrantNames}! 🎂`,
      results,
    };
  }
}
