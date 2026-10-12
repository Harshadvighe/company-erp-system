import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';

class CallsListPage extends ConsumerStatefulWidget {
  const CallsListPage({super.key});

  @override
  ConsumerState<CallsListPage> createState() => _CallsListPageState();
}

class _CallsListPageState extends ConsumerState<CallsListPage> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'ALL';
  final _filterOptions = ['ALL', 'CONNECTED', 'INTERESTED', 'CALL_BACK', 'BUSY', 'NO_ANSWER'];

  List<dynamic> _calls = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCalls() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(crmRepositoryProvider);
      final res = await repo.getCalls(
        callOutcome: _selectedFilter == 'ALL' ? null : _selectedFilter,
        search: _searchController.text.trim(),
      );

      setState(() {
        _calls = res['items'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} min';
  }

  Color _getOutcomeColor(String? outcome) {
    switch (outcome?.toUpperCase()) {
      case 'CONNECTED':
      case 'INTERESTED':
        return Colors.green;
      case 'CALL_BACK':
        return Colors.orange;
      case 'BUSY':
      case 'NO_ANSWER':
        return Colors.amber.shade800;
      case 'NOT_INTERESTED':
      case 'WRONG_NUMBER':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  void _openLogCallDialog() async {
    final customersRepo = ref.read(customersRepositoryProvider);
    final customersRes = await customersRepo.getCustomers(limit: 100);
    final customersList = customersRes['items'] as List<dynamic>? ?? [];

    if (!mounted) return;

    String? selectedCustomerId;
    String callType = 'OUTBOUND';
    String callOutcome = 'CONNECTED';
    final durationController = TextEditingController(text: '120');
    final notesController = TextEditingController();
    final recordingUrlController = TextEditingController();
    bool dataSent = false;
    final selectedDataTypes = <String>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Log Phone Call & Attachments'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Customer / Company *', border: OutlineInputBorder()),
                    items: customersList.map((c) => DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(c['companyName'] ?? ''),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedCustomerId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: callType,
                          decoration: const InputDecoration(labelText: 'Direction', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'OUTBOUND', child: Text('Outbound Call')),
                            DropdownMenuItem(value: 'INBOUND', child: Text('Inbound Call')),
                          ],
                          onChanged: (v) => setModalState(() => callType = v ?? 'OUTBOUND'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: callOutcome,
                          decoration: const InputDecoration(labelText: 'Outcome', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'CONNECTED', child: Text('Connected')),
                            DropdownMenuItem(value: 'INTERESTED', child: Text('Interested')),
                            DropdownMenuItem(value: 'CALL_BACK', child: Text('Call Back')),
                            DropdownMenuItem(value: 'BUSY', child: Text('Busy')),
                            DropdownMenuItem(value: 'NO_ANSWER', child: Text('No Answer')),
                            DropdownMenuItem(value: 'NOT_INTERESTED', child: Text('Not Interested')),
                          ],
                          onChanged: (v) => setModalState(() => callOutcome = v ?? 'CONNECTED'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (Seconds)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.timer_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Discussion Notes *', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: recordingUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Audio Recording URL / Storage Path (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.mic_none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Data Sent Checklist
                  CheckboxListTile(
                    title: const Text('Data / Documents Sent to Client'),
                    value: dataSent,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setModalState(() => dataSent = v ?? false),
                  ),
                  if (dataSent) ...[
                    Wrap(
                      spacing: 8,
                      children: ['QUOTATION', 'CATALOG', 'SLD_DRAWING', 'PANEL_ESTIMATE', 'COMPANY_PROFILE'].map((type) {
                        final isSelected = selectedDataTypes.contains(type);
                        return FilterChip(
                          label: Text(type.replaceAll('_', ' ')),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                selectedDataTypes.add(type);
                              } else {
                                selectedDataTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final repo = ref.read(crmRepositoryProvider);
                  await repo.createCall({
                    'customerId': selectedCustomerId,
                    'callType': callType,
                    'callOutcome': callOutcome,
                    'durationSec': int.tryParse(durationController.text) ?? 60,
                    'notes': notesController.text.trim(),
                    'recordingUrl': recordingUrlController.text.trim().isEmpty ? null : recordingUrlController.text.trim(),
                    'dataSent': dataSent,
                    'dataTypes': selectedDataTypes,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call logged successfully!')));
                  _loadCalls();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save Call Log'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/crm/dashboard');
            }
          },
        ),
        title: const Text('Phone Calls & Call Recordings'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCalls),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips & Search
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.darkSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search calls by notes, customer, outcome...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.darkTextSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.darkTextSecondary),
                            onPressed: () {
                              _searchController.clear();
                              _loadCalls();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.darkCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                  ),
                  onSubmitted: (_) => _loadCalls(),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((opt) {
                      final isSelected = _selectedFilter == opt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(opt.replaceAll('_', ' ')),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedFilter = opt);
                              _loadCalls();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Calls List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _calls.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_missed_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No Phone Calls Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Log customer phone conversations, recordings, and sent documents.', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCalls,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _calls.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final call = _calls[index];
                                final activity = call['activity'] as Map<String, dynamic>?;
                                final customer = activity?['customer'] as Map<String, dynamic>?;
                                final recordings = call['recordings'] as List<dynamic>? ?? [];
                                final hasRecording = recordings.isNotEmpty || call['recordingUrl'] != null;
                                final duration = call['durationSec'] ?? 0;
                                final outcome = call['callOutcome'] as String? ?? 'CONNECTED';
                                final isOutbound = call['callType'] == 'OUTBOUND';
                                final createdAt = activity?['createdAt'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(activity!['createdAt']))
                                    : '-';

                                List<dynamic> dataTypes = [];
                                if (call['dataTypes'] != null) {
                                  try {
                                    // Parse if string
                                    if (call['dataTypes'] is String) {
                                      dataTypes = (call['dataTypes'] as String)
                                          .replaceAll('[', '')
                                          .replaceAll(']', '')
                                          .replaceAll('"', '')
                                          .split(',')
                                          .map((s) => s.trim())
                                          .where((s) => s.isNotEmpty)
                                          .toList();
                                    }
                                  } catch (_) {}
                                }

                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Direction + Outcome + Date
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  isOutbound ? Icons.call_made : Icons.call_received,
                                                  color: isOutbound ? Colors.blue : Colors.green,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isOutbound ? 'OUTBOUND' : 'INBOUND',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isOutbound ? Colors.blue : Colors.green),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getOutcomeColor(outcome).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: _getOutcomeColor(outcome).withValues(alpha: 0.4)),
                                                  ),
                                                  child: Text(
                                                    outcome.replaceAll('_', ' '),
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getOutcomeColor(outcome)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(createdAt, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Customer & Contact
                                        if (customer != null)
                                          InkWell(
                                            onTap: () => context.push('/crm/companies/${customer['id']}'),
                                            child: Text(
                                              customer['companyName'] ?? 'Customer',
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          activity?['description'] ?? activity?['subject'] ?? 'Call notes',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(height: 10),

                                        // Duration & Data Sent
                                        Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(_formatDuration(duration), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            if (call['dataSent'] == true) ...[
                                              const SizedBox(width: 16),
                                              const Icon(Icons.send_outlined, size: 14, color: Colors.green),
                                              const SizedBox(width: 4),
                                              const Text('Data Sent', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                                            ],
                                          ],
                                        ),

                                        // Data Sent Chips
                                        if (dataTypes.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            children: dataTypes.map((dt) => Chip(
                                              label: Text('$dt', style: const TextStyle(fontSize: 10)),
                                              padding: EdgeInsets.zero,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            )).toList(),
                                          ),
                                        ],

                                        // Call Recording Player Bar
                                        if (hasRecording) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.indigo.shade200),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(Icons.mic, color: Colors.indigo, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Call Recording Attached', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                                  ],
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.play_circle_fill, color: Colors.indigo, size: 24),
                                                  tooltip: 'Play Recording',
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Playing call recording audio stream...')),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLogCallDialog,
        icon: const Icon(Icons.phone),
        label: const Text('Log Phone Call'),
      ),
    );
  }
}

