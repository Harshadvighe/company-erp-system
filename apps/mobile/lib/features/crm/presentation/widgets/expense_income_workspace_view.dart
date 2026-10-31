import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/sales_repository.dart';

// ─── Domain Model ─────────────────────────────────────────────────────────────
class ExpenseItem {
  final String id;
  String date; // YYYY-MM-DD
  String category;
  String description;
  double amount;
  String paymentMethod;
  String paidTo;
  String notes;

  ExpenseItem({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    this.paidTo = '',
    this.notes = '',
  });

  ExpenseItem copyWith({
    String? id,
    String? date,
    String? category,
    String? description,
    double? amount,
    String? paymentMethod,
    String? paidTo,
    String? notes,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidTo: paidTo ?? this.paidTo,
      notes: notes ?? this.notes,
    );
  }
}

class CategoryBreakdown {
  final String category;
  final double subtotal;
  final double percentage;

  CategoryBreakdown({
    required this.category,
    required this.subtotal,
    required this.percentage,
  });
}

// ─── Workspace View ───────────────────────────────────────────────────────────
class ExpenseIncomeWorkspaceView extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;
  const ExpenseIncomeWorkspaceView({super.key, this.onBackToDashboard});

  @override
  ConsumerState<ExpenseIncomeWorkspaceView> createState() =>
      _ExpenseIncomeWorkspaceViewState();
}

class _ExpenseIncomeWorkspaceViewState
    extends ConsumerState<ExpenseIncomeWorkspaceView> {
  bool _isLoading = false;

  // ─── Master List & Selection ───────────────────────────────────────────────
  final List<ExpenseItem> _expenses = [];
  int? _selectedExpenseIndex;

  // ─── Form Controllers ──────────────────────────────────────────────────────
  final _dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  String _selectedCategory = 'Salary';
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedPaymentMethod = 'Cash';
  final _paidToCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ─── Sort State ────────────────────────────────────────────────────────────
  int _sortColumnIndex = 0; // 0 = Date, 1 = Category, 2 = Amount
  bool _sortAscending = false;

  // ─── Constants & Options ───────────────────────────────────────────────────
  static const List<String> _categories = [
    'Salary',
    'Rent',
    'Electricity',
    'Travel',
    'Material Purchase',
    'Software',
    'Internet / Mobile',
    'Repairs',
    'Other',
  ];

  static const List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'UPI',
    'Credit Card',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeDefaultData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLiveBackendData();
    });
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _paidToCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _initializeDefaultData() {
    _expenses.addAll([
      ExpenseItem(
        id: 'exp-1',
        date: '2026-10-01',
        category: 'Rent',
        description: 'Factory and corporate office monthly premises lease',
        amount: 45000.00,
        paymentMethod: 'Bank Transfer',
        paidTo: 'Chakan Industrial Estates Ltd',
        notes: 'Monthly Lease Agreement, Voucher #VCH-1001',
      ),
      ExpenseItem(
        id: 'exp-2',
        date: '2026-10-05',
        category: 'Electricity',
        description: 'MSEDCL industrial electrical connection power tariff',
        amount: 18450.00,
        paymentMethod: 'UPI',
        paidTo: 'Maharashtra State Electricity Board',
        notes: 'Meter #MTR-88192-IND',
      ),
      ExpenseItem(
        id: 'exp-3',
        date: '2026-10-08',
        category: 'Internet / Mobile',
        description: 'Tata Tele broadband fiber and staff corporate CUG lines',
        amount: 4200.00,
        paymentMethod: 'Credit Card',
        paidTo: 'Tata Teleservices Ltd',
        notes: 'Bill ref: TT-OCT-2026',
      ),
      ExpenseItem(
        id: 'exp-4',
        date: '2026-10-10',
        category: 'Salary',
        description: 'Staff advance and fabrication team overtime disbursements',
        amount: 32000.00,
        paymentMethod: 'Bank Transfer',
        paidTo: 'Operations & Fabrication Staff',
        notes: 'Pay Sheet Reference: PS-2026-10A',
      ),
      ExpenseItem(
        id: 'exp-5',
        date: '2026-10-12',
        category: 'Travel',
        description: 'Client site technical survey & commissioning trip to Nashik',
        amount: 6800.00,
        paymentMethod: 'Cash',
        paidTo: 'Sunil Jagtap (Site Engineer)',
        notes: 'Toll receipts & fuel vouchers attached',
      ),
      ExpenseItem(
        id: 'exp-6',
        date: '2026-10-14',
        category: 'Repairs',
        description: 'CNC bending tool calibrator and hydraulic pump servicing',
        amount: 8500.00,
        paymentMethod: 'UPI',
        paidTo: 'Apex Tooling Works',
        notes: 'Warranty maintenance check',
      ),
    ]);
  }

  // ─── Mathematical Formulas ─────────────────────────────────────────────────
  /// Formula 1: Total Expenses = Sum(Amount of all records)
  double get _totalExpenses {
    return _expenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Formula 2: This Month Expenses = Sum(Amount where Date starts with YYYY-MM)
  double get _thisMonthExpenses {
    final now = DateTime.now();
    final ym = DateFormat('yyyy-MM').format(now);
    return _expenses
        .where((e) => e.date.startsWith(ym))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Formula 3: Category Breakdown & Top Category
  List<CategoryBreakdown> get _categoryBreakdowns {
    final totals = <String, double>{};
    for (final exp in _expenses) {
      totals[exp.category] = (totals[exp.category] ?? 0.0) + exp.amount;
    }

    final total = _totalExpenses;
    final list = totals.entries.map((entry) {
      final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
      return CategoryBreakdown(
        category: entry.key,
        subtotal: entry.value,
        percentage: pct,
      );
    }).toList();

    list.sort((a, b) => b.subtotal.compareTo(a.subtotal));
    return list;
  }

  String get _topCategory {
    final breakdowns = _categoryBreakdowns;
    if (breakdowns.isEmpty || _totalExpenses == 0) return '—';
    return breakdowns.first.category;
  }

  String _formatCurrency(double amt) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amt);
  }

  // ─── Live Backend Communication ────────────────────────────────────────────
  Future<void> _fetchLiveBackendData({bool showToast = false}) async {
    try {
      final repo = ref.read(salesRepositoryProvider);
      final rawList = await repo.getExpenses();

      if (!mounted) return;
      if (rawList.isNotEmpty) {
        setState(() {
          _expenses.clear();
          for (final item in rawList) {
            _expenses.add(
              ExpenseItem(
                id: item['id']?.toString() ?? 'exp-${DateTime.now().millisecondsSinceEpoch}',
                date: item['date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
                category: item['category']?.toString() ?? 'Other',
                description: item['description']?.toString() ?? '',
                amount: (item['amount'] is num)
                    ? (item['amount'] as num).toDouble()
                    : (double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0),
                paymentMethod: item['paymentMethod']?.toString() ?? 'Cash',
                paidTo: item['paidTo']?.toString() ?? '',
                notes: item['notes']?.toString() ?? '',
              ),
            );
          }
        });
      }

      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expenses and KPIs synchronized with backend!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to sync expenses: $e');
      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using local expense records: $e'),
            backgroundColor: const Color(0xFFE57A38),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Form Actions ──────────────────────────────────────────────────────────
  void _selectExpense(int index) {
    setState(() {
      _selectedExpenseIndex = index;
      final exp = _expenses[index];
      _dateCtrl.text = exp.date;
      _selectedCategory = exp.category;
      _amountCtrl.text = exp.amount.toStringAsFixed(2);
      _descCtrl.text = exp.description;
      _selectedPaymentMethod = exp.paymentMethod;
      _paidToCtrl.text = exp.paidTo;
      _notesCtrl.text = exp.notes;
    });
  }

  void _clearForm() {
    setState(() {
      _selectedExpenseIndex = null;
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedCategory = 'Salary';
      _amountCtrl.clear();
      _descCtrl.clear();
      _selectedPaymentMethod = 'Cash';
      _paidToCtrl.clear();
      _notesCtrl.clear();
    });
  }

  Future<void> _saveExpense() async {
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense Amount (₹) must be greater than 0.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final date = _dateCtrl.text.trim().isEmpty
        ? DateFormat('yyyy-MM-dd').format(DateTime.now())
        : _dateCtrl.text.trim();
    final cat = _selectedCategory;
    final desc = _descCtrl.text.trim();
    final method = _selectedPaymentMethod;
    final paidTo = _paidToCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    final isEdit = _selectedExpenseIndex != null &&
        _selectedExpenseIndex! < _expenses.length;
    final targetId = isEdit ? _expenses[_selectedExpenseIndex!].id : null;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(salesRepositoryProvider);
      await repo.saveExpense({
        if (targetId != null) 'id': targetId,
        'date': date,
        'category': cat,
        'description': desc,
        'amount': amt,
        'paymentMethod': method,
        'paidTo': paidTo,
        'notes': notes,
      });

      await _fetchLiveBackendData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense "${cat}: ${_formatCurrency(amt)}" saved successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _clearForm();
      }
    } catch (e) {
      setState(() {
        if (isEdit) {
          _expenses[_selectedExpenseIndex!] =
              _expenses[_selectedExpenseIndex!].copyWith(
            date: date,
            category: cat,
            description: desc,
            amount: amt,
            paymentMethod: method,
            paidTo: paidTo,
            notes: notes,
          );
        } else {
          _expenses.insert(
            0,
            ExpenseItem(
              id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
              date: date,
              category: cat,
              description: desc,
              amount: amt,
              paymentMethod: method,
              paidTo: paidTo,
              notes: notes,
            ),
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense saved locally ($e)'),
            backgroundColor: const Color(0xFFE57A38),
          ),
        );
        _clearForm();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteExpense() {
    if (_selectedExpenseIndex == null ||
        _selectedExpenseIndex! >= _expenses.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expense entry from the table to delete.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final target = _expenses[_selectedExpenseIndex!];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2025),
        title: const Text('Delete Expense', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${target.category}: ${_formatCurrency(target.amount)}" (${target.description})?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              try {
                final repo = ref.read(salesRepositoryProvider);
                await repo.deleteExpense(target.id);
                await _fetchLiveBackendData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Expense "${target.category}" removed from backend.'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  _expenses.removeWhere((x) => x.id == target.id);
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Expense deleted locally ($e).'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              } finally {
                _clearForm();
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _sortExpenses(int colIndex) {
    setState(() {
      if (_sortColumnIndex == colIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = colIndex;
        _sortAscending = true;
      }

      switch (colIndex) {
        case 0: // Date
          _expenses.sort((a, b) => _sortAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date));
          break;
        case 1: // Category
          _expenses.sort((a, b) => _sortAscending
              ? a.category.compareTo(b.category)
              : b.category.compareTo(a.category));
          break;
        case 2: // Amount
          _expenses.sort((a, b) => _sortAscending
              ? a.amount.compareTo(b.amount)
              : b.amount.compareTo(a.amount));
          break;
      }
    });
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    await _fetchLiveBackendData(showToast: true);
  }

  void _handleDownloadExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exporting ${_expenses.length} expense records to Microsoft Excel...',
        ),
        backgroundColor: const Color(0xFFF15A24),
      ),
    );
  }

  // ─── Main Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 960;

    return Container(
      color: const Color(0xFF191A1E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Back to Sales Dashboard Button ───────────────────────────
            _buildBackToDashboardButton(context),

            const SizedBox(height: 12),

            // ─── 2. Page Header Bar & Global Actions ─────────────────────────
            _buildPageHeader(context, isCompact),

            const SizedBox(height: 16),

            // ─── 3. Section 1: Summary KPI Cards ─────────────────────────────
            _buildSectionHeader('Summary'),
            const SizedBox(height: 6),
            _buildSummaryKpiCards(isCompact),

            const SizedBox(height: 18),

            // ─── 4. Section 2: Expenses by Category Breakdown ────────────────
            _buildSectionHeader('Expenses by Category'),
            const SizedBox(height: 6),
            _buildExpensesByCategorySection(),

            const SizedBox(height: 18),

            // ─── 5. Section 3: Add / Edit Expense Form ───────────────────────
            _buildSectionHeader('Add / Edit Expense'),
            const SizedBox(height: 6),
            _buildAddEditExpenseForm(isCompact),

            const SizedBox(height: 18),

            // ─── 6. Section 4: Expense Register Table ────────────────────────
            _buildSectionHeader('Expense Register'),
            const SizedBox(height: 6),
            _buildExpenseRegisterTable(isCompact),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── 1. Back to Dashboard Button ───────────────────────────────────────────
  Widget _buildBackToDashboardButton(BuildContext context) {
    return InkWell(
      onTap: widget.onBackToDashboard ?? () => context.go('/dashboard'),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF22242B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF383C46), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Back to Sales Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. Page Header Bar ────────────────────────────────────────────────────
  Widget _buildPageHeader(BuildContext context, bool isCompact) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title: 💸 Expenses
        const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Expenses',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),

        const Spacer(),

        // [🔄 Refresh]
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 0,
          ),
          onPressed: _isLoading ? null : _handleRefresh,
          icon: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh, size: 15),
          label: const Text(
            'Refresh',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(width: 10),

        // [⬇ Download Excel]
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 0,
          ),
          onPressed: _handleDownloadExcel,
          icon: const Icon(Icons.download, size: 15),
          label: const Text(
            'Download Excel',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ─── Section Header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE57A38),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }

  // ─── Section 1: Summary KPI Cards ──────────────────────────────────────────
  Widget _buildSummaryKpiCards(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: isCompact
          ? Column(
              children: [
                _buildKpiCard('Total Expenses', _formatCurrency(_totalExpenses)),
                const SizedBox(height: 10),
                _buildKpiCard('This Month', _formatCurrency(_thisMonthExpenses)),
                const SizedBox(height: 10),
                _buildKpiCard('Top Category', _topCategory),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildKpiCard('Total Expenses', _formatCurrency(_totalExpenses))),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard('This Month', _formatCurrency(_thisMonthExpenses))),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard('Top Category', _topCategory)),
              ],
            ),
    );
  }

  Widget _buildKpiCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151619),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2A2D35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section 2: Expenses by Category Breakdown Strip ───────────────────────
  Widget _buildExpensesByCategorySection() {
    final breakdowns = _categoryBreakdowns;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: breakdowns.isEmpty
          ? const SizedBox(
              height: 48,
              child: Center(
                child: Text(
                  'No expense records available to aggregate.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: breakdowns.map((cat) {
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151619),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF2A2D35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                cat.category,
                                style: const TextStyle(
                                  color: Color(0xFFE2E4E9),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${cat.percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Color(0xFFF15A24),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(cat.subtotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (cat.percentage / 100).clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: const Color(0xFF2A2D35),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF15A24)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ─── Section 3: Add / Edit Expense Entry Form ──────────────────────────────
  Widget _buildAddEditExpenseForm(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: Column(
        children: [
          // Row 0: Date, Category, Amount (₹)
          Row(
            children: [
              // Date Picker
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Date:',
                  child: TextFormField(
                    controller: _dateCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Category Dropdown
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Category:',
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('exp-cat-$_selectedCategory'),
                    initialValue: _selectedCategory,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c,
                        child: Text(
                          c,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v ?? 'Other'),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Amount (₹)
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Amount (₹):',
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 1: Description, Payment Method, Paid To
          Row(
            children: [
              // Description
              Expanded(
                flex: 4,
                child: _buildFormField(
                  label: 'Description:',
                  child: TextFormField(
                    controller: _descCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Purpose or narrative details'),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Payment Method
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Payment Method:',
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('exp-pay-$_selectedPaymentMethod'),
                    initialValue: _selectedPaymentMethod,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _paymentMethods.map((m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Text(
                          m,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedPaymentMethod = v ?? 'Cash'),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Paid To
              Expanded(
                flex: 3,
                child: _buildFormField(
                  label: 'Paid To:',
                  child: TextFormField(
                    controller: _paidToCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Recipient / vendor / employee'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Notes & Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Notes
              Expanded(
                flex: 5,
                child: _buildFormField(
                  label: 'Notes:',
                  child: TextFormField(
                    controller: _notesCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Additional remarks / receipt #'),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Buttons: [Save] [Delete] [Clear]
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _saveExpense,
                icon: const Icon(Icons.save_outlined, size: 15),
                label: Text(
                  _selectedExpenseIndex != null ? 'Update' : 'Save',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _deleteExpense,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _clearForm,
                icon: const Icon(Icons.close, size: 15),
                label: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section 4: Expense Register Table (Treeview - 7 Columns) ───────────────
  Widget _buildExpenseRegisterTable(bool isCompact) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: Column(
        children: [
          // Table Header Row (7 Columns: Date, Category, Description, Amount, Payment Method, Paid To, Notes)
          Container(
            height: 38,
            color: const Color(0xFF151619),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 95,
                  child: InkWell(
                    onTap: () => _sortExpenses(0),
                    child: _buildSortableHeader('Date', 0),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _sortExpenses(1),
                    child: _buildSortableHeader('Category', 1),
                  ),
                ),
                const Expanded(flex: 3, child: _ColHeader('Description')),
                SizedBox(
                  width: 120,
                  child: InkWell(
                    onTap: () => _sortExpenses(2),
                    child: _buildSortableHeader('Amount (₹)', 2, align: TextAlign.right),
                  ),
                ),
                const Expanded(flex: 2, child: _ColHeader('Payment Method')),
                const Expanded(flex: 2, child: _ColHeader('Paid To')),
                const Expanded(flex: 2, child: _ColHeader('Notes')),
              ],
            ),
          ),

          // Table Rows
          _expenses.isEmpty
              ? Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: const Text(
                    'No expenses recorded yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _expenses.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFF26282E),
                  ),
                  itemBuilder: (context, index) {
                    final exp = _expenses[index];
                    final isSelected = _selectedExpenseIndex == index;

                    return InkWell(
                      onTap: () => _selectExpense(index),
                      child: Container(
                        height: 36,
                        color: isSelected
                            ? const Color(0xFF2C3240)
                            : (index.isEven ? Colors.transparent : const Color(0xFF1B1C20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 95,
                              child: Text(
                                exp.date,
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                exp.category,
                                style: const TextStyle(
                                  color: Color(0xFFF15A24),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                exp.description,
                                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                _formatCurrency(exp.amount),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                exp.paymentMethod,
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                exp.paidTo.isEmpty ? '—' : exp.paidTo,
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                exp.notes.isEmpty ? '—' : exp.notes,
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // ─── Shared UI Helpers ─────────────────────────────────────────────────────
  Widget _buildSortableHeader(String title, int colIndex, {TextAlign align = TextAlign.left}) {
    final isCurrent = _sortColumnIndex == colIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE2E4E9),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          isCurrent
              ? (_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
              : Icons.sort,
          size: 14,
          color: isCurrent ? const Color(0xFFF15A24) : Colors.white38,
        ),
      ],
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD0D3DA),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(height: 34, child: child),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      fillColor: const Color(0xFF131417),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF32353E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF32353E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFF15A24), width: 1.2),
      ),
    );
  }
}

// ─── Simple Column Header ─────────────────────────────────────────────────────
class _ColHeader extends StatelessWidget {
  final String title;
  const _ColHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE2E4E9),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
