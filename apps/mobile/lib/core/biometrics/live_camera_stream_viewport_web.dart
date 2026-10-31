// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';

/// Controller interface to capture current frame from the camera stream viewport
abstract class LiveCameraStreamController {
  Future<String?> snapCurrentFrame();
}

/// Integrated live camera preview stream widget for Dual-Factor Authentication (2FA).
/// Uses browser getUserMedia WebRTC API to stream real camera feed and capture frames.
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

  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  String? _viewId;
  bool _cameraReady = false;
  String _statusMessage = 'Starting camera...';

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

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
        'audio': false,
      });

      _mediaStream = stream;

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..srcObject = stream
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '12px'
        ..style.transform = 'scaleX(-1)'; // Mirror for selfie view

      _viewId = 'saark-live-cam-${DateTime.now().millisecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId!,
        (int id) => video,
      );

      _videoElement = video;

      if (mounted) {
        setState(() {
          _cameraReady = true;
          _statusMessage = 'Live Camera Active';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera access denied';
        });
      }
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _mediaStream?.getTracks().forEach((t) => t.stop());
    super.dispose();
  }

  /// Captures the current video frame and returns it as base64-encoded JPEG
  @override
  Future<String?> snapCurrentFrame() async {
    final video = _videoElement;
    if (video == null || !_cameraReady) return null;

    // Draw current video frame onto an offscreen canvas
    final canvas = html.CanvasElement(
      width: video.videoWidth > 0 ? video.videoWidth : 640,
      height: video.videoHeight > 0 ? video.videoHeight : 480,
    );
    final ctx = canvas.context2D;

    // Mirror horizontally (same as video display)
    ctx.translate(canvas.width!, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, 0, 0);

    // Export as JPEG data URL
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.9);
    return dataUrl; // format: "data:image/jpeg;base64,..."
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF101216),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _cameraReady
              ? AppTheme.primary.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Live WebRTC Camera Feed
            if (_cameraReady && _viewId != null)
              Positioned.fill(
                child: HtmlElementView(viewType: _viewId!),
              )
            else
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
                        Icon(
                          Icons.videocam_off_rounded,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Animated Biometric Scan Beam
            if (_cameraReady)
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
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF00E5FF),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Face Alignment Guide Oval
            if (_cameraReady)
              Container(
                width: 145,
                height: 170,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(72.5, 85),
                  ),
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
              ),

            // Top Status Bar
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _cameraReady
                          ? const Color(0xFF00E676)
                          : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_cameraReady
                                  ? const Color(0xFF00E676)
                                  : Colors.red)
                              .withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _cameraReady
                        ? 'LIVE CAMERA STREAM ACTIVE'
                        : 'CAMERA INITIALIZING...',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: _cameraReady
                          ? const Color(0xFF00E676)
                          : Colors.white54,
                    ),
                  ),
                  const Spacer(),
                  if (_cameraReady)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HD • LIVE',
                        style: TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Status Bar
            if (_cameraReady)
              Positioned(
                bottom: 8,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        size: 13,
                        color: Color(0xFF00E5FF),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Live Camera Active',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
