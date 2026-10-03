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
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
    );
  }
}

class ProjectsRepository {
  final Dio _dio;

  ProjectsRepository(this._dio);

  Future<List<ProjectItem>> getProjects({String? status, String? search}) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _dio.get('/projects', queryParameters: queryParams);
    final data = response.data as List;
    return data.map((json) => ProjectItem.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> getProjectDetail(String id) async {
    final response = await _dio.get('/projects/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<ProjectItem> createProject(Map<String, dynamic> payload) async {
    final response = await _dio.post('/projects', data: payload);
    return ProjectItem.fromJson(response.data);
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.watch(dioProvider));
});

final projectsListProvider = FutureProvider.family<List<ProjectItem>, String?>((ref, search) async {
  return ref.watch(projectsRepositoryProvider).getProjects(search: search);
});
