import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/production/data/panel_manufacturing_repository.dart';

class PanelSpecsListPage extends ConsumerStatefulWidget {
  const PanelSpecsListPage({super.key});

  @override
  ConsumerState<PanelSpecsListPage> createState() => _PanelSpecsListPageState();
}

class _PanelSpecsListPageState extends ConsumerState<PanelSpecsListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  final _typeFilters = [
    'ALL',
    'VFD_PANEL',
    'BOOSTER_PUMP',
    'STP_PANEL',
    'HVAC_PANEL',
    'DEWATERING_PANEL',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _typeFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(panelListProvider.notifier).loadSpecs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panelListProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Filter specs
    final selectedFilter = _typeFilters[_tabController.index];
    final searchQuery = _searchController.text.toLowerCase().trim();

    final filteredSpecs = state.specs.where((spec) {
      final panelType = (spec['panelType'] ?? '').toString();
      final panelCode = (spec['panelCode'] ?? '').toString().toLowerCase();
      final customerName = (spec['customer']?['companyName'] ?? '').toString().toLowerCase();

      final matchesType = selectedFilter == 'ALL' || panelType == selectedFilter;
      final matchesSearch = searchQuery.isEmpty ||
          panelCode.contains(searchQuery) ||
          customerName.contains(searchQuery);

      return matchesType && matchesSearch;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context, state.specs, currencyFormat),
          _buildTypeTabs(),
          _buildSearchBar(),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _buildError(state.error!)
                    : filteredSpecs.isEmpty
                        ? _buildEmpty()
                        : isWide
                            ? _buildTable(filteredSpecs, currencyFormat)
                            : _buildCards(filteredSpecs, currencyFormat),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/production/new'),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('New Panel BOM'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Map<String, dynamic>> specs, NumberFormat currency) {
    final totalPanels = specs.length;
    final totalValue = specs.fold<double>(0, (sum, item) => sum + (NumberFormat().tryParse('${item['finalPrice']}')?.toDouble() ?? (item['finalPrice'] as num?)?.toDouble() ?? 0));
    final vfdPanels = specs.where((s) => s['panelType'] == 'VFD_PANEL').length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.precision_manufacturing, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panel Manufacturing & BOM',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      Text(
                        'Industrial Control Panels, Specification Design & Live Cost Estimation',
                        style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => context.push('/production/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Specification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _buildStatChip('Total Specifications', '$totalPanels', Icons.assignment_outlined, AppTheme.info),
              const SizedBox(width: 12),
              _buildStatChip('VFD Panels', '$vfdPanels', Icons.speed, AppTheme.warning),
              const SizedBox(width: 12),
              _buildStatChip('Total Est. Value', currency.format(totalValue), Icons.currency_rupee, AppTheme.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary)),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTabs() {
    return Container(
      color: AppTheme.darkSurface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppTheme.primary,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.darkTextSecondary,
        tabs: _typeFilters.map((t) => Tab(text: t.replaceAll('_', ' '))).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.darkBackground,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: AppTheme.darkText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by Panel Code, Customer Name, or Spec...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.darkTextSecondary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> specs, NumberFormat currency) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
          columns: const [
            DataColumn(label: Text('PANEL CODE', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('RATING / PUMP', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('CONTROL / STARTER', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('BOM COST', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('FINAL PRICE', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: specs.map((spec) {
            final id = spec['id'] ?? '';
            final code = spec['panelCode'] ?? '';
            final customer = spec['customer']?['companyName'] ?? '—';
            final rating = '${spec['currentRating'] ?? ''} • ${spec['pumpQty'] ?? 0}x ${spec['pumpHp'] ?? 0}HP';
            final control = '${spec['controlType'] ?? ''} (${spec['starterType'] ?? ''})';
            final materialCost = (spec['materialCost'] as num?)?.toDouble() ?? 0;
            final finalPrice = (spec['finalPrice'] as num?)?.toDouble() ?? 0;
            final status = spec['status'] ?? 'DRAFT';

            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () => context.push('/production/$id'),
                    child: Text(code, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
                DataCell(Text(customer)),
                DataCell(_buildTypeBadge(spec['panelType'] ?? '')),
                DataCell(Text(rating, style: const TextStyle(fontSize: 12))),
                DataCell(Text(control, style: const TextStyle(fontSize: 12))),
                DataCell(Text(currency.format(materialCost))),
                DataCell(Text(currency.format(finalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success))),
                DataCell(_buildStatusBadge(status)),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                    onPressed: () => context.push('/production/$id'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCards(List<Map<String, dynamic>> specs, NumberFormat currency) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: specs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final spec = specs[index];
        final id = spec['id'] ?? '';
        final code = spec['panelCode'] ?? '';
        final customer = spec['customer']?['companyName'] ?? '—';
        final finalPrice = (spec['finalPrice'] as num?)?.toDouble() ?? 0;
        final status = spec['status'] ?? 'DRAFT';

        return Card(
          child: InkWell(
            onTap: () => context.push('/production/$id'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(code, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16)),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(customer, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTypeBadge(spec['panelType'] ?? ''),
                      const SizedBox(width: 8),
                      Text('${spec['currentRating'] ?? ''} • ${spec['pumpQty'] ?? 0}x ${spec['pumpHp'] ?? 0} HP',
                          style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated Price', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                          Text(currency.format(finalPrice),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/production/$id'),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View BOM'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                          foregroundColor: AppTheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color = AppTheme.info;
    if (type == 'VFD_PANEL') color = AppTheme.primary;
    if (type == 'BOOSTER_PUMP') color = AppTheme.warning;
    if (type == 'STP_PANEL') color = AppTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppTheme.warning;
    if (status == 'APPROVED') color = AppTheme.info;
    if (status == 'IN_PRODUCTION') color = AppTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.precision_manufacturing_outlined, size: 64, color: AppTheme.darkTextSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('No Panel Specifications found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create your first panel design and Bill of Materials to calculate costs',
              style: TextStyle(color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push('/production/new'),
            icon: const Icon(Icons.add),
            label: const Text('Create New Panel Spec'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(panelListProvider.notifier).loadSpecs(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
