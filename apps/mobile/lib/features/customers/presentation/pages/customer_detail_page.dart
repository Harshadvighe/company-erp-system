import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDetailPage({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));

    return customerAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, __) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(e.toString(), style: const TextStyle(color: Colors.grey)),
              TextButton(
                  onPressed: () => context.pop(), child: const Text('Go Back')),
            ],
          ),
        ),
      ),
      data: (customer) => _buildPage(customer),
    );
  }

  Widget _buildPage(Map<String, dynamic> customer) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.darkSurface,
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
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(customer),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.go('/customers/${widget.customerId}/edit'),
                tooltip: 'Edit Customer',
              ),
              PopupMenuButton(
                itemBuilder: (_) => <PopupMenuEntry>[
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.phone, size: 16),
                      SizedBox(width: 8),
                      Text('Call')
                    ]),
                    onTap: () {},
                  ),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.chat, size: 16),
                      SizedBox(width: 8),
                      Text('WhatsApp')
                    ]),
                    onTap: () {},
                  ),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.email_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Email')
                    ]),
                    onTap: () {},
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.add, size: 16),
                      SizedBox(width: 8),
                      Text('Add Enquiry')
                    ]),
                    onTap: () {},
                  ),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.add, size: 16),
                      SizedBox(width: 8),
                      Text('Record Interaction')
                    ]),
                    onTap: () =>
                        _showAddInteractionDialog(customer['id'] as String),
                  ),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.star_border,
                          size: 16, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Review & Ratings',
                          style: TextStyle(color: AppTheme.primary))
                    ]),
                    onTap: () =>
                        Future.microtask(() => _showReviewDialog(customer)),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.merge_type, size: 16, color: AppTheme.warning),
                      SizedBox(width: 8),
                      Text('Merge Customer',
                          style: TextStyle(color: AppTheme.warning))
                    ]),
                    onTap: () =>
                        Future.microtask(() => _showMergeDialog(customer)),
                  ),
                ],
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Contacts'),
                  Tab(text: 'Media & Photos'),
                  Tab(text: 'Timeline (360)'),
                  Tab(text: 'Quotations, Orders & Invoices'),
                  Tab(text: 'Opportunities'),
                  Tab(text: 'Enquiries'),
                  Tab(text: 'Panels & Specs'),
                  Tab(text: 'Follow-ups'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(customer: customer),
            _ContactsTab(customer: customer, onRefresh: _refresh),
            _MediaAndPhotosTab(
                customerId: widget.customerId, customer: customer),
            _TimelineTab(customerId: widget.customerId),
            _QuotationsAndOrdersTab(customerId: widget.customerId),
            _OpportunitiesTab(customer: customer),
            _EnquiriesTab(customer: customer),
            _PanelsTab(customer: customer),
            _CustomerFollowUpsTab(
              customerId: widget.customerId,
              onAddFollowUp: () async {
                await context.push('/crm/follow-ups?customerId=${widget.customerId}');
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(customerDetailProvider(widget.customerId));
  }

  Widget _buildHeader(Map<String, dynamic> c) {
    final companyName = c['companyName'] as String? ?? '';
    final initials = companyName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    return Container(
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: Text(initials,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(companyName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Badge(
                        label: c['customerType'] as String? ?? '',
                        color: AppTheme.primary),
                    const SizedBox(width: 8),
                    _Badge(
                        label: c['status'] as String? ?? '',
                        color: AppTheme.success),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c['customerCode'] as String? ?? '',
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddInteractionDialog(String customerId) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.darkBorder),
        ),
        child: Container(
          width: 580,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
            maxWidth: 580,
          ),
          padding: const EdgeInsets.all(24),
          child:
              _AddInteractionForm(customerId: customerId, onSuccess: _refresh),
        ),
      ),
    );
  }

  void _showReviewDialog(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Row(
          children: [
            Icon(Icons.star_border, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Customer Review & Rating',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Review & rating management for ${customer['companyName']} will be available in the next release.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('CLOSE', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(Map<String, dynamic> customer) {
    final targetCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Row(
          children: [
            Icon(Icons.merge_type, color: AppTheme.warning),
            SizedBox(width: 8),
            Text('Merge Customer',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Merge "${customer['companyName']}" into another Master Customer profile. Contacts, leads, enquiries, opportunities, and activities will be re-parented.',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              decoration: const InputDecoration(
                labelText: 'Target Master Customer ID',
                hintText: 'Enter target customer UUID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () async {
              final targetId = targetCtrl.text.trim();
              if (targetId.isEmpty) return;
              try {
                final repo = ref.read(customersRepositoryProvider);
                await repo.mergeCustomers(
                    sourceId: customer['id'], targetId: targetId);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Customer merged successfully'),
                        backgroundColor: AppTheme.success),
                  );
                  context.go('/customers');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('CONFIRM MERGE',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _CustomerFollowUpsTab extends ConsumerStatefulWidget {
  final String customerId;
  final Future<void> Function() onAddFollowUp;

  const _CustomerFollowUpsTab({
    required this.customerId,
    required this.onAddFollowUp,
  });

  @override
  ConsumerState<_CustomerFollowUpsTab> createState() =>
      _CustomerFollowUpsTabState();
}

class _CustomerFollowUpsTabState extends ConsumerState<_CustomerFollowUpsTab> {
  late Future<List<dynamic>> _followUpsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _followUpsFuture = ref
        .read(crmRepositoryProvider)
        .getFollowUps(customerId: widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _followUpsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(height: 8),
                Text('Unable to load follow-ups: ${snapshot.error}'),
                TextButton(
                  onPressed: () => setState(_reload),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final followUps = snapshot.data!
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
        final now = DateTime.now();
        final completed =
            followUps.where((item) => item['status'] == 'COMPLETED').length;
        final overdue = followUps.where((item) {
          final due = DateTime.tryParse(item['scheduledDate']?.toString() ?? '');
          return item['status'] == 'PENDING' && due != null && due.isBefore(now);
        }).length;
        final pending = followUps.where((item) {
          final due = DateTime.tryParse(item['scheduledDate']?.toString() ?? '');
          return item['status'] == 'PENDING' && (due == null || !due.isBefore(now));
        }).length;
        final lastInteraction = followUps
            .where((item) => item['interactionDate'] != null)
            .map((item) => DateTime.tryParse(item['interactionDate'].toString()))
            .whereType<DateTime>()
            .fold<DateTime?>(null, (latest, date) {
          return latest == null || date.isAfter(latest) ? date : latest;
        });
        final nextDates = followUps
            .where((item) => item['status'] == 'PENDING')
            .map((item) => DateTime.tryParse(item['scheduledDate']?.toString() ?? ''))
            .whereType<DateTime>()
            .toList()
          ..sort();
        final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FollowUpMetric(label: 'Total', value: followUps.length),
                  _FollowUpMetric(label: 'Completed', value: completed),
                  _FollowUpMetric(label: 'Pending', value: pending),
                  _FollowUpMetric(label: 'Overdue', value: overdue),
                  _FollowUpMetric(
                    label: 'Last interaction',
                    value: lastInteraction == null
                        ? '—'
                        : dateFormat.format(lastInteraction.toLocal()),
                  ),
                  _FollowUpMetric(
                    label: 'Next follow-up',
                    value: nextDates.isEmpty
                        ? '—'
                        : dateFormat.format(nextDates.first.toLocal()),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await widget.onAddFollowUp();
                      if (mounted) setState(_reload);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Follow-up'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: followUps.isEmpty
                  ? const Center(child: Text('No follow-ups recorded yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: followUps.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = followUps[index];
                        final date = DateTime.tryParse(
                          (item['interactionDate'] ??
                                  item['scheduledDate'] ??
                                  item['createdAt'])
                              .toString(),
                        );
                        final status = item['displayStatus'] ??
                            item['status'] ??
                            'PENDING';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              '#${item['followUpNumber'] ?? index + 1}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item['subject']?.toString().isNotEmpty == true
                                ? item['subject'].toString()
                                : item['title']?.toString() ?? 'Follow-up',
                          ),
                          subtitle: Text(
                            '${item['activityType'] ?? 'FOLLOW-UP'}  ·  ${date == null ? 'No date' : dateFormat.format(date.toLocal())}\n${item['discussion'] ?? item['notes'] ?? ''}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            status.toString(),
                            style: TextStyle(
                              color: status == 'OVERDUE'
                                  ? AppTheme.error
                                  : status == 'COMPLETED'
                                      ? AppTheme.success
                                      : Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FollowUpMetric extends StatelessWidget {
  final String label;
  final Object value;

  const _FollowUpMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 3),
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _OverviewTab({required this.customer});

  @override
  Widget build(BuildContext context) {
    final productInterests = (customer['productInterests'] as List?) ?? [];
    final valuations = customer['valuations'] as Map<String, dynamic>? ?? {};
    final isGstVerified = customer['gstVerified'] == true;
    final gstStatus = customer['gstStatus'] ??
        (customer['gstin'] != null ? 'GST_REGISTERED' : 'NO_GST');
    final valScore = (valuations['valuablePercentage'] ??
            (customer['customerRating'] != null
                ? (customer['customerRating'] / 5 * 60 + 30)
                : 50.0))
        .toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── GST & COMPANY PROFILE CARD ────────────────────────────────────
        _SectionCard(
          title: 'GST Intelligence & Profile',
          icon: Icons.verified_user_outlined,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGstVerified
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : (gstStatus == 'NO_GST'
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isGstVerified
                          ? AppTheme.success.withValues(alpha: 0.5)
                          : (gstStatus == 'NO_GST'
                              ? Colors.amber.withValues(alpha: 0.5)
                              : Colors.grey),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGstVerified
                            ? Icons.check_circle
                            : (gstStatus == 'NO_GST'
                                ? Icons.info_outline
                                : Icons.help_outline),
                        color: isGstVerified
                            ? AppTheme.success
                            : (gstStatus == 'NO_GST'
                                ? Colors.amber
                                : Colors.grey),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isGstVerified
                            ? 'GST VERIFIED ACTIVE'
                            : (gstStatus == 'NO_GST'
                                ? 'NO GST / EXEMPT'
                                : 'UNVERIFIED GST'),
                        style: TextStyle(
                          color: isGstVerified
                              ? AppTheme.success
                              : (gstStatus == 'NO_GST'
                                  ? Colors.amber
                                  : Colors.white70),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
                label: 'GSTIN', value: customer['gstin'] ?? 'Not Registered'),
            if (customer['noGstReason'] != null)
              _InfoRow(
                  label: 'No GST Reason',
                  value:
                      (customer['noGstReason'] as String).replaceAll('_', ' ')),
            if (customer['legalName'] != null)
              _InfoRow(label: 'Legal Name', value: customer['legalName']),
            if (customer['tradeName'] != null)
              _InfoRow(label: 'Trade / Brand', value: customer['tradeName']),
            _InfoRow(
                label: 'Company Type',
                value: customer['companyType'] ?? 'PVT_LTD'),
            _InfoRow(label: 'PAN', value: customer['pan']),
          ],
        ),
        const SizedBox(height: 12),

        // ─── PRODUCT & SYSTEM INTERESTS ────────────────────────────────────
        _SectionCard(
          title: 'Product & System Interests',
          icon: Icons.precision_manufacturing_outlined,
          children: [
            if (productInterests.isEmpty &&
                (customer['customerSegment'] == null ||
                    customer['customerSegment'].toString().isEmpty))
              const Text('No specific product systems tagged yet',
                  style: TextStyle(color: Colors.grey, fontSize: 12))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (customer['customerSegment'] != null)
                    Chip(
                      label: Text(
                          customer['customerSegment']
                              .toString()
                              .replaceAll('_', ' '),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                  ...productInterests.map((pi) {
                    final sys =
                        pi['productSystem'] as Map<String, dynamic>? ?? {};
                    final name =
                        sys['name'] ?? pi['productSystemId'] ?? 'System';
                    return Chip(
                      label: Text(name.toString(),
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppTheme.darkCard,
                      side: const BorderSide(color: AppTheme.darkBorder),
                    );
                  }),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ─── COMPANY VALUATION & SCORING ───────────────────────────────────
        _SectionCard(
          title: 'Company Valuation & Scoring',
          icon: Icons.analytics_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customer Rating',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${customer['customerRating'] ?? 5.0} / 5.0',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Value Score',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.trending_up,
                                color: AppTheme.primary, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${valScore.toStringAsFixed(0)} / 100',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
                label: 'Potential Value',
                value: '₹${(customer['potentialValue'] ?? 0).toString()}'),
            _InfoRow(
                label: 'Credit Limit',
                value: '₹${(customer['creditLimit'] ?? 0).toString()}'),
            _InfoRow(
                label: 'Payment Terms',
                value: customer['paymentTerms'] ?? 'NET_30'),
          ],
        ),
        const SizedBox(height: 12),

        _SectionCard(
          title: 'Contact Information',
          icon: Icons.contact_phone,
          children: [
            _InfoRow(label: 'Contact Person', value: customer['contactPerson']),
            _InfoRow(label: 'Designation', value: customer['designation']),
            _InfoRow(label: 'Email', value: customer['email']),
            _InfoRow(label: 'Phone', value: customer['phone']),
            _InfoRow(
                label: 'Alternate Phone', value: customer['alternatePhone']),
            _InfoRow(label: 'Website', value: customer['website']),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Ownership & Business Information',
          icon: Icons.business,
          children: [
            _InfoRow(
              label: 'Sales Owner',
              value: (customer['assignedStaff'] as Map<String, dynamic>?)?['fullName'] ??
                  customer['ownerName'] ??
                  'Unassigned',
            ),
            _InfoRow(
              label: 'Added By (Creator)',
              value: (customer['createdByUser'] as Map<String, dynamic>?)?['fullName'] ??
                  'System / Admin',
            ),
            if (customer['createdAt'] != null)
              _InfoRow(
                label: 'Registered On',
                value: customer['createdAt'].toString().split('T').first,
              ),
            _InfoRow(label: 'Industry', value: customer['industry']),
            _InfoRow(label: 'Source', value: customer['source']),
            _InfoRow(
                label: 'Staff Count',
                value: (customer['staffCount'] ?? customer['numEmployees'])
                    ?.toString()),
            _InfoRow(label: 'Turnover', value: customer['turnover']),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Address',
          icon: Icons.location_on,
          children: [
            _InfoRow(label: 'Address', value: customer['address']),
            _InfoRow(label: 'City', value: customer['city']),
            _InfoRow(label: 'District', value: customer['district']),
            _InfoRow(label: 'State', value: customer['state']),
            _InfoRow(label: 'Pincode', value: customer['pincode']),
            _InfoRow(label: 'Country', value: customer['country']),
          ],
        ),
      ],
    );
  }
}

class _ContactsTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onRefresh;

  const _ContactsTab({required this.customer, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final contacts = (customer['contacts'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${contacts.length} Contact(s)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Contact', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...contacts.map((c) {
          final contact = c as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: contact['isPrimary'] == true
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                child: Icon(
                  Icons.person,
                  color: contact['isPrimary'] == true
                      ? AppTheme.primary
                      : Colors.grey,
                  size: 18,
                ),
              ),
              title: Row(
                children: [
                  Text(contact['name'] as String? ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (contact['isPrimary'] == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Primary',
                          style:
                              TextStyle(fontSize: 9, color: AppTheme.primary)),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                  '${contact['designation'] ?? ''} · ${contact['mobile'] ?? ''}',
                  style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.phone, size: 16),
                      onPressed: () {}),
                  IconButton(
                      icon: const Icon(Icons.chat, size: 16), onPressed: () {}),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

final _customerDocumentsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, id) async {
  final repo = ref.watch(customersRepositoryProvider);
  return repo.getCustomerDocuments(id);
});

class _MediaAndPhotosTab extends ConsumerStatefulWidget {
  final String customerId;
  final Map<String, dynamic> customer;

  const _MediaAndPhotosTab({required this.customerId, required this.customer});

  @override
  ConsumerState<_MediaAndPhotosTab> createState() => _MediaAndPhotosTabState();
}

class _MediaAndPhotosTabState extends ConsumerState<_MediaAndPhotosTab> {
  bool _isUploading = false;

  void _triggerUpload(String fieldType) {
    pickAndUploadWebFile(
      fieldType: fieldType,
      onFilePicked: (fileName, bytes) async {
        setState(() => _isUploading = true);
        try {
          final repo = ref.read(customersRepositoryProvider);
          await repo.uploadDocument(
            bytes: bytes,
            fileName: fileName,
            entityType: 'CUSTOMER',
            entityId: widget.customerId,
            documentType: fieldType == 'PHOTO'
                ? 'PHOTO'
                : (fieldType == 'AUDIO' ? 'AUDIO' : 'ATTACHMENT'),
          );
          ref.invalidate(_customerDocumentsProvider(widget.customerId));
          ref.invalidate(_interactionsProvider(widget.customerId));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Uploaded "$fileName" successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      },
    );
  }

  void _showUploadOptionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload to Company Profile',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select the type of media or file to attach:',
              style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add_a_photo, color: Colors.teal),
              title: const Text('Upload Photo',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Site photos, factory images, product installations',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _triggerUpload('PHOTO');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: AppTheme.primary),
              title: const Text('Upload Document / File / Video',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'PDF, Excel, Word, MP4 video, site blueprints',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _triggerUpload('ANY');
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic, color: Colors.blueAccent),
              title: const Text('Upload Voice Note / Audio',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Audio recordings, meeting voice logs',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _triggerUpload('AUDIO');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactionsAsync =
        ref.watch(_interactionsProvider(widget.customerId));
    final docsAsync = ref.watch(_customerDocumentsProvider(widget.customerId));

    final List<Map<String, dynamic>> mediaItems = [];

    interactionsAsync.whenData((interactions) {
      for (final item in interactions) {
        final map = item as Map<String, dynamic>;
        final dateStr = map['interactionDate'] ?? map['createdAt'] ?? '';
        final date = dateStr.toString().isNotEmpty
            ? dateStr.toString().split('T')[0]
            : 'Recent';
        final subject = map['subject'] as String? ?? 'Interaction / Site Visit';
        final notes = map['notes'] as String? ?? '';
        final decision = map['decision'] as String? ?? '';
        final outcome = map['outcome'] as String? ?? '';
        final hostName = map['hostName'] as String?;

        if (map['photoUrl'] != null && map['photoUrl'].toString().isNotEmpty) {
          mediaItems.add({
            'type': 'PHOTO',
            'title': 'Site Photo / Installation',
            'url': map['photoUrl'],
            'subject': subject,
            'date': date,
            'notes': notes,
            'decision': decision,
            'outcome': outcome,
            'hostName': hostName,
          });
        }
        if (map['audioUrl'] != null && map['audioUrl'].toString().isNotEmpty) {
          mediaItems.add({
            'type': 'AUDIO',
            'title': 'Voice Note / Call Recording',
            'url': map['audioUrl'],
            'subject': subject,
            'date': date,
            'notes': notes,
            'decision': decision,
            'outcome': outcome,
            'hostName': hostName,
          });
        }
        if (map['attachmentUrl'] != null &&
            map['attachmentUrl'].toString().isNotEmpty) {
          final url = map['attachmentUrl'].toString();
          final lower = url.toLowerCase();
          final isVideo = lower.endsWith('.mp4') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.avi') ||
              lower.endsWith('.mkv');
          mediaItems.add({
            'type': isVideo ? 'VIDEO' : 'DOCUMENT',
            'title':
                isVideo ? 'Client Video / Inspection' : 'Attachment Document',
            'url': url,
            'subject': subject,
            'date': date,
            'notes': notes,
            'decision': decision,
            'outcome': outcome,
            'hostName': hostName,
          });
        }
      }
    });

    docsAsync.whenData((docs) {
      for (final item in docs) {
        final map = item as Map<String, dynamic>;
        final url = map['url'] ?? map['filePath'] ?? map['fileUrl'] ?? '';
        if (url.toString().isEmpty) continue;

        final fileName = map['fileName'] ?? map['name'] ?? 'Company Document';
        final mimeType = (map['mimeType'] ?? '').toString().toLowerCase();
        final docType = (map['documentType'] ?? '').toString().toUpperCase();
        final dateStr = map['createdAt'] ?? '';
        final date = dateStr.toString().isNotEmpty
            ? dateStr.toString().split('T')[0]
            : 'Recent';

        String type = 'DOCUMENT';
        if (mimeType.startsWith('image/') ||
            docType == 'PHOTO' ||
            fileName.endsWith('.png') ||
            fileName.endsWith('.jpg') ||
            fileName.endsWith('.jpeg') ||
            fileName.endsWith('.webp')) {
          type = 'PHOTO';
        } else if (mimeType.startsWith('video/') ||
            fileName.endsWith('.mp4') ||
            fileName.endsWith('.mov') ||
            fileName.endsWith('.avi')) {
          type = 'VIDEO';
        } else if (mimeType.startsWith('audio/') ||
            docType == 'AUDIO' ||
            fileName.endsWith('.mp3') ||
            fileName.endsWith('.wav')) {
          type = 'AUDIO';
        }

        mediaItems.add({
          'type': type,
          'title': fileName,
          'url': url.toString(),
          'subject': 'Profile Upload (${map['uploadedBy'] ?? 'Direct'})',
          'date': date,
          'notes': map['description'] ?? '',
          'decision': '',
          'outcome': '',
          'hostName': map['uploadedBy'],
        });
      }
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.perm_media_outlined,
                  size: 24, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company Media & Photos (${mediaItems.length} Files)',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Upload photos, videos, voice notes & documents directly to this company profile',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _showUploadOptionsDialog,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(_isUploading ? 'Uploading...' : '+ Upload Media'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (interactionsAsync.isLoading || docsAsync.isLoading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (mediaItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 54, color: AppTheme.darkTextSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'No Photos or Media Attached Yet',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Click "+ Upload Media" above to add photos, site inspection videos, or documents directly to this company profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.darkTextSecondary),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _showUploadOptionsDialog,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('+ Upload Photo / Media Now'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mediaItems.length,
            itemBuilder: (context, index) {
              final media = mediaItems[index];
              final type = media['type'] as String;
              final url = media['url'] as String;
              final title = media['title'] as String;
              final date = media['date'] as String;
              final subject = media['subject'] as String? ?? '';
              final notes = media['notes'] as String? ?? '';
              final decision = media['decision'] as String? ?? '';
              final outcome = media['outcome'] as String? ?? '';
              final hostName = media['hostName'] as String?;
              final resolvedUrl = _resolveMediaUrl(url);

              IconData icon;
              Color iconColor;

              if (type == 'PHOTO') {
                icon = Icons.photo_outlined;
                iconColor = Colors.teal;
              } else if (type == 'VIDEO') {
                icon = Icons.videocam_outlined;
                iconColor = Colors.purpleAccent;
              } else if (type == 'AUDIO') {
                icon = Icons.mic_none_outlined;
                iconColor = Colors.blueAccent;
              } else {
                icon = Icons.description_outlined;
                iconColor = AppTheme.primary;
              }

              return Card(
                color: AppTheme.darkCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.darkBorder),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () =>
                      _showMediaPreviewDialog(context, url, type, title),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Media thumbnail / icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: type == 'PHOTO'
                                ? Image.network(
                                    resolvedUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                        Icon(icon, size: 36, color: iconColor),
                                  )
                                : Icon(icon, size: 36, color: iconColor),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Media Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    date,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (subject.isNotEmpty)
                                Text(
                                  'Subject: $subject',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.darkTextSecondary),
                                ),
                              if (hostName != null && hostName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Uploaded/Hosted By: $hostName',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.blueAccent),
                                ),
                              ],
                              if (notes.isNotEmpty ||
                                  decision.isNotEmpty ||
                                  outcome.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkBackground,
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: AppTheme.darkBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (notes.isNotEmpty) ...[
                                        const Text('Discussion / Notes:',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        const SizedBox(height: 2),
                                        Text(notes,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.white70)),
                                      ],
                                      if (decision.isNotEmpty) ...[
                                        if (notes.isNotEmpty)
                                          const SizedBox(height: 6),
                                        const Text('Decision:',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        const SizedBox(height: 2),
                                        Text(decision,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.greenAccent)),
                                      ],
                                      if (outcome.isNotEmpty) ...[
                                        if (notes.isNotEmpty ||
                                            decision.isNotEmpty)
                                          const SizedBox(height: 6),
                                        const Text('Outcome / Next Steps:',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        const SizedBox(height: 2),
                                        Text(outcome,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.orangeAccent)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

final _interactionsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, customerId) async {
  final repo = ref.watch(customersRepositoryProvider);
  return repo.getInteractions(customerId);
});

class _InteractionCard extends StatelessWidget {
  final Map<String, dynamic> interaction;
  const _InteractionCard({required this.interaction});

  @override
  Widget build(BuildContext context) {
    final type =
        (interaction['interactionType'] as String? ?? 'CALL').toUpperCase();
    final dateStr =
        interaction['interactionDate'] ?? interaction['createdAt'] ?? '';
    final date = dateStr.toString().isNotEmpty
        ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now()
        : DateTime.now();

    final typeColors = <String, Color>{
      'MEETING': Colors.orangeAccent,
      'CALL': Colors.blueAccent,
      'EMAIL': Colors.purpleAccent,
      'WHATSAPP': Colors.greenAccent,
      'VISIT': Colors.tealAccent,
      'DEMO': Colors.amberAccent,
      'FOLLOWUP': Colors.pinkAccent,
    };

    final typeIcons = <String, IconData>{
      'CALL': Icons.phone_in_talk,
      'EMAIL': Icons.email,
      'WHATSAPP': Icons.chat_bubble_outline,
      'MEETING': Icons.groups,
      'VISIT': Icons.location_on,
      'DEMO': Icons.computer,
      'FOLLOWUP': Icons.event_repeat,
    };

    final cardColor = typeColors[type] ?? AppTheme.primary;
    final icon = typeIcons[type] ?? Icons.info_outline;

    final subject =
        interaction['subject'] as String? ?? 'Client Interaction Log';
    final desc = interaction['description'] as String? ?? '';
    final outcome = interaction['outcome'] as String? ?? '';
    final hostName = interaction['assignedToName'] ??
        interaction['createdByName'] ??
        interaction['nextFollowUpHostName'];
    final hostRole = interaction['assignedToRole'];
    final isImportant = interaction['isImportantMeeting'] == true ||
        outcome.contains('Formal Meeting');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isImportant
              ? Colors.amber.withValues(alpha: 0.8)
              : AppTheme.darkBorder,
          width: isImportant ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              border:
                  const Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, color: cardColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: cardColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: cardColor),
                      ),
                    ),
                    if (isImportant) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.amber),
                            SizedBox(width: 3),
                            Text('FORMAL MEETING',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Content Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject Title
                Text(
                  subject,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),

                // Host / Staff Info Badge
                if (hostName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_pin,
                          size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      const Text(
                        'Meeting Host / Staff: ',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        '$hostName${hostRole != null ? " ($hostRole)" : ""}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],

                // Discussion Notes Box
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes, size: 13, color: Colors.white70),
                            SizedBox(width: 6),
                            Text('Discussion Notes / Details',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],

                // Outcome / Decision Box
                if (outcome.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 14, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Text('Agreed Decision / Outcome',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outcome,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],

                // Attached Files / Media Chips
                if ((interaction['attachmentUrl'] != null &&
                        (interaction['attachmentUrl'] as String).isNotEmpty) ||
                    (interaction['audioUrl'] != null &&
                        (interaction['audioUrl'] as String).isNotEmpty) ||
                    (interaction['photoUrl'] != null &&
                        (interaction['photoUrl'] as String).isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.darkBorder, height: 1),
                  const SizedBox(height: 10),
                  const Text('Attached Media & Files:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (interaction['photoUrl'] != null &&
                          (interaction['photoUrl'] as String).isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.photo,
                              size: 16, color: Colors.teal),
                          label: Text(
                              'Photo: ${(interaction['photoUrl'] as String).split('/').last}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          backgroundColor: Colors.teal.withValues(alpha: 0.2),
                          side: const BorderSide(color: Colors.teal),
                          onPressed: () => _showMediaPreviewDialog(
                              context,
                              interaction['photoUrl'] as String,
                              'PHOTO',
                              'Site Photo'),
                        ),
                      if (interaction['audioUrl'] != null &&
                          (interaction['audioUrl'] as String).isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.mic,
                              size: 16, color: Colors.blueAccent),
                          label: Text(
                              'Voice Note: ${(interaction['audioUrl'] as String).split('/').last}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                          side: const BorderSide(color: Colors.blue),
                          onPressed: () => _showMediaPreviewDialog(
                              context,
                              interaction['audioUrl'] as String,
                              'AUDIO',
                              'Voice Note'),
                        ),
                      if (interaction['attachmentUrl'] != null &&
                          (interaction['attachmentUrl'] as String).isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.insert_drive_file,
                              size: 16, color: AppTheme.primary),
                          label: Text(
                              'Document: ${(interaction['attachmentUrl'] as String).split('/').last}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.2),
                          side: const BorderSide(color: AppTheme.primary),
                          onPressed: () => _showMediaPreviewDialog(
                              context,
                              interaction['attachmentUrl'] as String,
                              'DOCUMENT',
                              'Document Attachment'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  final String customerId;
  const _TimelineTab({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(customerTimelineProvider(customerId));

    return timelineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child:
              Text(e.toString(), style: const TextStyle(color: Colors.grey))),
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off,
                    size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 12),
                const Text('No timeline activity recorded yet',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ev = events[index] as Map<String, dynamic>;
            final type = ev['type'] as String? ?? 'EVENT';
            final title = ev['title'] as String? ?? 'Activity';
            final desc = ev['description'] as String? ?? '';
            final dateStr = (ev['date'] ?? ev['timestamp'] ?? '').toString();
            final formattedDate =
                dateStr.isNotEmpty ? dateStr.split('T')[0] : '';
            final status = ev['status'] as String? ?? '';
            final metadata = ev['metadata'] is Map
                ? Map<String, dynamic>.from(ev['metadata'] as Map)
                : <String, dynamic>{};
            final media = (metadata['media'] as List? ?? [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where((item) =>
                    item['url'] is String && (item['url'] as String).isNotEmpty)
                .toList();

            IconData icon = Icons.circle_outlined;
            Color iconColor = AppTheme.primary;

            if (type == 'LEAD') {
              icon = Icons.flag_outlined;
              iconColor = Colors.blue;
            } else if (type == 'ENQUIRY') {
              icon = Icons.question_answer_outlined;
              iconColor = Colors.orange;
            } else if (type == 'OPPORTUNITY') {
              icon = Icons.monetization_on_outlined;
              iconColor = Colors.green;
            } else if (type == 'CALL') {
              icon = Icons.phone;
              iconColor = Colors.purple;
            } else if (type == 'MEETING') {
              icon = Icons.groups_outlined;
              iconColor = Colors.indigo;
            } else if (type == 'SITE_VISIT') {
              icon = Icons.location_on_outlined;
              iconColor = Colors.teal;
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(type,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: iconColor)),
                            Text(formattedDate,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(desc,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                        if (media.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: media.map((item) {
                              final mediaType =
                                  item['type'] as String? ?? 'DOCUMENT';
                              final mediaUrl = item['url'] as String;
                              final label =
                                  item['title'] as String? ?? mediaType;
                              final mediaIcon = mediaType == 'PHOTO'
                                  ? Icons.image_outlined
                                  : mediaType == 'AUDIO'
                                      ? Icons.audiotrack
                                      : Icons.insert_drive_file_outlined;
                              return ActionChip(
                                avatar:
                                    Icon(mediaIcon, size: 16, color: iconColor),
                                label: Text(label),
                                onPressed: () => _showMediaPreviewDialog(
                                  context,
                                  mediaUrl,
                                  mediaType,
                                  label,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (status.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status,
                                style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OpportunitiesTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _OpportunitiesTab({required this.customer});

  @override
  Widget build(BuildContext context) {
    final opps = (customer['opportunities'] as List? ?? []);

    if (opps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_outlined,
                size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            const Text('No opportunities logged for this customer',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: opps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final opp = opps[index] as Map<String, dynamic>;
        final val = (opp['estimatedValue'] ?? 0) as num;
        final prob = opp['probability'] ?? 0;
        final stage = opp['stage'] ?? 'NEW';

        return Container(
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
                  Text(opp['opportunityNumber'] ?? 'DEAL',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(stage,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(opp['productInterest'] ?? 'Engineered Panel System',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(opp['requirement'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('₹${val.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.green)),
                  Text('$prob% Probability',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EnquiriesTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _EnquiriesTab({required this.customer});

  @override
  Widget build(BuildContext context) {
    final enquiries = (customer['enquiries'] as List? ?? []);

    if (enquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.question_answer_outlined,
                size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            const Text('No enquiries recorded for this customer',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: enquiries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final enq = enquiries[index] as Map<String, dynamic>;
        final qty = enq['quantity'] ?? 1;
        final val = (enq['expectedValue'] ?? 0) as num;
        final status = enq['status'] ?? 'PENDING';

        return Container(
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
                  Text(enq['enquiryNumber'] ?? 'ENQ',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(status,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(enq['productInterest'] ?? 'Panel Requirement',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(enq['requirement'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Qty: $qty unit(s)',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  Text('₹${val.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.primary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PanelsTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _PanelsTab({required this.customer});

  @override
  Widget build(BuildContext context) {
    final panels = (customer['panelSpecifications'] as List? ?? []);

    if (panels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.precision_manufacturing_outlined,
                size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            const Text('No panel specifications associated',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: panels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = panels[index] as Map<String, dynamic>;
        final code = p['panelCode'] ?? '';
        final type = p['panelType'] ?? 'PANEL';
        final hp = p['pumpHp'] ?? 0;
        final price = (p['finalPrice'] ?? 0) as num;

        return Container(
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
                  Text(code,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(p['status'] ?? 'ACTIVE',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text('$type ($hp HP)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              Text('Price: ₹${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}

String _resolveMediaUrl(String url) {
  // If already absolute URL (http/https), use as-is
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  // If it's a relative path from the backend, prefix with backend base URL
  final base = AppConstants.baseUrl.replaceAll('/api/v1', '');
  final clean = url.startsWith('/') ? url : '/$url';
  return '$base$clean';
}

void _showMediaPreviewDialog(
    BuildContext context, String rawUrl, String type, String title) {
  final url = _resolveMediaUrl(rawUrl);
  final filename = rawUrl.split('/').last;
  final lowerUrl = rawUrl.toLowerCase();
  final isImage = type == 'PHOTO' ||
      lowerUrl.endsWith('.png') ||
      lowerUrl.endsWith('.jpg') ||
      lowerUrl.endsWith('.jpeg') ||
      lowerUrl.endsWith('.webp');
  final isAudio = type == 'AUDIO' ||
      lowerUrl.endsWith('.mp3') ||
      lowerUrl.endsWith('.wav') ||
      lowerUrl.endsWith('.m4a');

  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isImage
                          ? Icons.image
                          : (isAudio
                              ? Icons.audiotrack
                              : Icons.insert_drive_file),
                      color: AppTheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: AppTheme.darkBorder, height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                children: [
                  if (isImage) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image_outlined,
                                    size: 48, color: Colors.teal),
                                const SizedBox(height: 10),
                                Text(filename,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                const Text('Site Photo / Screenshot Attachment',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else if (isAudio) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_fill,
                              size: 40, color: Colors.blue),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(filename,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                const Text(
                                    'Voice Note / Audio Recording Attachment',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 40, color: AppTheme.primary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(filename,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                const Text(
                                    'Document Attachment (PDF / DOCX / XLSX / ANY Format)',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          url,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Close'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => openWebUrl(url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('VIEW / DOWNLOAD FILE'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddInteractionForm extends ConsumerStatefulWidget {
  final String customerId;
  final VoidCallback onSuccess;

  const _AddInteractionForm(
      {required this.customerId, required this.onSuccess});

  @override
  ConsumerState<_AddInteractionForm> createState() =>
      _AddInteractionFormState();
}

class _AddInteractionFormState extends ConsumerState<_AddInteractionForm> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'CALL';
  StaffMember? _selectedStaff;
  StaffMember? _nextFollowUpHost;
  bool _isImportantMeeting = false;
  TimeOfDay? _nextFollowUpTime;
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  final _outcomeController = TextEditingController();
  final _attachmentUrlController = TextEditingController();
  final _audioUrlController = TextEditingController();
  final _photoUrlController = TextEditingController();
  String? _attachmentDocumentId;
  String? _audioDocumentId;
  String? _photoDocumentId;
  DateTime? _nextFollowUpDate;
  bool _isLoading = false;
  bool _isUploading = false;
  late Future<List<StaffMember>> _staffListFuture;

  @override
  void initState() {
    super.initState();
    _staffListFuture = ref.read(staffRepositoryProvider).getStaffList();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descController.dispose();
    _outcomeController.dispose();
    _attachmentUrlController.dispose();
    _audioUrlController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _pickAndUploadFile(String fieldType, TextEditingController controller) {
    pickAndUploadWebFile(
      fieldType: fieldType,
      onFilePicked: (fileName, bytes) async {
        setState(() => _isUploading = true);
        try {
          final repo = ref.read(customersRepositoryProvider);
          final res = await repo.uploadDocument(
            bytes: bytes,
            fileName: fileName,
            entityType: 'CUSTOMER_INTERACTION_PENDING',
            entityId: widget.customerId,
            documentType: fieldType,
          );
          final uploadedUrl =
              res['filePath'] ?? res['fileUrl'] ?? res['url'] ?? '';
          setState(() {
            if (uploadedUrl.toString().isNotEmpty) {
              controller.text = uploadedUrl.toString();
            }
            if (identical(controller, _attachmentUrlController)) {
              _attachmentDocumentId = res['id']?.toString();
            } else if (identical(controller, _audioUrlController)) {
              _audioDocumentId = res['id']?.toString();
            } else if (identical(controller, _photoUrlController)) {
              _photoDocumentId = res['id']?.toString();
            }
          });
          ref.invalidate(_customerDocumentsProvider(widget.customerId));
          ref.invalidate(_interactionsProvider(widget.customerId));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File "$fileName" uploaded successfully ✓'),
                backgroundColor: AppTheme.success,
              ),
            );
          }
        } catch (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload error: $err'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      },
    );
  }

  void _clearUploadedDocumentId(TextEditingController controller) {
    if (identical(controller, _attachmentUrlController)) {
      _attachmentDocumentId = null;
    } else if (identical(controller, _audioUrlController)) {
      _audioDocumentId = null;
    } else if (identical(controller, _photoUrlController)) {
      _photoDocumentId = null;
    }
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70),
          ),
          if (isRequired)
            const Text(' *',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customersRepositoryProvider);

      String outcomeText = _outcomeController.text.trim();
      final followUpInfo = <String>[];
      if (_nextFollowUpHost != null) {
        followUpInfo.add('Host: ${_nextFollowUpHost!.fullName}');
      }
      if (_nextFollowUpTime != null && mounted) {
        followUpInfo.add('Time: ${_nextFollowUpTime!.format(context)}');
      }
      if (_isImportantMeeting) {
        followUpInfo.add('Status: Scheduled Formal Meeting (HIGH PRIORITY)');
      }

      if (followUpInfo.isNotEmpty) {
        final followUpSummary =
            '[Next Follow-up & Scheduled Meeting: ${followUpInfo.join(' | ')}]';
        if (outcomeText.isNotEmpty) {
          outcomeText = '$outcomeText\n$followUpSummary';
        } else {
          outcomeText = followUpSummary;
        }
      }

      await repo.recordInteraction(widget.customerId, {
        'interactionType': _type,
        'subject': _subjectController.text.trim(),
        'description': _descController.text.trim(),
        'outcome': outcomeText,
        'assignedToId': _selectedStaff?.id,
        'assignedToName': _selectedStaff?.fullName,
        'assignedToRole':
            _selectedStaff?.designationName ?? _selectedStaff?.departmentName,
        'nextFollowUpHostId': _nextFollowUpHost?.id,
        'nextFollowUpHostName': _nextFollowUpHost?.fullName,
        'isImportantMeeting': _isImportantMeeting,
        'nextFollowUpTime': _nextFollowUpTime != null
            ? '${_nextFollowUpTime!.hour.toString().padLeft(2, '0')}:${_nextFollowUpTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'attachmentUrl': _attachmentUrlController.text.trim().isEmpty
            ? null
            : _attachmentUrlController.text.trim(),
        'audioUrl': _audioUrlController.text.trim().isEmpty
            ? null
            : _audioUrlController.text.trim(),
        'photoUrl': _photoUrlController.text.trim().isEmpty
            ? null
            : _photoUrlController.text.trim(),
        'attachmentDocumentId': _attachmentDocumentId,
        'audioDocumentId': _audioDocumentId,
        'photoDocumentId': _photoDocumentId,
        'nextFollowUp': _nextFollowUpDate?.toIso8601String(),
        'interactionDate': DateTime.now().toIso8601String(),
      });

      ref.invalidate(_interactionsProvider(widget.customerId));
      ref.invalidate(_customerDocumentsProvider(widget.customerId));
      ref.invalidate(customerTimelineProvider(widget.customerId));

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Interaction & Meeting recorded successfully'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.rate_review_outlined,
                    color: AppTheme.primary, size: 22),
                SizedBox(width: 8),
                Text('Record Interaction & Meeting',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const Divider(color: AppTheme.darkBorder, height: 20),
        Flexible(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Interaction Type
                  _buildFieldLabel('Interaction / Activity Type',
                      isRequired: true),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: InputDecoration(
                      hintText: 'Select interaction type',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.primary)),
                      fillColor: AppTheme.darkCard,
                      filled: true,
                    ),
                    dropdownColor: AppTheme.darkCard,
                    items: [
                      'MEETING',
                      'CALL',
                      'EMAIL',
                      'WHATSAPP',
                      'VISIT',
                      'DEMO',
                      'FOLLOWUP'
                    ]
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(t.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 12),

                  // Select Admin or Employee (Meeting Host / Assigned Staff)
                  _buildFieldLabel(
                      'Select Admin / Employee (Meeting Host / Staff)'),
                  FutureBuilder<List<StaffMember>>(
                    future: _staffListFuture,
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
                              Text('Loading staff directory...',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        );
                      }
                      final staffList = snapshot.data ?? [];
                      return DropdownButtonFormField<StaffMember>(
                        initialValue: _selectedStaff,
                        decoration: InputDecoration(
                          hintText: 'Select Admin or Employee to assign/host',
                          prefixIcon: const Icon(Icons.person_pin,
                              size: 18, color: AppTheme.primary),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppTheme.darkBorder)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppTheme.darkBorder)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppTheme.primary)),
                          fillColor: AppTheme.darkCard,
                          filled: true,
                        ),
                        dropdownColor: AppTheme.darkCard,
                        items: staffList.map((staff) {
                          final roleLabel = staff.designationName ??
                              staff.departmentName ??
                              'Employee';
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
                            setState(() => _selectedStaff = val),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Subject
                  _buildFieldLabel('Subject', isRequired: true),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Discussed panel specs & pricing',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.primary)),
                      fillColor: AppTheme.darkCard,
                      filled: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Subject is required'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Discussion Notes
                  _buildFieldLabel('Discussion Notes / Details'),
                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      hintText: 'Key points discussed during call/visit...',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.primary)),
                      fillColor: AppTheme.darkCard,
                      filled: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

                  // Outcome / Decision
                  _buildFieldLabel('Outcome / Agreed Decision'),
                  TextFormField(
                    controller: _outcomeController,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Next follow-up agreed for quotation review',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.darkBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.primary)),
                      fillColor: AppTheme.darkCard,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Direct Upload Section
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
                        const Row(
                          children: [
                            Icon(Icons.attach_file,
                                color: AppTheme.primary, size: 16),
                            SizedBox(width: 6),
                            Text(
                                'Optional Attachments & Direct File Upload (Any Format)',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Document Upload (PDF, Word, Excel, ZIP, Any Format)
                        _buildFieldLabel(
                            'Upload Document / File Link (PDF, DOCX, XLSX, ANY)'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _attachmentUrlController,
                                onChanged: (_) => _clearUploadedDocumentId(
                                    _attachmentUrlController),
                                decoration: InputDecoration(
                                  hintText: 'File URL or click Upload button',
                                  prefixIcon: const Icon(
                                      Icons.description_outlined,
                                      size: 18),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: AppTheme.darkBorder)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: AppTheme.darkBorder)),
                                  fillColor: AppTheme.darkCard,
                                  filled: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isUploading
                                  ? null
                                  : () => _pickAndUploadFile(
                                      'DOCUMENT', _attachmentUrlController),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppTheme.primary.withValues(alpha: 0.2),
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: const BorderSide(
                                        color: AppTheme.primary)),
                              ),
                              icon: const Icon(Icons.upload_file, size: 16),
                              label: const Text('UPLOAD',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Audio Recording Upload
                        _buildFieldLabel(
                            'Audio Recording / Voice Note (MP3, WAV, M4A)'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _audioUrlController,
                                onChanged: (_) => _clearUploadedDocumentId(
                                    _audioUrlController),
                                decoration: InputDecoration(
                                  hintText: 'Audio URL or click Upload button',
                                  prefixIcon:
                                      const Icon(Icons.mic_outlined, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: AppTheme.darkBorder)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: AppTheme.darkBorder)),
                                  fillColor: AppTheme.darkCard,
                                  filled: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isUploading
                                  ? null
                                  : () => _pickAndUploadFile(
                                      'AUDIO', _audioUrlController),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.blue.withValues(alpha: 0.2),
                                foregroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: const BorderSide(color: Colors.blue)),
                              ),
                              icon: const Icon(Icons.mic, size: 16),
                              label: const Text('UPLOAD',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Screenshot / Site Photo Upload
                        _buildFieldLabel(
                            'Screenshot / Site Photo (PNG, JPG, WEBP)'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _photoUrlController,
                                onChanged: (_) => _clearUploadedDocumentId(
                                    _photoUrlController),
                                decoration: InputDecoration(
                                  hintText: 'Photo URL or click Upload button',
                                  prefixIcon: const Icon(Icons.image_outlined,
                                      size: 18),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: AppTheme.darkBorder)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: AppTheme.darkBorder)),
                                  fillColor: AppTheme.darkCard,
                                  filled: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isUploading
                                  ? null
                                  : () => _pickAndUploadFile(
                                      'PHOTO', _photoUrlController),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.teal.withValues(alpha: 0.2),
                                foregroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: const BorderSide(color: Colors.teal)),
                              ),
                              icon: const Icon(Icons.add_a_photo, size: 16),
                              label: const Text('UPLOAD',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Next Follow-up & Meeting Scheduling Container
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
                        const Row(
                          children: [
                            Icon(Icons.event_note,
                                color: AppTheme.primary, size: 16),
                            SizedBox(width: 6),
                            Text('Next Follow-up & Meeting Scheduling',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Next Follow-up Date
                        _buildFieldLabel('Next Follow-up Date (Optional)'),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _nextFollowUpDate = picked);
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
                                const Icon(Icons.calendar_today_outlined,
                                    size: 18, color: AppTheme.primary),
                                const SizedBox(width: 10),
                                Text(
                                  _nextFollowUpDate != null
                                      ? '${_nextFollowUpDate!.day}/${_nextFollowUpDate!.month}/${_nextFollowUpDate!.year}'
                                      : 'Select Next Follow-up Date',
                                  style: TextStyle(
                                      color: _nextFollowUpDate != null
                                          ? Colors.white
                                          : Colors.grey,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Next Follow-up Assigned Staff / Meeting Host
                        _buildFieldLabel(
                            'Select Admin / Staff (Next Follow-up Host)'),
                        FutureBuilder<List<StaffMember>>(
                          future: _staffListFuture,
                          builder: (context, snapshot) {
                            final staffList = snapshot.data ?? [];
                            return DropdownButtonFormField<StaffMember>(
                              initialValue: _nextFollowUpHost,
                              decoration: InputDecoration(
                                hintText:
                                    'Assign Admin/Staff to host next follow-up',
                                prefixIcon: const Icon(Icons.person_outline,
                                    size: 18, color: AppTheme.primary),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppTheme.darkBorder)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppTheme.darkBorder)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppTheme.primary)),
                                fillColor: AppTheme.darkCard,
                                filled: true,
                              ),
                              dropdownColor: AppTheme.darkCard,
                              items: staffList.map((staff) {
                                return DropdownMenuItem<StaffMember>(
                                  value: staff,
                                  child: Text(
                                      '${staff.fullName} (${staff.employeeId})',
                                      style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _nextFollowUpHost = val),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Important Meeting Toggle Switch
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _isImportantMeeting
                                    ? AppTheme.primary.withValues(alpha: 0.5)
                                    : AppTheme.darkBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Important / Schedule Formal Meeting',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _isImportantMeeting,
                                activeThumbColor: AppTheme.primary,
                                onChanged: (val) =>
                                    setState(() => _isImportantMeeting = val),
                              ),
                            ],
                          ),
                        ),

                        // Scheduled Meeting Time Picker (if Important is enabled)
                        if (_isImportantMeeting) ...[
                          const SizedBox(height: 12),
                          _buildFieldLabel('Scheduled Meeting Time'),
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    const TimeOfDay(hour: 10, minute: 30),
                              );
                              if (picked != null) {
                                setState(() => _nextFollowUpTime = picked);
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
                                  const Icon(Icons.access_time_filled,
                                      size: 18, color: Colors.amber),
                                  const SizedBox(width: 10),
                                  Text(
                                    _nextFollowUpTime != null
                                        ? _nextFollowUpTime!.format(context)
                                        : 'Tap to select Meeting Time (e.g. 10:30 AM)',
                                    style: TextStyle(
                                        color: _nextFollowUpTime != null
                                            ? Colors.white
                                            : Colors.grey,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _isUploading) ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(
                          _isLoading ? 'Saving...' : 'RECORD INTERACTION',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final nonNull = children
        .whereType<_InfoRow>()
        .where((r) => r.value != null && r.value!.isNotEmpty)
        .toList();
    if (nonNull.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
              ],
            ),
            const Divider(height: 20),
            ...nonNull,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(child: Text(value!, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppTheme.darkSurface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

// ─── Quotations & Sales Orders Tab ──────────────────────────────────────────

class _QuotationsAndOrdersTab extends ConsumerStatefulWidget {
  final String customerId;
  const _QuotationsAndOrdersTab({required this.customerId});

  @override
  ConsumerState<_QuotationsAndOrdersTab> createState() =>
      _QuotationsAndOrdersTabState();
}

class _QuotationsAndOrdersTabState
    extends ConsumerState<_QuotationsAndOrdersTab> {
  List<dynamic> _quotations = [];
  List<dynamic> _salesOrders = [];
  List<dynamic> _invoices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(salesRepositoryProvider);
      final quotesRes = await repo.getQuotations(customerId: widget.customerId);
      final ordersRes =
          await repo.getSalesOrders(customerId: widget.customerId);
      final invoicesRes = await repo.getInvoices(customerId: widget.customerId);

      setState(() {
        _quotations = quotesRes['items'] as List<dynamic>? ?? [];
        _salesOrders = ordersRes['items'] as List<dynamic>? ?? [];
        _invoices = invoicesRes['items'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load quotations: $_error',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Action Card: Create new quote for this customer
        Card(
          elevation: 1,
          color: AppTheme.primaryColor.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side:
                BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commercial Proposals',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Create new revision or proposal',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    context
                        .push(
                            '/crm/quotations/new?customerId=${widget.customerId}')
                        .then((_) => _loadData());
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Quote'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section 1: Commercial Quotations
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quotations (${_quotations.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadData),
          ],
        ),
        const SizedBox(height: 8),

        if (_quotations.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: const Center(
              child: Text('No quotations generated for this company yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._quotations.map((q) {
            final code = q['code'] as String? ?? q['quotationNumber'] ?? 'QUO';
            final revision = q['revisionNumber'] ?? 0;
            final status = q['status'] as String? ?? 'DRAFT';
            final total = (q['grandTotal'] as num?)?.toDouble() ?? 0;
            final date = q['createdAt'] != null
                ? DateFormat('dd MMM yyyy')
                    .format(DateTime.parse(q['createdAt']))
                : '-';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => context
                    .push('/crm/quotations/${q['id']}')
                    .then((_) => _loadData()),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.request_quote_outlined,
                      color: AppTheme.primaryColor),
                ),
                title: Row(
                  children: [
                    Text(code,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('REV-$revision',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.indigo.shade800,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                subtitle: Text('${q['subject'] ?? 'Proposal'} • $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currencyFormatter.format(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(status,
                        style: TextStyle(
                            fontSize: 10,
                            color: status == 'ACCEPTED'
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 20),

        // Section 2: Confirmed Sales Orders
        Text('Confirmed Sales Orders (${_salesOrders.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),

        if (_salesOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: const Center(
              child: Text('No sales orders for this customer yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._salesOrders.map((so) {
            final orderNumber = so['orderNumber'] as String? ?? 'SO';
            final status = so['status'] as String? ?? 'CONFIRMED';
            final prodStatus = so['productionStatus'] as String? ?? 'PENDING';
            final total = (so['grandTotal'] as num?)?.toDouble() ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => context.push('/crm/sales-orders'),
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withValues(alpha: 0.1),
                  child: const Icon(Icons.assignment_turned_in_outlined,
                      color: Colors.purple),
                ),
                title: Text(orderNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                    'Shopfloor: $prodStatus ${so['poNumber'] != null ? '• PO: ' + so['poNumber'] : ''}',
                    style: const TextStyle(fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currencyFormatter.format(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(status,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.purple,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 20),

        // Section 3: Tax Invoices & Billing
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tax Invoices & Billing (${_invoices.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(
              onPressed: () =>
                  context.push('/sales/invoices').then((_) => _loadData()),
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Manage Invoices'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_invoices.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: const Center(
              child: Text('No tax invoices generated for this company yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._invoices.map((inv) {
            final invNum = inv['invoiceNumber'] as String? ?? 'INV';
            final status = inv['paymentStatus'] as String? ?? 'UNPAID';
            final total = (inv['grandTotal'] as num?)?.toDouble() ?? 0;
            final balance = (inv['balanceDue'] as num?)?.toDouble() ?? 0;
            final date = inv['invoiceDate'] != null
                ? DateFormat('dd MMM yyyy')
                    .format(DateTime.parse(inv['invoiceDate']))
                : '-';

            Color statusColor = Colors.grey;
            if (status == 'PAID') {
              statusColor = Colors.green;
            } else if (status == 'PARTIALLY_PAID') {
              statusColor = Colors.orange;
            } else if (status == 'UNPAID') {
              statusColor = Colors.blueGrey;
            } else if (status == 'OVERDUE') {
              statusColor = Colors.redAccent;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () =>
                    context.push('/sales/invoices').then((_) => _loadData()),
                leading: CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(Icons.receipt_long_outlined, color: statusColor),
                ),
                title: Row(
                  children: [
                    Text(invNum,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                            fontSize: 9,
                            color: statusColor,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                    'Date: $date • Due: ${currencyFormatter.format(balance)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(currencyFormatter.format(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      balance > 0
                          ? 'Bal: ${currencyFormatter.format(balance)}'
                          : 'Settled',
                      style: TextStyle(
                          fontSize: 11,
                          color: balance > 0 ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 30),
      ],
    );
  }
}
