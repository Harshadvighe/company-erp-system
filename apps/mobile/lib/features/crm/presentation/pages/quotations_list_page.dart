import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

class QuotationsListPage extends ConsumerStatefulWidget {
  const QuotationsListPage({super.key});

  @override
  ConsumerState<QuotationsListPage> createState() => _QuotationsListPageState();
}

class _QuotationsListPageState extends ConsumerState<QuotationsListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  final _statusFilters = ['ALL', 'DRAFT', 'SENT', 'ACCEPTED', 'CONVERTED', 'REJECTED'];
  
  List<dynamic> _quotations = [];
  bool _isLoading = false;
  String? _error;
  int _totalCount = 0;
  double _totalValue = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadQuotations();
      }
    });
    _loadQuotations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final selectedStatus = _statusFilters[_tabController.index];
      final repo = ref.read(salesRepositoryProvider);
      final res = await repo.getQuotations(
        status: selectedStatus == 'ALL' ? null : selectedStatus,
        search: _searchController.text.trim(),
      );

      final items = res['items'] as List<dynamic>? ?? [];
      double sum = 0;
      for (final itm in items) {
        sum += (itm['grandTotal'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _quotations = items;
        _totalCount = (res['total'] as num?)?.toInt() ?? items.length;
        _totalValue = sum;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACCEPTED':
        return Colors.green;
      case 'CONVERTED':
        return Colors.purple;
      case 'SENT':
        return Colors.orange;
      case 'PENDING_APPROVAL':
        return Colors.amber.shade800;
      case 'REJECTED':
      case 'EXPIRED':
        return Colors.red;
      case 'DRAFT':
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
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
        title: const Text('Quotations & Commercial Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuotations,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
            tooltip: 'Filter',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: _statusFilters.map((s) => Tab(text: s.replaceAll('_', ' '))).toList(),
        ),
      ),
      body: Column(
        children: [
          // ─── Metric & Search Bar ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.darkSurface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.request_quote_outlined, color: AppTheme.primaryColor),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Offers', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                                Text('$_totalCount Quotes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.currency_rupee, color: AppTheme.success),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pipeline Value', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                                Text(
                                  currencyFormatter.format(_totalValue),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.success),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Quotation #, Revision, Company, Subject...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.darkTextSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.darkTextSecondary),
                            onPressed: () {
                              _searchController.clear();
                              _loadQuotations();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.darkCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.darkBorder),
                    ),
                  ),
                  onSubmitted: (_) => _loadQuotations(),
                ),
              ],
            ),
          ),

          // ─── Quotations List ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadQuotations, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _quotations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Quotations Found',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create a new commercial quote or import from an engineering panel specification.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => context.push('/crm/quotations/new').then((_) => _loadQuotations()),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create First Quotation'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadQuotations,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _quotations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final quote = _quotations[index];
                                final customer = quote['customer'] as Map<String, dynamic>?;
                                final status = quote['status'] as String? ?? 'DRAFT';
                                final code = quote['code'] as String? ?? quote['quotationNumber'] ?? 'QUO';
                                final revisionNumber = quote['revisionNumber'] ?? 0;
                                final grandTotal = (quote['grandTotal'] as num?)?.toDouble() ?? 0;
                                final itemsCount = (quote['items'] as List?)?.length ?? 0;
                                final createdAt = quote['createdAt'] != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(quote['createdAt']))
                                    : '-';

                                return Card(
                                  elevation: 1.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      context.push('/crm/quotations/${quote['id']}').then((_) => _loadQuotations());
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top Row: Code + Revision + Status Badge
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      code,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.primaryColor,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.indigo.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.indigo.shade200),
                                                    ),
                                                    child: Text(
                                                      'REV-$revisionNumber',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.indigo.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(status).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  status.replaceAll('_', ' '),
                                                  style: TextStyle(
                                                    color: _getStatusColor(status),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Company Name & Subject
                                          Text(
                                            customer?['companyName'] ?? 'Unnamed Customer',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            quote['subject'] ?? 'Commercial Proposal',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                          const Divider(height: 1),
                                          const SizedBox(height: 12),

                                          // Bottom Row: Date, Items count & Grand Total
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                                  const SizedBox(width: 12),
                                                  Icon(Icons.layers_outlined, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Text('$itemsCount Items', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                                ],
                                              ),
                                              Text(
                                                currencyFormatter.format(grandTotal),
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppTheme.primaryColor,
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
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/crm/quotations/new').then((_) => _loadQuotations());
        },
        icon: const Icon(Icons.add),
        label: const Text('New Quotation'),
      ),
    );
  }
}

