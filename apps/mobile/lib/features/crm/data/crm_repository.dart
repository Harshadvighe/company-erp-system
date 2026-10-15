import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class CrmRepository {
  final Dio _dio;
  CrmRepository(this._dio);

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _dio.get('/crm/dashboard');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> globalSearch(String query) async {
    final response = await _dio.get('/crm/search', queryParameters: {'q': query});
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return (data['data'] is Map<String, dynamic>) ? data['data'] as Map<String, dynamic> : data;
    }
    return {};
  }

  // ─── Leads ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getLeads(
      {String? status, String? priority, String? search, int page = 1}) async {
    final response = await _dio.get('/crm/leads', queryParameters: {
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': 25,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLead(String id) async {
    final response = await _dio.get('/crm/leads/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLead(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/leads', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLead(
      String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/crm/leads/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLeadStatus(
      String id, String status) async {
    final response =
        await _dio.patch('/crm/leads/$id/status', data: {'status': status});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> qualifyLead(
      String id, Map<String, dynamic> bantData) async {
    final response = await _dio.post('/crm/leads/$id/qualify', data: bantData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> convertLead(
      String id, Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/leads/$id/convert', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Enquiries ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEnquiries(
      {String? status,
      String? customerId,
      String? search,
      int page = 1}) async {
    final response = await _dio.get('/crm/enquiries', queryParameters: {
      if (status != null) 'status': status,
      if (customerId != null) 'customerId': customerId,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': 25,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEnquiry(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/enquiries', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEnquiry(
      String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/crm/enquiries/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Opportunities & Pipeline ───────────────────────────────────────────

  Future<Map<String, dynamic>> getOpportunities(
      {String? stage, String? status, String? search, int page = 1}) async {
    final response = await _dio.get('/crm/opportunities', queryParameters: {
      if (stage != null) 'stage': stage,
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': 50,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPipeline() async {
    final response = await _dio.get('/crm/pipeline');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createOpportunity(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/opportunities', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateOpportunityStage(
      String id, String stage) async {
    final response = await _dio
        .patch('/crm/opportunities/$id/stage', data: {'stage': stage});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markOpportunityLost(
      String id, String reason, String? notes) async {
    final response = await _dio.post('/crm/opportunities/$id/lost', data: {
      'reason': reason,
      if (notes != null) 'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  // ─── Activities, Calls, Meetings & Site Visits ──────────────────────────

  Future<Map<String, dynamic>> logCall(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/activities/call', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scheduleMeeting(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/activities/meeting', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> logSiteVisit(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/activities/site-visit', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Follow-ups ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getFollowUps({
    String? status,
    String? due,
    String? customerId,
  }) async {
    final response = await _dio.get('/crm/follow-ups', queryParameters: {
      if (status != null) 'status': status,
      if (due != null) 'due': due,
      if (customerId != null) 'customerId': customerId,
    });
    final data = response.data;
    if (data is Map) return data['data'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<Map<String, dynamic>> getFollowUpCompanies({
    String? search,
    String? status,
    String? assignedStaffId,
    String? customerId,
    int page = 1,
    int limit = 50,
  }) async {
    final response =
        await _dio.get('/crm/follow-ups/companies', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status != 'ALL') 'status': status,
      if (assignedStaffId != null) 'assignedStaffId': assignedStaffId,
      if (customerId != null) 'customerId': customerId,
      'page': page,
      'limit': limit,
    });
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return {'data': data, 'meta': <String, dynamic>{}};
    throw const FormatException('Unexpected company follow-up response');
  }

  Future<Map<String, dynamic>> completeFollowUp(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.patch('/crm/follow-ups/$id/complete', data: {
      ...data,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Phase 3: Atomically resolve a follow-up, record activity outcome,
  /// link uploaded media, and optionally schedule next follow-up with idempotency key.
  Future<Map<String, dynamic>> resolveFollowUp(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post('/crm/follow-ups/$id/resolve', data: data);
    final resData = response.data;
    if (resData is Map && resData['data'] is Map) {
      return Map<String, dynamic>.from(resData['data'] as Map);
    }
    if (resData is Map) {
      return Map<String, dynamic>.from(resData);
    }
    throw const FormatException('Unexpected resolve follow-up response');
  }

  /// Phase 3: Fetch automated callback date/time suggestion (11:00 AM IST next working day)
  Future<Map<String, dynamic>> getCallbackSuggestion({DateTime? date}) async {
    final response = await _dio.get(
      '/crm/follow-ups/callback-suggestion',
      queryParameters: {
        if (date != null) 'date': date.toIso8601String(),
      },
    );
    final resData = response.data;
    if (resData is Map && resData['data'] is Map) {
      return Map<String, dynamic>.from(resData['data'] as Map);
    }
    if (resData is Map) {
      return Map<String, dynamic>.from(resData);
    }
    throw const FormatException('Unexpected callback suggestion response');
  }

  /// Phase 3: Upload multi-file CRM attachments (audio, images, docs, videos)
  Future<List<Map<String, dynamic>>> uploadCrmAttachments({
    required List<({String fileName, List<int> bytes})> files,
    String? customerId,
    String? followUpId,
    String? activityId,
    String? sourceCategory,
    String? description,
  }) async {
    if (files.isEmpty) return [];
    final formData = FormData();
    if (customerId != null && customerId.isNotEmpty) {
      formData.fields.add(MapEntry('customerId', customerId));
    }
    if (followUpId != null && followUpId.isNotEmpty) {
      formData.fields.add(MapEntry('followUpId', followUpId));
    }
    if (activityId != null && activityId.isNotEmpty) {
      formData.fields.add(MapEntry('activityId', activityId));
    }
    if (sourceCategory != null && sourceCategory.isNotEmpty) {
      formData.fields.add(MapEntry('sourceCategory', sourceCategory));
    }
    if (description != null && description.isNotEmpty) {
      formData.fields.add(MapEntry('description', description));
    }

    for (final file in files) {
      formData.files.add(MapEntry(
        'files',
        MultipartFile.fromBytes(file.bytes, filename: file.fileName),
      ));
    }

    final response = await _dio.post('/crm/attachments/upload', data: formData);
    final resData = response.data;
    if (resData is Map && resData['data'] is List) {
      return (resData['data'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (resData is List) {
      return resData
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createFollowUp(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/follow-ups', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPendingFollowUps() async {
    return getFollowUps(status: 'PENDING');
  }

  // ─── Analytics & Customer 360 ───────────────────────────────────────────

  Future<Map<String, dynamic>> getAnalytics() async {
    final response = await _dio.get('/crm/analytics');
    return response.data as Map<String, dynamic>;
  }

  /// Phase 1/3: Unified company activity timeline with attachments & media
  Future<List<dynamic>> getCompanyTimeline(String companyId) async {
    final response = await _dio.get('/crm/companies/$companyId/timeline');
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return data['data'] as List;
    }
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> getCustomerTimeline(String customerId) async {
    try {
      final res = await getCompanyTimeline(customerId);
      if (res.isNotEmpty) return res;
    } catch (_) {}
    final response = await _dio.get('/customers/$customerId/timeline');
    final data = response.data;
    if (data is Map) return data['data'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<Map<String, dynamic>> checkDuplicate(
      Map<String, dynamic> params) async {
    final response =
        await _dio.get('/customers/duplicates/check', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mergeCustomers(
      String primaryId, String duplicateId, String? reason) async {
    final response = await _dio.post('/customers/merge', data: {
      'primaryCustomerId': primaryId,
      'duplicateCustomerId': duplicateId,
      if (reason != null) 'reason': reason,
    });
    return response.data as Map<String, dynamic>;
  }

  // ─── Meetings Management ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMeetings({
    String? customerId,
    String? status,
    String? hostStaffId,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get('/crm/meetings', queryParameters: {
      if (customerId != null) 'customerId': customerId,
      if (status != null) 'status': status,
      if (hostStaffId != null) 'hostStaffId': hostStaffId,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createMeeting(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/meetings', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> respondMeeting(
    String id, {
    required String action,
    String? newStartTime,
    String? newEndTime,
    String? reason,
  }) async {
    final response = await _dio.patch('/crm/meetings/$id/respond', data: {
      'action': action,
      if (newStartTime != null) 'newStartTime': newStartTime,
      if (newEndTime != null) 'newEndTime': newEndTime,
      if (reason != null) 'reason': reason,
    });
    return response.data as Map<String, dynamic>;
  }

  // ─── Calls Management ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCalls({
    String? customerId,
    String? callOutcome,
    String? callType,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get('/crm/calls', queryParameters: {
      if (customerId != null) 'customerId': customerId,
      if (callOutcome != null) 'callOutcome': callOutcome,
      if (callType != null) 'callType': callType,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCall(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/calls', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadCallRecording(
      String callId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/crm/calls/$callId/recordings', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Site Visits Management ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getSiteVisits({
    String? customerId,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get('/crm/site-visits', queryParameters: {
      if (customerId != null) 'customerId': customerId,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSiteVisit(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/site-visits', data: data);
    return response.data as Map<String, dynamic>;
  }
}

final crmRepositoryProvider = Provider<CrmRepository>((ref) {
  return CrmRepository(ref.watch(dioProvider));
});

// ─── Dashboard Provider ─────────────────────────────────────────────────────

final crmDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(crmRepositoryProvider);
  final result = await repo.getDashboard();
  return result['data'] as Map<String, dynamic>? ?? result;
});

// ─── Leads State ─────────────────────────────────────────────────────────────

class LeadListState {
  final List<Map<String, dynamic>> leads;
  final bool isLoading;
  final String? error;
  final int total;
  final String? filterStatus;

  const LeadListState({
    this.leads = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.filterStatus,
  });

  LeadListState copyWith({
    List<Map<String, dynamic>>? leads,
    bool? isLoading,
    String? error,
    int? total,
    String? filterStatus,
  }) {
    return LeadListState(
      leads: leads ?? this.leads,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

class LeadListNotifier extends StateNotifier<LeadListState> {
  final CrmRepository _repo;
  LeadListNotifier(this._repo) : super(const LeadListState());

  Future<void> loadLeads({String? status, String? search}) async {
    state = state.copyWith(isLoading: true, error: null, filterStatus: status);
    try {
      final result = await _repo.getLeads(status: status, search: search);
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final leads = (data['data'] as List? ?? [])
          .map((l) => l as Map<String, dynamic>)
          .toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      state = state.copyWith(
          leads: leads,
          isLoading: false,
          total: meta['total'] as int? ?? leads.length);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateStatus(String id, String status) async {
    await _repo.updateLeadStatus(id, status);
    await loadLeads(status: state.filterStatus);
  }
}

final leadListProvider =
    StateNotifierProvider<LeadListNotifier, LeadListState>((ref) {
  return LeadListNotifier(ref.watch(crmRepositoryProvider));
});

// ─── Enquiries State ─────────────────────────────────────────────────────────

class EnquiryListState {
  final List<Map<String, dynamic>> enquiries;
  final bool isLoading;
  final String? error;
  final int total;

  const EnquiryListState({
    this.enquiries = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  EnquiryListState copyWith(
      {List<Map<String, dynamic>>? enquiries,
      bool? isLoading,
      String? error,
      int? total}) {
    return EnquiryListState(
      enquiries: enquiries ?? this.enquiries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

class EnquiryListNotifier extends StateNotifier<EnquiryListState> {
  final CrmRepository _repo;
  EnquiryListNotifier(this._repo) : super(const EnquiryListState());

  Future<void> loadEnquiries({String? status, String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getEnquiries(status: status, search: search);
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final enquiries = (data['data'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      state = state.copyWith(
          enquiries: enquiries,
          isLoading: false,
          total: meta['total'] as int? ?? enquiries.length);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final enquiryListProvider =
    StateNotifierProvider<EnquiryListNotifier, EnquiryListState>((ref) {
  return EnquiryListNotifier(ref.watch(crmRepositoryProvider));
});

// ─── Pipeline Provider ───────────────────────────────────────────────────────

final crmPipelineProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(crmRepositoryProvider);
  final result = await repo.getPipeline();
  return result['data'] as Map<String, dynamic>? ?? result;
});

// ─── Follow-Ups State ────────────────────────────────────────────────────────

class FollowUpListState {
  final List<dynamic> followUps;
  final bool isLoading;
  final String? error;
  final String? filterStatus;

  const FollowUpListState({
    this.followUps = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus,
  });

  FollowUpListState copyWith({
    List<dynamic>? followUps,
    bool? isLoading,
    String? error,
    String? filterStatus,
  }) {
    return FollowUpListState(
      followUps: followUps ?? this.followUps,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

class FollowUpListNotifier extends StateNotifier<FollowUpListState> {
  final CrmRepository _repo;
  FollowUpListNotifier(this._repo) : super(const FollowUpListState());

  Future<void> loadFollowUps({String? status, String? due}) async {
    state = state.copyWith(isLoading: true, error: null, filterStatus: status);
    try {
      final items = await _repo.getFollowUps(status: status, due: due);
      state = state.copyWith(followUps: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> complete(String id, String? outcome) async {
    await _repo.completeFollowUp(id, {
      if (outcome != null) 'outcome': outcome,
      if (outcome != null) 'discussion': outcome,
    });
    await loadFollowUps(status: state.filterStatus);
  }

  /// Phase 3: Atomically resolve follow-up with outcome, callback suggestion,
  /// media attachment ids, and idempotency key.
  Future<Map<String, dynamic>> resolve(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await _repo.resolveFollowUp(id, data);
    await loadFollowUps(status: state.filterStatus);
    return result;
  }
}

final followUpListProvider =
    StateNotifierProvider<FollowUpListNotifier, FollowUpListState>((ref) {
  return FollowUpListNotifier(ref.watch(crmRepositoryProvider));
});

// ─── Analytics Provider ─────────────────────────────────────────────────────

final crmAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(crmRepositoryProvider);
  final result = await repo.getAnalytics();
  return result['data'] as Map<String, dynamic>? ?? result;
});
