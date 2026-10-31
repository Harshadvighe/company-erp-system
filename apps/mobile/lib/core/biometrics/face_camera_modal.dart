import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:saark_erp_mobile/core/biometrics/live_camera_stream_viewport.dart';

/// Modal dialog for live face camera capture and alignment.
/// Captures real frames from the browser's camera via WebRTC getUserMedia.
class FaceCameraModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final String actionButtonText;
  final bool isVerificationMode;

  const FaceCameraModal({
    super.key,
    this.title = 'Face Biometric Verification',
    this.subtitle =
        'Please look directly at the camera and position your face inside the frame.',
    this.actionButtonText = 'Verify Face',
    this.isVerificationMode = true,
  });

  /// Static helper to show the dialog and return captured base64 image
  static Future<String?> show(
    BuildContext context, {
    String title = 'Face Biometric Verification',
    String subtitle =
        'Please look directly at the camera and position your face inside the frame.',
    String actionButtonText = 'Verify Face',
    bool isVerificationMode = true,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FaceCameraModal(
        title: title,
        subtitle: subtitle,
        actionButtonText: actionButtonText,
        isVerificationMode: isVerificationMode,
      ),
    );
  }

  @override
  State<FaceCameraModal> createState() => _FaceCameraModalState();
}

class _FaceCameraModalState extends State<FaceCameraModal>
    with SingleTickerProviderStateMixin {
  bool _isCapturing = false;
  String? _capturedImageBase64;
  Uint8List? _previewBytes;
  String _statusMessage = 'Position your face in the oval frame.';
  Color _frameColor = const Color(0xFF00E5FF);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Key to access the LiveCameraStreamViewportState (for snapCurrentFrame)
  final GlobalKey<LiveCameraStreamViewportState> _viewportKey =
      GlobalKey<LiveCameraStreamViewportState>();

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Uint8List? _safeDecodeBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final clean =
          base64Str.contains(',') ? base64Str.split(',').last : base64Str;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleCapture() async {
    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing live biometric frame...';
    });

    // Snap a real frame from the live camera viewport
    final frame = await _viewportKey.currentState?.snapCurrentFrame();

    if (!mounted) return;

    if (frame == null || frame.isEmpty) {
      setState(() {
        _isCapturing = false;
        _statusMessage = 'Failed to capture frame. Ensure camera is active.';
        _frameColor = Colors.redAccent;
      });
      return;
    }

    setState(() {
      _capturedImageBase64 = frame;
      _previewBytes = _safeDecodeBase64(frame);
      _isCapturing = false;
      _statusMessage = 'Live biometric frame captured.';
      _frameColor = const Color(0xFF00E676);
    });
  }

  void _confirmAndSubmit() async {
    if (_capturedImageBase64 != null) {
      Navigator.of(context).pop(_capturedImageBase64);
    } else {
      // Auto-capture on submit if not yet captured
      await _handleCapture();
      if (_capturedImageBase64 != null && mounted) {
        Navigator.of(context).pop(_capturedImageBase64);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2024),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2E3238)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar with Title & Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF26522).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: Color(0xFFF26522),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Saark Exploration ERP • Biometric Security (AES-256-GCM)',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(null),
                  tooltip: 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Instruction Banner
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141517),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2D33)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF00E5FF), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Camera Viewfinder
            Center(
              child: SizedBox(
                width: 270,
                height: 270,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Real WebRTC camera stream viewport
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _capturedImageBase64 != null &&
                                _previewBytes != null
                            ? Image.memory(
                                _previewBytes!,
                                fit: BoxFit.cover,
                              )
                            : LiveCameraStreamViewport(
                                key: _viewportKey,
                                height: 270,
                              ),
                      ),
                    ),

                    // Animated Face Guide Oval
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 175,
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.elliptical(87, 110),
                              ),
                              border: Border.all(
                                color: _capturedImageBase64 != null
                                    ? const Color(0xFF00E676)
                                    : _frameColor,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_capturedImageBase64 != null
                                          ? const Color(0xFF00E676)
                                          : _frameColor)
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

                    // Corner guides
                    Positioned(
                        top: 14,
                        left: 14,
                        child: _buildCornerGuide(true, true)),
                    Positioned(
                        top: 14,
                        right: 14,
                        child: _buildCornerGuide(true, false)),
                    Positioned(
                        bottom: 14,
                        left: 14,
                        child: _buildCornerGuide(false, true)),
                    Positioned(
                        bottom: 14,
                        right: 14,
                        child: _buildCornerGuide(false, false)),

                    // Status Pill
                    Positioned(
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _capturedImageBase64 != null
                                ? const Color(0xFF00E676)
                                : const Color(0xFF00E5FF),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _capturedImageBase64 != null
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFF00E5FF),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _statusMessage,
                              style: const TextStyle(
                                  fontSize: 10.5, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCapturing
                        ? null
                        : () {
                            setState(() {
                              _capturedImageBase64 = null;
                              _previewBytes = null;
                              _statusMessage =
                                  'Position your face in the oval frame.';
                              _frameColor = const Color(0xFF00E5FF);
                            });
                            if (_capturedImageBase64 != null) {
                              // Was showing preview, now back to live
                            } else {
                              _handleCapture();
                            }
                          },
                    icon: Icon(
                        _capturedImageBase64 != null
                            ? Icons.refresh
                            : Icons.camera_alt_outlined,
                        size: 14),
                    label: Text(
                        _capturedImageBase64 != null ? 'Retake' : 'Capture'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCapturing ? null : _confirmAndSubmit,
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: Text(widget.actionButtonText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF26522),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerGuide(bool isTop, bool isLeft) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Color(0xFF00E5FF), width: 2)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Color(0xFF00E5FF), width: 2)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Color(0xFF00E5FF), width: 2)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Color(0xFF00E5FF), width: 2)
              : BorderSide.none,
        ),
      ),
    );
  }
}
