// HR Module Data Models for Saark Industrial ERP

class Employee {
  final String id;
  final String employeeCode;
  final String? userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String designation;
  final String? departmentId;
  final String? departmentName;
  final String employmentType;
  final String workerCategory; // STAFF_OFFICE, SHOPFLOOR_TECH, CONTRACT_LABOR, APPRENTICE
  final String? skillLevel;    // LEVEL_1_TRAINEE, LEVEL_2_WIREMAN, LEVEL_3_BUSBAR_SPECIALIST, LEVEL_4_TESTING_EXPERT, STAFF_ENGINEER
  final String? assignedBay;   // BAY_1_FABRICATION, BAY_2_BUSBAR, BAY_3_MOUNTING, BAY_4_WIRING, BAY_5_FAT_TESTING, BAY_6_DISPATCH
  final String shiftCode;      // SHIFT_G, SHIFT_A, SHIFT_B, SHIFT_N
  final String? electricalLicenseNo;
  final String? contractorAgency;
  final bool ppeKitIssued;
  final double salaryCtc;
  final String status;
  final String? bankAccountNo;
  final String? bankIfsc;
  final String? panNo;
  final String? aadhaarNo;
  final String? bloodGroup;
  final String? emergencyPhone;
  final String? address;
  final String? avatarUrl;
  final DateTime joiningDate;

  String get fullName => '$firstName $lastName'.trim();

  const Employee({
    required this.id,
    required this.employeeCode,
    this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.designation,
    this.departmentId,
    this.departmentName,
    this.employmentType = 'FULL_TIME',
    this.workerCategory = 'SHOPFLOOR_TECH',
    this.skillLevel = 'LEVEL_2_WIREMAN',
    this.assignedBay = 'BAY_4_WIRING',
    this.shiftCode = 'SHIFT_G',
    this.electricalLicenseNo,
    this.contractorAgency,
    this.ppeKitIssued = true,
    this.salaryCtc = 0,
    this.status = 'ACTIVE',
    this.bankAccountNo,
    this.bankIfsc,
    this.panNo,
    this.aadhaarNo,
    this.bloodGroup,
    this.emergencyPhone,
    this.address,
    this.avatarUrl,
    required this.joiningDate,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? '',
      employeeCode: json['employeeCode'] ?? '',
      userId: json['userId'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      designation: json['designation'] ?? '',
      departmentId: json['departmentId'],
      departmentName: json['department']?['name'] ?? json['departmentName'],
      employmentType: json['employmentType'] ?? 'FULL_TIME',
      workerCategory: json['workerCategory'] ?? 'SHOPFLOOR_TECH',
      skillLevel: json['skillLevel'] ?? 'LEVEL_2_WIREMAN',
      assignedBay: json['assignedBay'] ?? 'BAY_4_WIRING',
      shiftCode: json['shiftCode'] ?? 'SHIFT_G',
      electricalLicenseNo: json['electricalLicenseNo'],
      contractorAgency: json['contractorAgency'],
      ppeKitIssued: json['ppeKitIssued'] ?? true,
      salaryCtc: (json['salaryCtc'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'ACTIVE',
      bankAccountNo: json['bankAccountNo'],
      bankIfsc: json['bankIfsc'],
      panNo: json['panNo'],
      aadhaarNo: json['aadhaarNo'],
      bloodGroup: json['bloodGroup'],
      emergencyPhone: json['emergencyPhone'],
      address: json['address'],
      avatarUrl: json['avatarUrl'],
      joiningDate: json['joiningDate'] != null
          ? DateTime.tryParse(json['joiningDate']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AttendanceItem {
  final String id;
  final String employeeId;
  final DateTime punchDate;
  final DateTime? punchIn;
  final DateTime? punchOut;
  final double workHours;
  final String status;
  final String shiftCode;
  final double overtimeHours;
  final bool overtimeApproved;
  final String? assignedBay;
  final bool ppeCompliant;
  final String? location;
  final String? checkInNote;
  final String? checkOutNote;
  final Employee? employee;

  const AttendanceItem({
    required this.id,
    required this.employeeId,
    required this.punchDate,
    this.punchIn,
    this.punchOut,
    this.workHours = 0,
    required this.status,
    this.shiftCode = 'SHIFT_G',
    this.overtimeHours = 0,
    this.overtimeApproved = false,
    this.assignedBay,
    this.ppeCompliant = true,
    this.location,
    this.checkInNote,
    this.checkOutNote,
    this.employee,
  });

  factory AttendanceItem.fromJson(Map<String, dynamic> json) {
    return AttendanceItem(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      punchDate: json['punchDate'] != null
          ? DateTime.tryParse(json['punchDate']) ?? DateTime.now()
          : DateTime.now(),
      punchIn: json['punchIn'] != null ? DateTime.tryParse(json['punchIn']) : null,
      punchOut: json['punchOut'] != null ? DateTime.tryParse(json['punchOut']) : null,
      workHours: (json['workHours'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'PRESENT',
      shiftCode: json['shiftCode'] ?? 'SHIFT_G',
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0,
      overtimeApproved: json['overtimeApproved'] ?? false,
      assignedBay: json['assignedBay'] ?? json['employee']?['assignedBay'],
      ppeCompliant: json['ppeCompliant'] ?? true,
      location: json['location'],
      checkInNote: json['checkInNote'],
      checkOutNote: json['checkOutNote'],
      employee: json['employee'] != null ? Employee.fromJson(json['employee']) : null,
    );
  }
}

class ShiftMasterItem {
  final String id;
  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final int graceMinutes;
  final double shiftAllowance;
  final String? departmentName;

  const ShiftMasterItem({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.graceMinutes = 15,
    this.shiftAllowance = 0,
    this.departmentName,
  });

  factory ShiftMasterItem.fromJson(Map<String, dynamic> json) {
    return ShiftMasterItem(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      startTime: json['startTime'] ?? '08:30',
      endTime: json['endTime'] ?? '17:00',
      graceMinutes: (json['graceMinutes'] as num?)?.toInt() ?? 15,
      shiftAllowance: (json['shiftAllowance'] as num?)?.toDouble() ?? 0,
      departmentName: json['departmentName'],
    );
  }
}

class WorkstationAllocationItem {
  final String id;
  final DateTime allocationDate;
  final String employeeId;
  final String bayCode;
  final String? panelCode;
  final String shiftCode;
  final double targetHours;
  final double actualHours;
  final String status;
  final String? supervisorNote;
  final Employee? employee;

  const WorkstationAllocationItem({
    required this.id,
    required this.allocationDate,
    required this.employeeId,
    required this.bayCode,
    this.panelCode,
    this.shiftCode = 'SHIFT_G',
    this.targetHours = 8.0,
    this.actualHours = 8.0,
    this.status = 'IN_PROGRESS',
    this.supervisorNote,
    this.employee,
  });

  factory WorkstationAllocationItem.fromJson(Map<String, dynamic> json) {
    return WorkstationAllocationItem(
      id: json['id'] ?? '',
      allocationDate: json['allocationDate'] != null
          ? DateTime.tryParse(json['allocationDate']) ?? DateTime.now()
          : DateTime.now(),
      employeeId: json['employeeId'] ?? '',
      bayCode: json['bayCode'] ?? '',
      panelCode: json['panelCode'],
      shiftCode: json['shiftCode'] ?? 'SHIFT_G',
      targetHours: (json['targetHours'] as num?)?.toDouble() ?? 8.0,
      actualHours: (json['actualHours'] as num?)?.toDouble() ?? 8.0,
      status: json['status'] ?? 'IN_PROGRESS',
      supervisorNote: json['supervisorNote'],
      employee: json['employee'] != null ? Employee.fromJson(json['employee']) : null,
    );
  }
}

class SafetyIncidentItem {
  final String id;
  final String incidentCode;
  final DateTime reportDate;
  final String incidentType;
  final String severity;
  final String locationBay;
  final String? employeeId;
  final String description;
  final String? actionTaken;
  final String status;
  final String? reportedBy;

  const SafetyIncidentItem({
    required this.id,
    required this.incidentCode,
    required this.reportDate,
    required this.incidentType,
    required this.severity,
    required this.locationBay,
    this.employeeId,
    required this.description,
    this.actionTaken,
    this.status = 'RESOLVED',
    this.reportedBy,
  });

  factory SafetyIncidentItem.fromJson(Map<String, dynamic> json) {
    return SafetyIncidentItem(
      id: json['id'] ?? '',
      incidentCode: json['incidentCode'] ?? '',
      reportDate: json['reportDate'] != null
          ? DateTime.tryParse(json['reportDate']) ?? DateTime.now()
          : DateTime.now(),
      incidentType: json['incidentType'] ?? 'NEAR_MISS',
      severity: json['severity'] ?? 'LOW',
      locationBay: json['locationBay'] ?? '',
      employeeId: json['employeeId'],
      description: json['description'] ?? '',
      actionTaken: json['actionTaken'],
      status: json['status'] ?? 'RESOLVED',
      reportedBy: json['reportedBy'],
    );
  }
}

class LeaveRequestItem {
  final String id;
  final String leaveCode;
  final String employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final double daysCount;
  final String reason;
  final String status;
  final String? approvedBy;
  final String? decisionNote;
  final DateTime createdAt;
  final Employee? employee;

  const LeaveRequestItem({
    required this.id,
    required this.leaveCode,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.daysCount = 1,
    required this.reason,
    this.status = 'PENDING',
    this.approvedBy,
    this.decisionNote,
    required this.createdAt,
    this.employee,
  });

  factory LeaveRequestItem.fromJson(Map<String, dynamic> json) {
    return LeaveRequestItem(
      id: json['id'] ?? '',
      leaveCode: json['leaveCode'] ?? '',
      employeeId: json['employeeId'] ?? '',
      leaveType: json['leaveType'] ?? 'CASUAL',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate']) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate']) ?? DateTime.now()
          : DateTime.now(),
      daysCount: (json['daysCount'] as num?)?.toDouble() ?? 1,
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'PENDING',
      approvedBy: json['approvedBy'],
      decisionNote: json['decisionNote'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      employee: json['employee'] != null ? Employee.fromJson(json['employee']) : null,
    );
  }
}

class PayrollItem {
  final String id;
  final String slipNumber;
  final String employeeId;
  final String month;
  final int year;
  final int monthNumber;
  final int workingDays;
  final double presentDays;
  final double basicSalary;
  final double hraAllowance;
  final double specialAllowance;
  final double overtimeHours;
  final double overtimePay;
  final double shiftAllowance;
  final double productionIncentive;
  final double grossPay;
  final double pfDeduction;
  final double taxDeduction;
  final double esiDeduction;
  final double totalDeductions;
  final double netPay;
  final String paymentStatus;
  final DateTime? paymentDate;
  final String paymentMode;
  final Employee? employee;

  const PayrollItem({
    required this.id,
    required this.slipNumber,
    required this.employeeId,
    required this.month,
    required this.year,
    required this.monthNumber,
    required this.workingDays,
    required this.presentDays,
    required this.basicSalary,
    required this.hraAllowance,
    required this.specialAllowance,
    this.overtimeHours = 0,
    this.overtimePay = 0,
    this.shiftAllowance = 0,
    this.productionIncentive = 0,
    required this.grossPay,
    required this.pfDeduction,
    required this.taxDeduction,
    required this.esiDeduction,
    required this.totalDeductions,
    required this.netPay,
    required this.paymentStatus,
    this.paymentDate,
    required this.paymentMode,
    this.employee,
  });

  factory PayrollItem.fromJson(Map<String, dynamic> json) {
    return PayrollItem(
      id: json['id'] ?? '',
      slipNumber: json['slipNumber'] ?? '',
      employeeId: json['employeeId'] ?? '',
      month: json['month'] ?? '',
      year: json['year'] ?? 2026,
      monthNumber: json['monthNumber'] ?? 10,
      workingDays: json['workingDays'] ?? 26,
      presentDays: (json['presentDays'] as num?)?.toDouble() ?? 26,
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0,
      hraAllowance: (json['hraAllowance'] as num?)?.toDouble() ?? 0,
      specialAllowance: (json['specialAllowance'] as num?)?.toDouble() ?? 0,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0,
      overtimePay: (json['overtimePay'] as num?)?.toDouble() ?? 0,
      shiftAllowance: (json['shiftAllowance'] as num?)?.toDouble() ?? 0,
      productionIncentive: (json['productionIncentive'] as num?)?.toDouble() ?? 0,
      grossPay: (json['grossPay'] as num?)?.toDouble() ?? 0,
      pfDeduction: (json['pfDeduction'] as num?)?.toDouble() ?? 0,
      taxDeduction: (json['taxDeduction'] as num?)?.toDouble() ?? 0,
      esiDeduction: (json['esiDeduction'] as num?)?.toDouble() ?? 0,
      totalDeductions: (json['totalDeductions'] as num?)?.toDouble() ?? 0,
      netPay: (json['netPay'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['paymentStatus'] ?? 'PAID',
      paymentDate: json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate']) : null,
      paymentMode: json['paymentMode'] ?? 'NEFT/RTGS',
      employee: json['employee'] != null ? Employee.fromJson(json['employee']) : null,
    );
  }
}

class HrDashboardMetrics {
  final int totalEmployees;
  final int activeEmployees;
  final int onLeaveEmployees;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int attendanceRate;
  final int pendingLeaves;
  final double totalMonthlyPayroll;
  final Map<String, int> workforceBreakdown;
  final Map<String, int> shiftBreakdown;
  final Map<String, dynamic> overtimeSummary;
  final Map<String, dynamic> safetyKpis;
  final int bayAllocationsCount;
  final List<DepartmentStat> departmentStats;
  final List<LeaveRequestItem> recentLeaves;
  final List<AttendanceItem> recentClockIns;

  const HrDashboardMetrics({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.onLeaveEmployees,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.attendanceRate,
    required this.pendingLeaves,
    required this.totalMonthlyPayroll,
    required this.workforceBreakdown,
    required this.shiftBreakdown,
    required this.overtimeSummary,
    required this.safetyKpis,
    required this.bayAllocationsCount,
    required this.departmentStats,
    required this.recentLeaves,
    required this.recentClockIns,
  });

  factory HrDashboardMetrics.fromJson(Map<String, dynamic> json) {
    final stats = json['todayStats'] ?? {};
    final deptList = (json['departmentStats'] as List?) ?? [];
    final leaves = (json['recentLeaves'] as List?) ?? [];
    final clocks = (json['recentClockIns'] as List?) ?? [];

    final wb = json['workforceBreakdown'] as Map<String, dynamic>? ?? {};
    final sb = json['shiftBreakdown'] as Map<String, dynamic>? ?? {};
    final ot = json['overtimeSummary'] as Map<String, dynamic>? ?? {};
    final safety = json['safetyKpis'] as Map<String, dynamic>? ?? {};

    return HrDashboardMetrics(
      totalEmployees: json['totalEmployees'] ?? 0,
      activeEmployees: json['activeEmployees'] ?? 0,
      onLeaveEmployees: json['onLeaveEmployees'] ?? 0,
      presentCount: stats['presentCount'] ?? 0,
      lateCount: stats['lateCount'] ?? 0,
      absentCount: stats['absentCount'] ?? 0,
      attendanceRate: stats['attendanceRate'] ?? 0,
      pendingLeaves: json['pendingLeaves'] ?? 0,
      totalMonthlyPayroll: (json['totalMonthlyPayroll'] as num?)?.toDouble() ?? 0,
      workforceBreakdown: wb.map((k, v) => MapEntry(k, (v as num).toInt())),
      shiftBreakdown: sb.map((k, v) => MapEntry(k, (v as num).toInt())),
      overtimeSummary: ot,
      safetyKpis: safety,
      bayAllocationsCount: json['bayAllocationsCount'] ?? 0,
      departmentStats: deptList.map((d) => DepartmentStat.fromJson(d)).toList(),
      recentLeaves: leaves.map((l) => LeaveRequestItem.fromJson(l)).toList(),
      recentClockIns: clocks.map((c) => AttendanceItem.fromJson(c)).toList(),
    );
  }
}

class DepartmentStat {
  final String name;
  final String code;
  final int count;

  const DepartmentStat({
    required this.name,
    required this.code,
    required this.count,
  });

  factory DepartmentStat.fromJson(Map<String, dynamic> json) {
    return DepartmentStat(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}
