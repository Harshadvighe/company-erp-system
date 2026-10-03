import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class TaskItem {
  final String id;
  final String taskNumber;
  final String title;
  final String? description;
  final String? projectName;
  final String? projectNumber;
  final String? assigneeName;
  final String? assigneeStaffId;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final double estimatedHours;
  final double actualHours;
  final int progress;
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    required this.taskNumber,
    required this.title,
    this.description,
    this.projectName,
    this.projectNumber,
    this.assigneeName,
    this.assigneeStaffId,
    required this.priority,
    required this.status,
    this.dueDate,
    required this.estimatedHours,
    required this.actualHours,
    required this.progress,
    required this.createdAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] ?? '',
      taskNumber: json['taskNumber'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      projectName: json['project']?['name'],
      projectNumber: json['project']?['projectNumber'],
      assigneeName: json['assignee']?['fullName'],
      assigneeStaffId: json['assigneeStaffId'],
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'CREATED',
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      estimatedHours: (json['estimatedHours'] ?? 0).toDouble(),
      actualHours: (json['actualHours'] ?? 0).toDouble(),
      progress: json['progress'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class TasksRepository {
  final Dio _dio;

  TasksRepository(this._dio);

  Future<List<TaskItem>> getTasks({
    String? status,
    String? priority,
    String? projectId,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (priority != null && priority != 'ALL') queryParams['priority'] = priority;
    if (projectId != null) queryParams['projectId'] = projectId;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _dio.get('/tasks', queryParameters: queryParams);
    final data = response.data as List;
    return data.map((json) => TaskItem.fromJson(json)).toList();
  }

  Future<List<TaskItem>> getMyTasks() async {
    final response = await _dio.get('/tasks/my-tasks');
    final data = response.data as List;
    return data.map((json) => TaskItem.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> getTaskDetail(String id) async {
    final response = await _dio.get('/tasks/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<TaskItem> createTask(Map<String, dynamic> payload) async {
    final response = await _dio.post('/tasks', data: payload);
    return TaskItem.fromJson(response.data);
  }

  Future<void> updateTaskStatus(String id, String status, {String? notes}) async {
    await _dio.patch('/tasks/$id/status', data: {
      'status': status,
      if (notes != null) 'notes': notes,
    });
  }

  Future<void> addComment(String id, String comment) async {
    await _dio.post('/tasks/$id/comments', data: {'comment': comment});
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(dioProvider));
});

final allTasksProvider = FutureProvider.family<List<TaskItem>, String?>((ref, status) async {
  return ref.watch(tasksRepositoryProvider).getTasks(status: status);
});

final myTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  return ref.watch(tasksRepositoryProvider).getMyTasks();
});
