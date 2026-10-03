import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/widgets/app_shell.dart';
import 'package:saark_erp_mobile/features/authentication/presentation/pages/login_page.dart';
import 'package:saark_erp_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:saark_erp_mobile/features/customers/presentation/pages/customers_list_page.dart';
import 'package:saark_erp_mobile/features/customers/presentation/pages/customer_detail_page.dart';
import 'package:saark_erp_mobile/features/customers/presentation/pages/customer_form_page.dart';
import 'package:saark_erp_mobile/features/vendors/presentation/pages/vendors_list_page.dart';
import 'package:saark_erp_mobile/features/products/presentation/pages/products_list_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/leads_list_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/enquiries_list_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/crm_dashboard_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/crm_pipeline_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/crm_follow_ups_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/crm_analytics_page.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_specs_list_page.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_spec_detail_page.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_spec_form_page.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/pages/purchase_dashboard_page.dart';
import 'package:saark_erp_mobile/features/my_work/presentation/pages/my_work_page.dart';
import 'package:saark_erp_mobile/features/tasks/presentation/pages/tasks_list_page.dart';
import 'package:saark_erp_mobile/features/projects/presentation/pages/projects_list_page.dart';
import 'package:saark_erp_mobile/features/projects/presentation/pages/project_detail_page.dart';
import 'package:saark_erp_mobile/features/staff/presentation/pages/staff_directory_page.dart';
import 'package:saark_erp_mobile/features/hr/presentation/pages/hr_dashboard_page.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isLoggedIn = authState.isAuthenticated;
    final isLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginPage) return '/login';
    if (isLoggedIn && isLoginPage) return '/dashboard';
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ─── Auth ──────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // ─── Main Shell ────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(
          child: child,
          currentRoute: state.matchedLocation,
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardPage(),
          ),

          // ─── My Work ─────────────────────────────────────────────
          GoRoute(
            path: '/my-work',
            name: 'my-work',
            builder: (context, state) => const MyWorkPage(),
          ),

          // ─── Staff Directory ─────────────────────────────────────
          GoRoute(
            path: '/staff',
            name: 'staff',
            builder: (context, state) => const StaffDirectoryPage(),
          ),

          // ─── Tasks ───────────────────────────────────────────────
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            builder: (context, state) => const TasksListPage(),
          ),

          // ─── Projects ────────────────────────────────────────────
          GoRoute(
            path: '/projects',
            name: 'projects',
            builder: (context, state) => const ProjectsListPage(),
          ),
          GoRoute(
            path: '/projects/:id',
            name: 'project-detail',
            builder: (context, state) =>
                ProjectDetailPage(projectId: state.pathParameters['id']!),
          ),

          // ─── Customers ───────────────────────────────────────────
          GoRoute(
            path: '/customers',
            name: 'customers',
            builder: (context, state) => const CustomersListPage(),
          ),
          GoRoute(
            path: '/customers/new',
            name: 'customer-new',
            builder: (context, state) => const CustomerFormPage(),
          ),
          GoRoute(
            path: '/customers/:id',
            name: 'customer-detail',
            builder: (context, state) =>
                CustomerDetailPage(customerId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/customers/:id/edit',
            name: 'customer-edit',
            builder: (context, state) =>
                CustomerFormPage(customerId: state.pathParameters['id']),
          ),

          // ─── Vendors ─────────────────────────────────────────────
          GoRoute(
            path: '/vendors',
            name: 'vendors',
            builder: (context, state) => const VendorsListPage(),
          ),

          // ─── Products ────────────────────────────────────────────
          GoRoute(
            path: '/products',
            name: 'products',
            builder: (context, state) => const ProductsListPage(),
          ),

          // ─── CRM ─────────────────────────────────────────────────
          GoRoute(
            path: '/crm/dashboard',
            name: 'crm-dashboard',
            builder: (context, state) => const CrmDashboardPage(),
          ),
          GoRoute(
            path: '/crm/leads',
            name: 'crm-leads',
            builder: (context, state) => const LeadsListPage(),
          ),
          GoRoute(
            path: '/crm/enquiries',
            name: 'crm-enquiries',
            builder: (context, state) => const EnquiriesListPage(),
          ),
          GoRoute(
            path: '/crm/pipeline',
            name: 'crm-pipeline',
            builder: (context, state) => const CrmPipelinePage(),
          ),
          GoRoute(
            path: '/crm/follow-ups',
            name: 'crm-follow-ups',
            builder: (context, state) => const CrmFollowUpsPage(),
          ),
          GoRoute(
            path: '/crm/analytics',
            name: 'crm-analytics',
            builder: (context, state) => const CrmAnalyticsPage(),
          ),

          // ─── Phase 2 Modules (placeholder pages) ─────────────────
          GoRoute(path: '/sales/quotations', builder: (_, __) => _comingSoon('Sales — Phase 2')),
          GoRoute(path: '/sales/orders', builder: (_, __) => _comingSoon('Sales Orders — Phase 2')),
          GoRoute(path: '/sales/invoices', builder: (_, __) => _comingSoon('Invoices — Phase 2')),
          // ─── Purchase / Procurement Module ───────────────────────
          GoRoute(
            path: '/purchase',
            name: 'purchase',
            builder: (context, state) => const PurchaseDashboardPage(),
          ),
          GoRoute(
            path: '/purchase/orders',
            name: 'purchase-orders',
            builder: (context, state) => const PurchaseDashboardPage(),
          ),
          GoRoute(
            path: '/purchase/inward',
            name: 'purchase-inward',
            builder: (context, state) => const PurchaseDashboardPage(),
          ),
          GoRoute(path: '/inventory', builder: (_, __) => _comingSoon('Inventory — Phase 2')),
          // ─── Production / Panel Manufacturing ────────────────────
          GoRoute(
            path: '/production',
            name: 'production',
            builder: (context, state) => const PanelSpecsListPage(),
          ),
          GoRoute(
            path: '/production/new',
            name: 'production-new',
            builder: (context, state) => const PanelSpecFormPage(),
          ),
          GoRoute(
            path: '/production/:id',
            name: 'production-detail',
            builder: (context, state) =>
                PanelSpecDetailPage(specId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/accounts', builder: (_, __) => _comingSoon('Accounts — Phase 2')),
          GoRoute(
            path: '/hr',
            name: 'hr-dashboard',
            builder: (context, state) => const HrDashboardPage(),
          ),
          GoRoute(
            path: '/hr/employees',
            name: 'hr-employees',
            builder: (context, state) => const HrDashboardPage(),
          ),
          GoRoute(path: '/reports', builder: (_, __) => _comingSoon('Reports — Phase 2')),
          GoRoute(path: '/admin', builder: (_, __) => _comingSoon('Administration — Phase 2')),
        ],
      ),
    ],
  );
});

Widget _comingSoon(String label) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This module will be available in Phase 2',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
