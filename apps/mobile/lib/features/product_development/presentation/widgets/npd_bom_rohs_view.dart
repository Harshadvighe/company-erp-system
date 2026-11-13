import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/npd_models.dart';
import '../../data/npd_repository.dart';

class NpdBomRohsView extends ConsumerStatefulWidget {
  final NpdBoardData boardData;
  final VoidCallback onRefresh;

  const NpdBomRohsView({
    super.key,
    required this.boardData,
    required this.onRefresh,
  });

  @override
  ConsumerState<NpdBomRohsView> createState() => _NpdBomRohsViewState();
}

class _NpdBomRohsViewState extends ConsumerState<NpdBomRohsView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final bomItems = widget.boardData.bomLinks.where((b) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return b.designator.toLowerCase().contains(q) ||
          b.mpn.toLowerCase().contains(q) ||
          (b.manufacturer?.toLowerCase().contains(q) ?? false) ||
          (b.description?.toLowerCase().contains(q) ?? false);
    }).toList();

    final totalCount = widget.boardData.totalBomCount;
    final rohsCount = widget.boardData.rohsCompliantCount;
    final rohsPct = widget.boardData.rohsCompliantPct;
    final is100Rohs = totalCount > 0 && rohsCount == totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── RoHS 100% Compliance KPI Card ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: is100Rohs
                ? const Color(0xFF2EC4B6).withOpacity(0.12)
                : totalCount == 0
                    ? const Color(0xFF1E2128)
                    : Colors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: is100Rohs
                  ? const Color(0xFF2EC4B6).withOpacity(0.4)
                  : totalCount == 0
                      ? Colors.white12
                      : Colors.amber.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                is100Rohs
                    ? Icons.verified_rounded
                    : totalCount == 0
                        ? Icons.info_outline
                        : Icons.warning_amber_rounded,
                color: is100Rohs
                    ? const Color(0xFF2EC4B6)
                    : totalCount == 0
                        ? Colors.white70
                        : Colors.amber,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      is100Rohs
                          ? '100% RoHS 3 / REACH Verified — Step 14 PO Gate Ready'
                          : totalCount == 0
                              ? 'Engineering BOM Empty — Import or Add Components'
                              : 'Step 14 Hard Stop: RoHS Compliance is $rohsPct% ($rohsCount / $totalCount items)',
                      style: TextStyle(
                        color: is100Rohs
                            ? const Color(0xFF2EC4B6)
                            : totalCount == 0
                                ? Colors.white
                                : Colors.amber,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      is100Rohs
                          ? 'All electronic parts conform to EU RoHS Directive 2011/65/EU and 2015/863.'
                          : totalCount == 0
                              ? 'Upload BOM line items from KiCad/Altium or add critical parts below.'
                              : 'Step 14 PO release is strictly blocked until every component certificate is logged.',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (totalCount == 0)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A86FF),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Seed Standard BOM'),
                  onPressed: () => _seedStandardBom(),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Search & Add Component ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2128),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search designator (R1, U2), MPN, or manufacturer...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF16181D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Component'),
                onPressed: () => _showAddComponentDialog(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── BOM Table ────────────────────────────────────────────────────────
        if (bomItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2128),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('No BOM items match query.', style: TextStyle(color: Colors.white54)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2128),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF252932)),
                columns: const [
                  DataColumn(label: Text('Designator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('MPN (Part Number)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Manufacturer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Package', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Qty/PCB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('RoHS Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Lifecycle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Target Cost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
                rows: bomItems.map((b) {
                  return DataRow(
                    cells: [
                      DataCell(Text(b.designator, style: const TextStyle(color: Color(0xFF4CC9F0), fontWeight: FontWeight.bold))),
                      DataCell(Text(b.mpn, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'))),
                      DataCell(Text(b.manufacturer ?? 'Generic', style: const TextStyle(color: Colors.white70))),
                      DataCell(Text(b.package ?? 'SMD', style: const TextStyle(color: Colors.white60))),
                      DataCell(Text('${b.quantityPerPcb}', style: const TextStyle(color: Colors.white70))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.isRohsCompliant ? const Color(0xFF2EC4B6).withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          b.isRohsCompliant ? 'RoHS 3 Pass' : 'Non-RoHS',
                          style: TextStyle(
                            color: b.isRohsCompliant ? const Color(0xFF2EC4B6) : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
                      DataCell(Text(b.lifecycleStatus, style: TextStyle(color: b.lifecycleStatus == 'ACTIVE' ? Colors.tealAccent : Colors.orangeAccent, fontSize: 11))),
                      DataCell(Text('₹${b.targetUnitCost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70))),
                      DataCell(Text(b.description ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddComponentDialog() {
    final desController = TextEditingController();
    final mpnController = TextEditingController();
    final mfgController = TextEditingController();
    final pkgController = TextEditingController(text: '0805');
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController(text: '0.00');
    final descController = TextEditingController();
    bool isRohs = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2128),
          title: const Text('Add Component to BOM', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: desController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Designator (e.g. U1, R4, C12)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Quantity Per PCB'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mpnController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Manufacturer Part Number (MPN)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: mfgController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Manufacturer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: pkgController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Package / Footprint'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Target Unit Cost (INR)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Description / Function'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isRohs,
                        activeColor: const Color(0xFF2EC4B6),
                        onChanged: (v) => setDialogState(() => isRohs = v ?? true),
                      ),
                      const Text('100% RoHS 3 / REACH Compliant', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A86FF)),
              onPressed: () async {
                final currentItems = widget.boardData.bomLinks.map((b) => {
                  'designator': b.designator,
                  'mpn': b.mpn,
                  'manufacturer': b.manufacturer,
                  'description': b.description,
                  'package': b.package,
                  'quantityPerPcb': b.quantityPerPcb,
                  'isRohsCompliant': b.isRohsCompliant,
                  'targetUnitCost': b.targetUnitCost,
                }).toList();

                currentItems.add({
                  'designator': desController.text.trim().toUpperCase(),
                  'mpn': mpnController.text.trim(),
                  'manufacturer': mfgController.text.trim(),
                  'description': descController.text.trim(),
                  'package': pkgController.text.trim(),
                  'quantityPerPcb': int.tryParse(qtyController.text.trim()) ?? 1,
                  'isRohsCompliant': isRohs,
                  'targetUnitCost': double.tryParse(costController.text.trim()) ?? 0.0,
                });

                try {
                  final repo = ref.read(npdRepositoryProvider);
                  await repo.syncBom(widget.boardData.project.id, currentItems);
                  Navigator.pop(ctx);
                  widget.onRefresh();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text('Add Part'),
            ),
          ],
        ),
      ),
    );
  }

  void _seedStandardBom() async {
    final sampleItems = [
      {
        'designator': 'U1',
        'mpn': 'ESP32-S3-WROOM-1-N8R8',
        'manufacturer': 'Espressif Systems',
        'description': 'Dual-core Xtensa 240MHz MCU, 8MB Flash, 8MB PSRAM, Wi-Fi & BLE 5',
        'package': 'Module SMD-41',
        'quantityPerPcb': 1,
        'isRohsCompliant': true,
        'targetUnitCost': 295.0,
      },
      {
        'designator': 'U2',
        'mpn': 'MAX13487EESA+',
        'manufacturer': 'Analog Devices',
        'description': 'AutoDirection Half-Duplex RS-485/RS-422 Transceiver with ESD Protection',
        'package': 'SOIC-8',
        'quantityPerPcb': 1,
        'isRohsCompliant': true,
        'targetUnitCost': 85.0,
      },
      {
        'designator': 'U3',
        'mpn': 'MP1584EN-LF-Z',
        'manufacturer': 'Monolithic Power',
        'description': '3A, 28V, 1.5MHz Step-Down DC-DC Switching Regulator (12V/24V to 3.3V)',
        'package': 'SOIC-8-EP',
        'quantityPerPcb': 1,
        'isRohsCompliant': true,
        'targetUnitCost': 42.0,
      },
      {
        'designator': 'U4',
        'mpn': 'PC817C',
        'manufacturer': 'Sharp / Everlight',
        'description': 'High Isolation Voltage Photocoupler (5kV)',
        'package': 'DIP-4 / SOP-4',
        'quantityPerPcb': 4,
        'isRohsCompliant': true,
        'targetUnitCost': 8.5,
      },
      {
        'designator': 'C1, C2',
        'mpn': 'GRM188R61C106MA73D',
        'manufacturer': 'Murata',
        'description': '10uF 16V X5R 10% 0603 Ceramic Capacitor',
        'package': '0603',
        'quantityPerPcb': 2,
        'isRohsCompliant': true,
        'targetUnitCost': 3.2,
      },
      {
        'designator': 'R1, R2',
        'mpn': 'RC0603FR-0710KL',
        'manufacturer': 'Yageo',
        'description': '10k Ohm 1% 1/10W Thick Film Chip Resistor',
        'package': '0603',
        'quantityPerPcb': 2,
        'isRohsCompliant': true,
        'targetUnitCost': 0.8,
      },
      {
        'designator': 'D1',
        'mpn': 'SMBJ15CA',
        'manufacturer': 'Littelfuse',
        'description': '600W Bidirectional TVS Diode for 12V/24V Power Rail Transient Protection',
        'package': 'DO-214AA (SMB)',
        'quantityPerPcb': 1,
        'isRohsCompliant': true,
        'targetUnitCost': 14.5,
      },
    ];

    try {
      final repo = ref.read(npdRepositoryProvider);
      await repo.syncBom(widget.boardData.project.id, sampleItems);
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard BOM seeded successfully!'), backgroundColor: Color(0xFF2EC4B6)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seeding BOM: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

