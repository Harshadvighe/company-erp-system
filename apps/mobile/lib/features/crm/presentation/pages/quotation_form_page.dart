import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

class QuotationFormPage extends ConsumerStatefulWidget {
  final String? editId;
  final String? prefillCustomerId;
  final String? prefillOpportunityId;
  final String? prefillPanelSpecId;

  const QuotationFormPage({
    super.key,
    this.editId,
    this.prefillCustomerId,
    this.prefillOpportunityId,
    this.prefillPanelSpecId,
  });

  @override
  ConsumerState<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationItemData {
  String? productId;
  String itemCode;
  String description;
  String hsnSac;
  int quantity;
  String unit;
  double unitPrice;
  double discountPercent;
  double gstPercent;

  _QuotationItemData({
    this.itemCode = 'PANEL-01',
    this.description = 'Control Panel Automation System',
    this.quantity = 1,
    this.unitPrice = 0,
  }) : productId = null, hsnSac = '8537', unit = 'Nos', discountPercent = 0, gstPercent = 18.0;

  double get taxableAmount {
    final subtotal = quantity * unitPrice;
    final discount = subtotal * (discountPercent / 100);
    return subtotal - discount;
  }

  double get gstAmount => taxableAmount * (gstPercent / 100);
  double get totalAmount => taxableAmount + gstAmount;
}

class _QuotationFormPageState extends ConsumerState<QuotationFormPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  String? _selectedOpportunityId;
  String? _selectedPanelSpecId;
  String? _customerGstin;
  String? _customerState;

  final _subjectController = TextEditingController(text: 'Commercial Proposal for Electrical Control Panel & Automation Systems');
  final _paymentTermsController = TextEditingController(text: '50% Advance, 50% Against Proforma Invoice before Dispatch');
  final _deliveryTermsController = TextEditingController(text: '2 to 3 weeks from receipt of PO and approved drawings');
  final _freightTermsController = TextEditingController(text: 'Ex-Works Pune. Freight extra at actuals.');
  final _warrantyTermsController = TextEditingController(text: '18 months from supply or 12 months from commissioning.');
  final _notesController = TextEditingController();

  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  bool _isInterState = false;
  final double _overallDiscountAmount = 0;
  bool _isSubmitting = false;

  final List<_QuotationItemData> _items = [
    _QuotationItemData(
      itemCode: 'PANEL-01',
      description: 'VFD Control Panel - 415V 3-Phase, IP55 Powder Coated Enclosure',
      unitPrice: 125000,
      quantity: 1,
    ),
  ];

  List<dynamic> _customers = [];
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.prefillCustomerId;
    _selectedOpportunityId = widget.prefillOpportunityId;
    _selectedPanelSpecId = widget.prefillPanelSpecId;
    _loadCustomers();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _paymentTermsController.dispose();
    _deliveryTermsController.dispose();
    _freightTermsController.dispose();
    _warrantyTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final repo = ref.read(customersRepositoryProvider);
      final res = await repo.getCustomers(limit: 100);
      final list = res['items'] as List<dynamic>? ?? [];
      setState(() {
        _customers = list;
        _isLoadingCustomers = false;
      });

      if (_selectedCustomerId != null) {
        _onCustomerSelected(_selectedCustomerId);
      }
    } catch (_) {
      setState(() => _isLoadingCustomers = false);
    }
  }

  void _onCustomerSelected(String? customerId) {
    if (customerId == null) return;
    final customer = _customers.firstWhere(
      (c) => c['id'] == customerId,
      orElse: () => null,
    );
    if (customer != null) {
      setState(() {
        _selectedCustomerId = customerId;
        _customerGstin = customer['gstin'];
        _customerState = customer['state'];
        // If customer state is outside Maharashtra (State code 27), default to inter-state IGST
        if (_customerState != null && !_customerState!.toLowerCase().contains('maharashtra')) {
          _isInterState = true;
        }
      });
    }
  }

  double get _subtotal => _items.fold(0, (sum, itm) => sum + (itm.quantity * itm.unitPrice));
  double get _itemDiscounts => _items.fold(0, (sum, itm) => sum + ((itm.quantity * itm.unitPrice) * (itm.discountPercent / 100)));
  double get _taxableAmount => _items.fold(0, (sum, itm) => sum + itm.taxableAmount);
  double get _cgstAmount => _isInterState ? 0 : (_taxableAmount * 0.09);
  double get _sgstAmount => _isInterState ? 0 : (_taxableAmount * 0.09);
  double get _igstAmount => _isInterState ? (_taxableAmount * 0.18) : 0;
  double get _totalGst => _cgstAmount + _sgstAmount + _igstAmount;
  double get _grandTotal => _taxableAmount + _totalGst - _overallDiscountAmount;

  void _addItem() {
    setState(() {
      _items.add(_QuotationItemData(
        itemCode: 'ITM-${_items.length + 1}',
        description: 'Standard Automation & Switchgear Component',
        unitPrice: 10000,
        quantity: 1,
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one line item is required')),
      );
      return;
    }
    setState(() => _items.removeAt(index));
  }

  Future<void> _submitQuotation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Customer for this Quotation')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(salesRepositoryProvider);
      final payload = {
        'customerId': _selectedCustomerId,
        'opportunityId': _selectedOpportunityId,
        'panelSpecId': _selectedPanelSpecId,
        'subject': _subjectController.text.trim(),
        'validUntil': _validUntil.toIso8601String(),
        'isInterState': _isInterState,
        'discountAmount': _overallDiscountAmount,
        'paymentTerms': _paymentTermsController.text.trim(),
        'deliveryTerms': _deliveryTermsController.text.trim(),
        'freightTerms': _freightTermsController.text.trim(),
        'warrantyTerms': _warrantyTermsController.text.trim(),
        'notes': _notesController.text.trim(),
        'items': _items.map((i) => {
          'itemCode': i.itemCode,
          'description': i.description,
          'hsnSac': i.hsnSac,
          'quantity': i.quantity,
          'unit': i.unit,
          'unitPrice': i.unitPrice,
          'discountPercent': i.discountPercent,
          'gstPercent': i.gstPercent,
        }).toList(),
      };

      final res = await repo.createQuotation(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quotation ${res['code']} created successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create quotation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Create Commercial Quotation'),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _submitQuotation,
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, color: Colors.white),
            label: const Text('SAVE QUOTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
            // ─── 1. Customer & General Info Card ───────────────────────────
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.business, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('Customer & Header Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),

                    // Customer Selection
                    _isLoadingCustomers
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedCustomerId,
                            decoration: const InputDecoration(
                              labelText: 'Customer / Company *',
                              prefixIcon: Icon(Icons.corporate_fare),
                              border: OutlineInputBorder(),
                            ),
                            items: _customers.map((c) {
                              return DropdownMenuItem<String>(
                                value: c['id'],
                                child: Text('${c['companyName']} (${c['city'] ?? 'India'})'),
                              );
                            }).toList(),
                            onChanged: _onCustomerSelected,
                            validator: (val) => val == null ? 'Please select customer' : null,
                          ),
                    const SizedBox(height: 12),

                    if (_customerGstin != null || _customerState != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GSTIN: ${_customerGstin ?? 'Unregistered'}', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600, fontSize: 12)),
                            Text('State: ${_customerState ?? 'Not specified'}', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Subject
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Quotation Subject *',
                        prefixIcon: Icon(Icons.subject),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Subject is required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Validity & Inter-state switch
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _validUntil,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 180)),
                              );
                              if (picked != null) setState(() => _validUntil = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Valid Until',
                                prefixIcon: Icon(Icons.event),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(DateFormat('dd MMM yyyy').format(_validUntil)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.darkCard,
                              border: Border.all(color: AppTheme.darkBorder),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tax Type', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(_isInterState ? 'IGST (18%)' : 'CGST+SGST (9%+9%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                                Switch(
                                  value: _isInterState,
                                  activeThumbColor: AppTheme.primaryColor,
                                  onChanged: (val) => setState(() => _isInterState = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── 2. Line Items Table Editor ───────────────────────────────
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.list_alt, color: AppTheme.primaryColor),
                            SizedBox(width: 8),
                            Text('Itemized Quotation Lines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    ..._items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppTheme.primaryColor,
                                      child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Line #${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeItem(idx),
                                  tooltip: 'Delete Line',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: item.itemCode,
                                    decoration: const InputDecoration(labelText: 'Item Code', border: OutlineInputBorder()),
                                    onChanged: (v) => item.itemCode = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: item.hsnSac,
                                    decoration: const InputDecoration(labelText: 'HSN / SAC', border: OutlineInputBorder()),
                                    onChanged: (v) => item.hsnSac = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: '${item.quantity}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                                    onChanged: (v) {
                                      setState(() {
                                        item.quantity = int.tryParse(v) ?? 1;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: item.unit,
                                    decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                                    onChanged: (v) => item.unit = v,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: item.description,
                              decoration: const InputDecoration(labelText: 'Item Description & Technical Specifications *', border: OutlineInputBorder()),
                              maxLines: 2,
                              onChanged: (v) => item.description = v,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: '${item.unitPrice.toInt()}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Rate (₹)',
                                      prefixText: '₹ ',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        item.unitPrice = double.tryParse(v) ?? 0;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: '${item.discountPercent}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Disc %',
                                      suffixText: '%',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        item.discountPercent = double.tryParse(v) ?? 0;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: '${item.gstPercent}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'GST %',
                                      suffixText: '%',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        item.gstPercent = double.tryParse(v) ?? 18.0;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Taxable: ${currencyFormatter.format(item.taxableAmount)}', style: const TextStyle(fontSize: 12)),
                                  Text('GST: ${currencyFormatter.format(item.gstAmount)}', style: const TextStyle(fontSize: 12)),
                                  Text(
                                    'Total: ${currencyFormatter.format(item.totalAmount)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── 3. Terms & Conditions ─────────────────────────────────────
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.gavel, color: AppTheme.primaryColor),
                title: const Text('Commercial Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _paymentTermsController,
                    decoration: const InputDecoration(labelText: 'Payment Terms', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _deliveryTermsController,
                    decoration: const InputDecoration(labelText: 'Delivery Period', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _freightTermsController,
                    decoration: const InputDecoration(labelText: 'Freight & Transportation', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _warrantyTermsController,
                    decoration: const InputDecoration(labelText: 'Warranty & Guarantee', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Internal / Special Notes', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── 4. Tax & Grand Total Summary Card ──────────────────────────
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calculate, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('Quotation Financial Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items Gross Subtotal:'),
                        Text(currencyFormatter.format(_subtotal)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Item Discounts:'),
                        Text('- ${currencyFormatter.format(_itemDiscounts)}', style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Taxable Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(currencyFormatter.format(_taxableAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (!_isInterState) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('CGST (9%):'),
                          Text(currencyFormatter.format(_cgstAmount)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('SGST (9%):'),
                          Text(currencyFormatter.format(_sgstAmount)),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('IGST (18%):'),
                          Text(currencyFormatter.format(_igstAmount)),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GRAND TOTAL (INC. TAX):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                        Text(
                          currencyFormatter.format(_grandTotal),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitQuotation,
                icon: const Icon(Icons.send_outlined),
                label: Text(_isSubmitting ? 'GENERATING OFFER...' : 'GENERATE COMMERCIAL QUOTATION'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ),
);
  }
}
