import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';

class InvoicesListPage extends ConsumerStatefulWidget {
  const InvoicesListPage({super.key});

  @override
  ConsumerState<InvoicesListPage> createState() => _InvoicesListPageState();
}

class _InvoicesListPageState extends ConsumerState<InvoicesListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  final _statusFilters = ['ALL', 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'OVERDUE'];

  List<dynamic> _invoices = [];
  bool _isLoading = false;
  String? _error;
  double _totalInvoiced = 0;
  double _totalCollected = 0;
  double _totalOutstanding = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadInvoices();
      }
    });
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final selectedStatus = _statusFilters[_tabController.index];
      final repo = ref.read(salesRepositoryProvider);
      final res = await repo.getInvoices(
        paymentStatus: selectedStatus == 'ALL' ? null : selectedStatus,
        search: _searchController.text.trim(),
      );

      final items = res['items'] as List<dynamic>? ?? [];

      double invoiced = 0;
      double collected = 0;
      double outstanding = 0;

      for (final item in items) {
        invoiced += (item['grandTotal'] as num?)?.toDouble() ?? 0;
        collected += (item['paidAmount'] as num?)?.toDouble() ?? 0;
        outstanding += (item['balanceDue'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _invoices = items;
        _totalInvoiced = invoiced;
        _totalCollected = collected;
        _totalOutstanding = outstanding;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PARTIALLY_PAID':
        return Colors.orange;
      case 'UNPAID':
        return Colors.blueGrey;
      case 'OVERDUE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _openRecordPaymentDialog(Map<String, dynamic> invoice) {
    final amountController = TextEditingController(text: (invoice['balanceDue'] ?? 0).toString());
    final refController = TextEditingController();
    final bankController = TextEditingController(text: 'HDFC Bank');
    final notesController = TextEditingController();
    String paymentMode = 'NEFT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payment, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Customer Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    'Against Invoice ${invoice['invoiceNumber']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Invoice Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('₹${(invoice['grandTotal'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Already Paid', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('₹${(invoice['paidAmount'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Balance Due', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('₹${(invoice['balanceDue'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Received Amount (₹) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Payment Mode *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NEFT', child: Text('NEFT / RTGS Bank Transfer')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI / QR Code')),
                      DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque / Demand Draft')),
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    ],
                    onChanged: (val) => setDialogState(() => paymentMode = val ?? 'NEFT'),
                  ),
                  const SizedBox(height: 14),
                  const Text('UTR / Cheque / Transaction Ref #', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: refController,
                    decoration: InputDecoration(
                      hintText: 'e.g. UTR12345678 or CHQ987654',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Bank Account / Deposited In', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: bankController,
                    decoration: InputDecoration(
                      hintText: 'e.g. HDFC Bank Current A/c',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Notes / Remarks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Payment receipt notes...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Confirm Receipt'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid amount')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final repo = ref.read(salesRepositoryProvider);
                  await repo.recordPayment(invoice['id'], {
                    'amount': amt,
                    'paymentMode': paymentMode,
                    'referenceNumber': refController.text.trim(),
                    'bankName': bankController.text.trim(),
                    'notes': notesController.text.trim(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully!')));
                    _loadInvoices();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record payment: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateInvoiceDialog() async {
    final customersRepo = ref.read(customersRepositoryProvider);
    final salesRepo = ref.read(salesRepositoryProvider);

    final customersRes = await customersRepo.getCustomers(limit: 100);
    final customersList = customersRes['items'] as List<dynamic>? ?? [];

    final ordersRes = await salesRepo.getSalesOrders(limit: 50);
    final ordersList = ordersRes['items'] as List<dynamic>? ?? [];

    if (!mounted) return;

    String? selectedCustomerId;
    String? selectedOrderId;
    final poController = TextEditingController();
    final ewayController = TextEditingController();
    final itemDescController = TextEditingController(text: 'Custom Industrial Control Panel');
    final itemQtyController = TextEditingController(text: '1');
    final itemRateController = TextEditingController(text: '150000');
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Text('Generate Commercial Tax Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ordersList.isNotEmpty) ...[
                    const Text('Link from Confirmed Sales Order (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedOrderId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Select Sales Order to auto-fill',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('None (Direct Invoice)')),
                        ...ordersList.map((o) => DropdownMenuItem<String>(
                          value: o['id'],
                          child: Text('${o['orderNumber']} - ${o['customer']?['companyName'] ?? ''} (₹${(o['grandTotal'] ?? 0).toStringAsFixed(0)})'),
                        )),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedOrderId = val;
                          if (val != null) {
                            final match = ordersList.firstWhere((o) => o['id'] == val, orElse: () => null);
                            if (match != null) {
                              selectedCustomerId = match['customer']?['id'];
                              poController.text = match['poNumber'] ?? '';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Company / Customer *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCustomerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Select Customer',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: customersList.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem<String>(
                        value: c['id']?.toString(),
                        child: Text('${c['companyName'] ?? 'Unknown'} (${c['customerCode'] ?? 'CUS'})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedCustomerId = val),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Customer PO #', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: poController,
                              decoration: InputDecoration(
                                hintText: 'e.g. PO/2026/894',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('E-Way Bill #', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: ewayController,
                              decoration: InputDecoration(
                                hintText: 'e.g. 241089345671',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Product / Line Item Description *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: itemDescController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 15 HP Dual Pump VFD Panel (HSN 8537)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: itemQtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unit Rate (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: itemRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Invoice Notes & Dispatch Terms', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Delivery terms, bank instructions...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Generate Invoice'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedCustomerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select customer')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final qty = int.tryParse(itemQtyController.text.trim()) ?? 1;
                  final rate = double.tryParse(itemRateController.text.trim()) ?? 0;

                  if (selectedOrderId != null) {
                    await salesRepo.createInvoiceFromSalesOrder(selectedOrderId!, {
                      'ewayBillNumber': ewayController.text.trim(),
                      'notes': notesController.text.trim(),
                    });
                  } else {
                    await salesRepo.createInvoice({
                      'customerId': selectedCustomerId,
                      'poNumber': poController.text.trim(),
                      'ewayBillNumber': ewayController.text.trim(),
                      'notes': notesController.text.trim(),
                      'items': [
                        {
                          'description': itemDescController.text.trim(),
                          'quantity': qty,
                          'unitPrice': rate,
                          'gstPercent': 18.0,
                        },
                      ],
                    });
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tax Invoice generated successfully!')));
                    _loadInvoices();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate invoice: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Commercial Invoices & Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadInvoices,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Generate Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: _openCreateInvoiceDialog,
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          isScrollable: true,
          tabs: _statusFilters.map((s) => Tab(text: s.replaceAll('_', ' '))).toList(),
        ),
      ),
      body: Column(
        children: [
          _buildMetricsHeader(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildMetricsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          _buildMetricBadge('Total Invoiced', '₹${_totalInvoiced.toStringAsFixed(0)}', Icons.receipt_long, Colors.blue),
          const SizedBox(width: 16),
          _buildMetricBadge('Collections Received', '₹${_totalCollected.toStringAsFixed(0)}', Icons.check_circle_outline, Colors.green),
          const SizedBox(width: 16),
          _buildMetricBadge('Outstanding Balance', '₹${_totalOutstanding.toStringAsFixed(0)}', Icons.pending_actions, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      color: AppTheme.darkSurface,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search invoices by INV #, customer, PO #, or E-Way Bill #...',
          prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.darkTextSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppTheme.darkTextSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _loadInvoices();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onSubmitted: (_) => _loadInvoices(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadInvoices, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No commercial invoices found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Text('Generate tax invoices directly from confirmed sales orders.', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Generate First Invoice'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: _openCreateInvoiceDialog,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index] as Map<String, dynamic>;
        return _buildInvoiceCard(inv);
      },
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final customer = inv['customer'] as Map<String, dynamic>? ?? {};
    final salesOrder = inv['salesOrder'] as Map<String, dynamic>?;
    final payments = inv['payments'] as List<dynamic>? ?? [];

    final invoiceNumber = inv['invoiceNumber'] ?? 'INV';
    final customerName = customer['companyName'] ?? 'Direct Customer';
    final grandTotal = (inv['grandTotal'] as num?)?.toDouble() ?? 0;
    final paidAmount = (inv['paidAmount'] as num?)?.toDouble() ?? 0;
    final balanceDue = (inv['balanceDue'] as num?)?.toDouble() ?? 0;
    final paymentStatus = inv['paymentStatus'] ?? 'UNPAID';
    final statusColor = _getPaymentStatusColor(paymentStatus);

    DateTime? invoiceDate;
    if (inv['invoiceDate'] != null) invoiceDate = DateTime.tryParse(inv['invoiceDate'].toString());

    DateTime? dueDate;
    if (inv['dueDate'] != null) dueDate = DateTime.tryParse(inv['dueDate'].toString());
    final isOverdue = balanceDue > 0 && dueDate != null && dueDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          if (inv['financialYear'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text('FY ${inv['financialYear']}', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isOverdue ? Colors.red : statusColor).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: (isOverdue ? Colors.red : statusColor).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              isOverdue ? 'OVERDUE' : paymentStatus.replaceAll('_', ' '),
                              style: TextStyle(color: isOverdue ? Colors.red : statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(customerName, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invoice Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(invoiceDate != null ? DateFormat('dd MMM yyyy').format(invoiceDate) : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Due Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      dueDate != null ? DateFormat('dd MMM yyyy').format(dueDate) : '-',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isOverdue ? Colors.red : null),
                    ),
                  ],
                ),
                if (salesOrder != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sales Order', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(salesOrder['orderNumber'] ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total (incl. GST)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Payment progress bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Collected: ₹${paidAmount.toStringAsFixed(2)} (${payments.length} receipts)', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                      Text('Balance Due: ₹${balanceDue.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: balanceDue > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: grandTotal > 0 ? (paidAmount / grandTotal).clamp(0.0, 1.0) : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(balanceDue == 0 ? Colors.green : Colors.orange),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (customer['id'] != null)
                  TextButton.icon(
                    icon: const Icon(Icons.business, size: 16),
                    label: const Text('Customer 360'),
                    onPressed: () => context.go('/customers/${customer['id']}'),
                  ),
                const SizedBox(width: 8),
                if (balanceDue > 0)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('Record Payment'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => _openRecordPaymentDialog(inv),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
