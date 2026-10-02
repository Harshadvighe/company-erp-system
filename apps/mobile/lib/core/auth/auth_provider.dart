import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/core/storage/app_storage.dart';

// ─── Auth State Model ───────────────────────────────────────────────────────

class AuthUser {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? phone;
  final String? designation;
  final String? department;
  final List<String> roles;
  final List<String> permissions;

  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.phone,
    this.designation,
    this.department,
    required this.roles,
    required this.permissions,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'],
      designation: json['designation'],
      department: json['department'],
      roles: List<String>.from(json['roles'] ?? []),
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'fullName': fullName,
        'phone': phone,
        'designation': designation,
        'department': department,
        'roles': roles,
        'permissions': permissions,
      };

  bool get isAdmin => roles.contains('ADMIN') || roles.contains('SUPER_ADMIN');

  bool hasPermission(String module, String action) {
    if (isAdmin) return true;
    return permissions.contains('$module:$action');
  }

  bool canView(String module) => hasPermission(module, 'VIEW');
  bool canCreate(String module) => hasPermission(module, 'CREATE');
  bool canEdit(String module) => hasPermission(module, 'EDIT');
  bool canDelete(String module) => hasPermission(module, 'DELETE');
  bool canApprove(String module) => hasPermission(module, 'APPROVE');
  bool canExport(String module) => hasPermission(module, 'EXPORT');
}

// ─── Auth State ─────────────────────────────────────────────────────────────

class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({AuthUser? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Auth Notifier ───────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final profile = await AppStorage.read(AppConstants.userProfileKey);
      if (profile != null) {
        try {
          final json = jsonDecode(profile) as Map<String, dynamic>;
          state = AuthState(user: AuthUser.fromJson(json));
        } catch (_) {
          await logout();
        }
      }
    } catch (_) {
      state = const AuthState();
    }
  }

  Future<void> setUser(AuthUser user, String accessToken, String refreshToken) async {
    await AppStorage.write(AppConstants.accessTokenKey, accessToken);
    await AppStorage.write(AppConstants.refreshTokenKey, refreshToken);
    await AppStorage.write(
        AppConstants.userProfileKey, jsonEncode(user.toJson()));
    state = AuthState(user: user);
  }

  Future<void> logout() async {
    await AppStorage.deleteAll();
    state = const AuthState();
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, isLoading: false);
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).user;
});
