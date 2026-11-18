import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/biometrics/live_camera_stream_viewport.dart';
import 'package:saark_erp_mobile/features/authentication/data/auth_repository.dart';

class SessionPresenceDialog extends ConsumerStatefulWidget {
  final String currentRoute;
  final VoidCallback onVerified;
  final VoidCallback onFailed;

  const SessionPresenceDialog({
    super.key,
    required this.currentRoute,
    required this.onVerified,
    required this.onFailed,
  });

  static Future<bool> show(
    BuildContext context, {
    required String currentRoute,
    required VoidCallback onVerified,
    required VoidCallback onFailed,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SessionPresenceDialog(
        currentRoute: currentRoute,
        onVerified: onVerified,
        onFailed: onFailed,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SessionPresenceDialog> createState() =>
      _SessionPresenceDialogState();
}

class _SessionPresenceDialogState extends ConsumerState<SessionPresenceDialog>
    with SingleTickerProviderStateMixin {
  final GlobalKey<LiveCameraStreamViewportState> _viewportKey =
      GlobalKey<LiveCameraStreamViewportState>();

  int _secondsRemaining = 45;
  Timer? _countdownTimer;
  Timer? _scanIntervalTimer;
  bool _isVerifying = false;
  bool _hasSucceeded = false;
  String _statusText = 'Looking for face in camera frame...';
  Color _statusColor = const Color(0xFF00E5FF);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
    // Begin scanning after camera initializes
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _startPeriodicScan();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scanIntervalTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  void _startPeriodicScan() {
    _scanIntervalTimer =
        Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!_isVerifying && !_hasSucceeded && mounted) {
        _attemptVerification();
      }
    });
  }

  Future<void> _attemptVerification() async {
    if (_isVerifying || _hasSucceeded) return;

    final frame = await _viewportKey.currentState?.snapCurrentFrame();
    if (frame == null || frame.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _statusText = 'Analyzing face biometrics...';
      _statusColor = const Color(0xFFFFB300);
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final res = await authRepo.verifyPresence(
        frame,
        currentRoute: widget.currentRoute,
      );

      final isVerified = res['verified'] == true;
      if (isVerified) {
        _hasSucceeded = true;
        _countdownTimer?.cancel();
        _scanIntervalTimer?.cancel();

        setState(() {
          _statusText = 'Presence Verified! Resuming session...';
          _statusColor = const Color(0xFF00E676);
        });

        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          widget.onVerified();
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _statusText = res['message'] ?? 'Face not recognized. Looking...';
          _statusColor = const Color(0xFFFF5252);
        });
      }
    } catch (e) {
      setState(() {
        _statusText = 'Scanning... Please look directly into the camera.';
        _statusColor = const Color(0xFF00E5FF);
      });
    } finally {
      if (mounted && !_hasSucceeded) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _handleTimeout() {
    if (_hasSucceeded) return;
    _scanIntervalTimer?.cancel();
    setState(() {
      _statusText = 'Presence verification timeout. Logging out...';
      _statusColor = Colors.redAccent;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        widget.onFailed();
        Navigator.of(context).pop(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B1E23),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _hasSucceeded
              ? const Color(0xFF00E676).withOpacity(0.6)
              : const Color(0xFF00E5FF).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_hasSucceeded
                            ? const Color(0xFF00E676)
                            : const Color(0xFF00E5FF))
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _hasSucceeded
                        ? Icons.check_circle_rounded
                        : Icons.camera_front_rounded,
                    color: _hasSucceeded
                        ? const Color(0xFF00E676)
                        : const Color(0xFF00E5FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '30-Minute Presence Check',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Working on: ${widget.currentRoute}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Countdown Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (_secondsRemaining <= 10
                            ? Colors.redAccent
                            : const Color(0xFF2A2E35))
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _secondsRemaining <= 10
                          ? Colors.redAccent
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: _secondsRemaining <= 10
                            ? Colors.redAccent
                            : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_secondsRemaining}s',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _secondsRemaining <= 10
                              ? Colors.redAccent
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF121417),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF00E5FF), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please look at the camera to verify your presence. Once verified, you stay on your current screen.',
                      style: TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Viewfinder
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LiveCameraStreamViewport(
                        key: _viewportKey,
                        height: 260,
                      ),
                    ),
                    // Oval guide
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _hasSucceeded ? 1.0 : _pulseAnimation.value,
                          child: Container(
                            width: 170,
                            height: 215,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.elliptical(85, 107),
                              ),
                              border: Border.all(
                                color: _hasSucceeded
                                    ? const Color(0xFF00E676)
                                    : _statusColor,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_hasSucceeded
                                          ? const Color(0xFF00E676)
                                          : _statusColor)
                                      .withOpacity(0.25),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Status message
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isVerifying && !_hasSucceeded) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (_hasSucceeded) ...[
                    const Icon(Icons.check_circle,
                        color: Color(0xFF00E676), size: 16),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
