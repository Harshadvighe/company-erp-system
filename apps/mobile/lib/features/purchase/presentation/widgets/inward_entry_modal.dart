import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/vendor_registration_modal.dart';

class InwardEntryModal extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const InwardEntryModal({super.key, required this.onSuccess});

  @override
  ConsumerState<InwardEntryModal> createState() => _InwardEntryModalState();
}

class _LineItem {
  final String id;
  String productMaterial;
  double qty;
  double rate;
  String? productId;

  _LineItem({
    required this.id,
    required this.productMaterial,
    required this.qty,
    required this.rate,
    this.productId,
  });

  double get amount => qty * rate;
}

class _InwardEntryModalState extends ConsumerState<InwardEntryModal> {
  final _formKey = GlobalKey<FormState>();

  // ─── Invoice Details ────────────────────────────────────────────────────────
  final _dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _invoiceNumCtrl = TextEditingController();
  String _selectedDepartment = 'Panel Department';
  String? _selectedVendorId;
  String? _selectedVendorName;

  // ─── Add Product Inputs ────────────────────────────────────────────────────
  final _manualProductCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController(text: '0');
  String? _selectedCatalogProductId;

  // ─── Line Items Table ──────────────────────────────────────────────────────
  final List<_LineItem> _items = [];
  int? _selectedRowIndex;

  // ─── Payment & Notes ───────────────────────────────────────────────────────
  String _paymentStatus = 'Pending';
  String _paymentMethod = 'Hard Cash';
  final _chequeDateCtrl = TextEditingController();
  final _chequeNumCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Masters
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingMasters = true;
  bool _isSubmitting = false;

  final List<String> _departments = [
    'Panel Department',
    'R&D',
    'Maintenance',
    'Production',
    'Other',
  ];

  final List<String> _paymentStatuses = ['Pending', 'Paid', 'Partial'];
  final List<String> _paymentMethods = ['Hard Cash', 'Account Pay', 'Cheque'];

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final repo = ref.read(purchaseRepositoryProvider);
      final vendors = await repo.getVendors();
      final products = await repo.getProducts();

      if (mounted) {
        setState(() {
          _vendors = vendors;
          _products = products;
          if (_vendors.isNotEmpty) {
            _selectedVendorId = _vendors.first['id']?.toString();
            _selectedVendorName = _vendors.first['legalName'] ??
                _vendors.first['companyName'] ??
                'Vendor';
          }
          if (_products.isNotEmpty) {
            _selectedCatalogProductId = _products.first['id']?.toString();
          }
          _isLoadingMasters = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMasters = false);
      }
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _invoiceNumCtrl.dispose();
    _manualProductCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _chequeDateCtrl.dispose();
    _chequeNumCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _invoiceTotal => _items.fold(0.0, (acc, it) => acc + it.amount);

  void _addProduct() {
    final name = _manualProductCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Product / Material description'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;

    setState(() {
      _items.add(_LineItem(
        id: UniqueKey().toString(),
        productMaterial: name,
        qty: qty,
        rate: rate,
        productId: _selectedCatalogProductId,
      ));
      _manualProductCtrl.clear();
      _qtyCtrl.text = '1';
      _rateCtrl.text = '0';
    });
  }

  void _useSelectedProduct() {
    if (_selectedCatalogProductId == null) return;
    final prod = _products.firstWhere(
      (p) => p['id']?.toString() == _selectedCatalogProductId,
      orElse: () => {},
    );
    if (prod.isNotEmpty) {
      final name = prod['name']?.toString() ?? 'Component';
      final price = (prod['purchasePrice'] as num?)?.toDouble() ??
          (prod['price'] as num?)?.toDouble() ??
          0.0;
      setState(() {
        _manualProductCtrl.text = name;
        _rateCtrl.text = price.toStringAsFixed(2);
      });
    }
  }

  void _removeSelectedProduct() {
    if (_selectedRowIndex == null || _selectedRowIndex! >= _items.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an item in the table to remove'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }
    setState(() {
      _items.removeAt(_selectedRowIndex!);
      _selectedRowIndex = null;
    });
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product line item to this invoice.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(purchaseRepositoryProvider);

      final itemsPayload = _items.map((it) {
        return {
          'productId': it.productId,
          'productName': it.productMaterial,
          'quantity': it.qty,
          'rate': it.rate,
          'amount': it.amount,
          'unit': 'Nos',
          'taxRate': 0,
        };
      }).toList();

      final payload = {
        'vendorId': _selectedVendorId,
        'vendorName': _selectedVendorName,
        'vendorInvoiceNumber': _invoiceNumCtrl.text.trim(),
        'invoiceNumber': _invoiceNumCtrl.text.trim(),
        'department': _selectedDepartment,
        'inwardDate': _dateCtrl.text.trim(),
        'paymentStatus': _paymentStatus,
        'paymentMethod': _paymentMethod,
        'chequeDate': _chequeDateCtrl.text.trim().isEmpty ? null : _chequeDateCtrl.text.trim(),
        'chequeNumber': _chequeNumCtrl.text.trim().isEmpty ? null : _chequeNumCtrl.text.trim(),
        'remarks': _notesCtrl.text.trim(),
        'totalAmount': _invoiceTotal,
        'items': itemsPayload,
      };

      await repo.createInwardEntry(payload);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save inward invoice: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: const Color(0xFF191A1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Container(
        width: 1100,
        constraints: const BoxConstraints(maxHeight: 820),
        child: Column(
          children: [
            // ─── Top Window Header Strip ───────────────────────────────────────
            _buildTopBar(),

            // ─── Scrollable Form Body ──────────────────────────────────────────
            Expanded(
              child: _isLoadingMasters
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFF15A24)),
                    )
                  : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── 1. Invoice Details ────────────────────────────
                            _buildSectionHeader('Invoice Details'),
                            const SizedBox(height: 8),
                            _buildInvoiceDetailsSection(),
                            const SizedBox(height: 16),

                            // ─── 2. Add Product to This Invoice ────────────────
                            _buildSectionHeader('Add Product to This Invoice'),
                            const SizedBox(height: 8),
                            _buildAddProductSection(),
                            const SizedBox(height: 16),

                            // ─── 3. Products in this invoice: ──────────────────
                            _buildSectionHeader('Products in this invoice:'),
                            const SizedBox(height: 8),
                            _buildProductsTableSection(),
                            const SizedBox(height: 16),

                            // ─── 4. Payment and Notes ──────────────────────────
                            _buildSectionHeader('Payment and Notes'),
                            const SizedBox(height: 8),
                            _buildPaymentAndNotesSection(),
                          ],
                        ),
                      ),
                    ),
            ),

            // ─── Bottom Actions ────────────────────────────────────────────────
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  // ─── Top Header Strip ───────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2F36), width: 1.2)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF22242B),
              side: const BorderSide(color: Color(0xFF383C46)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 14, color: Colors.white),
            label: const Text(
              'Back to Accounts & Finance',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF22242B),
              side: const BorderSide(color: Color(0xFF383C46)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () {},
            icon: const Icon(Icons.help_outline, size: 14, color: Colors.white),
            label: const Text(
              'Help',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'New Inward Invoice',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE57A38),
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }

  // ─── 1. Invoice Details Section ────────────────────────────────────────────
  Widget _buildInvoiceDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Date
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Date (YYYY-MM-DD):',
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
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Supplier Dropdown + [+ Add Vendor]
              Expanded(
                flex: 3,
                child: _buildFormField(
                  label: 'Supplier:',
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedVendorId,
                          dropdownColor: const Color(0xFF22242B),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: _inputDecoration(),
                          items: _vendors.map((v) {
                            return DropdownMenuItem<String>(
                              value: v['id']?.toString(),
                              child: Text(
                                v['legalName'] ?? v['companyName'] ?? 'Vendor',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedVendorId = v;
                              final match = _vendors.firstWhere(
                                (item) => item['id']?.toString() == v,
                                orElse: () => {},
                              );
                              _selectedVendorName = match['legalName'] ?? match['companyName'];
                            });
                          },
                          validator: (v) => v == null ? 'Please select supplier' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF15A24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => VendorRegistrationModal(
                              onSuccess: () => _loadMasters(),
                            ),
                          );
                        },
                        child: const Text(
                          '+ Add Vendor',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Invoice / Challan No.
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Invoice / Challan No.:',
                  child: TextFormField(
                    controller: _invoiceNumCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'e.g. 123 or INV-2026-001'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Department
              Expanded(
                flex: 3,
                child: _buildFormField(
                  label: 'Department:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDepartment,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _departments.map((d) {
                      return DropdownMenuItem<String>(
                        value: d,
                        child: Text(d, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedDepartment = v ?? 'Panel Department'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Add Product to This Invoice Section ────────────────────────────────
  Widget _buildAddProductSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Product / Material free text
              Expanded(
                flex: 4,
                child: _buildFormField(
                  label: 'Product / Material:',
                  child: TextFormField(
                    controller: _manualProductCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Item specification / component name'),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Qty
              SizedBox(
                width: 75,
                child: _buildFormField(
                  label: 'Qty:',
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Rate
              SizedBox(
                width: 100,
                child: _buildFormField(
                  label: 'Rate:',
                  child: TextFormField(
                    controller: _rateCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Add Product Button
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF15A24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _addProduct,
                  child: const Text(
                    'Add Product',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Existing Product Catalog Row
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildFormField(
                  label: 'Existing Product:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCatalogProductId,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _products.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['id']?.toString(),
                        child: Text(
                          p['name'] ?? 'Product',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCatalogProductId = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF15A24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _useSelectedProduct,
                  child: const Text(
                    'Use Selected Product',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. Products in this invoice Table ──────────────────────────────────────
  Widget _buildProductsTableSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF16171A),
              border: Border(bottom: BorderSide(color: Color(0xFF2B2D33))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Product / Material',
                    style: TextStyle(color: Color(0xFFE2E4E9), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Color(0xFFE2E4E9), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Rate',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Color(0xFFE2E4E9), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Color(0xFFE2E4E9), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // Items Table Viewport
          Container(
            height: 140,
            color: const Color(0xFF18191D),
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'No products added yet. Use form above to add items.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final it = _items[index];
                      final isSelected = _selectedRowIndex == index;
                      return InkWell(
                        onTap: () => setState(() => _selectedRowIndex = index),
                        child: Container(
                          height: 32,
                          color: isSelected ? const Color(0xFF2C3240) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  it.productMaterial,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '${it.qty.toInt()}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  it.rate.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  it.amount.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white,
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
          ),

          // Bottom Bar of Table: [Remove Selected Product] and Invoice Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2025),
              border: Border(top: BorderSide(color: Color(0xFF2C2F36))),
            ),
            child: Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF15A24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _removeSelectedProduct,
                  child: const Text(
                    'Remove Selected Product',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  'Invoice Total: ${_invoiceTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. Payment and Notes Section ──────────────────────────────────────────
  Widget _buildPaymentAndNotesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Payment Status
              Expanded(
                child: _buildFormField(
                  label: 'Payment Status:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentStatus,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _paymentStatuses.map((s) {
                      return DropdownMenuItem<String>(
                        value: s,
                        child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _paymentStatus = v ?? 'Pending'),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Payment Method
              Expanded(
                child: _buildFormField(
                  label: 'Payment Method:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _paymentMethods.map((m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _paymentMethod = v ?? 'Hard Cash'),
                  ),
                ),
              ),
            ],
          ),

          // Cheque Details (if Cheque chosen)
          if (_paymentMethod == 'Cheque') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'Cheque Date:',
                    child: TextFormField(
                      controller: _chequeDateCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: _inputDecoration(hintText: 'YYYY-MM-DD'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    label: 'Cheque Number:',
                    child: TextFormField(
                      controller: _chequeNumCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: _inputDecoration(hintText: 'e.g. 000123'),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          _buildFormField(
            label: 'Notes:',
            child: TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFF1E2025), fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        border: Border(top: BorderSide(color: Color(0xFF2C2F36), width: 1.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: _isSubmitting ? null : _submitInvoice,
            child: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Save Invoice',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Field Helper ──────────────────────────────────────────────────────
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
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      isDense: true,
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 11.5),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF22242B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFF353942)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFF353942)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFF15A24), width: 1.2),
      ),
    );
  }
}
