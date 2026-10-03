import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';

class CrmPipelinePage extends ConsumerStatefulWidget {
  const CrmPipelinePage({super.key});

  @override
  ConsumerState<CrmPipelinePage> createState() => _CrmPipelinePageState();
}

class _CrmPipelinePageState extends ConsumerState<CrmPipelinePage> {
  static const List<Map<String, dynamic>> _stages = [
    {'key': 'NEW', 'label': 'New', 'prob': '10%', 'color': Colors.blue},
    {'key': 'QUALIFIED', 'label': 'Qualified', 'prob': '25%', 'color': Colors.indigo},
    {'key': 'REQUIREMENT', 'label': 'Requirement', 'prob': '40%', 'color': Colors.purple},
    {'key': 'TECHNICAL', 'label': 'Technical', 'prob': '60%', 'color': Colors.amber},
    {'key': 'QUOTATION', 'label': 'Quotation', 'prob': '75%', 'color': Colors.orange},
    {'key': 'NEGOTIATION', 'label': 'Negotiation', 'prob': '90%', 'color': Colors.deepOrange},
    {'key': 'WON', 'label': 'Won', 'prob': '100%', 'color': Colors.green},
    {'key': 'LOST', 'label': 'Lost', 'prob': '0%', 'color': Colors.red},
  ];

  @override
  Widget build(BuildContext context) {
    final pipelineAsync = ref.watch(crmPipelineProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/crm/dashboard');
            }
          },
        ),
        title: const Text('Sales Pipeline (Kanban)'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(crmPipelineProvider),
            tooltip: 'Refresh Pipeline',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateOpportunityDialog(),
            tooltip: 'New Opportunity',
          ),
        ],
      ),
      body: pipelineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(err.toString(), style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(crmPipelineProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final columns = (data['columns'] as List? ?? []);
          final summary = data['summary'] as Map<String, dynamic>? ?? {};

          return Column(
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: AppTheme.darkSurface,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _metricChip('Total Opps', '${summary['totalCount'] ?? 0}', Colors.blue),
                      const SizedBox(width: 8),
                      _metricChip('Pipeline', '₹${((summary['totalPipelineValue'] ?? 0) / 100000).toStringAsFixed(1)}L', Colors.amber),
                      const SizedBox(width: 8),
                      _metricChip('Weighted', '₹${((summary['weightedPipelineValue'] ?? 0) / 100000).toStringAsFixed(1)}L', AppTheme.primary),
                      const SizedBox(width: 8),
                      _metricChip('Won', '₹${((summary['wonValue'] ?? 0) / 100000).toStringAsFixed(1)}L', Colors.green),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppTheme.darkBorder),
              // Horizontal Kanban Scroll
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _stages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final stageMeta = _stages[index];
                    final stageKey = stageMeta['key'] as String;
                    
                    // Match column data from backend
                    final colData = columns.firstWhere(
                      (c) => c['stage'] == stageKey,
                      orElse: () => {'stage': stageKey, 'count': 0, 'totalValue': 0, 'items': []},
                    );

                    final items = (colData['items'] as List? ?? []);

                    return _buildKanbanColumn(stageMeta, colData, items);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricChip(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(
    Map<String, dynamic> stageMeta,
    Map<String, dynamic> colData,
    List<dynamic> items,
  ) {
    final color = stageMeta['color'] as Color;
    final totalVal = (colData['totalValue'] ?? 0) as num;

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      stageMeta['label'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${items.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(
                  '₹${(totalVal / 1000).toStringAsFixed(0)}k',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          // Column List of Cards
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No Deals',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i] as Map<String, dynamic>;
                      return _buildOpportunityCard(item, stageMeta['key'] as String);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(Map<String, dynamic> opp, String currentStage) {
    final customer = opp['customer'] as Map<String, dynamic>? ?? {};
    final value = (opp['estimatedValue'] ?? 0) as num;
    final prob = (opp['probability'] ?? 0) as num;
    final oppNumber = opp['opportunityNumber'] ?? '';
    final product = opp['productInterest'] ?? 'Industrial Panels';
    final priority = opp['priority'] ?? 'MEDIUM';

    Color priorityColor = Colors.grey;
    if (priority == 'HIGH') priorityColor = Colors.orange;
    if (priority == 'URGENT') priorityColor = Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showOpportunityDetailsSheet(opp),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(oppNumber, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(priority, style: TextStyle(fontSize: 9, color: priorityColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                customer['companyName'] ?? 'Unknown Company',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                product,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${value.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                  ),
                  Text('$prob% prob', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppTheme.darkBorder),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Move Stage',
                    icon: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                    itemBuilder: (_) => _stages
                        .where((s) => s['key'] != currentStage)
                        .map((s) => PopupMenuItem(
                              value: s['key'] as String,
                              child: Text('Move to ${s['label']} (${s['prob']})'),
                            ))
                        .toList(),
                    onSelected: (newStage) => _updateStage(opp['id'], newStage),
                  ),
                  if (currentStage != 'LOST' && currentStage != 'WON')
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showMarkLostDialog(opp['id']),
                      child: const Text('Mark Lost', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStage(String oppId, String newStage) async {
    try {
      final repo = ref.read(crmRepositoryProvider);
      await repo.updateOpportunityStage(oppId, newStage);
      ref.invalidate(crmPipelineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stage moved to $newStage'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showMarkLostDialog(String oppId) {
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Deal Lost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Lost Reason *', hintText: 'Price / Competitor / Spec mismatch'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes', hintText: 'Additional feedback or competitor name'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final repo = ref.read(crmRepositoryProvider);
                await repo.markOpportunityLost(oppId, reasonCtrl.text.trim(), notesCtrl.text.trim());
                ref.invalidate(crmPipelineProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deal marked as Lost'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Confirm Lost'),
          ),
        ],
      ),
    );
  }

  void _showOpportunityDetailsSheet(Map<String, dynamic> opp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(opp['opportunityNumber'] ?? 'Opportunity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(opp['customer']?['companyName'] ?? 'Company'),
              subtitle: Text('Stage: ${opp['stage']} | Priority: ${opp['priority']}'),
            ),
            const SizedBox(height: 8),
            Text('Product Interest: ${opp['productInterest'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Requirement: ${opp['requirement'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Estimated Value: ₹${opp['estimatedValue'] ?? 0} (${opp['probability']}% probability)'),
            const SizedBox(height: 4),
            Text('Owner: ${opp['owner']?['fullName'] ?? opp['owner']?['email'] ?? 'Unassigned'}'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCreateOpportunityDialog() {
    final titleCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final custIdCtrl = TextEditingController();
    final productCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Opportunity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: custIdCtrl, decoration: const InputDecoration(labelText: 'Customer ID *')),
            TextField(controller: productCtrl, decoration: const InputDecoration(labelText: 'Product / System Interest *')),
            TextField(controller: valueCtrl, decoration: const InputDecoration(labelText: 'Estimated Value (₹) *'), keyboardType: TextInputType.number),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Requirement / Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (custIdCtrl.text.trim().isEmpty || productCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final repo = ref.read(crmRepositoryProvider);
                await repo.createOpportunity({
                  'customerId': custIdCtrl.text.trim(),
                  'productInterest': productCtrl.text.trim(),
                  'estimatedValue': double.tryParse(valueCtrl.text) ?? 0,
                  'requirement': titleCtrl.text.trim(),
                  'stage': 'NEW',
                  'priority': 'MEDIUM',
                });
                ref.invalidate(crmPipelineProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opportunity created'), backgroundColor: AppTheme.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Create Deal'),
          ),
        ],
      ),
    );
  }
}
