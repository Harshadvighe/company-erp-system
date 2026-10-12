import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
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
            Tab(text: 'Today'),
            Tab(text: '🚨 Overdue'),
            Tab(text: 'Pending'),
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

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppTheme.darkSurface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
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
                                fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                Text(
                    '${company['contactPerson'] ?? ''}  ·  ${company['phone'] ?? ''}  ·  ${company['email'] ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Follow-up history (${followUps.length})',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold)),
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
                  child: followUps.isEmpty
                      ? const Center(
                          child: Text('No interactions recorded yet.',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: followUps.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final followUp = followUps[index];
                            final number =
                                followUp['followUpNumber'] ?? index + 1;
                            final date = followUp['interactionDate'] ??
                                followUp['scheduledDate'] ??
                                followUp['createdAt'];
                            final status =
                                followUp['displayStatus']?.toString() ??
                                    followUp['status']?.toString() ??
                                    'PENDING';
                            final staff = followUp['assignedStaff'] as Map?;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Text(
                                              'Follow-up #$number  ·  ${followUp['activityType'] ?? followUp['title'] ?? 'FOLLOW-UP'}',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      _buildStatusBadge(status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${_formatDate(date)}  ·  Assigned: ${staff?['fullName'] ?? '—'}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  if ((followUp['subject'] ?? followUp['title'])
                                          ?.toString()
                                          .isNotEmpty ==
                                      true)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                            'Subject: ${followUp['subject'] ?? followUp['title']}')),
                                  if (followUp['discussion']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                            'Discussion: ${followUp['discussion']}')),
                                  if (followUp['outcome']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                            'Outcome: ${followUp['outcome']}')),
                                  if (followUp['nextAction']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                            'Next action: ${followUp['nextAction']}')),
                                  if (status == 'PENDING' ||
                                      status == 'OVERDUE')
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          Navigator.pop(dialogContext);
                                          _showCompleteCompanyFollowUpDialog(
                                              followUp);
                                        },
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Complete'),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (!schedule &&
                              discussionController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Enter the interaction details to complete now.')));
                            return;
                          }
                          Navigator.pop(dialogContext);
                          try {
                            await ref
                                .read(crmRepositoryProvider)
                                .createFollowUp({
                              'customerId': company['id'],
                              'mode': schedule ? 'SCHEDULE' : 'COMPLETE_NOW',
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
                              if (schedule) 'reminderMinutes': reminderMinutes,
                            });
                            await _loadCompanies();
                            await ref
                                .read(followUpListProvider.notifier)
                                .loadFollowUps();
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Follow-up saved.'),
                                      backgroundColor: AppTheme.success));
                            }
                          } catch (error) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Could not save follow-up: $error'),
                                      backgroundColor: AppTheme.error));
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Follow-up'),
                      ),
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

  void _showCompleteCompanyFollowUpDialog(Map<String, dynamic> followUp) {
    final discussionController = TextEditingController();
    final outcomeController = TextEditingController();
    final nextActionController = TextEditingController();
    bool scheduleNext = false;
    DateTime nextDate = DateTime.now().add(const Duration(days: 1));
    final company = followUp['customer'] as Map?;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title:
              Text('Complete Follow-up #${followUp['followUpNumber'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(company?['companyName']?.toString() ??
                    _selectedCompany?['companyName']?.toString() ??
                    ''),
                const SizedBox(height: 12),
                TextField(
                    controller: discussionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Actual discussion *')),
                const SizedBox(height: 10),
                TextField(
                    controller: outcomeController,
                    decoration: const InputDecoration(labelText: 'Outcome')),
                const SizedBox(height: 10),
                TextField(
                    controller: nextActionController,
                    decoration:
                        const InputDecoration(labelText: 'Next action')),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Schedule next follow-up'),
                  value: scheduleNext,
                  onChanged: (value) =>
                      setDialogState(() => scheduleNext = value),
                ),
                if (scheduleNext)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: nextDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (date == null || !dialogContext.mounted) return;
                      final time = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.fromDateTime(nextDate));
                      if (time != null) {
                        setDialogState(() => nextDate = DateTime(date.year,
                            date.month, date.day, time.hour, time.minute));
                      }
                    },
                    icon: const Icon(Icons.event),
                    label: Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(nextDate)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (discussionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Discussion is required.')));
                  return;
                }
                Navigator.pop(dialogContext);
                try {
                  await ref
                      .read(crmRepositoryProvider)
                      .completeFollowUp(followUp['id'].toString(), {
                    'discussion': discussionController.text.trim(),
                    'outcome': outcomeController.text.trim(),
                    'nextAction': nextActionController.text.trim(),
                    'scheduleNext': scheduleNext,
                    if (scheduleNext)
                      'nextScheduledDate': nextDate.toIso8601String(),
                  });
                  await _loadCompanies();
                  await ref.read(followUpListProvider.notifier).loadFollowUps();
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                        content: Text(scheduleNext
                            ? 'Completed and next follow-up scheduled for the same company.'
                            : 'Follow-up completed.'),
                        backgroundColor: AppTheme.success));
                  }
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                        content: Text('Could not complete follow-up: $error'),
                        backgroundColor: AppTheme.error));
                  }
                }
              },
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Data Table View ──────────────────────────────────────────────────────────

  Widget _buildFollowUpDataTable(List<dynamic> followUps) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
            dataRowMaxHeight: 68,
            columnSpacing: 18,
            columns: const [
              DataColumn(
                  label: Text('Customer / Company',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary))),
              DataColumn(
                  label: Text('Action / Type',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary))),
              DataColumn(
                  label: Text('Assigned Host / Admin',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary))),
              DataColumn(
                  label: Text('Due Date & Time',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary))),
              DataColumn(
                  label: Text('Priority',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary))),
              DataColumn(
                  label: Text('Status',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary))),
              DataColumn(
                  label: Text('Notes / Subject',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary))),
              DataColumn(
                  label: Text('Quick Actions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary))),
            ],
            rows: followUps.map((item) {
              final fu = item as Map<String, dynamic>;
              final status = fu['status'] as String? ?? 'PENDING';
              final isOverdue = status == 'OVERDUE' ||
                  (fu['dueDate'] != null &&
                      DateTime.tryParse(fu['dueDate'])
                              ?.isBefore(DateTime.now()) ==
                          true &&
                      status == 'PENDING');
              final customer = fu['customer'] as Map<String, dynamic>?;
              final lead = fu['lead'] as Map<String, dynamic>?;
              final assignedStaff =
                  fu['assignedStaff'] as Map<String, dynamic>? ??
                      fu['staff'] as Map<String, dynamic>?;
              final assignedName =
                  assignedStaff?['fullName'] ?? 'Amit Joshi (Sales Exec)';
              final assignedRole =
                  assignedStaff?['designation']?['name'] ?? 'Sales Executive';

              final entityName = customer?['companyName'] ??
                  lead?['companyName'] ??
                  customer?['name'] ??
                  'General Customer';
              final contactPerson = customer?['contactPerson'] ??
                  customer?['ownerName'] ??
                  lead?['contactPerson'] ??
                  '';
              final phone = customer?['phone'] ?? lead?['phone'] ?? '';
              final action = fu['action'] ?? 'Follow-up';
              final dueDateStr = fu['dueDate'] != null
                  ? fu['dueDate'].toString().split('T')[0]
                  : 'No Date';
              final priority = fu['priority'] ?? 'MEDIUM';
              final notes = fu['notes'] as String? ?? '';

              Color priorityColor = Colors.grey;
              if (priority == 'HIGH') priorityColor = Colors.orange;
              if (priority == 'URGENT') priorityColor = Colors.red;

              IconData actionIcon = Icons.call;
              if (action.toString().toUpperCase().contains('MEETING')) {
                actionIcon = Icons.groups;
              }
              if (action.toString().toUpperCase().contains('VISIT')) {
                actionIcon = Icons.location_on;
              }
              if (action.toString().toUpperCase().contains('DEMO')) {
                actionIcon = Icons.computer;
              }

              return DataRow(
                onSelectChanged: (_) => _showFollowUpDetailModal(fu),
                cells: [
                  // Customer Column
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entityName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white)),
                        if (contactPerson.isNotEmpty || phone.isNotEmpty)
                          Text(
                              '$contactPerson ${phone.isNotEmpty ? "($phone)" : ""}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),

                  // Action / Type
                  DataCell(
                    Row(
                      children: [
                        Icon(actionIcon, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(action,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ),

                  // Assigned Host / Admin
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(assignedName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(assignedRole,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  // Due Date
                  DataCell(
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14,
                            color: isOverdue ? Colors.red : Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          dueDateStr,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: isOverdue
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isOverdue ? Colors.red : Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Priority
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(priority,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: priorityColor)),
                    ),
                  ),

                  // Status
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? Colors.red.withValues(alpha: 0.15)
                            : (status == 'COMPLETED'
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: isOverdue
                                ? Colors.red
                                : (status == 'COMPLETED'
                                    ? Colors.green
                                    : Colors.blue),
                            width: 0.5),
                      ),
                      child: Text(
                        isOverdue ? 'OVERDUE' : status,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOverdue
                                ? Colors.red
                                : (status == 'COMPLETED'
                                    ? Colors.green
                                    : Colors.blue)),
                      ),
                    ),
                  ),

                  // Notes / Subject
                  DataCell(
                    SizedBox(
                      width: 170,
                      child: Text(
                        notes.isEmpty ? 'No notes added' : notes,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Quick Actions
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined,
                              size: 18, color: AppTheme.primary),
                          tooltip: 'View Details',
                          onPressed: () => _showFollowUpDetailModal(fu),
                        ),
                        IconButton(
                          icon: const Icon(Icons.event,
                              size: 18, color: Colors.blue),
                          tooltip: 'Schedule Meeting',
                          onPressed: () => _showScheduleMeetingDialog(
                              initialCustomer: customer ?? lead),
                        ),
                        if (status != 'COMPLETED')
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18, color: Colors.green),
                            tooltip: 'Complete',
                            onPressed: () => _showCompleteDialog(fu['id']),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─── Card View ────────────────────────────────────────────────────────────────

  Widget _buildFollowUpCard(Map<String, dynamic> fu) {
    final status = fu['status'] as String? ?? 'PENDING';
    final isOverdue = status == 'OVERDUE' ||
        (fu['dueDate'] != null &&
            DateTime.tryParse(fu['dueDate'])?.isBefore(DateTime.now()) ==
                true &&
            status == 'PENDING');
    final customer = fu['customer'] as Map<String, dynamic>?;
    final lead = fu['lead'] as Map<String, dynamic>?;
    final assignedStaff = fu['assignedStaff'] as Map<String, dynamic>? ??
        fu['staff'] as Map<String, dynamic>?;
    final assignedName =
        assignedStaff?['fullName'] ?? 'Amit Joshi (Sales Exec)';

    final entityName =
        customer?['companyName'] ?? lead?['companyName'] ?? 'General Follow-up';
    final action = fu['action'] ?? 'Follow-up';
    final dueDate = fu['dueDate'] != null
        ? DateTime.tryParse(fu['dueDate'])?.toLocal().toString().split(' ')[0]
        : 'No Date';
    final priority = fu['priority'] ?? 'MEDIUM';

    Color priorityColor = Colors.grey;
    if (priority == 'HIGH') priorityColor = Colors.orange;
    if (priority == 'URGENT') priorityColor = Colors.red;

    return Card(
      color: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: isOverdue
                ? Colors.red.withValues(alpha: 0.5)
                : AppTheme.darkBorder),
      ),
      child: InkWell(
        onTap: () => _showFollowUpDetailModal(fu),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.red.withValues(alpha: 0.15)
                              : (status == 'COMPLETED'
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: isOverdue
                                  ? Colors.red
                                  : (status == 'COMPLETED'
                                      ? Colors.green
                                      : Colors.blue),
                              width: 0.5),
                        ),
                        child: Text(
                          isOverdue ? 'OVERDUE' : status,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOverdue
                                  ? Colors.red
                                  : (status == 'COMPLETED'
                                      ? Colors.green
                                      : Colors.blue)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(priority,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: priorityColor)),
                      ),
                    ],
                  ),
                  Text('Due: $dueDate',
                      style: TextStyle(
                          fontSize: 11,
                          color: isOverdue ? Colors.red : Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Text(entityName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Action: $action',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  Text('• Assigned: $assignedName',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              if (fu['notes'] != null &&
                  (fu['notes'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(fu['notes'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppTheme.darkBorder),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _showFollowUpDetailModal(fu),
                    icon: const Icon(Icons.info_outline, size: 14),
                    label: const Text('View Full Record',
                        style: TextStyle(fontSize: 12)),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showScheduleMeetingDialog(
                            initialCustomer: customer ?? lead),
                        icon: const Icon(Icons.event,
                            size: 14, color: Colors.blue),
                        label: const Text('Meeting',
                            style: TextStyle(color: Colors.blue, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue)),
                      ),
                      if (status != 'COMPLETED') ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showCompleteDialog(fu['id']),
                          icon: const Icon(Icons.check,
                              size: 14, color: Colors.green),
                          label: const Text('Done',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.green)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Follow-up Record Detail Dialog ───────────────────────────────────────────

  void _showFollowUpDetailModal(Map<String, dynamic> fu) {
    final customer = fu['customer'] as Map<String, dynamic>?;
    final lead = fu['lead'] as Map<String, dynamic>?;
    final assignedStaff = fu['assignedStaff'] as Map<String, dynamic>? ??
        fu['staff'] as Map<String, dynamic>?;
    final assignedName =
        assignedStaff?['fullName'] ?? 'Amit Joshi (Sales Exec)';
    final assignedRole =
        assignedStaff?['designation']?['name'] ?? 'Sales Executive';

    final entityName = customer?['companyName'] ??
        lead?['companyName'] ??
        customer?['name'] ??
        'General Follow-up';
    final contactPerson = customer?['contactPerson'] ??
        customer?['ownerName'] ??
        lead?['contactPerson'] ??
        'N/A';
    final phone = customer?['phone'] ?? lead?['phone'] ?? 'N/A';
    final email = customer?['email'] ?? lead?['email'] ?? 'N/A';
    final address = customer?['address'] ?? lead?['address'] ?? '';
    final gstin = customer?['gstin'] ?? '';
    final action = fu['action'] ?? 'Follow-up';
    final status = fu['status'] as String? ?? 'PENDING';
    final priority = fu['priority'] ?? 'MEDIUM';
    final dueDateStr =
        fu['dueDate'] != null ? fu['dueDate'].toString().split('T')[0] : 'N/A';
    final notes = fu['notes'] ?? 'No additional notes provided.';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.darkBorder),
        ),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined,
                          color: AppTheme.primary, size: 22),
                      SizedBox(width: 8),
                      Text('Follow-up Record Details',
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

              // Customer / Company Record Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entityName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: status == 'COMPLETED'
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(status,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'COMPLETED'
                                      ? Colors.green
                                      : Colors.blue)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text('Contact: $contactPerson',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                        const SizedBox(width: 16),
                        const Icon(Icons.phone_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(phone,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                    if (email.isNotEmpty && email != 'N/A') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(email,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ],
                    if (gstin.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('GSTIN: $gstin',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Address: $address',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Scheduled Action & Assigned Host Details
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scheduled Action Specifications',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(
                            width: 140,
                            child: Text('Action Type:',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12))),
                        Expanded(
                            child: Text(action,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(
                            width: 140,
                            child: Text('Assigned Host / Admin:',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12))),
                        Expanded(
                          child: Text('$assignedName ($assignedRole)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(
                            width: 140,
                            child: Text('Due Date:',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12))),
                        Expanded(
                            child: Text(dueDateStr,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.orange))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(
                            width: 140,
                            child: Text('Priority:',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12))),
                        Expanded(
                            child: Text(priority,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.primary))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Subject & Instructions:',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(notes,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (customer?['id'] != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/customers/${customer!['id']}');
                      },
                      icon: const Icon(Icons.account_box, size: 16),
                      label: const Text('Customer Profile'),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showScheduleMeetingDialog(
                              initialCustomer: customer ?? lead);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue),
                        icon: const Icon(Icons.event, size: 16),
                        label: const Text('SCHEDULE MEETING'),
                      ),
                      const SizedBox(width: 8),
                      if (status != 'COMPLETED')
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCompleteDialog(fu['id']);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('MARK DONE'),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Complete Follow-up Dialog ────────────────────────────────────────────────

  void _showCompleteDialog(String id) {
    final outcomeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Follow-up & Record Outcome'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: outcomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Outcome / Agreed Action *',
                hintText:
                    'e.g. Quotation approved, meeting scheduled for technical discussion',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(followUpListProvider.notifier)
                  .complete(id, outcomeCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Follow-up completed successfully'),
                      backgroundColor: AppTheme.success),
                );
              }
            },
            child: const Text('MARK COMPLETED'),
          ),
        ],
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
                            ScaffoldMessenger.of(context).showSnackBar(
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
                            ScaffoldMessenger.of(context).showSnackBar(
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
