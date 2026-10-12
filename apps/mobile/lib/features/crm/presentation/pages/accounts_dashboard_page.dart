import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

class AccountsDashboardPage extends ConsumerStatefulWidget {
  const AccountsDashboardPage({super.key});

  @override
  ConsumerState<AccountsDashboardPage> createState() => _AccountsDashboardPageState();
}

class _AccountsDashboardPageState extends ConsumerState<AccountsDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(salesRepositoryProvider);
      final res = await repo.getAccountsSummary();
      setState(() {
        _summary = res;
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
            Icon(Icons.account_balance_outlined, size: 22, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Accounts & Receivables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Ledger',
            onPressed: _loadSummary,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/sales/invoices'),
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('All Invoices'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
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
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                      const SizedBox(height: 12),
                      Text('Error loading accounts: $_error', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadSummary, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(currencyFormat),
    );
  }

  Widget _buildContent(NumberFormat currencyFormat) {
    final totalInvoiced = (_summary?['totalInvoiced'] as num?)?.toDouble() ?? 0.0;
    final totalCollected = (_summary?['totalCollected'] as num?)?.toDouble() ?? 0.0;
    final totalOutstanding = (_summary?['totalOutstanding'] as num?)?.toDouble() ?? 0.0;
    final overdueAmount = (_summary?['overdueAmount'] as num?)?.toDouble() ?? 0.0;
    final statusCounts = _summary?['statusCounts'] as Map<String, dynamic>? ?? {};
    final recentPayments = _summary?['recentPayments'] as List<dynamic>? ?? [];
    final customerBalances = _summary?['customerBalances'] as List<dynamic>? ?? [];

    final recoveryRate = totalInvoiced > 0 ? (totalCollected / totalInvoiced) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 4 Hero KPI Cards ─────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 2.0 : 1.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard(
                    title: 'Total Invoiced',
                    amount: currencyFormat.format(totalInvoiced),
                    icon: Icons.receipt_long,
                    color: AppTheme.primaryColor,
                    subtitle: '${_summary?['totalInvoicesCount'] ?? 0} Invoices generated',
                  ),
                  _buildKpiCard(
                    title: 'Realized Collections',
                    amount: currencyFormat.format(totalCollected),
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    subtitle: '${recoveryRate.toStringAsFixed(1)}% Recovery Rate',
                  ),
                  _buildKpiCard(
                    title: 'Outstanding Balance',
                    amount: currencyFormat.format(totalOutstanding),
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    subtitle: 'Pending Customer Dues',
                  ),
                  _buildKpiCard(
                    title: 'Overdue Dues',
                    amount: currencyFormat.format(overdueAmount),
                    icon: Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    subtitle: 'Beyond Payment Terms',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // ─── Recovery Rate & Status Breakdown Card ─────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Receivables Health & Aging',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${recoveryRate.toStringAsFixed(1)}% Recovered',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: recoveryRate > 70 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalInvoiced > 0 ? (totalCollected / totalInvoiced).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip('PAID', statusCounts['PAID'] ?? 0, Colors.green),
                      _buildStatusChip('PARTIALLY PAID', statusCounts['PARTIALLY_PAID'] ?? 0, Colors.orange),
                      _buildStatusChip('UNPAID', statusCounts['UNPAID'] ?? 0, Colors.blueGrey),
                      _buildStatusChip('OVERDUE', statusCounts['OVERDUE'] ?? 0, Colors.redAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Tabs: Customer Receivables Ledger vs Recent Receipts ────────
          Container(
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
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text('Customer Receivables Ledger (${customerBalances.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payment_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text('Recent Payment Receipts (${recentPayments.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 480,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomerBalancesList(customerBalances, currencyFormat),
                _buildRecentPaymentsList(recentPayments, currencyFormat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
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
            Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerBalancesList(List<dynamic> balances, NumberFormat currencyFormat) {
    if (balances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: const Center(
          child: Text('No customers with outstanding receivables! All dues cleared.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      itemCount: balances.length,
      itemBuilder: (context, index) {
        final item = balances[index];
        final companyName = item['companyName'] ?? 'Unknown Customer';
        final code = item['customerCode'] ?? '';
        final totalInvoiced = (item['totalInvoiced'] as num?)?.toDouble() ?? 0;
        final totalPaid = (item['totalPaid'] as num?)?.toDouble() ?? 0;
        final balanceDue = (item['balanceDue'] as num?)?.toDouble() ?? 0;
        final invoiceCount = item['invoicesCount'] ?? 0;
        final customerId = item['customerId'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: balanceDue > 0 ? Colors.orange.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
              child: Icon(
                balanceDue > 0 ? Icons.business : Icons.verified,
                color: balanceDue > 0 ? Colors.orange : Colors.green,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    companyName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (code.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(code, style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Text(
              'Invoices: $invoiceCount • Invoiced: ${currencyFormat.format(totalInvoiced)} • Paid: ${currencyFormat.format(totalPaid)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(balanceDue),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: balanceDue > 0 ? Colors.orange : Colors.green,
                      ),
                    ),
                    Text(
                      balanceDue > 0 ? 'Balance Due' : 'Settled',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: balanceDue > 0 ? Colors.orange : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  tooltip: 'View Customer 360',
                  onPressed: () {
                    if (customerId.isNotEmpty) {
                      context.push('/crm/companies/$customerId');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentPaymentsList(List<dynamic> payments, NumberFormat currencyFormat) {
    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: const Center(
          child: Text('No payment receipts recorded yet.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy');

    return ListView.builder(
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        final amount = (p['amount'] as num?)?.toDouble() ?? 0;
        final date = p['paymentDate'] != null ? dateFormat.format(DateTime.parse(p['paymentDate'])) : '-';
        final method = p['paymentMethod'] ?? 'NEFT';
        final refNo = p['referenceNumber'] ?? p['receiptNumber'] ?? '-';
        final customerName = p['customer']?['companyName'] ?? 'Customer';
        final invoiceNumber = p['invoice']?['invoiceNumber'] ?? 'Invoice';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.15),
              child: const Icon(Icons.call_received, color: Colors.green, size: 18),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(method, style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: Text('Inv #$invoiceNumber • Ref: $refNo • $date', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Text(
              currencyFormat.format(amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
            ),
          ),
        );
      },
    );
  }
}
