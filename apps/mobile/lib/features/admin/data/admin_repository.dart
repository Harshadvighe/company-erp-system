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
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
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
    String? password,
    String? departmentId,
    String? designationId,
    List<String>? roleIds,
  }) async {
    final response = await _dio.post('/admin/employee-requests/$employeeId/approve', data: {
      'username': username,
      if (password != null && password.isNotEmpty) 'password': password,
      if (departmentId != null) 'departmentId': departmentId,
      if (designationId != null) 'designationId': designationId,
      if (roleIds != null && roleIds.isNotEmpty) 'roleIds': roleIds,
    });
    return response.data['data'] ?? response.data;
  }

  Future<Map<String, dynamic>> rejectEmployeeRequest(String employeeId, {String? reason}) async {
    final response = await _dio.post('/admin/employee-requests/$employeeId/reject', data: {
      'reason': reason ?? 'Rejected by Administrator',
    });
    return response.data['data'] ?? response.data;
  }

  Future<List<DepartmentItem>> getDepartments() async {
    final response = await _dio.get('/admin/departments');
    final list = response.data['data'] as List? ?? (response.data as List? ?? []);
    return list.map((i) => DepartmentItem.fromJson(i)).toList();
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

  // ─── EMPLOYEE ACCESS MANAGEMENT (PHASE 2 & 3) ─────────────────────────────

  Future<Map<String, dynamic>> getEmployeesAccessList({
    int page = 1,
    int limit = 25,
    String? search,
    String? departmentId,
  }) async {
    final response = await _dio.get('/admin/employees/access', queryParameters: {
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (departmentId != null && departmentId.isNotEmpty && departmentId != 'ALL') 'departmentId': departmentId,
    });
    final payload = _payload(response.data);
    return Map<String, dynamic>.from(payload is Map ? payload : response.data);
  }

  Future<Map<String, dynamic>> getEmployeeAccessDetail(String employeeId) async {
    final response = await _dio.get('/admin/employees/$employeeId/access');
    final payload = _payload(response.data);
    return Map<String, dynamic>.from(payload is Map ? payload : response.data);
  }

  Future<Map<String, dynamic>> resetEmployeePassword(
    String employeeId, {
    required String newPassword,
  }) async {
    final response = await _dio.post('/admin/employee-requests/$employeeId/reset-password', data: {
      'newPassword': newPassword,
    });
    return response.data['data'] ?? response.data;
  }

  Future<Map<String, dynamic>> updateEmployeeAccess(
    String employeeId, {
    required List<Map<String, dynamic>> overrides,
    String? reason,
  }) async {
    final response = await _dio.put('/admin/employees/$employeeId/access', data: {
      'overrides': overrides,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    final payload = _payload(response.data);
    return Map<String, dynamic>.from(payload is Map ? payload : response.data);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});

