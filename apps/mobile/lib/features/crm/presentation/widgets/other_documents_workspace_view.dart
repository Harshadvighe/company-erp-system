import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

class OtherDocumentsWorkspaceView extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;

  const OtherDocumentsWorkspaceView({
    super.key,
    this.onBackToDashboard,
  });

  @override
  ConsumerState<OtherDocumentsWorkspaceView> createState() => _OtherDocumentsWorkspaceViewState();
}

class _DocumentLineItem {
  final String id;
  String description;
  double qty;
  double rate;

  _DocumentLineItem({
    required this.id,
    required this.description,
    required this.qty,
    required this.rate,
  });

  double get amount => qty * rate;
}

class _OtherDocumentsWorkspaceViewState extends ConsumerState<OtherDocumentsWorkspaceView> {
  // ─── Theme Colors ───────────────────────────────────────────────────────────
  static const Color _bgDark = Color(0xFF191A1E);
  static const Color _cardBg = Color(0xFF1E2025);
  static const Color _orangeAccent = Color(0xFFF15A24);
  static const Color _borderDark = Color(0xFF2E3138);
  static const Color _inputBorder = Color(0xFF383C44);
  static const Color _textMuted = Color(0xFF9AA0A6);

  // ─── Master Dropdown Data ───────────────────────────────────────────────────
  static const List<String> _documentTypes = [
    'Quotation',
    'Proforma Invoice',
    'Tax Invoice',
    'Invoice',
    'Delivery Challan',
    'Returnable / Retainable Challan',
    'Sales Order',
    'Purchase Order',
    'Job Work',
    'Credit Note',
    'Debit Note',
    'Service Request',
  ];

  static const List<String> _departments = [
    'Production',
    'R&D',
    'Panel Department',
    'Office',
    'Sales',
    'Marketing',
    'Other',
  ];

  // ─── Section 1: Outward Document Details ────────────────────────────────────
  String _selectedDocumentType = 'Quotation';
  late final TextEditingController _dateCtrl;
  late final TextEditingController _docNoCtrl;
  late final TextEditingController _customerCtrl;
  String? _selectedDepartment;
  bool _isDocNoManual = false;

  // ─── Section 2: Add Product / Material ──────────────────────────────────────
  String? _selectedCatalogItem;
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _rateCtrl = TextEditingController(text: '0');

  // ─── Section 3: Items in This Document ──────────────────────────────────────
  final List<_DocumentLineItem> _items = [];
  int? _selectedItemIndex;

  // ─── Section 4: Notes ───────────────────────────────────────────────────────
  final TextEditingController _notesCtrl = TextEditingController();

  // Masters from backend
  List<String> _customerList = [
    'Win Win Distribution Pvt Ltd',
    'Naga Pumps Private Limited',
    'TechMech Automation',
    'Apex Solar Solutions',
    'Satyam Infotech',
    'Shree Ganesh Engineering',
    'Revolve Engineers',
    'RKS Engineering Company',
  ];
  List<Map<String, dynamic>> _catalogList = [];
  bool _isLoadingMasters = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dateCtrl = TextEditingController(text: today);
    _docNoCtrl = TextEditingController(text: _computeLocalSmartDocNo('Quotation', today));
    _customerCtrl = TextEditingController();

    _loadMasters();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _docNoCtrl.dispose();
    _customerCtrl.dispose();
    _descriptionCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Smart document number calculation (matching outward_window.py)
  String _computeLocalSmartDocNo(String docType, String dateStr) {
    final words = RegExp(r'[A-Za-z]+').allMatches(docType).map((m) => m.group(0) ?? '').toList();
    final typeCode = words.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    final cleanDate = dateStr.replaceAll(RegExp(r'[^0-9]'), '');
    final dateCode = cleanDate.length >= 8 ? cleanDate.substring(0, 8) : DateFormat('yyyyMMdd').format(DateTime.now());
    return '$typeCode-$dateCode-001';
  }

  Future<void> _updateSmartDocumentNo() async {
    if (_isDocNoManual) return;
    try {
      final repo = ref.read(salesRepositoryProvider);
      final nextNo = await repo.getNextOutwardNumber(_selectedDocumentType, _dateCtrl.text);
      if (nextNo.isNotEmpty && mounted) {
        setState(() {
          _docNoCtrl.text = nextNo;
        });
        return;
      }
    } catch (_) {}

    // Fallback to local computation
    if (mounted) {
      setState(() {
        _docNoCtrl.text = _computeLocalSmartDocNo(_selectedDocumentType, _dateCtrl.text);
      });
    }
  }

  Future<void> _loadMasters() async {
    try {
      final repo = ref.read(salesRepositoryProvider);
      final customers = await repo.getOutwardCustomers();
      final catalog = await repo.getOutwardCatalog();
      if (mounted) {
        setState(() {
          if (customers.isNotEmpty) _customerList = customers;
          _catalogList = catalog;
          _isLoadingMasters = false;
        });
      }
      await _updateSmartDocumentNo();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMasters = false);
      }
    }
  }

  double get _documentTotal => _items.fold(0.0, (sum, item) => sum + item.amount);

  void _onCatalogItemSelected(String? label) {
    setState(() => _selectedCatalogItem = label);
    if (label == null || label.isEmpty) return;
    final found = _catalogList.firstWhere(
      (c) => c['label'] == label || c['name'] == label,
      orElse: () => {},
    );
    if (found.isNotEmpty) {
      final name = found['name'] ?? '';
      final cap = found['capacity'] ?? '';
      final sup = found['supplier'] ?? '';
      final price = found['price'] ?? 0;

      _descriptionCtrl.text = '$name $cap $sup'.trim();
      _rateCtrl.text = price.toString();
    }
  }

  void _addItem() {
    final desc = _descriptionCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;

    if (desc.isEmpty) {
      _showWarning('Enter or select a product/material description first.');
      return;
    }
    if (qty <= 0) {
      _showWarning('Please enter a valid quantity greater than 0.');
      return;
    }
    if (rate < 0) {
      _showWarning('Rate cannot be negative.');
      return;
    }

    setState(() {
      _items.add(_DocumentLineItem(
        id: 'item-${DateTime.now().millisecondsSinceEpoch}',
        description: desc,
        qty: qty,
        rate: rate,
      ));
      _selectedCatalogItem = null;
      _descriptionCtrl.clear();
      _qtyCtrl.text = '1';
      _rateCtrl.text = '0';
      _selectedItemIndex = null;
    });
  }

  void _removeSelectedItem() {
    if (_selectedItemIndex != null && _selectedItemIndex! < _items.length) {
      setState(() {
        _items.removeAt(_selectedItemIndex!);
        _selectedItemIndex = null;
      });
    } else {
      _showWarning('Select an item from the table to remove.');
    }
  }

  Future<void> _saveDocument() async {
    final docNo = _docNoCtrl.text.trim();
    final customer = _customerCtrl.text.trim();

    if (docNo.isEmpty) {
      _showWarning('Document Number is required.');
      return;
    }
    if (customer.isEmpty) {
      _showWarning('Customer Name is required.');
      return;
    }
    if (_items.isEmpty) {
      _showWarning('Add at least one product or material item.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final payload = {
        'documentType': _selectedDocumentType,
        'documentDate': _dateCtrl.text.trim(),
        'documentNo': docNo,
        'customer': customer,
        'department': _selectedDepartment ?? 'Office',
        'items': _items.map((i) => {
          'itemDescription': i.description,
          'quantity': i.qty,
          'rate': i.rate,
          'amount': i.amount,
        }).toList(),
        'notes': _notesCtrl.text.trim(),
      };

      await repo.saveOutwardDocument(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Outward document $docNo saved successfully.\nCSV, Excel, and printable PDF created.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );

        // Reset form for next document
        setState(() {
          _items.clear();
          _selectedItemIndex = null;
          _customerCtrl.clear();
          _notesCtrl.clear();
          _isDocNoManual = false;
        });
        await _updateSmartDocumentNo();
      }
    } catch (e) {
      if (mounted) {
        _showWarning('Failed to save outward document: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFC62828),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
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

            // ─── Section 1: Outward Document Details ───────────────────────
            _buildSectionCard(
              title: 'Outward Document Details',
              child: Column(
                children: [
                  // Row 0: Document Type & Document Date
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'Document Type:',
                          child: DropdownButtonFormField<String>(
                            value: _selectedDocumentType,
                            isExpanded: true,
                            dropdownColor: _cardBg,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration(),
                            icon: const Icon(Icons.arrow_drop_down, color: _textMuted),
                            items: _documentTypes.map((t) {
                              return DropdownMenuItem(value: t, child: Text(t));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDocumentType = val);
                                _updateSmartDocumentNo();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildFormField(
                          label: 'Document Date:',
                          child: TextFormField(
                            controller: _dateCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration(
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today, size: 16, color: _textMuted),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.tryParse(_dateCtrl.text) ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                                    });
                                    _updateSmartDocumentNo();
                                  }
                                },
                              ),
                            ),
                            onChanged: (_) => _updateSmartDocumentNo(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 1: Document No. & Customer Name
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'Document No.:',
                          child: TextFormField(
                            controller: _docNoCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration(),
                            onChanged: (_) => _isDocNoManual = true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildFormField(
                          label: 'Customer Name:',
                          child: Autocomplete<String>(
                            initialValue: TextEditingValue(text: _customerCtrl.text),
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return _customerList.take(6);
                              }
                              return _customerList.where((name) =>
                                  name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (selection) {
                              _customerCtrl.text = selection;
                            },
                            fieldViewBuilder: (ctx, ctrl, focusNode, onFieldSubmitted) {
                              ctrl.addListener(() {
                                _customerCtrl.text = ctrl.text;
                              });
                              return TextFormField(
                                controller: ctrl,
                                focusNode: focusNode,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration(
                                  suffixIcon: const Icon(Icons.arrow_drop_down, color: _textMuted),
                                ),
                              );
                            },
                            optionsViewBuilder: (ctx, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  color: const Color(0xFF22242A),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    width: 320,
                                    constraints: const BoxConstraints(maxHeight: 180),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, idx) {
                                        final opt = options.elementAt(idx);
                                        return ListTile(
                                          dense: true,
                                          title: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                          onTap: () => onSelected(opt),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Department
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'Department:',
                          child: DropdownButtonFormField<String>(
                            value: _selectedDepartment,
                            hint: const Text('Select Department', style: TextStyle(color: _textMuted, fontSize: 12)),
                            isExpanded: true,
                            dropdownColor: _cardBg,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration(),
                            icon: const Icon(Icons.arrow_drop_down, color: _textMuted),
                            items: _departments.map((d) {
                              return DropdownMenuItem(value: d, child: Text(d));
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedDepartment = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      const Expanded(child: SizedBox()), // Balances the 2-column grid
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Section 2: Add Product / Material ─────────────────────────
            _buildSectionCard(
              title: 'Add Product / Material',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 0: Existing Product Dropdown
                  Row(
                    children: [
                      const SizedBox(
                        width: 130,
                        child: Text(
                          'Existing Product:',
                          style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCatalogItem,
                          hint: const Text('Search or select from Catalog...', style: TextStyle(color: _textMuted, fontSize: 12)),
                          isExpanded: true,
                          dropdownColor: _cardBg,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration(),
                          icon: const Icon(Icons.arrow_drop_down, color: _textMuted),
                          items: _catalogList.map((c) {
                            final label = c['label']?.toString() ?? c['name']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: label,
                              child: Text(label, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: _onCatalogItemSelected,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 1: Description, Qty, Rate, and [Add Item] Button
                  Row(
                    children: [
                      const SizedBox(
                        width: 130,
                        child: Text(
                          'Description:',
                          style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _descriptionCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration(
                            hintText: 'Enter part name, specs, capacity, or details',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Qty:',
                        style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Rate:',
                        style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _addItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orangeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          elevation: 0,
                        ),
                        child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Section 3: Items in This Document ─────────────────────────
            _buildSectionCard(
              title: 'Items in This Document',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table Header & Rows Container
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _borderDark),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          color: const Color(0xFF22242A),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  'Product / Material',
                                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Qty',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Rate',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Amount',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Items List
                        if (_items.isEmpty)
                          Container(
                            height: 140,
                            alignment: Alignment.center,
                            child: const Text(
                              'No items added to this document yet.',
                              style: TextStyle(color: _textMuted, fontSize: 13),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: _borderDark),
                            itemBuilder: (ctx, index) {
                              final item = _items[index];
                              final isSelected = _selectedItemIndex == index;
                              return InkWell(
                                onTap: () => setState(() => _selectedItemIndex = index),
                                child: Container(
                                  color: isSelected ? const Color(0xFF2A2D35) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Text(
                                          item.description,
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          NumberFormat('#,##0.##').format(item.qty),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          NumberFormat('#,##0.00').format(item.rate),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          NumberFormat('#,##0.00').format(item.amount),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
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
                  const SizedBox(height: 12),

                  // Bottom row of Card 3: [Remove Selected Item] on left, Document Total on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _selectedItemIndex != null ? _removeSelectedItem : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orangeAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF4A4E58),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          elevation: 0,
                        ),
                        child: const Text('Remove Selected Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Document Total: ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            NumberFormat('#,##0.00').format(_documentTotal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Section 4: Notes & Bottom Action Bar ──────────────────────
            const Text(
              'Notes:',
              style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                hintText: 'Enter logistics details, vehicle no, transport instructions, or terms...',
                hintStyle: const TextStyle(color: Colors.black45, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 18),

            // Bottom Right Actions: [Save Outward Document] & [Back]
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orangeAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF4A4E58),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save Outward Document',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: widget.onBackToDashboard ?? () => context.go('/dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orangeAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                  child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Reusable Card & Input Helpers ──────────────────────────────────────────

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderDark, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _orangeAccent,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  InputDecoration _inputDecoration({Widget? suffixIcon, String? hintText}) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: const Color(0xFF151619),
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: _inputBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: _orangeAccent, width: 1.5),
      ),
    );
  }
}
