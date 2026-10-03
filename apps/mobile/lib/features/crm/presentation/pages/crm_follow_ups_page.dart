import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';

class CrmFollowUpsPage extends ConsumerStatefulWidget {
  const CrmFollowUpsPage({super.key});

  @override
  ConsumerState<CrmFollowUpsPage> createState() => _CrmFollowUpsPageState();
}

class _CrmFollowUpsPageState extends ConsumerState<CrmFollowUpsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _filters = ['ALL', 'TODAY', 'OVERDUE', 'PENDING', 'COMPLETED'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadCurrentTab();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentTab();
    });
  }

  void _loadCurrentTab() {
    final filter = _filters[_tabController.index];
    if (filter == 'TODAY') {
      ref.read(followUpListProvider.notifier).loadFollowUps(due: 'today');
    } else if (filter == 'OVERDUE') {
      ref.read(followUpListProvider.notifier).loadFollowUps(due: 'overdue');
    } else if (filter == 'ALL') {
      ref.read(followUpListProvider.notifier).loadFollowUps();
    } else {
      ref.read(followUpListProvider.notifier).loadFollowUps(status: filter);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(followUpListProvider);

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
        title: const Text('Follow-ups & Next Actions'),
        backgroundColor: AppTheme.darkSurface,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Today'),
            Tab(text: '🚨 Overdue'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentTab,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: _showScheduleFollowUpDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Follow-up', style: TextStyle(color: Colors.white)),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                      const SizedBox(height: 12),
                      Text(state.error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadCurrentTab, child: const Text('Retry')),
                    ],
                  ),
                )
              : state.followUps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: Colors.grey.shade600),
                          const SizedBox(height: 12),
                          const Text('No follow-ups in this queue', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.followUps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final fu = state.followUps[i] as Map<String, dynamic>;
                        return _buildFollowUpCard(fu);
                      },
                    ),
    );
  }

  Widget _buildFollowUpCard(Map<String, dynamic> fu) {
    final status = fu['status'] as String? ?? 'PENDING';
    final isOverdue = status == 'OVERDUE' || (fu['dueDate'] != null && DateTime.tryParse(fu['dueDate'])?.isBefore(DateTime.now()) == true && status == 'PENDING');
    final customer = fu['customer'] as Map<String, dynamic>?;
    final lead = fu['lead'] as Map<String, dynamic>?;
    final entityName = customer?['companyName'] ?? lead?['companyName'] ?? 'General Follow-up';
    final action = fu['action'] ?? 'Follow-up';
    final dueDate = fu['dueDate'] != null ? DateTime.tryParse(fu['dueDate'])?.toLocal().toString().split(' ')[0] : 'No Date';
    final priority = fu['priority'] ?? 'MEDIUM';

    Color priorityColor = Colors.grey;
    if (priority == 'HIGH') priorityColor = Colors.orange;
    if (priority == 'URGENT') priorityColor = Colors.red;

    return Card(
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isOverdue ? Colors.red.withOpacity(0.5) : AppTheme.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOverdue ? Colors.red.withOpacity(0.15) : (status == 'COMPLETED' ? Colors.green.withOpacity(0.15) : Colors.blue.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isOverdue ? Colors.red : (status == 'COMPLETED' ? Colors.green : Colors.blue), width: 0.5),
                      ),
                      child: Text(
                        isOverdue ? 'OVERDUE' : status,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOverdue ? Colors.red : (status == 'COMPLETED' ? Colors.green : Colors.blue)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: priorityColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor)),
                    ),
                  ],
                ),
                Text('Due: $dueDate', style: TextStyle(fontSize: 11, color: isOverdue ? Colors.red : Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(entityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('Action: $action', style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (fu['notes'] != null && (fu['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(fu['notes'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            if (status != 'COMPLETED') ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppTheme.darkBorder),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showCompleteDialog(fu['id']),
                    icon: const Icon(Icons.check, size: 14, color: Colors.green),
                    label: const Text('Mark Done', style: TextStyle(color: Colors.green, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCompleteDialog(String id) {
    final outcomeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Follow-up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: outcomeCtrl,
              decoration: const InputDecoration(labelText: 'Outcome / Notes *', hintText: 'E.g., Client requested quotation revision'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(followUpListProvider.notifier).complete(id, outcomeCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Follow-up completed'), backgroundColor: AppTheme.success),
                );
              }
            },
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  void _showScheduleFollowUpDialog() {
    final actionCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final customerIdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Follow-up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: customerIdCtrl, decoration: const InputDecoration(labelText: 'Customer ID (optional)')),
            TextField(controller: actionCtrl, decoration: const InputDecoration(labelText: 'Action *', hintText: 'Call / Email / Site Visit')),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (actionCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final repo = ref.read(crmRepositoryProvider);
                await repo.logCall({
                  if (customerIdCtrl.text.trim().isNotEmpty) 'customerId': customerIdCtrl.text.trim(),
                  'purpose': actionCtrl.text.trim(),
                  'outcome': 'SCHEDULED',
                  'nextAction': actionCtrl.text.trim(),
                  'nextFollowUpDate': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
                });
                _loadCurrentTab();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Follow-up scheduled'), backgroundColor: AppTheme.success),
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
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }
}
