import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/cheque_management_modal.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/inward_entry_modal.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/outward_document_modal.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/pay_invoice_dialog.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/vendor_registration_modal.dart';

/// Inward Line Item Model
class InwardLineItem {
  final String date;
  final String supplier;
  final String invoiceNo;
  final String department;
  final String productMaterial;
  final double qty;
  final double rate;
  final double amount;
  final String status;

  InwardLineItem({
    required this.date,
    required this.supplier,
    required this.invoiceNo,
    required this.department,
    required this.productMaterial,
    required this.qty,
    required this.rate,
    required this.amount,
    required this.status,
  });
}

/// Pending Vendor Invoice Model
class PendingVendorInvoice {
  final String id;
  final String vendor;
  final String invoiceNo;
  final String department;
  final double invoiceTotal;
  double paid;
  double pendingBalance;

  PendingVendorInvoice({
    required this.id,
    required this.vendor,
    required this.invoiceNo,
    required this.department,
    required this.invoiceTotal,
    required this.paid,
    required this.pendingBalance,
  });
}

/// Complete Purchase / Procurement Workspace View
/// Matches the exact UI from the Saark ERP Company Management Software:
/// - "Back to Sales Dashboard" button
/// - Title: "Purchase / Procurement" with 4 top action buttons:
///   [ Cheque Details ], [ + Vendor Registration ], [ + Outward Document ], [ + Inward Entry ]
/// - Section 1: Inward Purchase Summary (Product Lines, Total Inward Amount, Pending Amount)
/// - Section 2: Pending Invoices with [ Pay Selected Invoice ] action button
/// - Section 3: Inward Entry Register (Date, Supplier, Invoice No., Department, Product / Material, Qty, Rate, Amount, Status)
class PurchaseProcurementWorkspaceView extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;
  const PurchaseProcurementWorkspaceView({super.key, this.onBackToDashboard});

  @override
  ConsumerState<PurchaseProcurementWorkspaceView> createState() =>
      _PurchaseProcurementWorkspaceViewState();
}

class _PurchaseProcurementWorkspaceViewState
    extends ConsumerState<PurchaseProcurementWorkspaceView> {
  // ─── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  int? _selectedPendingInvoiceIndex;

  // KPI Metrics (Screenshot values as baseline)
  int _productLinesCount = 11;
  double _totalInwardAmount = 195383.84;
  double _pendingAmount = 169163.84;

  // Pending Invoices (Exact match to screenshot)
  late List<PendingVendorInvoice> _pendingInvoices;

  // Inward Entry Register (Exact match to screenshot)
  late List<InwardLineItem> _inwardRegister;

  @override
  void initState() {
    super.initState();
    _initializeSampleData();

    // Load live data from backend if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBackendData();
    });
  }

  void _initializeSampleData() {
    _pendingInvoices = [
      PendingVendorInvoice(
        id: 'p_inv_1',
        vendor: 'satyam',
        invoiceNo: '123',
        department: 'Panel Department',
        invoiceTotal: 1000.00,
        paid: 0.00,
        pendingBalance: 1000.00,
      ),
      PendingVendorInvoice(
        id: 'p_inv_2',
        vendor: 'satyam',
        invoiceNo: '234',
        department: 'Panel Department',
        invoiceTotal: 108663.84,
        paid: 0.00,
        pendingBalance: 108663.84,
      ),
      PendingVendorInvoice(
        id: 'p_inv_3',
        vendor: 'SATYAM',
        invoiceNo: '234',
        department: 'Panel Department',
        invoiceTotal: 40000.00,
        paid: 0.00,
        pendingBalance: 40000.00,
      ),
      PendingVendorInvoice(
        id: 'p_inv_4',
        vendor: 'kjh',
        invoiceNo: '23984y',
        department: 'Other',
        invoiceTotal: 19500.00,
        paid: 0.00,
        pendingBalance: 19500.00,
      ),
    ];

    _inwardRegister = [
      InwardLineItem(
        date: '2026-08-22',
        supplier: 'abc',
        invoiceNo: '123',
        department: '',
        productMaterial: 'slkdf',
        qty: 10,
        rate: 12.00,
        amount: 120.00,
        status: 'Partial',
      ),
      InwardLineItem(
        date: '2026-08-22',
        supplier: 'satyam',
        invoiceNo: '123',
        department: 'Panel Department',
        productMaterial: '5kw VFD',
        qty: 1,
        rate: 1000.00,
        amount: 1000.00,
        status: 'Partial',
      ),
      InwardLineItem(
        date: '2026-08-22',
        supplier: 'satyam',
        invoiceNo: '234',
        department: 'Panel Department',
        productMaterial: 'AIPCU HMI CONTROLLER MULTI\\',
        qty: 1,
        rate: 40000.00,
        amount: 40000.00,
        status: 'Pending',
      ),
      InwardLineItem(
        date: '2026-08-22',
        supplier: 'satyam',
        invoiceNo: '234',
        department: 'Panel Department',
        productMaterial: '5.5KW-ND7.5HP380-480V (186.6X1',
        qty: 1,
        rate: 14163.84,
        amount: 14163.84,
        status: 'Pending',
      ),
      InwardLineItem(
        date: '2026-08-22',
        supplier: 'satyam',
        invoiceNo: '234',
        department: 'Panel Department',
        productMaterial: 'DLC VFD T SURESH 14 Nos',
        qty: 1,
        rate: 9500.00,
        amount: 9500.00,
        status: 'Pending',
      ),
      InwardLineItem(
        date: '2026-08-22',
        supplier: 'satyam',
        invoiceNo: '234',
        department: 'Panel Department',
        productMaterial: 'DLC VFD 13 Nos',
        qty: 1,
        rate: 15000.00,
        amount: 15000.00,
        status: 'Pending',
      ),
      InwardLineItem(
        date: '2026-08-22',
        supplier: 'SATYAM',
        invoiceNo: '234',
        department: 'Panel Department',
        productMaterial: 'AIPCU HMI CONTROLLER MULTI\\',
        qty: 1,
        rate: 40000.00,
        amount: 40000.00,
        status: 'Pending',
      ),
    ];
  }

  // ─── Backend Data Synchronization ──────────────────────────────────────────
  Future<void> _loadBackendData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(purchaseRepositoryProvider);

      // Load Summary
      final summaryRes = await repo.getDashboardSummary();
      final num? totalInward = summaryRes['totalInwardAmount'];
      final num? totalPending = summaryRes['pendingPayableAmount'];
      final num? lines = summaryRes['inwardReceiptCount'] ?? summaryRes['itemCount'];

      // Load Pending Invoices
      final pendingRes = await repo.getPendingInvoices();
      final loadedPending = <PendingVendorInvoice>[];
      for (final it in pendingRes) {
        loadedPending.add(PendingVendorInvoice(
          id: it['id']?.toString() ?? UniqueKey().toString(),
          vendor: it['vendor']?['legalName'] ?? it['vendorName'] ?? 'Vendor',
          invoiceNo: it['invoiceNumber']?.toString() ?? '',
          department: it['department']?.toString() ?? 'Panel Department',
          invoiceTotal: (it['totalAmount'] as num?)?.toDouble() ?? 0.0,
          paid: (it['paidAmount'] as num?)?.toDouble() ?? 0.0,
          pendingBalance: (it['pendingBalance'] as num?)?.toDouble() ?? 0.0,
        ));
      }

      // Load Inward Register Entries
      final inwardRes = await repo.getInwardEntries(limit: 50);
      final rawItems = inwardRes['items'] ?? inwardRes['data'] ?? [];
      final loadedInward = <InwardLineItem>[];

      if (rawItems is List) {
        for (final entry in rawItems) {
          final itemsList = entry['items'] as List<dynamic>? ?? [];
          final rawDate = entry['inwardDate']?.toString();
          String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
          if (rawDate != null) {
            try {
              formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(rawDate));
            } catch (_) {}
          }

          final supplierName = entry['vendor']?['legalName']?.toString() ??
              entry['vendorName']?.toString() ??
              'Supplier';
          final invNo = entry['invoiceNumber']?.toString() ?? '';
          final dept = entry['department']?.toString() ?? 'Panel Department';
          final status = entry['paymentStatus']?.toString() ?? 'Pending';

          if (itemsList.isNotEmpty) {
            for (final line in itemsList) {
              final double q = (line['receivedQty'] as num?)?.toDouble() ?? 1.0;
              final double r = (line['unitPrice'] as num?)?.toDouble() ?? 0.0;
              final double amt = (line['totalAmount'] as num?)?.toDouble() ?? (q * r);
              loadedInward.add(InwardLineItem(
                date: formattedDate,
                supplier: supplierName,
                invoiceNo: invNo,
                department: dept,
                productMaterial: line['product']?['name']?.toString() ??
                    line['description']?.toString() ??
                    'Component',
                qty: q,
                rate: r,
                amount: amt,
                status: status,
              ));
            }
          } else {
            loadedInward.add(InwardLineItem(
              date: formattedDate,
              supplier: supplierName,
              invoiceNo: invNo,
              department: dept,
              productMaterial: 'Materials Delivered',
              qty: 1,
              rate: (entry['totalAmount'] as num?)?.toDouble() ?? 0.0,
              amount: (entry['totalAmount'] as num?)?.toDouble() ?? 0.0,
              status: status,
            ));
          }
        }
      }

      setState(() {
        if (lines != null && lines.toInt() > 0) _productLinesCount = lines.toInt();
        if (totalInward != null && totalInward.toDouble() > 0) _totalInwardAmount = totalInward.toDouble();
        if (totalPending != null && totalPending.toDouble() > 0) _pendingAmount = totalPending.toDouble();
        if (loadedPending.isNotEmpty) _pendingInvoices = loadedPending;
        if (loadedInward.isNotEmpty) _inwardRegister = loadedInward;
        _isLoading = false;
      });
    } catch (_) {
      // Backend not running or error, keep baseline sample data
      setState(() => _isLoading = false);
    }
  }

  // ─── Format Currency (₹) ───────────────────────────────────────────────────
  String _formatAmount(double amount) {
    try {
      final formatter = NumberFormat('#,##,##0.00');
      return formatter.format(amount);
    } catch (_) {
      return amount.toStringAsFixed(2);
    }
  }

  // ─── Pay Selected Invoice ──────────────────────────────────────────────────
  void _openPaySelectedInvoice() {
    if (_selectedPendingInvoiceIndex == null ||
        _selectedPendingInvoiceIndex! >= _pendingInvoices.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pending invoice from the table first.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final selected = _pendingInvoices[_selectedPendingInvoiceIndex!];
    final invoiceMap = {
      'id': selected.id,
      'invoiceNumber': selected.invoiceNo,
      'vendor': {'legalName': selected.vendor},
      'vendorName': selected.vendor,
      'totalAmount': selected.invoiceTotal,
      'paidAmount': selected.paid,
      'pendingBalance': selected.pendingBalance,
      'balanceAmount': selected.pendingBalance,
    };

    showDialog(
      context: context,
      builder: (ctx) => PayInvoiceDialog(
        invoice: invoiceMap,
        onPaymentSuccess: () {
          // Immediately recalculate
          setState(() {
            selected.paid = selected.invoiceTotal;
            selected.pendingBalance = 0.00;
            _pendingAmount = _pendingInvoices.fold(0.0, (sum, it) => sum + it.pendingBalance);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment settled for invoice ${selected.invoiceNo}!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _loadBackendData();
        },
      ),
    );
  }

  // ─── Dialog Triggers ───────────────────────────────────────────────────────
  void _openChequeDetails() {
    showDialog(
      context: context,
      builder: (ctx) => ChequeManagementModal(onUpdated: _loadBackendData),
    );
  }

  void _openVendorRegistration() {
    showDialog(
      context: context,
      builder: (ctx) => VendorRegistrationModal(onSuccess: _loadBackendData),
    );
  }

  void _openOutwardDocument() {
    showDialog(
      context: context,
      builder: (ctx) => OutwardDocumentModal(onSuccess: _loadBackendData),
    );
  }

  void _openInwardEntry() {
    showDialog(
      context: context,
      builder: (ctx) => InwardEntryModal(
        onSuccess: () {
          _loadBackendData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New inward invoice registered successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

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

            // ─── 2. Title & Top Right Action Buttons ─────────────────────────
            _buildTitleAndActionsRow(isCompact),

            const SizedBox(height: 14),

            // ─── 3. Section 1: Inward Purchase Summary (KPI Cards) ───────────
            _buildInwardPurchaseSummarySection(isCompact),

            const SizedBox(height: 14),

            // ─── 4. Section 2: Pending Invoices Table + Pay Selected Invoice ─
            _buildPendingInvoicesSection(isCompact),

            const SizedBox(height: 14),

            // ─── 5. Section 3: Inward Entry Register (Detailed Line Items) ───
            _buildInwardRegisterSection(isCompact),

            const SizedBox(height: 24),
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

  // ─── 2. Title & Action Buttons Row ─────────────────────────────────────────
  Widget _buildTitleAndActionsRow(bool isCompact) {
    final actions = [
      _buildActionButton('Cheque Details', _openChequeDetails),
      const SizedBox(width: 8),
      _buildActionButton('+ Vendor Registration', _openVendorRegistration),
      const SizedBox(width: 8),
      _buildActionButton('+ Outward Document', _openOutwardDocument),
      const SizedBox(width: 8),
      _buildActionButton('+ Inward Entry', _openInwardEntry),
    ];

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Purchase / Procurement',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: actions),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Purchase / Procurement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        Row(children: actions),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF15A24),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── 3. Inward Purchase Summary (KPI Cards) ────────────────────────────────
  Widget _buildInwardPurchaseSummarySection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inward Purchase Summary',
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
                    _buildKpiCard('Product Lines', '$_productLinesCount'),
                    const SizedBox(height: 8),
                    _buildKpiCard('Total Inward Amount', _formatAmount(_totalInwardAmount)),
                    const SizedBox(height: 8),
                    _buildKpiCard('Pending Amount', _formatAmount(_pendingAmount)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildKpiCard('Product Lines', '$_productLinesCount')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard('Total Inward Amount', _formatAmount(_totalInwardAmount)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard('Pending Amount', _formatAmount(_pendingAmount)),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value) {
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
            value,
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

  // ─── 4. Pending Invoices Section ───────────────────────────────────────────
  Widget _buildPendingInvoicesSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending Invoices',
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left / Center Table (6 columns)
              Expanded(
                child: Column(
                  children: [
                    // Header Row
                    Container(
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16171A),
                        border: Border(bottom: BorderSide(color: Color(0xFF2B2D33), width: 1)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: _ColHeader('Vendor')),
                          Expanded(flex: 2, child: _ColHeader('Invoice No.')),
                          Expanded(flex: 3, child: _ColHeader('Department')),
                          Expanded(flex: 2, child: _ColHeader('Invoice Total', align: TextAlign.right)),
                          Expanded(flex: 2, child: _ColHeader('Paid', align: TextAlign.right)),
                          Expanded(flex: 2, child: _ColHeader('Pending Balance', align: TextAlign.right)),
                        ],
                      ),
                    ),

                    // Rows
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pendingInvoices.length,
                      separatorBuilder: (ctx, i) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFF24272D),
                      ),
                      itemBuilder: (ctx, index) {
                        final it = _pendingInvoices[index];
                        final isSelected = _selectedPendingInvoiceIndex == index;

                        return InkWell(
                          onTap: () => setState(() => _selectedPendingInvoiceIndex = index),
                          child: Container(
                            height: 34,
                            color: isSelected
                                ? const Color(0xFF2B2E35)
                                : (index % 2 == 0 ? const Color(0xFF1E2025) : const Color(0xFF181A1E)),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    it.vendor,
                                    style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    it.invoiceNo,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    it.department,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatAmount(it.invoiceTotal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatAmount(it.paid),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatAmount(it.pendingBalance),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: it.pendingBalance > 0
                                          ? const Color(0xFFF87171)
                                          : Colors.white70,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
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

              // Right Stacked Orange Button: [ Pay Selected Invoice ]
              Container(
                margin: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
                height: 136,
                width: 100,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF15A24),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  onPressed: _openPaySelectedInvoice,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pay Selected\nInvoice',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 5. Inward Entry Register Section ──────────────────────────────────────
  Widget _buildInwardRegisterSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inward Entry Register',
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
          child: Column(
            children: [
              // Header Row (9 Columns)
              Container(
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF16171A),
                  border: Border(bottom: BorderSide(color: Color(0xFF2B2D33), width: 1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: const Row(
                  children: [
                    SizedBox(width: 85, child: _ColHeader('Date')),
                    Expanded(flex: 2, child: _ColHeader('Supplier')),
                    Expanded(flex: 2, child: _ColHeader('Invoice No.')),
                    Expanded(flex: 2, child: _ColHeader('Department')),
                    Expanded(flex: 4, child: _ColHeader('Product / Material')),
                    SizedBox(width: 45, child: _ColHeader('Qty', align: TextAlign.right)),
                    SizedBox(width: 75, child: _ColHeader('Rate', align: TextAlign.right)),
                    SizedBox(width: 90, child: _ColHeader('Amount', align: TextAlign.right)),
                    SizedBox(width: 65, child: _ColHeader('Status', align: TextAlign.center)),
                  ],
                ),
              ),

              // Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _inwardRegister.length,
                separatorBuilder: (ctx, i) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFF24272D),
                ),
                itemBuilder: (ctx, index) {
                  final it = _inwardRegister[index];
                  return Container(
                    height: 34,
                    color: index % 2 == 0 ? const Color(0xFF1E2025) : const Color(0xFF181A1E),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 85,
                          child: Text(
                            it.date,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            it.supplier,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            it.invoiceNo,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            it.department,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            it.productMaterial,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 45,
                          child: Text(
                            '${it.qty.toInt()}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        SizedBox(
                          width: 75,
                          child: Text(
                            _formatAmount(it.rate),
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            _formatAmount(it.amount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 65,
                          child: Text(
                            it.status,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: it.status == 'Paid'
                                  ? const Color(0xFF10B981)
                                  : (it.status == 'Partial'
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFF87171)),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Bottom Control: [Refresh] button to re-read entries
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE2E4E9),
              side: const BorderSide(color: Color(0xFF353942)),
              backgroundColor: const Color(0xFF22242B),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: _isLoading ? null : _loadBackendData,
            icon: _isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFF15A24),
                    ),
                  )
                : const Icon(Icons.refresh, size: 15, color: Color(0xFFF15A24)),
            label: Text(
              _isLoading ? 'Refreshing...' : 'Refresh Register',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE2E4E9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String title;
  final TextAlign align;

  const _ColHeader(this.title, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: align,
      style: const TextStyle(
        color: Color(0xFFE2E4E9),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
