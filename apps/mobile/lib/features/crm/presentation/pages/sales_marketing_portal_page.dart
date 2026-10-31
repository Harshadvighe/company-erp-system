import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/customer_vendor_crm_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/sales_invoice_workspace_view.dart';
import 'package:saark_erp_mobile/features/products/presentation/widgets/products_services_workspace_view.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/purchase_procurement_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/bank_cash_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/expense_income_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/other_documents_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/financial_reports_workspace_view.dart';
import 'package:saark_erp_mobile/features/production/presentation/widgets/booster_pump_calculator_workspace_view.dart';
import 'package:saark_erp_mobile/features/b2b_trading/presentation/widgets/b2b_trading_platform_workspace_view.dart';

/// Sales and Marketing Product Category & Customer / Vendor Portal Page
/// Recreates the exact Company Management Software UI requested by the user
class SalesMarketingPortalPage extends ConsumerStatefulWidget {
  final int initialTab;
  final int initialSubModule;
  const SalesMarketingPortalPage({super.key, this.initialTab = 1, this.initialSubModule = 0});

  @override
  ConsumerState<SalesMarketingPortalPage> createState() => _SalesMarketingPortalPageState();
}

class _SalesMarketingPortalPageState extends ConsumerState<SalesMarketingPortalPage> {
  String _selectedFiscalYear = 'F.Y. 2026-2027';
  late int _activeNavTab;

  @override
  void initState() {
    super.initState();
    _activeNavTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant SalesMarketingPortalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _activeNavTab = widget.initialTab);
    }
  }

  final List<_CategoryButtonData> _categories = [
    _CategoryButtonData(
      title: 'Customer CRM & Leads',
      route: '/crm/dashboard',
      description: 'Manage Leads, Enquiries, Sales Pipelines & Customer 360',
    ),
    _CategoryButtonData(
      title: 'Saark Product Sector',
      route: '/products',
      description: 'View full industrial catalog of Saark automation products',
    ),
    _CategoryButtonData(
      title: 'Booster Pump Control Panel Desing,Materil & Price Calculator',
      route: '/production/booster-pump-calculator',
      description: 'Design booster pump specs, calculate BOM material cost & final price',
    ),
    _CategoryButtonData(
      title: 'B2B Marketplace',
      route: '/crm/b2b-marketplace',
      description: 'B2B Trading Platform & White-Labeling Workflow',
    ),
    _CategoryButtonData(
      title: 'STP Panel',
      route: '/production/specs',
      description: 'Sewage Treatment Plant automation panel specifications & BOMs',
    ),
    _CategoryButtonData(
      title: 'Water Meter',
      route: '/products',
      description: 'Digital, ultrasonic & electromagnetic flow meters',
    ),
    _CategoryButtonData(
      title: 'BMS',
      route: '/products',
      description: 'Building Management Systems, HVAC & sensor automation panels',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF191A1E),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ─── 1. Desktop Window Strip ─────────────────────────────
            _buildWindowBar(user),

            // ─── 2. Top Orange Header Banner ────────────────────────
            _buildOrangeHeader(context, isCompact),

            // ─── 3. Navigation Tabs Bar ──────────────────────────────
            _buildNavigationTabs(context, isCompact),

            // ─── 4. Main Canvas ─────────────────────────────────────
            Expanded(
              child: _activeNavTab == 1
                  ? CustomerVendorCrmView(
                      initialSubModule: widget.initialSubModule,
                      onBackToDashboard: () => setState(() => _activeNavTab = 0),
                    )
                  : _activeNavTab == 2
                      ? ProductsServicesWorkspaceView(
                          onBackToDashboard: () => setState(() => _activeNavTab = 0),
                        )
                      : _activeNavTab == 3
                          ? SaleInvoiceWorkspaceView(
                              onBackToDashboard: () => setState(() => _activeNavTab = 0),
                            )
                          : _activeNavTab == 4
                              ? PurchaseProcurementWorkspaceView(
                                  onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                )
                              : _activeNavTab == 5
                                  ? BankCashWorkspaceView(
                                      onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                    )
                                  : _activeNavTab == 6
                                      ? ExpenseIncomeWorkspaceView(
                                          onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                        )
                                      : _activeNavTab == 7
                                          ? OtherDocumentsWorkspaceView(
                                              onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                            )
                                          : _activeNavTab == 8
                                              ? FinancialReportsWorkspaceView(
                                                  onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                )
                                              : _activeNavTab == 9
                                                  ? BoosterPumpCalculatorWorkspaceView(
                                                      onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                    )
                                                  : _activeNavTab == 10
                                                      ? B2bTradingPlatformWorkspaceView(
                                                          onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                        )
                                                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 600),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Select Product Category',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 28),
                              ...List.generate(_categories.length, (index) {
                                final item = _categories[index];
                                return _buildCategoryPillButton(context, item);
                              }),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 1. Window Top Title Bar ────────────────────────────────────────────────
  Widget _buildWindowBar(AuthUser? user) {
    final userName = user?.username ?? 'a';
    final userRole = user?.isAdmin == true ? 'Admin' : (user?.fullName ?? 'User');

    return Container(
      height: 28,
      color: const Color(0xFF131417),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.business_center_rounded, color: Color(0xFF00B4D8), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Company Management Software — Logged in: $userName ($userRole)',
              style: const TextStyle(
                color: Color(0xFFB0B3B8),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                icon: const Icon(Icons.remove, size: 13, color: Color(0xFF8E9297)),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                icon: const Icon(Icons.crop_square, size: 12, color: Color(0xFF8E9297)),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                icon: const Icon(Icons.close, size: 13, color: Color(0xFF8E9297)),
                onPressed: () => context.go('/dashboard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Top Brand Header Bar ────────────────────────────────────────────────
  Widget _buildOrangeHeader(BuildContext context, bool isCompact) {
    return Container(
      height: 52,
      color: const Color(0xFFF15A24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'SAARK EXPLORATION PRIVATE LIMITED',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 13 : 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // + Create Dropdown Button
              PopupMenuButton<String>(
                tooltip: 'Quick Actions',
                offset: const Offset(0, 36),
                color: const Color(0xFF222428),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                onSelected: (route) => context.go(route),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: '/crm/leads',
                    child: Row(
                      children: [
                        Icon(Icons.add_chart_rounded, color: Color(0xFFF15A24), size: 16),
                        SizedBox(width: 10),
                        Text('New CRM Lead', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: '/customers/new',
                    child: Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: Color(0xFFF15A24), size: 16),
                        SizedBox(width: 10),
                        Text('New Customer / Company', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: '/crm/enquiries',
                    child: Row(
                      children: [
                        Icon(Icons.inbox_outlined, color: Color(0xFFF15A24), size: 16),
                        SizedBox(width: 10),
                        Text('New Enquiry', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: '/production/new',
                    child: Row(
                      children: [
                        Icon(Icons.calculate_outlined, color: Color(0xFFF15A24), size: 16),
                        SizedBox(width: 10),
                        Text('New Panel BOM & Price Spec', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: '/crm/quotations/new',
                    child: Row(
                      children: [
                        Icon(Icons.request_quote_outlined, color: Color(0xFFF15A24), size: 16),
                        SizedBox(width: 10),
                        Text('New Sales Quotation', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Create', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Fiscal Year Selector
              PopupMenuButton<String>(
                tooltip: 'Select Financial Year',
                offset: const Offset(0, 36),
                color: const Color(0xFF222428),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                onSelected: (val) => setState(() => _selectedFiscalYear = val),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'F.Y. 2026-2027',
                    child: Text('F.Y. 2026-2027 (Active)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'F.Y. 2025-2026',
                    child: Text('F.Y. 2025-2026', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'F.Y. 2024-2025',
                    child: Text('F.Y. 2024-2025', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedFiscalYear,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),

              if (!isCompact) ...[
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Messages & Enquiries',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                  onPressed: () => context.go('/crm/enquiries'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'System Notifications',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28),
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 19),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.go('/dashboard'),
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFFF15A24), size: 16),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. Horizontal Module Navigation Tabs ──────────────────────────────────
  Widget _buildNavigationTabs(BuildContext context, bool isCompact) {
    final tabs = [
      _NavTabItem(title: 'Dashboard', icon: Icons.speed_rounded, route: '', isActive: _activeNavTab == 0 || _activeNavTab == 10),
      _NavTabItem(title: 'Customer / Vendor', icon: Icons.people_alt_outlined, route: '', isActive: _activeNavTab == 1),
      _NavTabItem(title: 'Products / Services', icon: Icons.inventory_2_outlined, route: '', isActive: _activeNavTab == 2),
      _NavTabItem(title: 'Sale Invoice', icon: Icons.receipt_long_outlined, route: '/crm/invoices', isActive: _activeNavTab == 3),
      _NavTabItem(title: 'Purchase Invoice', icon: Icons.shopping_cart_outlined, route: '/purchase/orders', isActive: _activeNavTab == 4),
      _NavTabItem(title: 'Payment', icon: Icons.currency_rupee_rounded, route: '', isActive: _activeNavTab == 5),
      _NavTabItem(title: 'Expense Income', icon: Icons.trending_up_rounded, route: '', isActive: _activeNavTab == 6),
      _NavTabItem(title: 'Other Documents', icon: Icons.description_outlined, route: '', isActive: _activeNavTab == 7),
      _NavTabItem(title: 'Report', icon: Icons.bar_chart_rounded, route: '', isActive: _activeNavTab == 8),
    ];

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1F23),
        border: Border(bottom: BorderSide(color: Color(0xFF2B2D31), width: 1)),
      ),
      child: isCompact
          ? ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (ctx, i) => _buildSingleTab(context, tabs[i], i),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(tabs.length, (i) => Expanded(child: _buildSingleTab(context, tabs[i], i))),
            ),
    );
  }

  Widget _buildSingleTab(BuildContext context, _NavTabItem item, int index) {
    return InkWell(
      onTap: () {
        if (index == 0) {
          context.go('/dashboard');
        } else if (index == 1) {
          setState(() => _activeNavTab = 1);
        } else if (index == 2) {
          setState(() => _activeNavTab = 2);
        } else if (index == 3) {
          setState(() => _activeNavTab = 3);
        } else if (index == 4) {
          setState(() => _activeNavTab = 4);
        } else if (index == 5) {
          setState(() => _activeNavTab = 5);
        } else if (index == 6) {
          setState(() => _activeNavTab = 6);
        } else if (index == 7) {
          setState(() => _activeNavTab = 7);
        } else if (index == 8) {
          setState(() => _activeNavTab = 8);
        } else if (item.route.isNotEmpty) {
          context.go(item.route);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: item.isActive ? const Color(0xFF131417) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: item.isActive ? const Color(0xFFF15A24) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 18,
              color: item.isActive ? Colors.white : const Color(0xFF9AA0A6),
            ),
            const SizedBox(height: 3),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: item.isActive ? Colors.white : const Color(0xFF9AA0A6),
                fontSize: 10.5,
                fontWeight: item.isActive ? FontWeight.bold : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. Category Pill Button ───────────────────────────────────────────────
  Widget _buildCategoryPillButton(BuildContext context, _CategoryButtonData item) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 430),
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFFF15A24),
        borderRadius: BorderRadius.circular(22),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (item.title == 'Customer CRM & Leads') {
              setState(() => _activeNavTab = 1);
            } else if (item.title == 'Saark Product Sector' || item.title == 'Water Meter' || item.title == 'BMS') {
              setState(() => _activeNavTab = 2);
            } else if (item.title.contains('Booster Pump')) {
              setState(() => _activeNavTab = 9);
            } else if (item.title == 'B2B Marketplace' || item.title.contains('B2B')) {
              setState(() => _activeNavTab = 10);
            } else {
              context.go(item.route);
            }
          },
          hoverColor: const Color(0xFFFF6D33),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryButtonData {
  final String title;
  final String route;
  final String description;

  _CategoryButtonData({
    required this.title,
    required this.route,
    required this.description,
  });
}

class _NavTabItem {
  final String title;
  final IconData icon;
  final String route;
  final bool isActive;

  _NavTabItem({
    required this.title,
    required this.icon,
    required this.route,
    this.isActive = false,
  });
}
