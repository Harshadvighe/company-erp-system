import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';

class LeadsListPage extends ConsumerStatefulWidget {
  const LeadsListPage({super.key});

  @override
  ConsumerState<LeadsListPage> createState() => _LeadsListPageState();
}

class _LeadsListPageState extends ConsumerState<LeadsListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  final _statusFilters = ['ALL', 'NEW', 'CONTACTED', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'WON', 'LOST'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final status = _statusFilters[_tabController.index];
        ref.read(leadListProvider.notifier).loadLeads(
              status: status == 'ALL' ? null : status,
              search: _searchController.text,
            );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leadListProvider.notifier).loadLeads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadListProvider);
    final dashAsync = ref.watch(crmDashboardProvider);

    return Scaffold(
      body: Column(
        children: [
          // Stats Row
          dashAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (d) => _buildStatsRow(d),
          ),
          // Search
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.darkBorder))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      final status = _statusFilters[_tabController.index];
                      ref.read(leadListProvider.notifier).loadLeads(search: v, status: status == 'ALL' ? null : status);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search leads…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showCreateLeadSheet(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Lead'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          // Status Tabs
          Container(
            color: AppTheme.darkSurface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              tabs: _statusFilters.map((s) => Tab(text: s)).toList(),
            ),
          ),
          // Leads List
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _buildError(state.error!)
                    : state.leads.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: state.leads.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _LeadCard(
                              lead: state.leads[i],
                              onStatusChange: (status) => ref.read(leadListProvider.notifier).updateStatus(state.leads[i]['id'] as String, status),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.darkBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatChip(label: 'Total', value: '${d['totalLeads'] ?? 0}', color: Colors.blue),
            const SizedBox(width: 8),
            _StatChip(label: 'New', value: '${d['newLeads'] ?? 0}', color: Colors.green),
            const SizedBox(width: 8),
            _StatChip(label: 'Won', value: '${d['wonLeads'] ?? 0}', color: AppTheme.primary),
            const SizedBox(width: 8),
            _StatChip(label: 'Lost', value: '${d['lostLeads'] ?? 0}', color: AppTheme.error),
            const SizedBox(width: 8),
            _StatChip(label: 'Follow-ups', value: '${d['pendingFollowUps'] ?? 0}', color: AppTheme.warning),
            const SizedBox(width: 8),
            _StatChip(label: 'Conversion', value: '${d['conversionRate'] ?? 0}%', color: Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text('No leads found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateLeadSheet,
            icon: const Icon(Icons.add),
            label: const Text('Create Lead'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: Colors.grey)),
      ElevatedButton(onPressed: () => ref.read(leadListProvider.notifier).loadLeads(), child: const Text('Retry')),
    ]));
  }

  void _showCreateLeadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LeadFormSheet(onSuccess: () {
        ref.read(leadListProvider.notifier).loadLeads();
      }),
    );
  }
}

// ─── Lead Card ────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final ValueChanged<String> onStatusChange;

  const _LeadCard({required this.lead, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final status = lead['status'] as String? ?? 'NEW';
    final priority = lead['priority'] as String? ?? 'MEDIUM';
    final followUp = lead['nextFollowUp'] != null ? DateTime.tryParse(lead['nextFollowUp'] as String) : null;
    final isOverdue = followUp != null && followUp.isBefore(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead['companyName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(lead['leadNumber'] as String? ?? '', style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                _PriorityBadge(priority: priority),
                const SizedBox(width: 6),
                _StatusDropdown(status: status, onChanged: onStatusChange),
              ],
            ),
            if (lead['productInterest'] != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.category_outlined, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(lead['productInterest'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (lead['contactPerson'] != null) ...[
                  const Icon(Icons.person_outline, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(lead['contactPerson'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 12),
                ],
                if (lead['phone'] != null) ...[
                  const Icon(Icons.phone_outlined, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(lead['phone'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                if (lead['estimatedValue'] != null) ...[
                  const Spacer(),
                  Text('₹${lead['estimatedValue']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
                ],
              ],
            ),
            if (followUp != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.schedule, size: 13, color: isOverdue ? AppTheme.error : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Follow-up: ${followUp.day}/${followUp.month}/${followUp.year}',
                  style: TextStyle(fontSize: 11, color: isOverdue ? AppTheme.error : Colors.grey),
                ),
                if (isOverdue) ...[
                  const SizedBox(width: 4),
                  const Text('OVERDUE', style: TextStyle(fontSize: 9, color: AppTheme.error, fontWeight: FontWeight.bold)),
                ],
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;

  const _StatusDropdown({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'NEW': Color(0xFF3B82F6),
      'CONTACTED': Color(0xFF8B5CF6),
      'QUALIFIED': Color(0xFF10B981),
      'PROPOSAL': Color(0xFFF59E0B),
      'NEGOTIATION': Color(0xFFF97316),
      'WON': Color(0xFF22C55E),
      'LOST': Color(0xFFEF4444),
    };
    final color = colors[status] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: status,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        dropdownColor: const Color(0xFF1E2028),
        icon: Icon(Icons.arrow_drop_down, size: 14, color: color),
        items: AppConstants.leadStatuses.map((s) {
          final c = colors[s] ?? Colors.grey;
          return DropdownMenuItem(
            value: s,
            child: Text(s, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
          );
        }).toList(),
        onChanged: (v) => v != null ? onChanged(v) : null,
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'LOW': Colors.green,
      'MEDIUM': Colors.blue,
      'HIGH': Colors.orange,
      'URGENT': Colors.red,
    };
    final color = colors[priority] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: (color as Color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(priority, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── Lead Form Sheet ─────────────────────────────────────────────────────────

class _LeadFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? lead;
  final VoidCallback onSuccess;

  const _LeadFormSheet({this.lead, required this.onSuccess});

  @override
  ConsumerState<_LeadFormSheet> createState() => _LeadFormSheetState();
}

class _LeadFormSheetState extends ConsumerState<_LeadFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _reqCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _assignedCtrl = TextEditingController();
  String _priority = 'MEDIUM';
  String _source = 'DIRECT';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.92,
        initialChildSize: 0.75,
        builder: (_, ctrl) => Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: ctrl,
              children: [
                const Text('New Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _field(_companyCtrl, 'Company Name *', required: true),
                _field(_contactCtrl, 'Contact Person *', required: true),
                Row(children: [
                  Expanded(child: _field(_phoneCtrl, 'Phone *', required: true, keyboardType: TextInputType.phone)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress)),
                ]),
                _field(_productCtrl, 'Product Interest'),
                _field(_reqCtrl, 'Requirement', maxLines: 2),
                Row(children: [
                  Expanded(child: _field(_valueCtrl, 'Estimated Value', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_assignedCtrl, 'Assigned To')),
                ]),
                DropdownButtonFormField<String>(
                  value: _source,
                  decoration: const InputDecoration(labelText: 'Source'),
                  items: AppConstants.leadSources.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
                  onChanged: (v) => setState(() => _source = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: AppConstants.priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Create Lead'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(crmRepositoryProvider);
      await repo.createLead({
        'companyName': _companyCtrl.text.trim(),
        'contactPerson': _contactCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'productInterest': _productCtrl.text.trim().isEmpty ? null : _productCtrl.text.trim(),
        'requirement': _reqCtrl.text.trim().isEmpty ? null : _reqCtrl.text.trim(),
        'estimatedValue': double.tryParse(_valueCtrl.text) ?? 0,
        'assignedTo': _assignedCtrl.text.trim().isEmpty ? null : _assignedCtrl.text.trim(),
        'source': _source,
        'priority': _priority,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead created'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
