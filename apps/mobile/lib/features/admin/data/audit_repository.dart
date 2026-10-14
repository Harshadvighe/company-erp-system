import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';

class AuditLogItem {
  final String id;
  final String? userId;
  final String? userEmail;
  final String? userName;
  final String action;
  final String module;
  final String? entityType;
  final String? entityId;
  final String outcome;
  final String? requestId;
  final String? ipAddress;
  final DateTime timestamp;
  final List<String> changedFields;
  final dynamic before;
  final dynamic after;
  final String? reason;
  final List<String> actorRoles;
  final Map<String, dynamic>? details;

  AuditLogItem({
    required this.id,
    this.userId,
    this.userEmail,
    this.userName,
    required this.action,
    required this.module,
    this.entityType,
    this.entityId,
    required this.outcome,
    this.requestId,
    this.ipAddress,
    required this.timestamp,
    required this.changedFields,
    this.before,
    this.after,
    this.reason,
    required this.actorRoles,
    this.details,
  });

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? detailsMap;
    if (json['details'] is Map) {
      detailsMap = Map<String, dynamic>.from(json['details']);
    } else if (json['details'] is String) {
      try {
        // In case details was passed as raw json string
        detailsMap = Map<String, dynamic>.from(
          json['details'].isNotEmpty ? Map<String, dynamic>.from(json['details']) : {},
        );
      } catch (_) {}
    }

    final actor = detailsMap?['actor'] as Map<String, dynamic>?;
    final outcomeVal = detailsMap?['outcome']?.toString() ??
        (json['action'] == 'AUTHORIZATION_DENIED' ? 'DENIED' : 'SUCCESS');

    final changedFieldsList = <String>[];
    if (detailsMap?['changedFields'] is List) {
      for (final f in detailsMap!['changedFields']) {
        changedFieldsList.add(f.toString());
      }
    }

    final rolesList = <String>[];
    if (actor?['roles'] is List) {
      for (final r in actor!['roles']) {
        rolesList.add(r.toString());
      }
    }

    return AuditLogItem(
      id: json['id'] ?? '',
      userId: actor?['userId'] ?? json['userId'],
      userEmail: actor?['userEmail'] ?? json['userEmail'] ?? json['user']?['email'],
      userName: actor?['fullName'] ?? json['user']?['fullName'],
      action: json['action'] ?? 'UNKNOWN',
      module: json['module'] ?? 'SYSTEM',
      entityType: json['entityType'],
      entityId: json['entityId'],
      outcome: outcomeVal,
      requestId: detailsMap?['requestId']?.toString(),
      ipAddress: json['ipAddress'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      changedFields: changedFieldsList,
      before: detailsMap?['before'],
      after: detailsMap?['after'],
      reason: detailsMap?['reason']?.toString(),
      actorRoles: rolesList,
      details: detailsMap,
    );
  }
}

class AuditLogsResult {
  final List<AuditLogItem> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  AuditLogsResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory AuditLogsResult.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return AuditLogsResult(
      items: list.map((i) => AuditLogItem.fromJson(Map<String, dynamic>.from(i))).toList(),
      page: meta['page'] is int ? meta['page'] : int.tryParse(meta['page']?.toString() ?? '1') ?? 1,
      limit: meta['limit'] is int ? meta['limit'] : int.tryParse(meta['limit']?.toString() ?? '25') ?? 25,
      total: meta['total'] is int ? meta['total'] : int.tryParse(meta['total']?.toString() ?? '0') ?? 0,
      totalPages: meta['totalPages'] is int
          ? meta['totalPages']
          : int.tryParse(meta['totalPages']?.toString() ?? '1') ?? 1,
    );
  }
}

class AuditRepository {
  final Dio _dio;

  AuditRepository(this._dio);

  Future<AuditLogsResult> getAuditLogs({
    int page = 1,
    int limit = 25,
    String? module,
    String? action,
    String? outcome,
    String? search,
    String? entityId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (module != null && module.isNotEmpty && module != 'ALL') 'module': module,
      if (action != null && action.isNotEmpty && action != 'ALL') 'action': action,
      if (outcome != null && outcome.isNotEmpty && outcome != 'ALL') 'outcome': outcome,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (entityId != null && entityId.trim().isNotEmpty) 'entityId': entityId.trim(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };

    final response = await _dio.get('/audit-logs', queryParameters: query);
    final data = response.data is Map ? response.data : {'data': response.data};
    return AuditLogsResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<AuditLogItem> getAuditLogDetail(String id) async {
    final response = await _dio.get('/audit-logs/$id');
    final data = response.data is Map ? response.data : {};
    return AuditLogItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> exportAuditLogsCsv({
    String? module,
    String? action,
    String? outcome,
    String? search,
    String? entityId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, dynamic>{
      if (module != null && module.isNotEmpty && module != 'ALL') 'module': module,
      if (action != null && action.isNotEmpty && action != 'ALL') 'action': action,
      if (outcome != null && outcome.isNotEmpty && outcome != 'ALL') 'outcome': outcome,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (entityId != null && entityId.trim().isNotEmpty) 'entityId': entityId.trim(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };

    final response = await _dio.get(
      '/audit-logs/export',
      queryParameters: query,
      options: Options(responseType: ResponseType.plain),
    );

    final csvContent = response.data.toString();
    final filename = 'saark_audit_logs_${DateTime.now().toIso8601String().sliceSafe(0, 10)}.csv';
    downloadExcelFile(csvContent, filename);
  }
}

extension on String {
  String sliceSafe(int start, int end) {
    if (length <= start) return this;
    if (length <= end) return substring(start);
    return substring(start, end);
  }
}

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepository(ref.watch(dioProvider));
});
