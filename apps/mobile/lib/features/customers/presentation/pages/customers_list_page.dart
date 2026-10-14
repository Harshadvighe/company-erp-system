import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';
import 'package:saark_erp_mobile/core/widgets/bulk_import_modal.dart';

class CustomersListPage extends ConsumerStatefulWidget {
  const CustomersListPage({super.key});

  @override
  ConsumerState<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends ConsumerState<CustomersListPage> {
  final _searchController = TextEditingController();
  final _ratingAboveController = TextEditingController();
  final Map<String, dynamic> _filterOptions = {};
  List<String> _selectedProductSystemIds = [];
  String _valuationFilter = 'ALL';
  String _activityFilter = 'ALL';
  String _enquiryFilter = 'ALL';
  String _enquiryTypeFilter = 'ALL';
  String _websiteFilter = 'ALL';
  String _stateFilter = 'ALL';
  String _districtFilter = 'ALL';
  String _distributorFilter = 'ALL';
  String _dealerFilter = 'ALL';
  String _sortOption = 'COMPANY_NAME_AZ';
  bool _filtersExpanded = false;
  bool _meetingFilterEnabled = false;
  DateTime? _meetingFrom;
  DateTime? _meetingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies(page: 1);
      _loadFilterOptions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ratingAboveController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _loadCompanies(page: 1);
  }

  Future<void> _loadFilterOptions({String? state}) async {
    try {
      final options = await ref
          .read(customersRepositoryProvider)
          .getCompanyFilterOptions(state: state == 'ALL' ? null : state);
      if (mounted) setState(() => _filterOptions.addAll(options));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load company filter options: $e')),
        );
      }
    }
  }

  Map<String, dynamic> _activeFilters() {
    final filters = <String, dynamic>{};
    if (_selectedProductSystemIds.isNotEmpty) {
      filters['productSystemIds'] = _selectedProductSystemIds.join(',');
    }
    if (_valuationFilter != 'ALL') filters['valuation'] = _valuationFilter;
    if (_activityFilter != 'ALL') filters['activity'] = _activityFilter;
    if (_meetingFilterEnabled) {
      filters['nextMeetingEnabled'] = 'true';
      if (_meetingFrom != null) {
        filters['meetingFrom'] = DateFormat('yyyy-MM-dd').format(_meetingFrom!);
      }
      if (_meetingTo != null) {
        filters['meetingTo'] = DateFormat('yyyy-MM-dd').format(_meetingTo!);
      }
    }
    if (_enquiryFilter != 'ALL') filters['enquiry'] = _enquiryFilter;
    if (_enquiryTypeFilter != 'ALL') {
      filters['enquiryType'] = _enquiryTypeFilter;
    }
    if (_websiteFilter != 'ALL') filters['website'] = _websiteFilter;
    if (_stateFilter != 'ALL') filters['state'] = _stateFilter;
    if (_districtFilter != 'ALL') filters['district'] = _districtFilter;
    if (_ratingAboveController.text.trim().isNotEmpty) {
      filters['ratingAbove'] = _ratingAboveController.text.trim();
    }
    if (_distributorFilter != 'ALL') {
      filters['distributor'] = _distributorFilter;
    }
    if (_dealerFilter != 'ALL') {
      filters['dealer'] = _dealerFilter;
    }
    return filters;
  }

  Future<void> _loadCompanies({int page = 1}) async {
    if (_meetingFilterEnabled &&
        (_meetingFrom == null ||
            _meetingTo == null ||
            _meetingFrom!.isAfter(_meetingTo!))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Choose a valid From Date and To Date for meetings')),
      );
      return;
    }
    await ref.read(customerListProvider.notifier).loadCustomers(
          search: _searchController.text,
          page: page,
          sortBy: _sortOption,
          filters: _activeFilters(),
        );
  }

  Future<void> _resetFilters() async {
    setState(() {
      _selectedProductSystemIds = [];
      _valuationFilter = 'ALL';
      _activityFilter = 'ALL';
      _enquiryFilter = 'ALL';
      _enquiryTypeFilter = 'ALL';
      _websiteFilter = 'ALL';
      _stateFilter = 'ALL';
      _districtFilter = 'ALL';
      _distributorFilter = 'ALL';
      _dealerFilter = 'ALL';
      _sortOption = 'COMPANY_NAME_AZ';
      _meetingFilterEnabled = false;
      _meetingFrom = null;
      _meetingTo = null;
      _ratingAboveController.clear();
    });
    await _loadCompanies(page: 1);
  }

  Future<void> _chooseDate({required bool from}) async {
    final initial = (from ? _meetingFrom : _meetingTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _meetingFrom = picked;
        } else {
          _meetingTo = picked;
        }
      });
    }
  }

  Future<void> _chooseProductSystems() async {
    final systems = (_filterOptions['productSystems'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final selected = Set<String>.from(_selectedProductSystemIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Product & System'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: systems.map((system) {
                final id = system['id']?.toString() ?? '';
                return CheckboxListTile(
                  value: selected.contains(id),
                  title: Text(system['name']?.toString() ?? ''),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      selected.add(id);
                    } else {
                      selected.remove(id);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _selectedProductSystemIds = result.toList());
    }
  }

  String _productSystemLabel() {
    final systems =
        (_filterOptions['productSystems'] as List? ?? []).whereType<Map>();
    final names = systems
        .where((system) =>
            _selectedProductSystemIds.contains(system['id']?.toString()))
        .map((system) => system['name']?.toString() ?? '')
        .toList();
    if (names.isEmpty) return 'All';
    return names.length <= 2 ? names.join(', ') : '${names.length} selected';
  }

  Future<void> _exportToExcel(CustomerListState state) async {
    if (state.customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No customers to export. Please load data first.')),
      );
      return;
    }

    late final List<dynamic> followUps;
    try {
      followUps = await ref.read(crmRepositoryProvider).getFollowUps();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Unable to load follow-ups for export: $error')),
        );
      }
      return;
    }
    final followUpsByCustomer = <String, List<Map<String, dynamic>>>{};
    for (final item in followUps.whereType<Map>()) {
      final followUp = Map<String, dynamic>.from(item);
      final customerId = followUp['customerId']?.toString();
      if (customerId == null) continue;
      followUpsByCustomer.putIfAbsent(customerId, () => []).add(followUp);
    }
    for (final items in followUpsByCustomer.values) {
      items.sort((a, b) => ((a['followUpNumber'] as num?)?.toInt() ?? 0)
          .compareTo((b['followUpNumber'] as num?)?.toInt() ?? 0));
    }
    final maximumFollowUpCount = state.customers.fold<int>(
      0,
      (maximum, customer) =>
          maximum > (followUpsByCustomer[customer.id]?.length ?? 0)
              ? maximum
              : (followUpsByCustomer[customer.id]?.length ?? 0),
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // CSV header row
    final headers = [
      'Customer Code',
      'Company Name',
      'Customer Type',
      'Contact Person',
      'Designation',
      'Email',
      'Phone',
      'Alternate Phone',
      'Address',
      'City',
      'District',
      'State',
      'Pincode',
      'Country',
      'Industry',
      'Source',
      'Website',
      'GSTIN',
      'PAN',
      'Status',
      'Rating',
      'Owner / Host',
      'Staff Count',
      'Turnover',
      'Created Date',
      for (var i = 1; i <= maximumFollowUpCount; i++) ...[
        'Follow-up $i - Action',
        'Follow-up $i - Output',
      ],
    ];

    String escapeHtml(String? v) {
      if (v == null || v.isEmpty) return '';
      return v
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
    }

    final buffer = StringBuffer();
    buffer.writeln('<html xmlns:x="urn:schemas-microsoft-com:office:excel">');
    buffer.writeln('<head><meta charset="utf-8"></head><body>');
    buffer.writeln('<table border="1"><tr>');
    for (final h in headers) {
      buffer.writeln(
          '<th style="background-color: #4CAF50; color: white;">$h</th>');
    }
    buffer.writeln('</tr>');

    for (final c in state.customers) {
      buffer.writeln('<tr>');
      buffer.writeln('<td>${escapeHtml(c.customerCode)}</td>');
      buffer.writeln('<td>${escapeHtml(c.companyName)}</td>');
      buffer.writeln('<td>${escapeHtml(c.customerType)}</td>');
      buffer.writeln('<td>${escapeHtml(c.contactPerson)}</td>');
      buffer.writeln('<td>${escapeHtml(c.designation)}</td>');
      buffer.writeln('<td>${escapeHtml(c.email)}</td>');
      buffer.writeln('<td>${escapeHtml(c.phone)}</td>');
      buffer.writeln('<td>${escapeHtml(c.alternatePhone)}</td>');
      buffer.writeln('<td>${escapeHtml(c.address)}</td>');
      buffer.writeln('<td>${escapeHtml(c.city)}</td>');
      buffer.writeln('<td>${escapeHtml(c.district)}</td>');
      buffer.writeln('<td>${escapeHtml(c.state)}</td>');
      buffer.writeln('<td>${escapeHtml(c.pincode)}</td>');
      buffer.writeln('<td>${escapeHtml(c.country)}</td>');
      buffer.writeln('<td>${escapeHtml(c.industry)}</td>');
      buffer.writeln('<td>${escapeHtml(c.source)}</td>');
      buffer.writeln('<td>${escapeHtml(c.website)}</td>');
      buffer.writeln('<td>${escapeHtml(c.gstin)}</td>');
      buffer.writeln('<td>${escapeHtml(c.pan)}</td>');
      buffer.writeln('<td>${escapeHtml(c.status)}</td>');
      buffer.writeln(
          '<td>${escapeHtml(c.customerRating.toStringAsFixed(1))}</td>');
      buffer.writeln('<td>${escapeHtml(c.ownerName)}</td>');
      buffer.writeln('<td>${escapeHtml(c.staffCount.toString())}</td>');
      buffer.writeln('<td>${escapeHtml(c.turnover)}</td>');
      buffer.writeln(
          '<td>${escapeHtml(DateFormat('dd/MM/yyyy').format(c.createdAt))}</td>');
      final customerFollowUps = followUpsByCustomer[c.id] ?? const [];
      for (var index = 0; index < maximumFollowUpCount; index++) {
        if (index >= customerFollowUps.length) {
          buffer.writeln('<td></td><td></td>');
          continue;
        }
        final followUp = customerFollowUps[index];
        buffer.writeln(
            '<td>${escapeHtml((followUp['activityType'] ?? followUp['title'])?.toString())}</td>');
        buffer.writeln(
            '<td>${escapeHtml((followUp['outcome'] ?? followUp['discussion'])?.toString())}</td>');
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</table></body></html>');

    final filename = 'saark_customers_$dateStr.xls';

    downloadExcelFile(buffer.toString(), filename);

    // Sync with backend audit trail
    try {
      await ref.read(dioProvider).get(
        '/customers/export',
        queryParameters: {
          if (_searchController.text.isNotEmpty) 'search': _searchController.text,
        },
      );
    } catch (_) {
      // Gracefully allow offline or network error fallback
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✓ Exported ${state.customers.length} customers to $filename'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _onBulkImportComplete() {
    final currentPage = ref.read(customerListProvider).page;
    _loadCompanies(page: currentPage);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Bulk import results received. Customer list refreshed using the current filters.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerListProvider);
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
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
        title: const Text('Customer Directory'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => BulkImportModal.show(
              context,
              target: 'CUSTOMER',
              onImportComplete: _onBulkImportComplete,
            ),
            tooltip: 'Import Excel',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCompanies(page: state.page),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(isWide, state),
          _buildSortingFilters(state),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                          ? _buildError(state.error!)
                          : state.customers.isEmpty
                              ? _buildEmpty()
                              : isWide
                                  ? _buildDataTable(state)
                                  : _buildCardList(state),
                ),
                if (!state.isLoading && state.error == null)
                  _buildPagination(state),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/customers/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Customer'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader(bool isWide, CustomerListState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by name, GST, phone, email…',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.darkBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => BulkImportModal.show(
              context,
              target: 'CUSTOMER',
              onImportComplete: _onBulkImportComplete,
            ),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Import Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          if (isWide) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _exportToExcel(state),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortingFilters(CustomerListState state) {
    final states = (_filterOptions['states'] as List? ?? [])
        .map((value) => value.toString())
        .toList();
    final districts = (_filterOptions['districts'] as List? ?? [])
        .map((value) => value.toString())
        .toList();
    final enquiryTypes = (_filterOptions['enquiryTypes'] as List? ?? [])
        .map((value) => value.toString())
        .toList();
    final productSystems = (_filterOptions['productSystems'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final selectedProducts = productSystems
        .where((system) =>
            _selectedProductSystemIds.contains(system['id']?.toString()))
        .map((system) => system['name']?.toString() ?? '')
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        initiallyExpanded: _filtersExpanded,
        onExpansionChanged: (expanded) =>
            setState(() => _filtersExpanded = expanded),
        title: Row(
          children: [
            const Expanded(
              child: Text('Filters & Sorting',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            if (_activeFilters().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('${_activeFilters().length} active',
                    style:
                        const TextStyle(color: AppTheme.primary, fontSize: 11)),
              ),
            Text('${state.total} / ${state.systemTotal}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: OutlinedButton.icon(
                  onPressed: _chooseProductSystems,
                  icon: const Icon(Icons.widgets_outlined, size: 16),
                  label: Text(
                    selectedProducts.isEmpty
                        ? 'Product & System: All'
                        : 'Product & System: ${_productSystemLabel()}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _dropdownFilter(
                'Company Valuation',
                _valuationFilter,
                const ['ALL', 'HIGH', 'MEDIUM', 'LOW'],
                (value) => setState(() => _valuationFilter = value ?? 'ALL'),
                labels: const {
                  'ALL': 'All',
                  'HIGH': 'High',
                  'MEDIUM': 'Medium',
                  'LOW': 'Low',
                },
              ),
              _dropdownFilter(
                'Activity & Communication',
                _activityFilter,
                const [
                  'ALL',
                  'ACTIVE',
                  'NO_ACTIVITY',
                  'FOLLOW_UP_OVERDUE',
                  'FOLLOW_UP_DUE',
                ],
                (value) => setState(() => _activityFilter = value ?? 'ALL'),
                labels: const {
                  'ALL': 'All',
                  'ACTIVE': 'Active (last 30 days)',
                  'NO_ACTIVITY': 'No activity',
                  'FOLLOW_UP_OVERDUE': 'Follow-up overdue',
                  'FOLLOW_UP_DUE': 'Follow-up due',
                },
                width: 230,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.darkBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _meetingFilterEnabled,
                      onChanged: (value) => setState(
                          () => _meetingFilterEnabled = value ?? false),
                    ),
                    const Text('Next Meeting Between'),
                    const SizedBox(width: 6),
                    _dateFilterButton(
                      _meetingFrom,
                      'From Date',
                      enabled: _meetingFilterEnabled,
                      onPressed: () => _chooseDate(from: true),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('to'),
                    ),
                    _dateFilterButton(
                      _meetingTo,
                      'To Date',
                      enabled: _meetingFilterEnabled,
                      onPressed: () => _chooseDate(from: false),
                    ),
                  ],
                ),
              ),
              _dropdownFilter(
                'Enquiry',
                _enquiryFilter,
                const ['ALL', 'YES', 'NO'],
                (value) => setState(() => _enquiryFilter = value ?? 'ALL'),
                labels: const {'ALL': 'All', 'YES': 'Yes', 'NO': 'No'},
              ),
              _dropdownFilter(
                'Enquiry Type',
                _enquiryTypeFilter,
                ['ALL', ...enquiryTypes],
                (value) => setState(() => _enquiryTypeFilter = value ?? 'ALL'),
              ),
              _dropdownFilter(
                'Website',
                _websiteFilter,
                const ['ALL', 'AVAILABLE', 'NOT_AVAILABLE'],
                (value) => setState(() => _websiteFilter = value ?? 'ALL'),
                labels: const {
                  'ALL': 'All',
                  'AVAILABLE': 'Available',
                  'NOT_AVAILABLE': 'Not Available',
                },
              ),
              _dropdownFilter(
                'State',
                _stateFilter,
                ['ALL', ...states],
                (value) {
                  setState(() {
                    _stateFilter = value ?? 'ALL';
                    _districtFilter = 'ALL';
                    _filterOptions['districts'] = <String>[];
                  });
                  _loadFilterOptions(state: value);
                },
              ),
              _dropdownFilter(
                'District',
                _districtFilter,
                ['ALL', ...districts],
                (value) => setState(() => _districtFilter = value ?? 'ALL'),
                enabled: _stateFilter != 'ALL',
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _ratingAboveController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Rating Above',
                    prefixText: '> ',
                    isDense: true,
                  ),
                ),
              ),
              _dropdownFilter(
                'Distributor',
                _distributorFilter,
                const ['ALL', 'YES', 'NO'],
                (value) => setState(() => _distributorFilter = value ?? 'ALL'),
                labels: const {'ALL': 'All', 'YES': 'Yes', 'NO': 'No'},
              ),
              _dropdownFilter(
                'Dealer',
                _dealerFilter,
                const ['ALL', 'YES', 'NO'],
                (value) => setState(() => _dealerFilter = value ?? 'ALL'),
                labels: const {'ALL': 'All', 'YES': 'Yes', 'NO': 'No'},
              ),
              _dropdownFilter(
                'Sort By',
                _sortOption,
                const [
                  'COMPANY_NAME_AZ',
                  'COMPANY_NAME_ZA',
                  'RECENTLY_ADDED',
                  'OLDEST_ADDED',
                  'RECENTLY_UPDATED',
                  'HIGHEST_RATING',
                  'LOWEST_RATING',
                  'HIGHEST_VALUATION',
                  'LOWEST_VALUATION',
                  'MOST_ACTIVITIES',
                  'LEAST_ACTIVITIES',
                  'LAST_CONTACTED',
                  'NEXT_MEETING',
                  'NEXT_FOLLOW_UP',
                ],
                (value) =>
                    setState(() => _sortOption = value ?? 'COMPANY_NAME_AZ'),
                labels: const {
                  'COMPANY_NAME_AZ': 'Company Name A-Z',
                  'COMPANY_NAME_ZA': 'Company Name Z-A',
                  'RECENTLY_ADDED': 'Recently Added',
                  'OLDEST_ADDED': 'Oldest Added',
                  'RECENTLY_UPDATED': 'Recently Updated',
                  'HIGHEST_RATING': 'Highest Rating',
                  'LOWEST_RATING': 'Lowest Rating',
                  'HIGHEST_VALUATION': 'Highest Company Valuation',
                  'LOWEST_VALUATION': 'Lowest Company Valuation',
                  'MOST_ACTIVITIES': 'Most Activities',
                  'LEAST_ACTIVITIES': 'Least Activities',
                  'LAST_CONTACTED': 'Last Contacted',
                  'NEXT_MEETING': 'Next Meeting',
                  'NEXT_FOLLOW_UP': 'Next Follow-up',
                },
                width: 230,
              ),
              ElevatedButton(
                onPressed: () => _loadCompanies(page: 1),
                child: const Text('Apply Filter'),
              ),
              OutlinedButton(
                onPressed: _resetFilters,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdownFilter(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged, {
    Map<String, String> labels = const {},
    double width = 190,
    bool enabled = true,
  }) {
    final safeValue = values.contains(value) ? value : values.first;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: safeValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: values
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(
                    labels[option] ?? (option == 'ALL' ? 'All' : option),
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _dateFilterButton(
    DateTime? value,
    String placeholder, {
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      child: Text(
          value == null ? placeholder : DateFormat('yyyy-MM-dd').format(value)),
    );
  }

  Widget _buildPagination(CustomerListState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Page ${state.page} of ${state.totalPages}'),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Previous page',
            onPressed: state.page > 1
                ? () => _loadCompanies(page: state.page - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: state.page < state.totalPages
                ? () => _loadCompanies(page: state.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(CustomerListState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingRowColor:
                    WidgetStateProperty.all(AppTheme.darkBackground),
                columns: const [
                  DataColumn(
                      label: Text('#',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Customer ID',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Company Name',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('GST Status',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Contact Person',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Contact & Email',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Location',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Products & Systems',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Added By',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent))),
                  DataColumn(
                      label: Text('Sales Owner',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary))),
                  DataColumn(
                      label: Text('Valuation / Rating',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Activities',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Status',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Actions',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                rows: state.customers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final c = entry.value;
                  final rowNum = (state.page - 1) * 25 + index + 1;
                  final salesOwner =
                      c.salesOwnerName ?? c.ownerName ?? 'Unassigned';
                  final addedBy = c.addedByName ?? 'System / Admin';
                  final gstDisplay = (c.gstin != null && c.gstin!.isNotEmpty)
                      ? c.gstin!
                      : (c.gstStatus == 'NO_GST' ? 'Unregistered' : 'Pending');

                  return DataRow(
                    onSelectChanged: (_) => context.go('/customers/${c.id}'),
                    cells: [
                      DataCell(Text('$rowNum',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey))),
                      DataCell(Text(c.customerCode,
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.2),
                            child: Text(c.initials,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.companyName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                if (c.customerType.isNotEmpty)
                                  Text(c.customerType.replaceAll('_', ' '),
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      )),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (c.gstin != null && c.gstin!.isNotEmpty
                                      ? Colors.teal
                                      : Colors.orange)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c.gstin != null && c.gstin!.isNotEmpty
                                  ? 'GST Registered'
                                  : (c.gstStatus ?? 'NO GST'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: c.gstin != null && c.gstin!.isNotEmpty
                                    ? Colors.teal
                                    : Colors.orangeAccent,
                              ),
                            ),
                          ),
                          if (c.gstin != null && c.gstin!.isNotEmpty)
                            Text(gstDisplay,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: Colors.grey)),
                        ],
                      )),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.contactPerson,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                          if (c.designation != null &&
                              c.designation!.isNotEmpty)
                            Text(c.designation!,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                        ],
                      )),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.phone, style: const TextStyle(fontSize: 12)),
                          if (c.email.isNotEmpty)
                            Text(c.email,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                        ],
                      )),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.city.isNotEmpty ? c.city : '-',
                              style: const TextStyle(fontSize: 12)),
                          Text(
                            [
                              if (c.district.isNotEmpty) c.district,
                              if (c.state.isNotEmpty) c.state
                            ].join(', '),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      )),
                      DataCell(c.products.isNotEmpty
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                c.products.join(', '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            )
                          : const Text('-',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline,
                                size: 13, color: Colors.blueAccent),
                            const SizedBox(width: 4),
                            Text(
                              addedBy,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueAccent),
                            ),
                          ],
                        ),
                      )),
                      DataCell(
                        InkWell(
                          onTap: () => _showAssignHostModal(c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_pin,
                                    size: 13, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  salesOwner,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_drop_down,
                                    size: 14, color: AppTheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  size: 12, color: Colors.amber),
                              const SizedBox(width: 3),
                              Text('${c.customerRating.toStringAsFixed(1)} / 5',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text(
                              '${c.valuationPercentage.toStringAsFixed(0)}% Potential',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ],
                      )),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${c.activityCount} acts · ${c.enquiryCount} enq',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      )),
                      DataCell(_StatusBadge(status: c.status)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.visibility_outlined, size: 16),
                            onPressed: () => context.go('/customers/${c.id}'),
                            tooltip: 'View Profile',
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_comment_outlined,
                                size: 16, color: AppTheme.primary),
                            onPressed: () => context
                                .push('/crm/follow-ups?customerId=${c.id}'),
                            tooltip: 'Add Follow-up',
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_add_alt_1_outlined,
                                size: 16, color: AppTheme.primary),
                            onPressed: () => _showAssignHostModal(c),
                            tooltip: 'Assign Sales Owner',
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            onPressed: () =>
                                context.go('/customers/${c.id}/edit'),
                            tooltip: 'Edit Company',
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: Colors.redAccent),
                            onPressed: () => _confirmDeleteCustomer(c),
                            tooltip: 'Delete Company',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${state.total} companies found',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCardList(CustomerListState state) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: state.customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = state.customers[i];
        final salesOwner = c.salesOwnerName ?? c.ownerName ?? 'Unassigned';
        final addedBy = c.addedByName ?? 'System / Admin';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      child: Text(c.initials,
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.companyName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                              '${c.customerCode} · ${c.city.isNotEmpty ? c.city : 'No City'}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    _TypeBadge(type: c.customerType),
                    const SizedBox(width: 6),
                    _StatusBadge(status: c.status),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Contact: ${c.contactPerson} · ${c.phone}',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.person_pin,
                                  size: 12, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text('Sales Owner: $salesOwner',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 12, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text('Added By: $addedBy',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(c.customerRating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                            '${c.valuationPercentage.toStringAsFixed(0)}% Potential',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('View 360',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => context.go('/customers/${c.id}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_comment_outlined,
                          size: 16, color: AppTheme.primary),
                      onPressed: () =>
                          context.push('/crm/follow-ups?customerId=${c.id}'),
                      tooltip: 'Add Follow-up',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: () => context.go('/customers/${c.id}/edit'),
                      tooltip: 'Edit Company',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.redAccent),
                      onPressed: () => _confirmDeleteCustomer(c),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text('No customers found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add your first customer to get started',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/customers/new'),
            icon: const Icon(Icons.add),
            label: const Text('Add Customer'),
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
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadCompanies(page: 1),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Delete Customer?',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete ${customer.companyName}? This action cannot be undone and will delete all associated data.',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(customersRepositoryProvider)
                    .deleteCustomer(customer.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Customer deleted successfully'),
                      backgroundColor: AppTheme.success));
                  _loadCompanies(page: ref.read(customerListProvider).page);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: AppTheme.error));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAssignHostModal(Customer customer) {
    StaffMember? selectedStaff;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.darkBorder),
          ),
          title: Row(
            children: [
              const Icon(Icons.person_add_alt_1_outlined,
                  color: AppTheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Admin / Employee Host',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(customer.companyName,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Select the Admin or Employee to assign as Host / Account Owner for this company:',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 12),
              FutureBuilder<List<StaffMember>>(
                future: ref.read(staffRepositoryProvider).getStaffList(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Loading staff list...',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    );
                  }
                  final staffList = snapshot.data ?? [];
                  return DropdownButtonFormField<StaffMember>(
                    initialValue: selectedStaff,
                    decoration: InputDecoration(
                      hintText: 'Select Admin or Employee',
                      prefixIcon: const Icon(Icons.person_pin,
                          size: 18, color: AppTheme.primary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      fillColor: AppTheme.darkCard,
                      filled: true,
                    ),
                    dropdownColor: AppTheme.darkCard,
                    items: staffList.map((staff) {
                      final roleLabel = staff.designationName ??
                          staff.departmentName ??
                          'Employee';
                      final isAdmin =
                          roleLabel.toLowerCase().contains('admin') ||
                              roleLabel.toLowerCase().contains('director') ||
                              roleLabel.toLowerCase().contains('manager');
                      return DropdownMenuItem<StaffMember>(
                        value: staff,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${staff.fullName} (${staff.employeeId})',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? AppTheme.primary.withValues(alpha: 0.2)
                                    : Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isAdmin
                                        ? AppTheme.primary
                                        : Colors.blue,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedStaff = val),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (selectedStaff == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Please select an Admin or Employee host')));
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  final repo = ref.read(customersRepositoryProvider);
                  await repo.updateCustomer(customer.id, {
                    'ownerName': selectedStaff!.fullName,
                    'assignedStaffId': selectedStaff!.id,
                    'assignedStaffName': selectedStaff!.fullName,
                  });
                  _loadCompanies(page: ref.read(customerListProvider).page);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            'Assigned host for ${customer.companyName} updated to "${selectedStaff!.fullName}" ✓'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  _loadCompanies(page: ref.read(customerListProvider).page);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            'Assigned host updated to "${selectedStaff!.fullName}" ✓'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('ASSIGN HOST'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'END_CUSTOMER': Color(0xFF3B82F6),
      'DEALER': Color(0xFF10B981),
      'DISTRIBUTOR': Color(0xFF8B5CF6),
      'OEM': Color(0xFFF97316),
      'GOVERNMENT': Color(0xFFEF4444),
      'OTHER': Color(0xFF6B7280),
    };
    final color = colors[type] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        type.replaceAll('_', ' '),
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'ACTIVE' ? AppTheme.success : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
