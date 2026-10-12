import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

class SalesOrdersListPage extends ConsumerStatefulWidget {
  const SalesOrdersListPage({super.key});

  @override
  ConsumerState<SalesOrdersListPage> createState() => _SalesOrdersListPageState();
}

class _SalesOrdersListPageState extends ConsumerState<SalesOrdersListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  final _statusFilters = ['ALL', 'CONFIRMED', 'IN_PRODUCTION', 'READY_FOR_DISPATCH', 'DISPATCHED', 'DELIVERED'];

  List<dynamic> _orders = [];
  bool _isLoading = false;
  String? _error;
  int _totalCount = 0;
  double _totalValue = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadOrders();
      }
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final selectedStatus = _statusFilters[_tabController.index];
      final repo = ref.read(salesRepositoryProvider);
      final res = await repo.getSalesOrders(
        status: selectedStatus == 'ALL' ? null : selectedStatus,
        search: _searchController.text.trim(),
      );

      final items = res['items'] as List<dynamic>? ?? [];
      double sum = 0;
      for (final itm in items) {
        sum += (itm['grandTotal'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _orders = items;
        _totalCount = (res['total'] as num?)?.toInt() ?? items.length;
        _totalValue = sum;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Color _getOrderStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'DELIVERED':
        return Colors.green;
      case 'DISPATCHED':
        return Colors.teal;
      case 'READY_FOR_DISPATCH':
        return Colors.blue;
      case 'IN_PRODUCTION':
        return Colors.amber.shade800;
      case 'CONFIRMED':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/crm/dashboard');
            }
          },
        ),
        title: const Text('Sales Orders & Production Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: _statusFilters.map((s) => Tab(text: s.replaceAll('_', ' '))).toList(),
        ),
      ),
      body: Column(
        children: [
          // ─── Header Metrics & Search ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.darkSurface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Active Sales Orders', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                            const SizedBox(height: 4),
                            Text('$_totalCount Orders', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Confirmed Order Value', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                            const SizedBox(height: 4),
                            Text(currencyFormatter.format(_totalValue), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.success)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Order #, Customer PO #, Company Name...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.darkTextSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.darkTextSecondary),
                            onPressed: () {
                              _searchController.clear();
                              _loadOrders();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.darkCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                  ),
                  onSubmitted: (_) => _loadOrders(),
                ),
              ],
            ),
          ),

          // ─── Orders List ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text('No Sales Orders Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Accepted commercial quotations convert into sales orders automatically.', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                final customer = order['customer'] as Map<String, dynamic>?;
                                final quote = order['quotation'] as Map<String, dynamic>?;
                                final status = order['status'] as String? ?? 'CONFIRMED';
                                final prodStatus = order['productionStatus'] as String? ?? 'PENDING';
                                final grandTotal = (order['grandTotal'] as num?)?.toDouble() ?? 0;
                                final orderDate = order['orderDate'] != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(order['orderDate']))
                                    : '-';

                                return Card(
                                  elevation: 1.5,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Order Number + Status
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    order['orderNumber'] ?? 'SO',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                                  ),
                                                ),
                                                if (order['poNumber'] != null) ...[
                                                  const SizedBox(width: 8),
                                                  Text('PO: ${order['poNumber']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                                                ],
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getOrderStatusColor(status).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: _getOrderStatusColor(status).withValues(alpha: 0.4)),
                                              ),
                                              child: Text(
                                                status.replaceAll('_', ' '),
                                                style: TextStyle(color: _getOrderStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Customer info
                                        Text(
                                          customer?['companyName'] ?? 'Customer',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        if (quote != null)
                                          Text(
                                            'From Quote: ${quote['code'] ?? quote['quotationNumber']}',
                                            style: TextStyle(fontSize: 12, color: Colors.indigo.shade700),
                                          ),
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 12),

                                        // Bottom Row: Date & Grand Total & Manufacturing status
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.factory_outlined, size: 14, color: Colors.orange.shade800),
                                                const SizedBox(width: 4),
                                                Text('Shopfloor: $prodStatus', style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                            Text(
                                              currencyFormatter.format(grandTotal),
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

