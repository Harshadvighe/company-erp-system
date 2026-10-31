import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';

class OutwardDocumentModal extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const OutwardDocumentModal({super.key, required this.onSuccess});

  @override
  ConsumerState<OutwardDocumentModal> createState() => _OutwardDocumentModalState();
}

class _OutwardLineItem {
  final String id;
  String productMaterial;
  double qty;
  double rate;

  _OutwardLineItem({
    required this.id,
    required this.productMaterial,
    required this.qty,
    required this.rate,
  });

  double get amount => qty * rate;
}

class _OutwardDocumentModalState extends ConsumerState<OutwardDocumentModal> {
  final _formKey = GlobalKey<FormState>();

  // ─── Document Details ───────────────────────────────────────────────────────
  String _documentType = 'Quotation';
  final _dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  late final TextEditingController _docNumberCtrl;
  String? _selectedCustomer;
  String _selectedDepartment = 'Panel Department';

  // ─── Add Product / Material ────────────────────────────────────────────────
  String? _selectedCatalogProductId;
  final _descriptionCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController(text: '0');

  // ─── Line Items & Selection ────────────────────────────────────────────────
  final List<_OutwardLineItem> _items = [];
  int? _selectedRowIndex;

  // ─── Notes ─────────────────────────────────────────────────────────────────
  final _notesCtrl = TextEditingController();

  // Masters
  List<Map<String, dynamic>> _products = [];
  final List<String> _customers = [
    'SAARK EXPLORATION PVT LTD',
    'TechMech Automation',
    'Apex Solar Solutions',
    'Satyam Infotech',
    'Shree Ganesh Engineering',
  ];

  final List<String> _docTypes = [
    'Quotation',
    'Delivery Challan',
    'Returnable Gate Pass',
    'Non-Returnable Gate Pass',
    'Material Dispatch Note',
  ];

  final List<String> _departments = [
    'Panel Department',
    'R&D',
    'Maintenance',
    'Production',
    'Other',
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
    _docNumberCtrl = TextEditingController(text: 'Q-$todayStr-001');
    _selectedCustomer = _customers.first;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final repo = ref.read(purchaseRepositoryProvider);
      final prods = await repo.getProducts();
      if (mounted) {
        setState(() {
          _products = prods;
          if (_products.isNotEmpty) {
            _selectedCatalogProductId = _products.first['id']?.toString();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _docNumberCtrl.dispose();
    _descriptionCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _documentTotal => _items.fold(0.0, (sum, it) => sum + it.amount);

  void _addItem() {
    final desc = _descriptionCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter item description / product name'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;

    setState(() {
      _items.add(_OutwardLineItem(
        id: UniqueKey().toString(),
        productMaterial: desc,
        qty: qty,
        rate: rate,
      ));
      _descriptionCtrl.clear();
      _qtyCtrl.text = '1';
      _rateCtrl.text = '0';
    });
  }

  void _onExistingProductChanged(String? val) {
    _selectedCatalogProductId = val;
    if (val != null) {
      final prod = _products.firstWhere(
        (p) => p['id']?.toString() == val,
        orElse: () => {},
      );
      if (prod.isNotEmpty) {
        setState(() {
          _descriptionCtrl.text = prod['name']?.toString() ?? '';
          final price = (prod['sellingPrice'] as num?)?.toDouble() ??
              (prod['price'] as num?)?.toDouble() ??
              0.0;
          _rateCtrl.text = price.toStringAsFixed(2);
        });
      }
    }
  }

  void _removeSelectedItem() {
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

  Future<void> _submitDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one line item to this outward document.'),
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
          'materialName': it.productMaterial,
          'quantity': it.qty,
          'unit': 'Nos',
          'rate': it.rate,
          'amount': it.amount,
        };
      }).toList();

      final payload = {
        'documentType': _documentType,
        'documentNumber': _docNumberCtrl.text.trim(),
        'documentDate': _dateCtrl.text.trim(),
        'partyName': _selectedCustomer ?? 'Direct Outward',
        'department': _selectedDepartment,
        'remarks': _notesCtrl.text.trim(),
        'totalAmount': _documentTotal,
        'items': itemsPayload,
      };

      await repo.createOutwardDocument(payload);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save outward document: $e'),
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
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── 1. Outward Document Details ─────────────────────────
                      _buildSectionHeader('Outward Document Details'),
                      const SizedBox(height: 8),
                      _buildDocumentDetailsSection(),
                      const SizedBox(height: 16),

                      // ─── 2. Add Product / Material ───────────────────────────
                      _buildSectionHeader('Add Product / Material'),
                      const SizedBox(height: 8),
                      _buildAddProductSection(),
                      const SizedBox(height: 16),

                      // ─── 3. Items in This Document ───────────────────────────
                      _buildSectionHeader('Items in This Document'),
                      const SizedBox(height: 8),
                      _buildItemsTableSection(),
                      const SizedBox(height: 16),

                      // ─── 4. Notes ────────────────────────────────────────────
                      _buildSectionHeader('Notes:'),
                      const SizedBox(height: 8),
                      _buildNotesSection(),
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
            'New Outward Document',
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

  // ─── 1. Document Details Section ───────────────────────────────────────────
  Widget _buildDocumentDetailsSection() {
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
              // Document Type
              Expanded(
                child: _buildFormField(
                  label: 'Document Type:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _documentType,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _docTypes.map((t) {
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _documentType = v ?? 'Quotation'),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Document Date
              Expanded(
                child: _buildFormField(
                  label: 'Document Date:',
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
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Document No.
              Expanded(
                child: _buildFormField(
                  label: 'Document No.:',
                  child: TextFormField(
                    controller: _docNumberCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Customer Name with orange highlight border
              Expanded(
                child: _buildFormField(
                  label: 'Customer Name:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCustomer,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(highlight: true),
                    items: _customers.map((c) {
                      return DropdownMenuItem<String>(
                        value: c,
                        child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCustomer = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Department
              Expanded(
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
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Add Product / Material Section ─────────────────────────────────────
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
              Expanded(
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
                    onChanged: _onExistingProductChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildFormField(
                  label: 'Description:',
                  child: TextFormField(
                    controller: _descriptionCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Product or service description'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF15A24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _addItem,
                  child: const Text(
                    'Add Item',
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

  // ─── 3. Items in This Document Table ───────────────────────────────────────
  Widget _buildItemsTableSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36)),
      ),
      child: Column(
        children: [
          // Header
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

          // Items Table
          Container(
            height: 140,
            color: const Color(0xFF18191D),
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'No items added yet.',
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

          // Bottom Bar
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
                  onPressed: _removeSelectedItem,
                  child: const Text(
                    'Remove Selected Item',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  'Document Total: ${_documentTotal.toStringAsFixed(2)}',
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

  // ─── 4. Notes Section ──────────────────────────────────────────────────────
  Widget _buildNotesSection() {
    return TextFormField(
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
            onPressed: _isSubmitting ? null : _submitDocument,
            child: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Save Outward Document',
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Back',
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

  InputDecoration _inputDecoration({
    bool highlight = false,
    String? hintText,
    Widget? suffixIcon,
  }) {
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
        borderSide: BorderSide(
          color: highlight ? const Color(0xFFF15A24) : const Color(0xFF353942),
          width: highlight ? 1.4 : 1.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(
          color: highlight ? const Color(0xFFF15A24) : const Color(0xFF353942),
          width: highlight ? 1.4 : 1.0,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
        borderSide: BorderSide(color: Color(0xFFF15A24), width: 1.4),
      ),
    );
  }
}
