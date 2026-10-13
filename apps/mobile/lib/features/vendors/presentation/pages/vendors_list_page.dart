import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';
import 'package:saark_erp_mobile/features/vendors/data/vendors_repository.dart';
import 'package:saark_erp_mobile/core/widgets/bulk_import_modal.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

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
        title: const Text('Vendors Directory & Management'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => BulkImportModal.show(
              context,
              target: 'VENDOR',
              onImportComplete: () => ref.read(vendorListProvider.notifier).loadVendors(),
            ),
            tooltip: 'Import Excel',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(vendorListProvider.notifier).loadVendors(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                            const SizedBox(height: 12),
                            Text(state.error!, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => ref.read(vendorListProvider.notifier).loadVendors(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(vendorListProvider.notifier).loadVendors(search: v),
              decoration: InputDecoration(
                hintText: 'Search vendors by company name, GSTIN, contact person, or location…',
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
              target: 'VENDOR',
              onImportComplete: () => ref.read(vendorListProvider.notifier).loadVendors(),
            ),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Import Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> vendors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
                columns: const [
                  DataColumn(label: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Vendor Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Vendor Legal Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Category & Constitution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Contact Person', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Phone & Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('GSTIN & PAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Added By', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                  DataColumn(label: Text('Vendor Owner / Assigned To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary))),
                  DataColumn(label: Text('Credit Terms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Approval Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                rows: vendors.asMap().entries.map((entry) {
                  final index = entry.key;
                  final v = entry.value;
                  final rowNum = index + 1;
                  final status = v['status'] as String? ?? 'ACTIVE';
                  final approvalStatus = v['approvalStatus'] as String? ?? 'APPROVED';
                  final createdByUser = v['createdByUser'] as Map<String, dynamic>?;
                  final assignedStaff = v['assignedStaff'] as Map<String, dynamic>?;
                  final addedBy = createdByUser?['fullName'] ?? 'System / Admin';
                  final vendorOwner = assignedStaff?['fullName'] ?? 'Unassigned';

                  return DataRow(cells: [
                    DataCell(Text('$rowNum', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                    DataCell(Text(v['vendorCode'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600))),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['companyName'] as String? ?? '',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (v['legalName'] != null && (v['legalName'] as String).isNotEmpty)
                          Text(v['legalName'] as String,
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    )),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((v['vendorCategory'] as String? ?? 'STANDARD').replaceAll('_', ' '),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        if (v['constitution'] != null)
                          Text((v['constitution'] as String).replaceAll('_', ' '),
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    )),
                    DataCell(Text(v['contactPerson'] as String? ?? '-', style: const TextStyle(fontSize: 12))),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['phone'] as String? ?? '-', style: const TextStyle(fontSize: 12)),
                        if (v['email'] != null && (v['email'] as String).isNotEmpty)
                          Text(v['email'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    )),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['city'] as String? ?? '-', style: const TextStyle(fontSize: 12)),
                        if (v['state'] != null && (v['state'] as String).isNotEmpty)
                          Text(v['state'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    )),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['gstin'] as String? ?? 'NO GST',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                        if (v['pan'] != null && (v['pan'] as String).isNotEmpty)
                          Text('PAN: ${v['pan']}',
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey)),
                      ],
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 13, color: Colors.blueAccent),
                          const SizedBox(width: 4),
                          Text(
                            addedBy,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                    )),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_pin, size: 13, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            vendorOwner,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    )),
                    DataCell(Text((v['paymentTerms'] as String? ?? 'NET_30').replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 11))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (approvalStatus == 'APPROVED' ? AppTheme.success : Colors.orange)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        approvalStatus.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: approvalStatus == 'APPROVED' ? AppTheme.success : Colors.orangeAccent,
                        ),
                      ),
                    )),
                    DataCell(_StatusBadge(status: status)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _showVendorForm(context, vendor: v),
                          tooltip: 'Edit Vendor',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${vendors.length} vendors registered',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
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
        final createdByUser = v['createdByUser'] as Map<String, dynamic>?;
        final assignedStaff = v['assignedStaff'] as Map<String, dynamic>?;
        final addedBy = createdByUser?['fullName'] ?? 'System / Admin';
        final vendorOwner = assignedStaff?['fullName'] ?? 'Unassigned';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.purple.withValues(alpha: 0.2),
                      child: Text(initials,
                          style: const TextStyle(
                              color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('${v['vendorCode'] ?? ''} · ${v['city'] ?? 'No City'}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    _StatusBadge(status: v['status'] as String? ?? 'ACTIVE'),
                  ],
                ),
                const Divider(height: 16),
                Text('Contact: ${v['contactPerson'] ?? ''} · ${v['phone'] ?? ''}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_pin, size: 12, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text('Vendor Owner: $vendorOwner',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 12, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text('Added By: $addedBy',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: () => _showVendorForm(context, vendor: v),
                      tooltip: 'Edit Vendor',
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
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _VendorFormSheet(
        vendor: vendor,
        onSuccess: () {
          ref.read(vendorListProvider.notifier).loadVendors();
        },
      ),
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
  final _legalNameCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String _paymentTerms = 'NET_30';
  String _vendorCategory = 'STANDARD';
  String _constitution = 'PRIVATE_LIMITED';
  bool _isLoading = false;
  bool _isVerifyingGst = false;
  bool _gstVerified = false;
  String? _verifiedGstin;
  String? _gstProviderRef;
  final Map<TextEditingController, String> _gstAutoFilledValues = {};

  List<StaffMember> _staffMembers = [];
  StaffMember? _selectedStaffOwner;

  bool get isEdit => widget.vendor != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final v = widget.vendor!;
      _companyCtrl.text = v['companyName'] as String? ?? '';
      _legalNameCtrl.text = v['legalName'] as String? ?? '';
      _gstCtrl.text = v['gstin'] as String? ?? '';
      _panCtrl.text = v['pan'] as String? ?? '';
      _contactCtrl.text = v['contactPerson'] as String? ?? '';
      _emailCtrl.text = v['email'] as String? ?? '';
      _phoneCtrl.text = v['phone'] as String? ?? '';
      _addressCtrl.text = v['address'] as String? ?? '';
      _cityCtrl.text = v['city'] as String? ?? '';
      _districtCtrl.text = v['district'] as String? ?? '';
      _stateCtrl.text = v['state'] as String? ?? '';
      _pincodeCtrl.text = v['pincode'] as String? ?? '';
      _paymentTerms = v['paymentTerms'] as String? ?? 'NET_30';
      _vendorCategory = v['vendorCategory'] as String? ?? 'STANDARD';
      _constitution = v['constitution'] as String? ?? 'PRIVATE_LIMITED';
      _gstVerified = v['gstin'] != null && v['gstin'].toString().trim().isNotEmpty;
      _verifiedGstin = _gstVerified ? v['gstin'].toString().trim().toUpperCase() : null;
    }
    _loadStaffMembers();
  }

  @override
  void dispose() {
    for (final c in [
      _companyCtrl,
      _legalNameCtrl,
      _gstCtrl,
      _panCtrl,
      _contactCtrl,
      _emailCtrl,
      _phoneCtrl,
      _addressCtrl,
      _cityCtrl,
      _districtCtrl,
      _stateCtrl,
      _pincodeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isValidGstin(String value) {
    const characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final gstin = value.trim().toUpperCase();
    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
        .hasMatch(gstin)) {
      return false;
    }

    var factor = 1;
    var sum = 0;
    for (var index = 0; index < 14; index++) {
      final codePoint = characters.indexOf(gstin[index]);
      var product = factor * codePoint;
      factor = factor == 2 ? 1 : 2;
      product = (product ~/ 36) + (product % 36);
      sum += product;
    }
    final checkCodePoint = (36 - (sum % 36)) % 36;
    return characters[checkCodePoint] == gstin[14];
  }

  void _fillGstValueIfEmpty(TextEditingController controller, String? value) {
    if (value == null || value.isEmpty) return;
    if (controller.text.trim().isEmpty || _gstAutoFilledValues.containsKey(controller)) {
      controller.text = value;
      _gstAutoFilledValues[controller] = value;
    }
  }

  void _onPincodeChanged(String val) {
    final cleanPin = val.trim();
    if (cleanPin.length == 6 && RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      const pinPrefixes = {
        '411': {'district': 'Pune', 'state': 'Maharashtra', 'city': 'Pune'},
        '412': {'district': 'Pune', 'state': 'Maharashtra', 'city': 'Pune Rural'},
        '413': {'district': 'Solapur', 'state': 'Maharashtra', 'city': 'Solapur'},
        '414': {'district': 'Ahmednagar', 'state': 'Maharashtra', 'city': 'Ahmednagar'},
        '415': {'district': 'Satara', 'state': 'Maharashtra', 'city': 'Satara'},
        '416': {'district': 'Kolhapur', 'state': 'Maharashtra', 'city': 'Kolhapur'},
        '400': {'district': 'Mumbai', 'state': 'Maharashtra', 'city': 'Mumbai'},
        '401': {'district': 'Thane', 'state': 'Maharashtra', 'city': 'Thane'},
        '421': {'district': 'Thane', 'state': 'Maharashtra', 'city': 'Kalyan'},
        '422': {'district': 'Nashik', 'state': 'Maharashtra', 'city': 'Nashik'},
        '424': {'district': 'Dhule', 'state': 'Maharashtra', 'city': 'Dhule'},
        '425': {'district': 'Jalgaon', 'state': 'Maharashtra', 'city': 'Jalgaon'},
        '431': {'district': 'Chhatrapati Sambhaji Nagar', 'state': 'Maharashtra', 'city': 'Chhatrapati Sambhaji Nagar'},
        '440': {'district': 'Nagpur', 'state': 'Maharashtra', 'city': 'Nagpur'},
        '444': {'district': 'Amravati', 'state': 'Maharashtra', 'city': 'Amravati'},
        '380': {'district': 'Ahmedabad', 'state': 'Gujarat', 'city': 'Ahmedabad'},
        '390': {'district': 'Vadodara', 'state': 'Gujarat', 'city': 'Vadodara'},
        '395': {'district': 'Surat', 'state': 'Gujarat', 'city': 'Surat'},
        '360': {'district': 'Rajkot', 'state': 'Gujarat', 'city': 'Rajkot'},
        '560': {'district': 'Bengaluru', 'state': 'Karnataka', 'city': 'Bengaluru'},
        '500': {'district': 'Hyderabad', 'state': 'Telangana', 'city': 'Hyderabad'},
        '600': {'district': 'Chennai', 'state': 'Tamil Nadu', 'city': 'Chennai'},
        '110': {'district': 'Delhi', 'state': 'Delhi', 'city': 'New Delhi'},
        '122': {'district': 'Gurugram', 'state': 'Haryana', 'city': 'Gurugram'},
        '201': {'district': 'Gautam Buddha Nagar', 'state': 'Uttar Pradesh', 'city': 'Noida'},
        '700': {'district': 'Kolkata', 'state': 'West Bengal', 'city': 'Kolkata'},
        '302': {'district': 'Jaipur', 'state': 'Rajasthan', 'city': 'Jaipur'},
      };
      final prefix = cleanPin.substring(0, 3);
      final mapped = pinPrefixes[prefix];
      if (mapped != null) {
        if (_districtCtrl.text.trim().isEmpty) _districtCtrl.text = mapped['district']!;
        if (_stateCtrl.text.trim().isEmpty) _stateCtrl.text = mapped['state']!;
        if (_cityCtrl.text.trim().isEmpty && mapped['city'] != null) _cityCtrl.text = mapped['city']!;
      }
    }
  }

  Future<void> _verifyGst() async {
    if (_isVerifyingGst) return;
    final gstin = _gstCtrl.text.trim().toUpperCase();
    if (!_isValidGstin(gstin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 15-digit GSTIN with a correct checksum digit'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingGst = true;
      _gstVerified = false;
      _gstProviderRef = null;
      _verifiedGstin = null;
    });

    try {
      final repo = ref.read(vendorsRepositoryProvider);
      final res = await repo.verifyGst(gstin);
      final data = res['data'] as Map<String, dynamic>? ?? res;

      if (data['valid'] == true) {
        final legalName = data['legalName']?.toString();
        final tradeName = data['tradeName']?.toString();
        final address = data['address']?.toString();
        final city = data['city']?.toString();
        final district = data['district']?.toString();
        final pincode = data['pincode']?.toString();
        final state = data['state']?.toString();
        final pan = data['pan']?.toString() ?? (gstin.length >= 12 ? gstin.substring(2, 12) : null);
        final companyType = data['companyType']?.toString();

        if (mounted) {
          setState(() {
            _gstVerified = true;
            _verifiedGstin = gstin;
            _gstProviderRef = data['providerRef']?.toString() ?? 'LIVE';

            _fillGstValueIfEmpty(_panCtrl, pan);
            _fillGstValueIfEmpty(_legalNameCtrl, legalName);
            _fillGstValueIfEmpty(
              _companyCtrl,
              tradeName != null && tradeName.isNotEmpty ? tradeName : legalName,
            );
            _fillGstValueIfEmpty(_addressCtrl, address);
            _fillGstValueIfEmpty(_cityCtrl, city);
            _fillGstValueIfEmpty(_districtCtrl, district);
            _fillGstValueIfEmpty(_pincodeCtrl, pincode);
            _fillGstValueIfEmpty(_stateCtrl, state);

            if (companyType != null) {
              if (companyType == 'PVT_LTD') {
                _constitution = 'PRIVATE_LIMITED';
              } else if (companyType == 'PUBLIC_LTD') {
                _constitution = 'PUBLIC_LIMITED';
              } else if (companyType == 'PROPRIETORSHIP') {
                _constitution = 'PROPRIETORSHIP';
              } else if (companyType == 'PARTNERSHIP') {
                _constitution = 'PARTNERSHIP';
              } else if (companyType == 'LLP') {
                _constitution = 'LLP';
              }
            }
          });

          final hasDetails = legalName != null && legalName.isNotEmpty;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasDetails
                          ? 'GSTIN verified: $legalName'
                          : 'GSTIN verified successfully & details filled.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'GSTIN verification was not successful');
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = parseDioError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.warning,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _verifyGst,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingGst = false);
      }
    }
  }

  Future<void> _loadStaffMembers() async {
    try {
      final staffRepo = ref.read(staffRepositoryProvider);
      final list = await staffRepo.getStaffList();
      if (mounted) {
        setState(() {
          _staffMembers = list;
          if (_selectedStaffOwner == null) {
            final v = widget.vendor;
            if (v != null && v['assignedStaffId'] != null) {
              _selectedStaffOwner = list.where((s) => s.id == v['assignedStaffId']).firstOrNull;
            }
            if (_selectedStaffOwner == null) {
              final currentUser = ref.read(currentUserProvider);
              if (currentUser != null) {
                _selectedStaffOwner = list.where(
                  (s) =>
                      (currentUser.staffId != null && s.id == currentUser.staffId) ||
                      (currentUser.employeeId != null && s.employeeId == currentUser.employeeId) ||
                      s.fullName.toLowerCase() == currentUser.fullName.toLowerCase() ||
                      s.email.toLowerCase() == currentUser.email.toLowerCase(),
                ).firstOrNull ?? (list.isNotEmpty ? list.first : null);
              } else if (list.isNotEmpty) {
                _selectedStaffOwner = list.first;
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isGstMatch = _gstVerified && _verifiedGstin == _gstCtrl.text.trim().toUpperCase();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.92,
        initialChildSize: 0.85,
        builder: (_, ctrl) => Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: ctrl,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isEdit ? 'Edit Vendor Details' : 'Vendor Registration',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // GSTIN Section with Auto Fetch
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gstCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'GSTIN (15-digit)',
                            hintText: '27AAAAA0000A1Z5',
                            prefixIcon: const Icon(Icons.receipt_long, size: 20),
                            suffixIcon: _isVerifyingGst
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : isGstMatch
                                    ? const Icon(Icons.check_circle, color: AppTheme.success)
                                    : null,
                          ),
                          onChanged: (val) {
                            if (_verifiedGstin != null && val.trim().toUpperCase() != _verifiedGstin) {
                              setState(() {
                                _gstVerified = false;
                                _verifiedGstin = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isVerifyingGst ? null : _verifyGst,
                          icon: _isVerifyingGst
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_download_outlined, size: 18),
                          label: const Text(
                            'Auto Fetch',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isGstMatch)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: AppTheme.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GSTIN Verified • ${_legalNameCtrl.text.isNotEmpty ? _legalNameCtrl.text : _companyCtrl.text}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _field(_companyCtrl, 'Vendor Display / Company Name *', required: true),
                _field(_legalNameCtrl, 'Legal Registered Entity Name'),
                Row(
                  children: [
                    Expanded(child: _field(_panCtrl, 'PAN Number')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          value: _constitution,
                          decoration: const InputDecoration(labelText: 'Constitution'),
                          items: ['PRIVATE_LIMITED', 'PUBLIC_LIMITED', 'PROPRIETORSHIP', 'PARTNERSHIP', 'LLP']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' '))))
                              .toList(),
                          onChanged: (v) => setState(() => _constitution = v!),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _vendorCategory,
                    decoration: const InputDecoration(labelText: 'Vendor Category'),
                    items: ['STANDARD', 'STRATEGIC_TIER_1', 'PREFERRED', 'CRITICAL']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: (v) => setState(() => _vendorCategory = v!),
                  ),
                ),
                // Vendor Owner / Assigned Staff Selection (Defaults to authenticated employee)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    value: _selectedStaffOwner?.id.isNotEmpty == true ? _selectedStaffOwner!.id : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Vendor Owner / Assigned To *',
                      helperText: 'Defaulted to logged-in employee. Reassignable to authorized staff.',
                      prefixIcon: const Icon(Icons.person_pin, color: AppTheme.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _staffMembers.map((staff) {
                      return DropdownMenuItem<String>(
                        value: staff.id,
                        child: Text(
                          staff.departmentName != null && staff.departmentName!.isNotEmpty
                              ? '${staff.fullName} (${staff.departmentName})'
                              : staff.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final found = _staffMembers.where((s) => s.id == val).firstOrNull;
                        if (found != null) setState(() => _selectedStaffOwner = found);
                      }
                    },
                  ),
                ),
                _field(_contactCtrl, 'Contact Person *', required: true),
                Row(
                  children: [
                    Expanded(child: _field(_phoneCtrl, 'Phone / Mobile *', required: true, keyboardType: TextInputType.phone)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_emailCtrl, 'Official Email', keyboardType: TextInputType.emailAddress)),
                  ],
                ),
                _field(_addressCtrl, 'Registered Office / Factory Address', maxLines: 2),
                Row(
                  children: [
                    Expanded(child: _field(_cityCtrl, 'City')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_districtCtrl, 'District')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _field(_stateCtrl, 'State')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _pincodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Pincode (6-digit)'),
                          onChanged: _onPincodeChanged,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    value: _paymentTerms,
                    decoration: const InputDecoration(labelText: 'Credit / Payment Terms'),
                    items: ['NET_7', 'NET_15', 'NET_30', 'NET_45', 'NET_60', 'ADVANCE', 'IMMEDIATE']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: (v) => setState(() => _paymentTerms = v!),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text(isEdit ? 'Update Vendor' : 'Register Vendor'),
                  ),
                ),
                const SizedBox(height: 12),
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
      'legalName': _legalNameCtrl.text.trim().isEmpty ? null : _legalNameCtrl.text.trim(),
      'gstin': _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim().toUpperCase(),
      'pan': _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim().toUpperCase(),
      'contactPerson': _contactCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      'district': _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
      'state': _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
      'paymentTerms': _paymentTerms,
      'vendorCategory': _vendorCategory,
      'constitution': _constitution,
      'assignedStaffId': _selectedStaffOwner?.id,
    };

    try {
      final repo = ref.read(vendorsRepositoryProvider);
      if (isEdit) {
        await repo.updateVendor(widget.vendor!['id'] as String, data);
      } else {
        await repo.createVendor(data);
      }
      if (mounted) {
        context.pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Vendor updated successfully' : 'Vendor registered successfully'),
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
