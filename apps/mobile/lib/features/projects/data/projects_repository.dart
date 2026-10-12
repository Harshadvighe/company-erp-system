import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class ProjectItem {
  final String id;
  final String projectNumber;
  final String name;
  final String? description;
  final String? customerName;
  final String projectType;
  final String? projectManagerName;
  final String? projectManagerStaffId;
  final String priority;
  final double budget;
  final String status;
  final String health;
  final int memberCount;
  final int milestoneCount;
  final int taskCount;
  final DateTime? startDate;
  final DateTime? endDate;

  const ProjectItem({
    required this.id,
    required this.projectNumber,
    required this.name,
    this.description,
    this.customerName,
    required this.projectType,
    this.projectManagerName,
    this.projectManagerStaffId,
    required this.priority,
    required this.budget,
    required this.status,
    required this.health,
    required this.memberCount,
    required this.milestoneCount,
    required this.taskCount,
    this.startDate,
    this.endDate,
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    return ProjectItem(
      id: json['id'] ?? '',
      projectNumber: json['projectNumber'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      customerName: json['customer']?['companyName'],
      projectType: json['projectType'] ?? 'Customer Project',
      projectManagerName: json['projectManager']?['fullName'],
      projectManagerStaffId: json['projectManagerStaffId'],
      priority: json['priority'] ?? 'MEDIUM',
      budget: (json['budget'] ?? 0).toDouble(),
      status: json['status'] ?? 'PLANNING',
      health: json['health'] ?? 'ON_TRACK',
      memberCount: json['_count']?['members'] ?? 0,
      milestoneCount: json['_count']?['milestones'] ?? 0,
      taskCount: json['_count']?['tasks'] ?? 0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate:
          json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
    );
  }
}

class ProjectsRepository {
  final Dio _dio;

  ProjectsRepository(this._dio);

  dynamic _unwrap(dynamic value) {
    var payload = value;
    for (var depth = 0;
        depth < 3 && payload is Map && payload.containsKey('data');
        depth++) {
      payload = payload['data'];
    }
    return payload;
  }

  Future<List<ProjectItem>> getProjects(
      {String? status, String? search}) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _dio.get('/projects', queryParameters: queryParams);
    final data = _unwrap(response.data);
    if (data is! List) {
      throw const FormatException('Unexpected projects list response');
    }
    return data
        .whereType<Map>()
        .map((json) => ProjectItem.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<Map<String, dynamic>> getProjectDetail(String id) async {
    final response = await _dio.get('/projects/$id');
    final data = _unwrap(response.data);
    if (data is! Map) {
      throw const FormatException('Unexpected project detail response');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<ProjectItem> createProject(Map<String, dynamic> payload) async {
    final response = await _dio.post('/projects', data: payload);
    final data = _unwrap(response.data);
    if (data is! Map) {
      throw const FormatException('Unexpected created project response');
    }
    return ProjectItem.fromJson(Map<String, dynamic>.from(data));
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.watch(dioProvider));
});

final projectsListProvider =
    FutureProvider.family<List<ProjectItem>, String?>((ref, search) async {
  return ref.watch(projectsRepositoryProvider).getProjects(search: search);
});
