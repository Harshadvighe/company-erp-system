import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';

class VendorRegistrationModal extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const VendorRegistrationModal({super.key, required this.onSuccess});

  @override
  ConsumerState<VendorRegistrationModal> createState() =>
      _VendorRegistrationModalState();
}

class _VendorRegistrationModalState
    extends ConsumerState<VendorRegistrationModal> {
  final _formKey = GlobalKey<FormState>();

  // ─── Basic Details ──────────────────────────────────────────────────────────
  final _vendorCodeCtrl = TextEditingController(text: 'VND-2026-002');
  final _legalNameCtrl = TextEditingController();
  String _vendorCategory = 'Raw Material';
  final _constitutionCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // ─── Registration & Location ────────────────────────────────────────────────
  final _cityCtrl = TextEditingController();
  final _factoryLocationCtrl = TextEditingController();
  final _registeredOfficeCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _msmeStatusCtrl = TextEditingController();

  // ─── Bank & Approval ────────────────────────────────────────────────────────
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCodeCtrl = TextEditingController();
  final _creditTermsCtrl = TextEditingController();
  String _approvalStatus = 'Pending Review';
  final _onboardingDateCtrl =
      TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

  bool _isSubmitting = false;

  final List<String> _categories = [
    'Raw Material',
    'Component Manufacturer',
    'Fabricator / Job Worker',
    'Logistics & Freight',
    'Service Provider',
    'Standard Supplier',
  ];

  final List<String> _approvalStatuses = [
    'Pending Review',
    'Approved',
    'Hold',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _fetchNextVendorCode();
  }

  Future<void> _fetchNextVendorCode() async {
    try {
      final repo = ref.read(purchaseRepositoryProvider);
      final vendors = await repo.getVendors();
      final count = vendors.length + 1;
      final code = 'VND-2026-${count.toString().padLeft(3, '0')}';
      if (mounted) {
        setState(() => _vendorCodeCtrl.text = code);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _vendorCodeCtrl.dispose();
    _legalNameCtrl.dispose();
    _constitutionCtrl.dispose();
    _contactPersonCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _factoryLocationCtrl.dispose();
    _registeredOfficeCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    _msmeStatusCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCodeCtrl.dispose();
    _creditTermsCtrl.dispose();
    _onboardingDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitVendor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(purchaseRepositoryProvider);

      final payload = {
        'vendorCode': _vendorCodeCtrl.text.trim(),
        'legalName': _legalNameCtrl.text.trim(),
        'companyName': _legalNameCtrl.text.trim(),
        'vendorCategory': _vendorCategory,
        'constitution': _constitutionCtrl.text.trim(),
        'contactPerson': _contactPersonCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'factoryLocation': _factoryLocationCtrl.text.trim(),
        'address': _registeredOfficeCtrl.text.trim().isNotEmpty
            ? _registeredOfficeCtrl.text.trim()
            : _factoryLocationCtrl.text.trim(),
        'registeredOffice': _registeredOfficeCtrl.text.trim(),
        'gstin': _gstinCtrl.text.trim(),
        'pan': _panCtrl.text.trim(),
        'msmeStatus': _msmeStatusCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim(),
        'accountNumber': _accountNumberCtrl.text.trim(),
        'ifscCode': _ifscCodeCtrl.text.trim(),
        'creditTerms': _creditTermsCtrl.text.trim(),
        'approvalStatus': _approvalStatus,
        'onboardingDate': _onboardingDateCtrl.text.trim(),
      };

      await repo.createVendorRegistration(payload);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor registered successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor registration failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: const Color(0xFF191A1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Container(
        width: 1100,
        constraints: const BoxConstraints(maxHeight: 840),
        child: Column(
          children: [
            // ─── Top Window Header Strip ───────────────────────────────────────
            _buildTopBar(),

            // ─── Scrollable Form Body ──────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subheader
                      const Text(
                        'Vendor Registration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Add the vendor once here, then select it in a new inward invoice.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ─── 1. Basic Details ────────────────────────────────────
                      _buildSectionHeader('Basic Details'),
                      const SizedBox(height: 8),
                      _buildBasicDetailsSection(),
                      const SizedBox(height: 16),

                      // ─── 2. Registration & Location ──────────────────────────
                      _buildSectionHeader('Registration & Location'),
                      const SizedBox(height: 8),
                      _buildRegistrationLocationSection(),
                      const SizedBox(height: 16),

                      // ─── 3. Bank & Approval ──────────────────────────────────
                      _buildSectionHeader('Bank & Approval'),
                      const SizedBox(height: 8),
                      _buildBankApprovalSection(),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Bottom Actions ────────────────────────────────────────────────
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  // ─── Top Header Strip ───────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2F36), width: 1.2)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF22242B),
              side: const BorderSide(color: Color(0xFF383C46)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 14, color: Colors.white),
            label: const Text(
              'Back to Previous Page',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF22242B),
              side: const BorderSide(color: Color(0xFF383C46)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () {},
            icon: const Icon(Icons.help_outline, size: 14, color: Colors.white),
            label: const Text(
              'Help',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Vendor Registration',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE57A38),
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }

  // ─── 1. Basic Details Section ──────────────────────────────────────────────
  Widget _buildBasicDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Vendor Code:',
                  child: TextFormField(
                    controller: _vendorCodeCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Vendor Legal Name:',
                  child: TextFormField(
                    controller: _legalNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Vendor Category:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _vendorCategory,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c,
                        child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _vendorCategory = v ?? 'Raw Material'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Constitution:',
                  child: TextFormField(
                    controller: _constitutionCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'e.g. Private Limited / Partnership / Proprietor'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Contact Person:',
                  child: TextFormField(
                    controller: _contactPersonCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Phone / Mobile:',
                  child: TextFormField(
                    controller: _phoneCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Official Email:',
                  child: TextFormField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'vendor@domain.com'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Registration & Location Section ────────────────────────────────────
  Widget _buildRegistrationLocationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Registered City:',
                  child: TextFormField(
                    controller: _cityCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Factory / Works Location:',
                  child: TextFormField(
                    controller: _factoryLocationCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Registered Office Location:',
                  child: TextFormField(
                    controller: _registeredOfficeCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'GSTIN:',
                  child: TextFormField(
                    controller: _gstinCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'e.g. 27ABCDE1234F1Z5'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'PAN:',
                  child: TextFormField(
                    controller: _panCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'e.g. ABCDE1234F'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'MSME Status:',
                  child: TextFormField(
                    controller: _msmeStatusCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Micro / Small / Medium / Not Registered'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. Bank & Approval Section ────────────────────────────────────────────
  Widget _buildBankApprovalSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Bank Name:',
                  child: TextFormField(
                    controller: _bankNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Account Number:',
                  child: TextFormField(
                    controller: _accountNumberCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'IFSC Code:',
                  child: TextFormField(
                    controller: _ifscCodeCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Credit Terms:',
                  child: TextFormField(
                    controller: _creditTermsCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'e.g. Net 30 Days / Advance'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Approval Status:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _approvalStatus,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _approvalStatuses.map((s) {
                      return DropdownMenuItem<String>(
                        value: s,
                        child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _approvalStatus = v ?? 'Pending Review'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Onboarding Date:',
                  child: TextFormField(
                    controller: _onboardingDateCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _onboardingDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        border: Border(top: BorderSide(color: Color(0xFF2C2F36), width: 1.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: _isSubmitting ? null : _submitVendor,
            child: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Save Vendor',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Back',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Field Helper ──────────────────────────────────────────────────────
  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD0D3DA),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      isDense: true,
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 11.5),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF22242B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFF353942)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFF353942)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFF15A24), width: 1.2),
      ),
    );
  }
}
