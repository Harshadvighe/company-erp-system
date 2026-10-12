import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class ReportsRepository {
  final Dio _dio;
  ReportsRepository(this._dio);

  Future<Map<String, dynamic>> getExecutiveSummary() async {
    final response = await _dio.get('/reports/summary');
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSalesReport() async {
    final response = await _dio.get('/reports/sales');
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInventoryReport() async {
    final response = await _dio.get('/reports/inventory');
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProductionReport() async {
    final response = await _dio.get('/reports/production');
    final data = response.data;
    if (data is Map<String, dynamic> && data['data'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReportsRepository(dio);
});
