import 'dart:convert';
import 'package:dio/dio.dart';
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
  final String? staffId;
  final String? employeeId;
  final List<String> roles;
  final List<String> permissions;
  final List<String> assignedModules;
  final String? targetRoute;
  final String? targetModule;

  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.phone,
    this.designation,
    this.department,
    this.staffId,
    this.employeeId,
    required this.roles,
    required this.permissions,
    this.assignedModules = const [],
    this.targetRoute,
    this.targetModule,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    List<String> modules = [];
    final rawModules = json['assignedModules'] ?? json['user']?['assignedModules'];
    if (rawModules is List) {
      modules = rawModules.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawModules is String && rawModules.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawModules);
        if (decoded is List) {
          modules = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {
        modules = rawModules.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    return AuthUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'],
      designation: json['designation'],
      department: json['department'],
      staffId: json['staffId'],
      employeeId: json['employeeId'],
      roles: List<String>.from(json['roles'] ?? []),
      permissions: List<String>.from(json['permissions'] ?? []),
      assignedModules: modules,
      targetRoute: json['targetRoute'],
      targetModule: json['targetModule'],
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
        'staffId': staffId,
        'employeeId': employeeId,
        'roles': roles,
        'permissions': permissions,
        'assignedModules': assignedModules,
        if (targetRoute != null) 'targetRoute': targetRoute,
        if (targetModule != null) 'targetModule': targetModule,
      };

  bool get isAdmin =>
      roles.contains('ADMIN') ||
      roles.contains('SUPER_ADMIN') ||
      roles.contains('ROLE_ADMIN');

  bool get isProjectManager =>
      isAdmin || roles.contains('ROLE_PROJECT_MGR');

  bool canAccessModule(String moduleKey) {
    if (isAdmin) return true;
    if (assignedModules.isNotEmpty) {
      return assignedModules.contains(moduleKey);
    }
    // Fallback to role-based permission checks if no explicit modules assigned
    switch (moduleKey) {
      case 'SALES_MARKETING':
        return canView('CRM') || canView('CUSTOMERS') || canView('SALES');
      case 'B2B_TRADING':
        return canView('CRM') || canView('SALES');
      case 'PRODUCTION':
      case 'PANEL_MANUFACTURING':
      case 'QUALITY_CONTROL':
      case 'RESEARCH_DEVELOPMENT':
        return canView('PRODUCTION');
      case 'PROJECTS':
        return canView('PROJECTS');
      case 'TASKS':
        return canView('TASKS');
      case 'ACCOUNTS':
        return canView('ACCOUNTS');
      case 'HR':
        return canView('HR') || canView('STAFF');
      case 'ATTENDANCE':
        return canView('ATTENDANCE') || canView('HR');
      case 'PURCHASE':
        return canView('PURCHASE');
      case 'INVENTORY':
      case 'ASSET_MANAGEMENT':
        return canView('INVENTORY');
      case 'MAINTENANCE':
        return canView('TASKS') || canView('PRODUCTION');
      case 'ADMINISTRATION':
        return isAdmin;
      default:
        return true;
    }
  }

  String getPrimaryModuleRoute() {
    if (targetRoute != null && targetRoute!.isNotEmpty) return targetRoute!;
    if (assignedModules.isEmpty) return '/dashboard';
    final primary = assignedModules.first;
    switch (primary) {
      case 'SALES_MARKETING':
        return '/sales-marketing';
      case 'B2B_TRADING':
        return '/crm/enquiries';
      case 'PRODUCTION':
        return '/production';
      case 'PANEL_MANUFACTURING':
        return '/production/new';
      case 'QUALITY_CONTROL':
        return '/production/management';
      case 'PROJECTS':
        return '/projects';
      case 'TASKS':
        return '/tasks';
      case 'ACCOUNTS':
        return '/accounts';
      case 'HR':
        return '/hr';
      case 'ATTENDANCE':
        return '/attendance';
      case 'PURCHASE':
        return '/purchase/orders';
      case 'INVENTORY':
        return '/inventory';
      case 'MAINTENANCE':
        return '/my-work';
      case 'RESEARCH_DEVELOPMENT':
        return '/production/specs';
      case 'ASSET_MANAGEMENT':
        return '/inventory?view=assets';
      case 'ADMINISTRATION':
        return '/admin';
      default:
        return '/dashboard';
    }
  }

  bool hasPermission(String module, String action) {
    if (isAdmin) return true;
    return permissions.contains('$module:$action');
  }

  bool canView(String module) => hasPermission(module, 'VIEW');
  bool canCreate(String module) => hasPermission(module, 'CREATE');
  bool canEdit(String module) => hasPermission(module, 'EDIT');
  bool canDelete(String module) => hasPermission(module, 'DELETE');
  bool canApprove(String module) => hasPermission(module, 'APPROVE');
  bool canAssign(String module) => hasPermission(module, 'ASSIGN');
  bool canReview(String module) => hasPermission(module, 'REVIEW');
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
      final token = await AppStorage.read(AppConstants.accessTokenKey);
      final profile = await AppStorage.read(AppConstants.userProfileKey);
      if (token != null && token.trim().isNotEmpty && profile != null && profile.trim().isNotEmpty) {
        try {
          final json = jsonDecode(profile) as Map<String, dynamic>;
          state = AuthState(user: AuthUser.fromJson(json));
        } catch (_) {
          await logout();
        }
      } else {
        await logout();
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

  Future<void> logout([String? sessionId]) async {
    final token = await AppStorage.read(AppConstants.accessTokenKey);
    if (token != null) {
      try {
        final dio = Dio(BaseOptions(
          baseUrl: AppConstants.baseUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ));
        await dio.post('/auth/logout', data: {
          if (sessionId != null) 'sessionId': sessionId,
        });
      } catch (_) {}
    }
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
