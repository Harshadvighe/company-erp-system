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
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';

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

  bool get _isRahulYeole {
    final t = _emailController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return t == 'saarkexploration30' ||
        t == 'saarkexploration30gmailcom' ||
        t.contains('rahul') ||
        t.contains('yeole') ||
        t.contains('saarkexploration') ||
        t.contains('emp2026005');
  }

  bool get _isSaarkAdmin {
    final t = _emailController.text.trim().toLowerCase();
    return t == 'saarkadmin';
  }

  bool get _shouldBypassCamera {
    return _isRahulYeole || _isSaarkAdmin;
  }

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
    _emailController.addListener(_onEmailChanged);
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

  void _onEmailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUsername() async {
    try {
      final saved = await AppStorage.read('last_login_username');
      if (saved != null && saved.isNotEmpty && mounted && _emailController.text.isEmpty) {
        setState(() {
          _emailController.text = saved;
        });
      }
    } catch (_) {}
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

      // Automatic camera bypass for Rahul Yeole, Saarkadmin, or user toggle (laptops with no camera)
      final isBypass = _shouldBypassCamera;

      // Capture live face frame if camera is available
      String? liveFaceData;
      if (!isBypass) {
        try {
          liveFaceData = await _cameraKey.currentState?.snapCurrentFrame();
        } catch (_) {
          liveFaceData = null;
        }
      }

      // If camera is not accessible, liveFaceData is null.
      // The backend will securely verify Username & Password and grant login directly!

      final loginResult = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
        faceData: liveFaceData,
      );

      final inputLower = _emailController.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final isBypassUser = isBypass ||
          inputLower == 'saarkadmin' ||
          inputLower == 'saarkexploration30' ||
          inputLower == 'saarkexploration30@gmail.com' ||
          inputLower == 'rahulyeole' ||
          inputLower.contains('rahul') ||
          (loginResult.userMap?['username']?.toString().toLowerCase() == 'saarkexploration30') ||
          (loginResult.userMap?['fullName']?.toString().toLowerCase().contains('rahul') == true &&
              loginResult.userMap?['fullName']?.toString().toLowerCase().contains('yeole') == true);

      // Two-step face challenge fallback (bypassed for Saarkadmin & Rahul Yeole)
      if (!isBypassUser &&
          loginResult.requiresFaceVerification &&
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
              final user = ref.read(currentUserProvider);
              final target = (user != null && !user.isAdmin && user.assignedModules.length == 1)
                  ? user.getPrimaryModuleRoute()
                  : '/dashboard';
              context.go(target);
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

      await AppStorage.write('last_login_username', _emailController.text.trim());

      if (mounted &&
          GoRouterState.of(context).matchedLocation == '/login') {
        final user = ref.read(currentUserProvider);
        final target = (user != null && !user.isAdmin && user.assignedModules.length == 1)
            ? user.getPrimaryModuleRoute()
            : (loginResult.targetRoute ?? '/dashboard');
        context.go(target);
      }
    } catch (e) {
      String message =
          'Authentication failed. Please check your credentials.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          message =
              'Server is waking up or connecting. Please wait 10-15 seconds and tap Sign In again.';
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

  Future<void> _handleFaceAutoLogin() async {
    final now = DateTime.now();
    if (now.hour >= 18) {
      setState(() {
        _errorMessage =
            'Office hours ended at 6:00 PM. System auto-logout is active. Please log in during regular business hours.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      String? liveFaceData;

      try {
        liveFaceData = await _cameraKey.currentState?.snapCurrentFrame();
      } catch (_) {
        liveFaceData = null;
      }

      if (liveFaceData == null || liveFaceData.isEmpty) {
        if (mounted) {
          liveFaceData = await FaceCameraModal.show(
            context,
            title: 'Face Scan Auto-Login',
            subtitle:
                'Position your face in the oval frame to automatically recognize and sign into your account.',
            actionButtonText: 'Scan & Sign In',
            isVerificationMode: true,
          );
        }
      }

      if (liveFaceData == null || liveFaceData.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Camera access is required for Face Scan Auto-Login. Please ensure your camera is enabled.';
          });
        }
        return;
      }

      final usernameHint = _emailController.text.trim();
      final loginResult = await authService.faceAutoLogin(
        liveFaceData,
        username: usernameHint.isNotEmpty ? usernameHint : null,
      );

      if (mounted && GoRouterState.of(context).matchedLocation == '/login') {
        final user = ref.read(currentUserProvider);
        final target = (user != null && !user.isAdmin && user.assignedModules.length == 1)
            ? user.getPrimaryModuleRoute()
            : (loginResult.targetRoute ?? '/dashboard');
        context.go(target);
      }
    } catch (e) {
      String message =
          'Face not recognized in the system. First-time setup: Please enter your Username in the box above to link your camera face, or sign in with your Username & Password.';
      if (e is DioException) {
        if (e.response?.data is Map &&
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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

                // ── 6:00 PM Office Hours Alert Banner ─────────────────────
                if (DateTime.now().hour >= 18) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: Color(0xFFFF9800), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Office Hours Closed (6:00 PM Auto-Logout Active). Standard employee access resumes tomorrow morning.',
                            style: TextStyle(
                              color: Color(0xFFFFB74D),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

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
                          child: _shouldBypassCamera
                              ? Container(
                                  height: 145,
                                  width: double.infinity,
                                  color: const Color(0xFF131518),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.no_photography_rounded,
                                          color: Color(0xFF10B981),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _isRahulYeole
                                            ? 'Rahul Yeole (Direct Password Login)'
                                            : 'Laptop Camera Bypassed',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isRahulYeole
                                            ? 'No camera or face scan required.\nDirect access with username & password.'
                                            : 'No camera required for this device.\nSign in directly with your password.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : LiveCameraStreamViewport(
                                  key: _cameraKey,
                                  height: 145,
                                ),
                        ),
                      ),
                    ),
                    AppSpacing.gapH6,
                    if (_shouldBypassCamera)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _isRahulYeole
                                    ? 'Camera Bypass Active: Rahul Yeole'
                                    : 'Camera Bypass Active: Ready to Sign In',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Center(
                        child: Text(
                          'Sign in with your Password, or tap Face Scan for instant camera access',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppTypography.darkTextMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                AppSpacing.gapH16,

                // ── Primary Action: Sign In Button (Username & Password) ──
                Center(
                  child: SizedBox(
                    width: 280,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppTheme.primary.withValues(alpha: 0.45),
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
                                Icon(Icons.login_rounded, size: 19),
                                SizedBox(width: 10),
                                Text(
                                  'Sign In (Username & Password)',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                // ── Secondary Action: Quick Face Scan Auto-Login (Camera Only) ──
                if (!_shouldBypassCamera) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.12),
                          thickness: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'OR 1-CLICK CAMERA AUTO-LOGIN',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.12),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox(
                      width: 280,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00E5FF),
                          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                        ),
                        onPressed: _isLoading ? null : _handleFaceAutoLogin,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_retouching_natural_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Face Scan Auto-Login',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
