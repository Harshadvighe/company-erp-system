import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';

class VendorRegistrationModal extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const VendorRegistrationModal({super.key, required this.onSuccess});

  @override
  ConsumerState<VendorRegistrationModal> createState() => _VendorRegistrationModalState();
}

class _VendorRegistrationModalState extends ConsumerState<VendorRegistrationModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Master Details
  final _companyNameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _productsCtrl = TextEditingController();
  String _vendorType = 'MANUFACTURER';
  String _vendorCategory = 'STANDARD';

  // Primary Contact
  final _contactPersonCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // Address
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController(text: 'Maharashtra');
  final _pincodeCtrl = TextEditingController();

  // Commercial & Terms
  final _creditLimitCtrl = TextEditingController(text: '500000');
  String _paymentTerms = 'NET_30';

  // Bank Master
  final _accHolderCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameCtrl.dispose();
    _legalNameCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    _productsCtrl.dispose();
    _contactPersonCtrl.dispose();
    _designationCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _creditLimitCtrl.dispose();
    _accHolderCtrl.dispose();
    _bankNameCtrl.dispose();
    _accNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.storefront, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vendor Registration & Master Onboarding',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Register vendor, multi-contacts, banking details & credit limits',
                              style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.darkTextSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.darkTextSecondary,
                tabs: const [
                  Tab(icon: Icon(Icons.business, size: 18), text: 'Master Info'),
                  Tab(icon: Icon(Icons.person, size: 18), text: 'Contact & Address'),
                  Tab(icon: Icon(Icons.account_balance, size: 18), text: 'Bank Account'),
                  Tab(icon: Icon(Icons.handshake, size: 18), text: 'Commercial Terms'),
                ],
              ),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Master Info
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _companyNameCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Vendor Name*',
                                    hintText: 'e.g. L&T Electrical Solutions',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _legalNameCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Legal Registered Entity Name',
                                    hintText: 'Larsen & Toubro Limited',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _gstinCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'GSTIN*',
                                    hintText: '27AAACS1234F1Z1',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _panCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'PAN Number*',
                                    hintText: 'AAACS1234F',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _vendorType,
                                  dropdownColor: AppTheme.darkSurface,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Vendor Type*',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'MANUFACTURER', child: Text('Manufacturer')),
                                    DropdownMenuItem(value: 'DEALER', child: Text('Authorized Dealer')),
                                    DropdownMenuItem(value: 'DISTRIBUTOR', child: Text('Distributor')),
                                    DropdownMenuItem(value: 'SERVICE_PROVIDER', child: Text('Service Provider')),
                                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                                  ],
                                  onChanged: (v) => setState(() => _vendorType = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _vendorCategory,
                                  dropdownColor: AppTheme.darkSurface,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Vendor Category*',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'STRATEGIC_TIER_1', child: Text('Strategic Tier 1')),
                                    DropdownMenuItem(value: 'STANDARD', child: Text('Standard')),
                                    DropdownMenuItem(value: 'PREFERRED', child: Text('Preferred')),
                                  ],
                                  onChanged: (v) => setState(() => _vendorCategory = v!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _productsCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Products Supplied / Materials Offered',
                              hintText: 'e.g. Copper Cables, VFD Drives, MCBs, Enclosures',
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: Contact & Address
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _contactPersonCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Contact Person*',
                                    hintText: 'e.g. Rajesh Sharma',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _designationCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Designation',
                                    hintText: 'Sales Director',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _mobileCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Mobile Phone*',
                                    hintText: '+91 98200 12345',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _emailCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Email Address*',
                                    hintText: 'sales@vendor.com',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _addressCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Factory / Office Address*',
                              hintText: 'Plot 105, Industrial Zone Phase 2',
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cityCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'City*',
                                    hintText: 'Mumbai',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _stateCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'State*',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _pincodeCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Pincode',
                                    hintText: '400001',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tab 3: Bank Account
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _accHolderCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Account Holder Name',
                              hintText: 'As per bank records',
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _bankNameCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Bank Name',
                                    hintText: 'e.g. HDFC Bank Ltd',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _accNumberCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Account Number',
                                    hintText: '50200001234567',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ifscCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'IFSC Code',
                                    hintText: 'HDFC0000123',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _branchCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Branch',
                                    hintText: 'Fort, Mumbai',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tab 4: Commercial Terms
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _paymentTerms,
                                  dropdownColor: AppTheme.darkSurface,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Payment Terms*',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'IMMEDIATE', child: Text('Immediate / Advance')),
                                    DropdownMenuItem(value: 'NET_15', child: Text('Net 15 Days')),
                                    DropdownMenuItem(value: 'NET_30', child: Text('Net 30 Days')),
                                    DropdownMenuItem(value: 'NET_45', child: Text('Net 45 Days')),
                                    DropdownMenuItem(value: 'NET_60', child: Text('Net 60 Days')),
                                  ],
                                  onChanged: (v) => setState(() => _paymentTerms = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _creditLimitCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Approved Credit Limit (₹)',
                                    filled: true,
                                    fillColor: AppTheme.darkBackground,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.darkBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submitVendor,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isSubmitting ? 'Registering...' : 'Register Vendor'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitVendor() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(purchaseRepositoryProvider);

      final payload = {
        'companyName': _companyNameCtrl.text.trim(),
        'legalName': _legalNameCtrl.text.trim().isEmpty ? null : _legalNameCtrl.text.trim(),
        'gstin': _gstinCtrl.text.trim(),
        'pan': _panCtrl.text.trim(),
        'vendorType': _vendorType,
        'vendorCategory': _vendorCategory,
        'contactPerson': _contactPersonCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'phone': _mobileCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'paymentTerms': _paymentTerms,
        'creditLimit': double.tryParse(_creditLimitCtrl.text.trim()) ?? 0,
        'productsSupplied': _productsCtrl.text.trim(),
      };

      await repo.createVendorRegistration(payload);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor registered successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vendor registration failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
