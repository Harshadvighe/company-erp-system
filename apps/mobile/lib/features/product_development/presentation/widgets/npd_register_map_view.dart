import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/npd_models.dart';
import '../../data/npd_repository.dart';

class NpdRegisterMapView extends ConsumerStatefulWidget {
  final NpdBoardData boardData;
  final VoidCallback onRefresh;

  const NpdRegisterMapView({
    super.key,
    required this.boardData,
    required this.onRefresh,
  });

  @override
  ConsumerState<NpdRegisterMapView> createState() => _NpdRegisterMapViewState();
}

class _NpdRegisterMapViewState extends ConsumerState<NpdRegisterMapView> {
  String _searchQuery = '';
  List<RegisterMapItem>? _localRegisters;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRegisters();
  }

  Future<void> _fetchRegisters() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(npdRepositoryProvider);
      final res = await repo.getRegisterMap(widget.boardData.project.id);
      final rawList = res['registers'] as List? ?? [];
      final list = rawList.map((r) => RegisterMapItem.fromJson(r as Map<String, dynamic>)).toList();
      setState(() {
        _localRegisters = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFrozen = widget.boardData.project.isRegisterMapFrozen;
    final registers = (_localRegisters ?? []).where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) ||
          r.pcReg.toLowerCase().contains(q) ||
          r.mbReg.toLowerCase().contains(q) ||
          (r.description?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Design Freeze Banner ─────────────────────────────────────────────
        if (isFrozen) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00B4D8).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFF00B4D8), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔒 Step 9 Design Freeze Active — Register Map is Immutable',
                        style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'All PC_REG and MB_REG addresses are locked for hardware fab & firmware sync. Modifications require formal Engineering Change Order (ECO).',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ─── Action & Search Strip ────────────────────────────────────────────
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
                    hintText: 'Search PC_REG, MB_REG, address, or signal name...',
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
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4CC9F0),
                  side: const BorderSide(color: Color(0xFF4CC9F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.code_rounded, size: 18),
                label: const Text('Export C-Header (.h)'),
                onPressed: () => _showCHeaderExportDialog(registers),
              ),
              const SizedBox(width: 10),
              if (!isFrozen)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A86FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Register'),
                  onPressed: () => _showAddRegisterDialog(),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Register Table ───────────────────────────────────────────────────
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (registers.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2128),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('No registers found.', style: TextStyle(color: Colors.white54)),
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
                  DataColumn(label: Text('PC Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Modbus Reg', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Addr (Dec)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Signal Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Data Type', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Default Val', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
                rows: registers.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r.pcReg, style: const TextStyle(color: Color(0xFF4CC9F0), fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                      DataCell(Text(r.mbReg, style: const TextStyle(color: Color(0xFFFF9F1C), fontFamily: 'monospace'))),
                      DataCell(Text('${r.address}', style: const TextStyle(color: Colors.white70))),
                      DataCell(Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(r.dataType, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      )),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: r.access == 'RW' ? Colors.teal.withOpacity(0.2) : Colors.blueGrey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(r.access, style: TextStyle(color: r.access == 'RW' ? Colors.tealAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      )),
                      DataCell(Text(r.defaultVal ?? '-', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'))),
                      DataCell(Text(r.description ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddRegisterDialog() {
    final pcController = TextEditingController(text: 'PC_REG_0x00');
    final mbController = TextEditingController(text: 'MB_REG_300');
    final addrController = TextEditingController();
    final nameController = TextEditingController();
    String dataType = 'UINT16';
    String access = 'R';
    final defaultController = TextEditingController(text: '0');
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2128),
          title: const Text('Add SSOT Register', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pcController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'PC Register ID (e.g. PC_REG_0x0005)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mbController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Modbus Register ID (e.g. MB_REG_30005)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addrController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Address (Decimal)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Signal Name (e.g. CURRENT_DRAW_MA)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: dataType,
                          dropdownColor: const Color(0xFF252932),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Data Type'),
                          items: ['UINT16', 'UINT32', 'INT16', 'INT32', 'FLOAT']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => dataType = v ?? 'UINT16'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: access,
                          dropdownColor: const Color(0xFF252932),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Access'),
                          items: ['R', 'W', 'RW']
                              .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => access = v ?? 'R'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: defaultController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Default Value'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Description / Scaling Factor'),
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
                final newItem = RegisterMapItem(
                  pcReg: pcController.text.trim(),
                  mbReg: mbController.text.trim(),
                  address: int.tryParse(addrController.text.trim()) ?? 0,
                  name: nameController.text.trim(),
                  dataType: dataType,
                  access: access,
                  defaultVal: defaultController.text.trim(),
                  description: descController.text.trim(),
                );

                final updatedList = [...(_localRegisters ?? []), newItem];
                try {
                  final repo = ref.read(npdRepositoryProvider);
                  await repo.updateRegisterMap(
                    widget.boardData.project.id,
                    updatedList.map<Map<String, dynamic>>((i) => i.toJson()).toList(),
                  );
                  Navigator.pop(ctx);
                  _fetchRegisters();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text('Save Register'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCHeaderExportDialog(List<RegisterMapItem> registers) {
    final buffer = StringBuffer();
    final pCode = widget.boardData.project.projectCode.replaceAll('-', '_');
    buffer.writeln('/**');
    buffer.writeln(' * @file    ${widget.boardData.project.projectCode}_registers.h');
    buffer.writeln(' * @brief   Single Source of Truth (SSOT) Register Map');
    buffer.writeln(' * @project ${widget.boardData.project.projectName}');
    buffer.writeln(' * @target  ${widget.boardData.project.targetMcu}');
    buffer.writeln(' * Generated by Saark ERP Product Development Module');
    buffer.writeln(' */\n');
    buffer.writeln('#ifndef ${pCode}_REGISTERS_H');
    buffer.writeln('#define ${pCode}_REGISTERS_H\n');
    buffer.writeln('#include <stdint.h>\n');

    buffer.writeln('/* --- Modbus & PC Register Addresses --- */');
    for (final r in registers) {
      final safeName = r.name.replaceAll(' ', '_').toUpperCase();
      buffer.writeln('#define REG_ADDR_${safeName.padRight(28)} (0x${r.address.toRadixString(16).padLeft(4, '0').toUpperCase()}U) /* ${r.pcReg} / ${r.mbReg} (${r.dataType}, ${r.access}) */');
    }

    buffer.writeln('\n#endif /* ${pCode}_REGISTERS_H */\n');
    final code = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2128),
        title: const Text('C-Header File Export (.h)', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF121418),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(color: Color(0xFF4CC9F0), fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2EC4B6)),
            icon: const Icon(Icons.copy, size: 16, color: Colors.black),
            label: const Text('Copy to Clipboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('C Header copied to clipboard!'), backgroundColor: Color(0xFF2EC4B6)),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}
