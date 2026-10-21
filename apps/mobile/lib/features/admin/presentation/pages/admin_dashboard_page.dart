import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';
import 'package:saark_erp_mobile/features/admin/presentation/pages/admin_organization_page.dart';
import 'package:saark_erp_mobile/features/admin/presentation/pages/admin_employee_access_page.dart';
import 'package:saark_erp_mobile/features/admin/presentation/pages/admin_audit_logs_page.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Requests state
  List<Employee> _requests = [];
  List<DepartmentItem> _departments = [];
  List<RoleItem> _roles = [];
  List<AdminUserItem> _users = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  // Scroll controllers for requests table (vertical + horizontal)
  final ScrollController _requestsVerticalScroll = ScrollController();
  final ScrollController _requestsHorizontalScroll = ScrollController();

  // Scroll controllers for users table (vertical + horizontal)
  final ScrollController _usersVerticalScroll = ScrollController();
  final ScrollController _usersHorizontalScroll = ScrollController();

  // Filters
  String _selectedDeptId = 'ALL';
  String _selectedStatus = 'PENDING_APPROVAL';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _requestsVerticalScroll.dispose();
    _requestsHorizontalScroll.dispose();
    _usersVerticalScroll.dispose();
    _usersHorizontalScroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final deptsFuture = repo.getDepartments();
      final rolesFuture = repo.getRoles();
      final reqsFuture = repo.getEmployeeRequests(
        departmentId: _selectedDeptId,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );
      final usersFuture = repo.getUsers();

      final results = await Future.wait([
        deptsFuture,
        rolesFuture,
        reqsFuture,
        usersFuture,
      ]).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _departments = results[0] as List<DepartmentItem>;
          _roles = results[1] as List<RoleItem>;
          _requests = results[2] as List<Employee>;
          _users = results[3] as List<AdminUserItem>;
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
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final repo = ref.read(adminRepositoryProvider);
      final reqsFuture = repo.getEmployeeRequests(
        departmentId: _selectedDeptId,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );
      final usersFuture = repo.getUsers();

      final results = await Future.wait([
        reqsFuture,
        usersFuture,
        if (_departments.isEmpty) repo.getDepartments(),
        if (_roles.isEmpty) repo.getRoles(),
      ]).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _requests = results[0] as List<Employee>;
          _users = results[1] as List<AdminUserItem>;
          if (_departments.isEmpty && results.length > 2) {
            _departments = results[2] as List<DepartmentItem>;
          }
          if (_roles.isEmpty && results.length > 3) {
            _roles = results[3] as List<RoleItem>;
          }
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Show reset-password-only dialog for already-provisioned employees
  void _showResetPasswordDialog(Employee employee) {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2024),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Color(0xFF2C2E33)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.lock_reset, color: Colors.blueAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reset Employee Password',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${employee.fullName} (${employee.employeeCode})',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: min(420.0, MediaQuery.of(context).size.width - 32),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                        ),
                        child: const Text(
                          '⚠️ This will immediately change the employee login password. The employee must use the new password on next login.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('New Password (min 8 characters):',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 6),
                      _buildDialogInput(
                        controller: newPassCtrl,
                        hint: 'Enter new password',
                        obscureText: obscureNew,
                        prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.white38),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility,
                              size: 16, color: Colors.white54),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Confirm New Password:',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 6),
                      _buildDialogInput(
                        controller: confirmPassCtrl,
                        hint: 'Re-enter new password',
                        obscureText: obscureConfirm,
                        prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.white38),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              size: 16, color: Colors.white54),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final np = newPassCtrl.text.trim();
                          final cp = confirmPassCtrl.text.trim();
                          if (np.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password must be at least 8 characters')),
                            );
                            return;
                          }
                          if (np != cp) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          try {
                            final repo = ref.read(adminRepositoryProvider);
                            await repo.resetEmployeePassword(employee.id, newPassword: np)
                                .timeout(const Duration(seconds: 20));
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🔑 Password reset for ${employee.fullName}'),
                                  backgroundColor: Colors.blueAccent[700],
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } catch (err) {
                            setDialogState(() => isSubmitting = false);
                            String errorMsg = err.toString();
                            if (err is DioException && err.response?.data != null) {
                              final d = err.response!.data;
                              if (d is Map && d['message'] != null) errorMsg = d['message'].toString();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reset failed: $errorMsg'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_reset, size: 16),
                  label: Text(isSubmitting ? 'Resetting...' : 'Reset Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent[700],
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

  void _showProvisioningDialog(Employee employee) {
    // Detect whether this employee already has a provisioned user account
    final bool alreadyProvisioned = employee.userId != null && employee.userId!.isNotEmpty;

    // Deduplicate departments and roles to avoid dropdown crashes
    final seenDeptIds = <String>{};
    final uniqueDepts = <DepartmentItem>[];
    for (final d in _departments) {
      if (d.id.isNotEmpty && d.id != 'ALL' && seenDeptIds.add(d.id)) {
        uniqueDepts.add(d);
      }
    }

    final seenRoleIds = <String>{};
    final uniqueRoles = <RoleItem>[];
    for (final r in _roles) {
      if (r.id.isNotEmpty && seenRoleIds.add(r.id)) {
        uniqueRoles.add(r);
      }
    }

    // Find initial department ID
    String? initialDeptId = employee.departmentId;
    if (initialDeptId == null || !uniqueDepts.any((d) => d.id == initialDeptId)) {
      if (uniqueDepts.isNotEmpty) {
        initialDeptId = uniqueDepts.first.id;
      }
    }

    // Suggested username: match existing user account if linked, else email prefix
    final existingUser = employee.userId != null
        ? _users.where((u) => u.id == employee.userId).firstOrNull
        : null;

    String suggestedUsername = '';
    if (existingUser != null && existingUser.username.isNotEmpty) {
      suggestedUsername = existingUser.username;
    } else {
      suggestedUsername = employee.email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]'), '');
      if (suggestedUsername.isEmpty) {
        suggestedUsername = '${employee.firstName.toLowerCase()}.${employee.lastName.toLowerCase()}';
      }
    }

    final usernameCtrl = TextEditingController(text: suggestedUsername);
    final passwordCtrl = TextEditingController(text: alreadyProvisioned ? '' : 'Saark@2026');
    final desigCtrl = TextEditingController(text: employee.designation);
    String selectedDeptId = initialDeptId ?? '';
    String? selectedRoleId = uniqueRoles.isNotEmpty ? uniqueRoles.first.id : null;
    bool obscurePassword = false;
    bool isSubmitting = false;

    // Pre-select existing role or default to R&D / Employee role
    if (existingUser != null && existingUser.roles.isNotEmpty) {
      final matchingRole = uniqueRoles.where((r) => existingUser.roles.contains(r.name) || existingUser.roles.contains(r.code)).firstOrNull;
      if (matchingRole != null) {
        selectedRoleId = matchingRole.id;
      }
    } else {
      final defaultRole = uniqueRoles.firstWhere(
        (r) => r.code == 'ROLE_EMPLOYEE' || r.code == 'ROLE_RND_ENG',
        orElse: () => uniqueRoles.isNotEmpty ? uniqueRoles.first : RoleItem(id: '', name: 'Standard Employee', code: 'ROLE_EMPLOYEE'),
      );
      if (defaultRole.id.isNotEmpty) {
        selectedRoleId = defaultRole.id;
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2024),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Color(0xFF2C2E33)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (alreadyProvisioned ? Colors.teal : const Color(0xFFF26522)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      alreadyProvisioned ? Icons.manage_accounts : Icons.verified_user_rounded,
                      color: alreadyProvisioned ? Colors.tealAccent : const Color(0xFFF26522),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alreadyProvisioned ? 'Manage Employee Account' : 'Review & Provision Employee Account',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alreadyProvisioned
                              ? 'Update department, username, role — leave password blank to keep existing'
                              : 'Assign department, set login credentials, and grant system role',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: min(580.0, MediaQuery.of(context).size.width - 32),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Employee Summary Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141517),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF26282E)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFF26522),
                              child: Text(
                                employee.firstName.isNotEmpty ? employee.firstName[0].toUpperCase() : 'E',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee.fullName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Code: ${employee.employeeCode}  •  Email: ${employee.email}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  if (employee.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Phone: ${employee.phone}',
                                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: alreadyProvisioned
                                    ? Colors.teal.withValues(alpha: 0.18)
                                    : Colors.orange.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: alreadyProvisioned
                                      ? Colors.teal.withValues(alpha: 0.4)
                                      : Colors.orange.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                alreadyProvisioned ? 'Account Exists' : 'Pending Approval',
                                style: TextStyle(
                                  color: alreadyProvisioned ? Colors.tealAccent : Colors.orangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Department Assignment (Matches user scenario, e.g. Research and Development)
                      const Text(
                        '1. ASSIGN / CONFIRM DEPARTMENT',
                        style: TextStyle(color: Color(0xFFF26522), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141517),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF2C2E33)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: uniqueDepts.any((d) => d.id == selectedDeptId) ? selectedDeptId : null,
                            dropdownColor: const Color(0xFF1E2024),
                            hint: const Text('Select Department', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: uniqueDepts.map((d) {
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text('${d.name} (${d.code})'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedDeptId = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Designation
                      const Text(
                        '2. DESIGNATION',
                        style: TextStyle(color: Color(0xFFF26522), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      _buildDialogInput(controller: desigCtrl, hint: 'e.g. Junior Design Engineer / R&D Specialist'),
                      const SizedBox(height: 16),

                      // Credentials: Username & Password
                      const Text(
                        '3. SET LOGIN USERNAME & PASSWORD',
                        style: TextStyle(color: Color(0xFFF26522), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isNarrow = constraints.maxWidth < 420;
                          final usernameField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Login Username:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 4),
                              _buildDialogInput(
                                controller: usernameCtrl,
                                hint: 'e.g. aditya.k',
                                prefixIcon: const Icon(Icons.person_outline, size: 16, color: Colors.white38),
                              ),
                            ],
                          );

                          final passwordField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Login Password:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {
                                      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
                                      final rand = Random();
                                      final generated = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
                                      setDialogState(() {
                                        passwordCtrl.text = generated;
                                        obscurePassword = false;
                                      });
                                    },
                                    child: const Text('Generate', style: TextStyle(color: Color(0xFFF26522), fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _buildDialogInput(
                                controller: passwordCtrl,
                                hint: alreadyProvisioned ? 'Blank to keep existing' : 'At least 6 characters',
                                obscureText: obscurePassword,
                                prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.white38),
                                suffixIcon: IconButton(
                                  icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.white54),
                                  onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                ),
                              ),
                            ],
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                usernameField,
                                const SizedBox(height: 12),
                                passwordField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: usernameField),
                              const SizedBox(width: 12),
                              Expanded(child: passwordField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // System Role Assignment
                      const Text(
                        '4. ASSIGN SYSTEM ROLE & ACCESS PERMISSION',
                        style: TextStyle(color: Color(0xFFF26522), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141517),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF2C2E33)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: uniqueRoles.any((r) => r.id == selectedRoleId) ? selectedRoleId : null,
                            dropdownColor: const Color(0xFF1E2024),
                            hint: const Text('Select System Role', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: uniqueRoles.map((r) {
                              return DropdownMenuItem<String>(
                                value: r.id,
                                child: Text('${r.name} (${r.code})'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedRoleId = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Grants permissions to view modules, projects, task boards, and ERP sections.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              actionsAlignment: alreadyProvisioned ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
              actionsOverflowAlignment: OverflowBarAlignment.end,
              actions: [
                if (alreadyProvisioned)
                  OutlinedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _showResetPasswordDialog(employee);
                          },
                    icon: const Icon(Icons.lock_reset, size: 15, color: Colors.blueAccent),
                    label: const Text('Reset Password', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    if (!alreadyProvisioned)
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setDialogState(() => isSubmitting = true);
                                try {
                                  final repo = ref.read(adminRepositoryProvider);
                                  await repo.rejectEmployeeRequest(employee.id)
                                      .timeout(const Duration(seconds: 20));
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Employee request ${employee.employeeCode} rejected.'),
                                        backgroundColor: Colors.redAccent,
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $errorMsg'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                        child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ElevatedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final username = usernameCtrl.text.trim();
                              final password = passwordCtrl.text.trim();

                              if (username.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Username is required')),
                                );
                                return;
                              }

                              if (!alreadyProvisioned && password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password is required for account creation')),
                                );
                                return;
                              }

                              if (password.isNotEmpty && password.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password must be at least 6 characters')),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);

                              try {
                                final repo = ref.read(adminRepositoryProvider);
                                await repo.approveEmployeeRequest(
                                  employee.id,
                                  username: username,
                                  password: password.isNotEmpty ? password : null,
                                  departmentId: selectedDeptId.isNotEmpty ? selectedDeptId : null,
                                  roleIds: selectedRoleId != null ? [selectedRoleId!] : null,
                                ).timeout(const Duration(seconds: 20));

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        alreadyProvisioned
                                            ? '✅ Employee ${employee.fullName} account details updated successfully!'
                                            : '✅ Employee ${employee.fullName} approved!\nUser account "$username" created with assigned department and role.',
                                      ),
                                      backgroundColor: Colors.green[800],
                                      duration: const Duration(seconds: 4),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $errorMsg'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(alreadyProvisioned ? Icons.save_outlined : Icons.check_circle_outline, size: 16),
                      label: Text(
                        isSubmitting
                            ? (alreadyProvisioned ? 'Saving...' : 'Provisioning...')
                            : (alreadyProvisioned ? 'Update Employee Details' : 'Approve & Create Account'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alreadyProvisioned ? Colors.teal[700] : const Color(0xFFF26522),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
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
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: InputBorder.none,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests.where((r) => r.status == 'PENDING_APPROVAL').length;

    return Scaffold(
      backgroundColor: const Color(0xFF141517),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeaderBar(pendingCount),

          // Main Tabs: Requests vs Users
          Container(
            color: const Color(0xFF1E2024),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFF26522),
              indicatorWeight: 3,
              labelColor: const Color(0xFFF26522),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.how_to_reg_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Text('Employee Onboarding Requests'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF26522),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Employee Access Management'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('System Users (${_users.length})'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Organization'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Security & Audit Logs'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26522)))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadInitialData,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF26522)),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildRequestsTabContent(),
                          const AdminEmployeeAccessPage(),
                          _buildUsersTabContent(),
                          const AdminOrganizationPage(),
                          const AdminAuditLogsPage(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(int pendingCount) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final titleSection = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF26522).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF26522), size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Management & User Provisioning',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3),
              Text(
                'Approve HR onboarding requests, assign departments, and generate user login credentials',
                style: TextStyle(fontSize: 11, color: Colors.white60),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    final actionsSection = Row(
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: isMobile ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _selectedStatus = 'PENDING_APPROVAL';
              _selectedDeptId = 'ALL';
            });
            _tabController.animateTo(0);
            _refreshRequests();
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pendingCount > 0 ? const Color(0xFFF26522).withValues(alpha: 0.15) : Colors.white10,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: pendingCount > 0 ? const Color(0xFFF26522).withValues(alpha: 0.4) : Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  color: pendingCount > 0 ? const Color(0xFFF26522) : Colors.white60,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '$pendingCount Pending Requests',
                  style: TextStyle(
                    color: pendingCount > 0 ? const Color(0xFFF26522) : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _isRefreshing ? null : _refreshRequests,
          tooltip: 'Refresh Data',
          icon: _isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF26522)),
                )
              : const Icon(Icons.refresh_rounded, color: Colors.white70),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024),
        border: Border(bottom: BorderSide(color: Color(0xFF26282E))),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleSection,
                const SizedBox(height: 12),
                actionsSection,
              ],
            )
          : Row(
              children: [
                Expanded(child: titleSection),
                const SizedBox(width: 16),
                actionsSection,
              ],
            ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: EMPLOYEE REQUESTS WITH DEPARTMENT FILTERING
  // -------------------------------------------------------------
  Widget _buildRequestsTabContent() {
    // Deduplicate departments by ID and exclude 'ALL' to prevent duplicate dropdown items
    final seenDeptIds = <String>{};
    final uniqueDepts = <DepartmentItem>[];
    for (final d in _departments) {
      if (d.id != 'ALL' && seenDeptIds.add(d.id)) {
        uniqueDepts.add(d);
      }
    }
    final isSelectedDeptValid = _selectedDeptId == 'ALL' || uniqueDepts.any((d) => d.id == _selectedDeptId);
    final effectiveDeptId = isSelectedDeptValid ? _selectedDeptId : 'ALL';

    const validStatuses = ['PENDING_APPROVAL', 'ACTIVE', 'ALL'];
    final effectiveStatus = validStatuses.contains(_selectedStatus) ? _selectedStatus : 'PENDING_APPROVAL';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar: Department Dropdown + Search + Status Switch
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2024),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF26282E)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 700;

                final deptWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Department:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141517),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF2C2E33)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: effectiveDeptId,
                          dropdownColor: const Color(0xFF1E2024),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          items: [
                            const DropdownMenuItem(value: 'ALL', child: Text('All Departments')),
                            ...uniqueDepts.map((d) {
                              final count = _requests.where((r) => r.departmentId == d.id && r.status == 'PENDING_APPROVAL').length;
                              return DropdownMenuItem(
                                value: d.id,
                                child: Text(count > 0 ? '${d.name} ($count req)' : d.name),
                              );
                            }),
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
                  ],
                );

                final statusWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Status:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141517),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF2C2E33)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: effectiveStatus,
                          dropdownColor: const Color(0xFF1E2024),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          items: const [
                            DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('Pending Approval')),
                            DropdownMenuItem(value: 'ACTIVE', child: Text('Approved / Active')),
                            DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
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
                  ],
                );

                final searchWidget = Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141517),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFF2C2E33)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    onSubmitted: (_) => _refreshRequests(),
                    decoration: InputDecoration(
                      hintText: 'Search by employee name, code, email...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: InputBorder.none,
                      isDense: true,
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.search, size: 16, color: Colors.white38),
                        onPressed: _refreshRequests,
                        tooltip: 'Search',
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14, color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                _refreshRequests();
                              },
                            )
                          : null,
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          deptWidget,
                          statusWidget,
                        ],
                      ),
                      const SizedBox(height: 10),
                      searchWidget,
                    ],
                  );
                }

                return Row(
                  children: [
                    deptWidget,
                    const SizedBox(width: 16),
                    statusWidget,
                    const SizedBox(width: 16),
                    Expanded(child: searchWidget),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Requests Table with explicit dual ScrollControllers
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2024),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF26282E)),
              ),
              child: _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_outlined, color: Colors.white24, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _selectedStatus == 'PENDING_APPROVAL'
                                ? 'No pending onboarding requests found'
                                : 'No matching employee records found',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'When HR creates an employee profile, it will appear here for Admin review and account provisioning.',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      controller: _requestsVerticalScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _requestsVerticalScroll,
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          controller: _requestsHorizontalScroll,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _requestsHorizontalScroll,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 1050),
                              child: DataTable(
                              headingRowHeight: 38,
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 52,
                              horizontalMargin: 16,
                              columnSpacing: 20,
                              headingRowColor: WidgetStateProperty.all(const Color(0xFF17181A)),
                              columns: const [
                                DataColumn(label: Text('Employee Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Full Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Designation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Work Email / Phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                              rows: _requests.map((r) {
                                final isPending = r.status == 'PENDING_APPROVAL';

                                return DataRow(
                                  cells: [
                                    DataCell(Text(
                                      r.employeeCode,
                                      style: const TextStyle(color: Color(0xFFF26522), fontWeight: FontWeight.bold, fontSize: 12),
                                    )),
                                    DataCell(Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 13,
                                          backgroundColor: const Color(0xFFF26522).withValues(alpha: 0.2),
                                          child: Text(
                                            r.firstName.isNotEmpty ? r.firstName[0].toUpperCase() : 'E',
                                            style: const TextStyle(color: Color(0xFFF26522), fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(r.fullName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
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
                                        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    )),
                                    DataCell(Text(r.designation, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                    DataCell(Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(r.email, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                        if (r.phone.isNotEmpty)
                                          Text(r.phone, style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isPending && (r.userId == null || r.userId!.isEmpty))
                                            ElevatedButton.icon(
                                              onPressed: () => _showProvisioningDialog(r),
                                              icon: const Icon(Icons.how_to_reg_rounded, size: 14),
                                              label: const Text('Review & Provision User'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFF26522),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            )
                                          else ...[
                                            ElevatedButton.icon(
                                              onPressed: () => _showProvisioningDialog(r),
                                              icon: const Icon(Icons.manage_accounts, size: 14),
                                              label: const Text('Manage Account'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.teal[800],
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton.icon(
                                              onPressed: () => _showResetPasswordDialog(r),
                                              icon: const Icon(Icons.lock_reset, size: 14, color: Colors.blueAccent),
                                              label: const Text('Reset Password', style: TextStyle(color: Colors.blueAccent)),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
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
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: SYSTEM USERS DIRECTORY
  // -------------------------------------------------------------
  Widget _buildUsersTabContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2024),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF26282E)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_rounded, color: Color(0xFFF26522), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Total System Accounts: ${_users.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2024),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF26282E)),
              ),
              child: Scrollbar(
                controller: _usersVerticalScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _usersVerticalScroll,
                  scrollDirection: Axis.vertical,
                  child: Scrollbar(
                    controller: _usersHorizontalScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _usersHorizontalScroll,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 950),
                        child: DataTable(
                        headingRowHeight: 38,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 48,
                        horizontalMargin: 16,
                        columnSpacing: 20,
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF17181A)),
                        columns: const [
                          DataColumn(label: Text('Username', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Full Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Role(s)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: _users.map((u) {
                          final isActive = u.status == 'ACTIVE';
                          return DataRow(
                            cells: [
                              DataCell(Text(u.username, style: const TextStyle(color: Color(0xFFF26522), fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(Text(u.fullName, style: const TextStyle(color: Colors.white, fontSize: 12))),
                              DataCell(Text(u.email, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                              DataCell(Text(u.departmentName ?? 'General', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12))),
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
                                    child: Text(r, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                                  );
                                }).toList(),
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  u.status,
                                  style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
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
        ),
        ],
      ),
    );
  }
}
