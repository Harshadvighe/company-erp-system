import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';

class CrmDashboardPage extends ConsumerWidget {
  const CrmDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(crmDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & CRM Dashboard'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(crmDashboardProvider),
            tooltip: 'Refresh Dashboard',
          ),
        ],
      ),
      body: dashAsync.when(
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
                onPressed: () => ref.invalidate(crmDashboardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _buildContent(context, data),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final totalLeads = data['totalLeads'] ?? 0;
    final newLeads = data['newLeads'] ?? 0;
    final qualifiedLeads = data['qualifiedLeads'] ?? 0;
    final totalCustomers = data['totalCustomers'] ?? 0;
    final activeCustomers = data['activeCustomers'] ?? 0;
    final openEnquiries = data['openEnquiries'] ?? 0;
    final openOpportunities = data['openOpportunities'] ?? 0;
    final followUpsToday = data['followUpsToday'] ?? 0;
    final overdueFollowUps = data['overdueFollowUps'] ?? 0;
    final pipelineVal = (data['pipelineValue'] ?? 0) as num;
    final wonVal = (data['wonValue'] ?? 0) as num;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Alert banner if there are overdue follow-ups
        if (overdueFollowUps > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$overdueFollowUps Overdue Follow-ups Require Action',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                      ),
                      const Text(
                        'Review client commitments and reschedule or log outcome.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/crm/follow-ups'),
                  child: const Text('View All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Quick Navigation Buttons
        Row(
          children: [
            Expanded(
              child: _navTile(
                context,
                title: 'Pipeline',
                subtitle: 'Kanban Board',
                icon: Icons.view_kanban_outlined,
                color: AppTheme.primary,
                route: '/crm/pipeline',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _navTile(
                context,
                title: 'Follow-ups',
                subtitle: 'Next Actions',
                icon: Icons.event_repeat_outlined,
                color: Colors.blue,
                route: '/crm/follow-ups',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _navTile(
                context,
                title: 'Analytics',
                subtitle: 'Intelligence',
                icon: Icons.analytics_outlined,
                color: Colors.green,
                route: '/crm/analytics',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Section: Key Performance Indicators
        const Text('Sales & Pipeline Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpiCard('Total Leads', '$totalLeads', Colors.blue, Icons.people_outline, () => context.go('/crm/leads')),
            _kpiCard('New Leads', '$newLeads', Colors.indigo, Icons.fiber_new, () => context.go('/crm/leads')),
            _kpiCard('Qualified Leads', '$qualifiedLeads', Colors.teal, Icons.verified_outlined, () => context.go('/crm/leads')),
            _kpiCard('Customers', '$totalCustomers ($activeCustomers Active)', Colors.purple, Icons.business_outlined, () => context.go('/customers')),
            _kpiCard('Open Enquiries', '$openEnquiries', Colors.orange, Icons.help_outline, () => context.go('/crm/enquiries')),
            _kpiCard('Open Deals', '$openOpportunities', Colors.amber, Icons.monetization_on_outlined, () => context.go('/crm/pipeline')),
            _kpiCard('Today Follow-ups', '$followUpsToday', Colors.blueGrey, Icons.schedule, () => context.go('/crm/follow-ups')),
            _kpiCard('Overdue Follow-ups', '$overdueFollowUps', Colors.red, Icons.alarm_off, () => context.go('/crm/follow-ups')),
            _kpiCard('Pipeline Value', '₹${(pipelineVal / 100000).toStringAsFixed(1)}L', AppTheme.primary, Icons.trending_up, () => context.go('/crm/pipeline')),
            _kpiCard('Won Value', '₹${(wonVal / 100000).toStringAsFixed(1)}L', Colors.green, Icons.emoji_events_outlined, () => context.go('/crm/analytics')),
          ],
        ),
        const SizedBox(height: 24),

        // Section: Upcoming Meetings & Activities
        const Text('Today & Upcoming Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        _buildActivitiesCard(data),
      ],
    );
  }

  Widget _navTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 165,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Icon(icon, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesCard(Map<String, dynamic> data) {
    final meetings = (data['meetingsToday'] as List? ?? []);

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Text('Scheduled Client Meetings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${meetings.length} scheduled', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          if (meetings.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No meetings scheduled for today', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
          ] else ...[
            ...meetings.map((m) {
              final meet = m as Map<String, dynamic>;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_outlined, color: AppTheme.primary),
                title: Text(meet['subject'] ?? 'Client Discussion'),
                subtitle: Text('Time: ${meet['scheduledAt'] ?? 'Today'}'),
              );
            }),
          ],
        ],
      ),
    );
  }
}
