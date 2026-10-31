import 'dart:async';
import 'package:flutter/material.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';

/// Controller interface to capture current frame from the camera stream viewport
abstract class LiveCameraStreamController {
  Future<String?> snapCurrentFrame();
}

/// Mobile stub for LiveCameraStreamViewport.
/// On Android/iOS, displays a camera placeholder. Real camera capture
/// should use the device camera plugin separately.
class LiveCameraStreamViewport extends StatefulWidget {
  final double height;
  final ValueChanged<String?>? onFrameCaptured;

  const LiveCameraStreamViewport({
    super.key,
    this.height = 220,
    this.onFrameCaptured,
  });

  @override
  State<LiveCameraStreamViewport> createState() =>
      LiveCameraStreamViewportState();
}

class LiveCameraStreamViewportState extends State<LiveCameraStreamViewport>
    with SingleTickerProviderStateMixin
    implements LiveCameraStreamController {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  /// Returns null on mobile — native camera handled by device
  @override
  Future<String?> snapCurrentFrame() async => null;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF101216),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [Color(0xFF1E2430), Color(0xFF0D0F12)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.face_retouching_natural_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 8),
                      const Text('Camera Ready',
                          style: TextStyle(
                              fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
              ),
            ),
            // Scan beam animation
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top: widget.height * _scanAnimation.value,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        AppTheme.primary.withValues(alpha: 0.8),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                );
              },
            ),
            // Face oval guide
            Container(
              width: 145,
              height: 170,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.all(Radius.elliptical(72.5, 85)),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.7),
                  width: 2,
                ),
              ),
            ),
            // Status
            Positioned(
              top: 8, left: 10, right: 10,
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('CAMERA ACTIVE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Color(0xFF00E676))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
