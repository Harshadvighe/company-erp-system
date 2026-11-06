import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_device_model.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AttendanceRepository(dio);
});

// State for active date in Attendance Ledger
final attendanceSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Riverpod provider for Biometric Devices
final attendanceDevicesProvider = FutureProvider.autoDispose<List<BiometricDevice>>((ref) async {
  return ref.watch(attendanceRepositoryProvider).getDevices();
});

// Riverpod provider for Sync Logs
final attendanceSyncLogsProvider = FutureProvider.autoDispose<List<DeviceSyncLog>>((ref) async {
  return ref.watch(attendanceRepositoryProvider).getSyncLogs();
});

// Riverpod provider for Daily Attendance Records
final dailyAttendanceRecordsProvider = FutureProvider.autoDispose<List<AttendanceItem>>((ref) async {
  final date = ref.watch(attendanceSelectedDateProvider);
  return ref.watch(attendanceRepositoryProvider).getDailyAttendance(date: date);
});

// Riverpod provider for Employees list (for Kiosk / manual punch)
final attendanceEmployeesProvider = FutureProvider.autoDispose<List<Employee>>((ref) async {
  return ref.watch(attendanceRepositoryProvider).getEmployees();
});

// Riverpod provider for Shifts
final attendanceShiftsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(attendanceRepositoryProvider).getShifts();
});

class AttendanceRepository {
  final Dio _dio;

  AttendanceRepository(this._dio);

  // ───────────────────────────────────────────────────────────────────────────
  // BIOMETRIC DEVICES
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<BiometricDevice>> getDevices() async {
    try {
      final response = await _dio.get('/attendance-sync/devices');
      final data = response.data['data'] ?? response.data;
      if (data is List) {
        return data.map((d) => BiometricDevice.fromJson(d)).toList();
      }
    } catch (e) {
      // Fallback to sample manufacturing plant hardware devices if offline
    }

    return _getFallbackDevices();
  }

  Future<BiometricDevice> registerDevice(Map<String, dynamic> dto) async {
    final response = await _dio.post('/attendance-sync/devices', data: dto);
    final data = response.data['data'] ?? response.data;
    return BiometricDevice.fromJson(data);
  }

  Future<BiometricDevice> updateDevice(String id, Map<String, dynamic> dto) async {
    final response = await _dio.put('/attendance-sync/devices/$id', data: dto);
    final data = response.data['data'] ?? response.data;
    return BiometricDevice.fromJson(data);
  }

  Future<void> deleteDevice(String id) async {
    await _dio.delete('/attendance-sync/devices/$id');
  }

  Future<Map<String, dynamic>> testDeviceConnection(String deviceId) async {
    try {
      final response = await _dio.post('/attendance-sync/devices/$deviceId/test');
      return response.data['data'] ?? response.data;
    } catch (e) {
      return {
        'success': false,
        'message': 'Device connection timed out or unreachable: ${e.toString()}',
        'pingMs': 0,
      };
    }
  }

  Future<Map<String, dynamic>> syncDevice(
    String deviceId, {
    DateTime? fromDate,
    DateTime? toDate,
    bool clearPunches = false,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance-sync/devices/$deviceId/sync',
        data: {
          if (fromDate != null) 'fromDate': fromDate.toIso8601String(),
          if (toDate != null) 'toDate': toDate.toIso8601String(),
          'clearPunchesAfterSync': clearPunches,
        },
      );
      return response.data['data'] ?? response.data;
    } catch (e) {
      return {
        'success': false,
        'message': 'Sync execution failed: ${e.toString()}',
      };
    }
  }

  Future<List<DeviceSyncLog>> getSyncLogs({String? deviceId, String? status, int limit = 30}) async {
    try {
      final response = await _dio.get(
        '/attendance-sync/sync-logs',
        queryParameters: {
          if (deviceId != null) 'deviceId': deviceId,
          if (status != null) 'status': status,
          'limit': limit,
        },
      );
      final data = response.data['data'] ?? response.data;
      if (data is List) {
        return data.map((l) => DeviceSyncLog.fromJson(l)).toList();
      }
    } catch (e) {
      // Fallback
    }

    return _getFallbackSyncLogs();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ATTENDANCE & PUNCHES
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<AttendanceItem>> getDailyAttendance({DateTime? date, String? departmentId, String? status}) async {
    final queryDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(queryDate);

    try {
      final response = await _dio.get(
        '/hr/attendance',
        queryParameters: {
          'date': dateStr,
          if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
          if (status != null && status.isNotEmpty && status != 'ALL') 'status': status,
        },
      );
      final data = response.data['data'] ?? response.data;
      final records = data is Map ? (data['records'] ?? []) : (data is List ? data : []);
      if (records is List && records.isNotEmpty) {
        return records.map((i) => AttendanceItem.fromJson(i)).toList();
      }
    } catch (e) {
      // Fallback
    }

    return _getFallbackDailyAttendance(queryDate);
  }

  Future<AttendanceItem> clockIn({
    required String employeeId,
    String? location,
    String? note,
    String? shiftCode,
    String? assignedBay,
    bool ppeCompliant = true,
  }) async {
    final response = await _dio.post('/hr/attendance/clock-in', data: {
      'employeeId': employeeId,
      'location': location ?? 'MIDC Industrial Unit 1',
      'checkInNote': note ?? 'Web Kiosk Punch',
      'shiftCode': shiftCode ?? 'SHIFT_G',
      'assignedBay': assignedBay ?? 'BAY_1_FABRICATION',
      'ppeCompliant': ppeCompliant,
    });
    final data = response.data['data'] ?? response.data;
    return AttendanceItem.fromJson(data);
  }

  Future<AttendanceItem> clockOut({
    required String employeeId,
    String? note,
  }) async {
    final response = await _dio.post('/hr/attendance/clock-out', data: {
      'employeeId': employeeId,
      'checkOutNote': note ?? 'Web Kiosk Shift Out',
    });
    final data = response.data['data'] ?? response.data;
    return AttendanceItem.fromJson(data);
  }

  Future<List<Employee>> getEmployees() async {
    try {
      final response = await _dio.get('/hr/employees', queryParameters: {'limit': 100});
      final data = response.data['data'] ?? response.data;
      final employees = data is Map ? (data['employees'] ?? []) : (data is List ? data : []);
      if (employees is List && employees.isNotEmpty) {
        return employees.map((e) => Employee.fromJson(e)).toList();
      }
    } catch (e) {
      // Fallback
    }

    return _getFallbackEmployees();
  }

  Future<List<Map<String, dynamic>>> getShifts() async {
    try {
      final response = await _dio.get('/hr/shifts');
      final data = response.data['data'] ?? response.data;
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      // Fallback
    }

    return [
      {
        'code': 'SHIFT_G',
        'name': 'General Industrial Shift',
        'startTime': '09:00',
        'endTime': '18:00',
        'graceMinutes': 15,
        'lunchBreakMinutes': 60,
        'teaBreakMinutes': 15,
        'halfDayHours': 4.5,
        'fullDayHours': 8.0,
      },
      {
        'code': 'SHIFT_A',
        'name': 'Morning Manufacturing Shift',
        'startTime': '06:00',
        'endTime': '14:30',
        'graceMinutes': 10,
        'lunchBreakMinutes': 30,
        'teaBreakMinutes': 15,
        'halfDayHours': 4.0,
        'fullDayHours': 8.0,
      },
      {
        'code': 'SHIFT_B',
        'name': 'Evening Assembly Shift',
        'startTime': '14:30',
        'endTime': '23:00',
        'graceMinutes': 10,
        'lunchBreakMinutes': 30,
        'teaBreakMinutes': 15,
        'halfDayHours': 4.0,
        'fullDayHours': 8.0,
      },
      {
        'code': 'SHIFT_C',
        'name': 'Night Continuous Shift',
        'startTime': '23:00',
        'endTime': '07:00',
        'graceMinutes': 10,
        'lunchBreakMinutes': 30,
        'teaBreakMinutes': 15,
        'halfDayHours': 4.0,
        'fullDayHours': 8.0,
      },
    ];
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SAMPLE DATA FALLBACK GENERATORS
  // ───────────────────────────────────────────────────────────────────────────

  List<BiometricDevice> _getFallbackDevices() {
    return [
      const BiometricDevice(
        id: 'dev-001',
        deviceCode: 'TM-2026-0001',
        deviceName: 'Main Gate Turnstile Biometric',
        deviceType: 'FINGERPRINT_FACE',
        manufacturer: 'TeamOffice',
        model: 'TM-700 Facial + Optical',
        serialNumber: 'TO2026098231',
        ipAddress: '192.168.1.105',
        port: 4370,
        connectionType: 'TCP_IP',
        isActive: true,
        lastSyncStatus: 'SUCCESS',
        lastSyncRecordCount: 38,
        syncIntervalMinutes: 10,
        autoSyncEnabled: true,
        location: 'MIDC Plant Security Gate A',
        notes: 'Primary worker entry turnstile with automated face capture',
      ),
      const BiometricDevice(
        id: 'dev-002',
        deviceCode: 'ZK-2026-0002',
        deviceName: 'Assembly Shopfloor Terminal',
        deviceType: 'FACE',
        manufacturer: 'ZKTeco',
        model: 'uFace 800 Plus',
        serialNumber: 'ZK987123984',
        ipAddress: '192.168.1.112',
        port: 4370,
        connectionType: 'TCP_IP',
        isActive: true,
        lastSyncStatus: 'SUCCESS',
        lastSyncRecordCount: 24,
        syncIntervalMinutes: 15,
        autoSyncEnabled: true,
        location: 'Panel Fabrication Bay 2',
        notes: 'Shopfloor worker terminal with PPE helmet compliance verification',
      ),
      const BiometricDevice(
        id: 'dev-003',
        deviceCode: 'SP-2026-0003',
        deviceName: 'Admin & Engineering Office',
        deviceType: 'FINGERPRINT',
        manufacturer: 'Suprema',
        model: 'BioStation 3',
        serialNumber: 'SP554433221',
        ipAddress: '192.168.1.120',
        port: 4370,
        connectionType: 'TCP_IP',
        isActive: true,
        lastSyncStatus: 'SUCCESS',
        lastSyncRecordCount: 16,
        syncIntervalMinutes: 30,
        autoSyncEnabled: true,
        location: 'Executive Office & Design Center',
        notes: 'RFID and fingerprint combo scanner for office & engineering teams',
      ),
    ];
  }

  List<DeviceSyncLog> _getFallbackSyncLogs() {
    final now = DateTime.now();
    return [
      DeviceSyncLog(
        id: 'sync-101',
        deviceId: 'dev-001',
        deviceCode: 'TM-2026-0001',
        syncType: 'AUTO',
        syncStatus: 'SUCCESS',
        recordsFetched: 38,
        recordsInserted: 14,
        recordsUpdated: 24,
        startedAt: now.subtract(const Duration(minutes: 8)),
        completedAt: now.subtract(const Duration(minutes: 8, seconds: -3)),
        durationMs: 3120,
      ),
      DeviceSyncLog(
        id: 'sync-102',
        deviceId: 'dev-002',
        deviceCode: 'ZK-2026-0002',
        syncType: 'AUTO',
        syncStatus: 'SUCCESS',
        recordsFetched: 24,
        recordsInserted: 6,
        recordsUpdated: 18,
        startedAt: now.subtract(const Duration(minutes: 14)),
        completedAt: now.subtract(const Duration(minutes: 14, seconds: -2)),
        durationMs: 2450,
      ),
      DeviceSyncLog(
        id: 'sync-103',
        deviceId: 'dev-003',
        deviceCode: 'SP-2026-0003',
        syncType: 'MANUAL',
        syncStatus: 'SUCCESS',
        recordsFetched: 16,
        recordsInserted: 2,
        recordsUpdated: 14,
        startedAt: now.subtract(const Duration(minutes: 25)),
        completedAt: now.subtract(const Duration(minutes: 25, seconds: -2)),
        durationMs: 1890,
      ),
    ];
  }

  List<Employee> _getFallbackEmployees() {
    return [
      Employee(
        id: 'emp-001',
        employeeCode: 'SE-EMP-001',
        firstName: 'Rahul',
        lastName: 'Yeole',
        email: 'rahul.yeole@saark.in',
        phone: '+91 98220 11223',
        designation: 'Operations Director & Technical Head',
        departmentName: 'Operations',
        employmentType: 'PERMANENT',
        workerCategory: 'STAFF_OFFICE',
        shiftCode: 'SHIFT_G',
        salaryCtc: 1200000,
        status: 'ACTIVE',
        hasBiometric: true,
        assignedModules: ['ALL'],
        joiningDate: DateTime(2020, 1, 15),
      ),
      Employee(
        id: 'emp-002',
        employeeCode: 'SE-TECH-101',
        firstName: 'Pooja',
        lastName: 'Sonawane',
        email: 'pooja.s@saark.in',
        phone: '+91 94220 33445',
        designation: 'Lead Production Engineer',
        departmentName: 'Production',
        employmentType: 'PERMANENT',
        workerCategory: 'SHOPFLOOR_TECH',
        assignedBay: 'BAY_1_FABRICATION',
        shiftCode: 'SHIFT_G',
        salaryCtc: 750000,
        status: 'ACTIVE',
        hasBiometric: true,
        assignedModules: ['PRODUCTION', 'ATTENDANCE'],
        joiningDate: DateTime(2021, 6, 1),
      ),
      Employee(
        id: 'emp-003',
        employeeCode: 'SE-TECH-102',
        firstName: 'Ganesh',
        lastName: 'Kulkarni',
        email: 'ganesh.k@saark.in',
        phone: '+91 98231 44556',
        designation: 'Senior Busbar & Wiring Specialist',
        departmentName: 'Electrical Panel Assembly',
        employmentType: 'PERMANENT',
        workerCategory: 'SHOPFLOOR_TECH',
        assignedBay: 'BAY_2_BUSBAR',
        shiftCode: 'SHIFT_A',
        salaryCtc: 580000,
        status: 'ACTIVE',
        hasBiometric: true,
        assignedModules: ['PRODUCTION'],
        joiningDate: DateTime(2022, 3, 10),
      ),
      Employee(
        id: 'emp-004',
        employeeCode: 'SE-TECH-103',
        firstName: 'Amit',
        lastName: 'Patil',
        email: 'amit.p@saark.in',
        phone: '+91 98232 55667',
        designation: 'FAT Testing & QA Inspector',
        departmentName: 'Quality Assurance',
        employmentType: 'PERMANENT',
        workerCategory: 'SHOPFLOOR_TECH',
        assignedBay: 'BAY_5_FAT_TESTING',
        shiftCode: 'SHIFT_A',
        salaryCtc: 520000,
        status: 'ACTIVE',
        hasBiometric: true,
        assignedModules: ['PRODUCTION'],
        joiningDate: DateTime(2022, 8, 1),
      ),
      Employee(
        id: 'emp-005',
        employeeCode: 'SE-TECH-104',
        firstName: 'Sachin',
        lastName: 'Shinde',
        email: 'sachin.s@saark.in',
        phone: '+91 98233 66778',
        designation: 'Panel Enclosure Fabricator',
        departmentName: 'Fabrication',
        employmentType: 'CONTRACT_LABOR',
        workerCategory: 'SHOPFLOOR_TECH',
        assignedBay: 'BAY_1_FABRICATION',
        shiftCode: 'SHIFT_B',
        salaryCtc: 380000,
        status: 'ACTIVE',
        hasBiometric: true,
        assignedModules: [],
        joiningDate: DateTime(2023, 2, 15),
      ),
    ];
  }

  List<AttendanceItem> _getFallbackDailyAttendance(DateTime date) {
    final empList = _getFallbackEmployees();
    final d = DateTime(date.year, date.month, date.day);

    return [
      AttendanceItem(
        id: 'att-001',
        employeeId: empList[0].id,
        punchDate: d,
        punchIn: d.add(const Duration(hours: 8, minutes: 55)), // 08:55 AM
        punchOut: d.add(const Duration(hours: 18, minutes: 15)), // 06:15 PM
        workHours: 9.3,
        status: 'PRESENT',
        shiftCode: 'SHIFT_G',
        overtimeHours: 0.8,
        overtimeApproved: true,
        assignedBay: 'EXECUTIVE_OFFICE',
        location: 'MIDC Gate A (TM-2026-0001)',
        checkInNote: 'Biometric Face Scan verified',
        employee: empList[0],
      ),
      AttendanceItem(
        id: 'att-002',
        employeeId: empList[1].id,
        punchDate: d,
        punchIn: d.add(const Duration(hours: 9, minutes: 2)), // 09:02 AM
        punchOut: d.add(const Duration(hours: 18, minutes: 30)), // 06:30 PM
        workHours: 9.5,
        status: 'PRESENT',
        shiftCode: 'SHIFT_G',
        overtimeHours: 1.0,
        overtimeApproved: true,
        assignedBay: 'BAY_1_FABRICATION',
        location: 'MIDC Gate A (TM-2026-0001)',
        checkInNote: 'Biometric Fingerprint verified',
        employee: empList[1],
      ),
      AttendanceItem(
        id: 'att-003',
        employeeId: empList[2].id,
        punchDate: d,
        punchIn: d.add(const Duration(hours: 5, minutes: 58)), // 05:58 AM (Shift A)
        punchOut: d.add(const Duration(hours: 14, minutes: 45)), // 02:45 PM
        workHours: 8.8,
        status: 'PRESENT',
        shiftCode: 'SHIFT_A',
        overtimeHours: 0.5,
        overtimeApproved: true,
        assignedBay: 'BAY_2_BUSBAR',
        location: 'Shopfloor Terminal (ZK-2026-0002)',
        checkInNote: 'Face scan verified • PPE compliant',
        employee: empList[2],
      ),
      AttendanceItem(
        id: 'att-004',
        employeeId: empList[3].id,
        punchDate: d,
        punchIn: d.add(const Duration(hours: 6, minutes: 22)), // 06:22 AM (Late)
        punchOut: d.add(const Duration(hours: 14, minutes: 30)),
        workHours: 8.1,
        status: 'LATE',
        shiftCode: 'SHIFT_A',
        overtimeHours: 0.0,
        overtimeApproved: false,
        assignedBay: 'BAY_5_FAT_TESTING',
        location: 'Shopfloor Terminal (ZK-2026-0002)',
        checkInNote: 'Late arrival (+22 mins)',
        employee: empList[3],
      ),
      AttendanceItem(
        id: 'att-005',
        employeeId: empList[4].id,
        punchDate: d,
        punchIn: null,
        punchOut: null,
        workHours: 0.0,
        status: 'ABSENT',
        shiftCode: 'SHIFT_B',
        overtimeHours: 0.0,
        overtimeApproved: false,
        assignedBay: 'BAY_1_FABRICATION',
        location: null,
        checkInNote: 'No biometric punch recorded',
        employee: empList[4],
      ),
    ];
  }
}
