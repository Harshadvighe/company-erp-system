import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/widgets/saark_logo.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';

/// Full Industrial PostgreSQL Database Record Explorer
/// Provides enterprise-grade live table exploration, data dictionary, sensitive field masking, and SQL query console.
class PostgreSqlDatabaseExplorerDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialTelemetry;
  final Map<String, dynamic>? authenticatedUser;
  final String? dbaToken;
  final int? expiresInSeconds;

  const PostgreSqlDatabaseExplorerDialog({
    super.key,
    this.initialTelemetry,
    this.authenticatedUser,
    this.dbaToken,
    this.expiresInSeconds,
  });

  @override
  ConsumerState<PostgreSqlDatabaseExplorerDialog> createState() =>
      _PostgreSqlDatabaseExplorerDialogState();
}

class _PostgreSqlDatabaseExplorerDialogState
    extends ConsumerState<PostgreSqlDatabaseExplorerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Session Lease Timer
  Timer? _leaseTimer;
  int _remainingLeaseSeconds = 1800; // 30 minutes default

  // Telemetry & tables
  bool _isLoadingTables = true;
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _filteredTables = [];
  String _activeCategory = 'ALL';
  final _tableSearchController = TextEditingController();
  Map<String, dynamic>? _selectedTable;
  Map<String, dynamic>? _telemetry;

  // Selected table records
  bool _isLoadingRecords = false;
  List<Map<String, dynamic>> _columns = [];
  List<Map<String, dynamic>> _rows = [];
  int _totalRows = 0;
  int _currentPage = 1;
  int _limit = 25;
  int _totalPages = 1;
  String? _sortBy;
  String _sortOrder = 'ASC';
  bool _maskSensitive = true;
  final _recordSearchController = TextEditingController();

  // SQL Console
  final _sqlQueryController = TextEditingController(
    text: 'SELECT * FROM "users" LIMIT 10;',
  );
  bool _isRunningQuery = false;
  String? _queryError;
  int? _queryExecutionTimeMs;
  List<String> _queryColumns = [];
  List<Map<String, dynamic>> _queryRows = [];
  final List<String> _queryHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _telemetry = widget.initialTelemetry;
    _remainingLeaseSeconds = widget.expiresInSeconds ?? 1800;
    _startLeaseTimer();
    _fetchTablesAndTelemetry();
  }

  @override
  void dispose() {
    _leaseTimer?.cancel();
    _tabController.dispose();
    _tableSearchController.dispose();
    _recordSearchController.dispose();
    _sqlQueryController.dispose();
    super.dispose();
  }

  void _startLeaseTimer() {
    _leaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingLeaseSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('DBA session expired for security. Please re-authenticate.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        setState(() => _remainingLeaseSeconds--);
      }
    });
  }

  String _formatLeaseCountdown(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

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

      setState(() {
        _tables = parsed;
        _telemetry = telemetryData['data'] is Map
            ? Map<String, dynamic>.from(telemetryData['data'])
            : Map<String, dynamic>.from(telemetryData);
        _isLoadingTables = false;
      });

      _applyTableFilters();

      // Default select "users" or the first table
      if (parsed.isNotEmpty && _selectedTable == null) {
        final defaultTable = parsed.firstWhere(
          (t) => t['tableName'] == 'users',
          orElse: () => parsed.first,
        );
        _selectTable(defaultTable);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTables = false);
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

  Future<void> _selectTable(Map<String, dynamic> table) async {
    setState(() {
      _selectedTable = table;
      _currentPage = 1;
      _sortBy = null;
      _sortOrder = 'ASC';
      _recordSearchController.clear();
    });
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
        dbaToken: widget.dbaToken,
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
      if (_queryHistory.length > 20) _queryHistory.removeLast();
    }

    setState(() {
      _isRunningQuery = true;
      _queryError = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.executeDatabaseQuery(sql, limit: 100, dbaToken: widget.dbaToken);

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
          _queryError = res['message']?.toString() ?? 'Query failed';
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
    if (rows.isEmpty || colNames.isEmpty) return;
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
      const SnackBar(content: Text('Table records exported as CSV to clipboard!'), duration: Duration(seconds: 2)),
    );
  }

  void _showRowDetails(Map<String, dynamic> row) {
    String searchFilter = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final keys = row.keys.where((k) => searchFilter.isEmpty || k.toLowerCase().contains(searchFilter.toLowerCase())).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E2128),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: const Color(0xFFF15A24).withValues(alpha: 0.3)),
            ),
            title: Row(
              children: [
                const Icon(Icons.data_object_rounded, color: Color(0xFFF15A24), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Record Inspector • ${_selectedTable?['tableName'] ?? 'Row'}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all_rounded, color: Colors.white70, size: 18),
                  tooltip: 'Copy as JSON',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(row)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copied to clipboard!'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    onChanged: (val) => setModalState(() => searchFilter = val),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF282D37),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
                      hintText: 'Search fields (${row.length} attributes)...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: keys.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      itemBuilder: (ctx, i) {
                        final key = keys[i];
                        final val = row[key];
                        final isNull = val == null;
                        final valStr = isNull ? 'NULL' : (val is Map || val is List ? jsonEncode(val) : val.toString());

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 220,
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                    color: Color(0xFFFF9E77),
                                    fontFamily: 'monospace',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close', style: TextStyle(color: Color(0xFFF15A24))),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dbaName = widget.authenticatedUser?['fullName'] ?? 'Administrator';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: screenSize.width * 0.96,
        height: screenSize.height * 0.94,
        decoration: BoxDecoration(
          color: const Color(0xFF16181E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF15A24).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Telemetry Header Bar
            _buildTopTelemetryHeader(dbaName),

            // Main Workspace: Left Categorized Directory + Right Panel
            Expanded(
              child: Row(
                children: [
                  _buildTableDirectoryPane(),
                  VerticalDivider(color: Colors.white.withValues(alpha: 0.08), width: 1),
                  Expanded(child: _buildRightContentPane()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTelemetryHeader(String dbaName) {
    final latency = _telemetry?['latencyMs'] ?? 0;
    final totalTables = _tables.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF20242E),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      child: Row(
        children: [
          const SaarkLogoBadge(size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'PostgreSQL 16.3 Relational Database Explorer',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                        SizedBox(width: 5),
                        Text(
                          'ONLINE POOLER',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF15A24).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '⚡ ${latency}ms latency',
                      style: const TextStyle(color: Color(0xFFFF9E77), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Supabase PgBouncer (Port 6543) • AWS ap-southeast-1 • $totalTables Tables • DBA: $dbaName',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5),
              ),
            ],
          ),
          const Spacer(),

          // Session Lease Timer Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF282D37),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _remainingLeaseSeconds < 300 ? Colors.redAccent : Colors.white24,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 15,
                  color: _remainingLeaseSeconds < 300 ? Colors.redAccent : const Color(0xFFFF9E77),
                ),
                const SizedBox(width: 6),
                Text(
                  'Lease: ${_formatLeaseCountdown(_remainingLeaseSeconds)}',
                  style: TextStyle(
                    color: _remainingLeaseSeconds < 300 ? Colors.redAccent : Colors.white,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Sensitive field mask toggle
          IconButton(
            icon: Icon(
              _maskSensitive ? Icons.shield_rounded : Icons.shield_outlined,
              color: _maskSensitive ? Colors.greenAccent : Colors.amberAccent,
              size: 20,
            ),
            tooltip: _maskSensitive ? 'Sensitive Hash Masking: ON (Click to toggle)' : 'Sensitive Hash Masking: OFF',
            onPressed: () {
              setState(() => _maskSensitive = !_maskSensitive);
              if (_selectedTable != null) {
                _fetchTableRecords(_selectedTable!['tableName'].toString());
              }
            },
          ),

          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            tooltip: 'Reload Database Schema & Telemetry',
            onPressed: _fetchTablesAndTelemetry,
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.lock_rounded, color: Color(0xFFF15A24), size: 20),
            tooltip: 'Lock DBA Session & Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableDirectoryPane() {
    final categories = [
      {'key': 'ALL', 'label': 'All (${_tables.length})'},
      {'key': 'AUTH_SECURITY', 'label': 'Auth'},
      {'key': 'HR_WORKFORCE', 'label': 'HR'},
      {'key': 'CRM_CUSTOMERS', 'label': 'CRM'},
      {'key': 'SALES_BILLING', 'label': 'Sales'},
      {'key': 'B2B_TRADING', 'label': 'B2B'},
      {'key': 'MANUFACTURING', 'label': 'Panels'},
      {'key': 'PURCHASE_VENDORS', 'label': 'Purch.'},
      {'key': 'INVENTORY_STORE', 'label': 'Store'},
      {'key': 'SYSTEM_CORE', 'label': 'Core'},
    ];

    return SizedBox(
      width: 290,
      child: Column(
        children: [
          // Search Table Bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
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
                hintText: 'Filter ${_tables.length} tables...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Category Chips Bar (horizontal scroll)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final isSelected = _activeCategory == cat['key'];

                return ChoiceChip(
                  label: Text(
                    cat['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFF15A24),
                  backgroundColor: const Color(0xFF222630),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _activeCategory = cat['key']!);
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.black.withValues(alpha: 0.25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MATCHED TABLES (${_filteredTables.length})',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const Icon(Icons.table_view_rounded, color: Colors.white38, size: 14),
              ],
            ),
          ),

          // Tables List View
          Expanded(
            child: _isLoadingTables
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF15A24), strokeWidth: 2))
                : ListView.builder(
                    itemCount: _filteredTables.length,
                    itemBuilder: (ctx, i) {
                      final item = _filteredTables[i];
                      final name = item['tableName'] ?? '';
                      final rowCount = item['estimatedRowCount'] ?? 0;
                      final colCount = item['columnCount'] ?? 0;
                      final isSelected = _selectedTable?['tableName'] == name;

                      IconData catIcon = Icons.table_rows_rounded;
                      switch (item['category']) {
                        case 'AUTH_SECURITY':
                          catIcon = Icons.security_rounded;
                          break;
                        case 'HR_WORKFORCE':
                          catIcon = Icons.people_rounded;
                          break;
                        case 'CRM_CUSTOMERS':
                          catIcon = Icons.business_rounded;
                          break;
                        case 'SALES_BILLING':
                          catIcon = Icons.receipt_long_rounded;
                          break;
                        case 'B2B_TRADING':
                          catIcon = Icons.storefront_rounded;
                          break;
                        case 'MANUFACTURING':
                          catIcon = Icons.precision_manufacturing_rounded;
                          break;
                        case 'PURCHASE_VENDORS':
                          catIcon = Icons.shopping_cart_rounded;
                          break;
                        case 'INVENTORY_STORE':
                          catIcon = Icons.inventory_2_rounded;
                          break;
                      }

                      return InkWell(
                        onTap: () => _selectTable(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF15A24).withValues(alpha: 0.16)
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isSelected ? const Color(0xFFF15A24) : Colors.transparent,
                                width: 3,
                              ),
                              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                catIcon,
                                size: 16,
                                color: isSelected ? const Color(0xFFF15A24) : Colors.white38,
                              ),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: rowCount > 0
                                      ? Colors.green.withValues(alpha: 0.16)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$rowCount rows • $colCount cols',
                                  style: TextStyle(
                                    color: rowCount > 0 ? Colors.greenAccent : Colors.white38,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightContentPane() {
    return Column(
      children: [
        // Tab Header
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF20242E),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)),
          ),
          child: Row(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFFF15A24),
                indicatorWeight: 3,
                labelColor: const Color(0xFFFF9E77),
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.table_chart_rounded, size: 16), text: 'Live Records'),
                  Tab(icon: Icon(Icons.schema_rounded, size: 16), text: 'Data Dictionary'),
                  Tab(icon: Icon(Icons.terminal_rounded, size: 16), text: 'SQL Terminal'),
                ],
              ),
              const Spacer(),
              if (_selectedTable != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      const Text('Schema: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text(
                        'public.${_selectedTable!['tableName']}',
                        style: const TextStyle(
                          color: Color(0xFFFF9E77),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 18),
                        tooltip: 'Export Current Page to CSV',
                        onPressed: () => _copyTableDataAsCsv(
                          _rows,
                          _columns.map((c) => c['columnName'].toString()).toList(),
                        ),
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
              _buildTableSchemaTab(),
              _buildSqlConsoleTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveRecordsTab() {
    if (_selectedTable == null) {
      return const Center(
        child: Text('Select a table from the left directory to inspect records.', style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: [
        // Records toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1B1E24),
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
                    _fetchTableRecords(_selectedTable!['tableName'].toString(), search: q);
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF252932),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 16),
                    hintText: 'Search records in ${_selectedTable!['tableName']}...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.search, color: Color(0xFFF15A24), size: 18),
                tooltip: 'Run Search',
                onPressed: () {
                  setState(() => _currentPage = 1);
                  _fetchTableRecords(_selectedTable!['tableName'].toString());
                },
              ),
              const Spacer(),

              // Rows per page selector
              const Text('Rows: ', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
              DropdownButton<int>(
                value: _limit,
                dropdownColor: const Color(0xFF222630),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                underline: const SizedBox(),
                items: [10, 25, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _limit = val;
                      _currentPage = 1;
                    });
                    _fetchTableRecords(_selectedTable!['tableName'].toString());
                  }
                },
              ),
              const SizedBox(width: 14),

              // Pagination controls
              Text(
                '$_totalRows total • Page $_currentPage of $_totalPages',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.first_page_rounded, color: Colors.white70, size: 20),
                tooltip: 'First Page',
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage = 1);
                        _fetchTableRecords(_selectedTable!['tableName'].toString());
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70, size: 20),
                tooltip: 'Previous Page',
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _fetchTableRecords(_selectedTable!['tableName'].toString());
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                tooltip: 'Next Page',
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _fetchTableRecords(_selectedTable!['tableName'].toString());
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, color: Colors.white70, size: 20),
                tooltip: 'Last Page',
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage = _totalPages);
                        _fetchTableRecords(_selectedTable!['tableName'].toString());
                      }
                    : null,
              ),
            ],
          ),
        ),

        // Data Table
        Expanded(
          child: _isLoadingRecords
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF15A24)))
              : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text(
                            'No records found in table "${_selectedTable!['tableName']}"',
                            style: const TextStyle(color: Colors.white54),
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
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF222630)),
                            dataRowColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.hovered)
                                  ? const Color(0xFF282D37)
                                  : const Color(0xFF181B20),
                            ),
                            headingTextStyle: const TextStyle(
                              color: Color(0xFFFF9E77),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                            dataTextStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                            ),
                            columnSpacing: 18,
                            horizontalMargin: 14,
                            columns: [
                              const DataColumn(label: Text('INSPECT')),
                              ..._columns.map((c) {
                                final colName = c['columnName'].toString();
                                final isPK = c['isPrimaryKey'] == true;
                                final isSorted = _sortBy?.toLowerCase() == colName.toLowerCase();

                                return DataColumn(
                                  label: InkWell(
                                    onTap: () => _handleSort(colName),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPK) ...[
                                          const Text('🔑 ', style: TextStyle(fontSize: 11)),
                                        ],
                                        Text(colName),
                                        if (isSorted) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            _sortOrder == 'ASC' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                            size: 13,
                                            color: const Color(0xFFF15A24),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                            rows: _rows.map((row) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFFF15A24)),
                                      tooltip: 'Inspect Row JSON',
                                      onPressed: () => _showRowDetails(row),
                                    ),
                                  ),
                                  ..._columns.map((c) {
                                    final colName = c['columnName'];
                                    final val = row[colName];
                                    final isNull = val == null;
                                    String displayStr = isNull ? 'NULL' : (val is Map || val is List ? jsonEncode(val) : val.toString());
                                    if (displayStr.length > 55) {
                                      displayStr = '${displayStr.substring(0, 52)}...';
                                    }

                                    final isProtected = displayStr.contains('[PROTECTED');

                                    return DataCell(
                                      Text(
                                        displayStr,
                                        style: TextStyle(
                                          color: isNull
                                              ? Colors.white24
                                              : isProtected
                                                  ? Colors.amberAccent
                                                  : Colors.white,
                                          fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
                                          fontWeight: isProtected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildTableSchemaTab() {
    if (_columns.isEmpty) {
      return const Center(child: Text('No columns found for this table.', style: TextStyle(color: Colors.white54)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF222630)),
        headingTextStyle: const TextStyle(color: Color(0xFFFF9E77), fontWeight: FontWeight.bold, fontSize: 12),
        dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('COLUMN NAME')),
          DataColumn(label: Text('KEY')),
          DataColumn(label: Text('DATA TYPE')),
          DataColumn(label: Text('NULLABLE')),
          DataColumn(label: Text('DEFAULT')),
          DataColumn(label: Text('MAX LENGTH')),
        ],
        rows: _columns.map((c) {
          final isNull = c['isNullable'] == true;
          final isPK = c['isPrimaryKey'] == true;

          return DataRow(
            cells: [
              DataCell(Text('${c['ordinalPosition'] ?? ''}')),
              DataCell(
                Text(
                  '${c['columnName']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                isPK
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔑 PK', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : const Text('—', style: TextStyle(color: Colors.white30)),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF15A24).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${c['dataType']}', style: const TextStyle(color: Color(0xFFFF9E77))),
                ),
              ),
              DataCell(
                Text(
                  isNull ? 'YES' : 'NO',
                  style: TextStyle(color: isNull ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text('${c['columnDefault'] ?? 'None'}', style: TextStyle(color: c['columnDefault'] != null ? Colors.white70 : Colors.white30))),
              DataCell(Text('${c['maxLength'] ?? '—'}')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSqlConsoleTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preset Query Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Text('Quick Queries: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
              _buildQueryChip('SELECT * FROM "users" LIMIT 10;'),
              _buildQueryChip('SELECT * FROM "user_sessions" ORDER BY "loginTime" DESC LIMIT 10;'),
              _buildQueryChip('SELECT * FROM "audit_logs" ORDER BY "timestamp" DESC LIMIT 10;'),
              _buildQueryChip('SELECT * FROM "employees" LIMIT 10;'),
              _buildQueryChip('SELECT * FROM "b2b_products" LIMIT 10;'),
              _buildQueryChip('SELECT count(*) FROM "customers";'),
            ],
          ),
          const SizedBox(height: 12),

          // Query Editor Box
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _sqlQueryController,
                  maxLines: 4,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter read-only SQL query (SELECT / EXPLAIN)...',
                    hintStyle: TextStyle(color: Colors.white24),
                    contentPadding: EdgeInsets.all(12),
                    border: InputBorder.none,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: const Color(0xFF222630),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, size: 14, color: Colors.greenAccent),
                      const SizedBox(width: 6),
                      const Text(
                        'DBA Read-Only Firewall Active (Mutations Blocked)',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: _isRunningQuery
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Execute Query'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF15A24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _isRunningQuery ? null : _runCustomQuery,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Query Result Stats / Error
          if (_queryError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Text(_queryError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            )
          else if (_queryExecutionTimeMs != null)
            Row(
              children: [
                Text(
                  'Query executed in ${_queryExecutionTimeMs}ms • ${_queryRows.length} rows returned',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFFFF9E77)),
                  label: const Text('Export CSV', style: TextStyle(color: Color(0xFFFF9E77), fontSize: 11.5)),
                  onPressed: () => _copyTableDataAsCsv(_queryRows, _queryColumns),
                ),
              ],
            ),

          // Query Results Table
          Expanded(
            child: _queryRows.isEmpty
                ? const Center(
                    child: Text(
                      'Run a SQL query above to view results.',
                      style: TextStyle(color: Colors.white38),
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
                          columns: [
                            const DataColumn(label: Text('INSPECT')),
                            ..._queryColumns.map(
                              (c) => DataColumn(
                                label: Text(c, style: const TextStyle(color: Color(0xFFFF9E77), fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                          rows: _queryRows.map((r) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFFF15A24)),
                                    onPressed: () => _showRowDetails(r),
                                  ),
                                ),
                                ..._queryColumns.map((col) {
                                  final val = r[col];
                                  final isNull = val == null;
                                  return DataCell(
                                    Text(
                                      isNull ? 'NULL' : (val is Map || val is List ? jsonEncode(val) : val.toString()),
                                      style: TextStyle(color: isNull ? Colors.white30 : Colors.white, fontFamily: 'monospace', fontSize: 11.5),
                                    ),
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
      ),
    );
  }

  Widget _buildQueryChip(String sql) {
    return ActionChip(
      label: Text(sql, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
      backgroundColor: const Color(0xFF222630),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      onPressed: () {
        setState(() => _sqlQueryController.text = sql);
        _runCustomQuery();
      },
    );
  }
}
