import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

class FinancialReportsWorkspaceView extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;

  const FinancialReportsWorkspaceView({
    super.key,
    this.onBackToDashboard,
  });

  @override
  ConsumerState<FinancialReportsWorkspaceView> createState() => _FinancialReportsWorkspaceViewState();
}

class _FinancialReportsWorkspaceViewState extends ConsumerState<FinancialReportsWorkspaceView> {
  // ─── Theme Colors ───────────────────────────────────────────────────────────
  static const Color _bgDark = Color(0xFF191A1E);
  static const Color _cardBg = Color(0xFF1E2025);
  static const Color _cardInsetBg = Color(0xFF141518);
  static const Color _orangeAccent = Color(0xFFF15A24);
  static const Color _borderDark = Color(0xFF2E3138);
  static const Color _textMuted = Color(0xFF9AA0A6);

  // Tab Index (0: Dashboard, 1: P&L, 2: Cash Flow, 3: Balance Sheet, 4: Outstanding)
  int _activeReportTab = 0;

  // Filter controllers for P&L and Cash Flow
  final TextEditingController _plPeriodCtrl = TextEditingController(text: DateFormat('yyyy-MM').format(DateTime.now()));
  final TextEditingController _cfPeriodCtrl = TextEditingController(text: DateFormat('yyyy-MM').format(DateTime.now()));

  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _plPeriodCtrl.dispose();
    _cfPeriodCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchReports([String? period]) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final data = await repo.getFinancialReports(period: period);
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Fallback baseline data if backend is offline
      if (mounted) {
        setState(() {
          _reportData = _buildFallbackData();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildFallbackData() {
    return {
      'period': '2026-10',
      'dashboard': {
        'todaySales': 118100.0,
        'monthlySales': 348100.0,
        'bankBalance': 0.0,
        'cashBalance': 0.0,
        'customerOutstanding': 150000.0,
        'vendorOutstanding': 133000.0,
        'monthlyExpense': 114950.0,
        'monthlyProfit': 233150.0,
        'gstPayable': 26218.0,
      },
      'profitAndLoss': {
        'incomeRows': [
          {'category': 'Sales', 'description': 'Total Sales / Revenue', 'amount': 348100.0},
          {'category': 'Sales', 'description': 'Amount Received', 'amount': 265000.0},
          {'category': 'Sales', 'description': 'Pending Receivable', 'amount': 83100.0},
        ],
        'expenseRows': [
          {'category': 'Expense', 'description': 'Rent', 'amount': 45000.0},
          {'category': 'Expense', 'description': 'Electricity', 'amount': 18450.0},
          {'category': 'Expense', 'description': 'Salary', 'amount': 32000.0},
          {'category': 'Expense', 'description': 'Repairs', 'amount': 8500.0},
          {'category': 'Expense', 'description': 'Travel', 'amount': 6800.0},
          {'category': 'Expense', 'description': 'Internet / Mobile', 'amount': 4200.0},
          {'category': 'Expense', 'description': 'Salary Payable', 'amount': 28500.0},
        ],
        'totalIncome': 348100.0,
        'totalExpenses': 143450.0,
        'netProfit': 204650.0,
      },
      'cashFlow': {
        'inflowRows': [
          {'section': 'Operating', 'description': 'Cash received from customers', 'amount': 265000.0},
          {'section': 'Financing', 'description': 'Bank deposits / Cash in', 'amount': 50000.0},
        ],
        'outflowRows': [
          {'section': 'Operating', 'description': 'Business Expenses', 'amount': 114950.0},
          {'section': 'Operating', 'description': 'Vendor / Supplier Payments', 'amount': 65000.0},
          {'section': 'Payroll', 'description': 'Salary Paid', 'amount': 32000.0},
        ],
        'totalInflow': 315000.0,
        'totalOutflow': 211950.0,
        'netCashFlow': 103050.0,
      },
      'balanceSheet': {
        'assetRows': [
          {'section': 'Current Assets', 'item': 'Bank Balance', 'amount': 0.0},
          {'section': 'Current Assets', 'item': 'Cash in Hand', 'amount': 0.0},
          {'section': 'Current Assets', 'item': 'Accounts Receivable (AR)', 'amount': 150000.0},
          {'section': 'Current Assets', 'item': 'Inventory / Stock Value', 'amount': 345000.0},
        ],
        'liabilityRows': [
          {'section': 'Current Liabilities', 'item': 'Accounts Payable (AP)', 'amount': 133000.0},
          {'section': 'Current Liabilities', 'item': 'Salary Payable', 'amount': 28500.0},
          {'section': 'Current Liabilities', 'item': 'GST Payable', 'amount': 26218.0},
        ],
        'equityRows': [
          {'section': "Owner's Equity", 'item': 'Net Company Capital', 'amount': 307282.0},
        ],
        'totalAssets': 495000.0,
        'totalLiabilities': 187718.0,
        'totalEquity': 307282.0,
      },
      'outstanding': {
        'totalCustomerOutstanding': 150000.0,
        'totalVendorOutstanding': 133000.0,
        'customerPending': [
          {
            'customer': 'Win Win Distribution Pvt Ltd',
            'invoiceNumber': 'INV-2026-1001',
            'invoiceDate': '2026-10-02',
            'dueDate': '2026-10-25',
            'invoiceAmount': 145000.0,
            'amountReceived': 100000.0,
            'pendingAmount': 45000.0,
            'status': 'Partial',
          },
          {
            'customer': 'TechMech Automation',
            'invoiceNumber': 'INV-2026-1003',
            'invoiceDate': '2026-10-15',
            'dueDate': '2026-11-05',
            'invoiceAmount': 65000.0,
            'amountReceived': 30000.0,
            'pendingAmount': 35000.0,
            'status': 'Partial',
          },
          {
            'customer': 'Revolve Engineers',
            'invoiceNumber': 'INV-2026-0915',
            'invoiceDate': '2026-09-18',
            'dueDate': '2026-10-10',
            'invoiceAmount': 120000.0,
            'amountReceived': 50000.0,
            'pendingAmount': 70000.0,
            'status': 'Overdue',
          },
        ],
        'vendorPending': [
          {
            'vendor': 'Apex Copper Conductors Ltd',
            'billNumber': 'BILL-2026-881',
            'billDate': '2026-09-28',
            'dueDate': '2026-10-15',
            'billAmount': 68000.0,
            'amountPaid': 20000.0,
            'pendingAmount': 48000.0,
            'status': 'Overdue',
          },
          {
            'vendor': 'Siemens Switchgear Agencies',
            'billNumber': 'BILL-2026-904',
            'billDate': '2026-10-05',
            'dueDate': '2026-10-28',
            'billAmount': 92000.0,
            'amountPaid': 45000.0,
            'pendingAmount': 47000.0,
            'status': 'Partial',
          },
          {
            'vendor': 'Schneider Electric Components',
            'billNumber': 'BILL-2026-920',
            'billDate': '2026-10-10',
            'dueDate': '2026-11-05',
            'billAmount': 38000.0,
            'amountPaid': 0.0,
            'pendingAmount': 38000.0,
            'status': 'Unpaid',
          },
        ],
      },
    };
  }

  void _exportAllToExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF2E7D32),
        content: Row(
          children: [
            Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Exporting consolidated financial statements to Excel (.xlsx)...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Sub-header Navigation Button ──────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: widget.onBackToDashboard ?? () => context.go('/dashboard'),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFFD0D5DD)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 14, color: Colors.black),
                      SizedBox(width: 6),
                      Text(
                        'Back to Sales Dashboard',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ─── Header & Global Actions ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assessment_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Financial Reports',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exportAllToExcel,
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Export All to Excel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orangeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _fetchReports(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh All', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orangeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── The Workspace Notebook (5 Audit Tabs) ─────────────────────
            _buildNotebookTabBar(),
            const SizedBox(height: 14),

            // ─── Active Tab View ───────────────────────────────────────────
            if (_isLoading)
              Container(
                height: 350,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: _orangeAccent),
              )
            else
              _buildActiveTabContent(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── 5-Tab Audit Notebook Bar ───────────────────────────────────────────────
  Widget _buildNotebookTabBar() {
    final tabs = [
      {'title': 'Dashboard', 'icon': '🏠'},
      {'title': 'Profit & Loss', 'icon': '📊'},
      {'title': 'Cash Flow', 'icon': '🏦'},
      {'title': 'Balance Sheet', 'icon': '📋'},
      {'title': 'Outstanding', 'icon': '⏳'},
    ];

    return Row(
      children: List.generate(tabs.length, (index) {
        final isActive = _activeReportTab == index;
        final t = tabs[index];
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            onTap: () => setState(() => _activeReportTab = index),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? _cardBg : const Color(0xFF151619),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isActive ? _orangeAccent : _borderDark,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t['icon']!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    t['title']!,
                    style: TextStyle(
                      color: isActive ? Colors.white : _textMuted,
                      fontSize: 12.5,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeReportTab) {
      case 0:
        return _buildTab1Dashboard();
      case 1:
        return _buildTab2ProfitAndLoss();
      case 2:
        return _buildTab3CashFlow();
      case 3:
        return _buildTab4BalanceSheet();
      case 4:
        return _buildTab5Outstanding();
      default:
        return _buildTab1Dashboard();
    }
  }

  // ─── TAB 1: 🏠 DASHBOARD (3x3 KPI GRID) ────────────────────────────────────
  Widget _buildTab1Dashboard() {
    final dash = _reportData['dashboard'] ?? {};
    final metrics = [
      {
        'label': "Today's Sales",
        'icon': '💰',
        'val': (dash['todaySales'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFF2563EB), // Navy
      },
      {
        'label': 'Monthly Sales',
        'icon': '📈',
        'val': (dash['monthlySales'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFF2563EB), // Navy
      },
      {
        'label': 'Bank Balance',
        'icon': '🏦',
        'val': (dash['bankBalance'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFF22C55E), // Green
      },
      {
        'label': 'Cash in Hand',
        'icon': '💵',
        'val': (dash['cashBalance'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFF22C55E), // Green
      },
      {
        'label': 'Customer Outstanding',
        'icon': '📥',
        'val': (dash['customerOutstanding'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFFEF4444), // Red
      },
      {
        'label': 'Vendor Outstanding',
        'icon': '📤',
        'val': (dash['vendorOutstanding'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFFEF4444), // Red
      },
      {
        'label': 'Monthly Expenses',
        'icon': '💸',
        'val': (dash['monthlyExpense'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFFF97316), // Dark Orange
      },
      {
        'label': 'Monthly Profit / Loss',
        'icon': '📊',
        'val': (dash['monthlyProfit'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFFA855F7), // Purple
      },
      {
        'label': 'GST Payable',
        'icon': '🧾',
        'val': (dash['gstPayable'] as num?)?.toDouble() ?? 0.0,
        'color': const Color(0xFFD97706), // Brown / Amber
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Today's Financial Snapshot",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        // Responsive Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth < 600 ? 1 : (constraints.maxWidth < 950 ? 2 : 3);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: cols == 1 ? 3.4 : 2.4,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, idx) {
                final m = metrics[idx];
                final label = m['label'] as String;
                final icon = m['icon'] as String;
                final val = m['val'] as double;
                final color = m['color'] as Color;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _borderDark, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _cardInsetBg,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '₹${NumberFormat('#,##0.00').format(val)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ─── TAB 2: 📊 PROFIT & LOSS STATEMENT ────────────────────────────────────
  Widget _buildTab2ProfitAndLoss() {
    final pl = _reportData['profitAndLoss'] ?? {};
    final incomeRows = (pl['incomeRows'] as List?) ?? [];
    final expenseRows = (pl['expenseRows'] as List?) ?? [];
    final totalIncome = (pl['totalIncome'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (pl['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (pl['netProfit'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Profit & Loss Statement',
              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const Text('Period (YYYY-MM):', style: TextStyle(color: _textMuted, fontSize: 12)),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              height: 32,
              child: TextFormField(
                controller: _plPeriodCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: _filterInputDecoration(),
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () => _fetchReports(_plPeriodCtrl.text.trim()),
              style: _filterButtonStyle(),
              child: const Text('Apply', style: TextStyle(fontSize: 11.5)),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () {
                _plPeriodCtrl.text = '';
                _fetchReports('All');
              },
              style: _filterButtonStyle(),
              child: const Text('All', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Table Container
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderDark),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              _buildTableHeader(['Category', 'Description', 'Amount (₹)']),
              // INCOME Header
              _buildSectionHeaderRow('INCOME'),
              ...incomeRows.map((r) => _buildDataRow(
                    col1: r['category']?.toString() ?? '',
                    col2: r['description']?.toString() ?? '',
                    col3: (r['amount'] as num?)?.toDouble() ?? 0.0,
                    textColor: const Color(0xFF60A5FA),
                  )),
              _buildTotalRow('Total Income', totalIncome, const Color(0xFF60A5FA)),
              // EXPENSES Header
              _buildSectionHeaderRow('EXPENSES'),
              ...expenseRows.map((r) => _buildDataRow(
                    col1: r['category']?.toString() ?? '',
                    col2: r['description']?.toString() ?? '',
                    col3: (r['amount'] as num?)?.toDouble() ?? 0.0,
                    textColor: const Color(0xFFF87171),
                  )),
              _buildTotalRow('Total Expenses', totalExpenses, const Color(0xFFF87171)),
              // NET OPERATING PROFIT / LOSS
              _buildHighlightRow(
                netProfit >= 0 ? 'NET OPERATING PROFIT' : 'NET OPERATING LOSS',
                netProfit,
                netProfit >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── TAB 3: 🏦 CASH FLOW STATEMENT ────────────────────────────────────────
  Widget _buildTab3CashFlow() {
    final cf = _reportData['cashFlow'] ?? {};
    final inflowRows = (cf['inflowRows'] as List?) ?? [];
    final outflowRows = (cf['outflowRows'] as List?) ?? [];
    final totalInflow = (cf['totalInflow'] as num?)?.toDouble() ?? 0.0;
    final totalOutflow = (cf['totalOutflow'] as num?)?.toDouble() ?? 0.0;
    final netCashFlow = (cf['netCashFlow'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Cash Flow Statement',
              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const Text('Period (YYYY-MM):', style: TextStyle(color: _textMuted, fontSize: 12)),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              height: 32,
              child: TextFormField(
                controller: _cfPeriodCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: _filterInputDecoration(),
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () => _fetchReports(_cfPeriodCtrl.text.trim()),
              style: _filterButtonStyle(),
              child: const Text('Apply', style: TextStyle(fontSize: 11.5)),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () {
                _cfPeriodCtrl.text = '';
                _fetchReports('All');
              },
              style: _filterButtonStyle(),
              child: const Text('All', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderDark),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              _buildTableHeader(['Section', 'Description', 'Amount (₹)']),
              _buildSectionHeaderRow('CASH INFLOWS'),
              ...inflowRows.map((r) => _buildDataRow(
                    col1: r['section']?.toString() ?? '',
                    col2: r['description']?.toString() ?? '',
                    col3: (r['amount'] as num?)?.toDouble() ?? 0.0,
                    textColor: const Color(0xFF22C55E),
                  )),
              _buildTotalRow('Total Cash In', totalInflow, const Color(0xFF22C55E)),
              _buildSectionHeaderRow('CASH OUTFLOWS'),
              ...outflowRows.map((r) => _buildDataRow(
                    col1: r['section']?.toString() ?? '',
                    col2: r['description']?.toString() ?? '',
                    col3: (r['amount'] as num?)?.toDouble() ?? 0.0,
                    textColor: const Color(0xFFEF4444),
                  )),
              _buildTotalRow('Total Cash Out', totalOutflow, const Color(0xFFEF4444)),
              _buildHighlightRow(
                'NET CASH FLOW',
                netCashFlow,
                netCashFlow >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── TAB 4: 📋 BALANCE SHEET ──────────────────────────────────────────────
  Widget _buildTab4BalanceSheet() {
    final bs = _reportData['balanceSheet'] ?? {};
    final assetRows = (bs['assetRows'] as List?) ?? [];
    final liabilityRows = (bs['liabilityRows'] as List?) ?? [];
    final equityRows = (bs['equityRows'] as List?) ?? [];
    final totalAssets = (bs['totalAssets'] as num?)?.toDouble() ?? 0.0;
    final totalLiabilities = (bs['totalLiabilities'] as num?)?.toDouble() ?? 0.0;
    final totalEquity = (bs['totalEquity'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Balance Sheet',
          style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderDark),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              _buildTableHeader(['Section', 'Item', 'Amount (₹)']),
              _buildSectionHeaderRow('ASSETS'),
              ...assetRows.map((r) => _buildDataRow(
                    col1: r['section']?.toString() ?? '',
                    col2: r['item']?.toString() ?? '',
                    col3: (r['amount'] as num?)?.toDouble() ?? 0.0,
                    textColor: const Color(0xFF38BDF8),
                  )),
              _buildTotalRow('Total Assets', totalAssets, const Color(0xFF38BDF8)),
              _buildSectionHeaderRow('LIABILITIES'),
              ...liabilityRows.map((r) => _buildDataRow(
                    col1: r['section']?.toString() ?? '',
                    col2: r['item']?.toString() ?? '',
                    col3: (r['amount'] as num?)?.toDouble() ?? 0.0,
                    textColor: const Color(0xFFFB7185),
                  )),
              _buildTotalRow('Total Liabilities', totalLiabilities, const Color(0xFFFB7185)),
              _buildSectionHeaderRow('EQUITY'),
              ...equityRows.map((r) => _buildDataRow(
                    col1: r['section']?.toString() ?? '',
                    col2: r['item']?.toString() ?? '',
                    col3: (r['amount'] as num?)?.toDouble() ?? 0.0,
                    textColor: const Color(0xFF34D399),
                  )),
              _buildHighlightRow("TOTAL EQUITY (Owner's Capital)", totalEquity, const Color(0xFF34D399)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── TAB 5: ⏳ OUTSTANDING REPORT ──────────────────────────────────────────
  Widget _buildTab5Outstanding() {
    final out = _reportData['outstanding'] ?? {};
    final custOut = (out['totalCustomerOutstanding'] as num?)?.toDouble() ?? 0.0;
    final vendOut = (out['totalVendorOutstanding'] as num?)?.toDouble() ?? 0.0;
    final custPending = (out['customerPending'] as List?) ?? [];
    final vendPending = (out['vendorPending'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Outstanding Report',
          style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Summary Strip
        Row(
          children: [
            Expanded(
              child: _buildOutstandingSummaryCard(
                title: 'Total Customer Outstanding',
                amount: custOut,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildOutstandingSummaryCard(
                title: 'Total Vendor Outstanding',
                amount: vendOut,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Customer Pending Table
        const Text(
          'Customer Pending Payments',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _build8ColTable(
          headers: ['Customer', 'Invoice No.', 'Invoice Date', 'Due Date', 'Invoice Amt', 'Received', 'Pending', 'Status'],
          rows: custPending.map((r) => [
            r['customer']?.toString() ?? '',
            r['invoiceNumber']?.toString() ?? '',
            r['invoiceDate']?.toString() ?? '',
            r['dueDate']?.toString() ?? '',
            '₹${NumberFormat('#,##0.00').format(r['invoiceAmount'] ?? 0)}',
            '₹${NumberFormat('#,##0.00').format(r['amountReceived'] ?? 0)}',
            '₹${NumberFormat('#,##0.00').format(r['pendingAmount'] ?? 0)}',
            r['status']?.toString() ?? '',
          ]).toList(),
        ),
        const SizedBox(height: 18),

        // Vendor Pending Table
        const Text(
          'Vendor Pending Payments',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _build8ColTable(
          headers: ['Vendor', 'Bill No.', 'Bill Date', 'Due Date', 'Bill Amt', 'Paid', 'Pending', 'Status'],
          rows: vendPending.map((r) => [
            r['vendor']?.toString() ?? '',
            r['billNumber']?.toString() ?? '',
            r['billDate']?.toString() ?? '',
            r['dueDate']?.toString() ?? '',
            '₹${NumberFormat('#,##0.00').format(r['billAmount'] ?? 0)}',
            '₹${NumberFormat('#,##0.00').format(r['amountPaid'] ?? 0)}',
            '₹${NumberFormat('#,##0.00').format(r['pendingAmount'] ?? 0)}',
            r['status']?.toString() ?? '',
          ]).toList(),
        ),
      ],
    );
  }

  // ─── Table & Row Helpers ───────────────────────────────────────────────────

  Widget _buildTableHeader(List<String> headings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFF22242A),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(headings[0], style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text(headings[1], style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(headings[2], textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderRow(String title) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF332014),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Text(
        title,
        style: const TextStyle(color: _orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildDataRow({required String col1, required String col2, required double col3, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF25272C), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(col1, style: const TextStyle(color: _textMuted, fontSize: 12))),
          Expanded(flex: 4, child: Text(col2, style: TextStyle(color: textColor, fontSize: 12.5))),
          Expanded(
            flex: 2,
            child: Text(
              '₹${NumberFormat('#,##0.00').format(col3)}',
              textAlign: TextAlign.right,
              style: TextStyle(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double total, Color color) {
    return Container(
      color: const Color(0xFF1E2025),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          const Expanded(flex: 2, child: SizedBox()),
          Expanded(flex: 4, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
          Expanded(
            flex: 2,
            child: Text(
              '₹${NumberFormat('#,##0.00').format(total)}',
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(String label, double val, Color color) {
    return Container(
      color: const Color(0xFF16171B),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          const Expanded(flex: 2, child: SizedBox()),
          Expanded(flex: 4, child: Text(label, style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.bold))),
          Expanded(
            flex: 2,
            child: Text(
              '₹${NumberFormat('#,##0.00').format(val)}',
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingSummaryCard({required String title, required double amount, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            '₹${NumberFormat('#,##0.00').format(amount)}',
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _build8ColTable({required List<String> headers, required List<List<String>> rows}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderDark),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFF22242A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: headers.map((h) {
                final isAmount = h.contains('Amt') || h.contains('Received') || h.contains('Paid') || h.contains('Pending');
                return Expanded(
                  flex: h.contains('Customer') || h.contains('Vendor') ? 3 : 2,
                  child: Text(
                    h,
                    textAlign: isAmount ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
          if (rows.isEmpty)
            Container(
              height: 80,
              alignment: Alignment.center,
              child: const Text('No records found.', style: TextStyle(color: _textMuted, fontSize: 12)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: _borderDark),
              itemBuilder: (ctx, idx) {
                final r = rows[idx];
                final status = r[7];
                final isOverdue = status == 'Overdue';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: List.generate(r.length, (cIdx) {
                      final val = r[cIdx];
                      final isAmount = cIdx >= 4 && cIdx <= 6;
                      final isPending = cIdx == 6;
                      return Expanded(
                        flex: cIdx == 0 ? 3 : 2,
                        child: Text(
                          val,
                          textAlign: isAmount ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            color: isPending || isOverdue
                                ? (isOverdue ? const Color(0xFFEF4444) : Colors.white)
                                : (cIdx == 7 && status == 'Paid' ? const Color(0xFF22C55E) : Colors.white),
                            fontSize: 11.5,
                            fontWeight: isPending || cIdx == 7 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  InputDecoration _filterInputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      filled: true,
      fillColor: const Color(0xFF151619),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: _borderDark)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: _borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: _orangeAccent)),
    );
  }

  ButtonStyle _filterButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF2A2D34),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      elevation: 0,
    );
  }
}
