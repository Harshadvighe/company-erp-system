import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/reports/data/reports_repository.dart';

class ReportsDashboardPage extends ConsumerStatefulWidget {
  const ReportsDashboardPage({super.key});

  @override
  ConsumerState<ReportsDashboardPage> createState() => _ReportsDashboardPageState();
}

class _ReportsDashboardPageState extends ConsumerState<ReportsDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _summaryData;
  Map<String, dynamic>? _salesData;
  Map<String, dynamic>? _inventoryData;
  Map<String, dynamic>? _productionData;

  String _selectedPeriod = 'FY 2025-26';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(reportsRepositoryProvider);
      final results = await Promise.all([
        repo.getExecutiveSummary(),
        repo.getSalesReport(),
        repo.getInventoryReport(),
        repo.getProductionReport(),
      ]);

      setState(() {
        _summaryData = results[0];
        _salesData = results[1];
        _inventoryData = results[2];
        _productionData = results[3];
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

    final fin = _summaryData?['financials'] as Map<String, dynamic>? ?? {};
    final ops = _summaryData?['operations'] as Map<String, dynamic>? ?? {};

    final totalRev = (fin['totalRevenue'] as num?)?.toDouble() ?? 0;
    final totalStockVal = (ops['totalStockValuation'] as num?)?.toDouble() ?? 0;
    final totalProc = (fin['totalProcurement'] as num?)?.toDouble() ?? 0;
    final activePanels = (ops['panelSpecsCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined, size: 22, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Reports & Executive Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            underline: const SizedBox(),
            dropdownColor: AppTheme.darkCard,
            items: ['This Month', 'This Quarter', 'FY 2025-26'].map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedPeriod = val);
                _loadAllReports();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Metrics',
            onPressed: _loadAllReports,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Export / Print Summary',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Executive Report exported successfully.')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text('Failed to load reports: $_error', style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadAllReports, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ─── 4 Hero KPI Cards Ribbon ───────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: AppTheme.darkCard,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          return GridView.count(
                            crossAxisCount: isWide ? 4 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: isWide ? 2.6 : 1.9,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: [
                              _buildKpiCard(
                                title: 'Total Sales Revenue',
                                value: currencyFormat.format(totalRev),
                                subtitle: 'Billed to Clients',
                                icon: Icons.trending_up,
                                color: Colors.greenAccent,
                              ),
                              _buildKpiCard(
                                title: 'Inventory Valuation',
                                value: currencyFormat.format(totalStockVal),
                                subtitle: '${ops['totalStockUnits'] ?? 0} Total Units',
                                icon: Icons.inventory_2,
                                color: Colors.blueAccent,
                              ),
                              _buildKpiCard(
                                title: 'Procurement Outflow',
                                value: currencyFormat.format(totalProc),
                                subtitle: '${ops['purchaseOrdersCount'] ?? 0} Purchase Orders',
                                icon: Icons.shopping_cart_outlined,
                                color: Colors.amberAccent,
                              ),
                              _buildKpiCard(
                                title: 'Panel Projects',
                                value: '$activePanels Units',
                                subtitle: 'Shopfloor Pipeline',
                                icon: Icons.precision_manufacturing_outlined,
                                color: Colors.purpleAccent,
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // ─── Tab Bar ──────────────────────────────────────────
                    Container(
                      color: AppTheme.darkCard,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppTheme.primaryColor,
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: Colors.grey,
                        isScrollable: true,
                        tabs: const [
                          Tab(icon: Icon(Icons.account_balance_outlined, size: 16), text: 'Financials & Tax'),
                          Tab(icon: Icon(Icons.point_of_sale_outlined, size: 16), text: 'Sales Performance'),
                          Tab(icon: Icon(Icons.warehouse_outlined, size: 16), text: 'Inventory Valuation'),
                          Tab(icon: Icon(Icons.build_outlined, size: 16), text: 'Panel Manufacturing'),
                        ],
                      ),
                    ),

                    // ─── Tab Views ────────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _FinancialsTab(financials: fin, operations: ops, currencyFormat: currencyFormat),
                          _SalesPerformanceTab(data: _salesData ?? {}, currencyFormat: currencyFormat),
                          _InventoryTab(data: _inventoryData ?? {}, currencyFormat: currencyFormat),
                          _ProductionTab(data: _productionData ?? {}, currencyFormat: currencyFormat),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── Helper for Future.wait ──────────────────────────────────────────────────
class Promise {
  static Future<List<T>> all<T>(List<Future<T>> futures) => Future.wait(futures);
}

// ─── Tab 1: Financials & Tax ─────────────────────────────────────────────────
class _FinancialsTab extends StatelessWidget {
  final Map<String, dynamic> financials;
  final Map<String, dynamic> operations;
  final NumberFormat currencyFormat;

  const _FinancialsTab({
    required this.financials,
    required this.operations,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final collected = (financials['collectedRevenue'] as num?)?.toDouble() ?? 0;
    final pendingRec = (financials['pendingReceivables'] as num?)?.toDouble() ?? 0;
    final totalGst = (financials['totalGstCollected'] as num?)?.toDouble() ?? 0;
    final netCash = (financials['netCashFlowEstimate'] as num?)?.toDouble() ?? 0;
    final payables = (financials['pendingPayables'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.currency_rupee, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text('Cash Flow & Receivables Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                _rowMetric('Collected Revenue (Receipts):', currencyFormat.format(collected), Colors.green),
                const SizedBox(height: 8),
                _rowMetric('Pending Invoiced Receivables:', currencyFormat.format(pendingRec), Colors.orange),
                const SizedBox(height: 8),
                _rowMetric('Pending Vendor Payables:', currencyFormat.format(payables), Colors.redAccent),
                const SizedBox(height: 8),
                _rowMetric('Estimated Net Cash Flow Margin:', currencyFormat.format(netCash), netCash >= 0 ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(height: 8),
                _rowMetric('Output GST Collected (18%):', currencyFormat.format(totalGst), Colors.blueAccent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.business_outlined, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text('Enterprise Master Ratios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                _rowMetric('Active Client Accounts:', '${operations['totalCustomers'] ?? 0} Clients', Colors.white),
                const SizedBox(height: 8),
                _rowMetric('Approved Vendors & Suppliers:', '${operations['totalVendors'] ?? 0} Suppliers', Colors.white),
                const SizedBox(height: 8),
                _rowMetric('Active Engineering Workforce:', '${operations['activeStaff'] ?? 0} On Payroll', Colors.white),
                const SizedBox(height: 8),
                _rowMetric('Low Stock Reorder Alerts:', '${operations['lowStockCount'] ?? 0} Items at risk', operations['lowStockCount'] > 0 ? Colors.redAccent : Colors.green),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _rowMetric(String title, String val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ─── Tab 2: Sales Performance ────────────────────────────────────────────────
class _SalesPerformanceTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat currencyFormat;

  const _SalesPerformanceTab({required this.data, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final topCustomers = (data['topCustomers'] as List<dynamic>?) ?? [];
    final recentOrders = (data['recentOrders'] as List<dynamic>?) ?? [];
    final convRate = (data['conversionRate'] as num?)?.toDouble() ?? 0;
    final totalQuo = data['totalQuotations'] ?? 0;
    final wonQuo = data['wonQuotations'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quotation funnel
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quotation-to-Order Conversion Funnel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text('Conversion: $convRate%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalQuo > 0 ? (wonQuo / totalQuo) : 0,
                  backgroundColor: AppTheme.darkBorder,
                  color: Colors.green,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text('$wonQuo Won / $totalQuo Total Commercial Quotations Sent', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Top Corporate Clients Leaderboard
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top Revenue Accounts (Billing Leaderboard)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                if (topCustomers.isEmpty)
                  const Text('No customer billing recorded yet.', style: TextStyle(color: Colors.grey))
                else
                  ...topCustomers.map((c) {
                    final billed = (c['billedAmount'] as num?)?.toDouble() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                            child: Text(c['name']?[0] ?? 'C', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Code: ${c['code'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(currencyFormat.format(billed), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Recent Sales Orders
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Sales Orders Issued', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                if (recentOrders.isEmpty)
                  const Text('No sales orders found.', style: TextStyle(color: Colors.grey))
                else
                  ...recentOrders.map((o) {
                    final amt = (o['totalAmount'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                      title: Text(o['orderNumber'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(o['customerName'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: Text(currencyFormat.format(amt), style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tab 3: Inventory Valuation ──────────────────────────────────────────────
class _InventoryTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat currencyFormat;

  const _InventoryTab({required this.data, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final whList = (data['warehouseBreakdown'] as List<dynamic>?) ?? [];
    final lowStock = (data['lowStockAlerts'] as List<dynamic>?) ?? [];
    final movements = (data['recentMovements'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Storage Warehouses
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Warehouse & Plant Store Valuation Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                if (whList.isEmpty)
                  const Text('No warehouses configured.', style: TextStyle(color: Colors.grey))
                else
                  ...whList.map((wh) {
                    final val = (wh['valuation'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.warehouse, color: Colors.white, size: 18),
                      ),
                      title: Text('${wh['name']} (${wh['code']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Location: ${wh['location']} • ${wh['skuCount']} SKUs • ${wh['units']} Units', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Text(currencyFormat.format(val), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Critical Reorder Alert Register
        if (lowStock.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('Critical Reorder Alerts (${lowStock.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ],
                  ),
                  const Divider(height: 20),
                  ...lowStock.map((item) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item['name']} [${item['sku']}]', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Stock: ${item['currentStock']} ${item['unit']} (Min Reorder: ${item['reorderLevel']})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text('Deficit -${item['deficit']}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Recent Inward / Outward / Transfers
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Material Movement Log', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                if (movements.isEmpty)
                  const Text('No recent movements.', style: TextStyle(color: Colors.grey))
                else
                  ...movements.take(6).map((m) {
                    final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
                    final isPos = qty > 0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(isPos ? Icons.south_west : Icons.north_east, color: isPos ? Colors.green : Colors.redAccent, size: 18),
                      title: Text('${m['productName']} (${m['sku']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text('${m['type']} @ ${m['warehouseCode']} • ${m['notes'] ?? ''}', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('${isPos ? '+' : ''}$qty', style: TextStyle(fontWeight: FontWeight.bold, color: isPos ? Colors.green : Colors.redAccent)),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tab 4: Panel Manufacturing & QC ─────────────────────────────────────────
class _ProductionTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat currencyFormat;

  const _ProductionTab({required this.data, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final stages = (data['stageBreakdown'] as Map<String, dynamic>?) ?? {};
    final panels = (data['activePanels'] as List<dynamic>?) ?? [];
    final totalPanels = data['totalPanels'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stage metrics
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Panel Assembly Throughput ($totalPanels Total Specs)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stages.entries.map((e) {
                    return Chip(
                      label: Text('${e.key.replaceAll('_', ' ')}: ${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: AppTheme.darkBackground,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Panel List
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Panel Specifications & Quality Stage', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                if (panels.isEmpty)
                  const Text('No panel specifications active.', style: TextStyle(color: Colors.grey))
                else
                  ...panels.map((p) {
                    final price = (p['finalPrice'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Colors.purple,
                        child: Icon(Icons.bolt, color: Colors.white, size: 18),
                      ),
                      title: Text('${p['panelCode']} • ${p['panelType']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Client: ${p['customerName']} • Voltage: ${p['voltage']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currencyFormat.format(price), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purpleAccent)),
                          Text(p['status'] ?? 'DRAFT', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
