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
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_specs_list_page.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_spec_detail_page.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_spec_form_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/dashboard';
      return null;
    },
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
            path: '/crm/leads',
            name: 'crm-leads',
            builder: (context, state) => const LeadsListPage(),
          ),
          GoRoute(
            path: '/crm/enquiries',
            name: 'crm-enquiries',
            builder: (context, state) => const EnquiriesListPage(),
          ),

          // ─── Phase 2 Modules (placeholder pages) ─────────────────
          GoRoute(path: '/sales/quotations', builder: (_, __) => _comingSoon('Sales — Phase 2')),
          GoRoute(path: '/sales/orders', builder: (_, __) => _comingSoon('Sales Orders — Phase 2')),
          GoRoute(path: '/sales/invoices', builder: (_, __) => _comingSoon('Invoices — Phase 2')),
          GoRoute(path: '/purchase/orders', builder: (_, __) => _comingSoon('Purchase — Phase 2')),
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
          GoRoute(path: '/projects', builder: (_, __) => _comingSoon('Projects — Phase 2')),
          GoRoute(path: '/tasks', builder: (_, __) => _comingSoon('Tasks — Phase 2')),
          GoRoute(path: '/accounts', builder: (_, __) => _comingSoon('Accounts — Phase 2')),
          GoRoute(path: '/hr/employees', builder: (_, __) => _comingSoon('HR — Phase 2')),
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
