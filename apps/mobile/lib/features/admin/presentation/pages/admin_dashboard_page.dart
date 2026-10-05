import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';
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
  String? _errorMessage;

  // Filters
  String _selectedDeptId = 'ALL';
  String _selectedStatus = 'PENDING_APPROVAL';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
      final users = await repo.getUsers();
      if (mounted) {
        setState(() {
          _requests = reqs;
          _users = users;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showProvisioningDialog(Employee employee) {
    // Find initial department ID
    String? initialDeptId = employee.departmentId;
    if (initialDeptId == null || !_departments.any((d) => d.id == initialDeptId)) {
      if (_departments.isNotEmpty) {
        initialDeptId = _departments.first.id;
      }
    }

    // Suggested username: firstname.lastname or email prefix
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

    // Default to R&D role or Employee role if available
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
                      color: const Color(0xFFF26522).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFFF26522), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review & Provision Employee Account',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Assign department, set login credentials, and grant system role',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
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
                                color: Colors.orange.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.orange.withOpacity(0.4)),
                              ),
                              child: const Text(
                                'Pending Approval',
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w600),
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
                            value: _departments.any((d) => d.id == selectedDeptId) ? selectedDeptId : null,
                            dropdownColor: const Color(0xFF1E2024),
                            hint: const Text('Select Department', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: _departments.map((d) {
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
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
                                  hint: 'At least 6 characters',
                                  obscureText: obscurePassword,
                                  prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.white38),
                                  suffixIcon: IconButton(
                                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.white54),
                                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                            value: _roles.any((r) => r.id == selectedRoleId) ? selectedRoleId : null,
                            dropdownColor: const Color(0xFF1E2024),
                            hint: const Text('Select System Role', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: _roles.map((r) {
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
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            final repo = ref.read(adminRepositoryProvider);
                            await repo.rejectEmployeeRequest(employee.id);
                            if (mounted) {
                              Navigator.pop(ctx);
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
                          final designation = desigCtrl.text.trim();

                          if (username.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Username and password are required')),
                            );
                            return;
                          }

                          if (password.length < 6) {
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
                              password: password,
                              departmentId: selectedDeptId.isNotEmpty ? selectedDeptId : null,
                              roleIds: selectedRoleId != null ? [selectedRoleId!] : null,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '✅ Employee ${employee.fullName} approved!\nUser account "$username" created with assigned department and role.',
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
                                  content: Text('Failed to approve employee: $errorMsg'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(isSubmitting ? 'Provisioning...' : 'Approve & Create Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF26522),
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
                        children: [
                          _buildRequestsTabContent(),
                          _buildUsersTabContent(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(int pendingCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024),
        border: Border(bottom: BorderSide(color: Color(0xFF26282E))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF26522).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF26522), size: 24),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Management & User Provisioning',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2),
              ),
              SizedBox(height: 3),
              Text(
                'Approve HR onboarding requests, assign departments, and generate user login credentials',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
          const Spacer(),
          // Pending Requests Counter Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pendingCount > 0 ? const Color(0xFFF26522).withOpacity(0.15) : Colors.white10,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: pendingCount > 0 ? const Color(0xFFF26522).withOpacity(0.4) : Colors.white24),
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
          const SizedBox(width: 8),
          IconButton(
            onPressed: _refreshRequests,
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: EMPLOYEE REQUESTS WITH DEPARTMENT FILTERING
  // -------------------------------------------------------------
  Widget _buildRequestsTabContent() {
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
            child: Row(
              children: [
                // Department Filter Dropdown (Crucial for the user prompt scenario: R&D, Sales, etc.)
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
                      value: _selectedDeptId,
                      dropdownColor: const Color(0xFF1E2024),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Departments')),
                        ..._departments.map((d) {
                          // Count how many requests in this department
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
                const SizedBox(width: 16),

                // Status Filter
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
                      value: _selectedStatus,
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
                const SizedBox(width: 16),

                // Search Bar
                Expanded(
                  child: Container(
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
                        prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Requests Table
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
                                          backgroundColor: const Color(0xFFF26522).withOpacity(0.2),
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
                                        color: Colors.blue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                                        color: isPending ? Colors.orange.withOpacity(0.18) : Colors.green.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: isPending ? Colors.orange.withOpacity(0.4) : Colors.green.withOpacity(0.4)),
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
                                      isPending
                                          ? ElevatedButton.icon(
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
                                          : Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.06),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                                  SizedBox(width: 4),
                                                  Text('User Created', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                                ],
                                              ),
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
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
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
                                      color: Colors.purple.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                    ),
                                    child: Text(r, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                                  );
                                }).toList(),
                              )),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
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
        ],
      ),
    );
  }
}
