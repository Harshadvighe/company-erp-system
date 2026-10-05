import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';

class InwardEntryModal extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const InwardEntryModal({super.key, required this.onSuccess});

  @override
  ConsumerState<InwardEntryModal> createState() => _InwardEntryModalState();
}

class _InwardItemRow {
  String? productId;
  String? productName;
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController rateCtrl = TextEditingController(text: '0');
  final TextEditingController taxCtrl = TextEditingController(text: '18');
  final TextEditingController batchCtrl = TextEditingController();
  String unit = 'PCS';
  bool qcRequired = true;

  double get subtotal {
    final q = double.tryParse(qtyCtrl.text) ?? 0;
    final r = double.tryParse(rateCtrl.text) ?? 0;
    return q * r;
  }

  double get taxAmount {
    final t = double.tryParse(taxCtrl.text) ?? 0;
    return (subtotal * t) / 100;
  }

  double get total => subtotal + taxAmount;
}

class _InwardEntryModalState extends ConsumerState<InwardEntryModal> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumCtrl = TextEditingController();
  final _transporterCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _lrCtrl = TextEditingController();
  final _dcCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  String? _selectedVendorId;
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingMasters = true;
  bool _isSubmitting = false;

  final List<_InwardItemRow> _items = [_InwardItemRow()];

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
          if (_vendors.isNotEmpty) _selectedVendorId = _vendors.first['id'];
          if (_products.isNotEmpty) {
            _items.first.productId = _products.first['id'];
            _items.first.productName = _products.first['name'];
            _items.first.rateCtrl.text = (_products.first['purchasePrice'] ?? 0).toString();
          }
          _isLoadingMasters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMasters = false);
    }
  }

  @override
  void dispose() {
    _invoiceNumCtrl.dispose();
    _transporterCtrl.dispose();
    _vehicleCtrl.dispose();
    _lrCtrl.dispose();
    _dcCtrl.dispose();
    _remarksCtrl.dispose();
    for (var i in _items) {
      i.qtyCtrl.dispose();
      i.rateCtrl.dispose();
      i.taxCtrl.dispose();
      i.batchCtrl.dispose();
    }
    super.dispose();
  }

  double get _grandTotal => _items.fold(0.0, (acc, item) => acc + item.total);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
        child: _isLoadingMasters
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Modal Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.move_to_inbox, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Inward Entry / Goods Receipt (GRN)',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('Receive incoming shipments, batch details & initialize QC inspection',
                                    style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.darkTextSecondary),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Master details
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedVendorId,
                                    dropdownColor: AppTheme.darkSurface,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Select Vendor / Supplier*',
                                      filled: true,
                                      fillColor: AppTheme.darkBackground,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    items: _vendors.map((v) {
                                      return DropdownMenuItem<String>(
                                        value: v['id'] as String,
                                        child: Text(v['companyName'] ?? 'Vendor'),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => _selectedVendorId = v),
                                    validator: (v) => v == null ? 'Please select vendor' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _invoiceNumCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Vendor Invoice Number*',
                                      hintText: 'e.g. INV-2026-908',
                                      filled: true,
                                      fillColor: AppTheme.darkBackground,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Logistics Details
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _transporterCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Transporter / Carrier',
                                      hintText: 'V-Trans / TCI Express',
                                      filled: true,
                                      fillColor: AppTheme.darkBackground,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _vehicleCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Vehicle Number',
                                      hintText: 'MH-04-GP-8821',
                                      filled: true,
                                      fillColor: AppTheme.darkBackground,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _dcCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Delivery Challan #',
                                      hintText: 'DC-88129',
                                      filled: true,
                                      fillColor: AppTheme.darkBackground,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Line Items Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Material Line Items',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      final item = _InwardItemRow();
                                      if (_products.isNotEmpty) {
                                        item.productId = _products.first['id'];
                                        item.productName = _products.first['name'];
                                      }
                                      _items.add(item);
                                    });
                                  },
                                  icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                                  label: const Text('Add Item', style: TextStyle(color: AppTheme.primary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Item Cards
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkBackground,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.darkBorder),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: DropdownButtonFormField<String>(
                                              initialValue: item.productId,
                                              dropdownColor: AppTheme.darkSurface,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: 'Product / Item*',
                                                isDense: true,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              items: _products.map((p) {
                                                return DropdownMenuItem<String>(
                                                  value: p['id'] as String,
                                                  child: Text(p['name'] ?? 'Product', overflow: TextOverflow.ellipsis),
                                                );
                                              }).toList(),
                                              onChanged: (v) {
                                                setState(() {
                                                  item.productId = v;
                                                  final prod = _products.firstWhere((p) => p['id'] == v, orElse: () => {});
                                                  item.productName = prod['name'];
                                                  if (prod['purchasePrice'] != null) {
                                                    item.rateCtrl.text = prod['purchasePrice'].toString();
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: item.qtyCtrl,
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: 'Qty*',
                                                isDense: true,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                              validator: (v) {
                                                final n = double.tryParse(v ?? '');
                                                return n == null || n <= 0 ? 'Invalid' : null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: item.rateCtrl,
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: 'Rate (₹)*',
                                                isDense: true,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: item.taxCtrl,
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: 'GST %',
                                                isDense: true,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          if (_items.length > 1)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                              onPressed: () => setState(() => _items.removeAt(index)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: item.batchCtrl,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: 'Batch / Lot Number',
                                                hintText: 'e.g. BT-2026-X1',
                                                isDense: true,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Row(
                                            children: [
                                              const Text('QC Required:', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
                                              Switch(
                                                value: item.qcRequired,
                                                activeThumbColor: AppTheme.primary,
                                                onChanged: (val) => setState(() => item.qcRequired = val),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Item Total: ₹${item.total.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Total Bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${_items.length} Product Line(s)',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  Text('Grand Total: ₹${_grandTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isSubmitting ? null : _submitInward,
                            icon: _isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check, size: 18),
                            label: Text(_isSubmitting ? 'Creating GRN...' : 'Save Inward Entry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _submitInward() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendorId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(purchaseRepositoryProvider);

      final itemsPayload = _items.map((it) {
        return {
          'productId': it.productId,
          'quantity': double.parse(it.qtyCtrl.text.trim()),
          'unit': it.unit,
          'rate': double.parse(it.rateCtrl.text.trim()),
          'taxRate': double.parse(it.taxCtrl.text.trim()),
          'batchNumber': it.batchCtrl.text.trim().isEmpty ? null : it.batchCtrl.text.trim(),
          'qcRequired': it.qcRequired,
        };
      }).toList();

      final payload = {
        'vendorId': _selectedVendorId,
        'vendorInvoiceNumber': _invoiceNumCtrl.text.trim(),
        'transporter': _transporterCtrl.text.trim(),
        'vehicleNumber': _vehicleCtrl.text.trim(),
        'deliveryChallanNumber': _dcCtrl.text.trim(),
        'remarks': _remarksCtrl.text.trim(),
        'items': itemsPayload,
      };

      await repo.createInwardEntry(payload);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inward Entry / GRN created successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save inward entry: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
