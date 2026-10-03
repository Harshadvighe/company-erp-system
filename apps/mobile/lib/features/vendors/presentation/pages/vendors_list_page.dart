import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/vendors/data/vendors_repository.dart';

class VendorsListPage extends ConsumerStatefulWidget {
  const VendorsListPage({super.key});

  @override
  ConsumerState<VendorsListPage> createState() => _VendorsListPageState();
}

class _VendorsListPageState extends ConsumerState<VendorsListPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vendorListProvider.notifier).loadVendors();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorListProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Text(state.error!, style: const TextStyle(color: Colors.grey)),
                        ElevatedButton(onPressed: () => ref.read(vendorListProvider.notifier).loadVendors(), child: const Text('Retry')),
                      ]))
                    : state.vendors.isEmpty
                        ? _buildEmpty()
                        : isWide
                            ? _buildTable(state.vendors)
                            : _buildCards(state.vendors),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVendorForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New Vendor'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.darkBorder))),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => ref.read(vendorListProvider.notifier).loadVendors(search: v),
        decoration: InputDecoration(
          hintText: 'Search vendors by name, GST, contact…',
          prefixIcon: const Icon(Icons.search, size: 18),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.darkBorder),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> vendors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
          columns: const [
            DataColumn(label: Text('Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Company', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('City', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ],
          rows: vendors.map((v) {
            final status = v['status'] as String? ?? 'ACTIVE';
            return DataRow(cells: [
              DataCell(Text(v['vendorCode'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontFamily: 'monospace'))),
              DataCell(Text(v['companyName'] as String? ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              DataCell(Text(v['contactPerson'] as String? ?? '', style: const TextStyle(fontSize: 12))),
              DataCell(Text(v['phone'] as String? ?? '', style: const TextStyle(fontSize: 12))),
              DataCell(Text(v['city'] as String? ?? '', style: const TextStyle(fontSize: 12))),
              DataCell(_StatusBadge(status: status)),
              DataCell(Row(children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  onPressed: () => _showVendorForm(context, vendor: v),
                  visualDensity: VisualDensity.compact,
                ),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCards(List<Map<String, dynamic>> vendors) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: vendors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = vendors[i];
        final name = v['companyName'] as String? ?? '';
        final initials = name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withValues(alpha: 0.2),
              child: Text(initials, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${v['contactPerson'] ?? ''} · ${v['phone'] ?? ''}', style: const TextStyle(fontSize: 12)),
            trailing: _StatusBadge(status: v['status'] as String? ?? 'ACTIVE'),
            onTap: () => _showVendorForm(context, vendor: v),
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
          Icon(Icons.store_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text('No vendors found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add your first vendor to get started', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showVendorForm(BuildContext context, {Map<String, dynamic>? vendor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VendorFormSheet(vendor: vendor, onSuccess: () {
        ref.read(vendorListProvider.notifier).loadVendors();
      }),
    );
  }
}

class _VendorFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? vendor;
  final VoidCallback onSuccess;

  const _VendorFormSheet({this.vendor, required this.onSuccess});

  @override
  ConsumerState<_VendorFormSheet> createState() => _VendorFormSheetState();
}

class _VendorFormSheetState extends ConsumerState<_VendorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  String _paymentTerms = 'NET_30';
  bool _isLoading = false;

  bool get isEdit => widget.vendor != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final v = widget.vendor!;
      _companyCtrl.text = v['companyName'] as String? ?? '';
      _gstCtrl.text = v['gstin'] as String? ?? '';
      _contactCtrl.text = v['contactPerson'] as String? ?? '';
      _emailCtrl.text = v['email'] as String? ?? '';
      _phoneCtrl.text = v['phone'] as String? ?? '';
      _addressCtrl.text = v['address'] as String? ?? '';
      _cityCtrl.text = v['city'] as String? ?? '';
      _stateCtrl.text = v['state'] as String? ?? '';
      _paymentTerms = v['paymentTerms'] as String? ?? 'NET_30';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text(isEdit ? 'Edit Vendor' : 'New Vendor',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _field(_companyCtrl, 'Company Name *', required: true),
                _field(_gstCtrl, 'GSTIN'),
                _field(_contactCtrl, 'Contact Person *', required: true),
                _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
                _field(_phoneCtrl, 'Phone *', required: true, keyboardType: TextInputType.phone),
                _field(_addressCtrl, 'Address', maxLines: 2),
                Row(children: [
                  Expanded(child: _field(_cityCtrl, 'City')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_stateCtrl, 'State')),
                ]),
                DropdownButtonFormField<String>(
                  initialValue: _paymentTerms,
                  decoration: const InputDecoration(labelText: 'Payment Terms'),
                  items: ['NET_7', 'NET_15', 'NET_30', 'NET_45', 'NET_60', 'ADVANCE', 'IMMEDIATE']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) => setState(() => _paymentTerms = v!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text(isEdit ? 'Update Vendor' : 'Create Vendor'),
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

    final data = {
      'companyName': _companyCtrl.text.trim(),
      'gstin': _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
      'contactPerson': _contactCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'paymentTerms': _paymentTerms,
    };

    try {
      final repo = ref.read(vendorsRepositoryProvider);
      if (isEdit) {
        await repo.updateVendor(widget.vendor!['id'] as String, data);
      } else {
        await repo.createVendor(data);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Vendor updated' : 'Vendor created'),
            backgroundColor: AppTheme.success,
          ),
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
      child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
