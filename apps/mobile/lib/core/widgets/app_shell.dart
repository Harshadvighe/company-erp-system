import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';

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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;

    if (isDesktop) return _DesktopShell(child: widget.child, currentRoute: widget.currentRoute);
    if (isTablet) return _TabletShell(child: widget.child, currentRoute: widget.currentRoute);
    return _MobileShell(child: widget.child, currentRoute: widget.currentRoute);
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

final _navItems = [
  const _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, route: '/dashboard'),
  const _NavItem(label: 'CRM', icon: Icons.people_outline, activeIcon: Icons.people, route: '/crm/leads'),
  const _NavItem(label: 'Customers', icon: Icons.person_outline, activeIcon: Icons.person, route: '/customers'),
  const _NavItem(label: 'Sales', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, route: '/sales/quotations'),
  const _NavItem(label: 'Purchase', icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag, route: '/purchase/orders'),
  const _NavItem(label: 'Inventory', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, route: '/inventory'),
  const _NavItem(label: 'Production', icon: Icons.precision_manufacturing_outlined, activeIcon: Icons.precision_manufacturing, route: '/production'),
  const _NavItem(label: 'Projects', icon: Icons.folder_outlined, activeIcon: Icons.folder, route: '/projects'),
  const _NavItem(label: 'Tasks', icon: Icons.task_alt_outlined, activeIcon: Icons.task_alt, route: '/tasks'),
  const _NavItem(label: 'Accounts', icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance, route: '/accounts'),
  const _NavItem(label: 'HR', icon: Icons.badge_outlined, activeIcon: Icons.badge, route: '/hr/employees'),
  const _NavItem(label: 'Vendors', icon: Icons.store_outlined, activeIcon: Icons.store, route: '/vendors'),
  const _NavItem(label: 'Products', icon: Icons.category_outlined, activeIcon: Icons.category, route: '/products'),
  const _NavItem(label: 'Reports', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, route: '/reports'),
  const _NavItem(label: 'Admin', icon: Icons.settings_outlined, activeIcon: Icons.settings, route: '/admin'),
];

// ─── Desktop Shell ───────────────────────────────────────────────────────────

class _DesktopShell extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const _DesktopShell({required this.child, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

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
                  color: AppTheme.darkBackground,
                  child: const Row(
                    children: [
                      Icon(Icons.water_drop_rounded, color: AppTheme.primary, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SAARK ERP',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Nav items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: _navItems.map((item) {
                      final isActive = currentRoute.startsWith(item.route) ||
                          (item.route == '/dashboard' && currentRoute == '/dashboard');
                      return _SidebarItem(
                        item: item,
                        isActive: isActive,
                        onTap: () => context.go(item.route),
                      );
                    }).toList(),
                  ),
                ),
                // User profile at bottom
                Container(
                  padding: const EdgeInsets.all(12),
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
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'User',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.designation ?? user?.roles.firstOrNull ?? '',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 16, color: Colors.grey),
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
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppTheme.darkSurface,
            selectedIndex: _getSelectedIndex(currentRoute),
            onDestinationSelected: (i) => context.go(_navItems[i].route),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppTheme.primary),
            selectedLabelTextStyle: const TextStyle(color: AppTheme.primary, fontSize: 10),
            unselectedIconTheme: const IconThemeData(color: Colors.grey, size: 22),
            unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
            destinations: _navItems.take(8).map((item) => NavigationRailDestination(
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

class _MobileShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const _MobileShell({required this.child, required this.currentRoute});

  @override
  ConsumerState<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<_MobileShell> {
  final _bottomNavItems = [
    _navItems[0], // Dashboard
    _navItems[1], // CRM
    _navItems[3], // Sales
    _navItems[8], // Tasks
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final selectedIndex = _getBottomNavIndex(widget.currentRoute);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.water_drop_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('SAARK', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppTheme.primary)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          PopupMenuButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary,
              child: Text(
                (user?.fullName.isNotEmpty == true) ? user!.fullName[0] : 'A',
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
      ),
      drawer: _buildDrawer(context, user),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (i) => context.go(_bottomNavItems[i].route),
        backgroundColor: AppTheme.darkSurface,
        indicatorColor: AppTheme.primary.withOpacity(0.2),
        destinations: _bottomNavItems.map((item) => NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.activeIcon, color: AppTheme.primary),
          label: item.label,
        )).toList(),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthUser? user) {
    return Drawer(
      backgroundColor: AppTheme.darkSurface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.darkBackground,
              child: Row(
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
                        Text(user?.fullName ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(user?.designation ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _navItems.map((item) {
                  final isActive = widget.currentRoute.startsWith(item.route);
                  return ListTile(
                    leading: Icon(
                      isActive ? item.activeIcon : item.icon,
                      color: isActive ? AppTheme.primary : Colors.grey,
                      size: 20,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? AppTheme.primary : null,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.go(item.route);
                    },
                  );
                }).toList(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, size: 20, color: Colors.grey),
              title: const Text('Logout', style: TextStyle(color: Colors.grey, fontSize: 14)),
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

  int _getBottomNavIndex(String route) {
    for (int i = 0; i < _bottomNavItems.length; i++) {
      if (route.startsWith(_bottomNavItems[i].route)) return i;
    }
    return 0;
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: AppTheme.primary.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 18,
              color: isActive ? AppTheme.primary : Colors.grey,
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppTheme.primary : Colors.white70,
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          // Breadcrumb
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            _getPageTitle(currentRoute),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const Spacer(),
          // Global Search
          Container(
            width: 220,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search, size: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                hintStyle: TextStyle(fontSize: 13),
              ),
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          // Notifications
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
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
    if (route.startsWith('/customers')) return 'Customers';
    if (route.startsWith('/vendors')) return 'Vendors';
    if (route.startsWith('/products')) return 'Products';
    if (route.startsWith('/crm/leads')) return 'Leads';
    if (route.startsWith('/crm/enquiries')) return 'Enquiries';
    if (route.startsWith('/sales')) return 'Sales';
    if (route.startsWith('/purchase')) return 'Purchase';
    if (route.startsWith('/inventory')) return 'Inventory';
    if (route.startsWith('/production')) return 'Production';
    if (route.startsWith('/projects')) return 'Projects';
    if (route.startsWith('/tasks')) return 'Tasks';
    if (route.startsWith('/hr')) return 'Human Resources';
    if (route.startsWith('/accounts')) return 'Accounts';
    if (route.startsWith('/reports')) return 'Reports';
    if (route.startsWith('/admin')) return 'Administration';
    return 'ERP';
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

int _getSelectedIndex(String route) {
  for (int i = 0; i < _navItems.length; i++) {
    if (route.startsWith(_navItems[i].route)) return i;
  }
  return 0;
}
