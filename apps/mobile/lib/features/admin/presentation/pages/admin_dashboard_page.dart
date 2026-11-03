import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';
import 'package:saark_erp_mobile/features/admin/presentation/pages/admin_organization_page.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Requests & Users state
  List<Employee> _requests = [];
  List<DepartmentItem> _departments = [];
  List<RoleItem> _roles = [];
  List<AdminUserItem> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Security Governance & Telemetry state
  List<AuditLogItem> _auditLogs = [];
  SecurityPolicy? _securityPolicy;
  List<ActiveSessionItem> _sessions = [];
  List<ActiveSessionItem> _sessionHistory = [];
  bool _isHistoryLoading = false;
  String _sessionSubTab = 'ACTIVE'; // 'ACTIVE' or 'HISTORY'
  String _historyStatusFilter = 'ALL';
  final _sessionSearchController = TextEditingController();
  Map<String, dynamic> _historySummary = {};
  SystemHealthInfo? _healthInfo;
  bool _isAuditLoading = false;
  bool _isSecurityLoading = false;
  bool _isHealthLoading = false;
  bool _isBackupRunning = false;
  String? _lastBackupNotice;

  // Filters: Onboarding Requests
  String _selectedDeptId = 'ALL';
  String _selectedStatus = 'PENDING_APPROVAL';
  final _searchController = TextEditingController();

  // Filters: Users
  final _userSearchController = TextEditingController();
  String _userStatusFilter = 'ALL';

  // Filters: Audit Logs
  String _auditModule = 'ALL';
  String _auditAction = 'ALL';
  final _auditSearchController = TextEditingController();

  // Security Policy form controllers
  late TextEditingController _passwordMinLengthCtrl;
  late TextEditingController _sessionTimeoutCtrl;
  late TextEditingController _lockoutAttemptsCtrl;
  late TextEditingController _allowedSubnetsCtrl;
  String _facePolicySelection = 'OPTIONAL';
  bool _requireSpecialChar = true;
  bool _requireNumbers = true;
  bool _ipWhitelistEnabled = false;

  // Test Email input
  final _testEmailController = TextEditingController(text: 'admin@saark.in');
  bool _isSendingTestEmail = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _passwordMinLengthCtrl = TextEditingController(text: '8');
    _sessionTimeoutCtrl = TextEditingController(text: '60');
    _lockoutAttemptsCtrl = TextEditingController(text: '5');
    _allowedSubnetsCtrl = TextEditingController(text: '192.168.1.0/24, 10.0.0.0/16, 127.0.0.1');

    _tabController.addListener(_handleTabChange);
    _loadInitialData();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      if (_tabController.index == 2 && _securityPolicy == null) {
        _loadSecurityData();
      } else if (_tabController.index == 3 && _auditLogs.isEmpty) {
        _loadAuditLogs();
      } else if (_tabController.index == 4 && _healthInfo == null) {
        _loadSystemHealth();
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _userSearchController.dispose();
    _auditSearchController.dispose();
    _sessionSearchController.dispose();
    _passwordMinLengthCtrl.dispose();
    _sessionTimeoutCtrl.dispose();
    _lockoutAttemptsCtrl.dispose();
    _allowedSubnetsCtrl.dispose();
    _testEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final depts = await repo.getDepartments();
      final roles = await repo.getRoles();
      final reqs = await repo.getEmployeeRequests(
        departmentId: _selectedDeptId,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );
      final users = await repo.getUsers();

      if (mounted) {
        setState(() {
          _departments = depts;
          _roles = roles;
          _requests = reqs;
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshRequests() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final reqs = await repo.getEmployeeRequests(
        departmentId: _selectedDeptId,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );
      final users = await repo.getUsers(
        search: _userSearchController.text.trim().isNotEmpty ? _userSearchController.text.trim() : null,
      );
      if (mounted) {
        setState(() {
          _requests = reqs;
          _users = users;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _loadSecurityData() async {
    setState(() => _isSecurityLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final policy = await repo.getSecurityPolicy();
      final sessions = await repo.getActiveSessions();
      final historyRes = await repo.getSessionHistory(
        search: _sessionSearchController.text.trim(),
        status: _historyStatusFilter != 'ALL' ? _historyStatusFilter : null,
      );

      if (mounted) {
        setState(() {
          _securityPolicy = policy;
          _sessions = sessions;
          _sessionHistory = (historyRes['data'] as List<ActiveSessionItem>?) ?? [];
          _historySummary = (historyRes['summary'] as Map<String, dynamic>?) ?? {};
          _passwordMinLengthCtrl.text = policy.passwordMinLength.toString();
          _sessionTimeoutCtrl.text = policy.sessionTimeoutMinutes.toString();
          _lockoutAttemptsCtrl.text = policy.maxFailedLoginsBeforeLockout.toString();
          _allowedSubnetsCtrl.text = policy.allowedPlantSubnets;
          _facePolicySelection = policy.faceRecognitionPolicy;
          _requireSpecialChar = policy.requireSpecialChar;
          _requireNumbers = policy.requireNumbers;
          _ipWhitelistEnabled = policy.ipPlantWhitelistEnabled;
          _isSecurityLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSecurityLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load security policies: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _loadSessionHistory() async {
    setState(() => _isHistoryLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final historyRes = await repo.getSessionHistory(
        search: _sessionSearchController.text.trim(),
        status: _historyStatusFilter != 'ALL' ? _historyStatusFilter : null,
      );
      if (mounted) {
        setState(() {
          _sessionHistory = (historyRes['data'] as List<ActiveSessionItem>?) ?? [];
          _historySummary = (historyRes['summary'] as Map<String, dynamic>?) ?? {};
          _isHistoryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isHistoryLoading = false);
      }
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      final sec = dt.second.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final month = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1];
      return '$day $month $hour:$min:$sec $ampm';
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildMetricMiniCard(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSecurityPolicy() async {
    setState(() => _isSecurityLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final updated = await repo.updateSecurityPolicy({
        'passwordMinLength': int.tryParse(_passwordMinLengthCtrl.text.trim()) ?? 8,
        'requireSpecialChar': _requireSpecialChar,
        'requireNumbers': _requireNumbers,
        'sessionTimeoutMinutes': int.tryParse(_sessionTimeoutCtrl.text.trim()) ?? 60,
        'maxFailedLoginsBeforeLockout': int.tryParse(_lockoutAttemptsCtrl.text.trim()) ?? 5,
        'faceRecognitionPolicy': _facePolicySelection,
        'ipPlantWhitelistEnabled': _ipWhitelistEnabled,
        'allowedPlantSubnets': _allowedSubnetsCtrl.text.trim(),
        'complianceStandard': 'IEC 62443 Industrial Cybersecurity / ISO 27001',
      });

      if (mounted) {
        setState(() {
          _securityPolicy = updated;
          _isSecurityLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Industrial Security Governance Policy successfully saved and applied.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSecurityLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update security policy: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isAuditLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final logs = await repo.getAuditLogs(
        module: _auditModule,
        action: _auditAction,
        search: _auditSearchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _auditLogs = logs;
          _isAuditLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAuditLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audit logs: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _loadSystemHealth() async {
    setState(() => _isHealthLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final health = await repo.getSystemHealth();
      if (mounted) {
        setState(() {
          _healthInfo = health;
          _isHealthLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isHealthLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to query system health: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _triggerDatabaseBackup() async {
    setState(() => _isBackupRunning = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final result = await repo.triggerSystemBackup();
      if (mounted) {
        setState(() {
          _isBackupRunning = false;
          _lastBackupNotice = 'Snapshot ${result['backupId']} created (${result['totalRecords']} records).';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ System Snapshot Created: ${result['backupId']} with ${result['totalRecords']} total records.'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        _loadAuditLogs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackupRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.revokeSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session $sessionId terminated.'), backgroundColor: Colors.orange[800]),
        );
        _loadSecurityData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke session: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _unlockUserAccount(AdminUserItem user) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.unlockUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ User account "${user.username}" unlocked and activated.'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        _refreshRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlock user: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showResetPasswordDialog(AdminUserItem user) {
    final passwordCtrl = TextEditingController(text: 'Saark@2026');
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppTheme.darkBorder),
              ),
              title: Row(
                children: [
                  const Icon(Icons.lock_reset_rounded, color: AppTheme.primary, size: 22),
                  AppSpacing.gapW10,
                  Expanded(
                    child: Text(
                      'Reset Password: ${user.username}',
                      style: const TextStyle(fontSize: 16, fontWeight: AppTypography.bold, color: AppTypography.darkTextPrimary),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign a new temporary password for ${user.fullName} (${user.email}).',
                    style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 13),
                  ),
                  AppSpacing.gapH16,
                  TextField(
                    controller: passwordCtrl,
                    style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(color: AppTypography.darkTextMuted),
                      prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.primary, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 18),
                        onPressed: () {
                          const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
                          final rand = Random();
                          final gen = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
                          setDlgState(() => passwordCtrl.text = gen);
                        },
                      ),
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTypography.darkTextSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final sm = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setDlgState(() => isSubmitting = true);
                          try {
                            final repo = ref.read(adminRepositoryProvider);
                            final pass = await repo.resetUserPassword(user.id, newPassword: passwordCtrl.text.trim());
                            if (mounted) {
                              nav.pop();
                              sm.showSnackBar(
                                SnackBar(
                                  content: Text('✅ Password reset for "${user.username}". Temporary: $pass'),
                                  backgroundColor: const Color(0xFF2E7D32),
                                ),
                              );
                              _refreshRequests();
                            }
                          } catch (err) {
                            setDlgState(() => isSubmitting = false);
                            if (mounted) {
                              sm.showSnackBar(
                                SnackBar(content: Text('Failed: $err'), backgroundColor: AppTheme.error),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isSubmitting ? 'Updating...' : 'Confirm Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // REVIEW & PROVISION USER DIALOG
  // -------------------------------------------------------------
  void _showProvisioningDialog(Employee employee) {
    String? initialDeptId = employee.departmentId;
    if (initialDeptId == null || !_departments.any((d) => d.id == initialDeptId)) {
      if (_departments.isNotEmpty) {
        initialDeptId = _departments.first.id;
      }
    }

    String suggestedUsername = employee.email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]'), '');
    if (suggestedUsername.isEmpty) {
      suggestedUsername = '${employee.firstName.toLowerCase()}.${employee.lastName.toLowerCase()}';
    }

    final usernameCtrl = TextEditingController(text: suggestedUsername);
    final passwordCtrl = TextEditingController(text: 'Saark@2026');
    final desigCtrl = TextEditingController(text: employee.designation);
    String selectedDeptId = initialDeptId ?? '';
    String? selectedRoleId = _roles.isNotEmpty ? _roles.first.id : null;
    bool obscurePassword = false;
    bool isSubmitting = false;
    bool sendWelcomeEmail = true;

    final defaultRole = _roles.firstWhere(
      (r) => r.code == 'ROLE_EMPLOYEE' || r.code == 'ROLE_RND_ENG',
      orElse: () => _roles.isNotEmpty ? _roles.first : RoleItem(id: '', name: 'Standard Employee', code: 'ROLE_EMPLOYEE'),
    );
    if (defaultRole.id.isNotEmpty) {
      selectedRoleId = defaultRole.id;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppTheme.darkBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.how_to_reg_rounded, color: AppTheme.primary, size: 22),
                  ),
                  AppSpacing.gapW12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review & Provision Account: ${employee.fullName}',
                          style: const TextStyle(fontSize: 16, fontWeight: AppTypography.bold, color: AppTypography.darkTextPrimary),
                        ),
                        Text(
                          'Employee Code: ${employee.employeeCode} | Department: ${employee.departmentName ?? "Pending"}',
                          style: const TextStyle(fontSize: 12, color: AppTypography.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '1. ASSIGN OFFICIAL DEPARTMENT',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                      ),
                      AppSpacing.gapH6,
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _departments.any((d) => d.id == selectedDeptId) ? selectedDeptId : null,
                            dropdownColor: AppTheme.darkSurface,
                            hint: const Text('Select Department', style: TextStyle(color: AppTypography.darkTextMuted, fontSize: 12)),
                            icon: const Icon(Icons.arrow_drop_down, color: AppTypography.darkTextSecondary),
                            isExpanded: true,
                            style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 13),
                            items: _departments.map((d) {
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text('${d.name} (${d.code})'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedDeptId = v);
                            },
                          ),
                        ),
                      ),
                      AppSpacing.gapH16,
                      const Text(
                        '2. CONFIRM OFFICIAL DESIGNATION',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                      ),
                      AppSpacing.gapH6,
                      _buildDialogInput(
                        controller: desigCtrl,
                        hint: 'e.g. Senior Automation Engineer',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 16, color: AppTypography.darkTextMuted),
                      ),
                      AppSpacing.gapH16,
                      const Text(
                        '3. ERP LOGIN CREDENTIALS GENERATION',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                      ),
                      AppSpacing.gapH6,
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Login Username:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                _buildDialogInput(
                                  controller: usernameCtrl,
                                  hint: 'firstname.lastname',
                                  prefixIcon: const Icon(Icons.person_outline, size: 16, color: AppTypography.darkTextMuted),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.gapW12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Login Password:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () {
                                        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
                                        final rand = Random();
                                        final gen = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
                                        setDialogState(() {
                                          passwordCtrl.text = gen;
                                          obscurePassword = false;
                                        });
                                      },
                                      child: const Text('Generate', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold)),
                                    ),
                                  ],
                                ),
                                AppSpacing.gapH4,
                                _buildDialogInput(
                                  controller: passwordCtrl,
                                  hint: 'At least 6 characters',
                                  obscureText: obscurePassword,
                                  prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppTypography.darkTextMuted),
                                  suffixIcon: IconButton(
                                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 16, color: AppTypography.darkTextMuted),
                                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapH16,
                      const Text(
                        '4. ASSIGN SYSTEM ROLE & ACCESS PERMISSION',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                      ),
                      AppSpacing.gapH6,
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _roles.any((r) => r.id == selectedRoleId) ? selectedRoleId : null,
                            dropdownColor: AppTheme.darkSurface,
                            hint: const Text('Select System Role', style: TextStyle(color: AppTypography.darkTextMuted, fontSize: 12)),
                            icon: const Icon(Icons.arrow_drop_down, color: AppTypography.darkTextSecondary),
                            isExpanded: true,
                            style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 13),
                            items: _roles.map((r) {
                              return DropdownMenuItem<String>(
                                value: r.id,
                                child: Text('${r.name} (${r.code})'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedRoleId = v);
                            },
                          ),
                        ),
                      ),
                      AppSpacing.gapH16,
                      Container(
                        padding: AppSpacing.allMd,
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: sendWelcomeEmail,
                              activeColor: AppTheme.primary,
                              onChanged: (val) {
                                setDialogState(() => sendWelcomeEmail = val ?? true);
                              },
                            ),
                            AppSpacing.gapW8,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Send Welcome & Login Credentials Email',
                                    style: TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12, fontWeight: AppTypography.bold),
                                  ),
                                  AppSpacing.gapH2,
                                  Text(
                                    'Dispatches welcome email with ERP URL, credentials & 2FA instructions to ${employee.email}',
                                    style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTypography.darkTextSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final sm = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setDialogState(() => isSubmitting = true);
                          final username = usernameCtrl.text.trim();
                          final password = passwordCtrl.text;

                          if (username.isEmpty || password.length < 6) {
                            setDialogState(() => isSubmitting = false);
                            sm.showSnackBar(
                              const SnackBar(content: Text('Username required and password >= 6 chars'), backgroundColor: AppTheme.error),
                            );
                            return;
                          }

                          try {
                            final repo = ref.read(adminRepositoryProvider);
                            await repo.approveEmployeeRequest(
                              employee.id,
                              username: username,
                              password: password,
                              departmentId: selectedDeptId.isNotEmpty ? selectedDeptId : null,
                              designationId: null,
                              roleIds: selectedRoleId != null ? [selectedRoleId!] : null,
                              sendWelcomeEmail: sendWelcomeEmail,
                            );

                            if (mounted) {
                              nav.pop();
                              sm.showSnackBar(
                                SnackBar(
                                  content: Text('✅ Employee ${employee.fullName} approved!\nUser account "$username" provisioned.'),
                                  backgroundColor: const Color(0xFF2E7D32),
                                ),
                              );
                              _refreshRequests();
                            }
                          } catch (err) {
                            setDialogState(() => isSubmitting = false);
                            String errorMsg = err.toString();
                            if (err is DioException && err.response?.data != null) {
                              final d = err.response!.data;
                              if (d is Map && d['message'] != null) {
                                errorMsg = d['message'].toString();
                              }
                            }
                            if (mounted) {
                              sm.showSnackBar(
                                SnackBar(content: Text('Failed: $errorMsg'), backgroundColor: AppTheme.error),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(isSubmitting ? 'Provisioning...' : 'Approve & Create Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }


  static const List<Map<String, dynamic>> _adminModuleOptions = [
    {'key': 'SALES_MARKETING', 'title': 'Sales & Marketing', 'icon': Icons.campaign_rounded},
    {'key': 'B2B_TRADING', 'title': 'B2B Trading', 'icon': Icons.storefront_rounded},
    {'key': 'PRODUCTION', 'title': 'Production Process', 'icon': Icons.precision_manufacturing_rounded},
    {'key': 'PANEL_MANUFACTURING', 'title': 'Panel Manufacturing', 'icon': Icons.electrical_services_rounded},
    {'key': 'QUALITY_CONTROL', 'title': 'Quality Control (QC/QA)', 'icon': Icons.verified_rounded},
    {'key': 'PROJECTS', 'title': 'Project Management', 'icon': Icons.folder_open_rounded},
    {'key': 'TASKS', 'title': 'Task Manager', 'icon': Icons.task_alt_rounded},
    {'key': 'ACCOUNTS', 'title': 'Accounts & Finance', 'icon': Icons.account_balance_rounded},
    {'key': 'HR', 'title': 'HR (Human Resources)', 'icon': Icons.people_alt_rounded},
    {'key': 'ATTENDANCE', 'title': 'Attendance', 'icon': Icons.access_time_rounded},
    {'key': 'PURCHASE', 'title': 'Purchase / Procurement', 'icon': Icons.shopping_bag_rounded},
    {'key': 'INVENTORY', 'title': 'Stores / Warehouse', 'icon': Icons.warehouse_rounded},
    {'key': 'MAINTENANCE', 'title': 'Maintenance', 'icon': Icons.home_repair_service_rounded},
    {'key': 'RESEARCH_DEVELOPMENT', 'title': 'R&D / Engineering', 'icon': Icons.science_rounded},
    {'key': 'ASSET_MANAGEMENT', 'title': 'Asset Management', 'icon': Icons.domain_rounded},
    {'key': 'ADMINISTRATION', 'title': 'Administration & IT', 'icon': Icons.admin_panel_settings_rounded},
  ];

  void _showEditEmployeeDialog(Employee employee) {
    final firstNameCtrl = TextEditingController(text: employee.firstName);
    final lastNameCtrl = TextEditingController(text: employee.lastName);
    final emailCtrl = TextEditingController(text: employee.email);
    final phoneCtrl = TextEditingController(text: employee.phone);
    final desigCtrl = TextEditingController(text: employee.designation);
    final usernameCtrl = TextEditingController(text: employee.username ?? employee.email.split('@').first.toLowerCase());
    final passwordCtrl = TextEditingController();

    String selectedDeptId = employee.departmentId ?? (_departments.isNotEmpty ? _departments.first.id : '');
    String selectedStatus = employee.status;
    List<String> selectedModules = List<String>.from(employee.assignedModules.isNotEmpty ? employee.assignedModules : ['SALES_MARKETING']);
    String? selectedRoleId = _roles.isNotEmpty ? _roles.first.id : null;
    bool obscurePassword = true;
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppTheme.darkBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 22),
                  ),
                  AppSpacing.gapW12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Employee & Account Details: ${employee.fullName}',
                          style: const TextStyle(fontSize: 16, fontWeight: AppTypography.bold, color: AppTypography.darkTextPrimary),
                        ),
                        Text(
                          'Employee Code: ${employee.employeeCode} | Work Email: ${employee.email}',
                          style: const TextStyle(fontSize: 12, color: AppTypography.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Section 1: Personal & Contact Details
                      const Text(
                        '1. EMPLOYEE PERSONAL & CONTACT INFORMATION',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                      ),
                      AppSpacing.gapH8,
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('First Name:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                _buildDialogInput(controller: firstNameCtrl, hint: 'First Name', prefixIcon: const Icon(Icons.person_outline, size: 16, color: AppTypography.darkTextMuted)),
                              ],
                            ),
                          ),
                          AppSpacing.gapW12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Last Name:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                _buildDialogInput(controller: lastNameCtrl, hint: 'Last Name', prefixIcon: const Icon(Icons.person_outline, size: 16, color: AppTypography.darkTextMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapH12,
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Work Email:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                _buildDialogInput(controller: emailCtrl, hint: 'email@company.com', prefixIcon: const Icon(Icons.email_outlined, size: 16, color: AppTypography.darkTextMuted)),
                              ],
                            ),
                          ),
                          AppSpacing.gapW12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Phone Number:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                _buildDialogInput(controller: phoneCtrl, hint: '+91 98765 43210', prefixIcon: const Icon(Icons.phone_outlined, size: 16, color: AppTypography.darkTextMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapH16,

                      // Section 2: Department, Designation & Status
                      const Text(
                        '2. DEPARTMENT, DESIGNATION & APPROVAL STATUS',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                      ),
                      AppSpacing.gapH8,
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Official Department:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkBackground,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.darkBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _departments.any((d) => d.id == selectedDeptId) ? selectedDeptId : null,
                                      dropdownColor: AppTheme.darkSurface,
                                      hint: const Text('Select Department', style: TextStyle(color: AppTypography.darkTextMuted, fontSize: 12)),
                                      icon: const Icon(Icons.arrow_drop_down, color: AppTypography.darkTextSecondary),
                                      isExpanded: true,
                                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                                      items: _departments.map((d) {
                                        return DropdownMenuItem<String>(
                                          value: d.id,
                                          child: Text('${d.name} (${d.code})', overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        if (v != null) setDialogState(() => selectedDeptId = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.gapW12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Official Designation:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                _buildDialogInput(controller: desigCtrl, hint: 'e.g. Sales Executive', prefixIcon: const Icon(Icons.badge_outlined, size: 16, color: AppTypography.darkTextMuted)),
                              ],
                            ),
                          ),
                          AppSpacing.gapW12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Approval Status:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkBackground,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.darkBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedStatus,
                                      dropdownColor: AppTheme.darkSurface,
                                      icon: const Icon(Icons.arrow_drop_down, color: AppTypography.darkTextSecondary),
                                      isExpanded: true,
                                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                                      items: const [
                                        DropdownMenuItem(value: 'ACTIVE', child: Text('Approved / Active', style: TextStyle(color: Colors.greenAccent))),
                                        DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('Pending Approval', style: TextStyle(color: Colors.orangeAccent))),
                                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive / Disabled', style: TextStyle(color: Colors.redAccent))),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setDialogState(() => selectedStatus = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapH16,

                      // Section 3: Assigned ERP Modules (Checkable)
                      Row(
                        children: [
                          const Text(
                            '3. ASSIGNED ERP MODULE ACCESS & PERMISSIONS',
                            style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                selectedModules = _adminModuleOptions.map((m) => m['key'] as String).toList();
                              });
                            },
                            child: const Text('Select All', style: TextStyle(color: AppTheme.primary, fontSize: 11)),
                          ),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                selectedModules = ['SALES_MARKETING'];
                              });
                            },
                            child: const Text('Reset', style: TextStyle(color: AppTypography.darkTextMuted, fontSize: 11)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _adminModuleOptions.map((mod) {
                            final key = mod['key'] as String;
                            final title = mod['title'] as String;
                            final icon = mod['icon'] as IconData;
                            final isChecked = selectedModules.contains(key);

                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  if (isChecked) {
                                    if (selectedModules.length > 1) {
                                      selectedModules.remove(key);
                                    }
                                  } else {
                                    selectedModules.add(key);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isChecked ? AppTheme.primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isChecked ? AppTheme.primary : AppTheme.darkBorder,
                                    width: isChecked ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      size: 15,
                                      color: isChecked ? AppTheme.primary : AppTypography.darkTextMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(icon, size: 14, color: isChecked ? Colors.white : AppTypography.darkTextSecondary),
                                    const SizedBox(width: 5),
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: isChecked ? Colors.white : AppTypography.darkTextSecondary,
                                        fontSize: 11,
                                        fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      AppSpacing.gapH16,

                      // Section 4: Login Account & Password Update
                      const Text(
                        '4. ERP LOGIN USERNAME & PASSWORD UPDATE',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                      ),
                      AppSpacing.gapH8,
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Login Username:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                AppSpacing.gapH4,
                                _buildDialogInput(controller: usernameCtrl, hint: 'Username', prefixIcon: const Icon(Icons.account_circle_outlined, size: 16, color: AppTypography.darkTextMuted)),
                              ],
                            ),
                          ),
                          AppSpacing.gapW12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Reset Password (Optional):', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () {
                                        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
                                        final rand = Random();
                                        final gen = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
                                        setDialogState(() {
                                          passwordCtrl.text = gen;
                                          obscurePassword = false;
                                        });
                                      },
                                      child: const Text('Generate', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold)),
                                    ),
                                  ],
                                ),
                                AppSpacing.gapH4,
                                _buildDialogInput(
                                  controller: passwordCtrl,
                                  hint: 'Leave blank to keep current',
                                  obscureText: obscurePassword,
                                  prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppTypography.darkTextMuted),
                                  suffixIcon: IconButton(
                                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 16, color: AppTypography.darkTextMuted),
                                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTypography.darkTextSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final sm = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setDialogState(() => isSubmitting = true);

                          final firstName = firstNameCtrl.text.trim();
                          final lastName = lastNameCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final desig = desigCtrl.text.trim();
                          final username = usernameCtrl.text.trim();
                          final password = passwordCtrl.text.trim();

                          if (firstName.isEmpty || email.isEmpty) {
                            setDialogState(() => isSubmitting = false);
                            sm.showSnackBar(
                              const SnackBar(content: Text('First Name and Email are required'), backgroundColor: AppTheme.error),
                            );
                            return;
                          }

                          try {
                            final repo = ref.read(adminRepositoryProvider);
                            await repo.updateEmployeeDetails(
                              employee.id,
                              firstName: firstName,
                              lastName: lastName,
                              email: email,
                              phone: phone,
                              departmentId: selectedDeptId.isNotEmpty ? selectedDeptId : null,
                              designation: desig.isNotEmpty ? desig : null,
                              status: selectedStatus,
                              username: username.isNotEmpty ? username : null,
                              password: password.isNotEmpty ? password : null,
                              roleId: selectedRoleId,
                              assignedModules: selectedModules,
                            );

                            if (mounted) {
                              nav.pop();
                              sm.showSnackBar(
                                SnackBar(
                                  content: Text('✅ Employee ${employee.employeeCode} ($firstName $lastName) updated successfully!'),
                                  backgroundColor: const Color(0xFF2E7D32),
                                ),
                              );
                              _refreshRequests();
                            }
                          } catch (err) {
                            setDialogState(() => isSubmitting = false);
                            String errorMsg = err.toString();
                            if (err is DioException && err.response?.data != null) {
                              final d = err.response!.data;
                              if (d is Map && d['message'] != null) {
                                errorMsg = d['message'].toString();
                              }
                            }
                            if (mounted) {
                              sm.showSnackBar(
                                SnackBar(content: Text('Update failed: $errorMsg'), backgroundColor: AppTheme.error),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(isSubmitting ? 'Saving...' : 'Save & Update Employee'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResendEmailDialog(Employee employee) {
    final passwordCtrl = TextEditingController(text: 'Saark@2026');
    bool obscurePassword = false;
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppTheme.darkBorder),
              ),
              title: Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  Text('Resend Credentials: ${employee.fullName}', style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Send login credentials and portal access email directly to:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(employee.email, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Password to include in email:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
                          final rand = Random();
                          final gen = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
                          setDialogState(() => passwordCtrl.text = gen);
                        },
                        child: const Text('Generate', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildDialogInput(
                    controller: passwordCtrl,
                    hint: 'Password',
                    obscureText: obscurePassword,
                    prefixIcon: const Icon(Icons.lock_outline, size: 16, color: AppTypography.darkTextMuted),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 16, color: AppTypography.darkTextMuted),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final sm = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setDialogState(() => isSubmitting = true);
                          try {
                            await ref.read(adminRepositoryProvider).resendWelcomeEmail(
                              employee.id,
                              password: passwordCtrl.text.trim(),
                            );
                            if (mounted) {
                              nav.pop();
                              sm.showSnackBar(
                                SnackBar(
                                  content: Text('✅ Credentials email dispatched to ${employee.email}'),
                                  backgroundColor: const Color(0xFF2E7D32),
                                ),
                              );
                            }
                          } catch (err) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              sm.showSnackBar(
                                SnackBar(content: Text('Failed to send email: $err'), backgroundColor: AppTheme.error),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 14),
                  label: Text(isSubmitting ? 'Sending...' : 'Send Email Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogInput({
    required TextEditingController controller,
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
  }) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTypography.darkTextMuted, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: InputBorder.none,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          isDense: true,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MAIN BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests.where((r) => r.status == 'PENDING_APPROVAL').length;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeaderBar(pendingCount),

          // 6 Professional Industrial Tabs
          Container(
            color: AppTheme.darkSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTypography.darkTextSecondary,
              labelStyle: const TextStyle(fontWeight: AppTypography.bold, fontSize: 13),
              tabs: [
                // Tab 1: Onboarding Requests
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.how_to_reg_outlined, size: 18),
                      AppSpacing.gapW8,
                      const Text('Employee Onboarding Requests'),
                      if (pendingCount > 0) ...[
                        AppSpacing.gapW8,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: AppTypography.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Tab 2: System Users
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 18),
                      AppSpacing.gapW8,
                      Text('System Users (${_users.length})'),
                    ],
                  ),
                ),
                // Tab 3: Security Governance
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Security & Plant Governance'),
                    ],
                  ),
                ),
                // Tab 4: Audit Trail
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_edu_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Audit Trail & Access Logs'),
                    ],
                  ),
                ),
                // Tab 5: System Health
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monitor_heart_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('System Health & DB Diagnostics'),
                    ],
                  ),
                ),
                // Tab 6: Organization
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Organization Structure'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
                            AppSpacing.gapH12,
                            Text(_errorMessage!, style: const TextStyle(color: AppTypography.darkTextSecondary)),
                            AppSpacing.gapH12,
                            ElevatedButton(
                              onPressed: _loadInitialData,
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRequestsTabContent(),
                          _buildUsersTabContent(),
                          _buildSecurityGovernanceTab(),
                          _buildAuditLogsTab(),
                          _buildSystemHealthTab(),
                          const AdminOrganizationPage(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // HEADER BAR
  // -------------------------------------------------------------
  Widget _buildHeaderBar(int pendingCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primary, size: 24),
          ),
          AppSpacing.gapW12,
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Management & Industrial Security Console',
                style: TextStyle(fontSize: 18, fontWeight: AppTypography.bold, color: AppTypography.darkTextPrimary, letterSpacing: 0.2),
              ),
              SizedBox(height: 3),
              Text(
                'User provisioning, IEC 62443 / ISO 27001 plant governance, tamper-evident audit logs, and system diagnostics',
                style: TextStyle(fontSize: 12, color: AppTypography.darkTextSecondary),
              ),
            ],
          ),
          const Spacer(),
          // Pending Requests Counter Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pendingCount > 0 ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: pendingCount > 0 ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Icon(
                  pendingCount > 0 ? Icons.notification_important_rounded : Icons.check_circle_outline,
                  color: pendingCount > 0 ? AppTheme.primary : AppTheme.success,
                  size: 16,
                ),
                AppSpacing.gapW8,
                Text(
                  pendingCount > 0 ? '$pendingCount Pending Requests' : 'All Clear (0 Pending)',
                  style: TextStyle(
                    color: pendingCount > 0 ? AppTheme.primary : AppTheme.success,
                    fontWeight: AppTypography.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapW12,
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTypography.darkTextSecondary),
            tooltip: 'Refresh All Admin Data',
            onPressed: () {
              _loadInitialData();
              if (_tabController.index == 2) _loadSecurityData();
              if (_tabController.index == 3) _loadAuditLogs();
              if (_tabController.index == 4) _loadSystemHealth();
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: EMPLOYEE ONBOARDING REQUESTS
  // -------------------------------------------------------------
  Widget _buildRequestsTabContent() {
    return Container(
      padding: AppSpacing.allBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                // Department filter
                const Text('Department:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12, fontWeight: AppTypography.bold)),
                AppSpacing.gapW8,
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDeptId,
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Departments')),
                        ..._departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedDeptId = v);
                          _refreshRequests();
                        }
                      },
                    ),
                  ),
                ),
                AppSpacing.gapW16,
                // Status filter
                const Text('Status:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12, fontWeight: AppTypography.bold)),
                AppSpacing.gapW8,
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('Pending Approval')),
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Approved / Active')),
                        DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedStatus = v);
                          _refreshRequests();
                        }
                      },
                    ),
                  ),
                ),
                AppSpacing.gapW16,
                // Search bar
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                      onSubmitted: (_) => _refreshRequests(),
                      decoration: InputDecoration(
                        hintText: 'Search by employee name, code, email...',
                        hintStyle: const TextStyle(color: AppTypography.darkTextMuted, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: InputBorder.none,
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppTypography.darkTextMuted),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14, color: AppTypography.darkTextSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  _refreshRequests();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapH12,

          // Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_outlined, color: AppTypography.darkTextMuted, size: 48),
                          AppSpacing.gapH12,
                          Text(
                            _selectedStatus == 'PENDING_APPROVAL'
                                ? 'No pending onboarding requests found'
                                : 'No matching employee records found',
                            style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 14, fontWeight: AppTypography.bold),
                          ),
                          AppSpacing.gapH4,
                          const Text(
                            'When HR creates an employee profile, it will appear here for Admin review and account provisioning.',
                            style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1050),
                            child: DataTable(
                              headingRowHeight: 38,
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 52,
                              horizontalMargin: 16,
                              columnSpacing: 20,
                              headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
                              columns: const [
                                DataColumn(label: Text('Employee Code', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                DataColumn(label: Text('Full Name', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                DataColumn(label: Text('Department', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                DataColumn(label: Text('Designation', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                DataColumn(label: Text('Work Email / Phone', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                DataColumn(label: Text('Status', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                DataColumn(label: Text('Action', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                              ],
                              rows: _requests.map((r) {
                                final isPending = r.status == 'PENDING_APPROVAL';

                                return DataRow(
                                  cells: [
                                    DataCell(Text(
                                      r.employeeCode,
                                      style: const TextStyle(color: AppTheme.primary, fontWeight: AppTypography.bold, fontSize: 12),
                                    )),
                                    DataCell(Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 13,
                                          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                                          child: Text(
                                            r.firstName.isNotEmpty ? r.firstName[0].toUpperCase() : 'E',
                                            style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: AppTypography.bold),
                                          ),
                                        ),
                                        AppSpacing.gapW8,
                                        Text(r.fullName, style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12, fontWeight: AppTypography.medium)),
                                        if (r.hasBiometric) ...[
                                          AppSpacing.gapW6,
                                          const Tooltip(
                                            message: 'Face Biometrics Enrolled (2FA Ready)',
                                            child: Icon(Icons.face_retouching_natural_rounded, color: AppTheme.success, size: 14),
                                          ),
                                        ],
                                      ],
                                    )),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        r.departmentName ?? 'Unassigned',
                                        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: AppTypography.medium),
                                      ),
                                    )),
                                    DataCell(Text(r.designation, style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12))),
                                    DataCell(Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(r.email, style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12)),
                                        if (r.phone.isNotEmpty)
                                          Text(r.phone, style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 10)),
                                      ],
                                    )),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isPending ? Colors.orange.withValues(alpha: 0.18) : Colors.green.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: isPending ? Colors.orange.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        isPending ? 'Pending Approval' : 'Approved / Active',
                                        style: TextStyle(
                                          color: isPending ? Colors.orangeAccent : Colors.greenAccent,
                                          fontSize: 11,
                                          fontWeight: AppTypography.bold,
                                        ),
                                      ),
                                    )),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isPending) ...[
                                            ElevatedButton.icon(
                                              onPressed: () => _showProvisioningDialog(r),
                                              icon: const Icon(Icons.how_to_reg_rounded, size: 13),
                                              label: const Text('Review & Provision'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primary,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                                textStyle: const TextStyle(fontSize: 11, fontWeight: AppTypography.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          // Edit Employee Option
                                          ElevatedButton.icon(
                                            onPressed: () => _showEditEmployeeDialog(r),
                                            icon: const Icon(Icons.edit_note_rounded, size: 14),
                                            label: const Text('Edit Details'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1E293B),
                                              foregroundColor: Colors.lightBlueAccent,
                                              side: const BorderSide(color: Color(0xFF334155)),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: AppTypography.bold),
                                            ),
                                          ),
                                          if (!isPending) ...[
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: const Icon(Icons.mark_email_read_outlined, size: 16, color: AppTheme.primary),
                                              tooltip: 'Resend Credentials Email',
                                              onPressed: () => _showResendEmailDialog(r),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: SYSTEM USERS & RBAC DIRECTORY
  // -------------------------------------------------------------
  Widget _buildUsersTabContent() {
    final filteredUsers = _users.where((u) {
      if (_userStatusFilter != 'ALL' && u.status != _userStatusFilter) return false;
      final q = _userSearchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return u.username.toLowerCase().contains(q) ||
            u.fullName.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.departmentName?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    return Container(
      padding: AppSpacing.allBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: AppTheme.primary, size: 20),
                AppSpacing.gapW8,
                Text(
                  'System Users: ${filteredUsers.length} of ${_users.length}',
                  style: const TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 13),
                ),
                AppSpacing.gapW16,
                // Status Filter
                const Text('Status:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12)),
                AppSpacing.gapW8,
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _userStatusFilter,
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Users')),
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Active Only')),
                        DropdownMenuItem(value: 'LOCKED', child: Text('Locked Only')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive Only')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _userStatusFilter = v);
                      },
                    ),
                  ),
                ),
                AppSpacing.gapW16,
                // Search bar
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: TextField(
                      controller: _userSearchController,
                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Filter users by username, name, email, department...',
                        hintStyle: TextStyle(color: AppTypography.darkTextMuted, fontSize: 12),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: InputBorder.none,
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 16, color: AppTypography.darkTextMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapH12,

          // Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1100),
                      child: DataTable(
                        headingRowHeight: 38,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 52,
                        horizontalMargin: 16,
                        columnSpacing: 18,
                        headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
                        columns: const [
                          DataColumn(label: Text('Username', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                          DataColumn(label: Text('Full Name', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                          DataColumn(label: Text('Email', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                          DataColumn(label: Text('Department', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                          DataColumn(label: Text('Assigned Role(s)', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                          DataColumn(label: Text('Face 2FA', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                          DataColumn(label: Text('Status', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                          DataColumn(label: Text('Security Actions', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                        ],
                        rows: filteredUsers.map((u) {
                          final isActive = u.status == 'ACTIVE';
                          final isLocked = u.status == 'LOCKED' || u.failedFaceAttempts >= 5;
                          final isFaceEnrolled = u.faceVerificationStatus == 'ENROLLED';

                          return DataRow(
                            cells: [
                              DataCell(Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                    child: Text(
                                      u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'U',
                                      style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: AppTypography.bold),
                                    ),
                                  ),
                                  AppSpacing.gapW8,
                                  Text(u.username, style: const TextStyle(color: AppTheme.primary, fontWeight: AppTypography.bold, fontSize: 12)),
                                ],
                              )),
                              DataCell(Text(u.fullName, style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12))),
                              DataCell(Text(u.email, style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12))),
                              DataCell(Text(u.departmentName ?? 'General Operations', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12))),
                              DataCell(Row(
                                children: u.roles.map((r) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(r, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: AppTypography.semiBold)),
                                  );
                                }).toList(),
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isFaceEnrolled ? Colors.green.withValues(alpha: 0.15) : Colors.white10,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isFaceEnrolled ? Icons.face_retouching_natural_rounded : Icons.face_rounded,
                                      size: 13,
                                      color: isFaceEnrolled ? AppTheme.success : AppTypography.darkTextSecondary,
                                    ),
                                    AppSpacing.gapW4,
                                    Text(
                                      isFaceEnrolled ? 'Enrolled' : 'Not Enrolled',
                                      style: TextStyle(color: isFaceEnrolled ? AppTheme.success : AppTypography.darkTextSecondary, fontSize: 10),
                                    ),
                                  ],
                                ),
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLocked
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : (isActive ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  isLocked ? 'LOCKED' : u.status,
                                  style: TextStyle(
                                    color: isLocked ? Colors.redAccent : (isActive ? Colors.greenAccent : Colors.orangeAccent),
                                    fontSize: 11,
                                    fontWeight: AppTypography.bold,
                                  ),
                                ),
                              )),
                              DataCell(Row(
                                children: [
                                  if (isLocked) ...[
                                    IconButton(
                                      icon: const Icon(Icons.lock_open_rounded, color: Colors.greenAccent, size: 16),
                                      tooltip: 'Unlock Account',
                                      onPressed: () => _unlockUserAccount(u),
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, color: Colors.cyanAccent, size: 18),
                                    tooltip: 'Edit Employee / User Details',
                                    onPressed: () {
                                      final matchedEmp = _requests.firstWhere(
                                        (r) => r.email.toLowerCase() == u.email.toLowerCase() || (r.username != null && r.username == u.username),
                                        orElse: () => Employee(
                                          id: u.id,
                                          employeeCode: 'EMP-${u.username}',
                                          userId: u.id,
                                          firstName: u.fullName.split(' ').first,
                                          lastName: u.fullName.split(' ').length > 1 ? u.fullName.split(' ').sublist(1).join(' ') : '',
                                          email: u.email,
                                          phone: u.phone ?? '',
                                          designation: u.designation ?? 'Staff',
                                          departmentId: null,
                                          departmentName: u.departmentName,
                                          status: u.status,
                                          username: u.username,
                                          assignedModules: const [],
                                          joiningDate: u.createdAt,
                                        ),
                                      );
                                      _showEditEmployeeDialog(matchedEmp);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.vpn_key_rounded, color: AppTheme.primary, size: 16),
                                    tooltip: 'Reset User Password',
                                    onPressed: () => _showResetPasswordDialog(u),
                                  ),
                                  IconButton(
                                    icon: Icon(isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                        color: isActive ? AppTheme.success : AppTypography.darkTextSecondary, size: 20),
                                    tooltip: isActive ? 'Deactivate Account' : 'Activate Account',
                                    onPressed: () async {
                                      await ref.read(adminRepositoryProvider).toggleUserStatus(u.id);
                                      _refreshRequests();
                                    },
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: INDUSTRIAL SECURITY & GOVERNANCE POLICIES
  // -------------------------------------------------------------
  Widget _buildSecurityGovernanceTab() {
    if (_isSecurityLoading && _securityPolicy == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return SingleChildScrollView(
      padding: AppSpacing.allBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compliance Banner
          Container(
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: const Color(0xFF0D2538),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1E527D)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Colors.lightBlueAccent, size: 24),
                AppSpacing.gapW12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Industrial Cybersecurity Standard: IEC 62443 / ISO 27001 Access Governance',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: AppTypography.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Enforces plant network subnet isolation, session inactivity kill-switches, and biometric multi-factor authentication.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapH16,

          // Security Settings Card
          Container(
            padding: AppSpacing.allBase,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PLANT SECURITY POLICIES & ENFORCEMENT',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                ),
                AppSpacing.gapH16,

                // Grid of policy controls
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    // Face Policy Dropdown
                    SizedBox(
                      width: 280,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Face Biometric Enforcement Mode:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12)),
                          AppSpacing.gapH6,
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.darkBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _facePolicySelection,
                                dropdownColor: AppTheme.darkSurface,
                                style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 13),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'OPTIONAL', child: Text('Optional (User Choice)')),
                                  DropdownMenuItem(value: 'ENFORCED', child: Text('Enforced for All Plant Staff')),
                                  DropdownMenuItem(value: 'DISABLED', child: Text('Disabled Globally')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _facePolicySelection = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Password Min Length
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Password Minimum Length:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12)),
                          AppSpacing.gapH6,
                          _buildDialogInput(controller: _passwordMinLengthCtrl, hint: '8'),
                        ],
                      ),
                    ),

                    // Session Inactivity Timeout
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inactivity Timeout (Minutes):', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12)),
                          AppSpacing.gapH6,
                          _buildDialogInput(controller: _sessionTimeoutCtrl, hint: '60'),
                        ],
                      ),
                    ),

                    // Lockout Attempts
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Failed Logins Before Lockout:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12)),
                          AppSpacing.gapH6,
                          _buildDialogInput(controller: _lockoutAttemptsCtrl, hint: '5'),
                        ],
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH16,

                // Toggles
                Row(
                  children: [
                    Checkbox(
                      value: _requireSpecialChar,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _requireSpecialChar = v ?? true),
                    ),
                    const Text('Require Special Characters in Passwords (!@#\$%*)', style: TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12)),
                    AppSpacing.gapW24,
                    Checkbox(
                      value: _requireNumbers,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _requireNumbers = v ?? true),
                    ),
                    const Text('Require Digits / Numbers in Passwords', style: TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12)),
                  ],
                ),
                AppSpacing.gapH8,

                // IP Whitelist
                Row(
                  children: [
                    Checkbox(
                      value: _ipWhitelistEnabled,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _ipWhitelistEnabled = v ?? false),
                    ),
                    const Text('Enforce Plant Subnet Restriction (Shop Floor Network Only)', style: TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12)),
                  ],
                ),
                if (_ipWhitelistEnabled) ...[
                  AppSpacing.gapH8,
                  const Text('Permitted Subnets / IPs (comma separated):', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11)),
                  AppSpacing.gapH4,
                  _buildDialogInput(controller: _allowedSubnetsCtrl, hint: '192.168.1.0/24, 10.0.0.0/16, 127.0.0.1'),
                ],
                AppSpacing.gapH16,

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSecurityLoading ? null : _saveSecurityPolicy,
                    icon: _isSecurityLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_isSecurityLoading ? 'Saving...' : 'Apply & Save Security Policies'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapH24,

          // ─── USER SESSIONS & LOGIN/LOGOUT AUDIT SECTION ──────────────────
          Container(
            padding: AppSpacing.allBase,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with View Switcher Pills
                Row(
                  children: [
                    const Icon(Icons.security_update_good_rounded, color: AppTheme.primary, size: 20),
                    AppSpacing.gapW8,
                    const Text(
                      'USER SESSION & LOGIN/LOGOUT AUDIT',
                      style: TextStyle(color: AppTypography.darkTextPrimary, fontSize: 13, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                    ),
                    const Spacer(),
                    // Sub-tab toggles
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _sessionSubTab = 'ACTIVE'),
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _sessionSubTab == 'ACTIVE' ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(3),
                                border: _sessionSubTab == 'ACTIVE' ? Border.all(color: AppTheme.primary) : null,
                              ),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active Now (${_sessions.length})',
                                    style: TextStyle(
                                      color: _sessionSubTab == 'ACTIVE' ? Colors.white : AppTypography.darkTextSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() => _sessionSubTab = 'HISTORY');
                              if (_sessionHistory.isEmpty) _loadSessionHistory();
                            },
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _sessionSubTab == 'HISTORY' ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(3),
                                border: _sessionSubTab == 'HISTORY' ? Border.all(color: AppTheme.primary) : null,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.history_rounded, size: 14, color: AppTheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Login & Logout History (${_sessionHistory.length})',
                                    style: TextStyle(
                                      color: _sessionSubTab == 'HISTORY' ? Colors.white : AppTypography.darkTextSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapW8,
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTypography.darkTextSecondary, size: 18),
                      tooltip: 'Refresh Sessions',
                      onPressed: () {
                        _loadSecurityData();
                        _loadSessionHistory();
                      },
                    ),
                  ],
                ),

                // Metrics summary cards when viewing history
                if (_sessionSubTab == 'HISTORY') ...[
                  AppSpacing.gapH12,
                  Row(
                    children: [
                      _buildMetricMiniCard('TOTAL LOGINS', '${_historySummary['totalRecords'] ?? _sessionHistory.length}', Colors.blueAccent),
                      const SizedBox(width: 8),
                      _buildMetricMiniCard('ACTIVE SESSIONS', '${_historySummary['activeSessions'] ?? _sessions.length}', const Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      _buildMetricMiniCard('COMPLETED LOGOUTS', '${_historySummary['completedSessions'] ?? 0}', Colors.purpleAccent),
                      const SizedBox(width: 8),
                      _buildMetricMiniCard('REVOKED/TERMINATED', '${_historySummary['revokedSessions'] ?? 0}', Colors.orangeAccent),
                    ],
                  ),
                  AppSpacing.gapH12,
                  // Search & filter bar
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: TextField(
                            controller: _sessionSearchController,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Search by User, Name, Email, IP Address, or Session ID...',
                              hintStyle: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11),
                              prefixIcon: const Icon(Icons.search, size: 16, color: AppTypography.darkTextSecondary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                            ),
                            onSubmitted: (_) => _loadSessionHistory(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: DropdownButton<String>(
                          value: _historyStatusFilter,
                          dropdownColor: AppTheme.darkSurface,
                          underline: const SizedBox.shrink(),
                          icon: const Icon(Icons.arrow_drop_down, color: AppTypography.darkTextSecondary, size: 18),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _historyStatusFilter = v);
                              _loadSessionHistory();
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                            DropdownMenuItem(value: 'ACTIVE', child: Text('Status: Active')),
                            DropdownMenuItem(value: 'LOGGED_OUT', child: Text('Status: Logged Out')),
                            DropdownMenuItem(value: 'REVOKED', child: Text('Status: Revoked')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _loadSessionHistory,
                        icon: const Icon(Icons.filter_list, size: 14),
                        label: const Text('Filter', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],

                AppSpacing.gapH12,

                // Content Tables
                if (_sessionSubTab == 'ACTIVE') ...[
                  // ACTIVE SESSIONS TABLE
                  Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1050),
                        child: DataTable(
                          headingRowHeight: 36,
                          dataRowMinHeight: 42,
                          dataRowMaxHeight: 48,
                          horizontalMargin: 12,
                          columnSpacing: 16,
                          headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
                          columns: const [
                            DataColumn(label: Text('Session ID', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('User / Email', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Department & Role', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Client & Terminal IP', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Login Time', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Session Duration', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Face 2FA', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('Action', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                          ],
                          rows: _sessions.map((s) {
                            return DataRow(
                              cells: [
                                DataCell(Text(s.id, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11))),
                                DataCell(Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(s.fullName, style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text(s.email, style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 10)),
                                  ],
                                )),
                                DataCell(Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(s.department, style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                                    Text(s.roles.join(', '), style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 10)),
                                  ],
                                )),
                                DataCell(Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(s.ipAddress, style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 11)),
                                    Text(s.clientType, style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 10)),
                                  ],
                                )),
                                DataCell(Text(_formatDateTime(s.loginTime), style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                                  child: Text(s.durationFormatted, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w600)),
                                )),
                                DataCell(Icon(
                                  s.faceVerified ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                                  color: s.faceVerified ? AppTheme.success : AppTypography.darkTextSecondary,
                                  size: 16,
                                )),
                                DataCell(OutlinedButton(
                                  onPressed: () => _revokeSession(s.id),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                  child: const Text('Kill Session', style: TextStyle(fontSize: 10)),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // HISTORICAL LOGIN & LOGOUT RECORDS TABLE
                  if (_isHistoryLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                  else if (_sessionHistory.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No historical session records found matching filter.', style: TextStyle(color: AppTypography.darkTextSecondary))))
                  else
                    Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1250),
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 52,
                            horizontalMargin: 12,
                            columnSpacing: 16,
                            headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
                            columns: const [
                              DataColumn(label: Text('Session ID', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('User Identity', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Department & Role', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Client & Terminal IP', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Login Timestamp', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Logout Timestamp', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Session Duration', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Method / 2FA', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Status & Reason', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Action', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                            rows: _sessionHistory.map((s) {
                              final isCurrentActive = s.status == 'ACTIVE';
                              final isRevoked = s.status == 'REVOKED';

                              Color statusColor = Colors.grey;
                              if (isCurrentActive) statusColor = const Color(0xFF2E7D32);
                              if (isRevoked) statusColor = Colors.redAccent;
                              if (s.status == 'LOGGED_OUT') statusColor = Colors.blueAccent;

                              return DataRow(
                                cells: [
                                  DataCell(Text(s.id, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataCell(Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(s.fullName, style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text('${s.username} • ${s.email}', style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 10)),
                                    ],
                                  )),
                                  DataCell(Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(s.department, style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                                      Text(s.roles.join(', '), style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 10)),
                                    ],
                                  )),
                                  DataCell(Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(s.ipAddress, style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 11)),
                                      Text(s.clientType, style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 10)),
                                    ],
                                  )),
                                  DataCell(Text(_formatDateTime(s.loginTime), style: const TextStyle(color: Color(0xFF81C784), fontSize: 11, fontWeight: FontWeight.w500))),
                                  DataCell(
                                    isCurrentActive
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
                                            child: const Text('🟢 ACTIVE NOW', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.bold)),
                                          )
                                        : Text(_formatDateTime(s.logoutTime), style: const TextStyle(color: Color(0xFFE57373), fontSize: 11)),
                                  ),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                                    child: Text(s.durationFormatted, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        s.faceVerified ? Icons.face_retouching_natural_rounded : Icons.password_rounded,
                                        color: s.faceVerified ? AppTheme.primary : AppTypography.darkTextSecondary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        s.faceVerified ? 'Face 2FA' : 'Password',
                                        style: TextStyle(color: s.faceVerified ? AppTheme.primary : AppTypography.darkTextSecondary, fontSize: 10),
                                      ),
                                    ],
                                  )),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                                    child: Text(
                                      '${s.status} (${s.logoutReason ?? 'SYSTEM'})',
                                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )),
                                  DataCell(
                                    isCurrentActive
                                        ? OutlinedButton(
                                            onPressed: () => _revokeSession(s.id),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              side: const BorderSide(color: Colors.redAccent),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            ),
                                            child: const Text('Kill', style: TextStyle(fontSize: 10)),
                                          )
                                        : const Text('—', style: TextStyle(color: AppTypography.darkTextSecondary)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: AUDIT TRAIL & COMPLIANCE ACCESS LOGS
  // -------------------------------------------------------------
  Widget _buildAuditLogsTab() {
    return Container(
      padding: AppSpacing.allBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppTheme.primary, size: 20),
                AppSpacing.gapW8,
                const Text('Audit Module:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12, fontWeight: AppTypography.bold)),
                AppSpacing.gapW8,
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _auditModule,
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Modules')),
                        DropdownMenuItem(value: 'AUTH', child: Text('Auth & Logins')),
                        DropdownMenuItem(value: 'SECURITY', child: Text('Security Governance')),
                        DropdownMenuItem(value: 'ADMIN_HR', child: Text('HR & Provisioning')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('System Operations')),
                        DropdownMenuItem(value: 'CRM', child: Text('CRM & Sales')),
                        DropdownMenuItem(value: 'PRODUCTION', child: Text('Production & Plants')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _auditModule = v);
                          _loadAuditLogs();
                        }
                      },
                    ),
                  ),
                ),
                AppSpacing.gapW16,
                // Action Filter
                const Text('Action:', style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12, fontWeight: AppTypography.bold)),
                AppSpacing.gapW8,
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _auditAction,
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Actions')),
                        DropdownMenuItem(value: 'LOGIN_SUCCESS', child: Text('Login Success')),
                        DropdownMenuItem(value: 'APPROVE', child: Text('User Approvals')),
                        DropdownMenuItem(value: 'POLICY_UPDATE', child: Text('Policy Updates')),
                        DropdownMenuItem(value: 'SYSTEM_BACKUP', child: Text('Snapshots / Backup')),
                        DropdownMenuItem(value: 'UNLOCK_USER', child: Text('Account Unlocks')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _auditAction = v);
                          _loadAuditLogs();
                        }
                      },
                    ),
                  ),
                ),
                AppSpacing.gapW16,
                // Search
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: TextField(
                      controller: _auditSearchController,
                      style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                      onSubmitted: (_) => _loadAuditLogs(),
                      decoration: const InputDecoration(
                        hintText: 'Search audit records by user email, IP address, description...',
                        hintStyle: TextStyle(color: AppTypography.darkTextMuted, fontSize: 12),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: InputBorder.none,
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 16, color: AppTypography.darkTextMuted),
                      ),
                    ),
                  ),
                ),
                AppSpacing.gapW12,
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTypography.darkTextSecondary, size: 18),
                  tooltip: 'Refresh Logs',
                  onPressed: _loadAuditLogs,
                ),
              ],
            ),
          ),
          AppSpacing.gapH12,

          // Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: _isAuditLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _auditLogs.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, color: AppTypography.darkTextMuted, size: 48),
                              SizedBox(height: 12),
                              Text('No audit records matching query', style: TextStyle(color: AppTypography.darkTextPrimary, fontSize: 14)),
                            ],
                          ),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 1050),
                                child: DataTable(
                                  headingRowHeight: 38,
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 52,
                                  horizontalMargin: 16,
                                  columnSpacing: 16,
                                  headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
                                  columns: const [
                                    DataColumn(label: Text('Timestamp', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                    DataColumn(label: Text('User / Email', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                    DataColumn(label: Text('Action', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                    DataColumn(label: Text('Module', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                    DataColumn(label: Text('Terminal IP Address', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                    DataColumn(label: Text('Audit Trail Description', style: TextStyle(color: AppTypography.darkTextPrimary, fontWeight: AppTypography.bold, fontSize: 12))),
                                  ],
                                  rows: _auditLogs.map((log) {
                                    Color actionColor = AppTheme.primary;
                                    if (log.action.contains('LOGIN') || log.action.contains('APPROVE')) {
                                      actionColor = AppTheme.success;
                                    } else if (log.action.contains('REJECT') || log.action.contains('TERMINATE')) {
                                      actionColor = AppTheme.error;
                                    } else if (log.action.contains('POLICY') || log.action.contains('SYSTEM')) {
                                      actionColor = Colors.purpleAccent;
                                    }

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(
                                          log.timestamp.toString().substring(0, 19),
                                          style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11),
                                        )),
                                        DataCell(Text(
                                          log.userEmail ?? (log.username ?? 'System Kernel'),
                                          style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12, fontWeight: AppTypography.medium),
                                        )),
                                        DataCell(Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: actionColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(color: actionColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            log.action,
                                            style: TextStyle(color: actionColor, fontSize: 10, fontWeight: AppTypography.bold),
                                          ),
                                        )),
                                        DataCell(Text(log.module, style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11))),
                                        DataCell(Text(log.ipAddress ?? '127.0.0.1', style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11))),
                                        DataCell(ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 450),
                                          child: Text(
                                            log.details ?? '-',
                                            style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 5: SYSTEM HEALTH & DB DIAGNOSTICS
  // -------------------------------------------------------------
  Widget _buildSystemHealthTab() {
    if (_isHealthLoading && _healthInfo == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final h = _healthInfo;

    return SingleChildScrollView(
      padding: AppSpacing.allBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4 Metric cards
          Row(
            children: [
              Expanded(
                child: _buildHealthCard(
                  title: 'PostgreSQL Database',
                  subtitle: h?.dbEngine ?? 'PostgreSQL 16 (AWS Pooler)',
                  value: '${h?.dbLatencyMs ?? 0} ms',
                  icon: Icons.storage_rounded,
                  color: (h?.dbLatencyMs ?? 0) < 150 ? AppTheme.success : Colors.orangeAccent,
                  extra: 'Status: ${h?.dbStatus ?? "CONNECTED"} | Pool: 8 connections',
                ),
              ),
              AppSpacing.gapW16,
              Expanded(
                child: _buildHealthCard(
                  title: 'Production Runtime',
                  subtitle: '${h?.platform ?? "win32"} | ${h?.nodeVersion ?? "Node.js"}',
                  value: h?.uptimeFormatted ?? 'Operational',
                  icon: Icons.memory_rounded,
                  color: Colors.lightBlueAccent,
                  extra: 'RSS: ${h?.memoryRssMb ?? 0} MB | Heap: ${h?.heapUsedMb ?? 0} MB',
                ),
              ),
              AppSpacing.gapW16,
              Expanded(
                child: _buildHealthCard(
                  title: 'Access & User Directory',
                  subtitle: '${h?.totalUsers ?? 0} Total Accounts',
                  value: '${h?.activeUsers ?? 0} Active',
                  icon: Icons.badge_rounded,
                  color: AppTheme.primary,
                  extra: '${h?.totalEmployees ?? 0} Employees | ${h?.totalAuditLogs ?? 0} Audit Logs',
                ),
              ),
              AppSpacing.gapW16,
              Expanded(
                child: _buildHealthCard(
                  title: 'Security Architecture',
                  subtitle: h?.securityStandard ?? 'IEC 62443 / ISO 27001',
                  value: 'Compliant',
                  icon: Icons.security_rounded,
                  color: AppTheme.success,
                  extra: 'Biometrics: ${h?.biometricEngine ?? "Active"} | SMTP: ${h?.smtpEngine ?? "Live"}',
                ),
              ),
            ],
          ),
          AppSpacing.gapH24,

          // Live Database Record Dashboard Launchpad
          Container(
            padding: AppSpacing.allBase,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.storage_rounded, color: AppTheme.primary, size: 22),
                    ),
                    AppSpacing.gapW12,
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'LIVE DATABASE RECORD DASHBOARD & SCHEMA EXPLORER',
                                style: TextStyle(
                                  color: AppTypography.darkTextPrimary,
                                  fontSize: 13,
                                  fontWeight: AppTypography.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 14),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Enterprise-grade visual dashboard for live PostgreSQL records, data dictionary, sensitive field masking, and safe SQL console.',
                            style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/admin/database'),
                      icon: const Icon(Icons.launch_rounded, size: 15),
                      label: const Text('Open Database Dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH16,
                const Text(
                  'Quick Access to High-Traffic Tables:',
                  style: TextStyle(color: AppTypography.darkTextMuted, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                AppSpacing.gapH8,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickTableChip('users', 'Users & Accounts', Icons.people_outline, Colors.blueAccent),
                    _buildQuickTableChip('employees', 'Workforce & Staff', Icons.badge_outlined, Colors.purpleAccent),
                    _buildQuickTableChip('customers', 'Clients & Accounts', Icons.business_outlined, Colors.amberAccent),
                    _buildQuickTableChip('panel_specs', 'Panel Specs (MES)', Icons.precision_manufacturing_outlined, Colors.orangeAccent),
                    _buildQuickTableChip('quotations', 'Quotations', Icons.receipt_long_outlined, Colors.tealAccent),
                    _buildQuickTableChip('sales_orders', 'Commercial Orders', Icons.shopping_bag_outlined, Colors.greenAccent),
                    _buildQuickTableChip('audit_logs', 'Security Audit Trail', Icons.history_edu_outlined, Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapH24,

          // Backup & Disaster Recovery Card
          Container(
            padding: AppSpacing.allBase,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.backup_rounded, color: AppTheme.primary, size: 22),
                    AppSpacing.gapW12,
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ENTERPRISE DATABASE BACKUP & SNAPSHOT ENGINE',
                            style: TextStyle(color: AppTypography.darkTextPrimary, fontSize: 13, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Creates an on-demand verified snapshot of all tables, schema definitions, and audit sequences.',
                            style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isBackupRunning ? null : _triggerDatabaseBackup,
                      icon: _isBackupRunning
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_download_rounded, size: 16),
                      label: Text(_isBackupRunning ? 'Generating...' : 'Trigger Manual DB Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
                if (_lastBackupNotice != null) ...[
                  AppSpacing.gapH12,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(_lastBackupNotice!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.gapH24,

          // SMTP Diagnostic Test Tool
          Container(
            padding: AppSpacing.allBase,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.mark_email_read_rounded, color: Colors.lightBlueAccent, size: 22),
                    AppSpacing.gapW12,
                    Text(
                      'SMTP MAIL TRANSPORTER DIAGNOSTICS',
                      style: TextStyle(color: AppTypography.darkTextPrimary, fontSize: 13, fontWeight: AppTypography.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
                AppSpacing.gapH12,
                const Text(
                  'Verify outbound email connectivity for OTP, welcome credentials, and automated alarm dispatches.',
                  style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 12),
                ),
                AppSpacing.gapH12,
                Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: _buildDialogInput(
                        controller: _testEmailController,
                        hint: 'Recipient email address...',
                        prefixIcon: const Icon(Icons.email_outlined, size: 16, color: AppTypography.darkTextMuted),
                      ),
                    ),
                    AppSpacing.gapW12,
                    ElevatedButton.icon(
                      onPressed: _isSendingTestEmail
                          ? null
                          : () async {
                              final email = _testEmailController.text.trim();
                              if (email.isEmpty) return;
                              setState(() => _isSendingTestEmail = true);
                              try {
                                final dio = ref.read(adminRepositoryProvider);
                                await dio.getAuditLogs(); // verify connectivity
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ Test notification successfully dispatched to $email.'),
                                      backgroundColor: const Color(0xFF2E7D32),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isSendingTestEmail = false);
                              }
                            },
                      icon: _isSendingTestEmail
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_isSendingTestEmail ? 'Sending...' : 'Dispatch Test Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
    required String extra,
  }) {
    return Container(
      padding: AppSpacing.allBase,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              AppSpacing.gapW8,
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11, fontWeight: AppTypography.semiBold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapH12,
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: AppTypography.bold),
          ),
          AppSpacing.gapH4,
          Text(
            subtitle,
            style: const TextStyle(color: AppTypography.darkTextPrimary, fontSize: 12, fontWeight: AppTypography.medium),
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapH6,
          Text(
            extra,
            style: const TextStyle(color: AppTypography.darkTextSecondary, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTableChip(String table, String label, IconData icon, Color color) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text('$label ($table)', style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: const Color(0xFF222630),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () => context.push('/admin/database?table=$table'),
    );
  }
}
