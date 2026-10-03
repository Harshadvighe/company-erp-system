import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class MyWorkRepository {
  final Dio _dio;

  MyWorkRepository(this._dio);

  Future<Map<String, dynamic>> getSummary() async {
    final response = await _dio.get('/my-work/summary');
    return response.data as Map<String, dynamic>;
  }
}

final myWorkRepositoryProvider = Provider<MyWorkRepository>((ref) {
  return MyWorkRepository(ref.watch(dioProvider));
});

final myWorkSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(myWorkRepositoryProvider).getSummary();
});
