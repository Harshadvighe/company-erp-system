import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';

final _dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(crmRepositoryProvider).getDashboard();
});

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerListProvider.notifier).loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final dashAsync = ref.watch(_dashboardDataProvider);
    final customerState = ref.watch(customerListProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_dashboardDataProvider);
          await ref.read(customerListProvider.notifier).loadCustomers();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              _buildGreeting(user),
              const SizedBox(height: 24),

              // KPI Stats
              dashAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildErrorBanner(parseDioError(e), () => ref.invalidate(_dashboardDataProvider)),
                data: (d) => _buildKpiGrid(context, d, customerState, user),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(context, user),
              const SizedBox(height: 24),

              // Recent Activity + Follow-ups (Zero Extra UI: only if authorized)
              if (user?.canView('CUSTOMERS') == true || user?.canView('CRM') == true) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final canCustomers = user?.canView('CUSTOMERS') == true;
                    final canCRM = user?.canView('CRM') == true;

                    if (constraints.maxWidth > 700) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canCustomers)
                            Expanded(child: _buildRecentCustomers(context, customerState)),
                          if (canCustomers && canCRM)
                            const SizedBox(width: 16),
                          if (canCRM)
                            Expanded(child: _buildFollowUps(ref)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        if (canCustomers)
                          _buildRecentCustomers(context, customerState),
                        if (canCustomers && canCRM)
                          const SizedBox(height: 16),
                        if (canCRM)
                          _buildFollowUps(ref),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(AuthUser? user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${user?.fullName.split(' ').first ?? 'User'}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${now.day} ${months[now.month - 1]} ${now.year} · FY 2025-26',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text('FY 2025-26', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(BuildContext context, Map<String, dynamic> d, CustomerListState cs, AuthUser? user) {
    final kpis = <_KpiData>[];

    if (user?.canView('CUSTOMERS') == true) {
      kpis.add(_KpiData(label: 'Customers', value: '${cs.total}', icon: Icons.people, color: const Color(0xFF3B82F6), route: '/customers'));
    }
    if (user?.canView('CRM') == true) {
      kpis.add(_KpiData(label: 'Open Enquiries', value: '${d['openEnquiries'] ?? 0}', icon: Icons.inbox, color: const Color(0xFFF59E0B), route: '/crm/enquiries'));
      kpis.add(_KpiData(label: 'Total Leads', value: '${d['totalLeads'] ?? 0}', icon: Icons.trending_up, color: AppTheme.primary, route: '/crm/leads'));
      kpis.add(_KpiData(label: 'Won Leads', value: '${d['wonLeads'] ?? 0}', icon: Icons.check_circle, color: AppTheme.success, route: '/crm/leads'));
      kpis.add(_KpiData(label: 'Follow-ups Due', value: '${d['pendingFollowUps'] ?? 0}', icon: Icons.schedule, color: AppTheme.error, route: '/crm/leads'));
      kpis.add(_KpiData(label: 'Conversion %', value: '${d['conversionRate'] ?? 0}%', icon: Icons.percent, color: const Color(0xFF8B5CF6), route: '/crm/leads'));
    }
    if (user?.canView('PROJECTS') == true) {
      kpis.add(const _KpiData(label: 'Active Projects', value: 'Live', icon: Icons.folder, color: Color(0xFF0EA5E9), route: '/projects'));
    }
    if (user?.canView('TASKS') == true) {
      kpis.add(const _KpiData(label: 'My Tasks', value: 'Active', icon: Icons.task_alt, color: Color(0xFF10B981), route: '/my-work'));
    }

    if (kpis.isEmpty) {
      kpis.add(const _KpiData(label: 'My Work Hub', value: 'View', icon: Icons.home_repair_service, color: AppTheme.primary, route: '/my-work'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: kpis.length,
      itemBuilder: (_, i) => _KpiCard(kpi: kpis[i]),
    );
  }

  Widget _buildQuickActions(BuildContext context, AuthUser? user) {
    if (user == null) return const SizedBox.shrink();

    final actions = <Widget>[];

    actions.add(_QuickAction(
      label: 'My Work',
      icon: Icons.home_repair_service_outlined,
      onTap: () => context.go('/my-work'),
    ));

    if (user.canView('TASKS')) {
      actions.add(_QuickAction(
        label: 'Task Board',
        icon: Icons.task_alt,
        onTap: () => context.go('/tasks'),
      ));
    }

    if (user.canView('PROJECTS')) {
      actions.add(_QuickAction(
        label: 'Projects',
        icon: Icons.folder_outlined,
        onTap: () => context.go('/projects'),
      ));
    }

    if (user.canCreate('CUSTOMERS')) {
      actions.add(_QuickAction(
        label: 'New Customer',
        icon: Icons.person_add,
        onTap: () => context.go('/customers/new'),
      ));
    }

    if (user.canCreate('CRM')) {
      actions.add(_QuickAction(
        label: 'New Lead',
        icon: Icons.add_chart,
        onTap: () => context.go('/crm/leads'),
      ));
      actions.add(_QuickAction(
        label: 'New Enquiry',
        icon: Icons.inbox_outlined,
        onTap: () => context.go('/crm/enquiries'),
      ));
    }

    if (user.canCreate('PURCHASE')) {
      actions.add(_QuickAction(
        label: 'Purchase Orders',
        icon: Icons.shopping_bag_outlined,
        onTap: () => context.go('/purchase/orders'),
      ));
    }

    if (user.canCreate('VENDORS')) {
      actions.add(_QuickAction(
        label: 'New Vendor',
        icon: Icons.store_outlined,
        onTap: () => context.go('/vendors'),
      ));
    }

    if (user.canView('STAFF')) {
      actions.add(_QuickAction(
        label: 'Staff Directory',
        icon: Icons.badge_outlined,
        onTap: () => context.go('/staff'),
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions,
        ),
      ],
    );
  }

  Widget _buildRecentCustomers(BuildContext context, CustomerListState state) {
    return _DashCard(
      title: 'Recent Customers',
      trailing: TextButton(
        onPressed: () => context.go('/customers'),
        child: const Text('View All', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
      ),
      child: state.customers.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No customers yet', style: TextStyle(color: Colors.grey))),
            )
          : Column(
              children: state.customers.take(5).map((c) {
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    child: Text(c.initials, style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(c.companyName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(c.city, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: Text(c.typeLabel.split(' ').first, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  onTap: () => context.go('/customers/${c.id}'),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildFollowUps(WidgetRef ref) {
    final followUpsAsync = ref.watch(_followUpsProvider);

    return _DashCard(
      title: 'Pending Follow-ups',
      trailing: const Icon(Icons.schedule, size: 16, color: AppTheme.warning),
      child: followUpsAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, __) => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Unable to load', style: TextStyle(color: Colors.grey))),
        ),
        data: (followUps) {
          if (followUps.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.success, size: 32),
                  SizedBox(height: 8),
                  Text('No pending follow-ups!', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                ]),
              ),
            );
          }
          return Column(
            children: followUps.take(5).map((f) {
              final lead = f as Map<String, dynamic>;
              final followUp = DateTime.tryParse(lead['nextFollowUp'] as String? ?? '');
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0x33F97316),
                  child: Icon(Icons.phone, color: AppTheme.primary, size: 14),
                ),
                title: Text(lead['companyName'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: followUp != null
                    ? Text('${followUp.day}/${followUp.month}/${followUp.year}', style: const TextStyle(fontSize: 11, color: AppTheme.warning))
                    : null,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('DUE', style: TextStyle(fontSize: 9, color: AppTheme.error, fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner(String message, VoidCallback onRetry) {
    final isAuthError = message.toLowerCase().contains('session expired') ||
        message.toLowerCase().contains('log in') ||
        message.toLowerCase().contains('401');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          if (isAuthError)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(Icons.login, size: 14),
              label: const Text('Log In Again'),
            )
          else
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

final _followUpsProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.watch(crmRepositoryProvider);
  return repo.getPendingFollowUps();
});

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String route;

  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go(kpi.route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kpi.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(kpi.icon, color: kpi.color, size: 18),
                  ),
                  Icon(Icons.arrow_outward, size: 14, color: Colors.grey[600]),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kpi.value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kpi.color)),
                  Text(kpi.label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.darkBorder),
          borderRadius: BorderRadius.circular(10),
          color: AppTheme.darkSurface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _DashCard({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}
