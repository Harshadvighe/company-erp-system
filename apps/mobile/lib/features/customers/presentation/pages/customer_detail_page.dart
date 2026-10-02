import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';

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
    _tabController = TabController(length: 6, vsync: this);
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, __) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(e.toString(), style: const TextStyle(color: Colors.grey)),
              TextButton(onPressed: () => context.pop(), child: const Text('Go Back')),
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
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(customer),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.go('/customers/${widget.customerId}/edit'),
                tooltip: 'Edit Customer',
              ),
              PopupMenuButton(
                itemBuilder: (_) => <PopupMenuEntry>[
                  PopupMenuItem(
                    child: const Row(children: [Icon(Icons.phone, size: 16), SizedBox(width: 8), Text('Call')]),
                    onTap: () {},
                  ),
                  PopupMenuItem(
                    child: const Row(children: [Icon(Icons.chat, size: 16), SizedBox(width: 8), Text('WhatsApp')]),
                    onTap: () {},
                  ),
                  PopupMenuItem(
                    child: const Row(children: [Icon(Icons.email_outlined, size: 16), SizedBox(width: 8), Text('Email')]),
                    onTap: () {},
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    child: const Row(children: [Icon(Icons.add, size: 16), SizedBox(width: 8), Text('Add Enquiry')]),
                    onTap: () {},
                  ),
                  PopupMenuItem(
                    child: const Row(children: [Icon(Icons.add, size: 16), SizedBox(width: 8), Text('Record Interaction')]),
                    onTap: () => _showAddInteractionDialog(customer['id'] as String),
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
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Contacts'),
                  Tab(text: 'Interactions'),
                  Tab(text: 'Enquiries'),
                  Tab(text: 'Leads'),
                  Tab(text: 'Panels'),
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
            _InteractionsTab(customerId: widget.customerId),
            _PlaceholderTab(label: 'Enquiries'),
            _PlaceholderTab(label: 'Leads'),
            _PlaceholderTab(label: 'Panels'),
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
    final initials = companyName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Container(
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.primary.withOpacity(0.2),
            child: Text(initials, style: const TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(companyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Badge(label: c['customerType'] as String? ?? '', color: AppTheme.primary),
                    const SizedBox(width: 8),
                    _Badge(label: c['status'] as String? ?? '', color: AppTheme.success),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c['customerCode'] as String? ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddInteractionDialog(String customerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddInteractionSheet(customerId: customerId, onSuccess: _refresh),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _OverviewTab({required this.customer});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Contact Information',
          icon: Icons.contact_phone,
          children: [
            _InfoRow(label: 'Contact Person', value: customer['contactPerson']),
            _InfoRow(label: 'Designation', value: customer['designation']),
            _InfoRow(label: 'Email', value: customer['email']),
            _InfoRow(label: 'Phone', value: customer['phone']),
            _InfoRow(label: 'Alternate Phone', value: customer['alternatePhone']),
            _InfoRow(label: 'Website', value: customer['website']),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Business Information',
          icon: Icons.business,
          children: [
            _InfoRow(label: 'GSTIN', value: customer['gstin']),
            _InfoRow(label: 'PAN', value: customer['pan']),
            _InfoRow(label: 'Industry', value: customer['industry']),
            _InfoRow(label: 'Source', value: customer['source']),
            _InfoRow(label: 'Owner Name', value: customer['ownerName']),
            _InfoRow(label: 'Staff Count', value: customer['staffCount']?.toString()),
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
            Text('${contacts.length} Contact(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    ? AppTheme.primary.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                child: Icon(
                  Icons.person,
                  color: contact['isPrimary'] == true ? AppTheme.primary : Colors.grey,
                  size: 18,
                ),
              ),
              title: Row(
                children: [
                  Text(contact['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (contact['isPrimary'] == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Primary', style: TextStyle(fontSize: 9, color: AppTheme.primary)),
                    ),
                  ],
                ],
              ),
              subtitle: Text('${contact['designation'] ?? ''} · ${contact['mobile'] ?? ''}',
                  style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.phone, size: 16), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.chat, size: 16), onPressed: () {}),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _InteractionsTab extends ConsumerWidget {
  final String customerId;
  const _InteractionsTab({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interactionsAsync = ref.watch(_interactionsProvider(customerId));

    return interactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text(e.toString())),
      data: (interactions) {
        if (interactions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No interactions recorded yet'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: interactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final interaction = interactions[i] as Map<String, dynamic>;
            return _InteractionCard(interaction: interaction);
          },
        );
      },
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
    final type = interaction['interactionType'] as String? ?? 'CALL';
    final date = interaction['interactionDate'] != null
        ? DateTime.parse(interaction['interactionDate'] as String)
        : DateTime.now();

    final typeIcons = {
      'CALL': Icons.phone,
      'EMAIL': Icons.email,
      'WHATSAPP': Icons.chat,
      'MEETING': Icons.meeting_room,
      'VISIT': Icons.directions_car,
      'DEMO': Icons.computer,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(typeIcons[type] ?? Icons.info, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                  if (interaction['subject'] != null)
                    Text(interaction['subject'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  if (interaction['description'] != null)
                    Text(interaction['description'] as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (interaction['outcome'] != null)
                    Text('Outcome: ${interaction['outcome']}', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Text('Coming in Phase 2', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AddInteractionSheet extends ConsumerStatefulWidget {
  final String customerId;
  final VoidCallback onSuccess;

  const _AddInteractionSheet({required this.customerId, required this.onSuccess});

  @override
  ConsumerState<_AddInteractionSheet> createState() => _AddInteractionSheetState();
}

class _AddInteractionSheetState extends ConsumerState<_AddInteractionSheet> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'CALL';
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  final _outcomeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.85,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: controller,
              children: [
                const Text('Record Interaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Interaction Type'),
                  items: ['CALL', 'EMAIL', 'WHATSAPP', 'MEETING', 'VISIT', 'DEMO', 'FOLLOWUP']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _outcomeController,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Interaction'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customersRepositoryProvider);
      await repo.recordInteraction(widget.customerId, {
        'interactionType': _type,
        'subject': _subjectController.text,
        'description': _descController.text,
        'outcome': _outcomeController.text,
        'interactionDate': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interaction recorded'), backgroundColor: AppTheme.success),
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final nonNull = children.whereType<_InfoRow>().where((r) => r.value != null && r.value!.isNotEmpty).toList();
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
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppTheme.darkSurface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
