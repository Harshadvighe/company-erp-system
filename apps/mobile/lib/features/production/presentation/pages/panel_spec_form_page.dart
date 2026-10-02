import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/production/data/panel_manufacturing_repository.dart';

class _BOMRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController specCtrl = TextEditingController();
  final TextEditingController mfrCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController(text: '0');

  _BOMRow({String name = '', String spec = '', String mfr = '', int qty = 1, double price = 0}) {
    nameCtrl.text = name;
    specCtrl.text = spec;
    mfrCtrl.text = mfr;
    qtyCtrl.text = '$qty';
    priceCtrl.text = '${price.toInt()}';
  }

  double get totalPrice {
    final q = double.tryParse(qtyCtrl.text) ?? 0;
    final p = double.tryParse(priceCtrl.text) ?? 0;
    return q * p;
  }

  void dispose() {
    nameCtrl.dispose();
    specCtrl.dispose();
    mfrCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class PanelSpecFormPage extends ConsumerStatefulWidget {
  const PanelSpecFormPage({super.key});

  @override
  ConsumerState<PanelSpecFormPage> createState() => _PanelSpecFormPageState();
}

class _PanelSpecFormPageState extends ConsumerState<PanelSpecFormPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  String _panelType = 'VFD_PANEL';
  String _voltage = '415V 3-Phase';
  String _currentRating = '100A';
  int _pumpQty = 2;
  double _pumpHp = 7.5;
  String _controlType = 'AUTOMATIC_PLC';
  String _starterType = 'VFD';
  String _ipRating = 'IP55';
  String _enclosureType = 'POWDER_COATED_MS';

  final _labourCostCtrl = TextEditingController(text: '10000');
  final _overheadCostCtrl = TextEditingController(text: '5000');
  final _marginPercentCtrl = TextEditingController(text: '15');

  final List<_BOMRow> _bomRows = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerListProvider.notifier).loadCustomers();
    });

    // Populate default standard panel components
    _bomRows.addAll([
      _BOMRow(name: 'Variable Frequency Drive (VFD)', spec: '7.5 kW / 10 HP 415V 3-Phase', mfr: 'Schneider Electric', qty: 2, price: 28500),
      _BOMRow(name: 'Molded Case Circuit Breaker (MCCB)', spec: '100A 4-Pole 36kA', mfr: 'L&T', qty: 1, price: 6200),
      _BOMRow(name: 'Micro PLC Controller Unit', spec: '16 I/O Relay, RS-485 Modbus', mfr: 'Delta', qty: 1, price: 8500),
      _BOMRow(name: 'AC Magnetic Contactors', spec: '18A 3-Pole 230V AC Coil', mfr: 'Siemens', qty: 2, price: 1850),
      _BOMRow(name: 'Multifunction Digital Meter', spec: 'V, A, Hz, PF, kWh LED Display', mfr: 'Rishabh', qty: 1, price: 2400),
      _BOMRow(name: 'Internal Busbar & Wiring Harness', spec: 'Electrolytic Copper Busbar & FRLS Wire', mfr: 'Polycab', qty: 1, price: 9500),
    ]);
  }

  @override
  void dispose() {
    _labourCostCtrl.dispose();
    _overheadCostCtrl.dispose();
    _marginPercentCtrl.dispose();
    for (var r in _bomRows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _materialCost {
    return _bomRows.fold(0, (sum, r) => sum + r.totalPrice);
  }

  double get _labourCost {
    return double.tryParse(_labourCostCtrl.text) ?? 0;
  }

  double get _overheadCost {
    return double.tryParse(_overheadCostCtrl.text) ?? 0;
  }

  double get _marginPercent {
    return double.tryParse(_marginPercentCtrl.text) ?? 0;
  }

  double get _baseCost => _materialCost + _labourCost + _overheadCost;
  double get _finalPrice => _baseCost * (1 + _marginPercent / 100);

  void _addBOMRow() {
    setState(() {
      _bomRows.add(_BOMRow());
    });
  }

  void _removeBOMRow(int index) {
    if (_bomRows.length > 1) {
      setState(() {
        _bomRows[index].dispose();
        _bomRows.removeAt(index);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Customer for this panel design')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final bomItemsData = _bomRows.map((r) => {
      'componentName': r.nameCtrl.text.trim(),
      'specification': r.specCtrl.text.trim(),
      'manufacturer': r.mfrCtrl.text.trim(),
      'quantity': int.tryParse(r.qtyCtrl.text) ?? 1,
      'unitPrice': double.tryParse(r.priceCtrl.text) ?? 0,
    }).toList();

    final payload = {
      'customerId': _selectedCustomerId,
      'panelType': _panelType,
      'voltage': _voltage,
      'currentRating': _currentRating,
      'pumpQty': _pumpQty,
      'pumpHp': _pumpHp,
      'controlType': _controlType,
      'starterType': _starterType,
      'ipRating': _ipRating,
      'enclosureType': _enclosureType,
      'materialCost': _materialCost,
      'labourCost': _labourCost,
      'overheadCost': _overheadCost,
      'marginPercent': _marginPercent,
      'finalPrice': _finalPrice.round(),
      'status': 'DRAFT',
      'bomItems': bomItemsData,
    };

    final success = await ref.read(panelListProvider.notifier).createSpec(payload);

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Panel Specification & BOM saved successfully!')),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save panel specification. Check inputs.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customerListProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Panel Design & BOM Calculator'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleSubmit,
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: const Text('Save & Calculate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildGeneralSpecsCard(customersState),
                          const SizedBox(height: 20),
                          _buildBOMBuilderCard(currency),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: _buildLiveCostingCalculator(currency),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildGeneralSpecsCard(customersState),
                    const SizedBox(height: 20),
                    _buildBOMBuilderCard(currency),
                    const SizedBox(height: 20),
                    _buildLiveCostingCalculator(currency),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGeneralSpecsCard(CustomerListState customersState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Panel Specifications & Electrical Sizing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
            ],
          ),
          const Divider(height: 24),
          // Customer Selector
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Customer *',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            initialValue: _selectedCustomerId,
            items: customersState.customers.map((c) {
              return DropdownMenuItem<String>(
                value: c.id,
                child: Text('${c.companyName} (${c.customerCode})', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedCustomerId = val),
            validator: (val) => val == null ? 'Customer selection is required' : null,
          ),
          const SizedBox(height: 16),
          // Row 1: Panel Type & Voltage
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Panel Application Type'),
                  initialValue: _panelType,
                  items: const [
                    DropdownMenuItem(value: 'VFD_PANEL', child: Text('VFD Control Panel')),
                    DropdownMenuItem(value: 'BOOSTER_PUMP', child: Text('Booster Pump System')),
                    DropdownMenuItem(value: 'STP_PANEL', child: Text('STP / ETP Automation')),
                    DropdownMenuItem(value: 'HVAC_PANEL', child: Text('HVAC Chiller & Fan')),
                    DropdownMenuItem(value: 'DEWATERING_PANEL', child: Text('Dewatering Auto Panel')),
                  ],
                  onChanged: (v) => setState(() => _panelType = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Operating Voltage'),
                  initialValue: _voltage,
                  items: const [
                    DropdownMenuItem(value: '415V 3-Phase', child: Text('415V 3-Phase + N + E')),
                    DropdownMenuItem(value: '230V 1-Phase', child: Text('230V 1-Phase Single')),
                    DropdownMenuItem(value: '110V AC', child: Text('110V Control Bus')),
                  ],
                  onChanged: (v) => setState(() => _voltage = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 2: Current Rating & Pump HP
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Rated Busbar Current'),
                  initialValue: _currentRating,
                  items: const ['32A', '63A', '100A', '160A', '250A', '400A', '630A', '800A'].map((r) {
                    return DropdownMenuItem(value: r, child: Text(r));
                  }).toList(),
                  onChanged: (v) => setState(() => _currentRating = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Pumps Count'),
                  initialValue: _pumpQty,
                  items: [1, 2, 3, 4, 6].map((q) => DropdownMenuItem(value: q, child: Text('$q Pumps'))).toList(),
                  onChanged: (v) => setState(() => _pumpQty = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<double>(
                  decoration: const InputDecoration(labelText: 'Motor HP Rating'),
                  initialValue: _pumpHp,
                  items: [3.0, 5.0, 7.5, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0].map((hp) {
                    return DropdownMenuItem(value: hp, child: Text('$hp HP'));
                  }).toList(),
                  onChanged: (v) => setState(() => _pumpHp = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 3: Control Type & Starter Type
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Control System'),
                  initialValue: _controlType,
                  items: const [
                    DropdownMenuItem(value: 'AUTOMATIC_PLC', child: Text('PLC + HMI Automation')),
                    DropdownMenuItem(value: 'MANUAL', child: Text('Manual Push Buttons')),
                    DropdownMenuItem(value: 'STAR_DELTA', child: Text('Automatic Star-Delta Timer')),
                    DropdownMenuItem(value: 'DOL', child: Text('Direct On-Line (DOL)')),
                  ],
                  onChanged: (v) => setState(() => _controlType = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Starter Architecture'),
                  initialValue: _starterType,
                  items: const [
                    DropdownMenuItem(value: 'VFD', child: Text('Variable Frequency Drive (VFD)')),
                    DropdownMenuItem(value: 'SOFT_STARTER', child: Text('Soft Starter')),
                    DropdownMenuItem(value: 'STAR_DELTA', child: Text('Star-Delta Starter')),
                    DropdownMenuItem(value: 'DOL', child: Text('DOL Starter')),
                  ],
                  onChanged: (v) => setState(() => _starterType = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 4: IP Rating & Enclosure
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Ingress Protection (IP)'),
                  initialValue: _ipRating,
                  items: const [
                    DropdownMenuItem(value: 'IP55', child: Text('IP55 (Dust Protected, Water Jets)')),
                    DropdownMenuItem(value: 'IP65', child: Text('IP65 (Dust Tight, Water Jets)')),
                    DropdownMenuItem(value: 'IP42', child: Text('IP42 (Indoor Utility)')),
                  ],
                  onChanged: (v) => setState(() => _ipRating = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Enclosure Material'),
                  initialValue: _enclosureType,
                  items: const [
                    DropdownMenuItem(value: 'POWDER_COATED_MS', child: Text('Powder Coated CRCA MS')),
                    DropdownMenuItem(value: 'STAINLESS_STEEL_SS304', child: Text('Stainless Steel SS304')),
                    DropdownMenuItem(value: 'ALUMINIUM', child: Text('Cast Aluminium')),
                  ],
                  onChanged: (v) => setState(() => _enclosureType = v!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBOMBuilderCard(NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.format_list_bulleted, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Bill of Materials (BOM) Line Items',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _addBOMRow,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Component'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Component Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 3, child: Text('Specification / Rating', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Manufacturer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Unit Price (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Total (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 32),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _bomRows.length,
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final row = _bomRows[index];

              return Row(
                children: [
                  // Component Name
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: row.nameCtrl,
                      decoration: const InputDecoration(isDense: true, hintText: 'e.g. VFD Drive'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Spec
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: row.specCtrl,
                      decoration: const InputDecoration(isDense: true, hintText: 'e.g. 7.5kW 415V'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mfr
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: row.mfrCtrl,
                      decoration: const InputDecoration(isDense: true, hintText: 'Schneider / ABB'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Qty
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: row.qtyCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Unit Price
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: row.priceCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Row Total
                  Expanded(
                    flex: 2,
                    child: Text(
                      currency.format(row.totalPrice),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 13),
                    ),
                  ),
                  // Delete
                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                      onPressed: () => _removeBOMRow(index),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCostingCalculator(NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Live Cost & Pricing Calculator',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
            ],
          ),
          const Divider(height: 24),
          // Raw Material Total
          _buildLivePriceRow('1. BOM Material Cost', currency.format(_materialCost)),
          const SizedBox(height: 16),
          // Labour Cost
          TextFormField(
            controller: _labourCostCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '2. Labour & Wiring Assembly (₹)',
              prefixIcon: Icon(Icons.engineering_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // Overhead Cost
          TextFormField(
            controller: _overheadCostCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '3. Testing & Factory Overheads (₹)',
              prefixIcon: Icon(Icons.factory_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const Divider(height: 24),
          // Base Cost
          _buildLivePriceRow('Total Base Cost (1+2+3)', currency.format(_baseCost), isBold: true),
          const SizedBox(height: 16),
          // Margin Percent
          TextFormField(
            controller: _marginPercentCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Gross Profit Margin (%)',
              prefixIcon: Icon(Icons.percent),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const Divider(height: 24),
          // Final Price Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  AppTheme.success.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ESTIMATED SELLING PRICE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(
                  currency.format(_finalPrice.round()),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.success),
                ),
                const SizedBox(height: 4),
                Text('Formula: (${currency.format(_baseCost)} × ${(1 + _marginPercent / 100).toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmit,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Save Specification & BOM', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePriceRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: isBold ? AppTheme.darkText : AppTheme.darkTextSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 14, color: AppTheme.darkText, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}
