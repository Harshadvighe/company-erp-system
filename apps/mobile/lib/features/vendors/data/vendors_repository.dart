import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class VendorsRepository {
  final Dio _dio;
  VendorsRepository(this._dio);

  Future<Map<String, dynamic>> getVendors({String? search, String? status, int page = 1}) async {
    final response = await _dio.get('/vendors', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null) 'status': status,
      'page': page,
      'limit': 25,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getVendor(String id) async {
    final response = await _dio.get('/vendors/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createVendor(Map<String, dynamic> data) async {
    final response = await _dio.post('/vendors', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateVendor(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/vendors/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteVendor(String id) async {
    await _dio.delete('/vendors/$id');
  }
}

final vendorsRepositoryProvider = Provider<VendorsRepository>((ref) {
  return VendorsRepository(ref.watch(dioProvider));
});

class VendorListState {
  final List<Map<String, dynamic>> vendors;
  final bool isLoading;
  final String? error;
  final int total;

  const VendorListState({
    this.vendors = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  VendorListState copyWith({
    List<Map<String, dynamic>>? vendors,
    bool? isLoading,
    String? error,
    int? total,
  }) {
    return VendorListState(
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

class VendorListNotifier extends StateNotifier<VendorListState> {
  final VendorsRepository _repo;

  VendorListNotifier(this._repo) : super(const VendorListState());

  Future<void> loadVendors({String? search, int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getVendors(search: search, page: page);
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final vendors = (data['data'] as List? ?? [])
          .map((v) => v as Map<String, dynamic>)
          .toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};

      state = state.copyWith(
        vendors: vendors,
        isLoading: false,
        total: meta['total'] as int? ?? vendors.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final vendorListProvider = StateNotifierProvider<VendorListNotifier, VendorListState>((ref) {
  return VendorListNotifier(ref.watch(vendorsRepositoryProvider));
});
