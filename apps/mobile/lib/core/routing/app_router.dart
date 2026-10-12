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
import 'package:saark_erp_mobile/features/crm/presentation/pages/quotations_list_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/quotation_form_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/quotation_detail_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/sales_orders_list_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/meetings_list_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/calls_list_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/site_visits_list_page.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_specs_list_page.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_spec_detail_page.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/panel_spec_form_page.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/pages/purchase_dashboard_page.dart';
import 'package:saark_erp_mobile/features/my_work/presentation/pages/my_work_page.dart';
import 'package:saark_erp_mobile/features/tasks/presentation/pages/tasks_list_page.dart';
import 'package:saark_erp_mobile/features/tasks/presentation/pages/task_detail_page.dart';
import 'package:saark_erp_mobile/features/projects/presentation/pages/projects_list_page.dart';
import 'package:saark_erp_mobile/features/projects/presentation/pages/project_detail_page.dart';
import 'package:saark_erp_mobile/features/staff/presentation/pages/staff_directory_page.dart';
import 'package:saark_erp_mobile/features/hr/presentation/pages/hr_dashboard_page.dart';
import 'package:saark_erp_mobile/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/invoices_list_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/accounts_dashboard_page.dart';
import 'package:saark_erp_mobile/features/inventory/presentation/pages/inventory_dashboard_page.dart';
import 'package:saark_erp_mobile/features/reports/presentation/pages/reports_dashboard_page.dart';

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
          currentRoute: state.matchedLocation,
          child: child,
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
          GoRoute(
            path: '/tasks/:id',
            name: 'task-detail',
            builder: (context, state) =>
                TaskDetailPage(taskId: state.pathParameters['id']!),
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
            path: '/crm/companies',
            name: 'crm-companies',
            builder: (context, state) => const CustomersListPage(),
          ),
          GoRoute(
            path: '/crm/companies/new',
            name: 'crm-company-new',
            builder: (context, state) => const CustomerFormPage(),
          ),
          GoRoute(
            path: '/crm/companies/:id',
            name: 'crm-company-detail',
            builder: (context, state) =>
                CustomerDetailPage(customerId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/crm/companies/:id/edit',
            name: 'crm-company-edit',
            builder: (context, state) =>
                CustomerFormPage(customerId: state.pathParameters['id']),
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
            builder: (context, state) => CrmFollowUpsPage(
              initialCustomerId: state.uri.queryParameters['customerId'],
            ),
          ),
          GoRoute(
            path: '/crm/analytics',
            name: 'crm-analytics',
            builder: (context, state) => const CrmAnalyticsPage(),
          ),
          GoRoute(
            path: '/crm/meetings',
            name: 'crm-meetings',
            builder: (context, state) => const MeetingsListPage(),
          ),
          GoRoute(
            path: '/crm/calls',
            name: 'crm-calls',
            builder: (context, state) => const CallsListPage(),
          ),
          GoRoute(
            path: '/crm/site-visits',
            name: 'crm-site-visits',
            builder: (context, state) => const SiteVisitsListPage(),
          ),

          // ─── Commercial Quotations & Sales Orders ────────────────
          GoRoute(
            path: '/crm/quotations',
            name: 'crm-quotations',
            builder: (context, state) => const QuotationsListPage(),
          ),
          GoRoute(
            path: '/crm/quotations/new',
            name: 'crm-quotation-new',
            builder: (context, state) => QuotationFormPage(
              prefillCustomerId: state.uri.queryParameters['customerId'],
              prefillOpportunityId: state.uri.queryParameters['opportunityId'],
              prefillPanelSpecId: state.uri.queryParameters['panelSpecId'],
            ),
          ),
          GoRoute(
            path: '/crm/quotations/:id',
            name: 'crm-quotation-detail',
            builder: (context, state) =>
                QuotationDetailPage(quotationId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/sales/quotations',
            name: 'sales-quotations',
            builder: (context, state) => const QuotationsListPage(),
          ),
          GoRoute(
            path: '/crm/sales-orders',
            name: 'crm-sales-orders',
            builder: (context, state) => const SalesOrdersListPage(),
          ),
          GoRoute(
            path: '/sales/orders',
            name: 'sales-orders',
            builder: (context, state) => const SalesOrdersListPage(),
          ),
          GoRoute(
            path: '/crm/invoices',
            name: 'crm-invoices',
            builder: (context, state) => const InvoicesListPage(),
          ),
          GoRoute(
            path: '/sales/invoices',
            name: 'sales-invoices',
            builder: (context, state) => const InvoicesListPage(),
          ),
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
          GoRoute(
            path: '/inventory',
            name: 'inventory',
            builder: (context, state) => const InventoryDashboardPage(),
          ),
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
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            builder: (context, state) => const AccountsDashboardPage(),
          ),
          GoRoute(
            path: '/hr',
            name: 'hr-dashboard',
            builder: (context, state) => const HrDashboardPage(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsDashboardPage(),
          ),
          GoRoute(
              path: '/admin', builder: (_, __) => const AdminDashboardPage()),
        ],
      ),
    ],
  );
});
