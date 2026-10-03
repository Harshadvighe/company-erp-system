import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';

class EnquiriesListPage extends ConsumerStatefulWidget {
  const EnquiriesListPage({super.key});

  @override
  ConsumerState<EnquiriesListPage> createState() => _EnquiriesListPageState();
}

class _EnquiriesListPageState extends ConsumerState<EnquiriesListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  final _statusFilters = ['ALL', 'PENDING', 'QUOTED', 'CLOSED_WON', 'CLOSED_LOST'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final status = _statusFilters[_tabController.index];
        ref.read(enquiryListProvider.notifier).loadEnquiries(status: status == 'ALL' ? null : status);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(enquiryListProvider.notifier).loadEnquiries();
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
    final state = ref.watch(enquiryListProvider);

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.darkBorder))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      final status = _statusFilters[_tabController.index];
                      ref.read(enquiryListProvider.notifier).loadEnquiries(search: v, status: status == 'ALL' ? null : status);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search enquiries…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showCreateEnquirySheet(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Enquiry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppTheme.darkSurface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              tabs: _statusFilters.map((s) => Tab(text: s.replaceAll('_', ' '))).toList(),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text(state.error!, style: const TextStyle(color: Colors.grey)))
                    : state.enquiries.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: state.enquiries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _EnquiryCard(enquiry: state.enquiries[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text('No enquiries found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateEnquirySheet,
            icon: const Icon(Icons.add),
            label: const Text('Create Enquiry'),
          ),
        ],
      ),
    );
  }

  void _showCreateEnquirySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EnquiryFormSheet(onSuccess: () {
        ref.read(enquiryListProvider.notifier).loadEnquiries();
      }),
    );
  }
}

class _EnquiryCard extends StatelessWidget {
  final Map<String, dynamic> enquiry;
  const _EnquiryCard({required this.enquiry});

  @override
  Widget build(BuildContext context) {
    final status = enquiry['status'] as String? ?? 'PENDING';
    final priority = enquiry['priority'] as String? ?? 'MEDIUM';
    final customer = enquiry['customer'] as Map<String, dynamic>?;
    final followUp = enquiry['followUpDate'] != null ? DateTime.tryParse(enquiry['followUpDate'] as String) : null;
    final isOverdue = followUp != null && followUp.isBefore(DateTime.now());

    const statusColors = {
      'PENDING': Color(0xFFF59E0B),
      'QUOTED': Color(0xFF3B82F6),
      'CLOSED_WON': Color(0xFF22C55E),
      'CLOSED_LOST': Color(0xFFEF4444),
    };
    const priorityColors = {
      'LOW': Color(0xFF22C55E),
      'MEDIUM': Color(0xFF3B82F6),
      'HIGH': Color(0xFFF59E0B),
      'URGENT': Color(0xFFEF4444),
    };

    final statusColor = statusColors[status] ?? Colors.grey;
    final priorityColor = priorityColors[priority] ?? Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(enquiry['enquiryNumber'] as String? ?? '', style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontFamily: 'monospace')),
                      if (customer != null)
                        Text(customer['companyName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                _Badge(label: priority, color: priorityColor),
                const SizedBox(width: 6),
                _Badge(label: status.replaceAll('_', ' '), color: statusColor),
              ],
            ),
            if (enquiry['productInterest'] != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.category_outlined, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(enquiry['productInterest'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (enquiry['quantity'] != null) ...[
                  const SizedBox(width: 8),
                  Text('Qty: ${enquiry['quantity']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ]),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (enquiry['assignedTo'] != null) ...[
                  const Icon(Icons.person_outline, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(enquiry['assignedTo'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                if (enquiry['expectedValue'] != null) ...[
                  const Spacer(),
                  Text('₹${enquiry['expectedValue']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
                ],
              ],
            ),
            if (followUp != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.schedule, size: 13, color: isOverdue ? AppTheme.error : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Follow-up: ${followUp.day}/${followUp.month}/${followUp.year}',
                  style: TextStyle(fontSize: 11, color: isOverdue ? AppTheme.error : Colors.grey),
                ),
                if (isOverdue) ...[
                  const SizedBox(width: 4),
                  const Text('OVERDUE', style: TextStyle(fontSize: 9, color: AppTheme.error, fontWeight: FontWeight.bold)),
                ],
              ]),
            ],
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EnquiryFormSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _EnquiryFormSheet({required this.onSuccess});

  @override
  ConsumerState<_EnquiryFormSheet> createState() => _EnquiryFormSheetState();
}

class _EnquiryFormSheetState extends ConsumerState<_EnquiryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _productCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _reqCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _assignedCtrl = TextEditingController();
  String? _customerId;
  String _priority = 'MEDIUM';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customerListProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.92,
        initialChildSize: 0.75,
        builder: (_, ctrl) => Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: ctrl,
              children: [
                const Text('New Enquiry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Customer Search
                DropdownButtonFormField<String>(
                  initialValue: _customerId,
                  decoration: const InputDecoration(labelText: 'Customer *'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Select Customer')),
                    ...customersState.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.companyName, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _customerId = v),
                  validator: (v) => v == null ? 'Please select a customer' : null,
                ),
                const SizedBox(height: 12),
                _field(_productCtrl, 'Product Interest *', required: true),
                Row(children: [
                  Expanded(child: _field(_qtyCtrl, 'Quantity', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_valueCtrl, 'Expected Value', keyboardType: TextInputType.number)),
                ]),
                _field(_reqCtrl, 'Requirement Details', maxLines: 2),
                _field(_assignedCtrl, 'Assigned To'),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: AppConstants.priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Create Enquiry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(crmRepositoryProvider);
      await repo.createEnquiry({
        'customerId': _customerId,
        'productInterest': _productCtrl.text.trim(),
        'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
        'requirement': _reqCtrl.text.trim().isEmpty ? null : _reqCtrl.text.trim(),
        'expectedValue': double.tryParse(_valueCtrl.text) ?? 0,
        'assignedTo': _assignedCtrl.text.trim().isEmpty ? null : _assignedCtrl.text.trim(),
        'priority': _priority,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enquiry created'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
