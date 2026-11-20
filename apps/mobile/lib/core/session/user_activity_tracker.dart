import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';

/// Global User Activity Tracker
/// Monitors continuous user inactivity across the entire application.
/// If 30 continuous minutes pass with NO user interaction (clicks, touches, keyboard, pointer moves),
/// it automatically records an inactivity logout event with the backend server.
/// If the user exceeds the 10-count limit, the backend locks the account and the user is redirected
/// to the login page with an explicit HR-contact lockout warning.
class UserActivityTracker extends ConsumerStatefulWidget {
  final Widget? child;

  const UserActivityTracker({super.key, this.child});

  @override
  ConsumerState<UserActivityTracker> createState() => _UserActivityTrackerState();
}

class _UserActivityTrackerState extends ConsumerState<UserActivityTracker> {
  // 30 continuous minutes of no interaction
  static const Duration _idleThreshold = Duration(minutes: 30);
  // Periodic check interval
  static const Duration _checkInterval = Duration(seconds: 15);

  DateTime _lastActivityTime = DateTime.now();
  Timer? _idleCheckTimer;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _lastActivityTime = DateTime.now();
    _startIdleTimer();
  }

  @override
  void dispose() {
    _idleCheckTimer?.cancel();
    super.dispose();
  }

  void _onUserInteraction() {
    _lastActivityTime = DateTime.now();
  }

  void _startIdleTimer() {
    _idleCheckTimer?.cancel();
    _idleCheckTimer = Timer.periodic(_checkInterval, (_) {
      _checkInactivity();
    });
  }

  Future<void> _checkInactivity() async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated || _isLoggingOut) return;

    final inactiveDuration = DateTime.now().difference(_lastActivityTime);
    if (inactiveDuration >= _idleThreshold) {
      _isLoggingOut = true;
      try {
        final result = await ref.read(authProvider.notifier).recordIdleLogout();
        final count = result?['idleLogoutCount'] ?? 1;
        final isLocked = (result?['isIdleLocked'] == true) || (count is num && count >= 10);

        if (mounted) {
          final query = isLocked
              ? 'reason=idle_locked&count=$count&locked=true'
              : 'reason=idle_timeout&count=$count';
          
          try {
            GoRouter.of(context).go('/login?$query');
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[UserActivityTracker] Idle logout error: $e');
        if (mounted) {
          try {
            GoRouter.of(context).go('/login?reason=idle_timeout');
          } catch (_) {}
        }
      } finally {
        _isLoggingOut = false;
        _lastActivityTime = DateTime.now();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserInteraction(),
      onPointerMove: (_) => _onUserInteraction(),
      onPointerHover: (_) => _onUserInteraction(),
      onPointerSignal: (_) => _onUserInteraction(),
      child: widget.child ?? const SizedBox.shrink(),
    );
  }
}

