import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';

// ─── Auth Repository ─────────────────────────────────────────────────────────

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<Map<String, dynamic>> login(String emailOrUsername, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'emailOrUsername': emailOrUsername,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentProfile() async {
    final response = await _dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

// ─── Auth Service (use-case layer) ────────────────────────────────────────────

class AuthService {
  final AuthRepository _repo;
  final AuthNotifier _authNotifier;

  AuthService(this._repo, this._authNotifier);

  Future<void> login(String emailOrUsername, String password) async {
    _authNotifier.setLoading(true);
    _authNotifier.setError(null);

    final response = await _repo.login(emailOrUsername, password);
    final data = response['data'] ?? response;

    final userMap = data['user'] as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>;

    final user = AuthUser.fromJson(userMap);
    await _authNotifier.setUser(
      user,
      tokens['accessToken'] as String,
      tokens['refreshToken'] as String,
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(authRepositoryProvider),
    ref.read(authProvider.notifier),
  );
});
