import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/admin/data/audit_repository.dart';

class AdminAuditLogsPage extends ConsumerStatefulWidget {
  const AdminAuditLogsPage({super.key});

  @override
  ConsumerState<AdminAuditLogsPage> createState() => _AdminAuditLogsPageState();
}

class _AdminAuditLogsPageState extends ConsumerState<AdminAuditLogsPage> {
  // Query parameters
  int _currentPage = 1;
  int _pageSize = 25;
  String _selectedModule = 'ALL';
  String _selectedAction = 'ALL';
  String _selectedOutcome = 'ALL';
  DateTimeRange? _selectedDateRange;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _entityIdCtrl = TextEditingController();

  // Data state
  List<AuditLogItem> _logs = [];
  int _totalRecords = 0;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  static const List<String> _modules = [
    'ALL',
    'CRM',
    'SALES',
    'PURCHASE',
    'INVENTORY',
    'PRODUCTION',
    'HR',
    'STAFF',
    'PROJECTS',
    'TASKS',
    'VENDORS',
    'CUSTOMERS',
    'ORGANIZATION',
    'USERS',
    'ROLES',
    'AUDIT',
  ];

  static const List<String> _actions = [
    'ALL',
    'CREATE',
    'UPDATE',
    'DELETE',
    'APPROVE',
    'REJECT',
    'EXPORT',
    'LOGIN',
    'AUTHORIZATION_DENIED',
  ];

  static const List<String> _outcomes = [
    'ALL',
    'SUCCESS',
    'DENIED',
    'FAILED',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _entityIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs({int? page}) async {
    final targetPage = page ?? _currentPage;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(auditRepositoryProvider);
      final res = await repo.getAuditLogs(
        page: targetPage,
        limit: _pageSize,
        module: _selectedModule,
        action: _selectedAction,
        outcome: _selectedOutcome,
        search: _searchCtrl.text.trim(),
        entityId: _entityIdCtrl.text.trim(),
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );

      if (mounted) {
        setState(() {
          _logs = res.items;
          _currentPage = res.page;
          _totalRecords = res.total;
          _totalPages = res.totalPages;
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

  Future<void> _exportCsv() async {
    final user = ref.read(currentUserProvider);
    if (user != null && !user.isAdmin && !user.canView('AUDIT')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: You do not have permission to export audit logs (AUDIT:EXPORT).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final repo = ref.read(auditRepositoryProvider);
      await repo.exportAuditLogsCsv(
        module: _selectedModule,
        action: _selectedAction,
        outcome: _selectedOutcome,
        search: _searchCtrl.text.trim(),
        entityId: _entityIdCtrl.text.trim(),
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audit logs CSV exported successfully and download started.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export audit logs: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedModule = 'ALL';
      _selectedAction = 'ALL';
      _selectedOutcome = 'ALL';
      _selectedDateRange = null;
      _searchCtrl.clear();
      _entityIdCtrl.clear();
      _currentPage = 1;
    });
    _fetchLogs(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canView = user?.isAdmin == true || user?.canView('AUDIT') == true;

    if (!canView) {
      return const Scaffold(
        backgroundColor: Color(0xFF141517),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gpp_bad_outlined, size: 56, color: Colors.redAccent),
              SizedBox(height: 16),
              Text(
                'Access Restricted: Administrator or AUDIT:VIEW Permission Required',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Only authorized administrative personnel may inspect the central security audit trail.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF141517),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildFilterToolbar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26522)))
                : _errorMessage != null
                    ? _buildErrorView()
                    : _logs.isEmpty
                        ? _buildEmptyView()
                        : _buildLogsTable(),
          ),
          _buildPaginationFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2E33))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF26522).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFFF26522), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Centralized Audit Trail & Security Logs',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Tooltip(
                      message: 'Append-Only & Immutable: Audit logs can never be altered or purged.',
                      child: Icon(Icons.lock_outline, size: 16, color: Color(0xFF4CAF50)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Chronological activity, actor snapshots, field diffs, and authorization failures across all modules ($_totalRecords recorded)',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _fetchLogs(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Color(0xFF3B4048)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: (_isExporting || _isLoading) ? null : _exportCsv,
            icon: _isExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded, size: 16),
            label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF26522),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF181A1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2E33))),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Module Dropdown
          _buildFilterDropdown(
            label: 'Module',
            value: _selectedModule,
            items: _modules,
            onChanged: (val) {
              setState(() => _selectedModule = val!);
              _fetchLogs(page: 1);
            },
          ),

          // Action Dropdown
          _buildFilterDropdown(
            label: 'Action',
            value: _selectedAction,
            items: _actions,
            onChanged: (val) {
              setState(() => _selectedAction = val!);
              _fetchLogs(page: 1);
            },
          ),

          // Outcome Dropdown
          _buildFilterDropdown(
            label: 'Outcome',
            value: _selectedOutcome,
            items: _outcomes,
            onChanged: (val) {
              setState(() => _selectedOutcome = val!);
              _fetchLogs(page: 1);
            },
          ),

          // Search Field
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search actor, email, reason...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF23262B),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF353940)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF353940)),
                ),
              ),
              onSubmitted: (_) => _fetchLogs(page: 1),
            ),
          ),

          // Entity ID Field
          SizedBox(
            width: 160,
            height: 36,
            child: TextField(
              controller: _entityIdCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Record / Entity ID',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF23262B),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF353940)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF353940)),
                ),
              ),
              onSubmitted: (_) => _fetchLogs(page: 1),
            ),
          ),

          // Date Range Picker
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range, size: 15, color: Colors.white70),
            label: Text(
              _selectedDateRange == null
                  ? 'Date Range'
                  : '${_formatDateShort(_selectedDateRange!.start)} - ${_formatDateShort(_selectedDateRange!.end)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF23262B),
              side: const BorderSide(color: Color(0xFF353940)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),

          // Search / Apply Button
          ElevatedButton(
            onPressed: () => _fetchLogs(page: 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C3038),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Apply Filters', style: TextStyle(fontSize: 12)),
          ),

          // Clear button
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF23262B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF353940)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF23262B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white60),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item == 'ALL' ? '$label: All' : item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF26522),
              surface: Color(0xFF1E2024),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchLogs(page: 1);
    }
  }

  Widget _buildLogsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFF1E2024)),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFF2A2E35);
              }
              return const Color(0xFF141517);
            }),
            horizontalMargin: 16,
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Timestamp', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Actor', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Module', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Action', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Target / Entity', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Outcome', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Diff / Fields', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: _logs.map((log) {
              return DataRow(
                cells: [
                  // Timestamp
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDateTime(log.timestamp), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        Text(
                          '${_sliceSafe(log.timestamp.toUtc().toIso8601String(), 11, 19)} UTC',
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  // Actor
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.userName?.isNotEmpty == true ? log.userName! : (log.userEmail ?? 'System Actor'),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (log.userEmail != null && log.userName != null)
                          Text(log.userEmail!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),

                  // Module
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2E35),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF3B4048)),
                      ),
                      child: Text(log.module, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  // Action
                  DataCell(_buildActionBadge(log.action)),

                  // Entity Target
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (log.entityType != null) ...[
                          Text('${log.entityType}: ', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                        Text(
                          log.entityId != null ? _truncate(log.entityId!, 18) : '-',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                        ),
                        if (log.entityId != null && log.entityId!.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(Icons.copy, size: 12, color: Colors.white38),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Copy ID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: log.entityId!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ID copied to clipboard'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Outcome
                  DataCell(_buildOutcomeBadge(log.outcome)),

                  // Diff Summary
                  DataCell(
                    log.changedFields.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${log.changedFields.length} field(s) changed',
                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                            ),
                          )
                        : Text(
                            log.action == 'AUTHORIZATION_DENIED' ? 'Permission Denied' : '-',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                  ),

                  // Actions
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFFF26522)),
                      tooltip: 'Inspect Event Details & Diffs',
                      onPressed: () => _showLogDetailModal(log),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color bg;
    Color fg;

    switch (action.toUpperCase()) {
      case 'CREATE':
        bg = const Color(0xFF1B5E20).withValues(alpha: 0.3);
        fg = const Color(0xFF81C784);
        break;
      case 'UPDATE':
        bg = const Color(0xFF0D47A1).withValues(alpha: 0.3);
        fg = const Color(0xFF64B5F6);
        break;
      case 'DELETE':
        bg = const Color(0xFFB71C1C).withValues(alpha: 0.3);
        fg = const Color(0xFFE57373);
        break;
      case 'APPROVE':
        bg = const Color(0xFF004D40).withValues(alpha: 0.3);
        fg = const Color(0xFF4DB6AC);
        break;
      case 'REJECT':
      case 'AUTHORIZATION_DENIED':
        bg = const Color(0xFFE65100).withValues(alpha: 0.3);
        fg = const Color(0xFFFFB74D);
        break;
      case 'EXPORT':
        bg = const Color(0xFF4A148C).withValues(alpha: 0.3);
        fg = const Color(0xFFBA68C8);
        break;
      default:
        bg = const Color(0xFF37474F).withValues(alpha: 0.3);
        fg = const Color(0xFFB0BEC5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        action,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOutcomeBadge(String outcome) {
    final isSuccess = outcome.toUpperCase() == 'SUCCESS';
    final isDenied = outcome.toUpperCase() == 'DENIED';
    final color = isSuccess
        ? const Color(0xFF4CAF50)
        : isDenied
            ? const Color(0xFFFF9800)
            : const Color(0xFFF44336);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSuccess
              ? Icons.check_circle_outline
              : isDenied
                  ? Icons.remove_circle_outline
                  : Icons.error_outline,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          outcome,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024),
        border: Border(top: BorderSide(color: Color(0xFF2C2E33))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${((_currentPage - 1) * _pageSize) + (_logs.isEmpty ? 0 : 1)} - ${((_currentPage - 1) * _pageSize) + _logs.length} of $_totalRecords events',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Row(
            children: [
              const Text('Rows per page: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  dropdownColor: const Color(0xFF23262B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: [15, 25, 50, 100].map((size) {
                    return DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                      _fetchLogs(page: 1);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Text('Page $_currentPage of $_totalPages', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                color: Colors.white,
                disabledColor: Colors.white24,
                onPressed: _currentPage > 1 ? () => _fetchLogs(page: _currentPage - 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                color: Colors.white,
                disabledColor: Colors.white24,
                onPressed: _currentPage < _totalPages ? () => _fetchLogs(page: _currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt_off_outlined, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          const Text(
            'No audit events found matching active filter criteria',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try resetting or widening the filters to inspect earlier audit records.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _clearFilters,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF26522))),
            child: const Text('Reset All Filters', style: TextStyle(color: Color(0xFFF26522))),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Failed to load audit records',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _fetchLogs(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF26522)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showLogDetailModal(AuditLogItem log) {
    showDialog(
      context: context,
      builder: (ctx) => _AuditDetailDialog(log: log),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _truncate(String str, int maxLen) {
    if (str.length <= maxLen) return str;
    return '${str.substring(0, maxLen)}...';
  }

  static String _sliceSafe(String str, int start, int end) {
    if (str.length <= start) return str;
    if (str.length <= end) return str.substring(start);
    return str.substring(start, end);
  }
}

class _AuditDetailDialog extends StatelessWidget {
  final AuditLogItem log;

  const _AuditDetailDialog({required this.log});

  @override
  Widget build(BuildContext context) {
    final details = log.details ?? {};
    final changedFields = log.changedFields;
    final before = log.before;
    final after = log.after;

    return Dialog(
      backgroundColor: const Color(0xFF1E2024),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2C2E33)),
      ),
      child: Container(
        width: 720,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF26522).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.description_outlined, color: Color(0xFFF26522), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Event Details: ${log.action} on ${log.module}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Log ID: ${log.id}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF2C2E33), height: 24),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Grid
                    _buildSectionHeader('EVENT METADATA'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141517),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF2C2E33)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Timestamp (UTC):', log.timestamp.toUtc().toIso8601String()),
                          _buildDetailRow('Timestamp (Local):', log.timestamp.toLocal().toString()),
                          _buildDetailRow('Outcome:', log.outcome),
                          _buildDetailRow('Request ID:', log.requestId ?? 'N/A'),
                          _buildDetailRow('IP Address:', log.ipAddress ?? 'N/A'),
                          _buildDetailRow('Entity Type:', log.entityType ?? 'N/A'),
                          _buildDetailRow('Entity ID:', log.entityId ?? 'N/A'),
                          if (log.reason != null && log.reason!.isNotEmpty)
                            _buildDetailRow('Reason / Note:', log.reason!),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Actor Snapshot
                    _buildSectionHeader('ACTOR SNAPSHOT'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141517),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF2C2E33)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Full Name:', log.userName ?? 'System / Unknown'),
                          _buildDetailRow('Email:', log.userEmail ?? 'N/A'),
                          _buildDetailRow('User ID:', log.userId ?? 'N/A'),
                          _buildDetailRow(
                            'Roles / Designations:',
                            log.actorRoles.isNotEmpty ? log.actorRoles.join(', ') : 'Standard User',
                          ),
                        ],
                      ),
                    ),

                    // Changed Fields Diffs
                    if (changedFields.isNotEmpty || before != null || after != null) ...[
                      const SizedBox(height: 18),
                      _buildSectionHeader('CHANGED FIELDS & DIFFS'),
                      const SizedBox(height: 8),
                      if (changedFields.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: changedFields.map((field) {
                            return Chip(
                              label: Text(field, style: const TextStyle(fontSize: 11, color: Colors.white)),
                              backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.4),
                              side: const BorderSide(color: Color(0xFF1976D2)),
                              padding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Before vs After
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (before != null)
                            Expanded(
                              child: _buildJsonDiffBox('BEFORE (PRE-MUTATION)', before, const Color(0xFFB71C1C)),
                            ),
                          if (before != null && after != null) const SizedBox(width: 10),
                          if (after != null)
                            Expanded(
                              child: _buildJsonDiffBox('AFTER (POST-MUTATION)', after, const Color(0xFF1B5E20)),
                            ),
                        ],
                      ),
                    ],

                    // Raw Payload
                    const SizedBox(height: 18),
                    _buildSectionHeader('RAW AUDIT PAYLOAD (REDACTED)'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141517),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF2C2E33)),
                      ),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert(details),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Center(
                      child: Text(
                        '🔒 Cryptographically Append-Only Log — Immutable Record',
                        style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFF26522),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonDiffBox(String title, dynamic data, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: borderColor, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SelectableText(
            data is String ? data : const JsonEncoder.withIndent('  ').convert(data),
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
