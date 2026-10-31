import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class TaskItem {
  final String id;
  final String taskNumber;
  final String title;
  final String? description;
  final String? projectId;
  final String? projectName;
  final String? projectNumber;
  final String? milestoneId;
  final String? milestoneTitle;
  final String? departmentId;
  final String? departmentName;
  final String? teamId;
  final String? teamName;
  final String? assigneeName;
  final String? assigneeEmployeeId;
  final String? assigneeDesignation;
  final String? assigneeDepartment;
  final String? assigneeStaffId;
  final String? assignedByStaffId;
  final String? assignerName;
  final String? assignerEmployeeId;
  final String? assignerDesignation;
  final String? createdByStaffId;
  final String? creatorName;
  final String? creatorDesignation;
  final String assignmentScope;
  final String? teamRole;
  final bool isTaskAssigner;
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
    this.projectId,
    this.projectName,
    this.projectNumber,
    this.milestoneId,
    this.milestoneTitle,
    this.departmentId,
    this.departmentName,
    this.teamId,
    this.teamName,
    this.assigneeName,
    this.assigneeEmployeeId,
    this.assigneeDesignation,
    this.assigneeDepartment,
    this.assigneeStaffId,
    this.assignedByStaffId,
    this.assignerName,
    this.assignerEmployeeId,
    this.assignerDesignation,
    this.createdByStaffId,
    this.creatorName,
    this.creatorDesignation,
    this.assignmentScope = '',
    this.teamRole,
    this.isTaskAssigner = false,
    required this.priority,
    required this.status,
    this.dueDate,
    required this.estimatedHours,
    required this.actualHours,
    required this.progress,
    required this.createdAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final project = json['project'] is Map ? json['project'] as Map : const {};
    final milestone = json['milestone'] is Map ? json['milestone'] as Map : const {};
    final team = json['team'] is Map ? json['team'] as Map : const {};
    final department =
        json['department'] is Map ? json['department'] as Map : const {};
    final assignee =
        json['assignee'] is Map ? json['assignee'] as Map : const {};
    final assigner =
        json['assigner'] is Map ? json['assigner'] as Map : const {};
    final creator =
        json['creator'] is Map ? json['creator'] as Map : const {};

    return TaskItem(
      id: json['id'] ?? '',
      taskNumber: json['taskNumber'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      projectId: json['projectId']?.toString() ?? project['id']?.toString(),
      projectName: project['name']?.toString(),
      projectNumber: project['projectNumber']?.toString(),
      milestoneId: json['milestoneId']?.toString() ?? milestone['id']?.toString(),
      milestoneTitle: milestone['title']?.toString(),
      departmentId: json['departmentId']?.toString() ?? department['id']?.toString(),
      departmentName: department['name']?.toString(),
      teamId: json['teamId']?.toString() ?? team['id']?.toString(),
      teamName: team['name']?.toString(),
      assigneeName: assignee['fullName']?.toString(),
      assigneeEmployeeId: assignee['employeeId']?.toString(),
      assigneeDesignation: (assignee['designation'] is Map)
          ? assignee['designation']['name']?.toString()
          : null,
      assigneeDepartment: (assignee['department'] is Map)
          ? assignee['department']['name']?.toString()
          : null,
      assigneeStaffId: json['assigneeStaffId']?.toString(),
      assignedByStaffId: json['assignedByStaffId']?.toString(),
      assignerName: assigner['fullName']?.toString(),
      assignerEmployeeId: assigner['employeeId']?.toString(),
      assignerDesignation: (assigner['designation'] is Map)
          ? assigner['designation']['name']?.toString()
          : null,
      createdByStaffId: json['createdByStaffId']?.toString(),
      creatorName: creator['fullName']?.toString(),
      creatorDesignation: (creator['designation'] is Map)
          ? creator['designation']['name']?.toString()
          : null,
      assignmentScope: json['assignmentScope']?.toString() ?? 'DIRECT',
      teamRole: json['teamRole']?.toString(),
      isTaskAssigner: json['isTaskAssigner'] == true,
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'CREATED',
      dueDate:
          json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
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

  dynamic _payload(dynamic response) {
    var payload = response;
    for (var i = 0;
        i < 3 && payload is Map && payload.containsKey('data');
        i++) {
      payload = payload['data'];
    }
    return payload;
  }

  Future<List<TaskItem>> getTasks({
    String? status,
    String? priority,
    String? projectId,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (priority != null && priority != 'ALL') {
      queryParams['priority'] = priority;
    }
    if (projectId != null) queryParams['projectId'] = projectId;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _dio.get('/tasks', queryParameters: queryParams);
    final data = _payload(response.data);
    if (data is! List) throw const FormatException('Unexpected tasks response');
    return data
        .whereType<Map>()
        .map((json) => TaskItem.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<List<TaskItem>> getMyTasks() async {
    final response = await _dio.get('/tasks/my-tasks');
    final data = _payload(response.data);
    if (data is! List) {
      throw const FormatException('Unexpected my tasks response');
    }
    return data
        .whereType<Map>()
        .map((json) => TaskItem.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyLedTeams() async {
    final response = await _dio.get('/tasks/my-led-teams');
    final data = _payload(response.data);
    if (data is! List) {
      throw const FormatException('Unexpected led teams response');
    }
    return data
        .whereType<Map>()
        .map((team) => Map<String, dynamic>.from(team))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAssignableStaff() async {
    final response = await _dio.get('/tasks/assignees');
    final data = _payload(response.data);
    if (data is! List) {
      throw const FormatException('Unexpected assignable staff response');
    }
    return data
        .whereType<Map>()
        .map((staff) => Map<String, dynamic>.from(staff))
        .toList();
  }

  Future<Map<String, dynamic>> getTaskDetail(String id) async {
    final response = await _dio.get('/tasks/$id');
    final data = _payload(response.data);
    if (data is! Map) {
      throw const FormatException('Unexpected task detail response');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<TaskItem> createTask(Map<String, dynamic> payload) async {
    final response = await _dio.post('/tasks', data: payload);
    final data = _payload(response.data);
    if (data is! Map) {
      throw const FormatException('Unexpected created task response');
    }
    return TaskItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> updateTaskStatus(String id, String status,
      {String? notes}) async {
    await _dio.patch('/tasks/$id/status', data: {
      'status': status,
      if (notes != null) 'notes': notes,
    });
  }

  Future<void> updateTaskProgress(String id, int progress) async {
    await _dio.patch('/tasks/$id/progress', data: {'progress': progress});
  }

  Future<void> addComment(String id, String comment) async {
    await _dio.post('/tasks/$id/comments', data: {'comment': comment});
  }

  Future<TaskItem> updateTask(String id, Map<String, dynamic> payload) async {
    final response = await _dio.put('/tasks/$id', data: payload);
    final data = _payload(response.data);
    if (data is! Map) {
      throw const FormatException('Unexpected update task response');
    }
    return TaskItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> logWorkHours(String id, double hours, {String? notes}) async {
    await _dio.post('/tasks/$id/log-hours', data: {
      'hours': hours,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  Future<void> deleteTask(String id) async {
    await _dio.delete('/tasks/$id');
  }

  Future<Map<String, dynamic>> getTaskStats() async {
    try {
      final response = await _dio.get('/tasks/stats/summary');
      final data = _payload(response.data);
      if (data is! Map) return {};
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getFormOptions() async {
    try {
      final response = await _dio.get('/tasks/form-options');
      final data = _payload(response.data);
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return {};
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(dioProvider));
});

final allTasksProvider =
    FutureProvider.family<List<TaskItem>, String?>((ref, status) async {
  return ref.watch(tasksRepositoryProvider).getTasks(status: status);
});

final myTasksProvider = FutureProvider<List<TaskItem>>((ref) async {
  return ref.watch(tasksRepositoryProvider).getMyTasks();
});

final taskStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(tasksRepositoryProvider).getTaskStats();
});

final taskFormOptionsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(tasksRepositoryProvider).getFormOptions();
});
