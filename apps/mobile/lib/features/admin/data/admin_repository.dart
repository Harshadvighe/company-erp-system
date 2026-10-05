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
  }) async {
    final response = await _dio.post('/admin/employee-requests/$employeeId/approve', data: {
      'username': username,
      'password': password,
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
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});
