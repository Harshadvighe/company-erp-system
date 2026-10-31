import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

/// Sales / Income Register Entry Model
class SalesIncomeEntry {
  final String id;
  final String date;
  final String customer;
  final String invoiceNo;
  final String productService;
  final double invoiceAmount;
  final double amountReceived;
  final double pendingAmount;
  final String notes;

  SalesIncomeEntry({
    required this.id,
    required this.date,
    required this.customer,
    required this.invoiceNo,
    required this.productService,
    required this.invoiceAmount,
    required this.amountReceived,
    required this.pendingAmount,
    required this.notes,
  });

  SalesIncomeEntry copyWith({
    String? id,
    String? date,
    String? customer,
    String? invoiceNo,
    String? productService,
    double? invoiceAmount,
    double? amountReceived,
    double? pendingAmount,
    String? notes,
  }) {
    return SalesIncomeEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      customer: customer ?? this.customer,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      productService: productService ?? this.productService,
      invoiceAmount: invoiceAmount ?? this.invoiceAmount,
      amountReceived: amountReceived ?? this.amountReceived,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      notes: notes ?? this.notes,
    );
  }
}

/// Sales and Invoice Workspace View
/// Matches the exact Company Management Software UI:
/// - "Back to Sales Dashboard" button
/// - "Sales / Income" title with Refresh & Download Excel buttons
/// - Summary (Total Invoiced, Total Received, Total Pending)
/// - Add / Edit Entry form (Date, Customer, Invoice No., Product / Service, Invoice Amount, Amount Received, Notes, Save, Delete, Clear)
/// - Sales / Income Register table (Date, Customer, Invoice No., Product / Service, Invoice Amount, Received, Pending, Notes)
class SaleInvoiceWorkspaceView extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;
  const SaleInvoiceWorkspaceView({super.key, this.onBackToDashboard});

  @override
  ConsumerState<SaleInvoiceWorkspaceView> createState() => _SaleInvoiceWorkspaceViewState();
}

class _SaleInvoiceWorkspaceViewState extends ConsumerState<SaleInvoiceWorkspaceView> {
  // ─── Form Controllers ──────────────────────────────────────────────────────
  late DateTime _selectedDate;
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _customerCtrl = TextEditingController();
  final TextEditingController _invoiceNoCtrl = TextEditingController();
  final TextEditingController _productServiceCtrl = TextEditingController();
  final TextEditingController _invoiceAmountCtrl = TextEditingController();
  final TextEditingController _amountReceivedCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // ─── State ─────────────────────────────────────────────────────────────────
  final List<SalesIncomeEntry> _entries = [];
  int? _selectedIndex;
  bool _isLoading = false;
  bool _isSaving = false;

  // Preset list of customers and products for quick dropdown selection
  final List<String> _suggestedCustomers = [
    'Win Win Engineering',
    'Revolve Engineers',
    'Kalyani Technoforge Ltd',
    'Saark Industrial Automation',
    'Apex Water Solutions',
    'Pinnacle Electro Systems',
  ];

  final List<String> _suggestedProducts = [
    'Booster Pump Control Panel',
    'STP Automation Panel',
    'Water Meter & Sensors',
    'Building Management System (BMS)',
    'VFD Motor Control Center (MCC)',
    'Dual Pump Auto Transfer Switch (ATS)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(2026, 10, 15);
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _invoiceNoCtrl.text = 'INV-2026-001';

    // Load initial invoices from backend if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _customerCtrl.dispose();
    _invoiceNoCtrl.dispose();
    _productServiceCtrl.dispose();
    _invoiceAmountCtrl.dispose();
    _amountReceivedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ─── Load Invoices from Backend ─────────────────────────────────────────────
  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final res = await repo.getInvoices(limit: 100);
      final dynamic raw = res['items'] ?? res['data']?['items'] ?? (res['data'] is List ? res['data'] : (res is List ? res : null));
      final items = (raw is List) ? raw : <dynamic>[];

      final loaded = <SalesIncomeEntry>[];
      for (final item in items) {
        final double invAmt = (item['grandTotal'] as num?)?.toDouble() ?? 0.0;
        final double recAmt = (item['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final double pendAmt = (item['balanceDue'] as num?)?.toDouble() ?? (invAmt - recAmt);

        final rawDate = item['invoiceDate']?.toString();
        String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (rawDate != null) {
          try {
            formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(rawDate));
          } catch (_) {}
        }

        final custName = item['customer']?['companyName']?.toString() ?? 'Customer';
        final itemsList = item['items'] as List<dynamic>? ?? [];
        final prodName = itemsList.isNotEmpty
            ? (itemsList[0]['description']?.toString() ?? 'Industrial Panel')
            : 'Automation Service';

        loaded.add(SalesIncomeEntry(
          id: item['id']?.toString() ?? UniqueKey().toString(),
          date: formattedDate,
          customer: custName,
          invoiceNo: item['invoiceNumber']?.toString() ?? '',
          productService: prodName,
          invoiceAmount: invAmt,
          amountReceived: recAmt,
          pendingAmount: pendAmt,
          notes: item['notes']?.toString() ?? '',
        ));
      }

      setState(() {
        _entries.clear();
        _entries.addAll(loaded);
        _isLoading = false;
      });
    } catch (_) {
      // Backend not running or error, keep state clean
      setState(() => _isLoading = false);
    }
  }

  // ─── Summary Totals ────────────────────────────────────────────────────────
  double get _totalInvoiced => _entries.fold(0.0, (sum, it) => sum + it.invoiceAmount);
  double get _totalReceived => _entries.fold(0.0, (sum, it) => sum + it.amountReceived);
  double get _totalPending => _entries.fold(0.0, (sum, it) => sum + it.pendingAmount);

  // ─── Select Row from Register ──────────────────────────────────────────────
  void _selectEntry(int index) {
    setState(() {
      _selectedIndex = index;
      final item = _entries[index];
      _dateCtrl.text = item.date;
      try {
        _selectedDate = DateTime.parse(item.date);
      } catch (_) {}
      _customerCtrl.text = item.customer;
      _invoiceNoCtrl.text = item.invoiceNo;
      _productServiceCtrl.text = item.productService;
      _invoiceAmountCtrl.text = item.invoiceAmount.toStringAsFixed(2);
      _amountReceivedCtrl.text = item.amountReceived.toStringAsFixed(2);
      _notesCtrl.text = item.notes;
    });
  }

  // ─── Save / Update Entry ───────────────────────────────────────────────────
  Future<void> _handleSave() async {
    final customer = _customerCtrl.text.trim();
    final invoiceNo = _invoiceNoCtrl.text.trim();
    final product = _productServiceCtrl.text.trim();
    final dateStr = _dateCtrl.text.trim();
    final double invAmount = double.tryParse(_invoiceAmountCtrl.text.trim()) ?? 0.0;
    final double recAmount = double.tryParse(_amountReceivedCtrl.text.trim()) ?? 0.0;
    final double pendAmount = (invAmount - recAmount) > 0 ? (invAmount - recAmount) : 0.0;
    final notes = _notesCtrl.text.trim();

    if (customer.isEmpty && invoiceNo.isEmpty && invAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter customer, invoice number and amount.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(salesRepositoryProvider);

      if (_selectedIndex != null && _selectedIndex! < _entries.length) {
        // Updating existing entry
        final current = _entries[_selectedIndex!];
        final updated = current.copyWith(
          date: dateStr,
          customer: customer.isNotEmpty ? customer : current.customer,
          invoiceNo: invoiceNo.isNotEmpty ? invoiceNo : current.invoiceNo,
          productService: product.isNotEmpty ? product : current.productService,
          invoiceAmount: invAmount,
          amountReceived: recAmount,
          pendingAmount: pendAmount,
          notes: notes,
        );

        // Update on backend if connected
        try {
          await repo.updateInvoice(current.id, {
            'invoiceNumber': updated.invoiceNo,
            'invoiceDate': updated.date,
            'grandTotal': updated.invoiceAmount,
            'paidAmount': updated.amountReceived,
            'notes': updated.notes,
          });
        } catch (_) {}

        setState(() {
          _entries[_selectedIndex!] = updated;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice ${updated.invoiceNo} updated successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        // Adding new entry
        final newEntry = SalesIncomeEntry(
          id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
          date: dateStr,
          customer: customer.isNotEmpty ? customer : 'Win Win Engineering',
          invoiceNo: invoiceNo.isNotEmpty ? invoiceNo : 'INV-${DateTime.now().year}-${_entries.length + 101}',
          productService: product.isNotEmpty ? product : 'Booster Pump Control Panel',
          invoiceAmount: invAmount,
          amountReceived: recAmount,
          pendingAmount: pendAmount,
          notes: notes,
        );

        // Save to backend if connected
        try {
          await repo.createInvoice({
            'invoiceNumber': newEntry.invoiceNo,
            'customerName': newEntry.customer,
            'invoiceDate': newEntry.date,
            'grandTotal': newEntry.invoiceAmount,
            'paidAmount': newEntry.amountReceived,
            'notes': newEntry.notes,
            'items': [
              {
                'description': newEntry.productService,
                'quantity': 1,
                'unitPrice': newEntry.invoiceAmount,
                'gstPercent': 18.0,
              }
            ],
          });
        } catch (_) {}

        setState(() {
          _entries.insert(0, newEntry);
          _selectedIndex = 0;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New Invoice ${newEntry.invoiceNo} registered successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally: $e'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // ─── Delete Entry ──────────────────────────────────────────────────────────
  Future<void> _handleDelete() async {
    if (_selectedIndex == null || _selectedIndex! >= _entries.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an invoice entry from the register to delete.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final entryToDelete = _entries[_selectedIndex!];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222428),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Text('Delete Invoice Entry', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete invoice "${entryToDelete.invoiceNo}" for "${entryToDelete.customer}"?',
          style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF15A24)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(salesRepositoryProvider);
        await repo.deleteInvoice(entryToDelete.id);
      } catch (_) {}

      setState(() {
        _entries.removeAt(_selectedIndex!);
        _selectedIndex = null;
        _handleClear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice ${entryToDelete.invoiceNo} deleted.'),
            backgroundColor: const Color(0xFFF15A24),
          ),
        );
      }
    }
  }

  // ─── Clear Form ────────────────────────────────────────────────────────────
  void _handleClear() {
    setState(() {
      _selectedIndex = null;
      _selectedDate = DateTime(2026, 10, 15);
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _customerCtrl.clear();
      _invoiceNoCtrl.text = 'INV-2026-${_entries.length + 101}';
      _productServiceCtrl.clear();
      _invoiceAmountCtrl.clear();
      _amountReceivedCtrl.clear();
      _notesCtrl.clear();
    });
  }

  // ─── Download Excel ────────────────────────────────────────────────────────
  void _downloadExcel() {
    final buffer = StringBuffer();
    buffer.writeln('<html xmlns:x="urn:schemas-microsoft-com:office:excel">');
    buffer.writeln('<head><meta charset="utf-8"></head><body>');
    buffer.writeln('<h2>SAARK EXPLORATION PRIVATE LIMITED</h2>');
    buffer.writeln('<h3>Sales / Income Register (F.Y. 2026-2027)</h3>');
    buffer.writeln('<p>Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}</p>');

    buffer.writeln('<table border="1">');
    buffer.writeln('<tr style="background-color: #F15A24; color: white; font-weight: bold;">');
    buffer.writeln('<th>Date</th>');
    buffer.writeln('<th>Customer</th>');
    buffer.writeln('<th>Invoice No.</th>');
    buffer.writeln('<th>Product / Service</th>');
    buffer.writeln('<th>Invoice Amount (₹)</th>');
    buffer.writeln('<th>Received (₹)</th>');
    buffer.writeln('<th>Pending (₹)</th>');
    buffer.writeln('<th>Notes</th>');
    buffer.writeln('</tr>');

    for (final it in _entries) {
      buffer.writeln('<tr>');
      buffer.writeln('<td>${_escapeHtml(it.date)}</td>');
      buffer.writeln('<td>${_escapeHtml(it.customer)}</td>');
      buffer.writeln('<td>${_escapeHtml(it.invoiceNo)}</td>');
      buffer.writeln('<td>${_escapeHtml(it.productService)}</td>');
      buffer.writeln('<td>${it.invoiceAmount.toStringAsFixed(2)}</td>');
      buffer.writeln('<td>${it.amountReceived.toStringAsFixed(2)}</td>');
      buffer.writeln('<td>${it.pendingAmount.toStringAsFixed(2)}</td>');
      buffer.writeln('<td>${_escapeHtml(it.notes)}</td>');
      buffer.writeln('</tr>');
    }

    // Totals row
    buffer.writeln('<tr style="background-color: #24272D; font-weight: bold;">');
    buffer.writeln('<td colspan="4" style="text-align: right;">Total:</td>');
    buffer.writeln('<td>${_totalInvoiced.toStringAsFixed(2)}</td>');
    buffer.writeln('<td>${_totalReceived.toStringAsFixed(2)}</td>');
    buffer.writeln('<td>${_totalPending.toStringAsFixed(2)}</td>');
    buffer.writeln('<td></td>');
    buffer.writeln('</tr>');

    buffer.writeln('</table></body></html>');

    downloadExcelFile(buffer.toString(), 'saark_sales_income_register_2026_2027.xls');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sales / Income register exported to Excel successfully!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  // ─── Pick Date Helper ──────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF15A24),
              onPrimary: Colors.white,
              surface: Color(0xFF222428),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 900;

    return Container(
      color: const Color(0xFF191A1E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Top Action: Back to Sales Dashboard ──────────────────────
            _buildBackToDashboardButton(context),

            const SizedBox(height: 12),

            // ─── 2. Title Row: Sales / Income + Refresh + Download Excel ─────
            _buildTitleAndActionsRow(isCompact),

            const SizedBox(height: 14),

            // ─── 3. Summary Panel (Total Invoiced, Total Received, Total Pending)
            _buildSummarySection(isCompact),

            const SizedBox(height: 14),

            // ─── 4. Add / Edit Entry Form ────────────────────────────────────
            _buildAddEditEntrySection(isCompact),

            const SizedBox(height: 14),

            // ─── 5. Sales / Income Register Table ────────────────────────────
            _buildRegisterTableSection(isCompact),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── 1. Back to Sales Dashboard Button ─────────────────────────────────────
  Widget _buildBackToDashboardButton(BuildContext context) {
    return InkWell(
      onTap: widget.onBackToDashboard ?? () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/sales-marketing');
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF222428),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF4E515A), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.crop_square_outlined, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Icon(Icons.arrow_back, color: Colors.white, size: 13),
            SizedBox(width: 6),
            Text(
              'Back to Sales Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. Title Row (Sales / Income with Refresh & Download Excel) ───────────
  Widget _buildTitleAndActionsRow(bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Title
        const Row(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Sales / Income',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),

        // Right Actions (Refresh & Download Excel)
        Row(
          children: [
            // Refresh Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadInvoices,
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh, size: 15, color: Colors.white),
              label: const Text(
                'Refresh',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF15A24),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),

            const SizedBox(width: 8),

            // Download Excel Button
            ElevatedButton.icon(
              onPressed: _downloadExcel,
              icon: const Icon(Icons.download_rounded, size: 15, color: Colors.white),
              label: const Text(
                'Download Excel',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF15A24),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 3. Summary Section ────────────────────────────────────────────────────
  Widget _buildSummarySection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(
            color: Color(0xFFE57A38),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2025),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
          ),
          padding: const EdgeInsets.all(12),
          child: isCompact
              ? Column(
                  children: [
                    _buildMetricBox('Total Invoiced', _totalInvoiced),
                    const SizedBox(height: 8),
                    _buildMetricBox('Total Received', _totalReceived),
                    const SizedBox(height: 8),
                    _buildMetricBox('Total Pending', _totalPending),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildMetricBox('Total Invoiced', _totalInvoiced)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricBox('Total Received', _totalReceived)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricBox('Total Pending', _totalPending)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String label, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF2B2E35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E9297),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. Add / Edit Entry Section ───────────────────────────────────────────
  Widget _buildAddEditEntrySection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add / Edit Entry',
          style: TextStyle(
            color: Color(0xFFE57A38),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2025),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Date, Customer, Invoice No.
              if (isCompact) ...[
                _buildDateField('Date:'),
                const SizedBox(height: 10),
                _buildCustomerField('Customer:'),
                const SizedBox(height: 10),
                _buildLabeledTextField('Invoice No.:', _invoiceNoCtrl),
              ] else ...[
                Row(
                  children: [
                    SizedBox(width: 200, child: _buildDateField('Date:')),
                    const SizedBox(width: 14),
                    Expanded(child: _buildCustomerField('Customer:')),
                    const SizedBox(width: 14),
                    Expanded(child: _buildLabeledTextField('Invoice No.:', _invoiceNoCtrl)),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Row 2: Product / Service, Invoice Amount (₹), Amount Received (₹)
              if (isCompact) ...[
                _buildProductField('Product / Service:'),
                const SizedBox(height: 10),
                _buildLabeledTextField('Invoice Amount (₹):', _invoiceAmountCtrl, isNumber: true),
                const SizedBox(height: 10),
                _buildLabeledTextField('Amount Received (₹):', _amountReceivedCtrl, isNumber: true),
              ] else ...[
                Row(
                  children: [
                    Expanded(flex: 3, child: _buildProductField('Product / Service:')),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: _buildLabeledTextField('Invoice Amount (₹):', _invoiceAmountCtrl, isNumber: true),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: _buildLabeledTextField('Amount Received (₹):', _amountReceivedCtrl, isNumber: true),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Row 3: Notes + Action Buttons (Save, Delete, Clear)
              if (isCompact) ...[
                _buildLabeledTextField('Notes:', _notesCtrl),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildFormButtons(),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildLabeledTextField('Notes:', _notesCtrl)),
                    const SizedBox(width: 20),
                    Row(children: _buildFormButtons()),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFormButtons() {
    return [
      // Save Button
      ElevatedButton.icon(
        onPressed: _isSaving ? null : _handleSave,
        icon: _isSaving
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_outlined, size: 14, color: Colors.white),
        label: Text(
          _selectedIndex != null ? 'Save' : 'Save',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF15A24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),

      const SizedBox(width: 8),

      // Delete Button
      ElevatedButton.icon(
        onPressed: _handleDelete,
        icon: const Icon(Icons.delete_outline, size: 14, color: Colors.white),
        label: const Text(
          'Delete',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF15A24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),

      const SizedBox(width: 8),

      // Clear Button
      ElevatedButton.icon(
        onPressed: _handleClear,
        icon: const Icon(Icons.clear, size: 14, color: Colors.white),
        label: const Text(
          'Clear',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF15A24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    ];
  }

  // ─── Input Field Widgets (Matching Screenshot Style) ───────────────────────
  Widget _buildDateField(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: InkWell(
            onTap: _pickDate,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141518),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF33363D), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _dateCtrl.text,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerField(String label) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF141518),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF33363D), width: 1),
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Select Customer',
              offset: const Offset(0, 32),
              color: const Color(0xFF222428),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onSelected: (val) => setState(() => _customerCtrl.text = val),
              itemBuilder: (context) => _suggestedCustomers
                  .map(
                    (c) => PopupMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customerCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: '',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductField(String label) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF141518),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF33363D), width: 1),
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Select Product / Service',
              offset: const Offset(0, 32),
              color: const Color(0xFF222428),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onSelected: (val) => setState(() => _productServiceCtrl.text = val),
              itemBuilder: (context) => _suggestedProducts
                  .map(
                    (p) => PopupMenuItem(
                      value: p,
                      child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _productServiceCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: '',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141518),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF33363D), width: 1),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              keyboardType: isNumber
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 5. Sales / Income Register Table Section ──────────────────────────────
  Widget _buildRegisterTableSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sales / Income Register',
          style: TextStyle(
            color: Color(0xFFE57A38),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 280),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2025),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
          ),
          child: Column(
            children: [
              // Table Header Row
              Container(
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF16171A),
                  border: Border(bottom: BorderSide(color: Color(0xFF2B2D33), width: 1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: const Row(
                  children: [
                    SizedBox(width: 90, child: _TableHeaderText('Date')),
                    Expanded(flex: 2, child: _TableHeaderText('Customer')),
                    Expanded(flex: 2, child: _TableHeaderText('Invoice No.')),
                    Expanded(flex: 3, child: _TableHeaderText('Product / Service')),
                    Expanded(flex: 2, child: _TableHeaderText('Invoice Amount')),
                    Expanded(flex: 2, child: _TableHeaderText('Received')),
                    Expanded(flex: 2, child: _TableHeaderText('Pending')),
                    Expanded(flex: 3, child: _TableHeaderText('Notes')),
                  ],
                ),
              ),

              // Table Body (Rows or Empty Canvas)
              if (_entries.isEmpty)
                Container(
                  height: 240,
                  alignment: Alignment.center,
                  child: const Text(
                    'No sales invoice entries found. Add an entry above to populate register.',
                    style: TextStyle(color: Color(0xFF6F747E), fontSize: 12),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _entries.length,
                  separatorBuilder: (ctx, i) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFF26282E),
                  ),
                  itemBuilder: (ctx, index) {
                    final item = _entries[index];
                    final isSelected = _selectedIndex == index;

                    return InkWell(
                      onTap: () => _selectEntry(index),
                      child: Container(
                        height: 36,
                        color: isSelected
                            ? const Color(0xFF2A2D35)
                            : (index % 2 == 0 ? const Color(0xFF1E2025) : const Color(0xFF191B1F)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                item.date,
                                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.customer,
                                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.invoiceNo,
                                style: const TextStyle(
                                  color: Color(0xFF58A6FF),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.productService,
                                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₹${item.invoiceAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₹${item.amountReceived.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₹${item.pendingAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: item.pendingAmount > 0
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFF8E9297),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.notes,
                                style: const TextStyle(color: Color(0xFFB0B3B8), fontSize: 11.5),
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
        ),
      ],
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  final String text;
  const _TableHeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFE2E4E9),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
