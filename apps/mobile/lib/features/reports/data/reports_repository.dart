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

  Future<String> exportExecutiveSummaryCsv() async {
    final response = await _dio.get(
      '/reports/summary/export',
      options: Options(responseType: ResponseType.plain),
    );
    return response.data.toString();
  }

  Future<String> exportGstJson({String? month, int? year}) async {
    final response = await _dio.get(
      '/reports/gst/export',
      queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
        'format': 'json',
      },
      options: Options(responseType: ResponseType.plain),
    );
    return response.data.toString();
  }

  Future<String> exportGstCsv({String? month, int? year}) async {
    final response = await _dio.get(
      '/reports/gst/export',
      queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
        'format': 'csv',
      },
      options: Options(responseType: ResponseType.plain),
    );
    return response.data.toString();
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReportsRepository(dio);
});
