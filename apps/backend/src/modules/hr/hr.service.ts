import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { CreateLeaveDto, UpdateLeaveStatusDto } from './dto/create-leave.dto';
import { ClockInDto, ClockOutDto } from './dto/clock-in.dto';
import { AllocateWorkstationDto, LogOvertimeDto, ReportSafetyIncidentDto } from './dto/industrial.dto';

@Injectable()
export class HrService {
  constructor(private readonly prisma: PrismaService) {}

  // -------------------------------------------------------------
  // 1. HR INDUSTRIAL DASHBOARD & EXECUTIVE METRICS
  // -------------------------------------------------------------
  async getDashboardMetrics() {
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
          select: { firstName: true, lastName: true, designation: true, employeeCode: true, skillLevel: true },
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

    // Monthly Payroll
    const payrollRecords = await this.prisma.payrollRecord.findMany({
      where: { monthNumber: 10, year: 2026 },
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
          select: { firstName: true, lastName: true, designation: true, employeeCode: true },
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
          select: { firstName: true, lastName: true, designation: true, employeeCode: true, assignedBay: true, shiftCode: true },
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
        incidentFreeDays: 142, // Certified LTI Free milestone
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
    const count = await this.prisma.safetyIncident.count();
    const code = `INC-2026-${String(count + 1).padStart(3, '0')}`;

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
    const currentYear = year || 2026;
    const currentMonth = month ? Number(month) : 10;

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
        fullName: `${emp.firstName} ${emp.lastName}`,
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

  async createEmployee(dto: CreateEmployeeDto) {
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

    // Auto-generate next employeeCode safely without colliding
    const count = await this.prisma.employee.count();
    let codeIndex = count + 1;
    let nextCode = `EMP-2026-${String(codeIndex).padStart(3, '0')}`;
    while (await this.prisma.employee.findUnique({ where: { employeeCode: nextCode } })) {
      codeIndex++;
      nextCode = `EMP-2026-${String(codeIndex).padStart(3, '0')}`;
    }

    return this.prisma.employee.create({
      data: {
        employeeCode: nextCode,
        firstName: dto.firstName,
        lastName: dto.lastName,
        email: normalizedEmail,
        phone: dto.phone,
        designation: dto.designation,
        departmentId: dto.departmentId,
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
      },
      include: { department: true },
    });
  }

  async updateEmployee(idOrCode: string, dto: Partial<CreateEmployeeDto>) {
    const existing = await this.prisma.employee.findFirst({
      where: {
        OR: [{ id: idOrCode }, { employeeCode: idOrCode }],
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

    return this.prisma.employee.update({
      where: { id: existing.id },
      data: {
        ...(dto.firstName !== undefined && { firstName: dto.firstName }),
        ...(dto.lastName !== undefined && { lastName: dto.lastName }),
        ...(dto.email !== undefined && { email: dto.email.trim() }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
        ...(dto.designation !== undefined && { designation: dto.designation }),
        ...(dto.departmentId !== undefined && { departmentId: dto.departmentId }),
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
      include: { department: true },
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
    const isLate = now.getHours() > 9 || (now.getHours() === 9 && now.getMinutes() > 30);

    const emp = await this.prisma.employee.findUnique({ where: { id: dto.employeeId } });

    return this.prisma.attendance.upsert({
      where: { employeeId_punchDate: { employeeId: dto.employeeId, punchDate: today } },
      update: {
        punchIn: now,
        status: isLate ? 'LATE' : 'PRESENT',
        shiftCode: emp?.shiftCode || 'SHIFT_G',
        assignedBay: emp?.assignedBay || 'BAY_4_WIRING',
        location: dto.location || 'MIDC Industrial Unit',
        checkInNote: dto.note || 'Biometric / Mobile Punch',
      },
      create: {
        employeeId: dto.employeeId,
        punchDate: today,
        punchIn: now,
        status: isLate ? 'LATE' : 'PRESENT',
        shiftCode: emp?.shiftCode || 'SHIFT_G',
        assignedBay: emp?.assignedBay || 'BAY_4_WIRING',
        location: dto.location || 'MIDC Industrial Unit',
        checkInNote: dto.note || 'Biometric / Mobile Punch',
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
    const count = await this.prisma.leaveRequest.count();
    const leaveCode = `LV-2026-${String(count + 1).padStart(4, '0')}`;

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
