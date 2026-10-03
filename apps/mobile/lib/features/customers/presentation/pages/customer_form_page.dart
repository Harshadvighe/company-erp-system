import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  final String? customerId;
  const CustomerFormPage({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;

  // Form controllers
  final _companyNameCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _alternatePhoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _staffCountCtrl = TextEditingController();
  final _turnoverCtrl = TextEditingController();

  String _customerType = 'END_CUSTOMER';
  String _source = 'DIRECT';
  String _country = 'India';
  String? _industry;

  bool get isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isFetching = true);
    try {
      final repo = ref.read(customersRepositoryProvider);
      final result = await repo.getCustomer(widget.customerId!);
      final c = result['data'] as Map<String, dynamic>? ?? result;

      _companyNameCtrl.text = c['companyName'] ?? '';
      _gstinCtrl.text = c['gstin'] ?? '';
      _panCtrl.text = c['pan'] ?? '';
      _contactPersonCtrl.text = c['contactPerson'] ?? '';
      _designationCtrl.text = c['designation'] ?? '';
      _emailCtrl.text = c['email'] ?? '';
      _phoneCtrl.text = c['phone'] ?? '';
      _alternatePhoneCtrl.text = c['alternatePhone'] ?? '';
      _websiteCtrl.text = c['website'] ?? '';
      _addressCtrl.text = c['address'] ?? '';
      _cityCtrl.text = c['city'] ?? '';
      _districtCtrl.text = c['district'] ?? '';
      _stateCtrl.text = c['state'] ?? '';
      _pincodeCtrl.text = c['pincode'] ?? '';
      _ownerNameCtrl.text = c['ownerName'] ?? '';
      _staffCountCtrl.text = c['staffCount']?.toString() ?? '';
      _turnoverCtrl.text = c['turnover'] ?? '';
      _customerType = c['customerType'] ?? 'END_CUSTOMER';
      _source = c['source'] ?? 'DIRECT';
      _country = c['country'] ?? 'India';
      _industry = c['industry'];
      setState(() {});
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isFetching = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _companyNameCtrl, _gstinCtrl, _panCtrl, _contactPersonCtrl,
      _designationCtrl, _emailCtrl, _phoneCtrl, _alternatePhoneCtrl,
      _websiteCtrl, _addressCtrl, _cityCtrl, _districtCtrl, _stateCtrl,
      _pincodeCtrl, _ownerNameCtrl, _staffCountCtrl, _turnoverCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    final data = {
      'companyName': _companyNameCtrl.text.trim(),
      'gstin': _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
      'pan': _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
      'customerType': _customerType,
      'contactPerson': _contactPersonCtrl.text.trim(),
      'designation': _designationCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'alternatePhone': _alternatePhoneCtrl.text.trim().isEmpty ? null : _alternatePhoneCtrl.text.trim(),
      'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'country': _country,
      'ownerName': _ownerNameCtrl.text.trim().isEmpty ? null : _ownerNameCtrl.text.trim(),
      'staffCount': int.tryParse(_staffCountCtrl.text) ?? 0,
      'turnover': _turnoverCtrl.text.trim().isEmpty ? null : _turnoverCtrl.text.trim(),
      'industry': _industry,
      'source': _source,
    };

    try {
      final repo = ref.read(customersRepositoryProvider);
      if (isEdit) {
        await repo.updateCustomer(widget.customerId!, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer updated successfully'), backgroundColor: AppTheme.success),
          );
          context.go('/customers/${widget.customerId}');
        }
      } else {
        final result = await repo.createCustomer(data);
        final created = result['data'] as Map<String, dynamic>? ?? result;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer created successfully'), backgroundColor: AppTheme.success),
          );
          context.go('/customers/${created['id']}');
        }
      }
    } on Exception catch (e) {
      setState(() => _errorMessage = parseDioError(e as dynamic));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Customer' : 'New Customer'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('SAVE', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ),

              _sectionTitle('Company Information'),
              _buildField(_companyNameCtrl, 'Company Name *', required: true),
              _buildDropdown('Customer Type', _customerType, AppConstants.customerTypes,
                  (v) => setState(() => _customerType = v!)),
              _buildField(_gstinCtrl, 'GSTIN'),
              _buildField(_panCtrl, 'PAN'),
              _buildField(_websiteCtrl, 'Website', keyboardType: TextInputType.url),

              _sectionTitle('Primary Contact'),
              _buildField(_contactPersonCtrl, 'Contact Person *', required: true),
              _buildField(_designationCtrl, 'Designation'),
              _buildField(_emailCtrl, 'Email *', required: true, keyboardType: TextInputType.emailAddress),
              _buildField(_phoneCtrl, 'Phone *', required: true, keyboardType: TextInputType.phone),
              _buildField(_alternatePhoneCtrl, 'Alternate Phone', keyboardType: TextInputType.phone),

              _sectionTitle('Address'),
              _buildField(_addressCtrl, 'Address *', required: true, maxLines: 2),
              Row(
                children: [
                  Expanded(child: _buildField(_cityCtrl, 'City *', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(_districtCtrl, 'District')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildField(_stateCtrl, 'State *', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(_pincodeCtrl, 'Pincode', keyboardType: TextInputType.number)),
                ],
              ),

              _sectionTitle('Business Details'),
              _buildField(_ownerNameCtrl, 'Owner Name'),
              Row(
                children: [
                  Expanded(child: _buildField(_staffCountCtrl, 'Staff Count', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(_turnoverCtrl, 'Turnover')),
                ],
              ),
              _buildDropdown('Source', _source, AppConstants.leadSources,
                  (v) => setState(() => _source = v!)),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(isEdit ? 'UPDATE CUSTOMER' : 'CREATE CUSTOMER',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? '${label.replaceAll(' *', '')} is required' : null
            : null,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.replaceAll('_', ' ')))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
