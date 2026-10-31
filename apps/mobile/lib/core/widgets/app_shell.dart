import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/widgets/back_to_dashboard_button.dart';
import 'package:saark_erp_mobile/core/widgets/saark_logo.dart';

/// Opens the Enterprise Database Record Dashboard.
Future<void> _openDatabasePortal(BuildContext context) async {
  context.go('/admin/database');
}

// ─── Responsive Shell ────────────────────────────────────────────────────────


class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    if (widget.currentRoute.startsWith('/hr') ||
        widget.currentRoute.startsWith('/sales-marketing') ||
        widget.currentRoute.startsWith('/crm/customer-vendor') ||
        widget.currentRoute.startsWith('/production') ||
        widget.currentRoute.startsWith('/admin/database') ||
        widget.currentRoute.startsWith('/database')) {
      return widget.child;
    }

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;

    if (isDesktop) return _DesktopShell(currentRoute: widget.currentRoute, child: widget.child);
    if (isTablet) return _TabletShell(currentRoute: widget.currentRoute, child: widget.child);
    return _MobileShell(currentRoute: widget.currentRoute, child: widget.child);
  }
}

// ─── Navigation Items ────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

List<_NavItem> _getAuthorizedNavItems(AuthUser? user) {
  if (user == null) return [];

  final items = <_NavItem>[
    const _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      route: '/dashboard',
    ),
  ];

  // 1. Sales & Marketing
  if (user.isAdmin || user.canView('CRM') || user.canView('CUSTOMERS') || user.canView('SALES')) {
    items.add(const _NavItem(
      label: 'Sales & Marketing',
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign,
      route: '/sales-marketing',
    ));
  }

  // 2. B2B Trading
  if (user.isAdmin || user.canView('CRM') || user.canView('SALES')) {
    items.add(const _NavItem(
      label: 'B2B Trading',
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
      route: '/crm/enquiries',
    ));
  }

  // 3. Production Process
  if (user.isAdmin || user.canView('PRODUCTION')) {
    items.add(const _NavItem(
      label: 'Production Process',
      icon: Icons.precision_manufacturing_outlined,
      activeIcon: Icons.precision_manufacturing,
      route: '/production',
    ));
  }

  // 4. Project Management / Professional Services
  if (user.isAdmin || user.canView('PROJECTS')) {
    items.add(const _NavItem(
      label: 'Project Management / Professional Services',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      route: '/projects',
    ));
  }

  // 5. Task Manager
  if (user.isAdmin || user.canView('TASKS')) {
    items.add(const _NavItem(
      label: 'Task Manager',
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt,
      route: '/tasks',
    ));
  }

  // 6. Quality Control (QC) / Quality Assurance (QA)
  if (user.isAdmin || user.canView('PRODUCTION')) {
    items.add(const _NavItem(
      label: 'Quality Control (QC) / Quality Assurance (QA)',
      icon: Icons.verified_outlined,
      activeIcon: Icons.verified,
      route: '/production/management',
    ));
  }

  // 7. Panel Manufacturing
  if (user.isAdmin || user.canView('PRODUCTION')) {
    items.add(const _NavItem(
      label: 'Panel Manufacturing',
      icon: Icons.build_circle_outlined,
      activeIcon: Icons.build_circle,
      route: '/production/new',
    ));
  }

  // 8. Accounts & Finance
  if (user.isAdmin || user.canView('ACCOUNTS')) {
    items.add(const _NavItem(
      label: 'Accounts & Finance',
      icon: Icons.account_balance_outlined,
      activeIcon: Icons.account_balance,
      route: '/accounts',
    ));
  }

  // 9. HR (Human Resources)
  if (user.isAdmin || user.canView('HR') || user.canView('STAFF')) {
    items.add(const _NavItem(
      label: 'HR (Human Resources)',
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt,
      route: '/hr',
    ));
  }

  // 10. Attendance (Biometric Punching Device)
  if (user.isAdmin || user.canView('ATTENDANCE') || user.canView('HR')) {
    items.add(const _NavItem(
      label: 'Attendance',
      icon: Icons.access_time_outlined,
      activeIcon: Icons.access_time,
      route: '/attendance',
    ));
  }

  // 11. Purchase / Procurement
  if (user.isAdmin || user.canView('PURCHASE')) {
    items.add(const _NavItem(
      label: 'Purchase / Procurement',
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag,
      route: '/purchase/orders',
    ));
  }

  // 11. Stores / Warehouse
  if (user.isAdmin || user.canView('INVENTORY')) {
    items.add(const _NavItem(
      label: 'Stores / Warehouse',
      icon: Icons.warehouse_outlined,
      activeIcon: Icons.warehouse,
      route: '/inventory',
    ));
  }

  // 12. Maintenance
  if (user.isAdmin || user.canView('TASKS') || user.canView('PRODUCTION')) {
    items.add(const _NavItem(
      label: 'Maintenance',
      icon: Icons.home_repair_service_outlined,
      activeIcon: Icons.home_repair_service,
      route: '/my-work',
    ));
  }

  // 13. R&D / Engineering
  if (user.isAdmin || user.canView('PRODUCTION')) {
    items.add(const _NavItem(
      label: 'R&D / Engineering',
      icon: Icons.science_outlined,
      activeIcon: Icons.science,
      route: '/production/specs',
    ));
  }

  // 14. Asset Management / Fixed Assets
  if (user.isAdmin || user.canView('INVENTORY') || user.canView('ACCOUNTS')) {
    items.add(const _NavItem(
      label: 'Asset Management / Fixed Assets',
      icon: Icons.domain_outlined,
      activeIcon: Icons.domain,
      route: '/inventory?view=assets',
    ));
  }

  // 15. EHS / Risk Management
  if (user.isAdmin || user.canView('PROJECTS')) {
    items.add(const _NavItem(
      label: 'EHS / Risk Management',
      icon: Icons.shield_outlined,
      activeIcon: Icons.shield,
      route: '/projects?view=ehs',
    ));
  }

  // 16. Point of Sale (POS) / E-Commerce
  if (user.isAdmin || user.canView('SALES') || user.canView('CRM')) {
    items.add(const _NavItem(
      label: 'Point of Sale (POS) / E-Commerce',
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale,
      route: '/crm/invoices',
    ));
  }

  // 17. IT
  if (user.isAdmin) {
    items.add(const _NavItem(
      label: 'IT',
      icon: Icons.computer_outlined,
      activeIcon: Icons.computer,
      route: '/admin?section=it',
    ));
  }

  // 18. Customer Service
  if (user.isAdmin || user.canView('CRM') || user.canView('CUSTOMERS')) {
    items.add(const _NavItem(
      label: 'Customer Service',
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent,
      route: '/crm/follow-ups',
    ));
  }

  // 19. Legal & Compliance
  if (user.isAdmin || user.canView('REPORTS')) {
    items.add(const _NavItem(
      label: 'Legal & Compliance',
      icon: Icons.gavel_outlined,
      activeIcon: Icons.gavel,
      route: '/reports?section=compliance',
    ));
  }

  // 20. Administration
  if (user.isAdmin) {
    items.add(const _NavItem(
      label: 'Administration',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      route: '/admin',
    ));
  }

  // 21. Supply Chain / Logistics
  if (user.isAdmin || user.canView('PURCHASE') || user.canView('INVENTORY') || user.canView('VENDORS')) {
    items.add(const _NavItem(
      label: 'Supply Chain / Logistics',
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping,
      route: '/vendors',
    ));
  }

  return items;
}

int _getNavIndex(List<_NavItem> items, String route) {
  for (int i = 0; i < items.length; i++) {
    if (items[i].route == route) return i;
  }
  if (route.startsWith('/admin/database') || route.startsWith('/database')) {
    final idx = items.indexWhere((it) => it.route == '/admin/database');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/sales-marketing')) {
    final idx = items.indexWhere((it) => it.route == '/sales-marketing');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/crm/enquiries')) {
    final idx = items.indexWhere((it) => it.route == '/crm/enquiries');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/crm/follow-ups') || route.startsWith('/customers')) {
    final idx = items.indexWhere((it) => it.route == '/crm/follow-ups');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/crm/invoices')) {
    final idx = items.indexWhere((it) => it.route == '/crm/invoices');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/crm') || route.startsWith('/sales')) {
    final idx = items.indexWhere((it) => it.route == '/sales-marketing');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/production/management')) {
    final idx = items.indexWhere((it) => it.route == '/production/management');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/production/new')) {
    final idx = items.indexWhere((it) => it.route == '/production/new');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/production/specs')) {
    final idx = items.indexWhere((it) => it.route == '/production/specs');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/production')) {
    final idx = items.indexWhere((it) => it.route == '/production');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/inventory')) {
    final idx = items.indexWhere((it) => it.route == '/inventory');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/purchase')) {
    final idx = items.indexWhere((it) => it.route.startsWith('/purchase'));
    if (idx != -1) return idx;
  }
  if (route.startsWith('/projects')) {
    final idx = items.indexWhere((it) => it.route.startsWith('/projects'));
    if (idx != -1) return idx;
  }
  if (route.startsWith('/tasks')) {
    final idx = items.indexWhere((it) => it.route == '/tasks');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/my-work')) {
    final idx = items.indexWhere((it) => it.route == '/my-work');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/accounts')) {
    final idx = items.indexWhere((it) => it.route == '/accounts');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/hr') || route.startsWith('/staff')) {
    final idx = items.indexWhere((it) => it.route == '/hr');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/reports')) {
    final idx = items.indexWhere((it) => it.route.startsWith('/reports'));
    if (idx != -1) return idx;
  }
  if (route.startsWith('/admin')) {
    final idx = items.indexWhere((it) => it.route == '/admin');
    if (idx != -1) return idx;
  }
  if (route.startsWith('/vendors')) {
    final idx = items.indexWhere((it) => it.route == '/vendors');
    if (idx != -1) return idx;
  }
  if (route == '/dashboard' || route == '/') {
    return 0;
  }
  return 0;
}

// ─── Desktop Shell ───────────────────────────────────────────────────────────

class _DesktopShell extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const _DesktopShell({required this.child, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final navItems = _getAuthorizedNavItems(user);
    final selectedIdx = _getNavIndex(navItems, currentRoute);
    final isDashboard = currentRoute == '/dashboard' || currentRoute == '/';

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: AppTheme.darkSurface,
            child: Column(
              children: [
                // Logo
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SaarkBrandHeader(
                      badgeSize: 34,
                      fontSize: 13,
                      isCompact: false,
                      onTap: () {
                        if (currentRoute != '/dashboard' && currentRoute != '/') {
                          context.go('/dashboard');
                        }
                      },
                      onDoubleTap: isDashboard
                          ? () => _openDatabasePortal(context)
                          : null,
                    ),
                  ),
                ),
                // Navigation items
                Expanded(
                  child: isDashboard
                      ? ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: navItems.map((item) {
                            final isActive = navItems.indexOf(item) == selectedIdx;
                            return _SidebarItem(
                              item: item,
                              isActive: isActive,
                              onTap: () => context.go(item.route),
                            );
                          }).toList(),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
                              child: Text(
                                'ACTIVE MODULE',
                                style: TextStyle(
                                  fontSize: AppTypography.scaleMicro,
                                  fontWeight: AppTypography.bold,
                                  letterSpacing: 1.2,
                                  color: AppTypography.darkTextMuted,
                                ),
                              ),
                            ),
                            if (selectedIdx >= 0 && selectedIdx < navItems.length)
                              _SidebarItem(
                                item: navItems[selectedIdx],
                                isActive: true,
                                onTap: () {},
                              ),
                            // Notice: Other modules locked until return to Dashboard
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
                              padding: AppSpacing.pMd,
                              decoration: BoxDecoration(
                                color: AppTheme.darkBackground.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.darkBorder),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.lock_outline, size: 14, color: AppTheme.warning),
                                      AppSpacing.gapW6,
                                      Text(
                                        'Modules Locked',
                                        style: TextStyle(
                                          fontSize: AppTypography.scaleLabelMedium,
                                          fontWeight: AppTypography.semiBold,
                                          color: AppTypography.darkTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  AppSpacing.gapH6,
                                  Text(
                                    'Other modules (HR, Admin, etc.) are disabled while inside this module.\n\nClick "Back to Dashboard" above to switch modules.',
                                    style: TextStyle(
                                      fontSize: AppTypography.scaleLabelSmall,
                                      color: AppTypography.darkTextSecondary,
                                      height: AppTypography.leadingBody,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                // User profile at bottom
                Container(
                  padding: AppSpacing.pMd,
                  color: AppTheme.darkBackground,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          (user?.fullName.isNotEmpty == true)
                              ? user!.fullName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: AppTypography.bold),
                        ),
                      ),
                      AppSpacing.gapW8,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'User',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: AppTypography.semiBold,
                                color: AppTypography.darkTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.designation ?? user?.roles.firstOrNull ?? '',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppTypography.darkTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 16, color: AppTypography.darkTextSecondary),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _TopHeader(currentRoute: currentRoute, user: user, ref: ref),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tablet Shell (Navigation Rail) ─────────────────────────────────────────

class _TabletShell extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const _TabletShell({required this.child, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final navItems = _getAuthorizedNavItems(user);
    final selectedIndex = _getNavIndex(navItems, currentRoute);
    final isDashboard = currentRoute == '/dashboard' || currentRoute == '/';

    if (!isDashboard) {
      final activeItem = (selectedIndex >= 0 && selectedIndex < navItems.length)
          ? navItems[selectedIndex]
          : null;

      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppTheme.darkSurface,
              selectedIndex: 1,
              onDestinationSelected: (i) {
                if (i == 0) {
                  context.go('/dashboard');
                }
              },
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: AppTheme.primary),
              selectedLabelTextStyle: const TextStyle(color: AppTheme.primary, fontSize: 10),
              unselectedIconTheme: const IconThemeData(color: Colors.grey, size: 22),
              unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.arrow_back),
                  selectedIcon: Icon(Icons.arrow_back),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(activeItem?.activeIcon ?? Icons.folder),
                  selectedIcon: Icon(activeItem?.activeIcon ?? Icons.folder),
                  label: Text(activeItem?.label.split(' ').first ?? 'Module'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppTheme.darkSurface,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (i) => context.go(navItems[i].route),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppTheme.primary),
            selectedLabelTextStyle: const TextStyle(color: AppTheme.primary, fontSize: 10),
            unselectedIconTheme: const IconThemeData(color: Colors.grey, size: 22),
            unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
            destinations: navItems.take(7).map((item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: Text(item.label),
            )).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Mobile Shell (Bottom Nav + Drawer) ──────────────────────────────────────

class _MobileBottomTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final bool isMore;

  const _MobileBottomTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.route = '',
    this.isMore = false,
  });
}

class _MobileShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const _MobileShell({required this.child, required this.currentRoute});

  @override
  ConsumerState<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<_MobileShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final navItems = _getAuthorizedNavItems(user);
    final isDashboard = widget.currentRoute == '/dashboard' || widget.currentRoute == '/';

    // Build responsive mobile bottom destinations
    final mobileTabs = <_MobileBottomTab>[
      const _MobileBottomTab(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        route: '/dashboard',
      ),
    ];

    if (user?.canView('CRM') == true || user?.canView('CUSTOMERS') == true) {
      mobileTabs.add(const _MobileBottomTab(
        label: 'Sales & Mktg',
        icon: Icons.campaign_outlined,
        activeIcon: Icons.campaign,
        route: '/sales-marketing',
      ));
    }

    if (user?.canView('TASKS') == true) {
      mobileTabs.add(const _MobileBottomTab(
        label: 'Tasks',
        icon: Icons.task_alt_outlined,
        activeIcon: Icons.task_alt,
        route: '/tasks',
      ));
    } else if (user?.canView('PROJECTS') == true) {
      mobileTabs.add(const _MobileBottomTab(
        label: 'Projects',
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        route: '/projects',
      ));
    }

    mobileTabs.add(const _MobileBottomTab(
      label: 'My Work',
      icon: Icons.home_repair_service_outlined,
      activeIcon: Icons.home_repair_service,
      route: '/my-work',
    ));

    mobileTabs.add(const _MobileBottomTab(
      label: 'More',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      isMore: true,
    ));

    // Determine active index for mobile bottom navigation
    int selectedIndex = -1;
    for (int i = 0; i < mobileTabs.length; i++) {
      if (mobileTabs[i].isMore) continue;
      final r = mobileTabs[i].route;
      if (r == '/dashboard' && isDashboard) {
        selectedIndex = i;
        break;
      }
      if (r != '/dashboard' && widget.currentRoute.startsWith(r)) {
        selectedIndex = i;
        break;
      }
    }

    // Check if on sub-CRM routes like /crm/pipeline, /crm/follow-ups, /crm/leads, /crm/enquiries, /sales-marketing, /sales
    if (selectedIndex == -1 && (widget.currentRoute.startsWith('/crm') || widget.currentRoute.startsWith('/sales-marketing') || widget.currentRoute.startsWith('/customers') || widget.currentRoute.startsWith('/sales'))) {
      final crmIdx = mobileTabs.indexWhere((t) => t.route == '/sales-marketing' || t.route == '/crm/dashboard');
      if (crmIdx != -1) selectedIndex = crmIdx;
    }

    // Default to the "More" tab if current page is from the drawer (e.g. /vendors, /inventory, etc.)
    if (selectedIndex == -1) {
      final moreIdx = mobileTabs.indexWhere((t) => t.isMore);
      selectedIndex = moreIdx != -1 ? moreIdx : 0;
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: isDashboard
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: SaarkBrandHeader(
                badgeSize: 28,
                fontSize: 13,
                isCompact: true,
                onTap: () {
                  if (widget.currentRoute != '/dashboard' && widget.currentRoute != '/') {
                    context.go('/dashboard');
                  }
                },
                onDoubleTap: isDashboard
                    ? () => _openDatabasePortal(context)
                    : null,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                PopupMenuButton(
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      (user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'A',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      child: const Row(children: [Icon(Icons.logout, size: 16), SizedBox(width: 8), Text('Logout')]),
                      onTap: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      drawer: _buildDrawer(context, user, navItems),
      body: widget.child,
      bottomNavigationBar: mobileTabs.isNotEmpty
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) {
                if (mobileTabs[i].isMore) {
                  _scaffoldKey.currentState?.openDrawer();
                } else {
                  context.go(mobileTabs[i].route);
                }
              },
              backgroundColor: AppTheme.darkSurface,
              indicatorColor: AppTheme.primary.withValues(alpha: 0.2),
              destinations: mobileTabs.map((item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon, color: AppTheme.primary),
                label: item.label,
              )).toList(),
            )
          : null,
    );
  }

  Widget _buildDrawer(BuildContext context, AuthUser? user, List<_NavItem> navItems) {
    final isDashboard = widget.currentRoute == '/dashboard' || widget.currentRoute == '/';
    final selectedIdx = _getNavIndex(navItems, widget.currentRoute);

    return Drawer(
      backgroundColor: AppTheme.darkSurface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.darkBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SaarkFullLogoCard(width: double.infinity, height: 60, padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          (user?.fullName.isNotEmpty == true) ? user!.fullName[0] : 'A',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'User',
                              style: const TextStyle(
                                fontWeight: AppTypography.bold,
                                fontSize: AppTypography.scaleTitleMedium,
                                color: AppTypography.darkTextPrimary,
                              ),
                            ),
                            Text(
                              user?.designation ?? '',
                              style: const TextStyle(
                                color: AppTypography.darkTextSecondary,
                                fontSize: AppTypography.scaleLabelMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: isDashboard
                  ? ListView(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      children: navItems.map((item) {
                        final isActive = navItems.indexOf(item) == selectedIdx;
                        return ListTile(
                          leading: Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive ? AppTheme.primary : AppTypography.darkTextMuted,
                            size: 20,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: isActive ? AppTheme.primary : AppTypography.darkTextPrimary,
                              fontWeight: isActive ? AppTypography.semiBold : AppTypography.regular,
                              fontSize: AppTypography.scaleTitleSmall,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            context.go(item.route);
                          },
                        );
                      }).toList(),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.arrow_back, color: Color(0xFFF15A24), size: 22),
                          title: const Text(
                            'Back to Dashboard',
                            style: TextStyle(
                              color: Color(0xFFF15A24),
                              fontWeight: AppTypography.bold,
                              fontSize: AppTypography.scaleTitleSmall,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            context.go('/dashboard');
                          },
                        ),
                        const Divider(color: AppTheme.darkBorder),
                        if (selectedIdx >= 0 && selectedIdx < navItems.length)
                          ListTile(
                            leading: Icon(
                              navItems[selectedIdx].activeIcon,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            title: Text(
                              navItems[selectedIdx].label,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: AppTypography.bold,
                                fontSize: AppTypography.scaleTitleSmall,
                              ),
                            ),
                            subtitle: const Text(
                              'Active Module',
                              style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: 11),
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                        Container(
                          margin: AppSpacing.allMd,
                          padding: AppSpacing.allMd,
                          decoration: BoxDecoration(
                            color: AppTheme.darkBackground.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 16, color: AppTheme.warning),
                              AppSpacing.gapW8,
                              Expanded(
                                child: Text(
                                  'Other modules (HR, Admin, etc.) are locked. Return to Dashboard to switch modules.',
                                  style: TextStyle(
                                    fontSize: AppTypography.scaleLabelSmall,
                                    color: AppTypography.darkTextSecondary,
                                    height: AppTypography.leadingBody,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, size: 20, color: AppTypography.darkTextSecondary),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppTypography.darkTextSecondary, fontSize: AppTypography.scaleTitleSmall),
              ),
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sidebar Item ─────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({required this.item, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: AppTheme.primary.withValues(alpha: 0.35)) : null,
        ),
        child: Row(
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 18,
              color: isActive ? AppTheme.primary : AppTypography.darkTextMuted,
            ),
            AppSpacing.gapW10,
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: AppTypography.scaleBodySmall,
                  height: AppTypography.leadingLabel,
                  fontWeight: isActive ? AppTypography.semiBold : AppTypography.regular,
                  color: isActive ? AppTheme.primary : AppTypography.darkTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Header ───────────────────────────────────────────────────────────────

class _TopHeader extends StatelessWidget {
  final String currentRoute;
  final AuthUser? user;
  final WidgetRef ref;

  const _TopHeader({required this.currentRoute, this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          if (currentRoute != '/dashboard' && currentRoute != '/') ...[
            const BackToDashboardButton(),
            AppSpacing.gapW12,
            Container(width: 1, height: 24, color: AppTheme.darkBorder),
            AppSpacing.gapW12,
          ],
          // Breadcrumb
          const Icon(Icons.chevron_right, size: 16, color: AppTypography.darkTextMuted),
          AppSpacing.gapW4,
          Text(
            _getPageTitle(currentRoute),
            style: const TextStyle(
              fontWeight: AppTypography.semiBold,
              fontSize: AppTypography.scaleTitleMedium,
              height: AppTypography.leadingTitle,
              color: AppTypography.darkTextPrimary,
            ),
          ),
          const Spacer(),
          // Global Search
          Container(
            width: 240,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search modules & records...',
                prefixIcon: Icon(Icons.search, size: 16, color: AppTypography.darkTextMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                hintStyle: TextStyle(
                  fontSize: AppTypography.scaleBodySmall,
                  color: AppTypography.darkTextMuted,
                ),
              ),
              style: TextStyle(
                fontSize: AppTypography.scaleBodySmall,
                color: AppTypography.darkTextPrimary,
              ),
            ),
          ),
          AppSpacing.gapW16,
          // Notifications
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: AppTypography.darkTextSecondary),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          // User Avatar + dropdown
          PopupMenuButton(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    (user?.fullName.isNotEmpty == true) ? user!.fullName[0] : 'A',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.fullName ?? 'User',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(user?.designation ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
              ],
            ),
            itemBuilder: (_) => <PopupMenuEntry>[
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.person_outline, size: 16), SizedBox(width: 8), Text('My Profile')]),
                onTap: () {},
              ),
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.settings_outlined, size: 16), SizedBox(width: 8), Text('Settings')]),
                onTap: () {},
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.logout, size: 16, color: Colors.red), SizedBox(width: 8), Text('Logout', style: TextStyle(color: Colors.red))]),
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPageTitle(String route) {
    if (route.startsWith('/dashboard')) return 'Dashboard';
    if (route.startsWith('/sales-marketing')) return 'Sales & Marketing';
    if (route.startsWith('/crm/enquiries')) return 'B2B Trading';
    if (route.startsWith('/crm/follow-ups') || route.startsWith('/customers')) return 'Customer Service';
    if (route.startsWith('/crm/invoices') || route.startsWith('/sales/invoices')) return 'Point of Sale (POS) / E-Commerce';
    if (route.startsWith('/crm') || route.startsWith('/sales')) return 'Sales & Marketing';
    if (route.startsWith('/production/management')) return 'Quality Control (QC) / QA';
    if (route.startsWith('/production/new')) return 'Panel Manufacturing';
    if (route.startsWith('/production/specs')) return 'R&D / Engineering';
    if (route.startsWith('/production')) return 'Production Process';
    if (route.startsWith('/projects')) return 'Project Management / Professional Services';
    if (route.startsWith('/tasks')) return 'Task Manager';
    if (route.startsWith('/my-work')) return 'Maintenance';
    if (route.startsWith('/accounts')) return 'Accounts & Finance';
    if (route.startsWith('/hr') || route.startsWith('/staff')) return 'HR (Human Resources)';
    if (route.startsWith('/purchase')) return 'Purchase / Procurement';
    if (route.startsWith('/inventory')) return 'Stores / Warehouse';
    if (route.startsWith('/vendors')) return 'Supply Chain / Logistics';
    if (route.startsWith('/reports')) return 'Legal & Compliance';
    if (route.startsWith('/admin')) return 'Administration & IT';
    return 'ERP';
  }
}
