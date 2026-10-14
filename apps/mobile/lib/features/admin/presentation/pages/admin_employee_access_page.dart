import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';

class AdminEmployeeAccessPage extends ConsumerStatefulWidget {
  const AdminEmployeeAccessPage({super.key});

  @override
  ConsumerState<AdminEmployeeAccessPage> createState() => _AdminEmployeeAccessPageState();
}

class _AdminEmployeeAccessPageState extends ConsumerState<AdminEmployeeAccessPage> {
  // Employee list state
  List<Map<String, dynamic>> _employees = [];
  bool _isLoadingList = true;
  String? _listError;
  int _currentPage = 1;
  int _totalPages = 1;
  final TextEditingController _searchCtrl = TextEditingController();

  // Selected employee detail state
  String? _selectedEmployeeId;
  Map<String, dynamic>? _selectedDetail;
  bool _isLoadingDetail = false;
  String? _detailError;

  // Staged modifications: Map<permissionId, { effect: 'ALLOW' | 'DENY' | 'INHERIT', reason?: string }>
  final Map<String, Map<String, dynamic>> _stagedOverrides = {};

  // Module filter in permission matrix
  String _matrixFilter = '';

  @override
  void initState() {
    super.initState();
    _fetchEmployeeList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployeeList({int page = 1}) async {
    setState(() {
      _isLoadingList = true;
      _listError = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.getEmployeesAccessList(
        page: page,
        limit: 20,
        search: _searchCtrl.text.trim(),
      );

      final list = (res['employees'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      final meta = res['meta'] as Map<String, dynamic>? ?? {};

      setState(() {
        _employees = list;
        _currentPage = meta['page'] ?? 1;
        _totalPages = meta['totalPages'] ?? 1;
        _isLoadingList = false;
      });

      // Automatically select first employee if none selected
      if (_selectedEmployeeId == null && list.isNotEmpty) {
        _selectEmployee(list.first['id']);
      }
    } catch (e) {
      setState(() {
        _listError = e.toString();
        _isLoadingList = false;
      });
    }
  }

  Future<void> _selectEmployee(String employeeId) async {
    if (_stagedOverrides.isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2024),
          title: const Text('Unsaved Changes', style: TextStyle(color: Colors.white)),
          content: const Text(
            'You have unsaved permission changes for the current employee. Do you want to discard them?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF26522)),
              child: const Text('Discard & Switch'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }

    setState(() {
      _selectedEmployeeId = employeeId;
      _stagedOverrides.clear();
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.getEmployeeAccessDetail(employeeId);
      if (mounted) {
        setState(() {
          _selectedDetail = res;
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _detailError = e.toString();
          _isLoadingDetail = false;
        });
      }
    }
  }

  void _stagePermissionChange(String permId, String? currentOverride, bool inherited, String newEffect) {
    setState(() {
      // If newEffect equals current override, remove from staged
      final existingOverride = currentOverride ?? 'INHERIT';
      if (newEffect == existingOverride) {
        _stagedOverrides.remove(permId);
      } else {
        _stagedOverrides[permId] = {
          'permissionId': permId,
          'effect': newEffect,
        };
      }
    });
  }

  void _stageModuleBulk(Map<String, dynamic> moduleData, String targetEffect) {
    final permissions = (moduleData['permissions'] as List? ?? []).map((p) => Map<String, dynamic>.from(p)).toList();
    setState(() {
      for (final p in permissions) {
        final permId = p['id'] as String;
        final currentOverride = p['override'] as String? ?? 'INHERIT';
        if (targetEffect == currentOverride) {
          _stagedOverrides.remove(permId);
        } else {
          _stagedOverrides[permId] = {
            'permissionId': permId,
            'effect': targetEffect,
          };
        }
      }
    });
  }

  void _showSaveConfirmationDialog() {
    if (_stagedOverrides.isEmpty || _selectedDetail == null) return;

    final reasonCtrl = TextEditingController();
    final allPerms = <String, Map<String, dynamic>>{};
    final modules = (_selectedDetail!['modules'] as List? ?? []);
    for (final m in modules) {
      for (final p in (m['permissions'] as List? ?? [])) {
        allPerms[p['id']] = Map<String, dynamic>.from(p);
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
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
                      color: const Color(0xFFF26522).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.security_update_good, color: Color(0xFFF26522), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm Permission Overrides',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Review and apply effective access changes to this employee',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // List of changes
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141517),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF26282E)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staged Modifications (${_stagedOverrides.length}):',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            ..._stagedOverrides.entries.map((entry) {
                              final permId = entry.key;
                              final newEffect = entry.value['effect'] as String;
                              final original = allPerms[permId] ?? {};
                              final originalEffect = original['override'] as String? ?? 'INHERIT';
                              final permName = original['name'] ?? permId;
                              final permAction = original['action'] ?? '';
                              final permModule = original['module'] ?? '';

                              Color badgeColor;
                              if (newEffect == 'ALLOW') {
                                badgeColor = const Color(0xFF0D9488);
                              } else if (newEffect == 'DENY') {
                                badgeColor = const Color(0xFFE11D48);
                              } else {
                                badgeColor = Colors.grey;
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '[$permModule] $permName ($permAction)',
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        originalEffect,
                                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(Icons.arrow_forward, size: 14, color: Colors.white38),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: badgeColor, width: 0.8),
                                      ),
                                      child: Text(
                                        newEffect,
                                        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Audit Reason input
                      const Text(
                        'Administrative Justification / Reason *',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141517),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2C2E33)),
                        ),
                        child: TextField(
                          controller: reasonCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Granted Inventory module access for warehouse transfer duty',
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                            contentPadding: EdgeInsets.all(10),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          try {
                            final repo = ref.read(adminRepositoryProvider);
                            final overrideList = _stagedOverrides.values.toList();
                            await repo.updateEmployeeAccess(
                              _selectedEmployeeId!,
                              overrides: overrideList,
                              reason: reasonCtrl.text.trim().isNotEmpty
                                  ? reasonCtrl.text.trim()
                                  : 'Updated by Administrator',
                            );

                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Employee permissions updated and audit trail recorded successfully!'),
                                backgroundColor: Color(0xFF0D9488),
                              ),
                            );
                            if (mounted) {
                              _stagedOverrides.clear();
                              _selectEmployee(_selectedEmployeeId!);
                              _fetchEmployeeList(page: _currentPage);
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to update permissions: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 16),
                  label: Text(isSaving ? 'Applying...' : 'Apply & Save Access'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF26522),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF141517),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Employee directory with search
        SizedBox(
          width: 320,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E2024),
              border: Border(right: BorderSide(color: Color(0xFF2C2E33))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchHeader(),
                Expanded(child: _buildEmployeeListView()),
              ],
            ),
          ),
        ),

        // Right Column: Permission Matrix and Overrides
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMatrixHeader(),
              Expanded(
                child: _isLoadingDetail
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26522)))
                    : _detailError != null
                        ? Center(child: Text(_detailError!, style: const TextStyle(color: Colors.redAccent)))
                        : _selectedDetail == null
                            ? const Center(
                                child: Text('Select an employee to manage multi-module access',
                                    style: TextStyle(color: Colors.white54)),
                              )
                            : _buildMatrixBody(),
              ),
              if (_stagedOverrides.isNotEmpty) _buildBottomActionBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchHeader(),
        // Horizontal list of employees on mobile
        SizedBox(
          height: 90,
          child: _buildEmployeeListView(horizontal: true),
        ),
        const Divider(color: Color(0xFF2C2E33), height: 1),
        Expanded(
          child: _isLoadingDetail
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26522)))
              : _detailError != null
                  ? Center(child: Text(_detailError!, style: const TextStyle(color: Colors.redAccent)))
                  : _selectedDetail == null
                      ? const Center(
                          child: Text('Select an employee to manage access', style: TextStyle(color: Colors.white54)),
                        )
                      : _buildMatrixBody(),
        ),
        if (_stagedOverrides.isNotEmpty) _buildBottomActionBar(),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1C20),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2E33))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFF26522), size: 18),
              const SizedBox(width: 8),
              Text(
                _totalPages > 1 ? 'Employees Access (Pg $_currentPage/$_totalPages)' : 'Employees Access',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                onPressed: () => _fetchEmployeeList(page: _currentPage),
                tooltip: 'Refresh list',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF141517),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2C2E33)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _fetchEmployeeList(page: 1),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search name, code, dept...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Colors.white38),
                        onPressed: () {
                          _searchCtrl.clear();
                          _fetchEmployeeList(page: 1);
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeListView({bool horizontal = false}) {
    if (_isLoadingList) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF26522), strokeWidth: 2));
    }
    if (_listError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
              const SizedBox(height: 6),
              Text(_listError!, style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _fetchEmployeeList(page: _currentPage),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF26522), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                child: const Text('Retry', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      );
    }
    if (_employees.isEmpty) {
      return const Center(child: Text('No employees found', style: TextStyle(color: Colors.white38, fontSize: 12)));
    }

    if (horizontal) {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: _employees.length,
        itemBuilder: (context, idx) {
          final emp = _employees[idx];
          final isSelected = emp['id'] == _selectedEmployeeId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _selectEmployee(emp['id']),
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF26522).withValues(alpha: 0.15) : const Color(0xFF1E2024),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF26522) : const Color(0xFF2C2E33),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      emp['fullName'] ?? 'Employee',
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFF26522) : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      emp['employeeCode'] ?? '',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                    Text(
                      emp['department'] ?? '',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _employees.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF26282E), height: 1),
      itemBuilder: (context, idx) {
        final emp = _employees[idx];
        final isSelected = emp['id'] == _selectedEmployeeId;
        final user = emp['user'] as Map<String, dynamic>?;
        final hasUser = user != null;
        final allowCount = user?['allowCount'] as int? ?? 0;
        final denyCount = user?['denyCount'] as int? ?? 0;
        final roles = (user?['roles'] as List? ?? []).join(', ');

        return Material(
          color: isSelected ? const Color(0xFFF26522).withValues(alpha: 0.12) : Colors.transparent,
          child: InkWell(
            onTap: () => _selectEmployee(emp['id']),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected ? const Color(0xFFF26522) : const Color(0xFF2C2E33),
                    child: Text(
                      (emp['firstName'] as String? ?? 'E').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp['fullName'] ?? 'Employee',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFF26522) : Colors.white,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${emp['employeeCode']} • ${emp['department'] ?? 'No Dept'}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasUser && roles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              roles,
                              style: const TextStyle(color: Color(0xFFF26522), fontSize: 9, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Overrides badges
                  if (allowCount > 0 || denyCount > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (allowCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('+$allowCount', style: const TextStyle(color: Color(0xFF0D9488), fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        if (denyCount > 0) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('-$denyCount', style: const TextStyle(color: Color(0xFFE11D48), fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatrixHeader() {
    final emp = _selectedDetail?['employee'] as Map<String, dynamic>?;
    final user = emp?['user'] as Map<String, dynamic>?;
    final roles = (_selectedDetail?['roles'] as List? ?? []);
    final roleNames = roles.map((r) => r['name'] ?? r['code']).join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2E33))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      emp?['fullName'] ?? 'Employee Access Management',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (emp != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF26522).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFFF26522), width: 0.8),
                        ),
                        child: Text(
                          emp['employeeCode'] ?? '',
                          style: const TextStyle(color: Color(0xFFF26522), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (emp != null)
                  Text(
                    'Dept: ${emp['department'] ?? 'N/A'}  •  Desig: ${emp['designation'] ?? 'N/A'}  •  User: ${user?['username'] ?? 'No Login'}  •  Roles: [${roleNames.isEmpty ? 'None' : roleNames}]',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
              ],
            ),
          ),
          // Filter matrix by keyword
          SizedBox(
            width: 200,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141517),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF2C2E33)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _matrixFilter = val.trim().toLowerCase()),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                decoration: const InputDecoration(
                  hintText: 'Filter permissions...',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                  prefixIcon: Icon(Icons.filter_list, size: 14, color: Colors.white38),
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixBody() {
    final modules = (_selectedDetail!['modules'] as List? ?? []).map((m) => Map<String, dynamic>.from(m)).toList();

    // Filter modules if filter text is set
    final filteredModules = modules.where((mod) {
      if (_matrixFilter.isEmpty) return true;
      final modName = (mod['name'] as String? ?? '').toLowerCase();
      if (modName.contains(_matrixFilter)) return true;
      final perms = (mod['permissions'] as List? ?? []);
      return perms.any((p) {
        final pName = (p['name'] as String? ?? '').toLowerCase();
        final pAction = (p['action'] as String? ?? '').toLowerCase();
        return pName.contains(_matrixFilter) || pAction.contains(_matrixFilter);
      });
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Legend & Help Callout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1C20),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2C2E33)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFFF26522)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Multi-Module RBAC: Green indicates inherited role access. Set ALLOW to grant extra modules or DENY to explicitly revoke specific actions.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              _buildLegendChip('Role Default', Colors.grey),
              const SizedBox(width: 6),
              _buildLegendChip('Custom ALLOW', const Color(0xFF0D9488)),
              const SizedBox(width: 6),
              _buildLegendChip('Explicit DENY', const Color(0xFFE11D48)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Module Cards
        ...filteredModules.map((mod) => _buildModuleCard(mod)),
      ],
    );
  }

  Widget _buildLegendChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> moduleData) {
    final moduleName = moduleData['name'] as String? ?? 'MODULE';
    final perms = (moduleData['permissions'] as List? ?? []).map((p) => Map<String, dynamic>.from(p)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Module Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF191B1E),
              border: Border(bottom: BorderSide(color: Color(0xFF26282E))),
            ),
            child: Row(
              children: [
                const Icon(Icons.view_module, color: Color(0xFFF26522), size: 16),
                const SizedBox(width: 8),
                Text(
                  moduleName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${perms.length} actions',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ),
                const Spacer(),
                // Bulk quick buttons
                _buildSmallButton('Grant All', const Color(0xFF0D9488), () => _stageModuleBulk(moduleData, 'ALLOW')),
                const SizedBox(width: 6),
                _buildSmallButton('Deny All', const Color(0xFFE11D48), () => _stageModuleBulk(moduleData, 'DENY')),
                const SizedBox(width: 6),
                _buildSmallButton('Reset', Colors.white60, () => _stageModuleBulk(moduleData, 'INHERIT')),
              ],
            ),
          ),

          // Permissions Table
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: perms.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF26282E), height: 1),
            itemBuilder: (context, idx) {
              final p = perms[idx];
              final permId = p['id'] as String;
              final action = p['action'] as String? ?? '';
              final name = p['name'] as String? ?? action;
              final inherited = p['inherited'] as bool? ?? false;
              final currentSavedOverride = p['override'] as String?;

              // Check if currently staged
              final staged = _stagedOverrides[permId];
              final effectiveOverride = staged != null ? (staged['effect'] as String) : (currentSavedOverride ?? 'INHERIT');

              // Compute effective state
              bool isEffectiveAllowed;
              if (effectiveOverride == 'ALLOW') {
                isEffectiveAllowed = true;
              } else if (effectiveOverride == 'DENY') {
                isEffectiveAllowed = false;
              } else {
                isEffectiveAllowed = inherited;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Action chip
                    Container(
                      width: 75,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141517),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF2C2E33)),
                      ),
                      child: Text(
                        action,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Permission Title & Inherited status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Row(
                            children: [
                              Text(
                                inherited ? 'Inherited from role' : 'Not in assigned role',
                                style: TextStyle(
                                  color: inherited ? const Color(0xFF0D9488) : Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                              if (staged != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF26522).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text('STAGED', style: TextStyle(color: Color(0xFFF26522), fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Effective State badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isEffectiveAllowed ? const Color(0xFF0D9488).withValues(alpha: 0.15) : const Color(0xFFE11D48).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isEffectiveAllowed ? const Color(0xFF0D9488) : const Color(0xFFE11D48),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEffectiveAllowed ? Icons.check_circle : Icons.cancel,
                            size: 12,
                            color: isEffectiveAllowed ? const Color(0xFF0D9488) : const Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isEffectiveAllowed ? 'GRANTED' : 'DENIED',
                            style: TextStyle(
                              color: isEffectiveAllowed ? const Color(0xFF0D9488) : const Color(0xFFE11D48),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 3-way Segmented Control: [INHERIT, ALLOW, DENY]
                    _buildTriStateToggle(
                      selected: effectiveOverride,
                      onSelected: (val) => _stagePermissionChange(permId, currentSavedOverride, inherited, val),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTriStateToggle({required String selected, required ValueChanged<String> onSelected}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('INHERIT', 'Role', selected == 'INHERIT', Colors.white70, () => onSelected('INHERIT')),
          _buildToggleOption('ALLOW', 'Allow', selected == 'ALLOW', const Color(0xFF0D9488), () => onSelected('ALLOW')),
          _buildToggleOption('DENY', 'Deny', selected == 'DENY', const Color(0xFFE11D48), () => onSelected('DENY')),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String value, String label, bool isSelected, Color activeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: isSelected ? Border.all(color: activeColor, width: 0.8) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.white54,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024),
        border: Border(top: BorderSide(color: Color(0xFF2C2E33))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF26522).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFF26522), width: 0.8),
            ),
            child: Text(
              '${_stagedOverrides.length} pending change(s)',
              style: const TextStyle(color: Color(0xFFF26522), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Changes have not yet been written to the database.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _stagedOverrides.clear()),
            child: const Text('Discard', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _showSaveConfirmationDialog,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Review & Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF26522),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
