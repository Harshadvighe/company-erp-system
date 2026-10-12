import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class StaffMember {
  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String? mobile;
  final String? profilePhoto;
  final String? departmentName;
  final String? designationName;
  final String? reportingManagerName;
  final String status;
  final String? location;
  final String? notes;
  final bool hasUserAccount;

  const StaffMember({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    this.mobile,
    this.profilePhoto,
    this.departmentName,
    this.designationName,
    this.reportingManagerName,
    required this.status,
    this.location,
    this.notes,
    required this.hasUserAccount,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      mobile: json['mobile'],
      profilePhoto: json['profilePhoto'],
      departmentName: _relationValue(json['department'], 'name') ??
          json['departmentName']?.toString(),
      designationName: _relationValue(json['designation'], 'name') ??
          json['designationName']?.toString(),
      reportingManagerName:
          _relationValue(json['reportingManager'], 'fullName'),
      status: json['status'] ?? 'ACTIVE',
      location: json['location'],
      notes: json['notes'],
      hasUserAccount: json['user'] != null,
    );
  }

  static String? _relationValue(dynamic relation, String key) {
    if (relation is Map) return relation[key]?.toString();
    if (relation is List && relation.isNotEmpty && relation.first is Map) {
      return relation.first[key]?.toString();
    }
    if (relation is String) return relation;
    return null;
  }
}

class StaffRepository {
  final Dio _dio;

  StaffRepository(this._dio);

  Future<List<StaffMember>> getStaffList({
    String? search,
    String? departmentId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (departmentId != null) queryParams['departmentId'] = departmentId;
    if (status != null) queryParams['status'] = status;

    final response = await _dio.get('/staff', queryParameters: queryParams);
    dynamic payload = response.data;
    for (var depth = 0; depth < 3 && payload is Map; depth++) {
      if (payload['data'] is List) {
        payload = payload['data'];
        break;
      }
      if (payload['data'] is Map) {
        payload = payload['data'];
        continue;
      }
      break;
    }
    if (payload is! List) {
      throw const FormatException('Unexpected staff list response');
    }
    return payload
        .whereType<Map>()
        .map((json) => StaffMember.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<StaffMember> createStaff(Map<String, dynamic> payload) async {
    final response = await _dio.post('/staff', data: payload);
    return StaffMember.fromJson(response.data);
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final response = await _dio.get('/admin/departments');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getDesignations() async {
    final response = await _dio.get('/admin/designations');
    return List<Map<String, dynamic>>.from(response.data);
  }
}

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(ref.watch(dioProvider));
});

final staffListProvider =
    FutureProvider.family<List<StaffMember>, String?>((ref, search) async {
  return ref.watch(staffRepositoryProvider).getStaffList(search: search);
});
