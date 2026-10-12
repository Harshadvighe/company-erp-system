import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/inventory/data/inventory_repository.dart';

class InventoryDashboardPage extends ConsumerStatefulWidget {
  const InventoryDashboardPage({super.key});

  @override
  ConsumerState<InventoryDashboardPage> createState() => _InventoryDashboardPageState();
}

class _InventoryDashboardPageState extends ConsumerState<InventoryDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<dynamic> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final summaryRes = await repo.getSummary();
      final whList = await repo.getWarehouses();

      setState(() {
        _summary = summaryRes['data'] ?? summaryRes;
        _warehouses = whList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 22, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Inventory & Stores Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Inventory',
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
            tooltip: 'Stock Actions',
            onSelected: (val) {
              if (val == 'ADJUST') {
                _showAdjustStockDialog();
              } else if (val == 'TRANSFER') {
                _showTransferStockDialog();
              } else if (val == 'WAREHOUSE') {
                _showCreateWarehouseDialog();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'ADJUST',
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Stock Adjustment'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'TRANSFER',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Inter-Store Transfer'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'WAREHOUSE',
                child: Row(
                  children: [
                    Icon(Icons.warehouse_outlined, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Add Warehouse / Bay'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                      const SizedBox(height: 12),
                      Text('Error loading inventory: $_error', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(currencyFormat),
    );
  }

  Widget _buildContent(NumberFormat currencyFormat) {
    final totalValuation = (_summary?['totalValuation'] as num?)?.toDouble() ?? 0.0;
    final totalProducts = _summary?['totalProducts'] ?? 0;
    final totalStockUnits = _summary?['totalStockUnits'] ?? 0;
    final lowStockCount = _summary?['lowStockCount'] ?? 0;
    final totalWarehouses = _summary?['totalWarehouses'] ?? _warehouses.length;

    return Column(
      children: [
        // ─── 4 Hero KPI Cards ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 2.2 : 1.6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard(
                    title: 'Total Stock Valuation',
                    value: currencyFormat.format(totalValuation),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppTheme.primaryColor,
                    subtitle: 'Asset Valuation at Cost',
                  ),
                  _buildKpiCard(
                    title: 'Active SKUs',
                    value: '$totalProducts SKUs',
                    icon: Icons.category_outlined,
                    color: Colors.blueAccent,
                    subtitle: '$totalStockUnits Physical Units',
                  ),
                  _buildKpiCard(
                    title: 'Low Stock Alerts',
                    value: '$lowStockCount Items',
                    icon: Icons.warning_amber_rounded,
                    color: lowStockCount > 0 ? Colors.redAccent : Colors.green,
                    subtitle: lowStockCount > 0 ? 'Below Reorder Threshold' : 'Stock Levels Healthy',
                  ),
                  _buildKpiCard(
                    title: 'Store Locations',
                    value: '$totalWarehouses Bays',
                    icon: Icons.warehouse_outlined,
                    color: Colors.purpleAccent,
                    subtitle: 'Plants & Warehouse Bays',
                  ),
                ],
              );
            },
          ),
        ),

        // ─── 4 Tabs Navigation ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Stock Items'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_outlined, size: 16, color: lowStockCount > 0 ? Colors.redAccent : null),
                      const SizedBox(width: 6),
                      Text('Reorder Alerts ($lowStockCount)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warehouse_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Warehouses (${_warehouses.length})'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Movement Ledger'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Tab Content Views ────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _StockItemsTab(
                warehouses: _warehouses,
                currencyFormat: currencyFormat,
                onStockAdjust: _showAdjustStockDialog,
              ),
              _LowStockTab(
                lowStockItems: _summary?['lowStockItems'] as List<dynamic>? ?? [],
                currencyFormat: currencyFormat,
                onReorder: (item) => _showAdjustStockDialog(prefillProduct: item),
              ),
              _WarehousesTab(
                warehouses: _warehouses,
                currencyFormat: currencyFormat,
                onAddWarehouse: _showCreateWarehouseDialog,
              ),
              _LedgerTab(
                currencyFormat: currencyFormat,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

  void _showAdjustStockDialog({dynamic prefillProduct}) {
    showDialog(
      context: context,
      builder: (_) => _AdjustStockDialog(
        warehouses: _warehouses,
        prefillProduct: prefillProduct,
        onSuccess: _loadData,
      ),
    );
  }

  void _showTransferStockDialog() {
    showDialog(
      context: context,
      builder: (_) => _TransferStockDialog(
        warehouses: _warehouses,
        onSuccess: _loadData,
      ),
    );
  }

  void _showCreateWarehouseDialog() {
    showDialog(
      context: context,
      builder: (_) => _CreateWarehouseDialog(
        onSuccess: _loadData,
      ),
    );
  }
}

// ─── Tab 1: Stock Items & Valuation ──────────────────────────────────────────

class _StockItemsTab extends ConsumerStatefulWidget {
  final List<dynamic> warehouses;
  final NumberFormat currencyFormat;
  final Function({dynamic prefillProduct}) onStockAdjust;

  const _StockItemsTab({
    required this.warehouses,
    required this.currencyFormat,
    required this.onStockAdjust,
  });

  @override
  ConsumerState<_StockItemsTab> createState() => _StockItemsTabState();
}

class _StockItemsTabState extends ConsumerState<_StockItemsTab> {
  final _searchController = TextEditingController();
  String? _selectedWarehouseId;
  bool _lowStockOnly = false;
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final res = await repo.getStockItems(
        warehouseId: _selectedWarehouseId,
        lowStockOnly: _lowStockOnly,
        search: _searchController.text.trim(),
      );
      setState(() {
        _items = res['items'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search SKU, component name, HSN...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _loadItems();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              const SizedBox(width: 12),
              // Warehouse filter dropdown
              DropdownButton<String?>(
                value: _selectedWarehouseId,
                hint: const Text('All Locations', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Locations', style: TextStyle(fontSize: 13))),
                  ...widget.warehouses.map((wh) => DropdownMenuItem(
                        value: wh['id'] as String,
                        child: Text('${wh['code']} - ${wh['name']}', style: const TextStyle(fontSize: 13)),
                      )),
                ],
                onChanged: (val) {
                  setState(() => _selectedWarehouseId = val);
                  _loadItems();
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Low Stock', style: TextStyle(fontSize: 12)),
                selected: _lowStockOnly,
                selectedColor: Colors.redAccent.withValues(alpha: 0.2),
                checkmarkColor: Colors.redAccent,
                onSelected: (val) {
                  setState(() => _lowStockOnly = val);
                  _loadItems();
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('No stock items match your criteria', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final isLow = item['isLowStock'] == true;
                        final current = item['currentStock'] ?? 0;
                        final reserved = item['reservedStock'] ?? 0;
                        final available = item['availableStock'] ?? 0;
                        final valuation = (item['valuation'] as num?)?.toDouble() ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isLow ? Colors.redAccent.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: Icon(
                                isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                                color: isLow ? Colors.redAccent : AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name'] ?? 'Product',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['sku'] ?? '',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Category: ${item['category']} • Unit Cost: ${widget.currencyFormat.format(item['purchasePrice'] ?? 0)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text('In Stock: $current ${item['unit']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Text('• Reserved: $reserved', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    Text('• Available: $available', style: TextStyle(fontSize: 11, color: available > 0 ? Colors.green : Colors.red)),
                                    if (isLow) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('LOW STOCK', style: TextStyle(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(widget.currencyFormat.format(valuation), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                OutlinedButton(
                                  onPressed: () => widget.onStockAdjust(prefillProduct: item),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Adjust', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─── Tab 2: Low Stock & Reorder Alerts ───────────────────────────────────────

class _LowStockTab extends StatelessWidget {
  final List<dynamic> lowStockItems;
  final NumberFormat currencyFormat;
  final Function(dynamic item) onReorder;

  const _LowStockTab({
    required this.lowStockItems,
    required this.currencyFormat,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (lowStockItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
              SizedBox(height: 12),
              Text('Healthy Inventory Levels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('All components and panels are above reorder thresholds.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lowStockItems.length,
      itemBuilder: (context, index) {
        final item = lowStockItems[index];
        final current = item['currentStock'] ?? 0;
        final reorder = item['reorderLevel'] ?? 0;
        final deficit = item['deficit'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            ),
            title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('SKU: ${item['sku']} • Category: ${item['category']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  'Current Stock: $current ${item['unit']} (Reorder Level: $reorder ${item['unit']}) • Deficit: -$deficit',
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            trailing: ElevatedButton.icon(
              onPressed: () => onReorder(item),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Adjust / Replenish', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Tab 3: Warehouses & Store Bays ──────────────────────────────────────────

class _WarehousesTab extends StatelessWidget {
  final List<dynamic> warehouses;
  final NumberFormat currencyFormat;
  final VoidCallback onAddWarehouse;

  const _WarehousesTab({
    required this.warehouses,
    required this.currencyFormat,
    required this.onAddWarehouse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Storage Facilities (${warehouses.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ElevatedButton.icon(
                onPressed: onAddWarehouse,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: warehouses.isEmpty
              ? const Center(child: Text('No storage locations registered', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: warehouses.length,
                  itemBuilder: (context, index) {
                    final wh = warehouses[index];
                    final valuation = (wh['totalValuation'] as num?)?.toDouble() ?? 0;
                    final totalUnits = wh['totalUnits'] ?? 0;
                    final uniqueSkus = wh['uniqueSkus'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.withValues(alpha: 0.15),
                          child: const Icon(Icons.warehouse_outlined, color: Colors.purple, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(wh['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(wh['code'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Location: ${wh['location']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text('SKUs: $uniqueSkus • Stored Units: $totalUnits', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(currencyFormat.format(valuation), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            const Text('Bay Valuation', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Tab 4: Stock Movement Ledger ────────────────────────────────────────────

class _LedgerTab extends ConsumerStatefulWidget {
  final NumberFormat currencyFormat;
  const _LedgerTab({required this.currencyFormat});

  @override
  ConsumerState<_LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends ConsumerState<_LedgerTab> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final res = await repo.getTransactions(limit: 50);
      setState(() {
        _transactions = res['transactions'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_transactions.isEmpty) {
      return const Center(child: Text('No stock movement transactions logged yet.', style: TextStyle(color: Colors.grey)));
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final type = tx['transactionType'] as String? ?? 'STOCK_IN';
        final qty = (tx['quantity'] as num?)?.toDouble() ?? 0;
        final date = tx['transactionDate'] != null ? dateFormat.format(DateTime.parse(tx['transactionDate'])) : '-';
        final productName = tx['product']?['name'] ?? 'Product';
        final sku = tx['product']?['sku'] ?? '';
        final whName = tx['warehouse']?['name'] ?? 'Warehouse';
        final isPositive = qty > 0;

        Color badgeColor = Colors.grey;
        if (type == 'STOCK_IN' || type == 'INWARD_GRN' || type == 'TRANSFER_IN') {
          badgeColor = Colors.green;
        } else if (type == 'STOCK_OUT' || type == 'PURCHASE_RETURN' || type == 'TRANSFER_OUT') {
          badgeColor = Colors.redAccent;
        } else if (type == 'ADJUSTMENT') {
          badgeColor = Colors.orange;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.15),
              child: Icon(
                isPositive ? Icons.call_received : Icons.call_made,
                color: badgeColor,
                size: 18,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(type, style: TextStyle(fontSize: 9, color: badgeColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text('SKU: $sku • Location: $whName • $date', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (tx['notes'] != null && tx['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Notes: ${tx['notes']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
            trailing: Text(
              '${isPositive ? '+' : ''}$qty ${tx['unit'] ?? ''}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: badgeColor),
            ),
          ),
        );
      },
    );
  }
}

// ─── Modal 1: Adjust Stock ───────────────────────────────────────────────────

class _AdjustStockDialog extends ConsumerStatefulWidget {
  final List<dynamic> warehouses;
  final dynamic prefillProduct;
  final VoidCallback onSuccess;

  const _AdjustStockDialog({
    required this.warehouses,
    this.prefillProduct,
    required this.onSuccess,
  });

  @override
  ConsumerState<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<_AdjustStockDialog> {
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedProductId;
  String? _selectedWarehouseId;
  String _adjustmentType = 'INCREASE';
  bool _isSubmitting = false;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    if (widget.prefillProduct != null) {
      _selectedProductId = widget.prefillProduct['id'];
    }
    if (widget.warehouses.isNotEmpty) {
      _selectedWarehouseId = widget.warehouses[0]['id'];
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final res = await repo.getStockItems(limit: 100);
      setState(() {
        _products = res['items'] as List<dynamic>? ?? [];
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_selectedProductId == null || _selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select product and warehouse')));
      return;
    }
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.adjustStock({
        'productId': _selectedProductId,
        'warehouseId': _selectedWarehouseId,
        'quantity': qty,
        'adjustmentType': _adjustmentType,
        'reason': _reasonController.text.trim(),
        'notes': _notesController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock adjusted successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adjustment failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune, color: AppTheme.primaryColor, size: 20),
          SizedBox(width: 8),
          Text('Manual Stock Adjustment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Selector
            const Text('Product / Component', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _selectedProductId,
              isExpanded: true,
              hint: const Text('Select Product'),
              items: _products.map((p) => DropdownMenuItem<String>(
                value: p['id'] as String,
                child: Text('${p['sku']} - ${p['name']}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) => setState(() => _selectedProductId = val),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            // Warehouse Selector
            const Text('Warehouse / Bay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _selectedWarehouseId,
              isExpanded: true,
              hint: const Text('Select Location'),
              items: widget.warehouses.map((wh) => DropdownMenuItem<String>(
                value: wh['id'] as String,
                child: Text('${wh['code']} - ${wh['name']}', style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: (val) => setState(() => _selectedWarehouseId = val),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            // Adjustment Type
            const Text('Adjustment Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Add (+)', style: TextStyle(fontSize: 11)),
                    selected: _adjustmentType == 'INCREASE',
                    onSelected: (_) => setState(() => _adjustmentType = 'INCREASE'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Deduct (-)', style: TextStyle(fontSize: 11)),
                    selected: _adjustmentType == 'DECREASE',
                    onSelected: (_) => setState(() => _adjustmentType = 'DECREASE'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Set Count (=)', style: TextStyle(fontSize: 11)),
                    selected: _adjustmentType == 'CORRECTION',
                    onSelected: (_) => setState(() => _adjustmentType = 'CORRECTION'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quantity
            const Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 5',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            // Reason
            const Text('Reason / Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Physical stock count / Damaged / Testing',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            const Text('Audit Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Optional audit explanation...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Apply Adjustment'),
        ),
      ],
    );
  }
}

// ─── Modal 2: Inter-Store Transfer ───────────────────────────────────────────

class _TransferStockDialog extends ConsumerStatefulWidget {
  final List<dynamic> warehouses;
  final VoidCallback onSuccess;

  const _TransferStockDialog({required this.warehouses, required this.onSuccess});

  @override
  ConsumerState<_TransferStockDialog> createState() => _TransferStockDialogState();
}

class _TransferStockDialogState extends ConsumerState<_TransferStockDialog> {
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedProductId;
  String? _fromWarehouseId;
  String? _toWarehouseId;
  bool _isSubmitting = false;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    if (widget.warehouses.length >= 2) {
      _fromWarehouseId = widget.warehouses[0]['id'];
      _toWarehouseId = widget.warehouses[1]['id'];
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final res = await repo.getStockItems(limit: 100);
      setState(() {
        _products = res['items'] as List<dynamic>? ?? [];
        if (_products.isNotEmpty) _selectedProductId = _products[0]['id'];
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_fromWarehouseId == null || _toWarehouseId == null || _selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select product, from and to locations')));
      return;
    }
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.transferStock({
        'productId': _selectedProductId,
        'fromWarehouseId': _fromWarehouseId,
        'toWarehouseId': _toWarehouseId,
        'quantity': qty,
        'notes': _notesController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inter-store transfer completed')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.blueAccent, size: 20),
          SizedBox(width: 8),
          Text('Inter-Store Stock Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product to Transfer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _selectedProductId,
              isExpanded: true,
              items: _products.map((p) => DropdownMenuItem<String>(
                value: p['id'] as String,
                child: Text('${p['sku']} - ${p['name']}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) => setState(() => _selectedProductId = val),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            const Text('From Store Location (Source)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _fromWarehouseId,
              isExpanded: true,
              items: widget.warehouses.map((wh) => DropdownMenuItem<String>(
                value: wh['id'] as String,
                child: Text('${wh['code']} - ${wh['name']}', style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: (val) => setState(() => _fromWarehouseId = val),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            const Text('To Store Location (Destination)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _toWarehouseId,
              isExpanded: true,
              items: widget.warehouses.map((wh) => DropdownMenuItem<String>(
                value: wh['id'] as String,
                child: Text('${wh['code']} - ${wh['name']}', style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: (val) => setState(() => _toWarehouseId = val),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            const Text('Transfer Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 10',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            const Text('Transfer Notes / Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'e.g. Transferred for Shopfloor Assembly Bay 4',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Execute Transfer'),
        ),
      ],
    );
  }
}

// ─── Modal 3: Add Warehouse / Store Location ─────────────────────────────────

class _CreateWarehouseDialog extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _CreateWarehouseDialog({required this.onSuccess});

  @override
  ConsumerState<_CreateWarehouseDialog> createState() => _CreateWarehouseDialogState();
}

class _CreateWarehouseDialogState extends ConsumerState<_CreateWarehouseDialog> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();

    if (code.isEmpty || name.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.createWarehouse({
        'code': code,
        'name': name,
        'location': location,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store location created successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Creation failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warehouse_outlined, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text('New Warehouse / Store Bay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: 'e.g. WH-RAW-01, BAY-ASSEMBLY-4',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            const Text('Store Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Raw Material Store & Sheet Metal Bay',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),

            const Text('Physical Location / Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'e.g. Plant Floor 1, North Wing MIDC Phase II',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Location'),
        ),
      ],
    );
  }
}
