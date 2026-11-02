import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(crmRepositoryProvider).getDashboard();
});

final _followUpsProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.watch(crmRepositoryProvider);
  return repo.getPendingFollowUps();
});

// ─── Industrial Dashboard Page ────────────────────────────────────────────────

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerListProvider.notifier).loadCustomers();
    });
  }

  Future<void> _refreshAll() async {
    setState(() => _isRefreshing = true);
    ref.invalidate(_dashboardDataProvider);
    ref.invalidate(_followUpsProvider);
    await ref.read(customerListProvider.notifier).loadCustomers();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final dashAsync = ref.watch(_dashboardDataProvider);
    final customerState = ref.watch(customerListProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.darkSurface,
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Executive Industrial Header (Single user avatar, no duplicate logo)
              _buildIndustrialHeader(user, context),
              AppSpacing.gapH20,

              // 2. Core Industrial Metrics (4 focused high-impact cards)
              dashAsync.when(
                loading: () => Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                      AppSpacing.gapW12,
                      Text(
                        'Updating Industrial Metrics...',
                        style: TextStyle(
                          color: AppTypography.darkTextSecondary,
                          fontSize: AppTypography.scaleBodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                error: (e, _) => _buildErrorBanner(parseDioError(e), _refreshAll),
                data: (d) => _buildIndustrialMetricsGrid(context, d, customerState, user),
              ),
              AppSpacing.gapH24,

              // 3. Industrial Operations Console (Direct power shortcuts to core modules)
              _buildOperationsConsole(context, user),
              const SizedBox(height: 24),

              // 4. Dual Operational Hub: Clients & Priority Action Items
              if (user?.canView('CUSTOMERS') == true || user?.canView('CRM') == true) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final canCustomers = user?.canView('CUSTOMERS') == true;
                    final canCRM = user?.canView('CRM') == true;

                    if (constraints.maxWidth > 800) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canCustomers)
                            Expanded(child: _buildRecentClients(context, customerState)),
                          if (canCustomers && canCRM)
                            const SizedBox(width: 18),
                          if (canCRM)
                            Expanded(child: _buildPriorityActions(ref, context)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        if (canCustomers)
                          _buildRecentClients(context, customerState),
                        if (canCustomers && canCRM)
                          const SizedBox(height: 18),
                        if (canCRM)
                          _buildPriorityActions(ref, context),
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

  // ─── Executive Industrial Header ──────────────────────────────────────────

  Widget _buildIndustrialHeader(AuthUser? user, BuildContext context) {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final name = (user?.fullName.isNotEmpty == true) ? user!.fullName : (user?.username ?? 'Executive');
    final role = (user?.designation?.isNotEmpty == true)
        ? user!.designation!
        : (user?.roles.isNotEmpty == true ? user!.roles.first : 'Managing Director');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF15A24).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 680;

          // Clean single user avatar and designation
          final userProfile = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF15A24), Color(0xFFE04A15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF15A24).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'V',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AppSpacing.gapW12,
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome back, $name',
                      style: const TextStyle(
                        fontSize: AppTypography.scaleHeadlineMedium,
                        fontWeight: AppTypography.bold,
                        color: AppTypography.darkTextPrimary,
                        letterSpacing: -0.2,
                        height: AppTypography.leadingHeading,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapH4,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFFF8555),
                              fontSize: AppTypography.scaleMicro,
                              fontWeight: AppTypography.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        AppSpacing.gapW8,
                        const _LivePulseDot(),
                        const SizedBox(width: 5),
                        const Text(
                          'Operations Online',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontSize: AppTypography.scaleLabelSmall,
                            fontWeight: AppTypography.semiBold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final dateAndControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.primary),
                    AppSpacing.gapW8,
                    Text(
                      '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}  •  F.Y. 2026-27',
                      style: const TextStyle(
                        color: AppTypography.darkTextSecondary,
                        fontSize: AppTypography.scaleLabelSmall,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _IndustrialRefreshButton(
                isRefreshing: _isRefreshing,
                onPressed: _refreshAll,
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                userProfile,
                const SizedBox(height: 12),
                dateAndControls,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: userProfile),
              dateAndControls,
            ],
          );
        },
      ),
    );
  }

  // ─── Core Industrial Metrics Grid (Simple & Powerful) ────────────────────────

  Widget _buildIndustrialMetricsGrid(
    BuildContext context,
    Map<String, dynamic> d,
    CustomerListState cs,
    AuthUser? user,
  ) {
    final metrics = <_IndustrialMetric>[];

    // 1. Projects & Operations
    if (user?.canView('PROJECTS') == true || user?.canView('PRODUCTION') == true) {
      metrics.add(const _IndustrialMetric(
        title: 'Active Projects',
        tag: 'Engineering Works',
        value: 'Active',
        icon: Icons.precision_manufacturing_rounded,
        accentColor: Color(0xFF0EA5E9),
        route: '/projects',
      ));
    }

    // 2. Enterprise Clients
    if (user?.canView('CUSTOMERS') == true) {
      metrics.add(_IndustrialMetric(
        title: 'Enterprise Clients',
        tag: 'B2B Client Base',
        value: '${cs.total}',
        icon: Icons.business_rounded,
        accentColor: const Color(0xFFF15A24),
        route: '/customers',
      ));
    }

    // 3. Open Enquiries & RFQs
    if (user?.canView('CRM') == true) {
      metrics.add(_IndustrialMetric(
        title: 'Open Enquiries',
        tag: 'Commercial RFQs',
        value: '${d['openEnquiries'] ?? 0}',
        icon: Icons.inbox_rounded,
        accentColor: const Color(0xFFFF7A45),
        route: '/crm/enquiries',
      ));
      metrics.add(_IndustrialMetric(
        title: 'Pending Follow-ups',
        tag: 'Action Required',
        value: '${d['pendingFollowUps'] ?? 0}',
        icon: Icons.assignment_late_rounded,
        accentColor: const Color(0xFFEF4444),
        isAlert: (d['pendingFollowUps'] ?? 0) > 0,
        route: '/crm/leads',
      ));
    }

    if (metrics.isEmpty) {
      metrics.add(const _IndustrialMetric(
        title: 'Operations Hub',
        tag: 'Daily Schedule',
        value: 'Online',
        icon: Icons.dashboard_rounded,
        accentColor: Color(0xFFF15A24),
        route: '/my-work',
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 600
            ? 2
            : (constraints.maxWidth < 960 ? 2 : metrics.length.clamp(2, 4));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: constraints.maxWidth < 600 ? 1.4 : 1.75,
          ),
          itemCount: metrics.length,
          itemBuilder: (_, i) => _IndustrialMetricCard(metric: metrics[i]),
        );
      },
    );
  }

  // ─── Industrial Operations Console ──────────────────────────────────────────

  Widget _buildOperationsConsole(BuildContext context, AuthUser? user) {
    if (user == null) return const SizedBox.shrink();

    final tiles = <_ConsoleTileData>[];

    if (user.canAccessModule('PRODUCTION')) {
      tiles.add(const _ConsoleTileData(
        title: 'Production Process',
        subtitle: 'Shop floor batches & workflow',
        icon: Icons.precision_manufacturing_rounded,
        route: '/production',
        accentColor: Color(0xFFF15A24),
      ));
    }
    if (user.canAccessModule('PANEL_MANUFACTURING')) {
      tiles.add(const _ConsoleTileData(
        title: 'Panel Manufacturing',
        subtitle: 'MCC / PCC & automation panels',
        icon: Icons.electrical_services_rounded,
        route: '/production/new',
        accentColor: Color(0xFFFF7A45),
      ));
    }
    if (user.canAccessModule('QUALITY_CONTROL')) {
      tiles.add(const _ConsoleTileData(
        title: 'Quality Control (QC/QA)',
        subtitle: 'FAT reports & inspection protocols',
        icon: Icons.verified_rounded,
        route: '/production/management',
        accentColor: Color(0xFF10B981),
      ));
    }

    if (user.canAccessModule('PROJECTS')) {
      tiles.add(const _ConsoleTileData(
        title: 'Project Management',
        subtitle: 'Engineering milestones & delivery',
        icon: Icons.folder_open_rounded,
        route: '/projects',
        accentColor: Color(0xFF0EA5E9),
      ));
    }

    if (user.canAccessModule('SALES_MARKETING')) {
      tiles.add(const _ConsoleTileData(
        title: 'Sales & Marketing',
        subtitle: 'B2B inquiries, leads & RFQs',
        icon: Icons.campaign_rounded,
        route: '/sales-marketing',
        accentColor: Color(0xFFF59E0B),
      ));
    }

    if (user.canAccessModule('TASKS')) {
      tiles.add(const _ConsoleTileData(
        title: 'Task Manager',
        subtitle: 'Operations assignments & boards',
        icon: Icons.task_alt_rounded,
        route: '/tasks',
        accentColor: Color(0xFF8B5CF6),
      ));
    }

    if (user.canAccessModule('ACCOUNTS')) {
      tiles.add(const _ConsoleTileData(
        title: 'Accounts & Finance',
        subtitle: 'Invoicing, ledger & balance reports',
        icon: Icons.account_balance_rounded,
        route: '/accounts',
        accentColor: Color(0xFF06B6D4),
      ));
    }

    if (user.canAccessModule('HR')) {
      tiles.add(const _ConsoleTileData(
        title: 'Human Resources',
        subtitle: 'Staff onboarding, directory & records',
        icon: Icons.people_alt_rounded,
        route: '/hr',
        accentColor: Color(0xFFEC4899),
      ));
    }

    if (user.canAccessModule('ATTENDANCE')) {
      tiles.add(const _ConsoleTileData(
        title: 'Attendance',
        subtitle: 'Biometric punch logs & shift reports',
        icon: Icons.access_time_rounded,
        route: '/attendance',
        accentColor: Color(0xFF3B82F6),
      ));
    }

    if (user.canAccessModule('PURCHASE')) {
      tiles.add(const _ConsoleTileData(
        title: 'Purchase / Procurement',
        subtitle: 'Purchase orders & vendor RFQs',
        icon: Icons.shopping_bag_rounded,
        route: '/purchase/orders',
        accentColor: Color(0xFFEAB308),
      ));
    }

    if (user.canAccessModule('INVENTORY')) {
      tiles.add(const _ConsoleTileData(
        title: 'Stores / Warehouse',
        subtitle: 'Stock balances & material issues',
        icon: Icons.warehouse_rounded,
        route: '/inventory',
        accentColor: Color(0xFF64748B),
      ));
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AppSpacing.gapW8,
              const Text(
                'Industrial Operations Console',
                style: TextStyle(
                  fontSize: AppTypography.scaleTitleLarge,
                  fontWeight: AppTypography.bold,
                  color: AppTypography.darkTextPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              const Text(
                'Quick Launch',
                style: TextStyle(
                  color: AppTypography.darkTextMuted,
                  fontSize: AppTypography.scaleLabelSmall,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ],
          ),
          AppSpacing.gapH16,
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 600 ? 1 : (constraints.maxWidth < 960 ? 2 : 3);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: constraints.maxWidth < 600 ? 3.5 : 2.7,
                ),
                itemCount: tiles.length,
                itemBuilder: (_, i) => _ConsoleTile(data: tiles[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Dual Column Hub: Recent Clients ────────────────────────────────────────

  Widget _buildRecentClients(BuildContext context, CustomerListState state) {
    return _IndustrialSectionBox(
      title: 'Recent Enterprise Clients',
      icon: Icons.business_rounded,
      trailing: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        ),
        onPressed: () => context.go('/customers'),
        icon: const Text(
          'All Clients',
          style: TextStyle(
            fontSize: AppTypography.scaleLabelMedium,
            fontWeight: AppTypography.semiBold,
          ),
        ),
        label: const Icon(Icons.arrow_forward_rounded, size: 13),
      ),
      child: state.customers.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'No client accounts registered',
                  style: TextStyle(color: AppTypography.darkTextMuted, fontSize: AppTypography.scaleLabelMedium),
                ),
              ),
            )
          : Column(
              children: state.customers.take(5).map((c) {
                return InkWell(
                  onTap: () => context.go('/customers/${c.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0x15FFFFFF))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.initials,
                            style: const TextStyle(
                              color: Color(0xFFFF8555),
                              fontSize: 11,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.companyName,
                                style: const TextStyle(
                                  fontSize: AppTypography.scaleBodySmall,
                                  fontWeight: AppTypography.semiBold,
                                  color: AppTypography.darkTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                c.city.isNotEmpty ? c.city : 'India',
                                style: const TextStyle(
                                  fontSize: AppTypography.scaleLabelSmall,
                                  color: AppTypography.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c.typeLabel.split(' ').first.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFFFF8555),
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─── Dual Column Hub: Actionable Follow-ups ─────────────────────────────────

  Widget _buildPriorityActions(WidgetRef ref, BuildContext context) {
    final followUpsAsync = ref.watch(_followUpsProvider);

    return _IndustrialSectionBox(
      title: 'Actionable Follow-ups',
      icon: Icons.notifications_active_rounded,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'PRIORITY',
          style: TextStyle(
            color: AppTheme.error,
            fontSize: 9,
            fontWeight: AppTypography.bold,
          ),
        ),
      ),
      child: followUpsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
        ),
        error: (_, __) => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text(
              'Schedule unavailable',
              style: TextStyle(color: AppTypography.darkTextMuted, fontSize: AppTypography.scaleLabelMedium),
            ),
          ),
        ),
        data: (followUps) {
          if (followUps.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'All client follow-ups up to date',
                  style: TextStyle(color: AppTheme.success, fontSize: AppTypography.scaleLabelMedium, fontWeight: AppTypography.semiBold),
                ),
              ),
            );
          }
          return Column(
            children: followUps.take(5).map((f) {
              final lead = f as Map<String, dynamic>;
              final followUp = DateTime.tryParse(lead['nextFollowUp'] as String? ?? '');
              final isOverdue = followUp != null && followUp.isBefore(DateTime.now());

              return InkWell(
                onTap: () => context.go('/crm/leads'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0x15FFFFFF))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: (isOverdue ? AppTheme.error : AppTheme.primary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.phone_in_talk_rounded,
                          color: isOverdue ? AppTheme.error : AppTheme.primary,
                          size: 15,
                        ),
                      ),
                      AppSpacing.gapW12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lead['companyName'] as String? ?? 'Lead Contact',
                              style: const TextStyle(
                                fontSize: AppTypography.scaleBodySmall,
                                fontWeight: AppTypography.semiBold,
                                color: AppTypography.darkTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (followUp != null)
                              Text(
                                '${followUp.day}/${followUp.month}/${followUp.year}',
                                style: TextStyle(
                                  fontSize: AppTypography.scaleLabelSmall,
                                  color: isOverdue ? AppTheme.error : AppTypography.darkTextSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isOverdue ? AppTheme.error : AppTheme.warning).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOverdue ? 'OVERDUE' : 'DUE',
                          style: TextStyle(
                            fontSize: 9,
                            color: isOverdue ? AppTheme.error : AppTheme.warning,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ─── Error Banner ───────────────────────────────────────────────────────────

  Widget _buildErrorBanner(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Industrial Supporting Widgets ────────────────────────────────────────────

class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot();

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.3 + (0.6 * _controller.value)),
                blurRadius: 4 + (3 * _controller.value),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IndustrialRefreshButton extends StatefulWidget {
  final bool isRefreshing;
  final VoidCallback onPressed;

  const _IndustrialRefreshButton({
    required this.isRefreshing,
    required this.onPressed,
  });

  @override
  State<_IndustrialRefreshButton> createState() => _IndustrialRefreshButtonState();
}

class _IndustrialRefreshButtonState extends State<_IndustrialRefreshButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didUpdateWidget(covariant _IndustrialRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      _controller.repeat();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        _controller.forward(from: 0.0);
        widget.onPressed();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF15A24).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF15A24).withValues(alpha: 0.3)),
        ),
        child: RotationTransition(
          turns: _controller,
          child: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFFF15A24)),
        ),
      ),
    );
  }
}

class _IndustrialMetric {
  final String title;
  final String tag;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String route;
  final bool isAlert;

  const _IndustrialMetric({
    required this.title,
    required this.tag,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.route,
    this.isAlert = false,
  });
}

class _IndustrialMetricCard extends StatefulWidget {
  final _IndustrialMetric metric;
  const _IndustrialMetricCard({required this.metric});

  @override
  State<_IndustrialMetricCard> createState() => _IndustrialMetricCardState();
}

class _IndustrialMetricCardState extends State<_IndustrialMetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.metric;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF1B1E28) : const Color(0xFF161922),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? const Color(0xFFF15A24) : Colors.white10,
            width: _isHovered ? 1.3 : 1.0,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: const Color(0xFFF15A24).withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(m.route),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: AppSpacing.allBase,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: m.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(m.icon, color: m.accentColor, size: 18),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.isAlert)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Icon(
                            Icons.arrow_outward_rounded,
                            size: 14,
                            color: _isHovered ? AppTheme.primary : AppTypography.darkTextMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.value,
                        style: const TextStyle(
                          fontSize: AppTypography.scaleDisplaySmall,
                          fontWeight: AppTypography.bold,
                          color: AppTypography.darkTextPrimary,
                          letterSpacing: 0.3,
                          height: AppTypography.leadingDisplay,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.gapH2,
                      Text(
                        m.title,
                        style: TextStyle(
                          color: _isHovered ? AppTheme.primary : AppTypography.darkTextPrimary,
                          fontSize: AppTypography.scaleBodySmall,
                          fontWeight: AppTypography.semiBold,
                          height: AppTypography.leadingTitle,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        m.tag,
                        style: const TextStyle(
                          color: AppTypography.darkTextSecondary,
                          fontSize: AppTypography.scaleMicro,
                          fontWeight: AppTypography.medium,
                          height: AppTypography.leadingCaption,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsoleTileData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color accentColor;

  const _ConsoleTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.accentColor,
  });
}

class _ConsoleTile extends StatefulWidget {
  final _ConsoleTileData data;
  const _ConsoleTile({required this.data});

  @override
  State<_ConsoleTile> createState() => _ConsoleTileState();
}

class _ConsoleTileState extends State<_ConsoleTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF1E222D) : const Color(0xFF12141C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isHovered ? AppTheme.primary : AppTheme.darkBorder,
            width: _isHovered ? 1.2 : 0.8,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(d.route),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: d.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(d.icon, color: d.accentColor, size: 18),
                  ),
                  AppSpacing.gapW12,
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title,
                          style: TextStyle(
                            fontSize: AppTypography.scaleBodySmall,
                            fontWeight: AppTypography.semiBold,
                            color: _isHovered ? AppTheme.primary : AppTypography.darkTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AppSpacing.gapH2,
                        Text(
                          d.subtitle,
                          style: const TextStyle(
                            fontSize: AppTypography.scaleLabelSmall,
                            color: AppTypography.darkTextSecondary,
                            height: AppTypography.leadingBody,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _isHovered ? AppTheme.primary : AppTypography.darkTextMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndustrialSectionBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Widget child;

  const _IndustrialSectionBox({
    required this.title,
    required this.icon,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFFF15A24)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x15FFFFFF)),
          child,
        ],
      ),
    );
  }
}
