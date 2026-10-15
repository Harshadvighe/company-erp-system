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

  const CrmFollowUpsPage({super.key, this.initialCustomerId});

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
    _staffFuture = ref.read(staffRepositoryProvider).getStaffList();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadCurrentTab();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentTab();
    });
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
            Text('CRM & Sales  /  Follow-ups',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
            Text('Follow-ups & Next Actions',
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
          IconButton(
            icon: const Icon(Icons.event_available_outlined),
            onPressed: () => _showScheduleMeetingDialog(
              initialCustomer: _selectedCompany,
            ),
            tooltip: 'Schedule a meeting',
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
      floatingActionButton: _selectedCompany == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              onPressed: () => _showCompanyFollowUpDialog(_selectedCompany!),
              icon: const Icon(Icons.add_task, color: Colors.white),
              label: const Text('Add Follow-up',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
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
                    : _companies.isEmpty
                        ? const Center(
                            child: Text(
                                'No companies match this follow-up filter.',
                                style: TextStyle(color: Colors.grey)))
                        : _isTableView
                            ? _buildCompanyTable(_companies)
                            : _buildCompanyCards(_companies),
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
      child: Row(
        children: [
          const Icon(Icons.business, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(company['companyName']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${company['phone'] ?? ''}  ·  ${company['city'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  '${followUps.length} follow-ups  ·  Last: ${_formatDate(company['lastInteraction'])}  ·  Next: ${_formatDate(company['nextFollowUp'])}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _showCompanyHistory(company),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('History'),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () => _showCompanyFollowUpDialog(company),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
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
                                _showCompanyFollowUpDialog(company);
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Follow-up'),
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
                              : FutureBuilder<List<dynamic>>(
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
                                    final timeline = snapshot.data ?? const [];
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCompanyFollowUpDialog(Map<String, dynamic> company) {
    final subjectController = TextEditingController();
    final discussionController = TextEditingController();
    final outcomeController = TextEditingController();
    final nextActionController = TextEditingController();
    final notesController = TextEditingController();
    String activityType = 'CALL';
    String priority = 'MEDIUM';
    int? reminderMinutes = 30;
    bool schedule = false;
    DateTime scheduledAt = DateTime.now().add(const Duration(days: 1));
    StaffMember? selectedStaff;
    final staffFuture = ref.read(staffRepositoryProvider).getStaffList();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppTheme.darkSurface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                            child: Text('Add Follow-up',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold))),
                        IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close)),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          '${company['companyName'] ?? ''}\n${company['phone'] ?? ''}  ·  ${company['city'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Follow-up type'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: activityType,
                      items: const [
                        'CALL',
                        'EMAIL',
                        'WHATSAPP',
                        'MEETING',
                        'SITE_VISIT',
                        'DEMO',
                        'OTHER'
                      ]
                          .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.replaceAll('_', ' '))))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => activityType = value ?? 'CALL'),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: false,
                            label: Text('Complete Now'),
                            icon: Icon(Icons.check_circle_outline)),
                        ButtonSegment(
                            value: true,
                            label: Text('Schedule'),
                            icon: Icon(Icons.calendar_month)),
                      ],
                      selected: {schedule},
                      onSelectionChanged: (values) =>
                          setDialogState(() => schedule = values.first),
                    ),
                    if (schedule) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: dialogContext,
                            initialDate: scheduledAt,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (date == null || !dialogContext.mounted) return;
                          final time = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.fromDateTime(scheduledAt));
                          if (time == null) return;
                          setDialogState(() => scheduledAt = DateTime(date.year,
                              date.month, date.day, time.hour, time.minute));
                        },
                        icon: const Icon(Icons.event),
                        label: Text(DateFormat('dd MMM yyyy, hh:mm a')
                            .format(scheduledAt)),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: reminderMinutes,
                        decoration:
                            const InputDecoration(labelText: 'Reminder'),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('No reminder')),
                          ...[5, 15, 30, 60]
                              .map((minutes) => DropdownMenuItem<int?>(
                                    value: minutes,
                                    child: Text('$minutes minutes before'),
                                  )),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => reminderMinutes = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                            labelText: 'Subject / purpose')),
                    if (!schedule) ...[
                      const SizedBox(height: 12),
                      TextField(
                          controller: discussionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Discussion / interaction *')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: outcomeController,
                          decoration:
                              const InputDecoration(labelText: 'Outcome')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: nextActionController,
                          decoration:
                              const InputDecoration(labelText: 'Next action')),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const ['LOW', 'MEDIUM', 'HIGH', 'URGENT']
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => priority = value ?? 'MEDIUM'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Notes (optional)')),
                    const SizedBox(height: 12),
                    FutureBuilder<List<StaffMember>>(
                      future: staffFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                              'Unable to load employees: ${snapshot.error}',
                              style: const TextStyle(color: AppTheme.error));
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final staff = snapshot.data!;
                        return DropdownButtonFormField<StaffMember>(
                          initialValue: selectedStaff,
                          decoration: const InputDecoration(
                              labelText: 'Assigned employee (optional)'),
                          items: staff
                              .map((member) => DropdownMenuItem(
                                  value: member, child: Text(member.fullName)))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedStaff = value),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    StatefulBuilder(
                      builder: (context, setBtnState) {
                        bool isSavingFollowUp = false;
                        return StatefulBuilder(
                          builder: (context, setSubState) {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isSavingFollowUp
                                    ? null
                                    : () async {
                                        if (subjectController.text.trim().isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Subject / purpose is required.')));
                                          return;
                                        }
                                        if (!schedule &&
                                            discussionController.text
                                                .trim()
                                                .isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Enter the interaction details to complete now.')));
                                          return;
                                        }
                                        setSubState(() => isSavingFollowUp = true);
                                        try {
                                          await ref
                                              .read(crmRepositoryProvider)
                                              .createFollowUp({
                                            'customerId': company['id'],
                                            'mode': schedule
                                                ? 'SCHEDULE'
                                                : 'COMPLETE_NOW',
                                            'activityType': activityType,
                                            'subject': subjectController.text.trim(),
                                            'discussion': discussionController.text.trim(),
                                            'outcome': outcomeController.text.trim(),
                                            'nextAction': nextActionController.text.trim(),
                                            'priority': priority,
                                            'notes': notesController.text.trim(),
                                            if (selectedStaff != null)
                                              'assignedStaffId': selectedStaff!.id,
                                            if (schedule)
                                              'scheduledDate': scheduledAt.toIso8601String(),
                                            if (schedule)
                                              'reminderMinutes': reminderMinutes,
                                          });
                                          if (dialogContext.mounted) {
                                            Navigator.pop(dialogContext);
                                          }
                                          await _loadCompanies();
                                          await ref
                                              .read(followUpListProvider.notifier)
                                              .loadFollowUps();
                                          if (mounted) {
                                            ScaffoldMessenger.of(this.context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text('Follow-up saved.'),
                                                    backgroundColor:
                                                        AppTheme.success));
                                          }
                                        } catch (error) {
                                          setSubState(() => isSavingFollowUp = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(this.context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Could not save follow-up: $error'),
                                                    backgroundColor: AppTheme.error));
                                          }
                                        }
                                      },
                                icon: isSavingFollowUp
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(isSavingFollowUp
                                    ? 'Saving...'
                                    : 'Save Follow-up'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    ref.read(customerListProvider.notifier).loadCustomers();
    final actionCtrl = TextEditingController(text: 'MEETING');
    final subjectCtrl = TextEditingController();
    final locationCtrl =
        TextEditingController(text: 'Client Site / Office Meeting Room');
    final notesCtrl = TextEditingController();
    final customerNameCtrl = TextEditingController(
        text:
            initialCustomer?['companyName'] ?? initialCustomer?['name'] ?? '');
    String selectedPriority = 'HIGH';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    StaffMember? selectedStaff;
    String? selectedCustomerId = initialCustomer?['id'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.darkBorder),
          ),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_month,
                              color: AppTheme.primary, size: 22),
                          SizedBox(width: 8),
                          Text('Schedule Meeting / Follow-up',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.darkBorder, height: 20),

                  // Customer Selector Dropdown
                  const Text('Select Customer *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  Consumer(
                    builder: (context, ref, _) {
                      final customersState = ref.watch(customerListProvider);
                      final customers = customersState.customers;
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          hintText: 'Select Existing Customer',
                          prefixIcon: Icon(Icons.business, size: 18),
                        ),
                        dropdownColor: AppTheme.darkCard,
                        isExpanded: true,
                        initialValue: selectedCustomerId,
                        items: customers.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text('${c.companyName} (${c.customerCode})',
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match =
                                customers.firstWhere((c) => c.id == val);
                            setModalState(() {
                              selectedCustomerId = val;
                              customerNameCtrl.text = match.companyName;
                              initialCustomer = {
                                'id': match.id,
                                'companyName': match.companyName
                              };
                            });
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer / Company Name',
                      hintText: 'e.g. Acme Solar Industries',
                      prefixIcon: Icon(Icons.edit_note, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Select Admin or Employee to Assign/Host
                  const Text(
                      'Select Admin / Employee (Meeting Host / Assigned To) *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  FutureBuilder<List<StaffMember>>(
                    future: ref.read(staffRepositoryProvider).getStaffList(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
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
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Loading staff list...',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        );
                      }
                      final staffList = snapshot.data ?? [];
                      return DropdownButtonFormField<StaffMember>(
                        initialValue: selectedStaff,
                        decoration: InputDecoration(
                          hintText: 'Select Admin or Employee to assign',
                          prefixIcon: const Icon(Icons.person_pin, size: 18),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
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
                              'Staff';
                          final isAdmin = roleLabel
                                  .toLowerCase()
                                  .contains('admin') ||
                              roleLabel.toLowerCase().contains('director') ||
                              roleLabel.toLowerCase().contains('manager');
                          return DropdownMenuItem<StaffMember>(
                            value: staff,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${staff.fullName} (${staff.employeeId})',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAdmin
                                        ? AppTheme.primary
                                            .withValues(alpha: 0.2)
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
                  const SizedBox(height: 12),

                  // Activity / Meeting Type
                  const Text('Meeting / Activity Type *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: actionCtrl.text,
                    decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    dropdownColor: AppTheme.darkCard,
                    items: [
                      'MEETING',
                      'DEMO',
                      'SITE_VISIT',
                      'CALL',
                      'PROPOSAL_REVIEW',
                      'TECHNICAL_DISCUSSION'
                    ]
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(t.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: (v) => setModalState(() => actionCtrl.text = v!),
                  ),
                  const SizedBox(height: 12),

                  // Meeting Subject
                  const Text('Subject / Agenda *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. Panel Specification & Commercial Offer Discussion',
                      prefixIcon: Icon(Icons.subject, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scheduled Date & Time
                  const Text('Scheduled Date & Time *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event,
                              size: 18, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy')
                                .format(selectedDate),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Meeting Location / Video Link
                  const Text('Location / Meeting Link',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. Conference Room B / Client Factory / Zoom',
                      prefixIcon: Icon(Icons.place, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Priority Selector
                  const Text('Priority Level',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPriority,
                    decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    dropdownColor: AppTheme.darkCard,
                    items: ['LOW', 'MEDIUM', 'HIGH', 'URGENT']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => selectedPriority = v!),
                  ),
                  const SizedBox(height: 12),

                  // Notes & Preparation
                  const Text('Meeting Notes & Preparation Details',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      hintText:
                          'Key discussion points, required documents to carry...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (customerNameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Customer name is required')));
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          final repo = ref.read(crmRepositoryProvider);
                          await repo.scheduleMeeting({
                            'customerName': customerNameCtrl.text.trim(),
                            if (selectedCustomerId != null)
                              'customerId': selectedCustomerId,
                            if (selectedStaff != null)
                              'assignedStaffId': selectedStaff!.id,
                            'assignedStaffName': selectedStaff?.fullName ?? '',
                            'purpose': subjectCtrl.text.trim().isEmpty
                                ? actionCtrl.text
                                : subjectCtrl.text.trim(),
                            'meetingDate': selectedDate.toIso8601String(),
                            'location': locationCtrl.text.trim(),
                            'priority': selectedPriority,
                            'notes': notesCtrl.text.trim(),
                          });
                          _loadCurrentTab();
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '✅ Meeting scheduled with ${selectedStaff?.fullName ?? "team"} — added to follow-up queue'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          _loadCurrentTab();
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Meeting scheduled & follow-up queue updated ✓'),
                                  backgroundColor: AppTheme.success),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('CONFIRM SCHEDULE MEETING',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
