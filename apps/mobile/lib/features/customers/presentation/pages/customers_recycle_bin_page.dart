import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';

class CustomersRecycleBinPage extends ConsumerStatefulWidget {
  const CustomersRecycleBinPage({super.key});

  @override
  ConsumerState<CustomersRecycleBinPage> createState() =>
      _CustomersRecycleBinPageState();
}

class _CustomersRecycleBinPageState extends ConsumerState<CustomersRecycleBinPage> {
  final _searchController = TextEditingController();
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();

  List<TrashedCustomer> _trashedCustomers = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _pageSize = 25;
  int _total = 0;
  int _totalPages = 1;

  final Set<String> _selectedIds = {};
  bool _isActionProcessing = false;

  bool get _canRestore {
    final user = ref.read(authProvider).user;
    return user?.isAdmin == true ||
        user?.hasPermission('CUSTOMERS', 'RESTORE') == true ||
        user?.hasPermission('CRM', 'RESTORE') == true ||
        user?.canDelete('CUSTOMERS') == true ||
        user?.canEdit('CUSTOMERS') == true;
  }

  bool get _canPermanentDelete {
    final user = ref.read(authProvider).user;
    return user?.isAdmin == true ||
        user?.hasPermission('CUSTOMERS', 'DELETE_PERMANENT') == true ||
        user?.hasPermission('CRM', 'DELETE_PERMANENT') == true;
  }

  @override
  void initState() {
    super.initState();
    _loadTrash(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableVerticalController.dispose();
    _tableHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadTrash({int? page, int? pageSize}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final targetPage = page ?? _page;
      final targetLimit = pageSize ?? _pageSize;

      final result = await ref.read(customersRepositoryProvider).getTrash(
            search: _searchController.text.trim(),
            page: targetPage,
            limit: targetLimit,
          );

      dynamic rawData = result['data'];
      List items = [];
      Map<String, dynamic> meta = {};

      if (rawData is Map) {
        if (rawData['data'] is List) {
          items = rawData['data'] as List;
        }
        if (rawData['meta'] is Map) {
          meta = Map<String, dynamic>.from(rawData['meta'] as Map);
        }
      } else if (rawData is List) {
        items = rawData;
        if (result['meta'] is Map) {
          meta = Map<String, dynamic>.from(result['meta'] as Map);
        }
      } else if (result['items'] is List) {
        items = result['items'] as List;
      }

      final dataList = items
          .whereType<Map>()
          .map((m) => TrashedCustomer.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      if (mounted) {
        setState(() {
          _trashedCustomers = dataList;
          _page = meta['page'] is int ? meta['page'] as int : targetPage;
          _pageSize = meta['limit'] is int ? meta['limit'] as int : targetLimit;
          _total = meta['total'] is int ? meta['total'] as int : _trashedCustomers.length;
          _totalPages = meta['totalPages'] is int
              ? meta['totalPages'] as int
              : (_total / _pageSize).ceil().clamp(1, 9999);
          _isLoading = false;
          // Retain only selected IDs that still exist
          _selectedIds.removeWhere((id) => !_trashedCustomers.any((c) => c.id == id));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreCustomer(TrashedCustomer customer) async {
    if (_isActionProcessing) return;
    setState(() => _isActionProcessing = true);

    try {
      final res = await ref.read(customersRepositoryProvider).restoreCustomer(customer.id);
      final msg = res['message'] ?? 'Customer restored successfully';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $msg'),
            backgroundColor: AppTheme.success,
          ),
        );
        _selectedIds.remove(customer.id);
        _loadTrash(page: _page);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  Future<void> _bulkRestore() async {
    if (_selectedIds.isEmpty || _isActionProcessing) return;

    final selectedCustomers =
        _trashedCustomers.where((c) => _selectedIds.contains(c.id)).toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.darkBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.restore_from_trash, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text('Restore ${_selectedIds.length} Customer(s)?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following customer(s) will be returned to the active Customer Directory:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: selectedCustomers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppTheme.darkBorder, height: 1),
                  itemBuilder: (_, i) {
                    final c = selectedCustomers[i];
                    return ListTile(
                      dense: true,
                      title: Text(c.companyName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${c.customerCode} · Contact: ${c.contactPerson}',
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.restore, size: 16),
            label: Text('Restore (${_selectedIds.length})'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionProcessing = true);
    try {
      final res = await ref
          .read(customersRepositoryProvider)
          .bulkRestore(_selectedIds.toList());
      final payload = res['data'] is Map ? res['data'] as Map : res;
      final count = payload['count'] ?? payload['restoredCount'] ?? _selectedIds.length;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Successfully restored $count customer(s)'),
            backgroundColor: AppTheme.success,
          ),
        );
        _selectedIds.clear();
        _loadTrash(page: _page);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to bulk restore: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  Future<void> _permanentDeleteCustomer(TrashedCustomer customer) async {
    if (customer.hasStatutoryRecords) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.darkBorder),
          ),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text('Retention Protected',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            customer.statutoryReason ??
                'This customer cannot be permanently deleted because they have financial, order, or statutory records that must be retained.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Permanent Deletion',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete "${customer.companyName}" (${customer.customerCode}) from the database?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WARNING: This action is completely IRREVERSIBLE. The customer and all non-statutory associations will be erased from the database.',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionProcessing = true);
    try {
      final res = await ref
          .read(customersRepositoryProvider)
          .permanentDeleteCustomer(customer.id);
      final msg = res['message'] ?? 'Customer permanently deleted';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $msg'),
            backgroundColor: AppTheme.success,
          ),
        );
        _selectedIds.remove(customer.id);
        _loadTrash(page: _page);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete permanently: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  Future<void> _bulkPermanentDelete() async {
    if (_selectedIds.isEmpty || _isActionProcessing) return;

    final selectedCustomers =
        _trashedCustomers.where((c) => _selectedIds.contains(c.id)).toList();

    final protectedCount =
        selectedCustomers.where((c) => c.hasStatutoryRecords).length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text('Permanently Delete ${_selectedIds.length} Customer(s)?',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'IRREVERSIBLE OPERATION: Selected customers without statutory records will be permanently removed from the database.',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              if (protectedCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$protectedCount of the selected customer(s) have statutory commercial records and will be protected from deletion.',
                          style: const TextStyle(
                              color: Colors.amber, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Selected for permanent deletion:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: selectedCustomers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppTheme.darkBorder, height: 1),
                  itemBuilder: (_, i) {
                    final c = selectedCustomers[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        c.hasStatutoryRecords ? Icons.shield : Icons.delete_outline,
                        color: c.hasStatutoryRecords ? Colors.amber : Colors.redAccent,
                        size: 18,
                      ),
                      title: Text(c.companyName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        c.hasStatutoryRecords
                            ? 'Protected: ${c.statutoryReason}'
                            : '${c.customerCode} · Ready for permanent removal',
                        style: TextStyle(
                            fontSize: 10,
                            color: c.hasStatutoryRecords ? Colors.amber : Colors.grey),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: Text('Permanently Delete (${_selectedIds.length})'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionProcessing = true);
    try {
      final res = await ref
          .read(customersRepositoryProvider)
          .bulkPermanentDelete(_selectedIds.toList());
      final payload = res['data'] is Map ? res['data'] as Map : res;
      final deletedCount = payload['deletedCount'] ?? 0;
      final skippedCount = payload['skippedCount'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ Deleted $deletedCount customer(s)${skippedCount > 0 ? ' ($skippedCount skipped due to retention)' : ''}'),
            backgroundColor: AppTheme.success,
          ),
        );
        _selectedIds.clear();
        _loadTrash(page: _page);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to permanently delete: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  Future<void> _emptyRecycleBin() async {
    if (_isActionProcessing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Text('EMPTY RECYCLE BIN',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to completely empty the Recycle Bin? There are currently $_total customer record(s) in the trash.',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERMANENT & IRREVERSIBLE ACTION',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• All trashed customers eligible for deletion will be erased from the database.\n'
                      '• Customers with commercial or statutory retention obligations will remain protected.\n'
                      '• Audit log history will be permanently preserved.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('YES, EMPTY RECYCLE BIN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionProcessing = true);
    try {
      final res = await ref.read(customersRepositoryProvider).emptyRecycleBin();
      final payload = res['data'] is Map ? res['data'] as Map : res;
      final deletedCount = payload['deletedCount'] ?? 0;
      final skippedCount = payload['skippedCount'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ Emptied Recycle Bin: $deletedCount deleted${skippedCount > 0 ? ', $skippedCount preserved for retention' : ''}'),
            backgroundColor: AppTheme.success,
          ),
        );
        _selectedIds.clear();
        _loadTrash(page: 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to empty recycle bin: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customers');
            }
          },
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Recycle Bin'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_total deleted',
                style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          if (_canPermanentDelete && _total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: _isActionProcessing ? null : _emptyRecycleBin,
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('Empty Recycle Bin'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadTrash(page: _page),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_selectedIds.isNotEmpty) _buildBulkActionBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _trashedCustomers.isEmpty
                        ? _buildEmptyView()
                        : _buildTable(isWide),
          ),
          if (!_isLoading && _error == null && _trashedCustomers.isNotEmpty)
            _buildPagination(isWide),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadTrash(page: 1),
              decoration: InputDecoration(
                hintText: 'Search deleted customers by name, code, phone, or email…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _loadTrash(page: 1);
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.darkBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _loadTrash(page: 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Search'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/customers'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Active Directory'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            '${_selectedIds.length} customer(s) selected',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          if (_canRestore) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _isActionProcessing ? null : _bulkRestore,
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restore Selected'),
            ),
            const SizedBox(width: 8),
          ],
          if (_canPermanentDelete) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _isActionProcessing ? null : _bulkPermanentDelete,
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const Text('Delete Permanently'),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton(
            onPressed: () => setState(() => _selectedIds.clear()),
            child: const Text('Clear Selection'),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
            scrollbars: false,
          ),
          child: Scrollbar(
            controller: _tableVerticalController,
            thumbVisibility: true,
            interactive: true,
            thickness: 10,
            radius: const Radius.circular(5),
            child: Scrollbar(
              controller: _tableHorizontalController,
              thumbVisibility: true,
              interactive: true,
              thickness: 10,
              radius: const Radius.circular(5),
              notificationPredicate: (notif) => notif.depth == 1,
              child: SingleChildScrollView(
                controller: _tableVerticalController,
                scrollDirection: Axis.vertical,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: SingleChildScrollView(
                  controller: _tableHorizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth - 24 > 1050
                          ? constraints.maxWidth - 24
                          : 1050,
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: DataTable(
                        columnSpacing: 18,
                        headingRowColor:
                            WidgetStateProperty.all(AppTheme.darkBackground),
                        onSelectAll: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.addAll(_trashedCustomers.map((c) => c.id));
                            } else {
                              _selectedIds.clear();
                            }
                          });
                        },
                        columns: const [
                          DataColumn(
                              label: Text('#',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Customer ID',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Company Name',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Contact Person',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Location',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Deleted Date',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Deleted By',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Retention Status',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Actions',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                        rows: _trashedCustomers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final c = entry.value;
                          final rowNum = (_page - 1) * _pageSize + index + 1;
                          final isSelected = _selectedIds.contains(c.id);
                          final deletedDateFormatted = c.deletedAt != null
                              ? DateFormat('dd MMM yyyy, hh:mm a').format(c.deletedAt!)
                              : 'Unknown';

                          return DataRow(
                            selected: isSelected,
                            onSelectChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedIds.add(c.id);
                                } else {
                                  _selectedIds.remove(c.id);
                                }
                              });
                            },
                            cells: [
                              DataCell(Text('$rowNum',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey))),
                              DataCell(Text(c.customerCode,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary))),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        Colors.orangeAccent.withValues(alpha: 0.2),
                                    child: Text(c.initials,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.orangeAccent,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.companyName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                        Text(c.customerType.replaceAll('_', ' '),
                                            style: const TextStyle(
                                                fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              )),
                              DataCell(Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.contactPerson,
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w500)),
                                  if (c.phone.isNotEmpty)
                                    Text(c.phone,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                ],
                              )),
                              DataCell(Text(
                                '${c.city.isNotEmpty ? c.city : '—'}, ${c.state.isNotEmpty ? c.state : '—'}',
                                style: const TextStyle(fontSize: 11),
                              )),
                              DataCell(Text(deletedDateFormatted,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white70))),
                              DataCell(Text(c.deletedBy ?? 'System',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.orangeAccent))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.hasStatutoryRecords
                                      ? Colors.amber.withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: c.hasStatutoryRecords
                                        ? Colors.amber.withValues(alpha: 0.4)
                                        : Colors.redAccent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      c.hasStatutoryRecords
                                          ? Icons.shield_outlined
                                          : Icons.delete_outline,
                                      size: 12,
                                      color: c.hasStatutoryRecords
                                          ? Colors.amber
                                          : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.hasStatutoryRecords
                                          ? 'Protected (Statutory)'
                                          : 'Eligible for Deletion',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: c.hasStatutoryRecords
                                            ? Colors.amber
                                            : Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_canRestore)
                                    IconButton(
                                      icon: const Icon(Icons.restore,
                                          size: 16, color: AppTheme.primary),
                                      onPressed: _isActionProcessing
                                          ? null
                                          : () => _restoreCustomer(c),
                                      tooltip: 'Restore Customer',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (_canPermanentDelete)
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_forever,
                                        size: 16,
                                        color: c.hasStatutoryRecords
                                            ? Colors.grey
                                            : Colors.redAccent,
                                      ),
                                      onPressed: _isActionProcessing
                                          ? null
                                          : () => _permanentDeleteCustomer(c),
                                      tooltip: c.hasStatutoryRecords
                                          ? 'Retention protected: ${c.statutoryReason}'
                                          : 'Delete Permanently',
                                      visualDensity: VisualDensity.compact,
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
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Recycle Bin is Empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Deleted customers will appear here for recovery or permanent database deletion.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.go('/customers'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Go to Customer Directory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
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
          Text('Failed to load Recycle Bin: $_error',
              style: const TextStyle(fontSize: 14, color: Colors.redAccent)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _loadTrash(page: _page),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(bool isWide) {
    final startItem = _total == 0 ? 0 : (_page - 1) * _pageSize + 1;
    final endItem = (_page * _pageSize) > _total ? _total : (_page * _pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          Text(
            'Showing $startItem–$endItem of $_total deleted customers',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Spacer(),
          Text('Page $_page of $_totalPages',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _page > 1 ? () => _loadTrash(page: _page - 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _page < _totalPages ? () => _loadTrash(page: _page + 1) : null,
          ),
        ],
      ),
    );
  }
}
