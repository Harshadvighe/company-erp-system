import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/cheque_management_modal.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/inward_entry_modal.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/outward_document_modal.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/pay_invoice_dialog.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/vendor_registration_modal.dart';

class PurchaseDashboardPage extends ConsumerStatefulWidget {
  const PurchaseDashboardPage({super.key});

  @override
  ConsumerState<PurchaseDashboardPage> createState() => _PurchaseDashboardPageState();
}

class _PurchaseDashboardPageState extends ConsumerState<PurchaseDashboardPage> {
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd MMM yyyy');

  String _selectedFinYear = '2026-27';
  String _selectedStatus = 'ALL';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDashboard();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshDashboard() {
    ref.read(purchaseDashboardProvider.notifier).loadDashboard(
          finYear: _selectedFinYear == 'ALL' ? null : _selectedFinYear,
          fromDate: _selectedDateRange?.start.toIso8601String(),
          toDate: _selectedDateRange?.end.toIso8601String(),
          status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        );
  }

  String _formatCurrency(num? value) {
    if (value == null) return '₹0.00';
    try {
      return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(value);
    } catch (_) {
      return '₹${value.toStringAsFixed(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseDashboardProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Page Header with Title & Top Quick Actions
          _buildTopHeader(isMobile),

          // 2. Dynamic Filters Bar
          _buildFilterBar(isMobile),

          // 3. Main Content Area
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : state.error != null
                    ? _buildErrorView(state.error!)
                    : RefreshIndicator(
                        onRefresh: () async => _refreshDashboard(),
                        color: AppTheme.primary,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SECTION 1: INWARD PURCHASE SUMMARY
                              _buildSectionTitle('INWARD PURCHASE SUMMARY'),
                              const SizedBox(height: 12),
                              _buildSummaryCards(state.summary ?? {}, isMobile),
                              const SizedBox(height: 28),

                              // SECTION 2: PENDING INVOICES
                              _buildPendingInvoicesSection(state.pendingInvoices, isMobile),
                              const SizedBox(height: 28),

                              // SECTION 3: INWARD ENTRY REGISTER
                              _buildInwardRegisterSection(state.recentInwards, isMobile),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: _refreshDashboard,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ─── Header & Top Quick Actions ──────────────────────────────────────────

  Widget _buildTopHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_bag, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Purchase / Procurement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Saark Exploration Private Limited • Inward GRN, Vendor Relations & Accounts Payables',
                    style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                  ),
                ],
              ),
              if (!isMobile)
                Row(
                  children: [
                    _buildQuickActionButton(
                      label: '+ Cheque Details',
                      icon: Icons.account_balance,
                      onTap: () => _openChequeManagement(),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickActionButton(
                      label: '+ Vendor Registration',
                      icon: Icons.storefront,
                      onTap: () => _openVendorRegistration(),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickActionButton(
                      label: '+ Outward Document',
                      icon: Icons.outbox,
                      onTap: () => _openOutwardDocument(),
                    ),
                    const SizedBox(width: 10),
                    _buildPrimaryActionButton(
                      label: '+ Inward Entry',
                      icon: Icons.move_to_inbox,
                      onTap: () => _openInwardEntry(),
                    ),
                  ],
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickActionButton(
                    label: '+ Cheque',
                    icon: Icons.account_balance,
                    onTap: () => _openChequeManagement(),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionButton(
                    label: '+ Vendor',
                    icon: Icons.storefront,
                    onTap: () => _openVendorRegistration(),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickActionButton(
                    label: '+ Outward',
                    icon: Icons.outbox,
                    onTap: () => _openOutwardDocument(),
                  ),
                  const SizedBox(width: 8),
                  _buildPrimaryActionButton(
                    label: '+ Inward',
                    icon: Icons.move_to_inbox,
                    onTap: () => _openInwardEntry(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: AppTheme.darkBorder),
        backgroundColor: AppTheme.darkBackground,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppTheme.primary),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPrimaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  // ─── Filter Bar ──────────────────────────────────────────────────────────

  Widget _buildFilterBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.darkBackground,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Financial Year selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFinYear,
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.darkTextSecondary),
                      items: const [
                        DropdownMenuItem(value: '2026-27', child: Text('FY 2026-27 (Current)')),
                        DropdownMenuItem(value: '2025-26', child: Text('FY 2025-26')),
                        DropdownMenuItem(value: 'ALL', child: Text('All Financial Years')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedFinYear = val);
                          _refreshDashboard();
                        }
                      },
                    ),
                  ),
                ),

                // Date Range Filter button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.darkSurface,
                    side: const BorderSide(color: AppTheme.darkBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                      initialDateRange: _selectedDateRange,
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primary,
                            onPrimary: Colors.white,
                            surface: AppTheme.darkSurface,
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                      _refreshDashboard();
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                  label: Text(
                    _selectedDateRange == null
                        ? 'Date Range: All'
                        : '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

                if (_selectedDateRange != null)
                  IconButton(
                    tooltip: 'Clear Date Filter',
                    icon: const Icon(Icons.clear, size: 16, color: AppTheme.darkTextSecondary),
                    onPressed: () {
                      setState(() => _selectedDateRange = null);
                      _refreshDashboard();
                    },
                  ),

                // Status Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      icon: const Icon(Icons.filter_list, color: AppTheme.darkTextSecondary, size: 16),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                        DropdownMenuItem(value: 'UNPAID', child: Text('Unpaid Invoices')),
                        DropdownMenuItem(value: 'PARTIALLY_PAID', child: Text('Partially Paid')),
                        DropdownMenuItem(value: 'PAID', child: Text('Paid Invoices')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                          _refreshDashboard();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Refresh button
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh, color: AppTheme.darkTextSecondary),
            onPressed: _refreshDashboard,
          ),
        ],
      ),
    );
  }

  // ─── Summary Cards ───────────────────────────────────────────────────────

  Widget _buildSummaryCards(Map<String, dynamic> summary, bool isMobile) {
    final productLines = summary['productLines'] ?? 0;
    final totalInwardAmount = (summary['totalInwardAmount'] as num?)?.toDouble() ?? 0.0;
    final pendingAmount = (summary['pendingAmount'] as num?)?.toDouble() ?? 0.0;

    final cards = [
      _buildDynamicCard(
        title: 'Product Lines',
        value: productLines.toString(),
        icon: Icons.layers_outlined,
        color: AppTheme.info,
        subtitle: 'Unique procurement items received',
      ),
      _buildDynamicCard(
        title: 'Total Inward Amount',
        value: _formatCurrency(totalInwardAmount),
        icon: Icons.inventory_2_outlined,
        color: AppTheme.success,
        subtitle: 'From authoritative inward GRN ledger',
      ),
      _buildDynamicCard(
        title: 'Pending Amount',
        value: _formatCurrency(pendingAmount),
        icon: Icons.pending_actions_outlined,
        color: AppTheme.primary,
        subtitle: 'Outstanding supplier invoice payables',
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
    );
  }

  Widget _buildDynamicCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── Pending Invoices Section ────────────────────────────────────────────

  Widget _buildPendingInvoicesSection(List<Map<String, dynamic>> invoices, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Search Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PENDING INVOICES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${invoices.length} outstanding invoice(s) requiring payment release',
                        style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),

          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppTheme.success, size: 40),
                    SizedBox(height: 10),
                    Text('No pending invoices found', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('All supplier purchase accounts are settled.', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
                  ],
                ),
              ),
            )
          else if (isMobile)
            _buildPendingInvoicesMobileCards(invoices)
          else
            _buildPendingInvoicesTable(invoices),
        ],
      ),
    );
  }

  Widget _buildPendingInvoicesTable(List<Map<String, dynamic>> invoices) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
        horizontalMargin: 20,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Vendor', style: TextStyle(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Invoice Number', style: TextStyle(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Department', style: TextStyle(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Invoice Total', style: TextStyle(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Paid', style: TextStyle(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pending Balance', style: TextStyle(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status', style: TextStyle(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Action', style: TextStyle(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold))),
        ],
        rows: invoices.map((inv) {
          final vendor = inv['vendor'];
          final vendorName = vendor is Map
              ? (vendor['companyName']?.toString() ?? 'Unknown Vendor')
              : (vendor?.toString() ?? 'Unknown Vendor');
          final invoiceNumber = inv['invoiceNumber']?.toString() ?? 'N/A';
          final dept = (inv['department'] ?? inv['departmentId'])?.toString() ?? 'Procurement';
          final total = (inv['invoiceTotal'] as num?)?.toDouble() ??
              (inv['totalAmount'] as num?)?.toDouble() ??
              0.0;
          final paid = (inv['paid'] as num?)?.toDouble() ??
              (inv['paidAmount'] as num?)?.toDouble() ??
              0.0;
          final balance = (inv['pendingBalance'] as num?)?.toDouble() ??
              (inv['balanceAmount'] as num?)?.toDouble() ??
              0.0;
          final status = inv['status']?.toString() ?? 'UNPAID';

          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    const Icon(Icons.business, size: 14, color: AppTheme.darkTextSecondary),
                    const SizedBox(width: 8),
                    Text(vendorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              DataCell(Text(invoiceNumber, style: const TextStyle(color: Colors.white))),
              DataCell(Text(dept, style: const TextStyle(color: AppTheme.darkTextSecondary))),
              DataCell(Text(_formatCurrency(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              DataCell(Text(_formatCurrency(paid), style: const TextStyle(color: AppTheme.success))),
              DataCell(
                Text(
                  _formatCurrency(balance),
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(_buildStatusBadge(status)),
              DataCell(
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openPayInvoiceDialog(inv),
                  icon: const Icon(Icons.payment, size: 14),
                  label: const Text('Pay Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPendingInvoicesMobileCards(List<Map<String, dynamic>> invoices) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final inv = invoices[index];
        final vendor = inv['vendor'];
        final vendorName = vendor is Map
            ? (vendor['companyName']?.toString() ?? 'Vendor')
            : (vendor?.toString() ?? 'Vendor');
        final invoiceNumber = inv['invoiceNumber']?.toString() ?? 'N/A';
        final total = (inv['invoiceTotal'] as num?)?.toDouble() ??
            (inv['totalAmount'] as num?)?.toDouble() ??
            0.0;
        final paid = (inv['paid'] as num?)?.toDouble() ??
            (inv['paidAmount'] as num?)?.toDouble() ??
            0.0;
        final balance = (inv['pendingBalance'] as num?)?.toDouble() ??
            (inv['balanceAmount'] as num?)?.toDouble() ??
            0.0;
        final status = inv['status']?.toString() ?? 'UNPAID';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      vendorName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 6),
              Text('Invoice: $invoiceNumber', style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Amount', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11)),
                      Text(_formatCurrency(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paid', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11)),
                      Text(_formatCurrency(paid), style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Pending Balance', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11)),
                      Text(
                        _formatCurrency(balance),
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openPayInvoiceDialog(inv),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Pay Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Inward Entry Register Section ───────────────────────────────────────

  Widget _buildInwardRegisterSection(List<Map<String, dynamic>> inwards, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.move_to_inbox, color: AppTheme.info, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INWARD ENTRY REGISTER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Goods Receipt Notes (GRN), partial receipts, QC inspections & stock records',
                        style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),

          if (inwards.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(
                child: Text('No Inward GRN entries found.', style: TextStyle(color: AppTheme.darkTextSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inwards.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.darkBorder),
              itemBuilder: (context, index) {
                final inw = inwards[index];
                final inwardNum = inw['inwardNumber']?.toString() ?? 'N/A';
                final vendor = inw['vendor'];
                final vendorName = vendor is Map
                    ? (vendor['companyName']?.toString() ?? 'Vendor')
                    : (vendor?.toString() ?? 'Vendor');
                final invoiceNum = inw['vendorInvoiceNumber']?.toString() ?? 'N/A';
                final grandTotal = (inw['grandTotal'] as num?)?.toDouble() ?? 0.0;
                final items = (inw['items'] as List? ?? []);
                DateTime? parsedDate;
                if (inw['inwardDate'] != null) {
                  try {
                    parsedDate = DateTime.tryParse(inw['inwardDate'].toString());
                  } catch (_) {}
                }
                final dateStr = parsedDate != null ? _dateFormat.format(parsedDate) : '';

                return ExpansionTile(
                  iconColor: AppTheme.primary,
                  collapsedIconColor: AppTheme.darkTextSecondary,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: const Icon(Icons.inventory, color: AppTheme.primary, size: 20),
                  ),
                  title: Row(
                    children: [
                      Text(inwardNum, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 10),
                      Text('• $vendorName', style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13)),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Date: $dateStr | Invoice: $invoiceNum | ${items.length} Product Lines',
                      style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                    ),
                  ),
                  trailing: Text(
                    _formatCurrency(grandTotal),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Line Items & QC Inspection Status:',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ...items.map((it) {
                            final productName = it['product']?['name'] ?? 'Product';
                            final qty = it['quantity'] ?? 0;
                            final unit = it['unit'] ?? 'PCS';
                            final rate = (it['rate'] as num?)?.toDouble() ?? 0.0;
                            final amt = (it['amount'] as num?)?.toDouble() ?? 0.0;
                            final qcStatus = it['qcStatus'] ?? 'PENDING';
                            final batch = it['batchNumber'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.darkBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.darkBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(productName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
                                        if (batch != null)
                                          Text('Batch: $batch', style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text('$qty $unit', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                  Expanded(
                                    child: Text('₹$rate', style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
                                  ),
                                  Expanded(
                                    child: Text(_formatCurrency(amt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                  ),
                                  _buildQCStatusBadge(qcStatus),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── Helpers & Badges ────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.darkTextSecondary,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'PAID':
        bg = AppTheme.success.withValues(alpha: 0.15);
        fg = AppTheme.success;
        break;
      case 'PARTIALLY_PAID':
        bg = AppTheme.primary.withValues(alpha: 0.15);
        fg = AppTheme.primary;
        break;
      case 'OVERDUE':
        bg = AppTheme.error.withValues(alpha: 0.15);
        fg = AppTheme.error;
        break;
      case 'UNPAID':
      default:
        bg = AppTheme.warning.withValues(alpha: 0.15);
        fg = AppTheme.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildQCStatusBadge(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        color = AppTheme.success;
        break;
      case 'REJECTED':
        color = AppTheme.error;
        break;
      case 'PARTIALLY_ACCEPTED':
        color = AppTheme.warning;
        break;
      default:
        color = AppTheme.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Modal Triggers ──────────────────────────────────────────────────────

  void _openPayInvoiceDialog(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (ctx) => PayInvoiceDialog(
        invoice: invoice,
        onPaymentSuccess: _refreshDashboard,
      ),
    );
  }

  void _openInwardEntry() {
    showDialog(
      context: context,
      builder: (ctx) => InwardEntryModal(
        onSuccess: _refreshDashboard,
      ),
    );
  }

  void _openChequeManagement() {
    showDialog(
      context: context,
      builder: (ctx) => ChequeManagementModal(
        onUpdated: _refreshDashboard,
      ),
    );
  }

  void _openOutwardDocument() {
    showDialog(
      context: context,
      builder: (ctx) => OutwardDocumentModal(
        onSuccess: _refreshDashboard,
      ),
    );
  }

  void _openVendorRegistration() {
    showDialog(
      context: context,
      builder: (ctx) => VendorRegistrationModal(
        onSuccess: _refreshDashboard,
      ),
    );
  }
}
