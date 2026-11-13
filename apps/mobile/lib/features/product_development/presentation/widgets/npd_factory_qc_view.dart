import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/npd_models.dart';
import '../../data/npd_repository.dart';

class NpdFactoryQcView extends ConsumerStatefulWidget {
  final NpdBoardData boardData;
  final VoidCallback onRefresh;

  const NpdFactoryQcView({
    super.key,
    required this.boardData,
    required this.onRefresh,
  });

  @override
  ConsumerState<NpdFactoryQcView> createState() => _NpdFactoryQcViewState();
}

class _NpdFactoryQcViewState extends ConsumerState<NpdFactoryQcView> {
  String _serialFilter = '';
  bool _isSimulating = false;

  @override
  Widget build(BuildContext context) {
    final logs = widget.boardData.recentTestLogs.where((l) {
      if (_serialFilter.isEmpty) return true;
      return l.serialNumber.toLowerCase().contains(_serialFilter.toLowerCase());
    }).toList();

    final passCount = widget.boardData.passTests;
    final failCount = widget.boardData.failTests;
    final totalTests = widget.boardData.totalTests;
    final yieldPct = totalTests > 0 ? ((passCount / totalTests) * 100).toStringAsFixed(1) : '100.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── QC KPI Strip ─────────────────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final cards = [
              _buildKpiCard('Total Ingested Units', '$totalTests', Icons.memory, const Color(0xFF3A86FF)),
              _buildKpiCard('Passed Units (FCT PASS)', '$passCount', Icons.check_circle_rounded, const Color(0xFF2EC4B6)),
              _buildKpiCard('Failed Units (FCT FAIL)', '$failCount', Icons.error_rounded, Colors.redAccent),
              _buildKpiCard('Production First Pass Yield', '$yieldPct%', Icons.analytics_rounded, const Color(0xFFFF9F1C)),
            ];

            if (isNarrow) {
              return Wrap(spacing: 8, runSpacing: 8, children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: c)).toList());
            }
            return Row(
              children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
            );
          },
        ),

        const SizedBox(height: 16),

        // ─── Action & Simulator Bar ───────────────────────────────────────────
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
                    hintText: 'Filter by Serial Number (e.g. SN-2026-NPD-0042)...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF16181D),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _serialFilter = val),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2EC4B6),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: _isSimulating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                    : const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text('Simulate Test Rig PASS', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _isSimulating ? null : () => _simulateTestLog('PASS'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                icon: const Icon(Icons.bug_report_outlined, size: 16),
                label: const Text('Simulate FAIL'),
                onPressed: _isSimulating ? null : () => _simulateTestLog('FAIL'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Test Logs List ───────────────────────────────────────────────────
        if (logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2128),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(Icons.terminal_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 10),
                const Text('No factory QC test logs recorded yet.', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 8),
                const Text(
                  'Automated test fixtures submit logs to POST /api/erp/npd/factory-test during Step 23.',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildTestLogRow(log);
            },
          ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestLogRow(NpdUnitTestLog log) {
    final isPass = log.testStatus == 'PASS';
    final statusColor = isPass ? const Color(0xFF2EC4B6) : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Status Pill
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Text(
              log.testStatus,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 14),

          // Serial & Test Station
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      log.serialNumber,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.testStationId ?? 'FCT-01',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FW: ${log.firmwareVersion ?? 'v1.0.0'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  children: [
                    Text(
                      '3.3V Rail: ${(log.voltageRailsResult?['3v3'] ?? 3.30)}V',
                      style: const TextStyle(color: Color(0xFF4CC9F0), fontSize: 12),
                    ),
                    Text(
                      'Current: ${log.currentConsumptionMa?.toStringAsFixed(1) ?? '85.4'} mA',
                      style: const TextStyle(color: Color(0xFFFF9F1C), fontSize: 12),
                    ),
                    Text(
                      'RF RSSI: ${log.rfRssiDbm?.toStringAsFixed(1) ?? '-52.0'} dBm',
                      style: const TextStyle(color: Color(0xFF2EC4B6), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Timestamp & Terminal Log Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                log.testedAt.toLocal().toString().substring(0, 19),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showRawLogModal(log),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.terminal, size: 14, color: Color(0xFF3A86FF)),
                    SizedBox(width: 4),
                    Text('View Rig Log', style: TextStyle(color: Color(0xFF3A86FF), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRawLogModal(NpdUnitTestLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2128),
        title: Text('Terminal Diagnostic: ${log.serialNumber}', style: const TextStyle(color: Colors.white, fontSize: 15)),
        content: SizedBox(
          width: 580,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101216),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              log.rawTerminalLog ?? '[RAW LOG NOT AVAILABLE]',
              style: const TextStyle(color: Color(0xFF2EC4B6), fontFamily: 'monospace', fontSize: 12, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _simulateTestLog(String status) async {
    setState(() => _isSimulating = true);
    final rnd = Random();
    final serial = 'SN-2026-NPD-${(1000 + rnd.nextInt(9000))}';
    final v3v3 = status == 'PASS' ? (3.29 + rnd.nextDouble() * 0.04) : 2.85;
    final current = status == 'PASS' ? (80.0 + rnd.nextDouble() * 15.0) : 340.5;
    final rssi = status == 'PASS' ? (-55.0 + rnd.nextDouble() * 10.0) : -92.0;

    final terminalBuffer = StringBuffer();
    terminalBuffer.writeln('[RIG] Initializing Pogo-Pin Testbed FCT-01...');
    terminalBuffer.writeln('[RIG] Clamping DUT Serial: $serial');
    terminalBuffer.writeln('[POW] Applying 24V DC input rail... OK');
    terminalBuffer.writeln('[POW] Verifying 3.3V LDO Output: ${v3v3.toStringAsFixed(3)}V (${status == 'PASS' ? 'PASS' : 'FAIL - BROWNOUT'})');
    terminalBuffer.writeln('[CUR] Quiescent current: ${current.toStringAsFixed(1)} mA (${status == 'PASS' ? 'IN BUDGET' : 'OVERCURRENT'})');
    terminalBuffer.writeln('[JTAG] Connecting MCU Xtensa LX7... CONNECTED');
    terminalBuffer.writeln('[UART] Boot message captured: Saark OS v1.0.0 (Rev A)');
    terminalBuffer.writeln('[I2C] Scanning bus 0x00..0x7F: Found 0x68 (RTC), 0x48 (TMP102)');
    terminalBuffer.writeln('[RS485] Modbus echo test address 0x01: OK (115200 8N1)');
    terminalBuffer.writeln('[RF] 2.4GHz Wi-Fi RSSI: ${rssi.toStringAsFixed(1)} dBm');
    terminalBuffer.writeln('[SUMMARY] FCT Test Result: $status');

    try {
      final repo = ref.read(npdRepositoryProvider);
      await repo.ingestFactoryTestLog({
        'projectId': widget.boardData.project.id,
        'serialNumber': serial,
        'stepNumber': 23,
        'testStationId': 'FCT-RIG-01',
        'operatorName': 'Automated Testbed',
        'testStatus': status,
        'voltageRailsResult': {'3v3': double.parse(v3v3.toStringAsFixed(2)), '5v0': 5.02, 'status': status},
        'currentConsumptionMa': double.parse(current.toStringAsFixed(1)),
        'rfRssiDbm': double.parse(rssi.toStringAsFixed(1)),
        'peripheralsTested': {'i2c': true, 'spi': true, 'uart': true, 'modbus': status == 'PASS'},
        'rawTerminalLog': terminalBuffer.toString(),
        'failureReason': status == 'FAIL' ? '3.3V Rail Undervoltage Brownout' : null,
      });

      setState(() => _isSimulating = false);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulated Test Rig Ingestion: $serial ($status)'),
            backgroundColor: status == 'PASS' ? const Color(0xFF2EC4B6) : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSimulating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simulation error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}

