import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/widgets/saark_logo.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';

/// Full-featured Enterprise Database Record Dashboard
/// Features:
/// 1. Simple, clean Username & Password DBA Login.
/// 2. Module-wise Table organization & Module Directory.
/// 3. In-Dashboard Database Entry insertion for any table.
/// 4. Live record data grid, sensitive field masking, analytics, schema dictionary, SQL terminal.
class DatabaseRecordDashboardPage extends ConsumerStatefulWidget {
  final String? initialTableName;

  const DatabaseRecordDashboardPage({
    super.key,
    this.initialTableName,
  });

  @override
  ConsumerState<DatabaseRecordDashboardPage> createState() =>
      _DatabaseRecordDashboardPageState();
}

class _DatabaseRecordDashboardPageState
    extends ConsumerState<DatabaseRecordDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ─── Simple Login State ──────────────────────────────────────────────────
  bool _isAuthenticated = false;
  String? _dbaToken;
  Map<String, dynamic>? _authenticatedUser;
  Timer? _leaseTimer;
  int _remainingLeaseSeconds = 1800; // 30 minutes lease

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isAuthLoading = false;
  String? _authErrorMessage;

  // ─── Telemetry & Tables State ──────────────────────────────────────────
  bool _isLoadingTables = true;
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _filteredTables = [];
  String _activeCategory = 'ALL';
  bool _groupByModule = false; // Module-wise grouping (flat list by default with module filtering)
  final _tableSearchController = TextEditingController();
  Map<String, dynamic>? _selectedTable;
  Map<String, dynamic>? _telemetry;
  Map<String, dynamic> _categorySummary = {};
  int _totalEstimatedRecords = 0;

  // ─── Selected Table Records State ──────────────────────────────────────
  bool _isLoadingRecords = false;
  List<Map<String, dynamic>> _columns = [];
  List<Map<String, dynamic>> _rows = [];
  int _totalRows = 0;
  int _currentPage = 1;
  int _limit = 25;
  int _totalPages = 1;
  String? _sortBy;
  String _sortOrder = 'ASC';
  final bool _maskSensitive = true;
  final _recordSearchController = TextEditingController();

  // ─── SQL Console State ──────────────────────────────────────────────────
  final _sqlQueryController = TextEditingController(
    text: 'SELECT * FROM "users" LIMIT 15;',
  );
  bool _isRunningQuery = false;
  String? _queryError;
  int? _queryExecutionTimeMs;
  List<String> _queryColumns = [];
  List<Map<String, dynamic>> _queryRows = [];
  final List<String> _queryHistory = [];

  // Module category registry
  static const List<Map<String, dynamic>> moduleRegistry = [
    {'key': 'ALL', 'label': 'All Modules', 'icon': Icons.public_rounded, 'color': Color(0xFFF97316)},
    {'key': 'AUTH_SECURITY', 'label': 'Auth & Security', 'icon': Icons.security_rounded, 'color': Color(0xFF3B82F6)},
    {'key': 'HR_WORKFORCE', 'label': 'HR & Workforce', 'icon': Icons.people_rounded, 'color': Color(0xFFA855F7)},
    {'key': 'CRM_CUSTOMERS', 'label': 'CRM & Clients', 'icon': Icons.business_rounded, 'color': Color(0xFFEAB308)},
    {'key': 'SALES_BILLING', 'label': 'Sales & Invoices', 'icon': Icons.receipt_long_rounded, 'color': Color(0xFF14B8A6)},
    {'key': 'ACCOUNTS_FINANCE', 'label': 'Accounts & Finance', 'icon': Icons.account_balance_rounded, 'color': Color(0xFF10B981)},
    {'key': 'B2B_TRADING', 'label': 'B2B Marketplace', 'icon': Icons.storefront_rounded, 'color': Color(0xFF6366F1)},
    {'key': 'MANUFACTURING', 'label': 'Manufacturing & MES', 'icon': Icons.precision_manufacturing_rounded, 'color': Color(0xFFF97316)},
    {'key': 'PURCHASE_VENDORS', 'label': 'Procurement & Vendors', 'icon': Icons.shopping_cart_rounded, 'color': Color(0xFFEC4899)},
    {'key': 'INVENTORY_STORE', 'label': 'Inventory & Stores', 'icon': Icons.inventory_2_rounded, 'color': Color(0xFF06B6D4)},
    {'key': 'SYSTEM_CORE', 'label': 'Core & System', 'icon': Icons.dns_rounded, 'color': Color(0xFF94A3B8)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _leaseTimer?.cancel();
    _tabController.dispose();
    _tableSearchController.dispose();
    _recordSearchController.dispose();
    _sqlQueryController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── SIMPLE AUTHENTICATION HANDLERS ──────────────────────────────────────

  Future<void> _handleAuthenticate() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _authErrorMessage = 'Please enter both username and password.');
      return;
    }

    setState(() {
      _isAuthLoading = true;
      _authErrorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final result = await repo.verifyDatabaseAuth(username, password);

      if (!mounted) return;

      if (result['success'] == true) {
        final token = result['dbaToken']?.toString();
        final expiresIn = result['expiresInSeconds'] is int ? result['expiresInSeconds'] as int : 1800;
        final user = result['user'] is Map ? Map<String, dynamic>.from(result['user']) : null;

        _passwordController.clear();

        setState(() {
          _isAuthenticated = true;
          _isAuthLoading = false;
          _dbaToken = token;
          _remainingLeaseSeconds = expiresIn;
          _authenticatedUser = user;
        });

        _startLeaseTimer();
        _fetchTablesAndTelemetry();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔓 Database session unlocked successfully.'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isAuthLoading = false;
          _authErrorMessage = result['message']?.toString() ?? 'Invalid username or password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthLoading = false;
        _authErrorMessage = 'Authentication failed: $e';
      });
    }
  }

  void _lockSession() {
    _leaseTimer?.cancel();
    _usernameController.clear();
    _passwordController.clear();
    setState(() {
      _isAuthenticated = false;
      _dbaToken = null;
      _authenticatedUser = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔒 Database session locked.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startLeaseTimer() {
    _leaseTimer?.cancel();
    _leaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingLeaseSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          _lockSession();
        }
      } else {
        if (mounted) {
          setState(() => _remainingLeaseSeconds--);
        }
      }
    });
  }

  // ─── DATA FETCHING ───────────────────────────────────────────────────────

  Future<void> _fetchTablesAndTelemetry() async {
    setState(() => _isLoadingTables = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final tablesFuture = repo.getDatabaseTables();
      final telemetryFuture = repo.getDatabaseTelemetry();

      final results = await Future.wait([tablesFuture, telemetryFuture]);
      final tablesData = results[0];
      final telemetryData = results[1];

      if (!mounted) return;

      final rawList = tablesData['tables'] as List? ?? [];
      final parsed = rawList.map((t) => Map<String, dynamic>.from(t)).toList();

      int recordSum = tablesData['totalEstimatedRecords'] is int
          ? tablesData['totalEstimatedRecords'] as int
          : 0;

      if (recordSum == 0) {
        for (final t in parsed) {
          recordSum += (t['estimatedRowCount'] is int ? t['estimatedRowCount'] as int : 0);
        }
      }

      setState(() {
        _tables = parsed;
        _totalEstimatedRecords = recordSum;
        _categorySummary = tablesData['categorySummary'] is Map
            ? Map<String, dynamic>.from(tablesData['categorySummary'])
            : {};
        _telemetry = telemetryData['data'] is Map
            ? Map<String, dynamic>.from(telemetryData['data'])
            : Map<String, dynamic>.from(telemetryData);
        _isLoadingTables = false;
      });

      _applyTableFilters();

      // Default select initial or "users" or the first table
      if (parsed.isNotEmpty && _selectedTable == null) {
        final targetName = widget.initialTableName ?? 'users';
        final defaultTable = parsed.firstWhere(
          (t) => (t['tableName'] ?? '').toString().toLowerCase() == targetName.toLowerCase(),
          orElse: () => parsed.first,
        );
        _selectTable(defaultTable);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTables = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load database metadata: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _applyTableFilters() {
    final query = _tableSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredTables = _tables.where((t) {
        final matchesCategory = _activeCategory == 'ALL' || t['category'] == _activeCategory;
        final matchesQuery = query.isEmpty ||
            (t['tableName'] ?? '').toString().toLowerCase().contains(query) ||
            (t['categoryLabel'] ?? '').toString().toLowerCase().contains(query);
        return matchesCategory && matchesQuery;
      }).toList();
    });
  }

  Future<void> _selectTable(Map<String, dynamic> table, {int targetTab = 0}) async {
    setState(() {
      _selectedTable = table;
      _currentPage = 1;
      _sortBy = null;
      _sortOrder = 'ASC';
      _recordSearchController.clear();
    });
    if (_tabController.index != targetTab) {
      _tabController.animateTo(targetTab);
    }
    await _fetchTableRecords(table['tableName'].toString());
  }

  Future<void> _fetchTableRecords(String tableName, {String? search}) async {
    setState(() => _isLoadingRecords = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.getDatabaseTableData(
        tableName,
        page: _currentPage,
        limit: _limit,
        search: search ?? _recordSearchController.text.trim(),
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        maskSensitive: _maskSensitive,
        dbaToken: _dbaToken,
      );

      if (!mounted) return;

      final rawCols = res['columns'] as List? ?? [];
      final rawRows = res['rows'] as List? ?? [];

      setState(() {
        _columns = rawCols.map((c) => Map<String, dynamic>.from(c)).toList();
        _rows = rawRows.map((r) => Map<String, dynamic>.from(r)).toList();
        _totalRows = res['totalRows'] is int ? res['totalRows'] : 0;
        _totalPages = res['totalPages'] is int ? res['totalPages'] : 1;
        if (res['sortBy'] != null && _sortBy == null) {
          _sortBy = res['sortBy'].toString();
        }
        _isLoadingRecords = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingRecords = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to query records for $tableName: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _handleSort(String columnName) {
    setState(() {
      if (_sortBy == columnName) {
        _sortOrder = _sortOrder == 'ASC' ? 'DESC' : 'ASC';
      } else {
        _sortBy = columnName;
        _sortOrder = 'ASC';
      }
      _currentPage = 1;
    });
    if (_selectedTable != null) {
      _fetchTableRecords(_selectedTable!['tableName'].toString());
    }
  }

  Future<void> _runCustomQuery() async {
    final sql = _sqlQueryController.text.trim();
    if (sql.isEmpty) return;

    if (!_queryHistory.contains(sql)) {
      _queryHistory.insert(0, sql);
      if (_queryHistory.length > 25) _queryHistory.removeLast();
    }

    setState(() {
      _isRunningQuery = true;
      _queryError = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.executeDatabaseQuery(sql, limit: 100, dbaToken: _dbaToken);

      if (!mounted) return;

      if (res['success'] == true) {
        final rawCols = res['columns'] as List? ?? [];
        final rawRows = res['rows'] as List? ?? [];

        setState(() {
          _queryColumns = rawCols.map((c) => c.toString()).toList();
          _queryRows = rawRows.map((r) => Map<String, dynamic>.from(r)).toList();
          _queryExecutionTimeMs = res['executionTimeMs'];
          _isRunningQuery = false;
        });
      } else {
        setState(() {
          _queryError = res['message']?.toString() ?? 'Query execution failed';
          _isRunningQuery = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _queryError = e.toString();
        _isRunningQuery = false;
      });
    }
  }

  void _copyTableDataAsCsv(List<Map<String, dynamic>> rows, List<String> colNames) {
    if (rows.isEmpty || colNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records available to export.')),
      );
      return;
    }
    final csvBuffer = StringBuffer();
    csvBuffer.writeln(colNames.map((c) => '"$c"').join(','));

    for (final row in rows) {
      final line = colNames.map((c) {
        final v = row[c];
        if (v == null) return '""';
        return '"${v.toString().replaceAll('"', '""')}"';
      }).join(',');
      csvBuffer.writeln(line);
    }

    Clipboard.setData(ClipboardData(text: csvBuffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${rows.length} records exported as CSV to clipboard!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _copyTableDataAsJson(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(rows);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${rows.length} records exported as JSON to clipboard!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DATABASE ENTRY CREATOR MODAL
  // ─────────────────────────────────────────────────────────────
  void _openInsertEntryDialog(Map<String, dynamic> table) async {
    final tableName = table['tableName']?.toString() ?? '';
    List<Map<String, dynamic>> tableColumns = [];

    // Use loaded columns if same table, otherwise fetch schema
    if (_selectedTable?['tableName'] == tableName && _columns.isNotEmpty) {
      tableColumns = _columns;
    } else {
      try {
        final repo = ref.read(adminRepositoryProvider);
        final res = await repo.getDatabaseTableData(tableName, limit: 1, dbaToken: _dbaToken);
        final rawCols = res['columns'] as List? ?? [];
        tableColumns = rawCols.map((c) => Map<String, dynamic>.from(c)).toList();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load table schema: $e'), backgroundColor: AppTheme.error),
        );
        return;
      }
    }

    if (!mounted) return;

    // Filter columns for data entry (exclude auto-managed columns by default, but allow specifying if desired)
    final inputControllers = <String, TextEditingController>{};
    final booleanValues = <String, bool>{};

    for (final col in tableColumns) {
      final colName = col['columnName'].toString();
      final dType = col['dataType']?.toString().toLowerCase() ?? '';
      if (dType == 'boolean') {
        booleanValues[colName] = false;
      } else {
        inputControllers[colName] = TextEditingController();
      }
    }

    bool isSubmitting = false;
    String? submitError;
    int entryMode = 0; // 0 = Visual Form Fields, 1 = Raw JSON
    final jsonController = TextEditingController(text: '{\n  \n}');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1E26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF2C313C)),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insert Database Entry • public.$tableName',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Creates a new record row directly in the database table',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 680,
                height: 500,
                child: Column(
                  children: [
                    // Mode Switcher (Form / JSON)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => entryMode = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: entryMode == 0 ? AppTheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    'Structured Form Fields (${tableColumns.length} columns)',
                                    style: TextStyle(
                                      color: entryMode == 0 ? Colors.white : Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => entryMode = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: entryMode == 1 ? AppTheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    'Raw JSON Object Payload',
                                    style: TextStyle(
                                      color: entryMode == 1 ? Colors.white : Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (submitError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                submitError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Content based on Mode
                    Expanded(
                      child: entryMode == 0
                          ? ListView.separated(
                              itemCount: tableColumns.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (cCtx, i) {
                                final col = tableColumns[i];
                                final colName = col['columnName'].toString();
                                final isPk = col['isPrimaryKey'] == true;
                                final isNullable = col['isNullable'] == true;
                                final dType = col['dataType']?.toString().toLowerCase() ?? '';
                                final defaultVal = col['columnDefault']?.toString();

                                final isAutoCol = (isPk && defaultVal != null) ||
                                    colName == 'created_at' ||
                                    colName == 'updated_at';

                                if (dType == 'boolean') {
                                  final currentVal = booleanValues[colName] ?? false;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF222630),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          colName,
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('(boolean)', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                                        const Spacer(),
                                        Switch(
                                          value: currentVal,
                                          activeThumbColor: AppTheme.primary,
                                          onChanged: (val) {
                                            setDialogState(() => booleanValues[colName] = val);
                                          },
                                        ),
                                        Text(currentVal ? 'TRUE' : 'FALSE', style: TextStyle(color: currentVal ? Colors.greenAccent : Colors.white54, fontSize: 11)),
                                      ],
                                    ),
                                  );
                                }

                                final ctrl = inputControllers[colName];

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 200,
                                      child: Row(
                                        children: [
                                          if (isPk)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 4),
                                              child: Icon(Icons.vpn_key_rounded, size: 12, color: Colors.amberAccent),
                                            ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  colName,
                                                  style: TextStyle(
                                                    color: isPk ? Colors.amberAccent : Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: isPk ? FontWeight.bold : FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '$dType • ${isNullable ? "optional" : "required"}',
                                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: ctrl,
                                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFF222630),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                          hintText: isAutoCol ? '(Auto-generated if left empty)' : 'Value...',
                                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          : TextField(
                              controller: jsonController,
                              maxLines: 20,
                              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF14171E),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                hintText: '{\n  "column_name": "value"\n}',
                                hintStyle: const TextStyle(color: Colors.white30, fontFamily: 'monospace'),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                            submitError = null;
                          });

                          final payload = <String, dynamic>{};

                          if (entryMode == 0) {
                            // Extract form fields
                            for (final entry in inputControllers.entries) {
                              final text = entry.value.text.trim();
                              if (text.isNotEmpty) {
                                payload[entry.key] = text;
                              }
                            }
                            for (final entry in booleanValues.entries) {
                              payload[entry.key] = entry.value;
                            }
                          } else {
                            // Parse JSON mode
                            try {
                              final parsed = jsonDecode(jsonController.text.trim());
                              if (parsed is Map) {
                                payload.addAll(Map<String, dynamic>.from(parsed));
                              } else {
                                setDialogState(() {
                                  isSubmitting = false;
                                  submitError = 'Root JSON payload must be an object { ... }';
                                });
                                return;
                              }
                            } catch (e) {
                              setDialogState(() {
                                isSubmitting = false;
                                submitError = 'Invalid JSON syntax: $e';
                              });
                              return;
                            }
                          }

                          if (payload.isEmpty) {
                            setDialogState(() {
                              isSubmitting = false;
                              submitError = 'Please provide at least one field value to insert.';
                            });
                            return;
                          }

                          try {
                            final repo = ref.read(adminRepositoryProvider);
                            final res = await repo.insertDatabaseTableRecord(tableName, payload, dbaToken: _dbaToken);

                            if (!dialogCtx.mounted) return;

                            if (res['success'] == true) {
                              Navigator.of(ctx).pop();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ New database entry successfully inserted into "$tableName"!'),
                                    backgroundColor: const Color(0xFF2E7D32),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                // Refresh current table records and tables list
                                _fetchTablesAndTelemetry();
                                _fetchTableRecords(tableName);
                              }
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                                submitError = res['message']?.toString() ?? 'Insert failed.';
                              });
                            }
                          } catch (err) {
                            setDialogState(() {
                              isSubmitting = false;
                              submitError = err.toString();
                            });
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(isSubmitting ? 'Inserting...' : 'Save Database Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EDIT DATABASE ENTRY MODAL (OPTION 1)
  // ─────────────────────────────────────────────────────────────
  void _openEditEntryDialog(Map<String, dynamic> row) {
    if (_selectedTable == null) return;
    final tableName = _selectedTable!['tableName']?.toString() ?? '';

    // Find primary key column
    final pkColMeta = _columns.firstWhere(
      (c) => c['isPrimaryKey'] == true,
      orElse: () => _columns.firstWhere(
        (c) => c['columnName'] == 'id' || c['columnName'] == 'uuid',
        orElse: () => _columns.isNotEmpty ? _columns.first : {'columnName': 'id'},
      ),
    );
    final pkColName = pkColMeta['columnName']?.toString() ?? 'id';
    final pkVal = row[pkColName];

    final inputControllers = <String, TextEditingController>{};
    final booleanValues = <String, bool>{};

    for (final col in _columns) {
      final colName = col['columnName'].toString();
      final dType = col['dataType']?.toString().toLowerCase() ?? '';
      final rawVal = row[colName];

      if (dType == 'boolean') {
        booleanValues[colName] = rawVal == true || rawVal.toString().toLowerCase() == 'true';
      } else {
        inputControllers[colName] = TextEditingController(
          text: rawVal != null ? rawVal.toString() : '',
        );
      }
    }

    bool isSubmitting = false;
    String? submitError;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1E26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF2C313C)),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Record • $tableName',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$pkColName: $pkVal',
                          style: const TextStyle(color: Color(0xFFFF9E77), fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 680,
                height: 480,
                child: Column(
                  children: [
                    if (submitError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                submitError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Expanded(
                      child: ListView.separated(
                        itemCount: _columns.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (cCtx, i) {
                          final col = _columns[i];
                          final colName = col['columnName'].toString();
                          final dType = col['dataType']?.toString() ?? 'text';
                          final isPk = col['isPrimaryKey'] == true || colName.toLowerCase() == pkColName.toLowerCase();
                          final isTimestamp = colName.contains('created') || colName.contains('updated');
                          final isReadOnly = isPk || isTimestamp;

                          if (dType.toLowerCase() == 'boolean') {
                            final currentVal = booleanValues[colName] ?? false;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222630),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    colName,
                                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: currentVal,
                                    activeThumbColor: AppTheme.primary,
                                    onChanged: isReadOnly
                                        ? null
                                        : (val) {
                                            setDialogState(() => booleanValues[colName] = val);
                                          },
                                  ),
                                ],
                              ),
                            );
                          }

                          final ctrl = inputControllers[colName]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isPk)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.vpn_key_rounded, size: 12, color: Colors.amberAccent),
                                    ),
                                  Text(
                                    colName,
                                    style: TextStyle(
                                      color: isPk ? Colors.amberAccent : Colors.white70,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '($dType)${isReadOnly ? ' • Read Only' : ''}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: ctrl,
                                readOnly: isReadOnly,
                                style: TextStyle(
                                  color: isReadOnly ? Colors.white38 : Colors.white,
                                  fontSize: 12.5,
                                  fontFamily: 'monospace',
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isReadOnly ? const Color(0xFF191C22) : const Color(0xFF222630),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                            submitError = null;
                          });

                          try {
                            final updatePayload = <String, dynamic>{};
                            for (final col in _columns) {
                              final colName = col['columnName'].toString();
                              final isPk = col['isPrimaryKey'] == true || colName.toLowerCase() == pkColName.toLowerCase();
                              final isTimestamp = colName.contains('created') || colName.contains('updated');
                              if (isPk || isTimestamp) continue;

                              final dType = col['dataType']?.toString().toLowerCase() ?? '';
                              if (dType == 'boolean') {
                                updatePayload[colName] = booleanValues[colName] ?? false;
                              } else {
                                final textVal = inputControllers[colName]?.text;
                                updatePayload[colName] = textVal;
                              }
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            final repo = ref.read(adminRepositoryProvider);
                            await repo.updateDatabaseTableRecord(
                              tableName,
                              primaryKeyCol: pkColName,
                              primaryKeyValue: pkVal,
                              data: updatePayload,
                              dbaToken: _dbaToken,
                            );

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('✅ Record updated successfully!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                            _fetchTableRecords(tableName);
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              submitError = e.toString();
                            });
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(isSubmitting ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE DATABASE ENTRY (OPTION 2)
  // ─────────────────────────────────────────────────────────────
  void _confirmDeleteRecord(Map<String, dynamic> row) {
    if (_selectedTable == null) return;
    final tableName = _selectedTable!['tableName']?.toString() ?? '';

    final pkColMeta = _columns.firstWhere(
      (c) => c['isPrimaryKey'] == true,
      orElse: () => _columns.firstWhere(
        (c) => c['columnName'] == 'id' || c['columnName'] == 'uuid',
        orElse: () => _columns.isNotEmpty ? _columns.first : {'columnName': 'id'},
      ),
    );
    final pkColName = pkColMeta['columnName']?.toString() ?? 'id';
    final pkVal = row[pkColName];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2129),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.35)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('Delete Record?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this record from table "$tableName"?\n\n'
          '• Primary Key ($pkColName): $pkVal\n\n'
          'This action cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(adminRepositoryProvider);
                await repo.deleteDatabaseTableRecord(
                  tableName,
                  primaryKeyCol: pkColName,
                  primaryKeyValue: pkVal,
                  dbaToken: _dbaToken,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Record deleted successfully!'), backgroundColor: AppTheme.success),
                );
                _fetchTableRecords(tableName);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DATABASE BACKUP & SNAPSHOT (OPTION 3)
  // ─────────────────────────────────────────────────────────────
  Future<void> _triggerDatabaseBackup() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating verified database backup snapshot...'), duration: Duration(seconds: 2)),
    );
    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.triggerDatabaseBackup(dbaToken: _dbaToken);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2129),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 24),
              SizedBox(width: 10),
              Text('Database Snapshot Verified', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Snapshot ID: ${res['backupId'] ?? res['data']?['backupId'] ?? 'BK-VERIFIED'}',
                  style: const TextStyle(color: Color(0xFFFF9E77), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Status: ${res['status'] ?? res['data']?['status'] ?? 'VERIFIED_SNAPSHOT'}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
              const SizedBox(height: 6),
              Text('Engine: ${res['databaseEngine'] ?? res['data']?['databaseEngine'] ?? 'PostgreSQL 16'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text('Total Live Records: ${res['totalRecords'] ?? res['data']?['totalRecords'] ?? _totalEstimatedRecords}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(res)));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup details copied to clipboard!')));
              },
              child: const Text('Copy Details', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CHANGE DBA MASTER PASSWORD (OPTION 4)
  // ─────────────────────────────────────────────────────────────
  void _openChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2129),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.key_rounded, color: Colors.amberAccent, size: 22),
              SizedBox(width: 10),
              Text('Change Database Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Current Password', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                TextField(
                  controller: currentPassController,
                  obscureText: obscureCurrent,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF282D37),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16, color: Colors.white54),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('New Password', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                TextField(
                  controller: newPassController,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF282D37),
                    isDense: true,
                    hintText: 'Minimum 6 characters',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16, color: Colors.white54),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Confirm New Password', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                TextField(
                  controller: confirmPassController,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF282D37),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final curr = currentPassController.text.trim();
                      final newP = newPassController.text.trim();
                      final conf = confirmPassController.text.trim();
                      if (curr.isEmpty || newP.isEmpty) {
                        setDialogState(() => errorMsg = 'All fields are required');
                        return;
                      }
                      if (newP.length < 6) {
                        setDialogState(() => errorMsg = 'New password must be at least 6 characters');
                        return;
                      }
                      if (newP != conf) {
                        setDialogState(() => errorMsg = 'New passwords do not match');
                        return;
                      }
                      setDialogState(() {
                        isSaving = true;
                        errorMsg = null;
                      });
                      try {
                        final repo = ref.read(adminRepositoryProvider);
                        final res = await repo.changeDatabasePassword(
                          username: _authenticatedUser?['username'] ?? 'admin',
                          currentPassword: curr,
                          newPassword: newP,
                          dbaToken: _dbaToken,
                        );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message']?.toString() ?? '✅ Password changed successfully!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          errorMsg = e.toString();
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CSV / EXCEL BULK IMPORT (OPTION 5)
  // ─────────────────────────────────────────────────────────────
  void _openImportCsvDialog() {
    if (_selectedTable == null) return;
    final tableName = _selectedTable!['tableName']?.toString() ?? '';
    final csvController = TextEditingController();
    bool isImporting = false;
    String? importResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2129),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              const Icon(Icons.upload_file_rounded, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Text('Import Records into $tableName',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Paste CSV Data (comma-separated)',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        final colNames = _columns
                            .map((c) => c['columnName'].toString())
                            .where((n) => n != 'id' && !n.contains('created') && !n.contains('updated'))
                            .toList();
                        csvController.text = '${colNames.join(',')}\n';
                      },
                      icon: const Icon(Icons.playlist_add_rounded, size: 14),
                      label: const Text('Insert Headers Template', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: csvController,
                  maxLines: 8,
                  style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF12141A),
                    hintText: 'col1,col2,col3\nval1,val2,val3\nval4,val5,val6',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontFamily: 'monospace'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
                if (importResult != null) ...[
                  const SizedBox(height: 10),
                  Text(importResult!, style: const TextStyle(color: Color(0xFFFF9E77), fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isImporting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: isImporting
                  ? null
                  : () async {
                      final text = csvController.text.trim();
                      if (text.isEmpty) return;
                      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
                      if (lines.length < 2) {
                        setDialogState(() => importResult = 'CSV must have at least 1 header line and 1 data line');
                        return;
                      }
                      final headers = lines[0].split(',').map((h) => h.trim()).toList();
                      final List<Map<String, dynamic>> records = [];
                      for (int i = 1; i < lines.length; i++) {
                        final values = lines[i].split(',').map((v) => v.trim()).toList();
                        final map = <String, dynamic>{};
                        for (int j = 0; j < headers.length && j < values.length; j++) {
                          if (values[j].isNotEmpty) {
                            map[headers[j]] = values[j];
                          }
                        }
                        if (map.isNotEmpty) records.add(map);
                      }
                      setDialogState(() => isImporting = true);
                      try {
                        final repo = ref.read(adminRepositoryProvider);
                        final res = await repo.bulkInsertDatabaseTableRecords(tableName, records, dbaToken: _dbaToken);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(res['message']?.toString() ?? '✅ Import completed!'),
                              backgroundColor: AppTheme.success),
                        );
                        _fetchTableRecords(tableName);
                      } catch (e) {
                        setDialogState(() {
                          isImporting = false;
                          importResult = 'Import failed: $e';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: isImporting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Import Records'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRowDetails(Map<String, dynamic> row) {
    String searchFilter = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final keys = row.keys
              .where((k) =>
                  searchFilter.isEmpty ||
                  k.toLowerCase().contains(searchFilter.toLowerCase()) ||
                  (row[k]?.toString().toLowerCase() ?? '').contains(searchFilter.toLowerCase()))
              .toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E2128),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.35)),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.data_object_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Details • ${_selectedTable?['tableName'] ?? 'Row'}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row.length} fields in record',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all_rounded, color: Colors.white70, size: 18),
                  tooltip: 'Copy Record as JSON',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(row)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Record JSON copied to clipboard!')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: 760,
              height: 540,
              child: Column(
                children: [
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    onChanged: (val) => setModalState(() => searchFilter = val),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF282D37),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
                      hintText: 'Filter attributes or values (${row.length} fields)...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16181E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: ListView.separated(
                        itemCount: keys.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                        itemBuilder: (ctx, i) {
                          final key = keys[i];
                          final val = row[key];
                          final isNull = val == null;
                          final valStr = isNull
                              ? 'NULL'
                              : (val is Map || val is List ? jsonEncode(val) : val.toString());

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 210,
                                  child: Row(
                                    children: [
                                      if (key == 'id' || key.endsWith('_id'))
                                        const Padding(
                                          padding: EdgeInsets.only(right: 5),
                                          child: Icon(Icons.vpn_key_rounded, size: 12, color: Colors.amberAccent),
                                        ),
                                      Expanded(
                                        child: Text(
                                          key,
                                          style: const TextStyle(
                                            color: Color(0xFFFF9E77),
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SelectableText(
                                    valStr,
                                    style: TextStyle(
                                      color: isNull
                                          ? Colors.white30
                                          : valStr.contains('[PROTECTED')
                                              ? Colors.amberAccent
                                              : Colors.white,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white38),
                                  tooltip: 'Copy value',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: valStr));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Copied "$key" to clipboard')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _confirmDeleteRecord(row);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openEditEntryDialog(row);
                },
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit Record', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close', style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MAIN BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // If not authenticated, render the Clean Simple Login Page
    if (!_isAuthenticated) {
      return _buildSimpleDatabaseLoginPage();
    }

    // Authenticated: Render Full Dashboard
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Clean Top Header Bar
          _buildExecutiveHeader(),

          // 2. Main Workspace: Left Table Directory + Right Content View
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Directory (280px width)
                _buildTableDirectoryPane(),

                // Vertical Divider
                VerticalDivider(color: Colors.white.withValues(alpha: 0.08), width: 1),

                // Right Workspace
                Expanded(child: _buildRightContentPane()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SIMPLE CLEAN DATABASE LOGIN PAGE (ONLY USERNAME & PASSWORD)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSimpleDatabaseLoginPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 390,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF181B21),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C313C)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Clean header with logo
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SaarkLogoBadge(size: 34),
                    SizedBox(width: 12),
                    Text(
                      'Database Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Error message if any
                if (_authErrorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _authErrorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Username field
                const Text(
                  'Username',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameController,
                  enabled: !_isAuthLoading,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF222630),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primary, size: 18),
                    hintText: 'Enter username',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                const Text(
                  'Password',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  enabled: !_isAuthLoading,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  onSubmitted: (_) => _handleAuthenticate(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF222630),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primary, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    hintText: 'Enter password',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                // Clean Login Button
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isAuthLoading ? null : _handleAuthenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isAuthLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Login', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),

                // Back / Cancel
                Center(
                  child: TextButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/admin');
                      }
                    },
                    child: const Text('Return to ERP', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CLEAN USER-FRIENDLY HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildExecutiveHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161920),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          // Back to Dashboard button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            tooltip: 'Return to ERP Dashboard',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          const SizedBox(width: 8),

          // Logo badge
          const SaarkLogoBadge(size: 32),
          const SizedBox(width: 12),

          // Title & Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'DATABASE RECORDS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, color: Colors.greenAccent, size: 6),
                          const SizedBox(width: 4),
                          Text(
                            _telemetry?['latencyMs'] != null ? 'Connected (${_telemetry!['latencyMs']}ms)' : 'Connected',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_tables.length} Tables • ${_formatNumber(_totalEstimatedRecords)} Live Records',
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'PostgreSQL Enterprise Explorer • Browse and manage records across all business modules',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                ),
              ],
            ),
          ),

          // Active User / Admin Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF222630),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  _authenticatedUser?['name']?.toString() ?? 'Administrator',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Change Master Password Action
          IconButton(
            icon: const Icon(Icons.key_rounded, color: Colors.amberAccent, size: 19),
            tooltip: 'Change Database Password',
            onPressed: _openChangePasswordDialog,
          ),
          const SizedBox(width: 2),

          // Database Snapshot Backup Action
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.lightBlueAccent, size: 20),
            tooltip: 'Create Database Snapshot Backup',
            onPressed: _triggerDatabaseBackup,
          ),
          const SizedBox(width: 2),

          // Reload button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            tooltip: 'Refresh Database',
            onPressed: _fetchTablesAndTelemetry,
          ),
          const SizedBox(width: 4),

          // Lock Session Action
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded, color: Colors.white60, size: 20),
            tooltip: 'Lock Database Session',
            onPressed: _lockSession,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EXECUTIVE KPI CARDS BANNER
  // ─────────────────────────────────────────────────────────────
  String _formatNumber(int num) {
    return num.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  // ─────────────────────────────────────────────────────────────
  // LEFT TABLE DIRECTORY PANE (MODULE-WISE GROUPING & LIST)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTableDirectoryPane() {
    // Group filtered tables by category
    final Map<String, List<Map<String, dynamic>>> groupedTables = {};
    for (final t in _filteredTables) {
      final cat = t['category']?.toString() ?? 'SYSTEM_CORE';
      groupedTables.putIfAbsent(cat, () => []).add(t);
    }

    return SizedBox(
      width: 320,
      child: Column(
        children: [
          // Filter / Search Bar with Group by Module toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              children: [
                TextField(
                  controller: _tableSearchController,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  onChanged: (_) => _applyTableFilters(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF222630),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                    suffixIcon: _tableSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                            onPressed: () {
                              _tableSearchController.clear();
                              _applyTableFilters();
                            },
                          )
                        : null,
                    hintText: 'Search ${_tables.length} tables...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 14, color: Color(0xFFFF9E77)),
                    const SizedBox(width: 6),
                    const Text('Group by Module', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const Spacer(),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: _groupByModule,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) => setState(() => _groupByModule = val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category Chips Bar
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: moduleRegistry.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final mod = moduleRegistry[i];
                final key = mod['key'] as String;
                final isSelected = _activeCategory == key;
                final count = key == 'ALL' ? _tables.length : (_categorySummary[key] ?? 0);

                return ChoiceChip(
                  label: Text(
                    '${mod['label']} ($count)',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: const Color(0xFF222630),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _activeCategory = key);
                      _applyTableFilters();
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Count Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: Colors.black.withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _groupByModule
                      ? 'MODULES (${groupedTables.length}) • TABLES (${_filteredTables.length})'
                      : 'MATCHED TABLES (${_filteredTables.length})',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  'Rows',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9.5),
                ),
              ],
            ),
          ),

          // Tables List (Grouped or Flat)
          Expanded(
            child: _isLoadingTables
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                : _filteredTables.isEmpty
                    ? Center(
                        child: Text(
                          'No tables found matching criteria',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                        ),
                      )
                    : _groupByModule
                        ? _buildGroupedModuleTableList(groupedTables)
                        : _buildFlatTableList(_filteredTables),
          ),
        ],
      ),
    );
  }

  // Grouped Module Accordion List
  Widget _buildGroupedModuleTableList(Map<String, List<Map<String, dynamic>>> groupedTables) {
    return ListView.builder(
      itemCount: moduleRegistry.length,
      itemBuilder: (ctx, idx) {
        final mod = moduleRegistry[idx];
        final catKey = mod['key'] as String;
        if (catKey == 'ALL') return const SizedBox.shrink();

        final tableList = groupedTables[catKey];
        if (tableList == null || tableList.isEmpty) return const SizedBox.shrink();

        final totalRows = tableList.fold<int>(0, (sum, t) => sum + (t['estimatedRowCount'] is int ? t['estimatedRowCount'] as int : 0));
        final modColor = mod['color'] as Color? ?? AppTheme.primary;
        final modIcon = mod['icon'] as IconData? ?? Icons.folder_rounded;

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            backgroundColor: const Color(0xFF13161C),
            collapsedBackgroundColor: Colors.transparent,
            leading: Icon(modIcon, size: 16, color: modColor),
            title: Text(
              mod['label'].toString(),
              style: TextStyle(color: modColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${tableList.length} tables • $totalRows total rows',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
            ),
            children: tableList.map((t) => _buildTableListItem(t)).toList(),
          ),
        );
      },
    );
  }

  // Flat Table List
  Widget _buildFlatTableList(List<Map<String, dynamic>> tables) {
    return ListView.builder(
      itemCount: tables.length,
      itemBuilder: (ctx, i) => _buildTableListItem(tables[i]),
    );
  }

  Widget _buildTableListItem(Map<String, dynamic> item) {
    final name = item['tableName'] ?? '';
    final rowCount = item['estimatedRowCount'] ?? 0;
    final isSelected = _selectedTable?['tableName'] == name;

    return InkWell(
      onTap: () => _selectTable(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.16) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 3.5,
            ),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.table_chart_outlined, size: 14, color: Colors.white38),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF9E77) : Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // + Entry Quick Action
            InkWell(
              onTap: () => _openInsertEntryDialog(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.add, size: 12, color: Color(0xFFFF9E77)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: rowCount > 0 ? Colors.green.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$rowCount rows',
                style: TextStyle(
                  color: rowCount > 0 ? Colors.greenAccent : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RIGHT CONTENT PANE
  // ─────────────────────────────────────────────────────────────
  Widget _buildRightContentPane() {
    return Column(
      children: [
        // Tab Header Bar
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF191C24),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
                labelColor: const Color(0xFFFF9E77),
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.table_rows_rounded, size: 16), text: 'Records Table'),
                  Tab(icon: Icon(Icons.grid_view_rounded, size: 16), text: 'Module Overview'),
                  Tab(icon: Icon(Icons.terminal_rounded, size: 16), text: 'SQL Query Console'),
                ],
              ),
              const Spacer(),
              if (_selectedTable != null)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _selectedTable!['tableName']?.toString() ?? '',
                          style: const TextStyle(
                            color: Color(0xFFFF9E77),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _openInsertEntryDialog(_selectedTable!),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Record', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 18),
                        tooltip: 'Export Current Records to CSV',
                        onPressed: () => _copyTableDataAsCsv(
                          _rows,
                          _columns.map((c) => c['columnName'].toString()).toList(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.data_object_rounded, color: Colors.white70, size: 18),
                        tooltip: 'Export Current Records to JSON',
                        onPressed: () => _copyTableDataAsJson(_rows),
                      ),
                      IconButton(
                        icon: const Icon(Icons.upload_file_rounded, color: Colors.white70, size: 18),
                        tooltip: 'Import Records from CSV',
                        onPressed: _openImportCsvDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                        tooltip: 'Reload Records',
                        onPressed: () {
                          if (_selectedTable != null) {
                            _fetchTableRecords(_selectedTable!['tableName'].toString());
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLiveRecordsTab(),
              _buildModuleDirectoryTab(),
              _buildSqlConsoleTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: LIVE RECORDS DATA GRID
  // ─────────────────────────────────────────────────────────────
  Widget _buildLiveRecordsTab() {
    if (_selectedTable == null) {
      return const Center(
        child: Text(
          'Select a table from the left directory to inspect database records.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final tableName = _selectedTable!['tableName']?.toString() ?? '';

    return Column(
      children: [
        // Records toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF161920),
          child: Row(
            children: [
              // Search input
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _recordSearchController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  onSubmitted: (q) {
                    setState(() => _currentPage = 1);
                    _fetchTableRecords(tableName, search: q);
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF222630),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
                    suffixIcon: _recordSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14, color: Colors.white54),
                            onPressed: () {
                              _recordSearchController.clear();
                              setState(() => _currentPage = 1);
                              _fetchTableRecords(tableName, search: '');
                            },
                          )
                        : null,
                    hintText: 'Search records in $tableName...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() => _currentPage = 1);
                  _fetchTableRecords(tableName);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B303C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Filter', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 10),

              // + Insert Database Entry button
              ElevatedButton.icon(
                onPressed: () => _openInsertEntryDialog(_selectedTable!),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const Spacer(),

              // Page size dropdown
              Text('Rows / page: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF222630),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<int>(
                  value: _limit,
                  dropdownColor: const Color(0xFF222630),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: [10, 25, 50, 100].map((n) {
                    return DropdownMenuItem(value: n, child: Text('$n'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _limit = val;
                        _currentPage = 1;
                      });
                      _fetchTableRecords(tableName);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Pagination controls
              Text(
                'Page $_currentPage of $_totalPages ($_totalRows records)',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 20),
                tooltip: 'Previous Page',
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _fetchTableRecords(tableName);
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                tooltip: 'Next Page',
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _fetchTableRecords(tableName);
                      }
                    : null,
              ),
            ],
          ),
        ),

        // Data Table Grid
        Expanded(
          child: _isLoadingRecords
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_rounded, size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            'Table "$tableName" has 0 matching records.',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _openInsertEntryDialog(_selectedTable!),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Insert First Record Entry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
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
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF1E2129)),
                            dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                              (states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return AppTheme.primary.withValues(alpha: 0.12);
                                }
                                return null;
                              },
                            ),
                            headingTextStyle: const TextStyle(
                              color: Color(0xFFFF9E77),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            dataTextStyle: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                            ),
                            columnSpacing: 22,
                            horizontalMargin: 16,
                            dividerThickness: 0.5,
                            columns: [
                              const DataColumn(label: Text('ACTION')),
                              ..._columns.map((c) {
                                final colName = c['columnName'].toString();
                                final isPk = c['isPrimaryKey'] == true;
                                final dType = c['dataType']?.toString() ?? '';
                                final isSorted = _sortBy == colName;

                                return DataColumn(
                                  label: InkWell(
                                    onTap: () => _handleSort(colName),
                                    child: Tooltip(
                                      message: 'Column: $colName\nType: $dType${isPk ? ' • Primary Key' : ''}\nClick to sort',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isPk)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 4),
                                              child: Icon(Icons.vpn_key_rounded, size: 12, color: Colors.amberAccent),
                                            ),
                                          Text(colName),
                                          if (isSorted) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              _sortOrder == 'ASC' ? Icons.arrow_upward : Icons.arrow_downward,
                                              size: 13,
                                              color: AppTheme.primary,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                            rows: _rows.map((row) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // View
                                        InkWell(
                                          onTap: () => _showRowDetails(row),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF282D37),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.visibility_outlined, size: 12, color: Color(0xFFFF9E77)),
                                                SizedBox(width: 4),
                                                Text('View', style: TextStyle(color: Color(0xFFFF9E77), fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Edit
                                        InkWell(
                                          onTap: () => _openEditEntryDialog(row),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit_outlined, size: 12, color: AppTheme.primary),
                                                SizedBox(width: 3),
                                                Text('Edit', style: TextStyle(color: AppTheme.primary, fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Delete
                                        InkWell(
                                          onTap: () => _confirmDeleteRecord(row),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(Icons.delete_outline_rounded, size: 13, color: Colors.redAccent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._columns.map((col) {
                                    final colName = col['columnName'].toString();
                                    final val = row[colName];
                                    final isNull = val == null;
                                    String text = isNull ? '—' : val.toString();

                                    Color cellColor = Colors.white;
                                    if (isNull) {
                                      cellColor = Colors.white30;
                                    } else if (text.contains('[PROTECTED')) {
                                      text = '••••••••••••';
                                      cellColor = Colors.white38;
                                    } else if (text == 'true') {
                                      cellColor = Colors.greenAccent;
                                    } else if (text == 'false') {
                                      cellColor = Colors.redAccent;
                                    }

                                    return DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 240),
                                        child: Text(
                                          text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: cellColor,
                                            fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
                                          ),
                                        ),
                                      ),
                                      onTap: () => _showRowDetails(row),
                                    );
                                  }),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: MODULE-WISE DIRECTORY & TABLE EXPLORER
  // ─────────────────────────────────────────────────────────────
  Widget _buildModuleDirectoryTab() {
    // Group all tables by category
    final Map<String, List<Map<String, dynamic>>> moduleGroups = {};
    for (final t in _tables) {
      final cat = t['category']?.toString() ?? 'SYSTEM_CORE';
      moduleGroups.putIfAbsent(cat, () => []).add(t);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'MODULE-WISE DATABASE SCHEMAS & ENTRIES',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.6),
              ),
              const Spacer(),
              Text(
                '${moduleGroups.length} Active Modules • ${_tables.length} Total Tables',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Explore database tables grouped by business domain. Inspect live records or insert new database entries directly.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
          ),
          const SizedBox(height: 20),

          // Render module cards
          ...moduleRegistry.where((m) => m['key'] != 'ALL').map((mod) {
            final catKey = mod['key'] as String;
            final tablesInMod = moduleGroups[catKey] ?? [];
            if (tablesInMod.isEmpty) return const SizedBox.shrink();

            final modTitle = mod['label'] as String;
            final modIcon = mod['icon'] as IconData? ?? Icons.folder_rounded;
            final modColor = mod['color'] as Color? ?? AppTheme.primary;
            final totalRows = tablesInMod.fold<int>(0, (sum, t) => sum + (t['estimatedRowCount'] is int ? t['estimatedRowCount'] as int : 0));

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF191C24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: modColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Module Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: modColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(modIcon, color: modColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              modTitle,
                              style: TextStyle(color: modColor, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${tablesInMod.length} tables in module • $totalRows total persisted records',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                  const SizedBox(height: 14),

                  // Tables within this module
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: tablesInMod.map((tbl) {
                      final name = tbl['tableName']?.toString() ?? '';
                      final rCount = tbl['estimatedRowCount'] ?? 0;
                      final cCount = tbl['columnCount'] ?? 0;

                      return Container(
                        width: 290,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222630),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: rCount > 0 ? Colors.green.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$rCount rows',
                                    style: TextStyle(
                                      color: rCount > 0 ? Colors.greenAccent : Colors.white38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$cCount columns in table schema',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10.5),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _selectTable(tbl, targetTab: 0),
                                    icon: const Icon(Icons.table_rows_rounded, size: 12),
                                    label: const Text('View Records', style: TextStyle(fontSize: 10.5)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openInsertEntryDialog(tbl),
                                    icon: const Icon(Icons.add, size: 12),
                                    label: const Text('+ Entry', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: SQL QUERY CONSOLE
  // ─────────────────────────────────────────────────────────────
  Widget _buildSqlConsoleTab() {
    final presets = [
      {'name': 'Users (Recent 20)', 'sql': 'SELECT id, username, email, status, created_at FROM "users" ORDER BY created_at DESC LIMIT 20;'},
      {'name': 'Top 10 Tables by Rows', 'sql': 'SELECT relname AS table_name, n_live_tup AS row_count FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 10;'},
      {'name': 'Audit Logs (Recent 25)', 'sql': 'SELECT id, action, module, user_email, ip_address, created_at FROM "audit_logs" ORDER BY created_at DESC LIMIT 25;'},
      {'name': 'Customer Count by Status', 'sql': 'SELECT status, count(*) AS count FROM "customers" GROUP BY status;'},
      {'name': 'Panel Specs (Recent 15)', 'sql': 'SELECT id, spec_number, project_name, status, created_at FROM "panel_specs" ORDER BY created_at DESC LIMIT 15;'},
      {'name': 'Sales Orders by Grand Total', 'sql': 'SELECT order_number, total_amount, payment_status, created_at FROM "sales_orders" ORDER BY total_amount DESC LIMIT 15;'},
    ];

    return Column(
      children: [
        // Console Toolbar & Presets
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF1E222A),
          child: Row(
            children: [
              const Icon(Icons.code_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'SAFE READ-ONLY SQL CONSOLE',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const Spacer(),
              const Text('Presets: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF282D37),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  hint: const Text('Load query template...', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF282D37),
                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                  items: presets.map((p) {
                    return DropdownMenuItem(value: p['sql'], child: Text(p['name']!));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _sqlQueryController.text = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isRunningQuery ? null : _runCustomQuery,
                icon: _isRunningQuery
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(_isRunningQuery ? 'Running...' : 'Execute SQL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),

        // SQL Input Textfield
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF12141A),
          child: TextField(
            controller: _sqlQueryController,
            maxLines: 4,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Enter read-only SQL query (SELECT / EXPLAIN)...',
              hintStyle: TextStyle(color: Colors.white30, fontFamily: 'monospace'),
            ),
          ),
        ),

        // Error Notice if any
        if (_queryError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _queryError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11.5, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),

        // Result Status Header
        if (_queryExecutionTimeMs != null && _queryError == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF1A1D24),
            child: Row(
              children: [
                Text(
                  'Query returned ${_queryRows.length} rows in ${_queryExecutionTimeMs}ms',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 16),
                  tooltip: 'Export Result as CSV',
                  onPressed: () => _copyTableDataAsCsv(_queryRows, _queryColumns),
                ),
              ],
            ),
          ),

        // Query Results Table
        Expanded(
          child: _queryRows.isEmpty
              ? Center(
                  child: Text(
                    _isRunningQuery ? 'Executing SQL query...' : 'Execute a query above to view results.',
                    style: const TextStyle(color: Colors.white38),
                  ),
                )
              : Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF222630)),
                        headingTextStyle: const TextStyle(color: Color(0xFFFF9E77), fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        dataTextStyle: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                        columns: _queryColumns.map((col) => DataColumn(label: Text(col))).toList(),
                        rows: _queryRows.map((row) {
                          return DataRow(
                            cells: _queryColumns.map((col) {
                              final val = row[col];
                              final isNull = val == null;
                              return DataCell(
                                Text(
                                  isNull ? 'NULL' : val.toString(),
                                  style: TextStyle(
                                    color: isNull ? Colors.white30 : Colors.white,
                                    fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
