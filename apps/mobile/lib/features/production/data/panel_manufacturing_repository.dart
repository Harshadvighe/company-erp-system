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
