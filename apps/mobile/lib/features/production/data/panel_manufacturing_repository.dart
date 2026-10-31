import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

// ─── Panel Specification Repository ──────────────────────────────────────────

class PanelManufacturingRepository {
  final Dio _dio;

  PanelManufacturingRepository(this._dio);

  Future<List<Map<String, dynamic>>> getSpecs() async {
    final response = await _dio.get('/panel-manufacturing/specs');
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> getSpec(String id) async {
    final response = await _dio.get('/panel-manufacturing/specs/$id');
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSpec(Map<String, dynamic> specData) async {
    final response = await _dio.post('/panel-manufacturing/specs', data: specData);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> calculateBoosterPump(Map<String, dynamic> input) async {
    final response = await _dio.post('/panel-manufacturing/booster-pump/calculate', data: input);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> saveBoosterPumpSpec(Map<String, dynamic> input) async {
    final response = await _dio.post('/panel-manufacturing/booster-pump/save-spec', data: input);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> quickAddCustomer({
    required String companyName,
    required double percentage,
  }) async {
    final response = await _dio.post(
      '/panel-manufacturing/booster-pump/quick-customer',
      data: {
        'companyName': companyName,
        'percentage': percentage,
      },
    );
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  // ─── Production Batches ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBatches() async {
    final response = await _dio.get('/panel-manufacturing/batches');
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> getBatch(String id) async {
    final response = await _dio.get('/panel-manufacturing/batches/$id');
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBatch(Map<String, dynamic> batchData) async {
    final response = await _dio.post('/panel-manufacturing/batches', data: batchData);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBatchStatus(String id, String status) async {
    final response = await _dio.patch('/panel-manufacturing/batches/$id/status', data: {'status': status});
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBatchMaterials(String id, List<Map<String, dynamic>> materials) async {
    final response = await _dio.put('/panel-manufacturing/batches/$id/materials', data: {'materials': materials});
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  // ─── Product Testing Records ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTestingRecords({String? batchId}) async {
    final response = await _dio.get(
      '/panel-manufacturing/testing-records',
      queryParameters: batchId != null ? {'batchId': batchId} : null,
    );
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getTestedOkProducts() async {
    final response = await _dio.get('/panel-manufacturing/testing-records/tested-ok');
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> createTestingRecord(Map<String, dynamic> testData) async {
    final response = await _dio.post('/panel-manufacturing/testing-records', data: testData);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  // ─── Dispatch Logs ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDispatchLogs() async {
    final response = await _dio.get('/panel-manufacturing/dispatch-logs');
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> createDispatch(Map<String, dynamic> dispatchData) async {
    final response = await _dio.post('/panel-manufacturing/dispatch-logs', data: dispatchData);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  // ─── Panel Assembly & QC ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAssemblyJobs() async {
    final response = await _dio.get('/panel-manufacturing/assembly-jobs');
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> createAssemblyJob(Map<String, dynamic> jobData) async {
    final response = await _dio.post('/panel-manufacturing/assembly-jobs', data: jobData);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signoffPanelQc(Map<String, dynamic> qcData) async {
    final response = await _dio.post('/panel-manufacturing/panel-qc-signoff', data: qcData);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}

final panelRepositoryProvider = Provider<PanelManufacturingRepository>((ref) {
  return PanelManufacturingRepository(ref.watch(dioProvider));
});

// ─── State Management ────────────────────────────────────────────────────────

class PanelListState {
  final List<Map<String, dynamic>> specs;
  final bool isLoading;
  final String? error;

  const PanelListState({
    this.specs = const [],
    this.isLoading = false,
    this.error,
  });

  PanelListState copyWith({
    List<Map<String, dynamic>>? specs,
    bool? isLoading,
    String? error,
  }) {
    return PanelListState(
      specs: specs ?? this.specs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PanelListNotifier extends StateNotifier<PanelListState> {
  final PanelManufacturingRepository _repo;

  PanelListNotifier(this._repo) : super(const PanelListState());

  Future<void> loadSpecs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final specs = await _repo.getSpecs();
      state = state.copyWith(specs: specs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createSpec(Map<String, dynamic> data) async {
    try {
      final newSpec = await _repo.createSpec(data);
      state = state.copyWith(specs: [newSpec, ...state.specs]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final panelListProvider =
    StateNotifierProvider<PanelListNotifier, PanelListState>((ref) {
  return PanelListNotifier(ref.watch(panelRepositoryProvider));
});

final panelDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(panelRepositoryProvider).getSpec(id);
});

final panelManufacturingRepositoryProvider = panelRepositoryProvider;

