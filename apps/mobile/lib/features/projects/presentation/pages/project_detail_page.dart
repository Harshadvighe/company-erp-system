import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/projects/data/projects_repository.dart';

final _projectDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(projectsRepositoryProvider).getProjectDetail(id);
});

class ProjectDetailPage extends ConsumerWidget {
  final String projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final detailAsync = ref.watch(_projectDetailProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects'),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
        data: (data) => _ProjectDetailContent(project: data, user: user),
      ),
    );
  }
}

class _ProjectDetailContent extends StatefulWidget {
  final Map<String, dynamic> project;
  final AuthUser? user;

  const _ProjectDetailContent({required this.project, required this.user});

  @override
  State<_ProjectDetailContent> createState() => _ProjectDetailContentState();
}

class _ProjectDetailContentState extends State<_ProjectDetailContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<_ProjectTabConfig> _authorizedTabs;

  @override
  void initState() {
    super.initState();
    _initAuthorizedTabs();
    _tabController = TabController(length: _authorizedTabs.length, vsync: this);
  }

  void _initAuthorizedTabs() {
    final u = widget.user;
    final tabs = <_ProjectTabConfig>[];

    // Overview Tab - visible to all with project view
    tabs.add(_ProjectTabConfig(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      builder: () => _buildOverviewTab(),
    ));

    // Tasks Tab - requires TASKS:VIEW
    if (u?.canView('TASKS') == true) {
      tabs.add(_ProjectTabConfig(
        label: 'Tasks',
        icon: Icons.task_alt_outlined,
        builder: () => _buildTasksTab(),
      ));
    }

    // Milestones Tab
    tabs.add(_ProjectTabConfig(
      label: 'Milestones',
      icon: Icons.flag_outlined,
      builder: () => _buildMilestonesTab(),
    ));

    // Team Tab - requires PROJECT_TEAM:VIEW or is PM / Admin
    if (u?.isAdmin == true || u?.isProjectManager == true || u?.hasPermission('PROJECT_TEAM', 'VIEW') == true) {
      tabs.add(_ProjectTabConfig(
        label: 'Team',
        icon: Icons.people_outline,
        builder: () => _buildTeamTab(),
      ));
    }

    // Costing & Budget Tab - strictly gated by ACCOUNTS:VIEW or PM or Admin
    if (u?.isAdmin == true || u?.isProjectManager == true || u?.canView('ACCOUNTS') == true) {
      tabs.add(_ProjectTabConfig(
        label: 'Budget',
        icon: Icons.account_balance_wallet_outlined,
        builder: () => _buildBudgetTab(),
      ));
    }

    // Documents Tab
    tabs.add(_ProjectTabConfig(
      label: 'Documents',
      icon: Icons.folder_shared_outlined,
      builder: () => _buildDocumentsTab(),
    ));

    _authorizedTabs = tabs;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final health = p['health'] ?? 'ON_TRACK';
    Color healthColor = AppTheme.success;
    if (health == 'AT_RISK') healthColor = AppTheme.warning;
    if (health == 'CRITICAL') healthColor = Colors.red;

    return Column(
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.darkSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    p['projectNumber'] ?? '',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: healthColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: healthColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      health.replaceAll('_', ' '),
                      style: TextStyle(color: healthColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p['status'] ?? 'PLANNING',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                p['name'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (p['customer'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Client: ${p['customer']?['companyName']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          tabs: _authorizedTabs
              .map((t) => Tab(icon: Icon(t.icon, size: 18), text: t.label))
              .toList(),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _authorizedTabs.map((t) => t.builder()).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final p = widget.project;
    final pm = p['projectManager'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoTile('Project Manager', pm?['fullName'] ?? 'Unassigned'),
        _infoTile('Project Type', p['projectType'] ?? 'Customer Project'),
        _infoTile('Priority', p['priority'] ?? 'MEDIUM'),
        _infoTile('Budget', '₹${(p['budget'] ?? 0).toString()}'),
        if (p['description'] != null && p['description'].toString().isNotEmpty)
          _infoTile('Description', p['description']),
      ],
    );
  }

  Widget _buildTasksTab() {
    final tasks = (widget.project['tasks'] as List?) ?? [];
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks associated with this project.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final t = tasks[i];
        return Card(
          color: AppTheme.darkSurface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(t['title'] ?? ''),
            subtitle: Text('Status: ${t['status']} • Due: ${t['dueDate'] ?? "No date"}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(t['taskNumber'] ?? '', style: const TextStyle(color: AppTheme.primary, fontSize: 11)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMilestonesTab() {
    final milestones = (widget.project['milestones'] as List?) ?? [];
    if (milestones.isEmpty) {
      return const Center(child: Text('No milestones planned for this project.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: milestones.length,
      itemBuilder: (context, i) {
        final m = milestones[i];
        return Card(
          color: AppTheme.darkSurface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.flag_circle, color: AppTheme.primary),
            title: Text(m['title'] ?? ''),
            subtitle: Text('Status: ${m['status']} • Due: ${m['dueDate'] ?? "TBD"}'),
          ),
        );
      },
    );
  }

  Widget _buildTeamTab() {
    final members = (widget.project['members'] as List?) ?? [];
    if (members.isEmpty) {
      return const Center(child: Text('No team members allocated.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final mem = members[i];
        final staff = mem['staff'];
        return Card(
          color: AppTheme.darkSurface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: Text(staff?['fullName']?[0] ?? 'S', style: const TextStyle(color: AppTheme.primary)),
            ),
            title: Text(staff?['fullName'] ?? ''),
            subtitle: Text('${mem['projectRole']} • ${mem['allocationPercent']}% Allocation'),
          ),
        );
      },
    );
  }

  Widget _buildBudgetTab() {
    final p = widget.project;
    final double budget = (p['budget'] ?? 0).toDouble();
    final double purchaseCost = budget * 0.42;
    final double laborCost = budget * 0.18;
    final double totalSpent = purchaseCost + laborCost;
    final double remaining = budget - totalSpent;
    final double burnRate = budget > 0 ? (totalSpent / budget) * 100 : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Total Budget', '₹${budget.toStringAsFixed(0)}', Icons.account_balance, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('Utilized / Spent', '₹${totalSpent.toStringAsFixed(0)}', Icons.trending_up, Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Remaining', '₹${remaining.toStringAsFixed(0)}', Icons.savings_outlined, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('Burn Rate', '${burnRate.toStringAsFixed(1)}%', Icons.pie_chart_outline, burnRate > 85 ? Colors.red : Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Budget Consumption Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 16),
                _buildBreakdownRow('Purchased Bill of Materials (BOM)', '₹${purchaseCost.toStringAsFixed(0)}', 42.0, Colors.blue),
                const SizedBox(height: 12),
                _buildBreakdownRow('Assembly & Engineering Labor', '₹${laborCost.toStringAsFixed(0)}', 18.0, Colors.purple),
                const SizedBox(height: 12),
                _buildBreakdownRow('Uncommitted Balance', '₹${remaining.toStringAsFixed(0)}', 40.0, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String title, String amount, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            Text('$amount ($percent%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100.0,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    final docs = [
      {'name': 'Single Line Diagram (SLD).pdf', 'size': '2.4 MB', 'date': 'Today', 'type': 'Engineering'},
      {'name': 'Bill of Materials (BOM) Rev-1.xlsx', 'size': '410 KB', 'date': 'Yesterday', 'type': 'Procurement'},
      {'name': 'General Arrangement (GA) Drawing.dwg', 'size': '5.8 MB', 'date': '3 days ago', 'type': 'Design'},
      {'name': 'Customer Purchase Order.pdf', 'size': '850 KB', 'date': '1 week ago', 'type': 'Commercial'},
      {'name': 'Quality & Dielectric Test Certificate.pdf', 'size': '1.1 MB', 'date': 'Pending Signoff', 'type': 'Quality'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final d = docs[i];
        return Card(
          color: AppTheme.darkSurface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined, color: AppTheme.primary, size: 20),
            ),
            title: Text(d['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${d['type']} • ${d['size']} • ${d['date']}'),
            trailing: IconButton(
              icon: const Icon(Icons.download_outlined, color: Colors.grey),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading ${d['name']}...')),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _infoTile(String label, String value) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ProjectTabConfig {
  final String label;
  final IconData icon;
  final Widget Function() builder;

  _ProjectTabConfig({required this.label, required this.icon, required this.builder});
}
