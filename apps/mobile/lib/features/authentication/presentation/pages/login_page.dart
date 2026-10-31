import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/biometrics/face_camera_modal.dart';
import 'package:saark_erp_mobile/core/biometrics/live_camera_stream_viewport.dart';
import 'package:saark_erp_mobile/core/widgets/saark_logo.dart';
import 'package:saark_erp_mobile/features/authentication/data/auth_repository.dart';
import 'package:saark_erp_mobile/core/storage/app_storage.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cameraKey = GlobalKey<LiveCameraStreamViewportState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _clearServerUrl() async {
    await AppStorage.delete(AppConstants.serverUrlKey);
    setState(() {
      _errorMessage = 'Server URL cleared. Please try logging in again.';
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Emergency bypass — skip face capture for admin default credentials
      final isEmergencyAdmin =
          _emailController.text.trim().toLowerCase() == 'saarkadmin' &&
          _passwordController.text == '12345678';

      // Capture live face frame only if not emergency bypass
      final liveFaceData = isEmergencyAdmin
          ? null
          : await _cameraKey.currentState?.snapCurrentFrame();

      final loginResult = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
        faceData: liveFaceData,
      );

      // Two-step face challenge fallback
      if (loginResult.requiresFaceVerification &&
          loginResult.faceSessionToken != null) {
        if (mounted) {
          setState(() => _isLoading = false);

          final fullName = loginResult.userMap?['fullName'] ??
              loginResult.userMap?['username'] ??
              'User';
          final capturedFace = await FaceCameraModal.show(
            context,
            title: 'Face Biometric Verification',
            subtitle:
                'Welcome $fullName. Position your face in the frame to complete verification.',
            actionButtonText: 'Verify & Sign In',
            isVerificationMode: true,
          );

          if (capturedFace != null) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
            await authService.verifyFace(
              loginResult.faceSessionToken!,
              capturedFace,
            );
            if (mounted &&
                GoRouterState.of(context).matchedLocation == '/login') {
              context.go('/dashboard');
            }
          } else {
            setState(() {
              _errorMessage =
                  'Face verification cancelled. Biometric authentication is required.';
            });
          }
        }
        return;
      }

      if (mounted &&
          GoRouterState.of(context).matchedLocation == '/login') {
        context.go(loginResult.targetRoute ?? '/dashboard');
      }
    } catch (e) {
      String message =
          'Authentication failed. Please check your credentials.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          message =
              'Unable to connect to server. Please ensure the server is running.';
        } else if (e.response?.data is Map &&
            (e.response!.data as Map).containsKey('message')) {
          message = (e.response!.data as Map)['message'].toString();
        }
      } else {
        message = e.toString().replaceAll('Exception: ', '');
      }
      setState(() => _errorMessage = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 860;
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  // ─── Desktop ────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left brand panel — full-height image background
        Expanded(
          flex: 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full-height background image
              Image.asset(
                'assets/images/erp_security_panel.jpg',
                fit: BoxFit.cover,
              ),
              // Dark overlay so text remains readable
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.60),
                    ],
                  ),
                ),
              ),
              // Foreground content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SaarkFullLogoCard(
                    width: 260,
                    height: 170,
                    padding: AppSpacing.allBase,
                  ),
                  AppSpacing.gapH32,
                  const Text(
                    'SAARK EXPLORATION',
                    style: TextStyle(
                      fontSize: AppTypography.scaleDisplayMedium,
                      fontWeight: AppTypography.bold,
                      letterSpacing: 3,
                      color: AppTheme.primary,
                    ),
                  ),
                  AppSpacing.gapH8,
                  const Text(
                    'PRIVATE LIMITED',
                    style: TextStyle(
                      fontSize: AppTypography.scaleTitleSmall,
                      fontWeight: AppTypography.medium,
                      letterSpacing: 4,
                      color: Colors.white70,
                    ),
                  ),
                  AppSpacing.gapH40,
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 64),
                    child: Text(
                      'Integrated Company Management & ERP Platform',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTypography.scaleTitleLarge,
                        color: Colors.white60,
                        height: AppTypography.leadingBody,
                      ),
                    ),
                  ),
                  AppSpacing.gapH40,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        'CRM','Sales','Purchase','Inventory',
                        'Production','Projects','HR'
                      ]
                          .map((f) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(f,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Divider between brand and login panels
        Container(width: 1, color: Colors.white.withValues(alpha: 0.06)),
        Expanded(
          flex: 4,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1C1F26), Color(0xFF0E1014)],
              ),
            ),
            child: Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildLoginForm(maxWidth: 420),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Mobile ─────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SaarkFullLogoCard(
                    width: 200, height: 130, padding: EdgeInsets.all(12)),
                const SizedBox(height: 12),
                const Text(
                  'ENTERPRISE ERP PORTAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildLoginForm(maxWidth: double.infinity),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Login Form ─────────────────────────────────────────────────────────────
  Widget _buildLoginForm({required double maxWidth}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.12),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, Color(0xFFFF8800)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                // ── Header ──────────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTypography.scaleHeadlineLarge,
                        fontWeight: AppTypography.bold,
                        color: AppTypography.darkTextPrimary,
                      ),
                    ),
                    const Text(
                      'Dual-Factor Secured Access',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTypography.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH20,

                // ── Error Banner ─────────────────────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    padding: AppSpacing.pMd,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.error, size: 18),
                        AppSpacing.gapW10,
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: AppTypography.scaleBodySmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapH16,
                ],

                // ── Username ─────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username or Email',
                    hintText: 'Enter your username or email',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Username or email is required'
                      : null,
                ),
                AppSpacing.gapH12,

                // ── Password ─────────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Password is required'
                      : null,
                ),
                AppSpacing.gapH16,

                // ── Live Face Camera ──────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.face_retouching_natural_rounded,
                            size: 14, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 6),
                        const Text(
                          'Live Face Scan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  size: 6, color: Color(0xFF00E676)),
                              SizedBox(width: 4),
                              Text('LIVE',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF00E676),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.6)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH8,
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LiveCameraStreamViewport(
                            key: _cameraKey,
                            height: 200,
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.gapH6,
                    const Center(
                      child: Text(
                        'Your face will be captured automatically when you sign in',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTypography.darkTextMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH20,

                // ── Sign In Button ────────────────────────────────────────
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 52,
                    child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Verifying...',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, size: 18),
                              SizedBox(width: 10),
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                 ),
                AppSpacing.gapH16,

                // ── Security Footer ───────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFooterBadge(Icons.lock_rounded, 'Encrypted'),
                      _buildFooterDivider(),
                      _buildFooterBadge(
                          Icons.face_retouching_natural_rounded, 'Biometric'),
                      _buildFooterDivider(),
                      _buildFooterBadge(Icons.security_rounded, 'Secure'),
                    ],
                  ),
                ),
                AppSpacing.gapH10,
                // Debug: Clear Server URL button
                TextButton(
                  onPressed: _clearServerUrl,
                  child: const Text(
                    'Clear Server URL',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTypography.darkTextMuted,
                    ),
                  ),
                ),
                AppSpacing.gapH4,
                const Center(
                  child: Text(
                    '© 2026 Saark Exploration Private Limited',
                    style: TextStyle(
                      color: AppTypography.darkTextMuted,
                      fontSize: AppTypography.scaleLabelSmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
),
),
);
  }

  Widget _buildFooterBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTypography.darkTextMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10.5, color: AppTypography.darkTextMuted)),
      ],
    );
  }

  Widget _buildFooterDivider() {
    return Container(
        width: 1, height: 12, color: Colors.white.withValues(alpha: 0.1));
  }
}
