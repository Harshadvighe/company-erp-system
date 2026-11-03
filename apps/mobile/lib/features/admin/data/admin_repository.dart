import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';

class AdminUserItem {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? phone;
  final String? designation;
  final String status;
  final String? departmentName;
  final List<String> roles;
  final bool faceVerificationEnabled;
  final String faceVerificationStatus;
  final int failedFaceAttempts;
  final DateTime createdAt;

  AdminUserItem({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.phone,
    this.designation,
    required this.status,
    this.departmentName,
    required this.roles,
    this.faceVerificationEnabled = false,
    this.faceVerificationStatus = 'NOT_ENROLLED',
    this.failedFaceAttempts = 0,
    required this.createdAt,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    final rolesList = <String>[];
    if (json['userRoles'] is List) {
      for (final ur in json['userRoles']) {
        if (ur['role']?['name'] != null) {
          rolesList.add(ur['role']['name'].toString());
        } else if (ur['role']?['code'] != null) {
          rolesList.add(ur['role']['code'].toString());
        }
      }
    }
    return AdminUserItem(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'],
      designation: json['designation'],
      status: json['status'] ?? 'ACTIVE',
      departmentName: json['department']?['name'],
      roles: rolesList,
      faceVerificationEnabled: json['faceVerificationEnabled'] == true,
      faceVerificationStatus: json['faceVerificationStatus'] ?? 'NOT_ENROLLED',
      failedFaceAttempts: json['failedFaceAttempts'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AuditLogItem {
  final String id;
  final String? userEmail;
  final String? username;
  final String action;
  final String module;
  final String? entityType;
  final String? entityId;
  final String? details;
  final String? ipAddress;
  final DateTime timestamp;

  AuditLogItem({
    required this.id,
    this.userEmail,
    this.username,
    required this.action,
    required this.module,
    this.entityType,
    this.entityId,
    this.details,
    this.ipAddress,
    required this.timestamp,
  });

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id'] ?? '',
      userEmail: json['userEmail'] ?? json['user']?['email'],
      username: json['user']?['username'] ?? json['user']?['fullName'],
      action: json['action'] ?? 'ACTIVITY',
      module: json['module'] ?? 'SYSTEM',
      entityType: json['entityType'],
      entityId: json['entityId'],
      details: json['details'] ?? '',
      ipAddress: json['ipAddress'] ?? '127.0.0.1',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SecurityPolicy {
  final int passwordMinLength;
  final bool requireSpecialChar;
  final bool requireNumbers;
  final int sessionTimeoutMinutes;
  final int maxFailedLoginsBeforeLockout;
  final String faceRecognitionPolicy;
  final bool ipPlantWhitelistEnabled;
  final String allowedPlantSubnets;
  final String twoFactorAuthMode;
  final String complianceStandard;
  final String lastUpdated;

  SecurityPolicy({
    required this.passwordMinLength,
    required this.requireSpecialChar,
    required this.requireNumbers,
    required this.sessionTimeoutMinutes,
    required this.maxFailedLoginsBeforeLockout,
    required this.faceRecognitionPolicy,
    required this.ipPlantWhitelistEnabled,
    required this.allowedPlantSubnets,
    required this.twoFactorAuthMode,
    required this.complianceStandard,
    required this.lastUpdated,
  });

  factory SecurityPolicy.fromJson(Map<String, dynamic> json) {
    return SecurityPolicy(
      passwordMinLength: json['passwordMinLength'] ?? 8,
      requireSpecialChar: json['requireSpecialChar'] ?? true,
      requireNumbers: json['requireNumbers'] ?? true,
      sessionTimeoutMinutes: json['sessionTimeoutMinutes'] ?? 60,
      maxFailedLoginsBeforeLockout: json['maxFailedLoginsBeforeLockout'] ?? 5,
      faceRecognitionPolicy: json['faceRecognitionPolicy'] ?? 'OPTIONAL',
      ipPlantWhitelistEnabled: json['ipPlantWhitelistEnabled'] ?? false,
      allowedPlantSubnets: json['allowedPlantSubnets'] ?? '192.168.1.0/24, 10.0.0.0/16, 127.0.0.1',
      twoFactorAuthMode: json['twoFactorAuthMode'] ?? 'ROLE_BASED',
      complianceStandard: json['complianceStandard'] ?? 'IEC 62443 / ISO 27001',
      lastUpdated: json['lastUpdated'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'passwordMinLength': passwordMinLength,
    'requireSpecialChar': requireSpecialChar,
    'requireNumbers': requireNumbers,
    'sessionTimeoutMinutes': sessionTimeoutMinutes,
    'maxFailedLoginsBeforeLockout': maxFailedLoginsBeforeLockout,
    'faceRecognitionPolicy': faceRecognitionPolicy,
    'ipPlantWhitelistEnabled': ipPlantWhitelistEnabled,
    'allowedPlantSubnets': allowedPlantSubnets,
    'twoFactorAuthMode': twoFactorAuthMode,
    'complianceStandard': complianceStandard,
  };
}

class ActiveSessionItem {
  final String id;
  final String userId;
  final String username;
  final String fullName;
  final String email;
  final String department;
  final List<String> roles;
  final String ipAddress;
  final String clientType;
  final String loginTime;
  final String? logoutTime;
  final String lastHeartbeat;
  final int? durationSeconds;
  final String durationFormatted;
  final String status;
  final bool faceVerified;
  final String loginMethod;
  final String? logoutReason;

  ActiveSessionItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
    required this.department,
    required this.roles,
    required this.ipAddress,
    required this.clientType,
    required this.loginTime,
    this.logoutTime,
    required this.lastHeartbeat,
    this.durationSeconds,
    this.durationFormatted = 'Active',
    required this.status,
    required this.faceVerified,
    this.loginMethod = 'CREDENTIALS_AND_BIOMETRIC_2FA',
    this.logoutReason,
  });

  factory ActiveSessionItem.fromJson(Map<String, dynamic> json) {
    return ActiveSessionItem(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      department: json['department'] ?? 'Operations',
      roles: (json['roles'] as List? ?? []).map((r) => r.toString()).toList(),
      ipAddress: json['ipAddress'] ?? '127.0.0.1',
      clientType: json['clientType'] ?? 'Web / Chrome',
      loginTime: json['loginTime'] ?? '',
      logoutTime: json['logoutTime'],
      lastHeartbeat: json['lastHeartbeat'] ?? '',
      durationSeconds: json['durationSeconds'],
      durationFormatted: json['durationFormatted'] ?? (json['status'] == 'ACTIVE' ? 'Live' : 'Completed'),
      status: json['status'] ?? 'ACTIVE',
      faceVerified: json['faceVerified'] == true,
      loginMethod: json['loginMethod'] ?? 'CREDENTIALS_AND_BIOMETRIC_2FA',
      logoutReason: json['logoutReason'],
    );
  }
}

class SystemHealthInfo {
  final String status;
  final String timestamp;
  final String dbEngine;
  final String dbStatus;
  final int dbLatencyMs;
  final int activePoolConnections;
  final String nodeVersion;
  final String platform;
  final String uptimeFormatted;
  final int memoryRssMb;
  final int heapUsedMb;
  final int totalUsers;
  final int activeUsers;
  final int totalEmployees;
  final int totalAuditLogs;
  final String securityStandard;
  final String biometricEngine;
  final String smtpEngine;

  SystemHealthInfo({
    required this.status,
    required this.timestamp,
    required this.dbEngine,
    required this.dbStatus,
    required this.dbLatencyMs,
    required this.activePoolConnections,
    required this.nodeVersion,
    required this.platform,
    required this.uptimeFormatted,
    required this.memoryRssMb,
    required this.heapUsedMb,
    required this.totalUsers,
    required this.activeUsers,
    required this.totalEmployees,
    required this.totalAuditLogs,
    required this.securityStandard,
    required this.biometricEngine,
    required this.smtpEngine,
  });

  factory SystemHealthInfo.fromJson(Map<String, dynamic> json) {
    final db = json['database'] as Map<String, dynamic>? ?? {};
    final rt = json['runtime'] as Map<String, dynamic>? ?? {};
    final em = json['entityMetrics'] as Map<String, dynamic>? ?? {};
    final sc = json['security'] as Map<String, dynamic>? ?? {};

    return SystemHealthInfo(
      status: json['status'] ?? 'HEALTHY',
      timestamp: json['timestamp'] ?? '',
      dbEngine: db['engine'] ?? 'PostgreSQL',
      dbStatus: db['status'] ?? 'CONNECTED',
      dbLatencyMs: db['latencyMs'] ?? 0,
      activePoolConnections: db['activePoolConnections'] ?? 1,
      nodeVersion: rt['nodeVersion'] ?? 'v20',
      platform: rt['platform'] ?? 'win32',
      uptimeFormatted: rt['uptimeFormatted'] ?? '1h',
      memoryRssMb: rt['memoryRssMb'] ?? 0,
      heapUsedMb: rt['heapUsedMb'] ?? 0,
      totalUsers: em['totalUsers'] ?? 0,
      activeUsers: em['activeUsers'] ?? 0,
      totalEmployees: em['totalEmployees'] ?? 0,
      totalAuditLogs: em['totalAuditLogs'] ?? 0,
      securityStandard: sc['standard'] ?? 'IEC 62443',
      biometricEngine: sc['biometricEngine'] ?? 'Active',
      smtpEngine: sc['smtpEngine'] ?? 'Active',
    );
  }
}


class RoleItem {
  final String id;
  final String name;
  final String code;
  final String? description;

  RoleItem({
    required this.id,
    required this.name,
    required this.code,
    this.description,
  });

  factory RoleItem.fromJson(Map<String, dynamic> json) {
    return RoleItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'],
    );
  }
}

class DepartmentItem {
  final String id;
  final String name;
  final String code;

  DepartmentItem({
    required this.id,
    required this.name,
    required this.code,
  });

  factory DepartmentItem.fromJson(Map<String, dynamic> json) {
    return DepartmentItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
    );
  }
}

class DesignationItem {
  final String id;
  final String name;
  final String code;

  DesignationItem({
    required this.id,
    required this.name,
    required this.code,
  });

  factory DesignationItem.fromJson(Map<String, dynamic> json) {
    return DesignationItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
    );
  }
}

class AdminRepository {
  final Dio _dio;

  AdminRepository(this._dio);

  dynamic _payload(dynamic response) {
    var payload = response;
    for (var i = 0; i < 3 && payload is Map && payload.containsKey('data'); i++) {
      payload = payload['data'];
    }
    return payload;
  }

  Future<List<Map<String, dynamic>>> getOrganizationStructure() async {
    final response = await _dio.get('/admin/organization');
    final payload = _payload(response.data);
    if (payload is! List) {
      throw const FormatException('Unexpected organization response');
    }
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> updateDepartmentHead(String departmentId, String? staffId) async {
    await _dio.put('/admin/departments/$departmentId/head', data: {
      'staffId': staffId,
    });
  }

  Future<Map<String, dynamic>> saveTeam(
    Map<String, dynamic> payload, {
    String? teamId,
  }) async {
    final response = teamId == null
        ? await _dio.post('/admin/teams', data: payload)
        : await _dio.put('/admin/teams/$teamId', data: payload);
    final data = _payload(response.data);
    if (data is! Map) {
      throw const FormatException('Unexpected saved team response');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteTeam(String teamId) async {
    await _dio.delete('/admin/teams/$teamId');
  }

  Future<List<Employee>> getEmployeeRequests({
    String? departmentId,
    String? status,
    String? search,
  }) async {
    final response = await _dio.get('/admin/employee-requests', queryParameters: {
      if (departmentId != null && departmentId.isNotEmpty && departmentId != 'ALL') 'departmentId': departmentId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final list = response.data['data'] as List? ?? (response.data as List? ?? []);
    return list.map((i) => Employee.fromJson(i)).toList();
  }

  Future<Map<String, dynamic>> approveEmployeeRequest(
    String employeeId, {
    required String username,
    required String password,
    String? departmentId,
    String? designationId,
    List<String>? roleIds,
    bool sendWelcomeEmail = true,
  }) async {
    final response = await _dio.post('/admin/employee-requests/$employeeId/approve', data: {
      'username': username,
      'password': password,
      if (departmentId != null) 'departmentId': departmentId,
      if (designationId != null) 'designationId': designationId,
      if (roleIds != null && roleIds.isNotEmpty) 'roleIds': roleIds,
      'sendWelcomeEmail': sendWelcomeEmail,
    });
    return response.data['data'] ?? response.data;
  }

  Future<Map<String, dynamic>> resendWelcomeEmail(String employeeId, {String? password}) async {
    final response = await _dio.post('/admin/employee-requests//resend-email', data: {
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return response.data['data'] ?? response.data;
  }

  Future<Map<String, dynamic>> rejectEmployeeRequest(String employeeId, {String? reason}) async {
    final response = await _dio.post('/admin/employee-requests/$employeeId/reject', data: {
      'reason': reason ?? 'Rejected by Administrator',
    });
    return response.data['data'] ?? response.data;
  }

  Future<DepartmentItem> createDepartment({required String name, String? code}) async {
    final cleanCode = (code != null && code.trim().isNotEmpty)
        ? code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_')
        : name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
    final response = await _dio.post('/admin/departments', data: {
      'name': name.trim(),
      'code': cleanCode.length > 20 ? cleanCode.substring(0, 20) : cleanCode,
    });
    final data = response.data['data'] ?? response.data;
    return DepartmentItem.fromJson(data);
  }

  Future<List<DepartmentItem>> getDepartments() async {
    final response = await _dio.get('/admin/departments');
    final list = response.data['data'] as List? ?? (response.data as List? ?? []);
    return list.map((i) => DepartmentItem.fromJson(i)).toList();
  }

  Future<List<DesignationItem>> getDesignations() async {
    final response = await _dio.get('/admin/designations');
    final list = response.data['data'] as List? ?? (response.data as List? ?? []);
    return list.map((i) => DesignationItem.fromJson(i)).toList();
  }

  Future<List<RoleItem>> getRoles() async {
    final response = await _dio.get('/admin/roles');
    final list = response.data['data'] as List? ?? (response.data as List? ?? []);
    return list.map((i) => RoleItem.fromJson(i)).toList();
  }

  Future<List<AdminUserItem>> getUsers({String? search, String? departmentId}) async {
    final response = await _dio.get('/admin/users', queryParameters: {
      if (search != null) 'search': search,
      if (departmentId != null) 'departmentId': departmentId,
    });
    final list = response.data['data'] as List? ?? (response.data as List? ?? []);
    return list.map((i) => AdminUserItem.fromJson(i)).toList();
  }

  Future<void> toggleUserStatus(String userId) async {
    await _dio.patch('/admin/users/$userId/toggle-status');
  }

  Future<void> unlockUser(String userId) async {
    await _dio.patch('/admin/users/$userId/unlock');
  }

  Future<String> resetUserPassword(String userId, {String? newPassword}) async {
    final response = await _dio.patch('/admin/users/$userId/reset-password', data: {
      if (newPassword != null) 'password': newPassword,
    });
    final data = response.data['data'] ?? response.data;
    return data['tempPassword']?.toString() ?? 'Saark@2026';
  }

  Future<void> toggleUserFaceVerification(String userId, {bool? enabled}) async {
    await _dio.patch('/admin/users/$userId/toggle-face', data: {
      if (enabled != null) 'enabled': enabled,
    });
  }

  Future<List<AuditLogItem>> getAuditLogs({
    String? module,
    String? action,
    String? search,
    int limit = 50,
  }) async {
    final response = await _dio.get('/admin/audit-logs', queryParameters: {
      if (module != null && module != 'ALL') 'module': module,
      if (action != null && action != 'ALL') 'action': action,
      if (search != null && search.isNotEmpty) 'search': search,
      'limit': limit,
    });
    final payload = response.data['data'] ?? response.data;
    final list = payload is Map && payload['data'] is List
        ? payload['data'] as List
        : (payload is List ? payload : []);
    return list.map((i) => AuditLogItem.fromJson(i)).toList();
  }

  Future<SecurityPolicy> getSecurityPolicy() async {
    final response = await _dio.get('/admin/security/policy');
    final payload = response.data['data'] ?? response.data;
    return SecurityPolicy.fromJson(payload);
  }

  Future<SecurityPolicy> updateSecurityPolicy(Map<String, dynamic> policy) async {
    final response = await _dio.put('/admin/security/policy', data: policy);
    final payload = response.data['data'] ?? response.data;
    return SecurityPolicy.fromJson(payload);
  }

  Future<List<ActiveSessionItem>> getActiveSessions() async {
    final response = await _dio.get('/admin/security/sessions');
    final payload = response.data['data'] ?? response.data;
    final list = payload is List ? payload : [];
    return list.map((i) => ActiveSessionItem.fromJson(i)).toList();
  }

  Future<void> revokeSession(String sessionId) async {
    await _dio.delete('/admin/security/sessions/$sessionId');
  }

  Future<Map<String, dynamic>> getSessionHistory({
    String? search,
    String? status,
    int limit = 30,
    int offset = 0,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final response = await _dio.get('/admin/security/session-history', queryParameters: queryParams);
    final payload = response.data['data'] ?? response.data;
    final list = payload is Map && payload['data'] is List
        ? (payload['data'] as List).map((i) => ActiveSessionItem.fromJson(i)).toList()
        : (payload is List ? payload.map((i) => ActiveSessionItem.fromJson(i)).toList() : <ActiveSessionItem>[]);
    final total = payload is Map && payload['total'] != null ? payload['total'] as int : list.length;
    final summary = payload is Map && payload['summary'] != null ? payload['summary'] as Map<String, dynamic> : <String, dynamic>{};

    return {
      'data': list,
      'total': total,
      'summary': summary,
    };
  }

  Future<SystemHealthInfo> getSystemHealth() async {
    final response = await _dio.get('/admin/system/health');
    final payload = response.data['data'] ?? response.data;
    return SystemHealthInfo.fromJson(payload);
  }

  Future<Map<String, dynamic>> triggerSystemBackup() async {
    final response = await _dio.post('/admin/system/backup');
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload);
  }

  // ─── POSTGRESQL LIVE DATABASE EXPLORER ────────────────────────────────────

  Future<Map<String, dynamic>> verifyDatabaseAuth(String username, String password) async {
    try {
      final response = await _dio.post(
        '/database/auth',
        data: {'username': username.trim(), 'password': password.trim()},
      );
      final payload = response.data['data'] ?? response.data;
      if (payload is Map<String, dynamic>) {
        return payload;
      }
      return Map<String, dynamic>.from(payload);
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map && d['message'] != null) {
          return {'success': false, 'message': d['message'].toString()};
        }
      }
      return {'success': false, 'message': 'Authentication failed: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getDatabaseTelemetry() async {
    final response = await _dio.get('/database/telemetry');
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload);
  }

  Future<Map<String, dynamic>> getDatabaseTables() async {
    final response = await _dio.get('/database/tables');
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload);
  }

  Future<Map<String, dynamic>> getDatabaseTableData(
    String tableName, {
    int page = 1,
    int limit = 25,
    String? search,
    String? sortBy,
    String? sortOrder,
    bool maskSensitive = true,
    String? dbaToken,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (sortBy != null && sortBy.trim().isNotEmpty) 'sortBy': sortBy.trim(),
      if (sortOrder != null && sortOrder.trim().isNotEmpty) 'sortOrder': sortOrder.trim(),
      'maskSensitive': maskSensitive,
    };
    final response = await _dio.get(
      '/database/table/$tableName',
      queryParameters: queryParams,
      options: dbaToken != null ? Options(headers: {'x-dba-token': dbaToken}) : null,
    );
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload);
  }

  Future<Map<String, dynamic>> executeDatabaseQuery(
    String query, {
    int limit = 50,
    String? dbaToken,
  }) async {
    final response = await _dio.post(
      '/database/query',
      data: {'query': query.trim(), 'limit': limit},
      options: dbaToken != null ? Options(headers: {'x-dba-token': dbaToken}) : null,
    );
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload);
  }

  Future<Map<String, dynamic>> insertDatabaseTableRecord(
    String tableName,
    Map<String, dynamic> data, {
    String? dbaToken,
  }) async {
    final response = await _dio.post(
      '/database/table/$tableName/entry',
      data: data,
      options: dbaToken != null ? Options(headers: {'x-dba-token': dbaToken}) : null,
    );
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload is Map ? payload : {'result': payload});
  }

  Future<Map<String, dynamic>> updateDatabaseTableRecord(
    String tableName, {
    required String primaryKeyCol,
    required dynamic primaryKeyValue,
    required Map<String, dynamic> data,
    String? dbaToken,
  }) async {
    final response = await _dio.put(
      '/database/table/$tableName/entry',
      data: {
        'primaryKeyCol': primaryKeyCol,
        'primaryKeyValue': primaryKeyValue,
        'data': data,
      },
      options: dbaToken != null ? Options(headers: {'x-dba-token': dbaToken}) : null,
    );
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload is Map ? payload : {'result': payload});
  }

  Future<Map<String, dynamic>> deleteDatabaseTableRecord(
    String tableName, {
    required String primaryKeyCol,
    required dynamic primaryKeyValue,
    String? dbaToken,
  }) async {
    final response = await _dio.delete(
      '/database/table/$tableName/entry',
      data: {
        'primaryKeyCol': primaryKeyCol,
        'primaryKeyValue': primaryKeyValue,
      },
      options: dbaToken != null ? Options(headers: {'x-dba-token': dbaToken}) : null,
    );
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload is Map ? payload : {'result': payload});
  }

  Future<Map<String, dynamic>> bulkInsertDatabaseTableRecords(
    String tableName,
    List<Map<String, dynamic>> records, {
    String? dbaToken,
  }) async {
    final response = await _dio.post(
      '/database/table/$tableName/bulk-insert',
      data: {'records': records},
      options: dbaToken != null ? Options(headers: {'x-dba-token': dbaToken}) : null,
    );
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload is Map ? payload : {'result': payload});
  }

  Future<Map<String, dynamic>> changeDatabasePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
    String? dbaToken,
  }) async {
    final response = await _dio.post(
      '/database/change-password',
      data: {
        'username': username,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      options: dbaToken != null ? Options(headers: {'x-dba-token': dbaToken}) : null,
    );
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload is Map ? payload : {'result': payload});
  }

  Future<Map<String, dynamic>> triggerDatabaseBackup({String? dbaToken}) async {
    final response = await _dio.post(
      '/database/backup',
      options: dbaToken != null ? Options(headers: {'x-dba-token': dbaToken}) : null,
    );
    final payload = response.data['data'] ?? response.data;
    return Map<String, dynamic>.from(payload is Map ? payload : {'result': payload});
  }
}




final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});
