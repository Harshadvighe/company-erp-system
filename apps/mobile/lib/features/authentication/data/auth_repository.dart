import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';

// ─── Login Result Model ───────────────────────────────────────────────────────

class LoginResult {
  final bool requiresFaceVerification;
  final String? faceSessionToken;
  final Map<String, dynamic>? userMap;
  final String? message;
  final bool isSuccess;
  final String? targetRoute;
  final String? targetModule;

  LoginResult({
    this.requiresFaceVerification = false,
    this.faceSessionToken,
    this.userMap,
    this.message,
    this.isSuccess = false,
    this.targetRoute,
    this.targetModule,
  });
}

// ─── Auth Repository ─────────────────────────────────────────────────────────

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    dynamic faceData,
    String? livePhotoBase64,
  }) async {
    final payload = <String, dynamic>{
      'username': username,
      'emailOrUsername': username,
      'password': password,
    };
    final biometric = faceData ?? livePhotoBase64;
    if (biometric != null) {
      payload['face_data'] = biometric;
      if (biometric is String && biometric.isNotEmpty) {
        payload['livePhotoBase64'] = biometric;
      }
    }
    final response = await _dio.post('/auth/login', data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loginStrict2FA(
    String username,
    String password,
    dynamic faceData,
  ) async {
    final payload = <String, dynamic>{
      'username': username,
      'emailOrUsername': username,
      'password': password,
      'face_data': faceData,
    };
    if (faceData is String && faceData.isNotEmpty) {
      payload['livePhotoBase64'] = faceData;
    }
    final response = await _dio.post('/auth/login-2fa', data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyFace(String faceSessionToken, String faceImage) async {
    final response = await _dio.post('/auth/face-verify', data: {
      'faceSessionToken': faceSessionToken,
      'faceImage': faceImage,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentProfile() async {
    final response = await _dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getFaceConfig() async {
    final response = await _dio.get('/auth/face-config');
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

  Future<LoginResult> login(
    String username,
    String password, {
    dynamic faceData,
    String? livePhotoBase64,
    bool strict2FA = false,
  }) async {
    _authNotifier.setLoading(true);
    _authNotifier.setError(null);

    final response = strict2FA
        ? await _repo.loginStrict2FA(username, password, faceData ?? livePhotoBase64)
        : await _repo.login(username, password, faceData: faceData, livePhotoBase64: livePhotoBase64);
    final data = response['data'] ?? response;

    // Check if Face Verification is required
    if (data['requiresFaceVerification'] == true) {
      _authNotifier.setLoading(false);
      return LoginResult(
        requiresFaceVerification: true,
        faceSessionToken: data['faceSessionToken'] as String?,
        userMap: data['user'] as Map<String, dynamic>?,
        message: data['message'] as String?,
        isSuccess: false,
      );
    }

    // Direct Login Successful (Backward compatible)
    final userMap = data['user'] as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>;

    final user = AuthUser.fromJson(userMap);
    await _authNotifier.setUser(
      user,
      tokens['accessToken'] as String,
      tokens['refreshToken'] as String,
    );

    final targetRoute = data['targetRoute'] as String? ?? userMap['targetRoute'] as String?;
    final targetModule = data['targetModule'] as String? ?? userMap['targetModule'] as String?;

    return LoginResult(
      requiresFaceVerification: false,
      userMap: userMap,
      targetRoute: targetRoute,
      targetModule: targetModule,
      isSuccess: true,
    );
  }


  Future<void> verifyFace(String faceSessionToken, String faceImageBase64) async {
    _authNotifier.setLoading(true);
    _authNotifier.setError(null);

    final response = await _repo.verifyFace(faceSessionToken, faceImageBase64);
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
