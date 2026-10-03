import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/core/storage/app_storage.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(milliseconds: AppConstants.connectionTimeout),
    receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LogInterceptor(
    requestBody: false,
    responseBody: false,
    error: true,
  ));

  return dio;
});

class AuthInterceptor extends Interceptor {
  final Ref ref;

  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.baseUrl = AppConstants.baseUrl;
    final token = await AppStorage.read(AppConstants.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Session expired or invalid — clear storage and reset auth state to force login
      try {
        await ref.read(authProvider.notifier).logout();
      } catch (_) {}
    }
    handler.next(err);
  }
}

/// Parses Dio errors into user-friendly messages
String parseDioError(dynamic e) {
  if (e is! DioException) {
    return e?.toString() ?? 'An unexpected error occurred.';
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'Connection timed out. Please check your network.';
  }
  if (e.type == DioExceptionType.unknown) {
    return 'Network unavailable. Please check your connection.';
  }
  final data = e.response?.data;
  if (data is Map && data['message'] != null) {
    final msg = data['message'];
    if (msg is List) return msg.join(', ');
    return msg.toString();
  }
  switch (e.response?.statusCode) {
    case 400: return 'Invalid request. Please check your input.';
    case 401: return 'Session expired. Please log in again.';
    case 403: return 'You do not have permission to perform this action.';
    case 404: return 'Record not found.';
    case 409: return data?['message']?.toString() ?? 'A duplicate record already exists.';
    case 500: return 'Server error. Please try again later.';
    default: return 'An unexpected error occurred.';
  }
}
