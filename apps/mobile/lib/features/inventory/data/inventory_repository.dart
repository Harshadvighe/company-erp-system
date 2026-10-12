import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class InventoryRepository {
  final Dio _dio;
  InventoryRepository(this._dio);

  Future<Map<String, dynamic>> getSummary() async {
    final response = await _dio.get('/inventory/summary');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getWarehouses() async {
    final response = await _dio.get('/inventory/warehouses');
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as List<dynamic>;
    }
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createWarehouse(Map<String, dynamic> data) async {
    final response = await _dio.post('/inventory/warehouses', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStockItems({
    String? warehouseId,
    String? categoryId,
    bool? lowStockOnly,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get('/inventory/stock', queryParameters: {
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (lowStockOnly == true) 'lowStockOnly': 'true',
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adjustStock(Map<String, dynamic> data) async {
    final response = await _dio.post('/inventory/adjust', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transferStock(Map<String, dynamic> data) async {
    final response = await _dio.post('/inventory/transfer', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTransactions({
    String? productId,
    String? warehouseId,
    String? transactionType,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get('/inventory/transactions', queryParameters: {
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
      if (transactionType != null && transactionType.isNotEmpty) 'transactionType': transactionType,
      'page': page,
      'limit': limit,
    });
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InventoryRepository(dio);
});
