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

  // ─── Leads ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getLeads({String? status, String? priority, String? search, int page = 1}) async {
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

  Future<Map<String, dynamic>> updateLead(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/crm/leads/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLeadStatus(String id, String status) async {
    final response = await _dio.patch('/crm/leads/$id/status', data: {'status': status});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> qualifyLead(String id, Map<String, dynamic> bantData) async {
    final response = await _dio.post('/crm/leads/$id/qualify', data: bantData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> convertLead(String id, Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/leads/$id/convert', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Enquiries ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEnquiries({String? status, String? customerId, String? search, int page = 1}) async {
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

  Future<Map<String, dynamic>> updateEnquiry(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/crm/enquiries/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Opportunities & Pipeline ───────────────────────────────────────────

  Future<Map<String, dynamic>> getOpportunities({String? stage, String? status, String? search, int page = 1}) async {
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

  Future<Map<String, dynamic>> createOpportunity(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/opportunities', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateOpportunityStage(String id, String stage) async {
    final response = await _dio.patch('/crm/opportunities/$id/stage', data: {'stage': stage});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markOpportunityLost(String id, String reason, String? notes) async {
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

  Future<Map<String, dynamic>> scheduleMeeting(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/activities/meeting', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> logSiteVisit(Map<String, dynamic> data) async {
    final response = await _dio.post('/crm/activities/site-visit', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Follow-ups ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getFollowUps({String? status, String? due}) async {
    final response = await _dio.get('/crm/follow-ups', queryParameters: {
      if (status != null) 'status': status,
      if (due != null) 'due': due,
    });
    final data = response.data;
    if (data is Map) return data['data'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<Map<String, dynamic>> completeFollowUp(String id, String? outcome) async {
    final response = await _dio.patch('/crm/follow-ups/$id/complete', data: {
      if (outcome != null) 'outcome': outcome,
    });
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

  Future<List<dynamic>> getCustomerTimeline(String customerId) async {
    final response = await _dio.get('/customers/$customerId/timeline');
    final data = response.data;
    if (data is Map) return data['data'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<Map<String, dynamic>> checkDuplicate(Map<String, dynamic> params) async {
    final response = await _dio.get('/customers/duplicates/check', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mergeCustomers(String primaryId, String duplicateId, String? reason) async {
    final response = await _dio.post('/customers/merge', data: {
      'primaryCustomerId': primaryId,
      'duplicateCustomerId': duplicateId,
      if (reason != null) 'reason': reason,
    });
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
      final leads = (data['data'] as List? ?? []).map((l) => l as Map<String, dynamic>).toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      state = state.copyWith(leads: leads, isLoading: false, total: meta['total'] as int? ?? leads.length);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateStatus(String id, String status) async {
    await _repo.updateLeadStatus(id, status);
    await loadLeads(status: state.filterStatus);
  }
}

final leadListProvider = StateNotifierProvider<LeadListNotifier, LeadListState>((ref) {
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

  EnquiryListState copyWith({List<Map<String, dynamic>>? enquiries, bool? isLoading, String? error, int? total}) {
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
      final enquiries = (data['data'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      state = state.copyWith(enquiries: enquiries, isLoading: false, total: meta['total'] as int? ?? enquiries.length);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final enquiryListProvider = StateNotifierProvider<EnquiryListNotifier, EnquiryListState>((ref) {
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
    await _repo.completeFollowUp(id, outcome);
    await loadFollowUps(status: state.filterStatus);
  }
}

final followUpListProvider = StateNotifierProvider<FollowUpListNotifier, FollowUpListState>((ref) {
  return FollowUpListNotifier(ref.watch(crmRepositoryProvider));
});

// ─── Analytics Provider ─────────────────────────────────────────────────────

final crmAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(crmRepositoryProvider);
  final result = await repo.getAnalytics();
  return result['data'] as Map<String, dynamic>? ?? result;
});

