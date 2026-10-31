import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/production/data/panel_manufacturing_repository.dart';

class BoosterPumpCalculatorWorkspaceView extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;

  const BoosterPumpCalculatorWorkspaceView({
    super.key,
    this.onBackToDashboard,
  });

  @override
  ConsumerState<BoosterPumpCalculatorWorkspaceView> createState() =>
      _BoosterPumpCalculatorWorkspaceViewState();
}

class _BoosterPumpCalculatorWorkspaceViewState
    extends ConsumerState<BoosterPumpCalculatorWorkspaceView> {
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 2);

  // ─── 20 Input Parameters Matching Exact UI Form ───────────
  String _productType = 'HYPN';
  String _pumpModel = 'Submersible Pump';
  String _switchgearMake = 'Schneider';
  String _panelClass = 'DOMESTIC';
  String _vfdMake = 'Delta';
  String _phase = '3PH';
  final _pumpCurrentCtrl = TextEditingController(text: '40');
  final _pumpHpCtrl = TextEditingController(text: '20');
  int _numPumps = 3;
  String _starterType = 'DOL';
  int _numVfd = 3;
  String _multiVfdBypass = 'NO';
  String _olrRequired = 'NO';
  String _indicatorRequired = 'YES';
  String _panelType = 'INDOOR';
  String _thermalProtection = 'YES';
  String _humidityProtection = 'NO';
  final _inputWireLengthCtrl = TextEditingController(text: '5 meter');
  final _outputWireMultiplierCtrl = TextEditingController(text: '9');

  // Customer Selection
  String? _selectedCustomerId;
  final _customerMarginCtrl = TextEditingController(text: '0');

  // Calculation State
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, dynamic>? _calculationResult;
  String _bomSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerListProvider.notifier).loadCustomers();
      _runCalculation();
    });
  }

  @override
  void dispose() {
    _pumpCurrentCtrl.dispose();
    _pumpHpCtrl.dispose();
    _inputWireLengthCtrl.dispose();
    _outputWireMultiplierCtrl.dispose();
    _customerMarginCtrl.dispose();
    super.dispose();
  }

  double get _calculatedKw {
    final hp = double.tryParse(_pumpHpCtrl.text) ?? 20;
    return double.parse((hp * 0.7457).toStringAsFixed(1));
  }

  Future<void> _runCalculation() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(panelManufacturingRepositoryProvider);
      final hp = double.tryParse(_pumpHpCtrl.text) ?? 20;
      final flc = double.tryParse(_pumpCurrentCtrl.text) ?? 40;
      final margin = double.tryParse(_customerMarginCtrl.text) ?? 0;
      final outMultiplier = double.tryParse(_outputWireMultiplierCtrl.text) ?? 9;

      final payload = {
        'product_type': _productType,
        'pump_model': _pumpModel,
        'switchgear_make': _switchgearMake,
        'panel_class': _panelClass,
        'vfd_make': _vfdMake,
        'phase': _phase,
        'pump_hp': hp,
        'pump_current': flc,
        'num_pumps': _numPumps,
        'starter_type': _starterType,
        'num_vfd': _numVfd,
        'multivfd_bypass': _multiVfdBypass,
        'olr_required': _olrRequired,
        'indicator_required': _indicatorRequired,
        'panel_type': _panelType,
        'thermal_protection': _thermalProtection,
        'humidity_protection': _humidityProtection,
        'input_wire_type': _inputWireLengthCtrl.text,
        'output_wire_multiplier': outMultiplier,
        'customerId': _selectedCustomerId,
        'customer_margin_percent': margin,
      };

      final res = await repo.calculateBoosterPump(payload);
      if (mounted) {
        setState(() {
          _calculationResult = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calculation Error: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  Future<void> _saveAsSpecification() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(panelManufacturingRepositoryProvider);
      final hp = double.tryParse(_pumpHpCtrl.text) ?? 20;
      final flc = double.tryParse(_pumpCurrentCtrl.text) ?? 40;
      final margin = double.tryParse(_customerMarginCtrl.text) ?? 0;
      final outMultiplier = double.tryParse(_outputWireMultiplierCtrl.text) ?? 9;

      final payload = {
        'product_type': _productType,
        'pump_model': _pumpModel,
        'switchgear_make': _switchgearMake,
        'panel_class': _panelClass,
        'vfd_make': _vfdMake,
        'phase': _phase,
        'pump_hp': hp,
        'pump_current': flc,
        'num_pumps': _numPumps,
        'starter_type': _starterType,
        'num_vfd': _numVfd,
        'multivfd_bypass': _multiVfdBypass,
        'olr_required': _olrRequired,
        'indicator_required': _indicatorRequired,
        'panel_type': _panelType,
        'thermal_protection': _thermalProtection,
        'humidity_protection': _humidityProtection,
        'input_wire_type': _inputWireLengthCtrl.text,
        'output_wire_multiplier': outMultiplier,
        'customerId': _selectedCustomerId,
        'customer_margin_percent': margin,
      };

      final res = await repo.saveBoosterPumpSpec(payload);
      if (mounted) {
        setState(() => _isSaving = false);
        final specCode = res['spec']?['panelCode'] ?? 'New Spec';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as Panel Specification: $specCode!'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save Error: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  void _exportCsv() {
    final bom = (_calculationResult?['bom'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (bom.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('SKU,Item Name,Category,Specification,Make,Quantity,Unit DP (Rs.),Total DP (Rs.)');
    for (final item in bom) {
      buffer.writeln(
        '"${item['sku']}","${item['itemName']}","${item['category']}","${item['specification']}","${item['make']}","${item['quantity']}","${item['unitPrice']}","${item['totalPrice']}"',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('BOM CSV copied to clipboard! (Ready to paste in Excel)'),
        backgroundColor: Color(0xFFF15A24),
      ),
    );
  }

  void _showCosterDataSheetModal() {
    final derived = _calculationResult?['derived'] ?? {};
    final pricing = _calculationResult?['pricing'] ?? {};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: const Row(
          children: [
            Icon(Icons.analytics_rounded, color: Color(0xFFF15A24)),
            SizedBox(width: 8),
            Text('Coster Data Sheet & Sizing Formulas', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModalSection('A. Kilowatt & Current Formulation', [
                  'kW = HP × 0.7457 = ${_pumpHpCtrl.text} × 0.7457 = $_calculatedKw kW',
                  'Individual Pump FLC = ${_pumpCurrentCtrl.text} A',
                  'Total Panel Current = Individual FLC × VFDs = ${derived['totalCurrent']} A',
                ]),
                const SizedBox(height: 12),
                _buildModalSection('B. Starter & Contactor Count', [
                  'Starter Mode: ${derived['starterType']}',
                  'Contactors Count: ${derived['contactorCount']} Units',
                  'Star-Delta Timers: ${derived['timerCount']} Units',
                  'OLR Count: ${derived['olrCount']} | SPP Count: ${derived['sppCount']}',
                ]),
                const SizedBox(height: 12),
                _buildModalSection('C. Breaker & Wire Sizing (AM4/AN4 IFS Ladder)', [
                  'Controller: ${derived['controllerType']} (${derived['powerSupply']})',
                  'Main Incomer: ${derived['mainIncomerType']} (${derived['mccbRating']}A)',
                  'Busbar Assembly Required: ${derived['isBusbarRequired'] ? "YES (>100A)" : "NO"}',
                  'Incomer Wire: ${derived['inputWireGaugeSqmm']} sq mm Flexible Polycab',
                  'Pump Output Wire: ${derived['outputWireGaugeSqmm']} sq mm Flexible Polycab',
                  'Control Wire: 0.5 sq mm Grey (300m)',
                ]),
                const SizedBox(height: 12),
                _buildModalSection('D. Costing & Labor Formulation', [
                  'Labor Formula: (VFDs + MCCB + Busbar) × Rs.450',
                  'Labor Cost: ${_currencyFormat.format(pricing['laborCost'] ?? 0)}',
                  'Total Material Cost (DP): ${_currencyFormat.format(pricing['totalMaterialCost'] ?? 0)}',
                  'Base Panel Cost: ${_currencyFormat.format(pricing['basePanelCost'] ?? 0)}',
                  'Grand Total Estimated Price: ${_currencyFormat.format(pricing['grandTotal'] ?? 0)}',
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFFF15A24))),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSection(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF33363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...lines.map((l) => Text('• $l', style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
        ],
      ),
    );
  }

  // ─── ADD CUSTOMER DIALOG (MATCHING LEGACY SAARK ERP MODAL) ───────────────
  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final pctCtrl = TextEditingController(text: '0');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFF15A24), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Add Customer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: Colors.white54, size: 18),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF33363D), height: 20),

                  // Customer Name Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 120,
                        child: Text(
                          'Customer Name:',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: TextField(
                            controller: nameCtrl,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF141518),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(3),
                                borderSide: const BorderSide(color: Color(0xFF383A42)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(3),
                                borderSide: const BorderSide(color: Color(0xFF383A42)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(3),
                                borderSide: const BorderSide(color: Color(0xFFF15A24)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Percentage Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 120,
                        child: Text(
                          'Percentage:',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: TextField(
                            controller: pctCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF141518),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(3),
                                borderSide: const BorderSide(color: Color(0xFF383A42)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(3),
                                borderSide: const BorderSide(color: Color(0xFF383A42)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(3),
                                borderSide: const BorderSide(color: Color(0xFFF15A24)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Save Button
                  SizedBox(
                    width: 120,
                    height: 32,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF15A24),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a Customer Name'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              setDialogState(() => isSaving = true);
                              try {
                                final repo = ref.read(panelManufacturingRepositoryProvider);
                                final pct = double.tryParse(pctCtrl.text.trim()) ?? 0.0;
                                final newCust = await repo.quickAddCustomer(
                                  companyName: name,
                                  percentage: pct,
                                );

                                // Reload customer list in Riverpod
                                await ref.read(customerListProvider.notifier).loadCustomers();

                                if (!mounted) return;

                                setState(() {
                                  _selectedCustomerId = newCust['id']?.toString();
                                  _customerMarginCtrl.text = pct.toString();
                                });
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Customer "$name" added ($pct%). Recalculating BOM...'),
                                      backgroundColor: const Color(0xFFF15A24),
                                    ),
                                  );
                                }
                                // Recalculate BOM immediately
                                _runCalculation();
                              } catch (e) {
                                setDialogState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to add customer: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111215),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 1. Sub-Header: Back to Dashboard Bar ──────────────────
          _buildBackToDashboardBar(),

          // ─── 2. Tab Strip: "Material & Labor Calculator" ───────────
          _buildTabStrip(),

          // ─── 3. Action Title & Customer Selection Strip ────────────
          _buildWorkspaceHeaderBar(),

          // ─── 4. Main Scrollable Content Area ───────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Upper Split: Left = Inputs (Yellow Section) | Right = Document Canvas
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Box: Inputs (Yellow Section)
                      Expanded(
                        flex: 6,
                        child: _buildYellowInputsBox(),
                      ),
                      const SizedBox(width: 14),
                      // Right Box: White Document Preview Sheet
                      Expanded(
                        flex: 4,
                        child: _buildRightDocumentSheet(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Bottom Section: Material Breakdown & BOM Table
                  _buildBottomBOMSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Sub-Header Bar (← Back to Dashboard) ──────────────────────────────
  Widget _buildBackToDashboardBar() {
    return Container(
      height: 38,
      color: const Color(0xFF222327),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: widget.onBackToDashboard,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF15A24),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Back to Dashboard',
                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'F.Y. 2026-2027',
            style: TextStyle(color: Color(0xFF8E9297), fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ─── 2. Sub-Tab Strip ──────────────────────────────────────────────────────
  Widget _buildTabStrip() {
    return Container(
      height: 36,
      color: const Color(0xFF18191C),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F23),
          border: Border.all(color: const Color(0xFFF15A24), width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Material & Labor Calculator',
          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ─── 3. Action Title & Customer Selection Strip ────────────────────────────
  Widget _buildWorkspaceHeaderBar() {
    final customers = ref.watch(customerListProvider).customers;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF141518),
      child: Row(
        children: [
          const Text(
            'Material & Labor Calculator',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          const Text(
            'Select Customer:  ',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Container(
            height: 30,
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1D21),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF383A40)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCustomerId,
                isDense: true,
                dropdownColor: const Color(0xFF222428),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                hint: const Text('Standard Customer', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Standard Customer (0%)'),
                  ),
                  ...customers.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.companyName} (${c.customerCode})', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedCustomerId = val;
                    if (val != null) {
                      final found = customers.where((c) => c.id == val).toList();
                      if (found.isNotEmpty) {
                        final valPct = found.first.valuationPercentage;
                        if (valPct != 50.0) {
                          _customerMarginCtrl.text = valPct.toString();
                        }
                      }
                    } else {
                      _customerMarginCtrl.text = '0';
                    }
                  });
                  _runCalculation();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1D21),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF383A40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Margin %: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                SizedBox(
                  width: 42,
                  child: TextField(
                    controller: _customerMarginCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _runCalculation(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: _showAddCustomerDialog,
            child: const Text('+ Add Customer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: _showCosterDataSheetModal,
            child: const Text('Open Price List', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── 4. Left Box: Inputs (Yellow Section) ──────────────────────────────────
  Widget _buildYellowInputsBox() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191A1E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2E3138)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Label in Orange/Amber
          const Text(
            'Inputs (Yellow Section)',
            style: TextStyle(
              color: Color(0xFFF15A24),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),

          // 10 Paired Input Rows
          // Row 1
          _buildPairedInputsRow(
            leftLabel: 'Product type:',
            leftWidget: _buildDropdown(
              value: _productType,
              items: const ['HYPN', 'STP', 'WTP', 'DEWATRING'],
              onChanged: (v) => setState(() => _productType = v!),
            ),
            rightLabel: 'PUMP TYPE:',
            rightWidget: _buildDropdown(
              value: _pumpModel,
              items: const [
                'Submersible Pump',
                'Booster Pump',
                'Vertical Inline Pump',
                'Horizontal Pump',
                'Dewatering Pump',
                'Sump Pump',
                'Sewage Pump',
                'Drainage Pump',
                'Monoblock Pump',
                'Openwell',
              ],
              onChanged: (v) {
                setState(() {
                  _pumpModel = v!;
                  final hp = double.tryParse(_pumpHpCtrl.text) ?? 20;
                  final factor = (_pumpModel.contains('Booster') ||
                          _pumpModel.contains('Inline') ||
                          _pumpModel.contains('Horizontal'))
                      ? 1.5
                      : 2.0;
                  _pumpCurrentCtrl.text = (hp * factor).toStringAsFixed(1);
                });
                _runCalculation();
              },
            ),
          ),

          // Row 2
          _buildPairedInputsRow(
            leftLabel: 'SWTICHGARE MAKE:',
            leftWidget: _buildDropdown(
              value: _switchgearMake,
              items: const ['Schneider', 'L&T', 'SIMENS'],
              onChanged: (v) => setState(() => _switchgearMake = v!),
            ),
            rightLabel: 'PANEL TYPE:',
            rightWidget: _buildDropdown(
              value: _panelClass,
              items: const ['DOMESTIC', 'INDUSTRIAL'],
              onChanged: (v) => setState(() => _panelClass = v!),
            ),
          ),

          // Row 3
          _buildPairedInputsRow(
            leftLabel: 'VFD MAKE:',
            leftWidget: _buildDropdown(
              value: _vfdMake,
              items: const [
                'Delta',
                'Danfoss',
                'Schneider Electric',
                'Siemens',
                'ABB',
                'Yaskawa',
                'Mitsubishi Electric',
                'Fuji Electric',
                'L&T',
                'CG Power',
                'Inovance',
              ],
              onChanged: (v) => setState(() => _vfdMake = v!),
            ),
            rightLabel: 'PUMP TYPE 3PH/1PH:',
            rightWidget: _buildDropdown(
              value: _phase,
              items: const ['3PH', '1PH'],
              onChanged: (v) => setState(() => _phase = v!),
            ),
          ),

          // Row 4
          _buildPairedInputsRow(
            leftLabel: 'Pump Current:',
            leftWidget: _buildTextField(_pumpCurrentCtrl, onChanged: (_) => _runCalculation()),
            rightLabel: 'Pump HP:',
            rightWidget: _buildTextField(_pumpHpCtrl, onChanged: (_) {
              setState(() {});
              _runCalculation();
            }),
          ),

          // Row 5
          _buildPairedInputsRow(
            leftLabel: 'Kilo Watt:',
            leftWidget: _buildReadOnlyTextField('$_calculatedKw'),
            rightLabel: 'Number Of Pump:',
            rightWidget: _buildDropdown(
              value: '$_numPumps',
              items: const ['1', '2', '3', '4', '5', '6'],
              onChanged: (v) {
                setState(() {
                  _numPumps = int.parse(v!);
                  if (_numVfd > _numPumps) _numVfd = _numPumps;
                });
                _runCalculation();
              },
            ),
          ),

          // Row 6
          _buildPairedInputsRow(
            leftLabel: 'Stater Type:',
            leftWidget: _buildDropdown(
              value: _starterType,
              items: const ['Automatic Selector', 'DOL', 'STARDELTA'],
              onChanged: (v) => setState(() => _starterType = v!),
            ),
            rightLabel: 'Number of VFD:',
            rightWidget: _buildDropdown(
              value: '$_numVfd',
              items: List.generate(_numPumps + 1, (i) => '$i'),
              onChanged: (v) => setState(() => _numVfd = int.parse(v!)),
            ),
          ),

          // Row 7
          _buildPairedInputsRow(
            leftLabel: 'IF MULTIVFD THEN BYPASS PROVISON NEEDED OR NOT:',
            leftWidget: _buildDropdown(
              value: _multiVfdBypass,
              items: const ['YES', 'NO'],
              onChanged: (v) => setState(() => _multiVfdBypass = v!),
            ),
            rightLabel: 'OLR REQUIRMENT:',
            rightWidget: _buildDropdown(
              value: _olrRequired,
              items: const ['YES', 'NO'],
              onChanged: (v) => setState(() => _olrRequired = v!),
            ),
          ),

          // Row 8
          _buildPairedInputsRow(
            leftLabel: 'INDICTOR NEEDED OR NOT:',
            leftWidget: _buildDropdown(
              value: _indicatorRequired,
              items: const ['YES', 'NO'],
              onChanged: (v) => setState(() => _indicatorRequired = v!),
            ),
            rightLabel: 'PANEL TYPE:',
            rightWidget: _buildDropdown(
              value: _panelType,
              items: const ['INDOOR', 'OUTDOOR', 'RITAL'],
              onChanged: (v) => setState(() => _panelType = v!),
            ),
          ),

          // Row 9
          _buildPairedInputsRow(
            leftLabel: 'Thermal protection:',
            leftWidget: _buildDropdown(
              value: _thermalProtection,
              items: const ['YES', 'NO'],
              onChanged: (v) => setState(() => _thermalProtection = v!),
            ),
            rightLabel: 'Humidity protection:',
            rightWidget: _buildDropdown(
              value: _humidityProtection,
              items: const ['YES', 'NO'],
              onChanged: (v) => setState(() => _humidityProtection = v!),
            ),
          ),

          // Row 10
          _buildPairedInputsRow(
            leftLabel: 'Input Wire Type (meters):',
            leftWidget: _buildTextField(_inputWireLengthCtrl, onChanged: (_) => _runCalculation()),
            rightLabel: 'Output Wire Length Multiplier:',
            rightWidget: _buildTextField(_outputWireMultiplierCtrl, onChanged: (_) => _runCalculation()),
          ),

          const SizedBox(height: 14),

          // Row of 6 Orange Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOrangeActionButton(
                label: 'Calculate BOM',
                isLoading: _isLoading,
                onPressed: _runCalculation,
              ),
              _buildOrangeActionButton(
                label: 'Download BOM in Excel',
                onPressed: _exportCsv,
              ),
              _buildOrangeActionButton(
                label: 'Download BOM in PDF',
                onPressed: _exportCsv,
              ),
              _buildOrangeActionButton(
                label: '+ Attach BOM List',
                isLoading: _isSaving,
                onPressed: _saveAsSpecification,
              ),
              _buildOrangeActionButton(
                label: '+ Add Material List',
                onPressed: _saveAsSpecification,
              ),
              _buildOrangeActionButton(
                label: 'Coster Data Sheet',
                onPressed: _showCosterDataSheetModal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 5. Right Box: White Document Preview Sheet ───────────────────────────
  Widget _buildRightDocumentSheet() {
    final customers = ref.watch(customerListProvider).customers;
    final derived = _calculationResult?['derived'] ?? {};
    final pricing = _calculationResult?['pricing'] ?? {};
    final summary = (_calculationResult?['incomerSummary'] as List?)?.cast<String>() ?? [];

    Customer? selectedCustomer;
    if (_selectedCustomerId != null) {
      final matches = customers.where((c) => c.id == _selectedCustomerId).toList();
      if (matches.isNotEmpty) selectedCustomer = matches.first;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sheet Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAARK EXPLORATION PRIVATE LIMITED',
                      style: TextStyle(
                        color: Color(0xFFD84315),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Booster Pump Control Panel Specification & Sizing Sheet',
                      style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.black54),
                tooltip: 'Copy Output Text',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  final text = summary.join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sizing summary copied to clipboard!')),
                  );
                },
              ),
            ],
          ),

          const Divider(color: Colors.black26, height: 16),

          // Sizing Derivations Box
          const Text(
            'WORKBOOK-DERIVED CALCULATIONS:',
            style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _buildSheetRow(
            'Customer / Party:',
            selectedCustomer != null
                ? '${selectedCustomer.companyName} (${selectedCustomer.customerCode})'
                : 'Standard Customer (0%)',
          ),
          _buildSheetRow('Customer Margin / Adj:', '${_customerMarginCtrl.text}%'),
          _buildSheetRow('Product / Model:', '$_productType / $_pumpModel'),
          _buildSheetRow('Switchgear / VFD:', '$_switchgearMake / $_vfdMake'),
          _buildSheetRow('Panel Application:', '$_panelClass (${derived['controllerType'] ?? "HMI"})'),
          _buildSheetRow('Power & Current:', '${_pumpHpCtrl.text} HP ($_calculatedKw kW) • FLC ${_pumpCurrentCtrl.text} A'),
          _buildSheetRow('Total Panel Current:', '${derived['totalCurrent'] ?? 120.0} A'),
          _buildSheetRow('Starter & Contactors:', '${derived['starterType'] ?? "STARDELTA"} (${derived['contactorCount'] ?? 6} Contactors)'),
          _buildSheetRow('Main Incomer Type:', '${derived['mainIncomerType'] ?? "THREE POLE MCCB"} (${derived['mccbRating'] ?? 125}A)'),
          _buildSheetRow('Busbar Required:', derived['isBusbarRequired'] == true ? 'YES (>100A)' : 'NO'),
          _buildSheetRow('Incomer Wire:', '${derived['inputWireGaugeSqmm'] ?? 35.0} sq mm Flexible Polycab'),
          _buildSheetRow('Pump Output Wire:', '${derived['outputWireGaugeSqmm'] ?? 2.5} sq mm Flexible Polycab'),

          const Divider(color: Colors.black26, height: 16),

          // Breaker Logic
          const Text(
            'AUTO BREAKER SELECTION LOGIC:',
            style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: summary
                  .map(
                    (s) => Text(
                      s,
                      style: const TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  )
                  .toList(),
            ),
          ),

          const Divider(color: Colors.black26, height: 16),

          // Commercial Price Quote Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetPriceRow('Total Material Cost (DP):', _currencyFormat.format(pricing['totalMaterialCost'] ?? 182189.50)),
                _buildSheetPriceRow('Wiring & Assembly Labor:', _currencyFormat.format(pricing['laborCost'] ?? 2250.00)),
                _buildSheetPriceRow(
                  'Customer Adjustment (${pricing['customerAdjustmentPercent'] ?? _customerMarginCtrl.text}%):',
                  '${((pricing['customerAdjustmentAmount'] as num?)?.toDouble() ?? 0.0) >= 0 ? "+" : ""}${_currencyFormat.format((pricing['customerAdjustmentAmount'] as num?)?.toDouble() ?? 0.0)}',
                ),
                const Divider(color: Color(0xFFFFB74D), height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GRAND TOTAL:',
                      style: TextStyle(color: Color(0xFFD84315), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _currencyFormat.format(pricing['grandTotal'] ?? 184439.50),
                      style: const TextStyle(color: Color(0xFFD84315), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 6. Bottom Section: Material Breakdown & BOM Table ─────────────────────
  Widget _buildBottomBOMSection() {
    final rawBom = (_calculationResult?['bom'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pricing = _calculationResult?['pricing'] ?? {};

    final filteredBom = rawBom.where((item) {
      if (_bomSearchQuery.isEmpty) return true;
      final q = _bomSearchQuery.toLowerCase();
      final name = (item['itemName'] ?? '').toString().toLowerCase();
      final sku = (item['sku'] ?? '').toString().toLowerCase();
      final cat = (item['category'] ?? '').toString().toLowerCase();
      final make = (item['make'] ?? '').toString().toLowerCase();
      return name.contains(q) || sku.contains(q) || cat.contains(q) || make.contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191A1E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2E3138)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF222327),
            child: Row(
              children: [
                const Text(
                  'Material Breakdown & BOM',
                  style: TextStyle(
                    color: Color(0xFFF15A24),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '(${rawBom.length} items)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const Spacer(),
                SizedBox(
                  width: 240,
                  height: 28,
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Filter SKU, component...',
                      hintStyle: const TextStyle(color: Color(0xFF72767D), fontSize: 10.5),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF72767D), size: 14),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      filled: true,
                      fillColor: const Color(0xFF141518),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => _bomSearchQuery = val),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable BOM Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 32,
              headingRowColor: WidgetStateProperty.all(const Color(0xFF141518)),
              headingTextStyle: const TextStyle(
                color: Color(0xFFB0B3B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              dataTextStyle: const TextStyle(color: Colors.white, fontSize: 11),
              horizontalMargin: 12,
              columnSpacing: 14,
              columns: const [
                DataColumn(label: Text('SKU')),
                DataColumn(label: Text('ITEM NAME')),
                DataColumn(label: Text('CATEGORY')),
                DataColumn(label: Text('SPECIFICATION')),
                DataColumn(label: Text('MAKE')),
                DataColumn(label: Text('QTY', textAlign: TextAlign.right)),
                DataColumn(label: Text('UNIT DP (Rs.)', textAlign: TextAlign.right)),
                DataColumn(label: Text('TOTAL DP (Rs.)', textAlign: TextAlign.right)),
              ],
              rows: filteredBom.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isZebra = idx % 2 == 1;

                return DataRow(
                  color: WidgetStateProperty.all(isZebra ? const Color(0xFF202226) : const Color(0xFF191A1E)),
                  cells: [
                    DataCell(Text(
                      '${item['sku'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF15A24)),
                    )),
                    DataCell(Text(
                      '${item['itemName'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )),
                    DataCell(Text(
                      '${item['category'] ?? ''}',
                      style: const TextStyle(color: Color(0xFF00B4D8), fontSize: 10.5),
                    )),
                    DataCell(Text('${item['specification'] ?? ''}')),
                    DataCell(Text('${item['make'] ?? ''}')),
                    DataCell(Text(
                      '${item['quantity'] ?? 1}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text(
                      _currencyFormat.format(item['unitPrice'] ?? 0),
                      textAlign: TextAlign.right,
                    )),
                    DataCell(Text(
                      _currencyFormat.format(item['totalPrice'] ?? 0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF81C784)),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),

          // Total Bar at Bottom of Table
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF131417),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL MATERIAL COST (DP): ${_currencyFormat.format(pricing['totalMaterialCost'] ?? 182189.50)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'LABOR & ASSEMBLY COST: ${_currencyFormat.format(pricing['laborCost'] ?? 2250.00)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'GRAND TOTAL ESTIMATED COST: ${_currencyFormat.format(pricing['grandTotal'] ?? 184439.50)}',
                  style: const TextStyle(color: Color(0xFFF15A24), fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reusable Input Row Builders ──────────────────────────────────────────
  Widget _buildPairedInputsRow({
    required String leftLabel,
    required Widget leftWidget,
    required String rightLabel,
    required Widget rightWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          // Left Field
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    leftLabel,
                    style: const TextStyle(color: Color(0xFFB0B3B8), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(flex: 5, child: leftWidget),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Right Field
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    rightLabel,
                    style: const TextStyle(color: Color(0xFFB0B3B8), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(flex: 5, child: rightWidget),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF383A40)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          isExpanded: true,
          dropdownColor: const Color(0xFF222428),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (val) {
            onChanged(val);
            _runCalculation();
          },
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, {ValueChanged<String>? onChanged}) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          filled: true,
          fillColor: const Color(0xFF141518),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFF383A40)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Color(0xFFF15A24)),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReadOnlyTextField(String val) {
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101113),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: Text(
        val,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOrangeActionButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF15A24),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 1,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildSheetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 10.5)),
          ),
          Expanded(
            flex: 6,
            child: Text(value, style: const TextStyle(color: Colors.black, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetPriceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87, fontSize: 10.5)),
          Text(value, style: const TextStyle(color: Colors.black, fontSize: 10.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
