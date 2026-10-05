import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';

class OutwardDocumentModal extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const OutwardDocumentModal({super.key, required this.onSuccess});

  @override
  ConsumerState<OutwardDocumentModal> createState() => _OutwardDocumentModalState();
}

class _OutwardItemRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  String unit = 'PCS';
}

class _OutwardDocumentModalState extends ConsumerState<OutwardDocumentModal> {
  final _formKey = GlobalKey<FormState>();
  final _fromLocationCtrl = TextEditingController(text: 'Main Assembly Warehouse MIDC');
  final _toLocationCtrl = TextEditingController();
  final _partyNameCtrl = TextEditingController();
  final _personNameCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _refNumberCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  String _outwardType = 'MATERIAL_OUTWARD';
  String _partyType = 'VENDOR';
  bool _isSubmitting = false;

  final List<_OutwardItemRow> _items = [_OutwardItemRow()];

  @override
  void dispose() {
    _fromLocationCtrl.dispose();
    _toLocationCtrl.dispose();
    _partyNameCtrl.dispose();
    _personNameCtrl.dispose();
    _purposeCtrl.dispose();
    _refNumberCtrl.dispose();
    _vehicleCtrl.dispose();
    _remarksCtrl.dispose();
    for (var i in _items) {
      i.nameCtrl.dispose();
      i.qtyCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
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
                      child: const Icon(Icons.outbox, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Outward Document',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Gate pass, material dispatch, repair, sample return & document tracking',
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

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Outward Type and Party Type
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _outwardType,
                              dropdownColor: AppTheme.darkSurface,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Outward Type*',
                                filled: true,
                                fillColor: AppTheme.darkBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'MATERIAL_OUTWARD', child: Text('Material Outward')),
                                DropdownMenuItem(value: 'DOCUMENT_OUTWARD', child: Text('Document Outward')),
                                DropdownMenuItem(value: 'SAMPLE', child: Text('Sample Handover')),
                                DropdownMenuItem(value: 'REPAIR', child: Text('Repair / Servicing')),
                                DropdownMenuItem(value: 'RETURN', child: Text('Vendor Return')),
                                DropdownMenuItem(value: 'DISPATCH', child: Text('Customer Dispatch')),
                                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                              ],
                              onChanged: (v) => setState(() => _outwardType = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _partyType,
                              dropdownColor: AppTheme.darkSurface,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Recipient Entity Type*',
                                filled: true,
                                fillColor: AppTheme.darkBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'VENDOR', child: Text('Vendor / Supplier')),
                                DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer / Client')),
                                DropdownMenuItem(value: 'INTERNAL', child: Text('Internal Department')),
                                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                              ],
                              onChanged: (v) => setState(() => _partyType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Locations
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fromLocationCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'From Location*',
                                filled: true,
                                fillColor: AppTheme.darkBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _toLocationCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'To Location / Destination*',
                                hintText: 'e.g. Pune Factory / Client Site',
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

                      // Recipient party and person
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _partyNameCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Company / Party Name*',
                                hintText: 'e.g. Schneider Electric Ltd',
                                filled: true,
                                fillColor: AppTheme.darkBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _personNameCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Contact / Carrier Person',
                                hintText: 'Driver / Engineer Name',
                                filled: true,
                                fillColor: AppTheme.darkBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Purpose and Reference
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _purposeCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Purpose of Outward*',
                                hintText: 'e.g. Replacement testing under warranty',
                                filled: true,
                                fillColor: AppTheme.darkBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _vehicleCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Vehicle / Transit Number',
                                hintText: 'MH-12-PQ-4412',
                                filled: true,
                                fillColor: AppTheme.darkBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Items list
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Dispatched Materials / Documents',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () => setState(() => _items.add(_OutwardItemRow())),
                            icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                            label: const Text('Add Material', style: TextStyle(color: AppTheme.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Container(
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
                                  child: TextFormField(
                                    controller: item.nameCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Description / Item Name*',
                                      hintText: 'e.g. VFD Drive / Calibration Certificate',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: item.qtyCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Quantity*',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: item.unit,
                                    dropdownColor: AppTheme.darkSurface,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Unit',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'PCS', child: Text('PCS')),
                                      DropdownMenuItem(value: 'SETS', child: Text('SETS')),
                                      DropdownMenuItem(value: 'NOS', child: Text('NOS')),
                                      DropdownMenuItem(value: 'MTRS', child: Text('MTRS')),
                                      DropdownMenuItem(value: 'DOCS', child: Text('DOCS')),
                                    ],
                                    onChanged: (v) => setState(() => item.unit = v!),
                                  ),
                                ),
                                if (_items.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                    onPressed: () => setState(() => _items.removeAt(index)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _remarksCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'General Remarks / Instructions',
                          filled: true,
                          fillColor: AppTheme.darkBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
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
                      onPressed: _isSubmitting ? null : _submitOutward,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Creating...' : 'Create Outward Document'),
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

  Future<void> _submitOutward() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(purchaseRepositoryProvider);

      final itemsPayload = _items.map((it) {
        return {
          'materialName': it.nameCtrl.text.trim(),
          'quantity': double.parse(it.qtyCtrl.text.trim()),
          'unit': it.unit,
        };
      }).toList();

      final payload = {
        'outwardType': _outwardType,
        'fromLocation': _fromLocationCtrl.text.trim(),
        'toLocation': _toLocationCtrl.text.trim(),
        'partyType': _partyType,
        'partyName': _partyNameCtrl.text.trim(),
        'personName': _personNameCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'vehicleNumber': _vehicleCtrl.text.trim(),
        'remarks': _remarksCtrl.text.trim(),
        'items': itemsPayload,
      };

      await repo.createOutwardDocument(payload);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Outward Document created successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create outward document: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
