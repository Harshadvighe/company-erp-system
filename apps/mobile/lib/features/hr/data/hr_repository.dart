import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';

class HrRepository {
  final Dio _dio;

  HrRepository(this._dio);

  Future<HrDashboardMetrics> getDashboard() async {
    final response = await _dio.get('/hr/dashboard');
    final data = response.data['data'] ?? response.data;
    return HrDashboardMetrics.fromJson(data);
  }

  Future<List<Employee>> getEmployees({
    String? search,
    String? departmentId,
    String? status,
    String? workerCategory,
  }) async {
    final response = await _dio.get('/hr/employees', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (workerCategory != null && workerCategory.isNotEmpty) 'workerCategory': workerCategory,
    });
    final list = response.data['data'] as List? ?? [];
    return list.map((i) => Employee.fromJson(i)).toList();
  }

  Future<Employee> getEmployeeById(String id) async {
    final response = await _dio.get('/hr/employees/$id');
    final data = response.data['data'] ?? response.data;
    return Employee.fromJson(data);
  }

  Future<Employee> createEmployee(Map<String, dynamic> payload) async {
    final response = await _dio.post('/hr/employees', data: payload);
    final data = response.data['data'] ?? response.data;
    return Employee.fromJson(data);
  }

  Future<Employee> updateEmployee(String id, Map<String, dynamic> payload) async {
    final response = await _dio.put('/hr/employees/$id', data: payload);
    final data = response.data['data'] ?? response.data;
    return Employee.fromJson(data);
  }

  Future<List<AttendanceItem>> getAttendance({String? date}) async {
    final response = await _dio.get('/hr/attendance', queryParameters: {
      if (date != null) 'date': date,
    });
    final data = response.data['data'] ?? response.data;
    final records = data['records'] as List? ?? [];
    return records.map((i) => AttendanceItem.fromJson(i)).toList();
  }

  Future<AttendanceItem> clockIn(String employeeId, {String? location, String? note}) async {
    final response = await _dio.post('/hr/attendance/clock-in', data: {
      'employeeId': employeeId,
      'location': location,
      'note': note,
    });
    final data = response.data['data'] ?? response.data;
    return AttendanceItem.fromJson(data);
  }

  Future<AttendanceItem> clockOut(String employeeId, {String? note}) async {
    final response = await _dio.post('/hr/attendance/clock-out', data: {
      'employeeId': employeeId,
      'note': note,
    });
    final data = response.data['data'] ?? response.data;
    return AttendanceItem.fromJson(data);
  }

  // Industrial Shifts
  Future<List<ShiftMasterItem>> getShifts() async {
    final response = await _dio.get('/hr/shifts');
    final list = response.data['data'] as List? ?? [];
    return list.map((i) => ShiftMasterItem.fromJson(i)).toList();
  }

  // Workstation Bay Allocations
  Future<List<WorkstationAllocationItem>> getWorkstations({String? date}) async {
    final response = await _dio.get('/hr/workstations', queryParameters: {
      if (date != null) 'date': date,
    });
    final list = response.data['data'] as List? ?? [];
    return list.map((i) => WorkstationAllocationItem.fromJson(i)).toList();
  }

  Future<WorkstationAllocationItem> allocateWorkstation(Map<String, dynamic> payload) async {
    final response = await _dio.post('/hr/workstations/allocate', data: payload);
    final data = response.data['data'] ?? response.data;
    return WorkstationAllocationItem.fromJson(data);
  }

  // Overtime
  Future<AttendanceItem> logOvertime(String attendanceId, double hours, {bool approved = true}) async {
    final response = await _dio.post('/hr/overtime/log', data: {
      'attendanceId': attendanceId,
      'overtimeHours': hours,
      'approved': approved,
    });
    final data = response.data['data'] ?? response.data;
    return AttendanceItem.fromJson(data);
  }

  Future<void> approveOvertime(String attendanceId, bool approved) async {
    await _dio.patch('/hr/overtime/$attendanceId/approve', data: {
      'approved': approved,
    });
  }

  // Safety & EHS
  Future<List<SafetyIncidentItem>> getSafetyIncidents() async {
    final response = await _dio.get('/hr/safety');
    final list = response.data['data'] as List? ?? [];
    return list.map((i) => SafetyIncidentItem.fromJson(i)).toList();
  }

  Future<SafetyIncidentItem> reportSafetyIncident(Map<String, dynamic> payload) async {
    final response = await _dio.post('/hr/safety', data: payload);
    final data = response.data['data'] ?? response.data;
    return SafetyIncidentItem.fromJson(data);
  }

  // Leaves
  Future<List<LeaveRequestItem>> getLeaves({String? status}) async {
    final response = await _dio.get('/hr/leaves', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    final list = response.data['data'] as List? ?? [];
    return list.map((i) => LeaveRequestItem.fromJson(i)).toList();
  }

  Future<LeaveRequestItem> createLeave(Map<String, dynamic> payload) async {
    final response = await _dio.post('/hr/leaves', data: payload);
    final data = response.data['data'] ?? response.data;
    return LeaveRequestItem.fromJson(data);
  }

  Future<LeaveRequestItem> updateLeaveStatus(String id, String status, {String? decisionNote}) async {
    final response = await _dio.patch('/hr/leaves/$id/status', data: {
      'status': status,
      if (decisionNote != null) 'decisionNote': decisionNote,
    });
    final data = response.data['data'] ?? response.data;
    return LeaveRequestItem.fromJson(data);
  }

  // Payroll
  Future<List<PayrollItem>> getPayroll({String? month, int? year}) async {
    final response = await _dio.get('/hr/payroll', queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    final list = response.data['data'] as List? ?? [];
    return list.map((i) => PayrollItem.fromJson(i)).toList();
  }
}

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  return HrRepository(ref.watch(dioProvider));
});

// State Providers
final hrDashboardProvider = FutureProvider.autoDispose<HrDashboardMetrics>((ref) async {
  return ref.watch(hrRepositoryProvider).getDashboard();
});

final employeesListProvider = FutureProvider.autoDispose.family<List<Employee>, String?>((ref, search) async {
  return ref.watch(hrRepositoryProvider).getEmployees(search: search);
});

final attendanceTodayProvider = FutureProvider.autoDispose<List<AttendanceItem>>((ref) async {
  return ref.watch(hrRepositoryProvider).getAttendance();
});

final shiftsProvider = FutureProvider.autoDispose<List<ShiftMasterItem>>((ref) async {
  return ref.watch(hrRepositoryProvider).getShifts();
});

final workstationAllocationsProvider = FutureProvider.autoDispose<List<WorkstationAllocationItem>>((ref) async {
  return ref.watch(hrRepositoryProvider).getWorkstations();
});

final safetyIncidentsProvider = FutureProvider.autoDispose<List<SafetyIncidentItem>>((ref) async {
  return ref.watch(hrRepositoryProvider).getSafetyIncidents();
});

final leaveRequestsProvider = FutureProvider.autoDispose.family<List<LeaveRequestItem>, String?>((ref, status) async {
  return ref.watch(hrRepositoryProvider).getLeaves(status: status);
});

final payrollListProvider = FutureProvider.autoDispose<List<PayrollItem>>((ref) async {
  return ref.watch(hrRepositoryProvider).getPayroll();
});
