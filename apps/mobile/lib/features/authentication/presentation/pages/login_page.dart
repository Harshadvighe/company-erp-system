import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/core/storage/app_storage.dart';
import 'package:saark_erp_mobile/features/authentication/data/auth_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.text = 'admin';
    _passwordController.text = 'Saark@2026';
    _loadSavedServerUrl();
  }

  void _loadSavedServerUrl() async {
    final saved = await AppStorage.read('custom_server_url');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        AppConstants.customServerUrl = saved;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        final location = GoRouterState.of(context).matchedLocation;
        if (location == '/login') {
          context.go('/dashboard');
        }
      }
    } on Exception catch (e) {
      String message = 'Login failed. Please check your credentials.';
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('dioexception') || errStr.contains('socketexception') || errStr.contains('connection refused') || errStr.contains('timed out')) {
        message = 'Cannot connect to Server ($baseUrlHost).\nCheck your Wi-Fi or tap "Server" below to change connection.';
      } else {
        message = e.toString().replaceAll('Exception: ', '');
      }
      setState(() => _errorMessage = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get baseUrlHost {
    try {
      return Uri.tryParse(AppConstants.baseUrl)?.host ?? AppConstants.baseUrl;
    } catch (_) {
      return AppConstants.baseUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      body: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left brand panel
        Expanded(
          flex: 5,
          child: Container(
            color: AppTheme.darkSurface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'SAARK EXPLORATION',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PRIVATE LIMITED',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Integrated Company Management & ERP Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white54,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: Column(
                    children: _buildFeaturePills(),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right login form
        Expanded(
          flex: 4,
          child: Center(child: _buildLoginForm(maxWidth: 400)),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'SAARK EXPLORATION',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppTheme.primary,
            ),
          ),
          const Text(
            'PRIVATE LIMITED',
            style: TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          _buildLoginForm(maxWidth: double.infinity),
        ],
      ),
    );
  }

  List<Widget> _buildFeaturePills() {
    final features = ['CRM', 'Sales', 'Purchase', 'Inventory', 'Production', 'Projects', 'HR'];
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: features.map((f) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(f, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        )).toList(),
      ),
    ];
  }

  Widget _buildLoginForm({required double maxWidth}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sign in to your account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your credentials to access the ERP platform',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Demo Credentials Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_rounded, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default Admin Account:',
                              style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'admin / Saark@2026',
                              style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppTheme.primary.withOpacity(0.15),
                        ),
                        onPressed: () {
                          setState(() {
                            _emailController.text = 'admin';
                            _passwordController.text = 'Saark@2026';
                          });
                        },
                        child: const Text('Fill', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppTheme.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Username / Email
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
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password is required' : null,
                ),
                const SizedBox(height: 4),

                // Remember me + Forgot password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.85,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                            activeColor: AppTheme.primary,
                          ),
                        ),
                        const Text('Remember me',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: EdgeInsets.zero),
                      child: const Text('Forgot Password?',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Login Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login, size: 18),
                              SizedBox(width: 8),
                              Text('SIGN IN',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: InkWell(
                    onTap: _showServerConfigDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_done_rounded, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Server: ${Uri.tryParse(AppConstants.baseUrl)?.host ?? AppConstants.baseUrl}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 12, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '© 2026 Saark Exploration Private Limited',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: AppConstants.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Server Connection', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure backend API address (works on 4G/5G mobile data or Wi-Fi):',
              style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://...',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    controller.text = '${AppConstants.defaultPublicUrl}/api/v1';
                  },
                  child: const Text('Cloud 24/7 (Render)'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    controller.text = '${AppConstants.localWifiUrl}/api/v1';
                  },
                  child: const Text('Local Wi-Fi'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await AppStorage.write('custom_server_url', newUrl);
                if (mounted) {
                  setState(() {
                    AppConstants.customServerUrl = newUrl;
                  });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
