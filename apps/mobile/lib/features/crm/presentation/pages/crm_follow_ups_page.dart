import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';

class CrmFollowUpsPage extends ConsumerStatefulWidget {
  final String? initialCustomerId;
  final String? initialActivityFilter;
  final String? initialAction;

  const CrmFollowUpsPage({
    super.key,
    this.initialCustomerId,
    this.initialActivityFilter,
    this.initialAction,
  });

  @override
  ConsumerState<CrmFollowUpsPage> createState() => _CrmFollowUpsPageState();
}

class _CrmFollowUpsPageState extends ConsumerState<CrmFollowUpsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _filters = [
    'ALL',
    'TODAY',
    'OVERDUE',
    'PENDING',
    'COMPLETED'
  ];
  String _selectedActivityFilter = 'ALL';
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  List<Map<String, dynamic>> _companies = [];
  int _companyLoadToken = 0;
  int _companiesPage = 1;
  int _companiesTotal = 0;
  int _companiesTotalPages = 1;
  late Future<List<StaffMember>> _staffFuture;
  bool _companiesLoading = false;
  String? _companiesError;
  String? _selectedCompanyId;
  String? _assignedStaffId;
  bool _didSelectInitialCompany = false;
  bool _isTableView = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialActivityFilter != null &&
        widget.initialActivityFilter!.isNotEmpty) {
      _selectedActivityFilter = widget.initialActivityFilter!.toUpperCase();
    }
    _staffFuture = ref.read(staffRepositoryProvider).getStaffList();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadCurrentTab();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentTab();
      if (widget.initialAction != null && widget.initialAction!.isNotEmpty) {
        _handleInitialAction(widget.initialAction!);
      }
    });
  }

  void _handleInitialAction(String action) {
    String type = 'CALL';
    final act = action.toLowerCase();
    if (act.contains('meet')) {
      type = 'MEETING';
    } else if (act.contains('site') || act.contains('visit')) {
      type = 'SITE_VISIT';
    } else if (act.contains('follow')) {
      type = 'FOLLOW_UP';
    }
    _showUnifiedInteractionDialog(initialType: type);
  }

  void _loadCurrentTab() {
    _companiesPage = 1;
    final filter = _filters[_tabController.index];
    if (filter == 'TODAY') {
      ref.read(followUpListProvider.notifier).loadFollowUps(due: 'today');
    } else if (filter == 'OVERDUE') {
      ref.read(followUpListProvider.notifier).loadFollowUps(due: 'overdue');
    } else if (filter == 'ALL') {
      ref.read(followUpListProvider.notifier).loadFollowUps();
    } else {
      ref.read(followUpListProvider.notifier).loadFollowUps(status: filter);
    }
    _loadCompanies();
  }

  Future<void> _loadCompanies({int? page}) async {
    if (!mounted) return;
    if (page != null) _companiesPage = page;
    final token = ++_companyLoadToken;
    setState(() {
      _companiesLoading = true;
      _companiesError = null;
    });
    try {
      final response =
          await ref.read(crmRepositoryProvider).getFollowUpCompanies(
                search: _searchController.text.trim(),
                status: _filters[_tabController.index],
                assignedStaffId: _assignedStaffId,
                customerId: widget.initialCustomerId,
                page: _companiesPage,
              );
      if (!mounted || token != _companyLoadToken) return;
      setState(() {
        _companies =
            (response['data'] as List? ?? []).whereType<Map>().map((company) {
          return Map<String, dynamic>.from(company);
        }).toList();
        final meta = response['meta'] as Map? ?? const {};
        _companiesTotal = (meta['total'] as num?)?.toInt() ?? _companies.length;
        _companiesTotalPages = (meta['totalPages'] as num?)?.toInt() ?? 1;
        _companiesLoading = false;
        if (!_didSelectInitialCompany && widget.initialCustomerId != null) {
          _selectedCompanyId = widget.initialCustomerId;
          _didSelectInitialCompany = true;
        }
      });
    } catch (e) {
      if (!mounted || token != _companyLoadToken) return;
      setState(() {
        _companiesLoading = false;
        _companiesError = e.toString();
      });
    }
  }

  void _onCompanySearch(String value) {
    _searchTimer?.cancel();
    _companiesPage = 1;
    _searchTimer = Timer(const Duration(milliseconds: 300), _loadCompanies);
  }

  void _reloadStaff() {
    setState(() {
      _staffFuture = ref.read(staffRepositoryProvider).getStaffList();
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/crm/dashboard');
            }
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CRM & Sales  /  Interactions',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
            Text('Unified CRM Interaction Workspace',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppTheme.darkSurface,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'My Day'),
            Tab(text: '🚨 Overdue'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          // View Switcher: Table View vs Card View
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true,
                  label: Text('Table'),
                  icon: Icon(Icons.table_chart_outlined, size: 16)),
              ButtonSegment(
                  value: false,
                  label: Text('Cards'),
                  icon: Icon(Icons.grid_view_outlined, size: 16)),
            ],
            selected: {_isTableView},
            onSelectionChanged: (set) =>
                setState(() => _isTableView = set.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showUnifiedInteractionDialog(
              initialCustomer: _selectedCompany,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Log Interaction'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentTab,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showUnifiedInteractionDialog(
          initialCustomer: _selectedCompany,
        ),
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: Text(
          _selectedCompany != null
              ? 'Log Interaction (${_selectedCompany!['companyName'] ?? 'Selected'})'
              : 'Log Interaction',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onCompanySearch,
              decoration: InputDecoration(
                hintText:
                    'Search company by name, GST, phone, email, contact...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _loadCompanies();
                        },
                      ),
                filled: true,
                fillColor: AppTheme.darkCard,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 280,
                child: FutureBuilder<List<StaffMember>>(
                  future: _staffFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return OutlinedButton.icon(
                        onPressed: _reloadStaff,
                        icon: const Icon(Icons.refresh, size: 16),
                        label:
                            const Text('Employee filter unavailable · Retry'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _assignedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Employee',
                        isDense: true,
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('All Employees')),
                        ...snapshot.data!
                            .map((employee) => DropdownMenuItem<String>(
                                  value: employee.id,
                                  child: Text(employee.fullName,
                                      overflow: TextOverflow.ellipsis),
                                )),
                      ],
                      onChanged: (value) {
                        setState(() => _assignedStaffId = value);
                        _companiesPage = 1;
                        _loadCompanies();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          _buildActivityFilterBar(),
          if (_selectedCompany != null)
            _buildSelectedCompany(_selectedCompany!),
          Expanded(
            child: _companiesLoading
                ? const Center(child: CircularProgressIndicator())
                : _companiesError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 44, color: AppTheme.error),
                            const SizedBox(height: 10),
                            Text(_companiesError!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                                onPressed: _loadCompanies,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _displayedCompanies.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.filter_list_off,
                                    size: 36, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedActivityFilter == 'ALL'
                                      ? 'No companies match this follow-up filter.'
                                      : 'No companies match the ${_selectedActivityFilter.replaceAll('_', ' ')} filter.',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : _isTableView
                            ? _buildCompanyTable(_displayedCompanies)
                            : _buildCompanyCards(_displayedCompanies),
          ),
          if (_companiesTotalPages > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                      'Page $_companiesPage of $_companiesTotalPages  ·  $_companiesTotal companies'),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: _companiesPage > 1
                        ? () => _loadCompanies(page: _companiesPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: _companiesPage < _companiesTotalPages
                        ? () => _loadCompanies(page: _companiesPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _displayedCompanies {
    if (_selectedActivityFilter == 'ALL') {
      return _companies;
    }
    return _companies.where((company) {
      final followUps =
          (company['followUps'] as List? ?? const []).whereType<Map>();
      if (followUps.isEmpty) {
        return true;
      }
      return followUps.any((fu) {
        final actType =
            (fu['activityType'] ?? fu['type'] ?? '').toString().toUpperCase();
        if (_selectedActivityFilter == 'CALL') {
          return actType.contains('CALL') || actType.contains('PHONE');
        } else if (_selectedActivityFilter == 'MEETING') {
          return actType.contains('MEET');
        } else if (_selectedActivityFilter == 'SITE_VISIT') {
          return actType.contains('SITE') || actType.contains('VISIT');
        } else if (_selectedActivityFilter == 'FOLLOW_UP') {
          return actType.contains('FOLLOW') || actType.isEmpty;
        }
        return true;
      });
    }).toList();
  }

  Widget _buildActivityFilterBar() {
    final filters = [
      ('ALL', 'All Activities', Icons.dashboard_outlined),
      ('CALL', 'Calls & Logs', Icons.phone_in_talk_outlined),
      ('MEETING', 'Meetings & Approvals', Icons.calendar_month_outlined),
      ('SITE_VISIT', 'Site Visits', Icons.engineering_outlined),
      ('FOLLOW_UP', 'Follow-ups & SLA', Icons.assignment_turned_in_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedActivityFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                f.$3,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.primary,
              ),
              label: Text(f.$2),
              selected: isSelected,
              selectedColor: AppTheme.primary,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedActivityFilter = f.$1;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Map<String, dynamic>? get _selectedCompany {
    for (final company in _companies) {
      if (company['id'] == _selectedCompanyId) return company;
    }
    return null;
  }

  Widget _buildSelectedCompany(Map<String, dynamic> company) {
    final followUps =
        (company['followUps'] as List? ?? const []).whereType<Map>().toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.09),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company['companyName']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        '${company['contactPerson'] ?? ''}  ·  ${company['phone'] ?? ''}  ·  ${company['city'] ?? ''}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${followUps.length} interactions  ·  Last: ${_formatDate(company['lastInteraction'])}  ·  Next: ${_formatDate(company['nextFollowUp'])}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCompanyHistory(company),
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Unified History'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    _showUnifiedInteractionDialog(initialCustomer: company),
                icon: const Icon(Icons.add_task, size: 16),
                label: const Text('Log Interaction'),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quick Action Bar
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.phone_in_talk,
                    size: 14, color: Colors.greenAccent),
                label: const Text('Log Call'),
                onPressed: () => _showUnifiedInteractionDialog(
                  initialCustomer: company,
                  initialType: 'CALL',
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month,
                    size: 14, color: Colors.blueAccent),
                label: const Text('Book Meeting'),
                onPressed: () => _showUnifiedInteractionDialog(
                  initialCustomer: company,
                  initialType: 'MEETING',
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.engineering,
                    size: 14, color: Colors.orangeAccent),
                label: const Text('Arrange Site Visit'),
                onPressed: () => _showUnifiedInteractionDialog(
                  initialCustomer: company,
                  initialType: 'SITE_VISIT',
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.assignment_turned_in,
                    size: 14, color: Colors.amberAccent),
                label: const Text('Add Follow-up'),
                onPressed: () => _showUnifiedInteractionDialog(
                  initialCustomer: company,
                  initialType: 'FOLLOW_UP',
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.attach_file,
                    size: 14, color: Colors.purpleAccent),
                label: const Text('Customer Media'),
                onPressed: () => _showUnifiedInteractionDialog(
                  initialCustomer: company,
                  initialFocusMedia: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyTable(List<Map<String, dynamic>> companies) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
          dataRowMaxHeight: 72,
          columns: const [
            DataColumn(label: Text('Select')),
            DataColumn(label: Text('Company / Contact')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Follow-ups')),
            DataColumn(label: Text('Last Follow-up')),
            DataColumn(label: Text('Next Due')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: companies.map((company) {
            final selected = company['id'] == _selectedCompanyId;
            final lastDate = _formatDate(company['lastInteraction']);
            final nextDate = _formatDate(company['nextFollowUp']);
            final status =
                company['displayStatus']?.toString() ?? 'NO_FOLLOW_UP';
            return DataRow(
              selected: selected,
              onSelectChanged: (value) => setState(() {
                _selectedCompanyId =
                    value == true ? company['id']?.toString() : null;
              }),
              cells: [
                DataCell(Checkbox(
                  value: selected,
                  onChanged: (value) => setState(() {
                    _selectedCompanyId =
                        value == true ? company['id']?.toString() : null;
                  }),
                )),
                DataCell(SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company['companyName']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${company['contactPerson'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                )),
                DataCell(Text(company['phone']?.toString() ?? '—')),
                DataCell(Text(company['city']?.toString() ?? '—')),
                DataCell(Text('${company['followUpCount'] ?? 0}')),
                DataCell(Text(lastDate)),
                DataCell(Text(nextDate,
                    style: TextStyle(
                        color: status == 'OVERDUE' ? AppTheme.error : null))),
                DataCell(_buildStatusBadge(status)),
                DataCell(Row(
                  children: [
                    TextButton(
                        onPressed: () => _showCompanyHistory(company),
                        child: const Text('View')),
                    TextButton.icon(
                      onPressed: () => _showCompanyFollowUpDialog(company),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Follow-up'),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCompanyCards(List<Map<String, dynamic>> companies) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: companies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final company = companies[index];
        final status = company['displayStatus']?.toString() ?? 'NO_FOLLOW_UP';
        final selected = company['id']?.toString() == _selectedCompanyId;
        final contact = [
          company['contactPerson']?.toString(),
          company['phone']?.toString(),
          company['city']?.toString(),
        ]
            .where((value) => value != null && value.trim().isNotEmpty)
            .join('  ·  ');
        return Card(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : AppTheme.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? AppTheme.primary : AppTheme.darkBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              _selectedCompanyId = selected ? null : company['id']?.toString();
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (value) => setState(() {
                      _selectedCompanyId =
                          value == true ? company['id']?.toString() : null;
                    }),
                    activeColor: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      (company['companyName']?.toString().trim().isNotEmpty ==
                              true
                          ? company['companyName']
                              .toString()
                              .trim()[0]
                              .toUpperCase()
                          : 'C'),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                company['companyName']?.toString() ??
                                    'Unnamed company',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildStatusBadge(status),
                          ],
                        ),
                        if (contact.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            contact,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _summaryChip(
                                '${company['followUpCount'] ?? 0} follow-ups'),
                            _summaryChip(
                                'Last: ${_formatDate(company['lastInteraction'])}'),
                            _summaryChip(
                                'Next: ${_formatDate(company['nextFollowUp'])}'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showCompanyHistory(company),
                              icon: const Icon(Icons.history, size: 16),
                              label: const Text('View History'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showCompanyFollowUpDialog(company),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Follow-up'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = switch (status) {
      'OVERDUE' => AppTheme.error,
      'PENDING' => Colors.blue,
      'COMPLETED' => AppTheme.success,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8)),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    return date == null ? '—' : DateFormat('dd MMM yyyy').format(date);
  }

  void _showCompanyHistory(Map<String, dynamic> company) {
    final followUps = (company['followUps'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
      ..sort((a, b) => ((b['followUpNumber'] as num?)?.toInt() ?? 0)
          .compareTo((a['followUpNumber'] as num?)?.toInt() ?? 0));

    final companyId = company['id']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setHistoryState) {
          int activeTab = 0;
          String timelineFilter = 'ALL';
          return StatefulBuilder(
            builder: (context, setInnerState) {
              return Dialog(
                backgroundColor: AppTheme.darkSurface,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 820, maxHeight: 760),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                company['companyName']?.toString() ??
                                    'Company history',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        Text(
                          '${company['contactPerson'] ?? ''}  ·  ${company['phone'] ?? ''}  ·  ${company['email'] ?? ''}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SegmentedButton<int>(
                              segments: [
                                ButtonSegment(
                                  value: 0,
                                  label: Text(
                                      'Follow-ups (${followUps.length})'),
                                  icon: const Icon(Icons.task_alt, size: 16),
                                ),
                                const ButtonSegment(
                                  value: 1,
                                  label: Text('Customer 360 Timeline'),
                                  icon: Icon(Icons.history, size: 16),
                                ),
                              ],
                              selected: {activeTab},
                              onSelectionChanged: (set) =>
                                  setInnerState(() => activeTab = set.first),
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _showUnifiedInteractionDialog(
                                  initialCustomer: company,
                                );
                              },
                              icon: const Icon(Icons.add_task, size: 16),
                              label: const Text('Log Interaction'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: activeTab == 0
                              ? (followUps.isEmpty
                                  ? const Center(
                                      child: Text(
                                          'No interactions recorded yet.',
                                          style: TextStyle(color: Colors.grey)),
                                    )
                                  : ListView.separated(
                                      itemCount: followUps.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 16),
                                      itemBuilder: (context, index) {
                                        final followUp = followUps[index];
                                        final number =
                                            followUp['followUpNumber'] ??
                                                index + 1;
                                        final date =
                                            followUp['interactionDate'] ??
                                                followUp['scheduledDate'] ??
                                                followUp['createdAt'];
                                        final status = followUp[
                                                    'displayStatus']
                                                ?.toString() ??
                                            followUp['status']?.toString() ??
                                            'PENDING';
                                        final staff =
                                            followUp['assignedStaff'] as Map?;
                                        final attachments = (followUp[
                                                'attachments'] as List?) ??
                                            const [];

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Follow-up #$number  ·  ${followUp['activityType'] ?? followUp['title'] ?? 'FOLLOW-UP'}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                  _buildStatusBadge(status),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_formatDate(date)}  ·  Assigned: ${staff?['fullName'] ?? '—'}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                              if ((followUp['subject'] ??
                                                          followUp['title'])
                                                      ?.toString()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                      top: 6),
                                                  child: Text(
                                                      'Subject: ${followUp['subject'] ?? followUp['title']}'),
                                                ),
                                              if (followUp['discussion']
                                                      ?.toString()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                      top: 4),
                                                  child: Text(
                                                      'Discussion: ${followUp['discussion']}'),
                                                ),
                                              if (followUp['outcome']
                                                      ?.toString()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                      top: 4),
                                                  child: Text(
                                                      'Outcome: ${followUp['outcome']}',
                                                      style: const TextStyle(
                                                          color: Colors
                                                              .amberAccent)),
                                                ),
                                              if (followUp['nextAction']
                                                      ?.toString()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                      top: 4),
                                                  child: Text(
                                                      'Next action: ${followUp['nextAction']}'),
                                                ),
                                              if (attachments.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: attachments
                                                      .whereType<Map>()
                                                      .map((att) {
                                                    final mediaClass =
                                                        att['mediaClass']
                                                                ?.toString() ??
                                                            'DOCUMENT';
                                                    final fileName =
                                                        att['fileName']
                                                                ?.toString() ??
                                                            'Attachment';
                                                    final attId = att['id']
                                                            ?.toString() ??
                                                        '';
                                                    IconData icon = Icons
                                                        .insert_drive_file;
                                                    if (mediaClass == 'AUDIO') {
                                                      icon = Icons.mic;
                                                    } else if (mediaClass ==
                                                        'IMAGE') {
                                                      icon = Icons.photo;
                                                    } else if (mediaClass ==
                                                        'VIDEO') {
                                                      icon = Icons.videocam;
                                                    }

                                                    return ActionChip(
                                                      avatar: Icon(icon,
                                                          size: 14,
                                                          color: AppTheme
                                                              .primary),
                                                      label: Text(fileName,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      11)),
                                                      onPressed: () {
                                                        if (attId.isNotEmpty) {
                                                          openWebUrl(
                                                              '${AppConstants.baseUrl}/crm/attachments/$attId/stream');
                                                        }
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                              if (status == 'PENDING' ||
                                                  status == 'OVERDUE')
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      Navigator.pop(
                                                          dialogContext);
                                                      _showResolveFollowUpDialog(
                                                          followUp);
                                                    },
                                                    icon: const Icon(
                                                        Icons.check,
                                                        size: 14),
                                                    label: const Text(
                                                        'Resolve Outcome'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          ChoiceChip(
                                            label: const Text('All'),
                                            selected: timelineFilter == 'ALL',
                                            onSelected: (val) => setInnerState(
                                                () => timelineFilter = 'ALL'),
                                          ),
                                          const SizedBox(width: 6),
                                          ChoiceChip(
                                            label: const Text('Calls'),
                                            selected: timelineFilter == 'CALL',
                                            onSelected: (val) => setInnerState(
                                                () => timelineFilter = 'CALL'),
                                          ),
                                          const SizedBox(width: 6),
                                          ChoiceChip(
                                            label: const Text('Meetings'),
                                            selected: timelineFilter == 'MEETING',
                                            onSelected: (val) => setInnerState(
                                                () => timelineFilter = 'MEETING'),
                                          ),
                                          const SizedBox(width: 6),
                                          ChoiceChip(
                                            label: const Text('Site Visits'),
                                            selected: timelineFilter == 'SITE_VISIT',
                                            onSelected: (val) => setInnerState(
                                                () => timelineFilter = 'SITE_VISIT'),
                                          ),
                                          const SizedBox(width: 6),
                                          ChoiceChip(
                                            label: const Text('Follow-ups'),
                                            selected: timelineFilter == 'FOLLOW_UP',
                                            onSelected: (val) => setInnerState(
                                                () => timelineFilter = 'FOLLOW_UP'),
                                          ),
                                          const SizedBox(width: 6),
                                          ChoiceChip(
                                            label: const Text('With Media'),
                                            selected: timelineFilter == 'MEDIA',
                                            onSelected: (val) => setInnerState(
                                                () => timelineFilter = 'MEDIA'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: FutureBuilder<List<dynamic>>(
                                        future: ref
                                            .read(crmRepositoryProvider)
                                            .getCustomerTimeline(companyId),
                                        builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Error loading timeline: ${snapshot.error}',
                                          style: const TextStyle(
                                              color: AppTheme.error),
                                        ),
                                      );
                                    }
                                    final rawTimeline = snapshot.data ?? const [];
                                          final timeline = rawTimeline.where((item) {
                                            if (item is! Map) return false;
                                            if (timelineFilter == 'ALL') return true;
                                            final itemType = (item['type'] ?? item['activityType'] ?? '').toString().toUpperCase();
                                            if (timelineFilter == 'CALL') return itemType.contains('CALL');
                                            if (timelineFilter == 'MEETING') return itemType.contains('MEETING');
                                            if (timelineFilter == 'SITE_VISIT') return itemType.contains('SITE') || itemType.contains('VISIT');
                                            if (timelineFilter == 'FOLLOW_UP') return itemType.contains('FOLLOW');
                                            if (timelineFilter == 'MEDIA') {
                                              final atts = (item['attachments'] as List?) ?? const [];
                                              return atts.isNotEmpty;
                                            }
                                            return true;
                                          }).toList();
                                          if (timeline.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No timeline records found.',
                                          style:
                                              TextStyle(color: Colors.grey),
                                        ),
                                      );
                                    }

                                    return ListView.separated(
                                      itemCount: timeline.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 16),
                                      itemBuilder: (context, index) {
                                        final item = timeline[index];
                                        if (item is! Map) {
                                          return const SizedBox.shrink();
                                        }
                                        final title = item['title'] ??
                                            item['subject'] ??
                                            item['type'] ??
                                            'Activity';
                                        final type = item['type']?.toString() ??
                                            'INTERACTION';
                                        final date = item['timestamp'] ??
                                            item['interactionDate'] ??
                                            item['createdAt'];
                                        final details = item['details'] ??
                                            item['discussion'] ??
                                            item['notes'];
                                        final outcome = item['outcome'];
                                        final staffName = item['userName'] ??
                                            item['staffName'] ??
                                            item['assignedStaff']
                                                ?['fullName'];
                                        final attachments =
                                            (item['attachments'] as List?) ??
                                                const [];

                                        return Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.darkCard,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.white10),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primary
                                                          .withValues(alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      type,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              AppTheme.primary,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      title.toString(),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatDate(date),
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                              if (staffName != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'By: $staffName',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white60),
                                                ),
                                              ],
                                              if (details != null &&
                                                  details
                                                      .toString()
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  details.toString(),
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              ],
                                              if (outcome != null &&
                                                  outcome
                                                      .toString()
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Outcome: $outcome',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .amberAccent,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ],
                                              if (attachments.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: attachments
                                                      .whereType<Map>()
                                                      .map((att) {
                                                    final mediaClass =
                                                        att['mediaClass']
                                                                ?.toString() ??
                                                            'DOCUMENT';
                                                    final fileName =
                                                        att['fileName']
                                                                ?.toString() ??
                                                            'Attachment';
                                                    final attId = att['id']
                                                            ?.toString() ??
                                                        '';
                                                    IconData icon = Icons
                                                        .insert_drive_file;
                                                    if (mediaClass == 'AUDIO') {
                                                      icon = Icons.mic;
                                                    } else if (mediaClass ==
                                                        'IMAGE') {
                                                      icon = Icons.photo;
                                                    } else if (mediaClass ==
                                                        'VIDEO') {
                                                      icon = Icons.videocam;
                                                    }

                                                    return ActionChip(
                                                      avatar: Icon(icon,
                                                          size: 14,
                                                          color: AppTheme
                                                              .primary),
                                                      label: Text(fileName,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      11)),
                                                      onPressed: () {
                                                        if (attId.isNotEmpty) {
                                                          openWebUrl(
                                                              '${AppConstants.baseUrl}/crm/attachments/$attId/stream');
                                                        }
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCompanyFollowUpDialog(Map<String, dynamic> company) {
    _showUnifiedInteractionDialog(
      initialCustomer: company,
      initialType: 'FOLLOW_UP',
    );
  }

  /// Phase 3: Unified Follow-up Resolution Workspace Dialog
  /// Includes:
  /// - Real outcome codes (CONNECTED, NO_ANSWER, BUSY, INTERESTED, etc.)
  /// - Automatic callback suggestion from backend on NO_ANSWER & BUSY
  /// - Editable next action scheduling with explicit opt-out
  /// - Multi-file attachments & safe audio recording selection
  /// - Idempotency key to prevent duplicate submissions on retries
  void _showResolveFollowUpDialog(Map<String, dynamic> followUp) {
    final company = followUp['customer'] as Map? ??
        (followUp['company'] as Map?) ??
        _selectedCompany;
    final companyId = company?['id']?.toString() ??
        followUp['customerId']?.toString() ??
        '';
    final companyName = company?['companyName']?.toString() ??
        followUp['companyName']?.toString() ??
        'Company';

    final subjectController = TextEditingController(
        text: followUp['subject']?.toString() ??
            followUp['title']?.toString() ??
            '');
    final discussionController = TextEditingController(
        text: followUp['discussion']?.toString() ?? '');
    final notesController = TextEditingController(
        text: followUp['notes']?.toString() ?? '');
    final nextSubjectController = TextEditingController();
    final nextActionController = TextEditingController();
    final nextNotesController = TextEditingController();

    String activityType =
        (followUp['activityType']?.toString() ?? 'CALL').toUpperCase();
    if (![
      'CALL',
      'MEETING',
      'SITE_VISIT',
      'DEMO',
      'EMAIL',
      'WHATSAPP',
      'OTHER'
    ].contains(activityType)) {
      activityType = 'CALL';
    }

    String outcome = 'CONNECTED';
    int? callDurationSec;
    bool scheduleNext = false;
    DateTime nextDate = DateTime.now().add(const Duration(days: 1));
    String nextActivityType = 'CALL';
    String nextPriority = 'MEDIUM';
    StaffMember? nextStaff;
    bool isFetchingSuggestion = false;
    String? suggestionMessage;
    bool isSubmitting = false;
    bool isUploadingAttachment = false;
    String? uploadStatusMessage;
    final List<Map<String, dynamic>> uploadedAttachments = [];
    final idempotencyKey =
        'idemp-${followUp['id']}-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';

    final staffFuture = ref.read(staffRepositoryProvider).getStaffList();

    showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> onOutcomeChanged(String? newOutcome) async {
            if (newOutcome == null) return;
            setDialogState(() {
              outcome = newOutcome;
            });

            if (newOutcome == 'NO_ANSWER' || newOutcome == 'BUSY') {
              setDialogState(() {
                scheduleNext = true;
                isFetchingSuggestion = true;
                suggestionMessage = 'Fetching automated callback suggestion...';
                if (newOutcome == 'NO_ANSWER') {
                  nextSubjectController.text =
                      'Callback: Customer did not answer call';
                  nextActionController.text =
                      'Retry phone call (Customer was unreachable / No Answer)';
                } else {
                  nextSubjectController.text =
                      'Callback: Phone line was busy';
                  nextActionController.text =
                      'Retry phone call (Customer line was busy)';
                }
              });

              try {
                final suggestion = await ref
                    .read(crmRepositoryProvider)
                    .getCallbackSuggestion();
                final iso = suggestion['suggestedDateIso']?.toString() ??
                    suggestion['suggestedDate']?.toString();
                DateTime parsed = DateTime.now().add(const Duration(days: 1));
                if (iso != null) {
                  parsed = DateTime.tryParse(iso)?.toLocal() ?? parsed;
                }
                final formatted = suggestion['formattedIST'] ??
                    DateFormat('dd MMM yyyy, hh:mm a').format(parsed);

                setDialogState(() {
                  nextDate = parsed;
                  isFetchingSuggestion = false;
                  suggestionMessage =
                      '💡 Automated callback applied: $formatted (${suggestion['dayOfWeek'] ?? 'Next working day'})';
                });
              } catch (e) {
                // Fallback to tomorrow 11:00 AM IST
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                final fallbackDate = DateTime(
                    tomorrow.year, tomorrow.month, tomorrow.day, 11, 0);
                setDialogState(() {
                  nextDate = fallbackDate;
                  isFetchingSuggestion = false;
                  suggestionMessage =
                      '💡 Callback scheduled for ${DateFormat('dd MMM yyyy, hh:mm a').format(fallbackDate)}';
                });
              }
            } else if (newOutcome == 'MEETING_FIXED') {
              setDialogState(() {
                scheduleNext = true;
                nextActivityType = 'MEETING';
                nextSubjectController.text = 'Technical / Commercial Meeting';
                nextActionController.text =
                    'Conduct meeting as agreed during resolution';
              });
            } else if (newOutcome == 'QUOTATION_REQUESTED') {
              setDialogState(() {
                scheduleNext = true;
                nextSubjectController.text = 'Follow-up on Quotation & Specs';
                nextActionController.text =
                    'Share quotation and follow up for technical approval';
              });
            }
          }

          void pickAndUploadAttachment(String fieldType) {
            pickAndUploadWebFile(
              fieldType: fieldType,
              onFilePicked: (fileName, bytes) async {
                setDialogState(() {
                  isUploadingAttachment = true;
                  uploadStatusMessage = 'Uploading "$fileName"...';
                });

                try {
                  final results = await ref
                      .read(crmRepositoryProvider)
                      .uploadCrmAttachments(
                        files: [(fileName: fileName, bytes: bytes)],
                        customerId: companyId.isNotEmpty ? companyId : null,
                        followUpId: followUp['id']?.toString(),
                        sourceCategory: 'FOLLOW_UP_RESOLUTION',
                        description:
                            'Uploaded during follow-up resolution #${followUp['followUpNumber'] ?? ''}',
                      );

                  setDialogState(() {
                    isUploadingAttachment = false;
                    uploadStatusMessage = null;
                    if (results.isNotEmpty) {
                      uploadedAttachments.addAll(results);
                    } else {
                      uploadedAttachments.add({
                        'id': 'att-${DateTime.now().millisecondsSinceEpoch}',
                        'fileName': fileName,
                        'fileSizeBytes': bytes.length,
                        'mediaClass': fieldType == 'PHOTO'
                            ? 'IMAGE'
                            : (fieldType == 'AUDIO' ? 'AUDIO' : 'DOCUMENT'),
                      });
                    }
                  });
                } catch (e) {
                  setDialogState(() {
                    isUploadingAttachment = false;
                    uploadStatusMessage = 'Upload failed: $e';
                  });
                }
              },
            );
          }

          return Dialog(
            backgroundColor: AppTheme.darkSurface,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 680, maxHeight: 820),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppTheme.primary, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Resolve Follow-up #${followUp['followUpNumber'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(companyName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          if (company?['phone'] != null ||
                              company?['contactPerson'] != null)
                            Text(
                              '${company?['contactPerson'] ?? ''}  ·  ${company?['phone'] ?? ''}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          if (followUp['scheduledDate'] != null)
                            Text(
                              'Scheduled: ${_formatDate(followUp['scheduledDate'])}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Activity Type & Outcome
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: activityType,
                                    decoration: const InputDecoration(
                                      labelText: 'Activity Type *',
                                      prefixIcon: Icon(Icons.touch_app, size: 18),
                                    ),
                                    items: const [
                                      'CALL',
                                      'MEETING',
                                      'SITE_VISIT',
                                      'DEMO',
                                      'EMAIL',
                                      'WHATSAPP',
                                      'OTHER',
                                    ]
                                        .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t.replaceAll('_', ' '))))
                                        .toList(),
                                    onChanged: isSubmitting
                                        ? null
                                        : (v) => setDialogState(
                                            () => activityType = v ?? 'CALL'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: outcome,
                                    decoration: const InputDecoration(
                                      labelText: 'Outcome *',
                                      prefixIcon: Icon(Icons.flag, size: 18),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'CONNECTED',
                                          child: Text('Connected / Reached')),
                                      DropdownMenuItem(
                                          value: 'NO_ANSWER',
                                          child: Text('No Answer (Auto Callback)')),
                                      DropdownMenuItem(
                                          value: 'BUSY',
                                          child: Text('Busy (Auto Callback)')),
                                      DropdownMenuItem(
                                          value: 'WRONG_NUMBER',
                                          child: Text('Wrong Number')),
                                      DropdownMenuItem(
                                          value: 'INTERESTED',
                                          child: Text('Highly Interested')),
                                      DropdownMenuItem(
                                          value: 'NOT_INTERESTED',
                                          child: Text('Not Interested')),
                                      DropdownMenuItem(
                                          value: 'MEETING_FIXED',
                                          child: Text('Meeting Fixed')),
                                      DropdownMenuItem(
                                          value: 'PO_RECEIVED',
                                          child: Text('PO Received')),
                                      DropdownMenuItem(
                                          value: 'QUOTATION_REQUESTED',
                                          child: Text('Quotation Requested')),
                                      DropdownMenuItem(
                                          value: 'FOLLOW_UP_REQUIRED',
                                          child: Text('Follow-up Required')),
                                      DropdownMenuItem(
                                          value: 'OTHER',
                                          child: Text('Other')),
                                    ],
                                    onChanged: isSubmitting
                                        ? null
                                        : (v) => onOutcomeChanged(v),
                                  ),
                                ),
                              ],
                            ),
                            if (suggestionMessage != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    if (isFetchingSuggestion)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    else
                                      const Icon(Icons.auto_awesome,
                                          size: 16, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        suggestionMessage!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.amberAccent,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: subjectController,
                              decoration: const InputDecoration(
                                labelText: 'Resolution Summary / Subject',
                                prefixIcon: Icon(Icons.short_text, size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: discussionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Actual Discussion & Notes *',
                                hintText:
                                    'What was discussed, customer feedback, next steps decided...',
                                prefixIcon: Icon(Icons.notes, size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (activityType == 'CALL') ...[
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined,
                                      size: 16, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  const Text('Call Duration: ',
                                      style: TextStyle(
                                          fontSize: 13, color: Colors.white70)),
                                  Wrap(
                                    spacing: 6,
                                    children: [30, 60, 180, 300, 600].map((sec) {
                                      final isSelected = callDurationSec == sec;
                                      return ChoiceChip(
                                        label: Text(
                                            '${sec ~/ 60 > 0 ? '${sec ~/ 60}m' : ''} ${sec % 60 > 0 ? '${sec % 60}s' : ''}'
                                                .trim()),
                                        selected: isSelected,
                                        onSelected: isSubmitting
                                            ? null
                                            : (sel) => setDialogState(() =>
                                                callDurationSec = sel ? sec : null),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Attachments & Media Section
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.darkCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_file,
                                          size: 18, color: AppTheme.primary),
                                      const SizedBox(width: 6),
                                      const Text('Attachments & Recordings',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                      const Spacer(),
                                      PopupMenuButton<String>(
                                        tooltip: 'Attach Media or Document',
                                        enabled: !isSubmitting &&
                                            !isUploadingAttachment,
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 20,
                                            color: AppTheme.primary),
                                        onSelected: pickAndUploadAttachment,
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'PHOTO',
                                            child: Row(
                                              children: [
                                                Icon(Icons.photo, size: 18),
                                                SizedBox(width: 8),
                                                Text('Photo / Image'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'AUDIO',
                                            child: Row(
                                              children: [
                                                Icon(Icons.mic, size: 18),
                                                SizedBox(width: 8),
                                                Text('Voice Note / Audio File'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'ANY',
                                            child: Row(
                                              children: [
                                                Icon(Icons.insert_drive_file,
                                                    size: 18),
                                                SizedBox(width: 8),
                                                Text('Document / PDF / Other'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Microphone note: Select an audio recording file (.mp3, .wav, .m4a, .webm). Live mic capture uses audio file selection.',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white54),
                                  ),
                                  if (isUploadingAttachment) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                            uploadStatusMessage ??
                                                'Uploading...',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70)),
                                      ],
                                    ),
                                  ],
                                  if (uploadedAttachments.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: uploadedAttachments.map((att) {
                                        final mediaClass =
                                            att['mediaClass']?.toString() ??
                                                'DOCUMENT';
                                        final name =
                                            att['fileName']?.toString() ??
                                                'File';
                                        IconData iconData =
                                            Icons.insert_drive_file;
                                        if (mediaClass == 'AUDIO') {
                                          iconData = Icons.mic;
                                        } else if (mediaClass == 'IMAGE') {
                                          iconData = Icons.photo;
                                        } else if (mediaClass == 'VIDEO') {
                                          iconData = Icons.videocam;
                                        }

                                        return Chip(
                                          avatar: Icon(iconData, size: 16),
                                          label: Text(name,
                                              style:
                                                  const TextStyle(fontSize: 12)),
                                          deleteIcon: const Icon(Icons.close,
                                              size: 14),
                                          onDeleted: isSubmitting
                                              ? null
                                              : () {
                                                  setDialogState(() {
                                                    uploadedAttachments
                                                        .remove(att);
                                                  });
                                                },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            // Next Follow-up Section
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.darkCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: scheduleNext
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : Colors.white12,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Schedule Next Callback / Follow-up',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      scheduleNext
                                          ? 'Next follow-up will be created atomically'
                                          : 'Opt-out (no further action required)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    value: scheduleNext,
                                    onChanged: isSubmitting
                                        ? null
                                        : (v) => setDialogState(
                                            () => scheduleNext = v),
                                  ),
                                  if (scheduleNext) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: isSubmitting
                                                ? null
                                                : () async {
                                                    final date =
                                                        await showDatePicker(
                                                      context: dialogContext,
                                                      initialDate: nextDate,
                                                      firstDate: DateTime.now(),
                                                      lastDate: DateTime.now().add(
                                                          const Duration(
                                                              days: 3650)),
                                                    );
                                                    if (date == null ||
                                                        !dialogContext.mounted) {
                                                      return;
                                                    }
                                                    final time =
                                                        await showTimePicker(
                                                      context: dialogContext,
                                                      initialTime:
                                                          TimeOfDay.fromDateTime(
                                                              nextDate),
                                                    );
                                                    if (time == null) return;
                                                    setDialogState(() {
                                                      nextDate = DateTime(
                                                        date.year,
                                                        date.month,
                                                        date.day,
                                                        time.hour,
                                                        time.minute,
                                                      );
                                                    });
                                                  },
                                            icon: const Icon(Icons.event,
                                                size: 16),
                                            label: Text(
                                              DateFormat(
                                                      'dd MMM yyyy, hh:mm a')
                                                  .format(nextDate),
                                              style: const TextStyle(
                                                  fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            initialValue: nextActivityType,
                                            decoration: const InputDecoration(
                                              labelText: 'Next Action Type',
                                            ),
                                            items: const [
                                              'CALL',
                                              'MEETING',
                                              'SITE_VISIT',
                                              'DEMO',
                                              'EMAIL',
                                              'WHATSAPP',
                                              'OTHER',
                                            ]
                                                .map((t) => DropdownMenuItem(
                                                    value: t,
                                                    child: Text(t.replaceAll(
                                                        '_', ' '))))
                                                .toList(),
                                            onChanged: isSubmitting
                                                ? null
                                                : (v) => setDialogState(() =>
                                                    nextActivityType =
                                                        v ?? 'CALL'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: nextSubjectController,
                                      decoration: const InputDecoration(
                                        labelText: 'Next Callback Subject',
                                        hintText:
                                            'e.g. Follow-up on technical quotation',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: nextActionController,
                                      decoration: const InputDecoration(
                                        labelText: 'Next Agreed Action',
                                        hintText:
                                            'e.g. Call back GM for pricing confirmation',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            initialValue: nextPriority,
                                            decoration: const InputDecoration(
                                              labelText: 'Priority',
                                            ),
                                            items: const [
                                              'LOW',
                                              'MEDIUM',
                                              'HIGH',
                                              'URGENT',
                                            ]
                                                .map((p) => DropdownMenuItem(
                                                    value: p, child: Text(p)))
                                                .toList(),
                                            onChanged: isSubmitting
                                                ? null
                                                : (v) => setDialogState(() =>
                                                    nextPriority =
                                                        v ?? 'MEDIUM'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FutureBuilder<List<StaffMember>>(
                                            future: staffFuture,
                                            builder: (context, snapshot) {
                                              final staffList =
                                                  snapshot.data ?? const [];
                                              return DropdownButtonFormField<
                                                  StaffMember?>(
                                                initialValue: nextStaff,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText:
                                                      'Reassign (Optional)',
                                                ),
                                                items: [
                                                  const DropdownMenuItem(
                                                    value: null,
                                                    child:
                                                        Text('Keep current'),
                                                  ),
                                                  ...staffList.map((m) =>
                                                      DropdownMenuItem(
                                                        value: m,
                                                        child:
                                                            Text(m.fullName),
                                                      )),
                                                ],
                                                onChanged: isSubmitting
                                                    ? null
                                                    : (v) => setDialogState(
                                                        () => nextStaff = v),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (discussionController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Discussion details are required to resolve follow-up.'),
                                        backgroundColor: AppTheme.error,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSubmitting = true);

                                  final payload = <String, dynamic>{
                                    'activityType': activityType,
                                    'outcome': outcome,
                                    'callOutcome': outcome,
                                    'subject': subjectController.text
                                            .trim()
                                            .isNotEmpty
                                        ? subjectController.text.trim()
                                        : 'Resolved Follow-up: $outcome',
                                    'discussion':
                                        discussionController.text.trim(),
                                    'notes': notesController.text.trim(),
                                    if (callDurationSec != null)
                                      'callDurationSec': callDurationSec,
                                    'scheduleNext': scheduleNext,
                                    if (scheduleNext) ...{
                                      'nextActivityType': nextActivityType,
                                      'nextScheduledDate':
                                          nextDate.toIso8601String(),
                                      if (nextSubjectController.text
                                          .trim()
                                          .isNotEmpty)
                                        'nextSubject':
                                            nextSubjectController.text.trim(),
                                      if (nextActionController.text
                                          .trim()
                                          .isNotEmpty)
                                        'nextAction':
                                            nextActionController.text.trim(),
                                      if (nextNotesController.text
                                          .trim()
                                          .isNotEmpty)
                                        'nextNotes':
                                            nextNotesController.text.trim(),
                                      if (nextStaff != null)
                                        'nextAssignedStaffId': nextStaff!.id,
                                      'nextPriority': nextPriority,
                                    },
                                    if (uploadedAttachments.isNotEmpty)
                                      'attachmentIds': uploadedAttachments
                                          .map((a) => a['id']?.toString() ?? '')
                                          .where((id) => id.isNotEmpty)
                                          .toList(),
                                    'idempotencyKey': idempotencyKey,
                                  };

                                  try {
                                    await ref
                                        .read(crmRepositoryProvider)
                                        .resolveFollowUp(
                                            followUp['id'].toString(), payload);

                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }

                                    await _loadCompanies();
                                    await ref
                                        .read(followUpListProvider.notifier)
                                        .loadFollowUps();

                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(scheduleNext
                                              ? 'Resolved & callback scheduled for ${DateFormat('dd MMM, hh:mm a').format(nextDate)}'
                                              : 'Follow-up resolved successfully.'),
                                          backgroundColor: AppTheme.success,
                                        ),
                                      );
                                    }
                                  } catch (error) {
                                    setDialogState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Resolution error: $error'),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                              isSubmitting ? 'Resolving...' : 'Resolve & Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Schedule Meeting & Follow-up Dialog ───────────────────────────────────────

  void _showScheduleMeetingDialog({Map<String, dynamic>? initialCustomer}) {
    _showUnifiedInteractionDialog(
      initialCustomer: initialCustomer,
      initialType: 'MEETING',
    );
  }

  /// ─── Unified CRM Interaction Workspace Dialog ─────────────────────────────
  /// Consolidates Calls, Follow-ups, Meetings, Site Visits, and Media into ONE single screen.
  void _showUnifiedInteractionDialog({
    Map<String, dynamic>? initialCustomer,
    String? initialType,
    bool initialFocusMedia = false,
  }) {
    ref.read(customerListProvider.notifier).loadCustomers();
    final staffFuture = ref.read(staffRepositoryProvider).getStaffList();

    // Text editing controllers
    final subjectController = TextEditingController();
    final discussionController = TextEditingController();
    final notesController = TextEditingController();
    final phoneCorrectionController = TextEditingController();
    final notInterestedReasonController = TextEditingController();
    final locationController = TextEditingController(
      text: initialCustomer?['city'] != null &&
              initialCustomer!['city'].toString().isNotEmpty
          ? 'Site: ${initialCustomer['city']}'
          : 'Client Site / Office',
    );
    final checklistNotesController = TextEditingController();
    final customerNameController = TextEditingController(
      text: initialCustomer?['companyName']?.toString() ??
          initialCustomer?['name']?.toString() ??
          '',
    );

    // Next action controllers
    final nextSubjectController = TextEditingController();
    final nextActionController = TextEditingController();
    final nextNotesController = TextEditingController();

    // State variables
    String? selectedCustomerId = initialCustomer?['id']?.toString();
    Map<String, dynamic>? currentCustomer = initialCustomer;

    String activityType = (initialType ?? 'CALL').toUpperCase();
    if (![
      'CALL',
      'MEETING',
      'SITE_VISIT',
      'FOLLOW_UP',
      'DEMO',
      'EMAIL',
      'WHATSAPP',
      'OTHER'
    ].contains(activityType)) {
      activityType = 'CALL';
    }

    DateTime interactionDate = DateTime.now();
    StaffMember? selectedStaff;

    // CALL specific state
    String callDirection = 'OUTBOUND';
    int? callDurationSec = 60;
    String callOutcome = 'CONNECTED';
    bool scheduleNext = false;
    DateTime nextDate = DateTime.now().add(const Duration(days: 1));
    String nextActivityType = 'CALL';
    String nextPriority = 'MEDIUM';
    StaffMember? nextStaff;
    bool isFetchingSuggestion = false;
    String? suggestionMessage;
    bool optOutOfCallback = false;

    // MEETING specific state
    String meetingMode = 'CLIENT_SITE';
    DateTime meetingStartTime =
        DateTime.now().add(const Duration(days: 1, hours: 2));
    DateTime meetingEndTime =
        DateTime.now().add(const Duration(days: 1, hours: 3));
    String meetingPriority = 'HIGH';
    StaffMember? hostStaff;

    // SITE VISIT specific state
    int teamSize = 1;
    final List<String> selectedTeamMemberIds = [];
    String voltageReading = '415V 3-Phase';
    String pumpRatingHp = '50';
    String panelDimensions = '1800x800x600 IP55';
    String siteEnvironment = 'Standard Outdoor / Pump House';

    // FOLLOW-UP specific state
    bool scheduleFollowUp = true;
    int? reminderMinutes = 30;
    String followUpPriority = 'MEDIUM';

    // Attachment upload state
    bool isSubmitting = false;
    bool isUploadingAttachment = false;
    String? uploadStatusMessage;
    final List<Map<String, dynamic>> uploadedAttachments = [];
    final idempotencyKey =
        'unified-int-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';

    showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> onCallOutcomeChanged(String? newOutcome) async {
            if (newOutcome == null) return;
            setDialogState(() {
              callOutcome = newOutcome;
            });

            if (newOutcome == 'NO_ANSWER' || newOutcome == 'BUSY') {
              if (optOutOfCallback) return;
              setDialogState(() {
                scheduleNext = true;
                nextActivityType = 'CALL';
                isFetchingSuggestion = true;
                suggestionMessage = 'Fetching automated callback suggestion...';
                if (newOutcome == 'NO_ANSWER') {
                  nextSubjectController.text =
                      'Callback: Customer did not answer call';
                  nextActionController.text =
                      'Retry phone call (Customer was unreachable / No Answer)';
                } else {
                  nextSubjectController.text =
                      'Callback: Phone line was busy';
                  nextActionController.text =
                      'Retry phone call (Customer line was busy)';
                }
              });

              try {
                final suggestion = await ref
                    .read(crmRepositoryProvider)
                    .getCallbackSuggestion();
                final iso = suggestion['suggestedDateIso']?.toString() ??
                    suggestion['suggestedDate']?.toString();
                DateTime parsed = DateTime.now().add(const Duration(days: 1));
                if (iso != null) {
                  parsed = DateTime.tryParse(iso)?.toLocal() ?? parsed;
                }
                final formatted = suggestion['formattedIST'] ??
                    DateFormat('dd MMM yyyy, hh:mm a').format(parsed);

                setDialogState(() {
                  nextDate = parsed;
                  isFetchingSuggestion = false;
                  suggestionMessage =
                      '💡 Automated callback applied: $formatted (${suggestion['dayOfWeek'] ?? 'Next working day'})';
                });
              } catch (_) {
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                final fallbackDate = DateTime(
                    tomorrow.year, tomorrow.month, tomorrow.day, 11, 0);
                setDialogState(() {
                  nextDate = fallbackDate;
                  isFetchingSuggestion = false;
                  suggestionMessage =
                      '💡 Callback scheduled for ${DateFormat('dd MMM yyyy, hh:mm a').format(fallbackDate)}';
                });
              }
            } else if (newOutcome == 'WRONG_NUMBER') {
              setDialogState(() {
                scheduleNext = false;
                suggestionMessage =
                    '⚠️ Invalid Contact / Wrong number noted. Enter corrected phone number below.';
              });
            } else if (newOutcome == 'NOT_INTERESTED') {
              setDialogState(() {
                scheduleNext = false;
                suggestionMessage =
                    'Outcome marked as Not Interested. Provide customer reason below.';
              });
            } else if (newOutcome == 'CALL_BACK_LATER') {
              setDialogState(() {
                scheduleNext = true;
                nextActivityType = 'CALL';
                nextSubjectController.text = 'Follow-up Call Back';
                nextActionController.text = 'Call back as requested by customer';
              });
            } else if (newOutcome == 'MEETING_REQUESTED') {
              setDialogState(() {
                scheduleNext = true;
                nextActivityType = 'MEETING';
                nextSubjectController.text = 'Technical / Commercial Meeting';
                nextActionController.text = 'Conduct client meeting';
              });
            } else if (newOutcome == 'QUOTATION_REQUESTED') {
              setDialogState(() {
                scheduleNext = true;
                nextActivityType = 'FOLLOW_UP';
                nextSubjectController.text = 'Follow-up on Quotation & Specs';
                nextActionController.text =
                    'Share quotation and follow up for approval';
              });
            } else if (newOutcome == 'PO_RECEIVED') {
              setDialogState(() {
                scheduleNext = false;
                suggestionMessage = '🎉 Purchase order received!';
              });
            }
          }

          void pickAndUploadAttachment(String fieldType) {
            pickAndUploadWebFile(
              fieldType: fieldType,
              onFilePicked: (fileName, bytes) async {
                setDialogState(() {
                  isUploadingAttachment = true;
                  uploadStatusMessage = 'Uploading "$fileName"...';
                });

                try {
                  final results = await ref
                      .read(crmRepositoryProvider)
                      .uploadCrmAttachments(
                        files: [(fileName: fileName, bytes: bytes)],
                        customerId: selectedCustomerId,
                        sourceCategory: 'UNIFIED_INTERACTION',
                        description:
                            'Uploaded during $activityType interaction',
                      );

                  setDialogState(() {
                    isUploadingAttachment = false;
                    uploadStatusMessage = null;
                    if (results.isNotEmpty) {
                      uploadedAttachments.addAll(results);
                    } else {
                      uploadedAttachments.add({
                        'id': 'att-${DateTime.now().millisecondsSinceEpoch}',
                        'fileName': fileName,
                        'fileSizeBytes': bytes.length,
                        'mediaClass': fieldType == 'PHOTO'
                            ? 'IMAGE'
                            : (fieldType == 'AUDIO'
                                ? 'AUDIO'
                                : (fieldType == 'VIDEO'
                                    ? 'VIDEO'
                                    : 'DOCUMENT')),
                      });
                    }
                  });
                } catch (e) {
                  setDialogState(() {
                    isUploadingAttachment = false;
                    uploadStatusMessage = 'Upload failed: $e';
                  });
                }
              },
            );
          }

          Future<void> submitInteraction() async {
            if (selectedCustomerId == null || selectedCustomerId!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a company/customer.'),
                  backgroundColor: AppTheme.error,
                ),
              );
              return;
            }

            if (activityType == 'SITE_VISIT') {
              if (selectedTeamMemberIds.length != teamSize) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please select exactly $teamSize team members (currently selected ${selectedTeamMemberIds.length}).',
                    ),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }
            }

            setDialogState(() => isSubmitting = true);

            final repo = ref.read(crmRepositoryProvider);
            final attIds = uploadedAttachments
                .map((a) => a['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();

            try {
              if (activityType == 'CALL') {
                final callPayload = <String, dynamic>{
                  'customerId': selectedCustomerId,
                  'customerName': customerNameController.text.trim(),
                  'callType': callDirection,
                  'callOutcome': callOutcome,
                  'durationSec': callDurationSec ?? 0,
                  'subject': subjectController.text.trim().isNotEmpty
                      ? subjectController.text.trim()
                      : '$callDirection Call - $callOutcome',
                  'notes': discussionController.text.trim().isNotEmpty
                      ? discussionController.text.trim()
                      : notesController.text.trim(),
                  'description': discussionController.text.trim(),
                  'scheduleNext': scheduleNext && !optOutOfCallback,
                  if (scheduleNext && !optOutOfCallback) ...{
                    'nextScheduledDate': nextDate.toIso8601String(),
                    'nextActivityType': nextActivityType,
                    'nextSubject': nextSubjectController.text.trim(),
                    'nextAction': nextActionController.text.trim(),
                    'nextPriority': nextPriority,
                    if (nextStaff != null)
                      'nextAssignedStaffId': nextStaff!.id,
                  },
                  if (attIds.isNotEmpty) 'attachmentIds': attIds,
                  'idempotencyKey': idempotencyKey,
                  if (callOutcome == 'WRONG_NUMBER' &&
                      phoneCorrectionController.text.trim().isNotEmpty)
                    'correctedPhone': phoneCorrectionController.text.trim(),
                  if (callOutcome == 'NOT_INTERESTED' &&
                      notInterestedReasonController.text.trim().isNotEmpty)
                    'lostReason': notInterestedReasonController.text.trim(),
                };
                await repo.createCall(callPayload);
              } else if (activityType == 'MEETING') {
                final meetingPayload = <String, dynamic>{
                  'customerId': selectedCustomerId,
                  'customerName': customerNameController.text.trim(),
                  'hostStaffId': hostStaff?.id ?? selectedStaff?.id,
                  'meetingType': meetingMode.contains('ONLINE')
                      ? 'ONLINE'
                      : 'OFFLINE',
                  'location': locationController.text.trim(),
                  'startTime': meetingStartTime.toIso8601String(),
                  'endTime': meetingEndTime.toIso8601String(),
                  'agenda': subjectController.text.trim().isNotEmpty
                      ? subjectController.text.trim()
                      : 'Client Meeting',
                  'notes': discussionController.text.trim().isNotEmpty
                      ? discussionController.text.trim()
                      : notesController.text.trim(),
                  'priority': meetingPriority,
                  if (attIds.isNotEmpty) 'attachmentIds': attIds,
                  'idempotencyKey': idempotencyKey,
                };
                await repo.createMeeting(meetingPayload);
              } else if (activityType == 'SITE_VISIT') {
                final siteVisitPayload = <String, dynamic>{
                  'customerId': selectedCustomerId,
                  'customerName': customerNameController.text.trim(),
                  'location': locationController.text.trim(),
                  'scheduledDate': interactionDate.toIso8601String(),
                  'visitDate': interactionDate.toIso8601String(),
                  'teamSize': teamSize,
                  'teamMemberIds': selectedTeamMemberIds,
                  'voltageReading': voltageReading,
                  'pumpRatingHp': double.tryParse(pumpRatingHp) ?? 50.0,
                  'panelDimensions': panelDimensions,
                  'siteCondition': siteEnvironment,
                  'inspectionNotes': [
                    if (subjectController.text.trim().isNotEmpty)
                      'Purpose: ${subjectController.text.trim()}',
                    if (discussionController.text.trim().isNotEmpty)
                      'Discussion: ${discussionController.text.trim()}',
                    if (checklistNotesController.text.trim().isNotEmpty)
                      'Checklist: ${checklistNotesController.text.trim()}',
                  ].join('\n'),
                  if (attIds.isNotEmpty) 'attachmentIds': attIds,
                  'idempotencyKey': idempotencyKey,
                };
                await repo.createSiteVisit(siteVisitPayload);
              } else {
                // FOLLOW_UP, DEMO, EMAIL, WHATSAPP, OTHER
                final followUpPayload = <String, dynamic>{
                  'customerId': selectedCustomerId,
                  'activityType': activityType,
                  'mode': scheduleFollowUp ? 'SCHEDULE' : 'COMPLETE_NOW',
                  'subject': subjectController.text.trim().isNotEmpty
                      ? subjectController.text.trim()
                      : activityType.replaceAll('_', ' '),
                  'discussion': discussionController.text.trim().isNotEmpty
                      ? discussionController.text.trim()
                      : 'Recorded via Unified CRM Workspace',
                  'notes': notesController.text.trim(),
                  'priority': followUpPriority,
                  'reminderMinutes':
                      scheduleFollowUp ? reminderMinutes : null,
                  'scheduledDate': scheduleFollowUp
                      ? interactionDate.toIso8601String()
                      : null,
                  'assignedStaffId': selectedStaff?.id,
                  if (attIds.isNotEmpty) 'attachmentIds': attIds,
                  'idempotencyKey': idempotencyKey,
                };
                await repo.createFollowUp(followUpPayload);
              }

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              await _loadCompanies();
              await ref.read(followUpListProvider.notifier).loadFollowUps();

              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ ${activityType.replaceAll('_', ' ')} recorded successfully! '
                      '${activityType == 'SITE_VISIT' ? 'Linked tasks created for all $teamSize team members.' : (activityType == 'MEETING' ? 'Linked task created for meeting host.' : '')}',
                    ),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            } catch (e) {
              setDialogState(() => isSubmitting = false);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save interaction: $e'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            }
          }

          return Dialog(
            backgroundColor: AppTheme.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.darkBorder),
            ),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 720, maxHeight: 860),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.sync_alt,
                            color: AppTheme.primary, size: 24),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unified CRM Interaction',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              Text(
                                'Calls • Follow-ups • Meetings • Site Visits',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(color: AppTheme.darkBorder, height: 16),

                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Company / Customer Selector
                            if (selectedCustomerId != null &&
                                currentCustomer != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.business,
                                        color: AppTheme.primary, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            currentCustomer!['companyName']
                                                    ?.toString() ??
                                                'Customer',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                          ),
                                          Text(
                                            '${currentCustomer!['contactPerson'] ?? ''}  ·  ${currentCustomer!['phone'] ?? ''}  ·  ${currentCustomer!['city'] ?? ''}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => setDialogState(() {
                                        selectedCustomerId = null;
                                        currentCustomer = null;
                                      }),
                                      icon: const Icon(Icons.swap_horiz,
                                          size: 16),
                                      label: const Text('Change'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Consumer(
                                builder: (context, ref, _) {
                                  final customersState =
                                      ref.watch(customerListProvider);
                                  final customers = customersState.customers;
                                  return DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Select Company / Customer *',
                                      prefixIcon: Icon(Icons.business),
                                    ),
                                    isExpanded: true,
                                    initialValue: selectedCustomerId,
                                    items: customers.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(
                                            '${c.companyName} (${c.customerCode})',
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final match = customers
                                            .firstWhere((c) => c.id == val);
                                        setDialogState(() {
                                          selectedCustomerId = val;
                                          currentCustomer = {
                                            'id': match.id,
                                            'companyName': match.companyName,
                                            'phone': match.phone,
                                            'email': match.email,
                                            'contactPerson':
                                                match.contactPerson,
                                            'city': match.city,
                                          };
                                          customerNameController.text =
                                              match.companyName;
                                          if (match.city != null &&
                                              match.city!.isNotEmpty) {
                                            locationController.text =
                                                'Site: ${match.city}';
                                          }
                                        });
                                      }
                                    },
                                  );
                                },
                              ),
                            const SizedBox(height: 12),

                            // Activity Type Switcher
                            const Text(
                              'Interaction Type *',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ('CALL', '📞 Call', Icons.phone_in_talk),
                                  ('MEETING', '🤝 Meeting', Icons.calendar_month),
                                  ('SITE_VISIT', '🏗️ Site Visit', Icons.engineering),
                                  ('FOLLOW_UP', '⏱️ Follow-up', Icons.assignment_turned_in),
                                  ('DEMO', '💻 Demo', Icons.laptop_chromebook),
                                  ('EMAIL', '✉️ Email', Icons.email_outlined),
                                  ('WHATSAPP', '💬 WhatsApp', Icons.chat),
                                  ('OTHER', '📝 Other', Icons.more_horiz),
                                ].map((item) {
                                  final isSel = activityType == item.$1;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(item.$2),
                                      selected: isSel,
                                      selectedColor: AppTheme.primary,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setDialogState(
                                              () => activityType = item.$1);
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Date, Time & Employee Row
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final date = await showDatePicker(
                                        context: dialogContext,
                                        initialDate: interactionDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now()
                                            .add(const Duration(days: 365)),
                                      );
                                      if (date == null ||
                                          !dialogContext.mounted) return;
                                      final time = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: TimeOfDay.fromDateTime(
                                            interactionDate),
                                      );
                                      if (time == null) return;
                                      setDialogState(() {
                                        interactionDate = DateTime(
                                          date.year,
                                          date.month,
                                          date.day,
                                          time.hour,
                                          time.minute,
                                        );
                                      });
                                    },
                                    icon: const Icon(Icons.event, size: 16),
                                    label: Text(
                                      DateFormat('dd MMM yyyy, hh:mm a')
                                          .format(interactionDate),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FutureBuilder<List<StaffMember>>(
                                    future: staffFuture,
                                    builder: (context, snapshot) {
                                      final staffList =
                                          snapshot.data ?? const [];
                                      return DropdownButtonFormField<
                                          StaffMember?>(
                                        initialValue: selectedStaff,
                                        decoration: const InputDecoration(
                                          labelText: 'Assigned Staff',
                                          prefixIcon:
                                              Icon(Icons.person_outline, size: 18),
                                        ),
                                        isExpanded: true,
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('Current Staff / Me'),
                                          ),
                                          ...staffList.map((m) =>
                                              DropdownMenuItem(
                                                value: m,
                                                child: Text(m.fullName,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              )),
                                        ],
                                        onChanged: (v) => setDialogState(
                                            () => selectedStaff = v),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Purpose / Subject
                            TextField(
                              controller: subjectController,
                              decoration: InputDecoration(
                                labelText: activityType == 'MEETING'
                                    ? 'Meeting Agenda / Subject *'
                                    : (activityType == 'SITE_VISIT'
                                        ? 'Site Visit Purpose *'
                                        : 'Purpose / Subject *'),
                                hintText:
                                    'e.g. 75HP VFD Solar Pump Specifications Discussion',
                                prefixIcon:
                                    const Icon(Icons.subject, size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Discussion Notes
                            TextField(
                              controller: discussionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Discussion Notes & Key Points *',
                                hintText:
                                    'Record what was discussed, customer reaction, commitments made...',
                                prefixIcon: const Icon(Icons.notes, size: 18),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ─── PROGRESSIVE DISCLOSURE: CALL ──────────────
                            if (activityType == 'CALL') ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Call Conversation & Outcome',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.primary)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Text('Direction: ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70)),
                                        ChoiceChip(
                                          label: const Text('Outgoing'),
                                          selected: callDirection == 'OUTBOUND',
                                          onSelected: (v) => setDialogState(
                                              () => callDirection = 'OUTBOUND'),
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('Incoming'),
                                          selected: callDirection == 'INBOUND',
                                          onSelected: (v) => setDialogState(
                                              () => callDirection = 'INBOUND'),
                                        ),
                                        const Spacer(),
                                        const Text('Duration: ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70)),
                                        ...[30, 60, 180, 300, 600].map((sec) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                left: 4),
                                            child: ChoiceChip(
                                              label: Text(sec < 60
                                                  ? '${sec}s'
                                                  : '${sec ~/ 60}m'),
                                              selected:
                                                  callDurationSec == sec,
                                              onSelected: (sel) =>
                                                  setDialogState(() =>
                                                      callDurationSec =
                                                          sel ? sec : null),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Call Outcome Dropdown
                                    DropdownButtonFormField<String>(
                                      initialValue: callOutcome,
                                      decoration: const InputDecoration(
                                        labelText: 'Call Outcome *',
                                        prefixIcon:
                                            Icon(Icons.flag_outlined, size: 18),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'CONNECTED',
                                            child: Text(
                                                'Connected — customer answered')),
                                        DropdownMenuItem(
                                            value: 'NO_ANSWER',
                                            child: Text(
                                                'No Answer (Automated Callback Suggestion)')),
                                        DropdownMenuItem(
                                            value: 'BUSY',
                                            child: Text(
                                                'Busy (Automated Callback Suggestion)')),
                                        DropdownMenuItem(
                                            value: 'WRONG_NUMBER',
                                            child: Text(
                                                'Wrong Number / Invalid Contact')),
                                        DropdownMenuItem(
                                            value: 'INTERESTED',
                                            child: Text('Interested')),
                                        DropdownMenuItem(
                                            value: 'NOT_INTERESTED',
                                            child: Text('Not Interested')),
                                        DropdownMenuItem(
                                            value: 'CALL_BACK_LATER',
                                            child: Text('Call Back Later')),
                                        DropdownMenuItem(
                                            value: 'MEETING_REQUESTED',
                                            child:
                                                Text('Meeting Requested')),
                                        DropdownMenuItem(
                                            value: 'QUOTATION_REQUESTED',
                                            child:
                                                Text('Quotation Requested')),
                                        DropdownMenuItem(
                                            value: 'PO_RECEIVED',
                                            child: Text(
                                                'Purchase Order Received')),
                                        DropdownMenuItem(
                                            value: 'OTHER',
                                            child: Text('Other')),
                                      ],
                                      onChanged: (v) =>
                                          onCallOutcomeChanged(v),
                                    ),

                                    if (suggestionMessage != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.amber
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: Colors.amber
                                                  .withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          children: [
                                            if (isFetchingSuggestion)
                                              const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                            else
                                              const Icon(Icons.auto_awesome,
                                                  size: 16,
                                                  color: Colors.amber),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                suggestionMessage!,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.amberAccent,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Conditional: Wrong number phone correction
                                    if (callOutcome == 'WRONG_NUMBER') ...[
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller:
                                            phoneCorrectionController,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Correct Contact Phone Number',
                                          hintText:
                                              'Enter verified 10-digit mobile number',
                                          prefixIcon: Icon(Icons.phone_iphone,
                                              size: 18),
                                        ),
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ],

                                    // Conditional: Not Interested Reason
                                    if (callOutcome == 'NOT_INTERESTED') ...[
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller:
                                            notInterestedReasonController,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Reason for Not Interested',
                                          hintText:
                                              'e.g. Price too high, chose competitor, no budget',
                                          prefixIcon: Icon(Icons.info_outline,
                                              size: 18),
                                        ),
                                      ),
                                    ],

                                    // Conditional: No Answer / Busy Opt-out
                                    if (callOutcome == 'NO_ANSWER' ||
                                        callOutcome == 'BUSY') ...[
                                      const SizedBox(height: 6),
                                      CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: const Text(
                                          'Opt-out: Do not schedule another callback',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        value: optOutOfCallback,
                                        onChanged: (val) {
                                          setDialogState(() {
                                            optOutOfCallback = val ?? false;
                                            if (optOutOfCallback) {
                                              scheduleNext = false;
                                            }
                                          });
                                        },
                                      ),
                                    ],

                                    // Connected next-action selection
                                    if (callOutcome == 'CONNECTED') ...[
                                      const SizedBox(height: 10),
                                      const Text(
                                          'Agreed Next Action with Customer:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          ActionChip(
                                            avatar: const Icon(
                                                Icons.phone_callback,
                                                size: 14),
                                            label: const Text('Call Back'),
                                            onPressed: () =>
                                                setDialogState(() {
                                              scheduleNext = true;
                                              nextActivityType = 'CALL';
                                              nextSubjectController.text =
                                                  'Follow-up Call Back';
                                              nextActionController.text =
                                                  'Follow-up as agreed during conversation';
                                            }),
                                          ),
                                          ActionChip(
                                            avatar: const Icon(
                                                Icons.calendar_month,
                                                size: 14),
                                            label:
                                                const Text('Schedule Meeting'),
                                            onPressed: () =>
                                                setDialogState(() {
                                              scheduleNext = true;
                                              nextActivityType = 'MEETING';
                                              nextSubjectController.text =
                                                  'Meeting with Client';
                                              nextActionController.text =
                                                  'Conduct technical/commercial meeting';
                                            }),
                                          ),
                                          ActionChip(
                                            avatar: const Icon(
                                                Icons.engineering,
                                                size: 14),
                                            label:
                                                const Text('Arrange Site Visit'),
                                            onPressed: () =>
                                                setDialogState(() {
                                              scheduleNext = true;
                                              nextActivityType = 'SITE_VISIT';
                                              nextSubjectController.text =
                                                  'Engineering Site Visit';
                                              nextActionController.text =
                                                  'Visit site for measurement and inspection';
                                            }),
                                          ),
                                          ActionChip(
                                            avatar: const Icon(
                                                Icons.request_quote,
                                                size: 14),
                                            label:
                                                const Text('Send Quotation'),
                                            onPressed: () =>
                                                setDialogState(() {
                                              scheduleNext = true;
                                              nextActivityType = 'FOLLOW_UP';
                                              nextSubjectController.text =
                                                  'Send Quotation & Specs';
                                              nextActionController.text =
                                                  'Share detailed panel quotation';
                                            }),
                                          ),
                                          ActionChip(
                                            avatar: const Icon(Icons.done_all,
                                                size: 14),
                                            label: const Text(
                                                'No Further Action'),
                                            onPressed: () =>
                                                setDialogState(() {
                                              scheduleNext = false;
                                            }),
                                          ),
                                        ],
                                      ),
                                    ],

                                    // Next Scheduled Action Details
                                    if (scheduleNext &&
                                        !optOutOfCallback) ...[
                                      const Divider(height: 20),
                                      const Text(
                                        'Next Scheduled Action Details',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.amberAccent),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                final date =
                                                    await showDatePicker(
                                                  context: dialogContext,
                                                  initialDate: nextDate,
                                                  firstDate: DateTime.now(),
                                                  lastDate: DateTime.now()
                                                      .add(const Duration(
                                                          days: 3650)),
                                                );
                                                if (date == null ||
                                                    !dialogContext.mounted) {
                                                  return;
                                                }
                                                final time =
                                                    await showTimePicker(
                                                  context: dialogContext,
                                                  initialTime:
                                                      TimeOfDay.fromDateTime(
                                                          nextDate),
                                                );
                                                if (time == null) return;
                                                setDialogState(() {
                                                  nextDate = DateTime(
                                                    date.year,
                                                    date.month,
                                                    date.day,
                                                    time.hour,
                                                    time.minute,
                                                  );
                                                });
                                              },
                                              icon: const Icon(Icons.event,
                                                  size: 16),
                                              label: Text(
                                                DateFormat(
                                                        'dd MMM yyyy, hh:mm a')
                                                    .format(nextDate),
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              initialValue: nextActivityType,
                                              decoration: const InputDecoration(
                                                labelText: 'Next Action Type',
                                              ),
                                              items: const [
                                                'CALL',
                                                'MEETING',
                                                'SITE_VISIT',
                                                'DEMO',
                                                'FOLLOW_UP',
                                                'OTHER',
                                              ]
                                                  .map((t) => DropdownMenuItem(
                                                      value: t,
                                                      child: Text(t.replaceAll(
                                                          '_', ' '))))
                                                  .toList(),
                                              onChanged: (v) => setDialogState(
                                                  () => nextActivityType =
                                                      v ?? 'CALL'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: nextSubjectController,
                                        decoration: const InputDecoration(
                                          labelText: 'Next Action Subject',
                                          hintText:
                                              'e.g. Quotation follow-up with Purchase Head',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: nextActionController,
                                        decoration: const InputDecoration(
                                          labelText: 'Specific Next Action',
                                          hintText:
                                              'e.g. Call back GM to confirm order approval',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ─── PROGRESSIVE DISCLOSURE: MEETING ───────────
                            if (activityType == 'MEETING') ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Meeting Scheduling & Details',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.primary)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Text('Mode: ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70)),
                                        ChoiceChip(
                                          label: const Text('Client Site'),
                                          selected:
                                              meetingMode == 'CLIENT_SITE',
                                          onSelected: (v) => setDialogState(
                                              () => meetingMode = 'CLIENT_SITE'),
                                        ),
                                        const SizedBox(width: 6),
                                        ChoiceChip(
                                          label: const Text('Office'),
                                          selected: meetingMode == 'OFFICE',
                                          onSelected: (v) => setDialogState(
                                              () => meetingMode = 'OFFICE'),
                                        ),
                                        const SizedBox(width: 6),
                                        ChoiceChip(
                                          label: const Text('Google Meet'),
                                          selected: meetingMode ==
                                              'ONLINE_GOOGLE_MEET',
                                          onSelected: (v) => setDialogState(() =>
                                              meetingMode =
                                                  'ONLINE_GOOGLE_MEET'),
                                        ),
                                        const SizedBox(width: 6),
                                        ChoiceChip(
                                          label: const Text('Zoom'),
                                          selected:
                                              meetingMode == 'ONLINE_ZOOM',
                                          onSelected: (v) => setDialogState(
                                              () => meetingMode =
                                                  'ONLINE_ZOOM'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: locationController,
                                      decoration: InputDecoration(
                                        labelText: meetingMode.contains('ONLINE')
                                            ? 'Meeting Link / Room ID'
                                            : 'Location / Venue Address',
                                        prefixIcon: Icon(
                                            meetingMode.contains('ONLINE')
                                                ? Icons.link
                                                : Icons.place,
                                            size: 18),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () async {
                                              final date = await showDatePicker(
                                                context: dialogContext,
                                                initialDate: meetingStartTime,
                                                firstDate: DateTime.now(),
                                                lastDate: DateTime.now().add(
                                                    const Duration(days: 365)),
                                              );
                                              if (date == null ||
                                                  !dialogContext.mounted) {
                                                return;
                                              }
                                              final time = await showTimePicker(
                                                context: dialogContext,
                                                initialTime:
                                                    TimeOfDay.fromDateTime(
                                                        meetingStartTime),
                                              );
                                              if (time == null) return;
                                              setDialogState(() {
                                                meetingStartTime = DateTime(
                                                  date.year,
                                                  date.month,
                                                  date.day,
                                                  time.hour,
                                                  time.minute,
                                                );
                                                meetingEndTime =
                                                    meetingStartTime.add(
                                                        const Duration(
                                                            hours: 1));
                                              });
                                            },
                                            icon: const Icon(Icons.access_time,
                                                size: 16),
                                            label: Text(
                                              'Start: ${DateFormat('dd MMM, hh:mm a').format(meetingStartTime)}',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FutureBuilder<
                                              List<StaffMember>>(
                                            future: staffFuture,
                                            builder: (context, snapshot) {
                                              final staffList =
                                                  snapshot.data ?? const [];
                                              return DropdownButtonFormField<
                                                  StaffMember?>(
                                                initialValue: hostStaff,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Meeting Host',
                                                  prefixIcon: Icon(
                                                      Icons.person_pin,
                                                      size: 18),
                                                ),
                                                isExpanded: true,
                                                items: staffList
                                                    .map((m) =>
                                                        DropdownMenuItem(
                                                          value: m,
                                                          child: Text(
                                                              m.fullName,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis),
                                                        ))
                                                    .toList(),
                                                onChanged: (v) => setDialogState(
                                                    () => hostStaff = v),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.blue
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.info_outline,
                                              size: 16,
                                              color: Colors.blueAccent),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'ℹ️ Task Integration: A task will automatically be created and assigned to the host in their Tasks / My Work modules.',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white70),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ─── PROGRESSIVE DISCLOSURE: SITE VISIT ────────
                            if (activityType == 'SITE_VISIT') ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                        'Engineering Site Visit & Team Assignment',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.primary)),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: locationController,
                                      decoration: const InputDecoration(
                                        labelText: 'Site Location / Address *',
                                        prefixIcon:
                                            Icon(Icons.place, size: 18),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Team Size Selector
                                    Row(
                                      children: [
                                        const Text('Team Size: ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        ...[1, 2, 3, 4, 5].map((size) {
                                          final isSel = teamSize == size;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                right: 6),
                                            child: ChoiceChip(
                                              label: Text('$size member${size > 1 ? 's' : ''}'),
                                              selected: isSel,
                                              onSelected: (sel) {
                                                if (sel) {
                                                  setDialogState(() {
                                                    teamSize = size;
                                                  });
                                                }
                                              },
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Team Member Multi-Selector
                                    Row(
                                      children: [
                                        Text(
                                          'Select Team Members (${selectedTeamMemberIds.length} of $teamSize selected):',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: selectedTeamMemberIds
                                                        .length ==
                                                    teamSize
                                                ? AppTheme.success
                                                    .withValues(alpha: 0.2)
                                                : AppTheme.error
                                                    .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            selectedTeamMemberIds.length ==
                                                    teamSize
                                                ? '✓ Count Matches'
                                                : '⚠️ Select $teamSize member${teamSize > 1 ? 's' : ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: selectedTeamMemberIds
                                                          .length ==
                                                      teamSize
                                                  ? AppTheme.success
                                                  : AppTheme.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    FutureBuilder<List<StaffMember>>(
                                      future: staffFuture,
                                      builder: (context, snapshot) {
                                        final staffList =
                                            snapshot.data ?? const [];
                                        return Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: staffList.map((m) {
                                            final isAssigned =
                                                selectedTeamMemberIds
                                                    .contains(m.id);
                                            return FilterChip(
                                              avatar: Icon(
                                                isAssigned
                                                    ? Icons.check
                                                    : Icons.person_outline,
                                                size: 14,
                                                color: isAssigned
                                                    ? Colors.white
                                                    : Colors.white70,
                                              ),
                                              label: Text(m.fullName),
                                              selected: isAssigned,
                                              selectedColor: AppTheme.primary,
                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  if (selected) {
                                                    if (!selectedTeamMemberIds
                                                        .contains(m.id)) {
                                                      selectedTeamMemberIds
                                                          .add(m.id);
                                                    }
                                                  } else {
                                                    selectedTeamMemberIds
                                                        .remove(m.id);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Engineering Checklist
                                    const Text(
                                        'Engineering Checklist & Measurements',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white70)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                            initialValue: voltageReading,
                                            decoration: const InputDecoration(
                                              labelText: 'Supply Voltage',
                                            ),
                                            items: const [
                                              '415V 3-Phase',
                                              '230V 1-Phase',
                                              '480V 3-Phase',
                                              '11kV HT Supply',
                                              'Solar DC Supply',
                                            ]
                                                .map((v) => DropdownMenuItem(
                                                    value: v, child: Text(v)))
                                                .toList(),
                                            onChanged: (v) => setDialogState(
                                                () => voltageReading =
                                                    v ?? '415V 3-Phase'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            decoration: const InputDecoration(
                                              labelText: 'Pump / Motor HP',
                                              hintText: 'e.g. 50 HP',
                                            ),
                                            onChanged: (v) =>
                                                pumpRatingHp = v,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Panel Dimensions (W x H x D)',
                                              hintText:
                                                  'e.g. 1800 x 800 x 600 mm',
                                            ),
                                            onChanged: (v) =>
                                                panelDimensions = v,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                            initialValue: siteEnvironment,
                                            decoration: const InputDecoration(
                                              labelText: 'Site Environment',
                                            ),
                                            items: const [
                                              'Standard Outdoor / Pump House',
                                              'Indoor Control Room',
                                              'High Dust / Desert Conditions',
                                              'Coastal / Corrosive Atmosphere',
                                              'Underground / Submersible Pit',
                                            ]
                                                .map((e) => DropdownMenuItem(
                                                    value: e, child: Text(e)))
                                                .toList(),
                                            onChanged: (v) => setDialogState(
                                                () => siteEnvironment = v ??
                                                    'Standard Outdoor'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: checklistNotesController,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Required Equipment & Checklist Notes',
                                        hintText:
                                            'e.g. Multimeter, clamp meter, safety harness, earthing check',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.green
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.task_alt,
                                              size: 16,
                                              color: Colors.greenAccent),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'ℹ️ Task Integration: Upon saving, individual Tasks will be created automatically for all $teamSize team members in Tasks / My Work.',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white70),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ─── PROGRESSIVE DISCLOSURE: FOLLOW-UP ────────
                            if (activityType == 'FOLLOW_UP' ||
                                activityType == 'DEMO' ||
                                activityType == 'EMAIL' ||
                                activityType == 'WHATSAPP' ||
                                activityType == 'OTHER') ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Complete Now'),
                                          selected: !scheduleFollowUp,
                                          onSelected: (v) => setDialogState(
                                              () => scheduleFollowUp = false),
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text(
                                              'Schedule for Later'),
                                          selected: scheduleFollowUp,
                                          onSelected: (v) => setDialogState(
                                              () => scheduleFollowUp = true),
                                        ),
                                        const Spacer(),
                                        DropdownButton<String>(
                                          value: followUpPriority,
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'LOW',
                                                child: Text('Priority: Low')),
                                            DropdownMenuItem(
                                                value: 'MEDIUM',
                                                child:
                                                    Text('Priority: Medium')),
                                            DropdownMenuItem(
                                                value: 'HIGH',
                                                child: Text('Priority: High')),
                                            DropdownMenuItem(
                                                value: 'URGENT',
                                                child:
                                                    Text('Priority: Urgent')),
                                          ],
                                          onChanged: (v) => setDialogState(
                                              () => followUpPriority =
                                                  v ?? 'MEDIUM'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ─── CUSTOMER MEDIA & ATTACHMENTS ──────────────
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.darkCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_file,
                                          size: 18, color: AppTheme.primary),
                                      const SizedBox(width: 6),
                                      const Text('Customer Media & Attachments',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                      const Spacer(),
                                      PopupMenuButton<String>(
                                        tooltip: 'Attach Media or Document',
                                        enabled: !isSubmitting &&
                                            !isUploadingAttachment,
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 20,
                                            color: AppTheme.primary),
                                        onSelected: pickAndUploadAttachment,
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'PHOTO',
                                            child: Row(
                                              children: [
                                                Icon(Icons.photo, size: 18),
                                                SizedBox(width: 8),
                                                Text('Photo / Image'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'AUDIO',
                                            child: Row(
                                              children: [
                                                Icon(Icons.mic, size: 18),
                                                SizedBox(width: 8),
                                                Text(
                                                    'Voice Note / Audio File'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'VIDEO',
                                            child: Row(
                                              children: [
                                                Icon(Icons.videocam, size: 18),
                                                SizedBox(width: 8),
                                                Text('Video File (up to 50MB)'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'ANY',
                                            child: Row(
                                              children: [
                                                Icon(Icons.insert_drive_file,
                                                    size: 18),
                                                SizedBox(width: 8),
                                                Text('Document / PDF / Quote'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '💡 Live microphone recording: Select or attach audio file/voice note. Video upload supported up to 50MB.',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white54),
                                  ),
                                  if (isUploadingAttachment) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          uploadStatusMessage ?? 'Uploading...',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.amberAccent),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (uploadedAttachments.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: uploadedAttachments.map((att) {
                                        final mediaClass = att['mediaClass']
                                                ?.toString() ??
                                            'DOCUMENT';
                                        final fileName = att['fileName']
                                                ?.toString() ??
                                            'File';
                                        final attId =
                                            att['id']?.toString() ?? '';
                                        IconData icon = Icons.insert_drive_file;
                                        if (mediaClass == 'AUDIO') {
                                          icon = Icons.mic;
                                        } else if (mediaClass == 'IMAGE') {
                                          icon = Icons.photo;
                                        } else if (mediaClass == 'VIDEO') {
                                          icon = Icons.videocam;
                                        }

                                        return ActionChip(
                                          avatar: Icon(icon,
                                              size: 14,
                                              color: AppTheme.primary),
                                          label: Text(fileName,
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                          onPressed: () {
                                            if (attId.isNotEmpty) {
                                              openWebUrl(
                                                  '${AppConstants.baseUrl}/crm/attachments/$attId/stream');
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dialog Actions Footer
                    Row(
                      children: [
                        TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: isSubmitting ? null : submitInteraction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            isSubmitting
                                ? 'Saving...'
                                : 'Save ${activityType.replaceAll('_', ' ')} Interaction',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }
}
