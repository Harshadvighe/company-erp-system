import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class ProductsRepository {
  final Dio _dio;
  ProductsRepository(this._dio);

  Future<Map<String, dynamic>> getProducts({String? search, String? categoryId, String? type, int page = 1}) async {
    final response = await _dio.get('/products', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'categoryId': categoryId,
      if (type != null) 'type': type,
      'page': page,
      'limit': 25,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('/products/categories/list');
    final data = response.data;
    if (data is Map) return data['data'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<List<dynamic>> getUnits() async {
    final response = await _dio.get('/products/units/list');
    final data = response.data;
    if (data is Map) return data['data'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final response = await _dio.post('/products', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/products/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteProduct(String id) async {
    await _dio.delete('/products/$id');
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.watch(dioProvider));
});

class ProductListState {
  final List<Map<String, dynamic>> products;
  final bool isLoading;
  final String? error;
  final int total;

  const ProductListState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  ProductListState copyWith({List<Map<String, dynamic>>? products, bool? isLoading, String? error, int? total}) {
    return ProductListState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

class ProductListNotifier extends StateNotifier<ProductListState> {
  final ProductsRepository _repo;

  ProductListNotifier(this._repo) : super(const ProductListState());

  Future<void> loadProducts({String? search, String? categoryId, String? type}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getProducts(search: search, categoryId: categoryId, type: type);
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final products = (data['data'] as List? ?? []).map((p) => p as Map<String, dynamic>).toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      state = state.copyWith(products: products, isLoading: false, total: meta['total'] as int? ?? products.length);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final productListProvider = StateNotifierProvider<ProductListNotifier, ProductListState>((ref) {
  return ProductListNotifier(ref.watch(productsRepositoryProvider));
});

final productCategoriesProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  return repo.getCategories();
});

final productUnitsProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  return repo.getUnits();
});
