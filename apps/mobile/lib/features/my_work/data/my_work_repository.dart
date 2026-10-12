import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class MyWorkRepository {
  final Dio _dio;

  MyWorkRepository(this._dio);

  Future<Map<String, dynamic>> getSummary() async {
    final response = await _dio.get('/my-work/summary');
    dynamic payload = response.data;
    for (var depth = 0;
        depth < 3 && payload is Map && payload.containsKey('data');
        depth++) {
      payload = payload['data'];
    }
    if (payload is! Map) {
      throw const FormatException('Unexpected my work summary response');
    }
    return Map<String, dynamic>.from(payload);
  }
}

final myWorkRepositoryProvider = Provider<MyWorkRepository>((ref) {
  return MyWorkRepository(ref.watch(dioProvider));
});

final myWorkSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(myWorkRepositoryProvider).getSummary();
});
