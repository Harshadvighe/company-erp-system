import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';

class CustomersListPage extends ConsumerStatefulWidget {
  const CustomersListPage({super.key});

  @override
  ConsumerState<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends ConsumerState<CustomersListPage> {
  final _searchController = TextEditingController();
  String? _filterType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerListProvider.notifier).loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(customerListProvider.notifier).loadCustomers(search: value, type: _filterType);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerListProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(isWide),
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

  Widget _buildHeader(bool isWide) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filterType,
              hint: const Text('All Types', style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                ...['END_CUSTOMER', 'DEALER', 'DISTRIBUTOR', 'OEM', 'GOVERNMENT']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ')))),
              ],
              onChanged: (v) {
                setState(() => _filterType = v);
                ref.read(customerListProvider.notifier).loadCustomers(
                      search: _searchController.text,
                      type: v,
                    );
              },
            ),
          ),
          if (isWide) ...[
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataTable(CustomerListState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
              columns: const [
                DataColumn(label: Text('Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Company', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('City', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              rows: state.customers.map((c) {
                return DataRow(
                  onSelectChanged: (_) => context.go('/customers/${c.id}'),
                  cells: [
                    DataCell(Text(c.customerCode,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.primary))),
                    DataCell(Row(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.primary.withOpacity(0.2),
                        child: Text(c.initials, style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(c.companyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    ])),
                    DataCell(Text(c.contactPerson, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(c.phone, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(c.city, style: const TextStyle(fontSize: 12))),
                    DataCell(_TypeBadge(type: c.customerType)),
                    DataCell(_StatusBadge(status: c.status)),
                    DataCell(Row(children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        onPressed: () => context.go('/customers/${c.id}'),
                        tooltip: 'View',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        onPressed: () => context.go('/customers/${c.id}/edit'),
                        tooltip: 'Edit',
                        visualDensity: VisualDensity.compact,
                      ),
                    ])),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text('${state.total} customers found', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
        return Card(
          child: ListTile(
            onTap: () => context.go('/customers/${c.id}'),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(c.initials, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            title: Text(c.companyName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.contactPerson} · ${c.phone}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                Text(c.city, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _TypeBadge(type: c.customerType),
                const SizedBox(height: 4),
                _StatusBadge(status: c.status),
              ],
            ),
            isThreeLine: true,
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
          const Text('No customers found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add your first customer to get started', style: TextStyle(color: Colors.grey)),
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
          Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(customerListProvider.notifier).loadCustomers(),
            child: const Text('Retry'),
          ),
        ],
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        type.replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
