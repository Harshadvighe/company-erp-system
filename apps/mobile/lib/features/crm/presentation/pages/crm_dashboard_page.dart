import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';
import 'package:saark_erp_mobile/core/widgets/bulk_import_modal.dart';

class CrmDashboardPage extends ConsumerStatefulWidget {
  const CrmDashboardPage({super.key});

  @override
  ConsumerState<CrmDashboardPage> createState() => _CrmDashboardPageState();
}

class _CrmDashboardPageState extends ConsumerState<CrmDashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  Map<String, dynamic>? _searchResults;
  bool _searchOverlayVisible = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = null;
        _searchOverlayVisible = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchOverlayVisible = true;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final repo = ref.read(crmRepositoryProvider);
        final results = await repo.globalSearch(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _searchResults = {'error': e.toString()};
          });
        }
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = null;
      _searchOverlayVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(crmDashboardProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_rounded,
                  color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRM & Sales Workspace',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3),
                ),
                Text(
                  'Unified Pipeline, Company 360 & Activity Management',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.darkBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Import Excel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: () => BulkImportModal.show(
              context,
              target: 'CUSTOMER',
              onImportComplete: () => ref.invalidate(crmDashboardProvider),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Workspace',
            onPressed: () => ref.invalidate(crmDashboardProvider),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_business_rounded, size: 16),
            label: const Text('Register Company',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: () => context.go('/customers/new'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          dashAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppTheme.error),
                    const SizedBox(height: 12),
                    Text(err.toString(),
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(crmDashboardProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Connection'),
                    ),
                  ],
                ),
              ),
            ),
            data: (data) => _buildMainDashboard(context, data, user?.fullName),
          ),
          if (_searchOverlayVisible) _buildSearchOverlay(context),
        ],
      ),
    );
  }

  Widget _buildMainDashboard(
      BuildContext context, Map<String, dynamic> data, String? userName) {
    final totalCompanies =
        data['totalCompanies'] ?? data['totalCustomers'] ?? 0;
    final openOpportunities = data['openOpportunities'] ?? 0;
    final pipelineVal = (data['pipelineValue'] ?? 0) as num;
    final followUpsToday = data['followUpsToday'] ?? 0;
    final overdueFollowUps = data['overdueFollowUps'] ?? 0;
    final meetingsToday = data['meetingsToday'] ??
        ((data['recentMeetings'] as List?)?.length ?? 0);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(crmDashboardProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Global Search Header Bar ──────────────────────────────────────────
          _buildSearchBar(context),
          const SizedBox(height: 16),

          // ── Overdue Warning Banner ──────────────────────────────────────────────
          if (overdueFollowUps > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$overdueFollowUps Overdue Follow-ups require immediate action.',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                          fontSize: 12),
                    ),
                  ),
                  InkWell(
                    onTap: () => context.go('/crm/follow-ups'),
                    child: const Text('Resolve Now →',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 2. Compact 6-Metric KPI Row ─────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final isMedium =
                  constraints.maxWidth >= 600 && constraints.maxWidth < 900;
              final crossAxisCount = isWide ? 6 : (isMedium ? 3 : 2);
              final itemWidth =
                  (constraints.maxWidth - (crossAxisCount - 1) * 10) /
                      crossAxisCount;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _kpiCard(
                    title: 'Total Companies',
                    value: '$totalCompanies',
                    icon: Icons.business_rounded,
                    color: Colors.purpleAccent,
                    onTap: () => context.go('/customers'),
                    width: itemWidth,
                  ),
                  _kpiCard(
                    title: 'Open Opportunities',
                    value: '$openOpportunities',
                    icon: Icons.monetization_on_outlined,
                    color: Colors.amber,
                    onTap: () => context.go('/crm/pipeline'),
                    width: itemWidth,
                  ),
                  _kpiCard(
                    title: 'Pipeline Value',
                    value: _formatCurrency(pipelineVal),
                    icon: Icons.trending_up_rounded,
                    color: AppTheme.primary,
                    onTap: () => context.go('/crm/pipeline'),
                    width: itemWidth,
                  ),
                  _kpiCard(
                    title: "Today's Follow-ups",
                    value: '$followUpsToday',
                    icon: Icons.event_repeat_rounded,
                    color: Colors.blueAccent,
                    onTap: () => context.go('/crm/follow-ups'),
                    width: itemWidth,
                  ),
                  _kpiCard(
                    title: 'Overdue Activities',
                    value: '$overdueFollowUps',
                    icon: Icons.alarm_off_rounded,
                    color:
                        overdueFollowUps > 0 ? Colors.redAccent : Colors.grey,
                    onTap: () => context.go('/crm/follow-ups'),
                    width: itemWidth,
                  ),
                  _kpiCard(
                    title: "Today's Meetings",
                    value: '$meetingsToday',
                    icon: Icons.calendar_month_rounded,
                    color: Colors.tealAccent,
                    onTap: () => context.go('/crm/meetings'),
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── 3. Four Core Workspace Categories ───────────────────────────────────
          const Text(
            'CRM Workspace Categories',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              return GridView.count(
                crossAxisCount: isDesktop ? 2 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isDesktop ? 1.75 : 1.35,
                children: [
                  _buildCategoryCard(
                    categoryTitle: 'A. Companies & Contacts',
                    categoryDesc:
                        'Company Master, GST Verification, Contacts, Products & Company 360',
                    themeColor: const Color(0xFF8B5CF6), // Purple
                    icon: Icons.business_outlined,
                    primaryRoute: '/customers',
                    items: [
                      const _CategoryItem(
                        label: 'Company Master & 360',
                        desc: 'Search, ratings, valuations & profile',
                        icon: Icons.corporate_fare_rounded,
                        route: '/customers',
                      ),
                      const _CategoryItem(
                        label: 'Register Company',
                        desc: 'GST verification & auto-fill',
                        icon: Icons.domain_add_rounded,
                        route: '/customers/new',
                      ),
                      const _CategoryItem(
                        label: 'Sorting & Filters',
                        desc: 'Filter by Industry, State, Rating',
                        icon: Icons.filter_alt_outlined,
                        route: '/customers',
                      ),
                    ],
                  ),
                  _buildCategoryCard(
                    categoryTitle: 'B. Sales & Pipeline',
                    categoryDesc:
                        'Leads, RFQ Enquiries, Opportunity Kanban, Quotations & Sales Orders',
                    themeColor: const Color(0xFF10B981), // Emerald
                    icon: Icons.trending_up_rounded,
                    primaryRoute: '/crm/pipeline',
                    items: [
                      const _CategoryItem(
                        label: 'Leads & Prospects',
                        desc: 'Inbound, qualification & conversion',
                        icon: Icons.person_search_outlined,
                        route: '/crm/leads',
                      ),
                      const _CategoryItem(
                        label: 'Customer Enquiries',
                        desc: 'RFQs & commercial requirements',
                        icon: Icons.help_outline_rounded,
                        route: '/crm/enquiries',
                      ),
                      const _CategoryItem(
                        label: 'Visual Pipeline',
                        desc: 'Kanban board & deal stages',
                        icon: Icons.view_kanban_outlined,
                        route: '/crm/pipeline',
                      ),
                      const _CategoryItem(
                        label: 'Quotations',
                        desc: 'Costing, revisions & approvals',
                        icon: Icons.request_quote_outlined,
                        route: '/crm/quotations',
                      ),
                      const _CategoryItem(
                        label: 'Sales Orders',
                        desc: 'Order booking & dispatch tracking',
                        icon: Icons.assignment_turned_in_outlined,
                        route: '/crm/sales-orders',
                      ),
                    ],
                  ),
                  _buildCategoryCard(
                    categoryTitle: 'C. Activities & Communication',
                    categoryDesc:
                        'Calls, Meeting Approvals, Follow-ups, Reminders & Site Visits',
                    themeColor: const Color(0xFFF59E0B), // Amber
                    icon: Icons.schedule_rounded,
                    primaryRoute: '/crm/follow-ups',
                    items: [
                      const _CategoryItem(
                        label: 'Calls & Audio Logs',
                        desc: 'Call logs & voice recordings',
                        icon: Icons.phone_in_talk_outlined,
                        route: '/crm/calls',
                      ),
                      const _CategoryItem(
                        label: 'Meetings & Approvals',
                        desc: 'Schedules, invites & acceptance',
                        icon: Icons.calendar_month_outlined,
                        route: '/crm/meetings',
                      ),
                      const _CategoryItem(
                        label: 'Follow-ups & SLA',
                        desc: 'Due dates, assignments & tasks',
                        icon: Icons.event_repeat_outlined,
                        route: '/crm/follow-ups',
                      ),
                      const _CategoryItem(
                        label: 'Site Visits',
                        desc: 'Field inspections & plant visits',
                        icon: Icons.location_city_outlined,
                        route: '/crm/site-visits',
                      ),
                    ],
                  ),
                  _buildCategoryCard(
                    categoryTitle: 'D. Sales Performance & Intelligence',
                    categoryDesc:
                        'Sales analytics, Win-loss conversion, SLA response & Team metrics',
                    themeColor: const Color(0xFF06B6D4), // Cyan
                    icon: Icons.analytics_outlined,
                    primaryRoute: '/crm/analytics',
                    items: [
                      const _CategoryItem(
                        label: 'Sales Analytics',
                        desc: 'Revenue, pipeline value & run rate',
                        icon: Icons.insights_rounded,
                        route: '/crm/analytics',
                      ),
                      const _CategoryItem(
                        label: 'Win / Loss Metrics',
                        desc: 'Stage conversions & closure rates',
                        icon: Icons.pie_chart_outline_rounded,
                        route: '/crm/analytics',
                      ),
                      const _CategoryItem(
                        label: 'Follow-up SLA',
                        desc: 'Response turnaround times',
                        icon: Icons.timer_outlined,
                        route: '/crm/analytics',
                      ),
                      const _CategoryItem(
                        label: 'Team Performance',
                        desc: 'Rep rankings & activity score',
                        icon: Icons.group_outlined,
                        route: '/crm/analytics',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── 4. My Work Today & Live Activity Desk ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Work Today & Key Activities',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5),
              ),
              TextButton.icon(
                onPressed: () => context.go('/crm/follow-ups'),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('View All Activities',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMyWorkToday(context, data),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText:
              'Search Companies, GSTIN, Contacts, Deals, Enquiries, Quotations...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.primary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(BuildContext context) {
    return Positioned(
      top: 60,
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.darkSurface,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppTheme.darkBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_isSearching)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.search,
                              size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Search Results for "${_searchController.text}"',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _clearSearch,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _buildSearchResultsList(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsList(BuildContext context) {
    if (_searchResults == null) return const SizedBox.shrink();

    final companies = (_searchResults!['companies'] as List?) ?? [];
    final leads = (_searchResults!['leads'] as List?) ?? [];
    final enquiries = (_searchResults!['enquiries'] as List?) ?? [];
    final opportunities = (_searchResults!['opportunities'] as List?) ?? [];
    final quotations = (_searchResults!['quotations'] as List?) ?? [];

    final totalFound = companies.length +
        leads.length +
        enquiries.length +
        opportunities.length +
        quotations.length;

    if (totalFound == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No CRM records matching your query.',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (companies.isNotEmpty) ...[
          _searchSectionHeader('COMPANIES & CUSTOMERS (${companies.length})',
              Icons.business, Colors.purple),
          ...companies.map((c) => ListTile(
                dense: true,
                leading: const Icon(Icons.business_rounded,
                    color: Colors.purple, size: 18),
                title: Text(c['name']?.toString() ?? 'Unnamed Company',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                    'GSTIN: ${c['gstin'] ?? 'No GST'} | City: ${c['city'] ?? 'N/A'} | Phone: ${c['phone'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  _clearSearch();
                  context.go('/customers/${c['id']}');
                },
              )),
          const Divider(color: AppTheme.darkBorder),
        ],
        if (leads.isNotEmpty) ...[
          _searchSectionHeader(
              'LEADS (${leads.length})', Icons.person_search, Colors.blue),
          ...leads.map((l) => ListTile(
                dense: true,
                leading: const Icon(Icons.person_search_rounded,
                    color: Colors.blue, size: 18),
                title: Text(l['name']?.toString() ?? 'Lead',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                    'Company: ${l['company'] ?? 'N/A'} | Phone: ${l['phone'] ?? 'N/A'} | Status: ${l['status'] ?? 'NEW'}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  _clearSearch();
                  context.go('/crm/leads');
                },
              )),
          const Divider(color: AppTheme.darkBorder),
        ],
        if (opportunities.isNotEmpty) ...[
          _searchSectionHeader('OPPORTUNITIES (${opportunities.length})',
              Icons.monetization_on, Colors.amber),
          ...opportunities.map((o) => ListTile(
                dense: true,
                leading: const Icon(Icons.monetization_on_outlined,
                    color: Colors.amber, size: 18),
                title: Text(o['title']?.toString() ?? 'Deal',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                    'Company: ${o['customer']?['name'] ?? 'N/A'} | Stage: ${o['stage']} | Value: ₹${o['dealValue'] ?? 0}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  _clearSearch();
                  context.go('/crm/pipeline');
                },
              )),
          const Divider(color: AppTheme.darkBorder),
        ],
        if (enquiries.isNotEmpty) ...[
          _searchSectionHeader('ENQUIRIES (${enquiries.length})',
              Icons.help_outline, Colors.orange),
          ...enquiries.map((e) => ListTile(
                dense: true,
                leading: const Icon(Icons.help_outline_rounded,
                    color: Colors.orange, size: 18),
                title: Text(e['subject']?.toString() ?? 'Enquiry',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                    'Company: ${e['customer']?['name'] ?? 'N/A'} | Status: ${e['status']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  _clearSearch();
                  context.go('/crm/enquiries');
                },
              )),
          const Divider(color: AppTheme.darkBorder),
        ],
        if (quotations.isNotEmpty) ...[
          _searchSectionHeader('QUOTATIONS (${quotations.length})',
              Icons.request_quote, Colors.teal),
          ...quotations.map((q) => ListTile(
                dense: true,
                leading: const Icon(Icons.request_quote_rounded,
                    color: Colors.teal, size: 18),
                title: Text('Quote #${q['quoteNumber'] ?? q['id']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                    'Company: ${q['customer']?['name'] ?? 'N/A'} | Total: ₹${q['totalAmount'] ?? 0} | Status: ${q['status']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () {
                  _clearSearch();
                  context.go('/crm/quotations');
                },
              )),
        ],
      ],
    );
  }

  Widget _searchSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double width,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String categoryTitle,
    required String categoryDesc,
    required Color themeColor,
    required IconData icon,
    required String primaryRoute,
    required List<_CategoryItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border:
                  const Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: themeColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryTitle,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: themeColor),
                      ),
                      Text(
                        categoryDesc,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded,
                      size: 16, color: Colors.grey),
                  tooltip: 'Open Category',
                  onPressed: () => context.go(primaryRoute),
                ),
              ],
            ),
          ),
          // Visible Action Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              physics: const BouncingScrollPhysics(),
              children: items.map((item) {
                return InkWell(
                  onTap: () => context.go(item.route),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Icon(item.icon,
                            size: 16, color: themeColor.withValues(alpha: 0.8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              Text(
                                item.desc,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyWorkToday(BuildContext context, Map<String, dynamic> data) {
    final rawMeetings = (data['recentMeetings'] as List?) ?? [];
    final rawFollowUps = (data['recentFollowUps'] as List?) ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        final meetingsCard = _buildActivityBox(
          title: "Today's Client Meetings",
          icon: Icons.calendar_month_rounded,
          color: Colors.tealAccent,
          viewAllRoute: '/crm/meetings',
          items: rawMeetings.map((m) {
            final meet = m as Map<String, dynamic>;
            final customerName = meet['customer']?['name'] ??
                meet['companyName'] ??
                'Client Meeting';
            final subject = meet['subject'] ?? 'Discussion';
            final time = meet['startTime'] ?? meet['scheduledAt'] ?? 'Today';
            return _ActivityRow(
              title: '$subject ($customerName)',
              subtitle:
                  'Time: $time | Status: ${meet['status'] ?? 'SCHEDULED'}',
              icon: Icons.groups_rounded,
              color: Colors.tealAccent,
              onTap: () => context.go('/crm/meetings'),
            );
          }).toList(),
          emptyText: 'No client meetings scheduled for today.',
        );

        final followUpsCard = _buildActivityBox(
          title: "Pending & Today's Follow-ups",
          icon: Icons.event_repeat_rounded,
          color: Colors.blueAccent,
          viewAllRoute: '/crm/follow-ups',
          items: rawFollowUps.map((f) {
            final follow = f as Map<String, dynamic>;
            final customerName =
                follow['customer']?['name'] ?? 'Client Follow-up';
            final discussion = follow['discussion'] ??
                follow['actionNotes'] ??
                'Scheduled Contact';
            final due = follow['dueDate'] ?? follow['scheduledAt'] ?? 'Today';
            return _ActivityRow(
              title: customerName,
              subtitle: '$discussion | Due: $due',
              icon: Icons.phone_forwarded_rounded,
              color: Colors.blueAccent,
              onTap: () => context.go('/crm/follow-ups'),
            );
          }).toList(),
          emptyText: 'No pending follow-ups for today.',
        );

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: meetingsCard),
              const SizedBox(width: 14),
              Expanded(child: followUpsCard),
            ],
          );
        } else {
          return Column(
            children: [
              meetingsCard,
              const SizedBox(height: 14),
              followUpsCard,
            ],
          );
        }
      },
    );
  }

  Widget _buildActivityBox({
    required String title,
    required IconData icon,
    required Color color,
    required String viewAllRoute,
    required List<_ActivityRow> items,
    required String emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              InkWell(
                onTap: () => context.go(viewAllRoute),
                child: const Text('Open →',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(emptyText,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            ...items.take(4).map((row) => InkWell(
                  onTap: row.onTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(row.icon, size: 14, color: row.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(row.subtitle,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  String _formatCurrency(num value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)} K';
    }
    return '₹${value.toStringAsFixed(0)}';
  }
}

class _CategoryItem {
  final String label;
  final String desc;
  final IconData icon;
  final String route;

  const _CategoryItem({
    required this.label,
    required this.desc,
    required this.icon,
    required this.route,
  });
}

class _ActivityRow {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
