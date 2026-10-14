import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  final String? customerId;
  const CustomerFormPage({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  // ─── Design System Color Tokens ──────────────────────────────────────────
  static const Color _bgDark = Color(0xFF0F1115);
  static const Color _cardBg = Color(0xFF1E222A);
  static const Color _inputBg = Color(0xFF20242C);
  static const Color _headerBg = Color(0xFF191C22);
  static const Color _borderColor = Color(0xFF303641);
  static const Color _primaryAccent = Color(0xFFFF7417);
  static const Color _textPrimary = Color(0xFFF5F6F8);
  static const Color _textSecondary = Color(0xFFA5ADB8);
  static const Color _textMuted = Color(0xFF7F8792);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _errorColor = Color(0xFFEF4444);

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetching = false;
  bool _isVerifyingGst = false;
  String? _errorMessage;

  // Dual GST flow
  String _gstStatus = 'GST_REGISTERED'; // 'GST_REGISTERED' or 'NO_GST'
  String _noGstReason = 'UNREGISTERED_BUSINESS';
  bool _gstVerified = false;
  String? _gstProviderRef;
  String? _gstVerificationToken;
  String? _verifiedGstin;
  final Map<TextEditingController, String> _gstAutoFilledValues = {};

  // Form controllers
  final _companyNameCtrl = TextEditingController();
  final _tradeNameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _alternatePhoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
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
  String _companyType = 'PVT_LTD';
  String _source = 'DIRECT';
  String _country = 'India';
  String? _industry;
  List<StaffMember> _staffMembers = [];
  StaffMember? _selectedStaffHost;

  // Product & system interests
  List<dynamic> _availableProductSystems = [];
  final Set<String> _selectedProductSystemIds = {};

  bool get isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    _loadProductSystems();
    _loadStaffMembers();
    if (isEdit) _loadCustomer();
  }

  Future<void> _loadStaffMembers() async {
    try {
      final staffRepo = ref.read(staffRepositoryProvider);
      final list = await staffRepo.getStaffList();
      if (mounted) {
        setState(() {
          _staffMembers = list;
          if (_selectedStaffHost == null) {
            final currentUser = ref.read(currentUserProvider);
            if (currentUser != null) {
              _selectedStaffHost = list
                      .where(
                        (s) =>
                            (currentUser.staffId != null &&
                                s.id == currentUser.staffId) ||
                            (currentUser.employeeId != null &&
                                s.employeeId == currentUser.employeeId) ||
                            s.fullName.toLowerCase() ==
                                currentUser.fullName.toLowerCase() ||
                            s.email.toLowerCase() ==
                                currentUser.email.toLowerCase(),
                      )
                      .firstOrNull ??
                  (list.isNotEmpty ? list.first : null);
            } else if (list.isNotEmpty) {
              _selectedStaffHost = list.first;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProductSystems() async {
    try {
      final repo = ref.read(customersRepositoryProvider);
      final systems = await repo.getProductSystems();
      if (mounted) {
        setState(() => _availableProductSystems = systems);
      }
    } catch (_) {}
  }

  Future<void> _loadCustomer() async {
    setState(() => _isFetching = true);
    try {
      final repo = ref.read(customersRepositoryProvider);
      final result = await repo.getCustomer(widget.customerId!);
      final c = result['data'] as Map<String, dynamic>? ?? result;

      _companyNameCtrl.text = c['companyName'] ?? '';
      _legalNameCtrl.text = c['legalName'] ?? '';
      _tradeNameCtrl.text = c['tradeName'] ?? '';
      _gstinCtrl.text = c['gstin'] ?? '';
      _panCtrl.text = c['pan'] ?? '';
      _gstStatus = c['gstStatus'] ??
          (c['gstin'] != null && c['gstin'].toString().isNotEmpty
              ? 'GST_REGISTERED'
              : 'NO_GST');
      _noGstReason = c['noGstReason'] ?? 'UNREGISTERED_BUSINESS';
      _gstVerified = c['gstVerified'] == true;
      _gstProviderRef = c['gstProviderRef'];
      _verifiedGstin = _gstVerified && c['gstin'] != null
          ? c['gstin'].toString().trim().toUpperCase()
          : null;
      _contactPersonCtrl.text = c['contactPerson'] ?? '';
      _designationCtrl.text = c['designation'] ?? '';
      _emailCtrl.text = c['email'] ?? '';
      _phoneCtrl.text = c['phone'] ?? '';
      _alternatePhoneCtrl.text = c['alternatePhone'] ?? '';
      _whatsappCtrl.text = c['whatsapp'] ?? '';
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
      _companyType = c['companyType'] ?? 'PVT_LTD';
      _source = c['source'] ?? 'DIRECT';
      _country = c['country'] ?? 'India';
      _industry = c['industry'];

      if (c['productInterests'] is List) {
        for (final pi in c['productInterests']) {
          if (pi['productSystemId'] != null) {
            _selectedProductSystemIds.add(pi['productSystemId']);
          }
        }
      }

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
      _companyNameCtrl,
      _tradeNameCtrl,
      _legalNameCtrl,
      _gstinCtrl,
      _panCtrl,
      _contactPersonCtrl,
      _designationCtrl,
      _emailCtrl,
      _phoneCtrl,
      _alternatePhoneCtrl,
      _whatsappCtrl,
      _websiteCtrl,
      _addressCtrl,
      _cityCtrl,
      _districtCtrl,
      _stateCtrl,
      _pincodeCtrl,
      _ownerNameCtrl,
      _staffCountCtrl,
      _turnoverCtrl,
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

  void _clearUneditedGstAutoFilledValues() {
    for (final entry in _gstAutoFilledValues.entries) {
      if (entry.key.text.trim() == entry.value) {
        entry.key.clear();
      }
    }
    _gstAutoFilledValues.clear();
  }

  void _fillGstValueIfEmpty(
    TextEditingController controller,
    String? value,
  ) {
    if (value == null || value.isEmpty) {
      return;
    }
    if (controller.text.trim().isEmpty ||
        _gstAutoFilledValues.containsKey(controller)) {
      controller.text = value;
      _gstAutoFilledValues[controller] = value;
    }
  }

  void _onPincodeChanged(String val) {
    final cleanPin = val.trim();
    if (cleanPin.length == 6 && RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      const pinPrefixes = {
        '411': {'district': 'Pune', 'state': 'Maharashtra', 'city': 'Pune'},
        '412': {
          'district': 'Pune',
          'state': 'Maharashtra',
          'city': 'Pune Rural'
        },
        '413': {
          'district': 'Solapur',
          'state': 'Maharashtra',
          'city': 'Solapur'
        },
        '414': {
          'district': 'Ahmednagar',
          'state': 'Maharashtra',
          'city': 'Ahmednagar'
        },
        '415': {'district': 'Satara', 'state': 'Maharashtra', 'city': 'Satara'},
        '416': {
          'district': 'Kolhapur',
          'state': 'Maharashtra',
          'city': 'Kolhapur'
        },
        '400': {'district': 'Mumbai', 'state': 'Maharashtra', 'city': 'Mumbai'},
        '401': {'district': 'Thane', 'state': 'Maharashtra', 'city': 'Thane'},
        '421': {'district': 'Thane', 'state': 'Maharashtra', 'city': 'Kalyan'},
        '422': {'district': 'Nashik', 'state': 'Maharashtra', 'city': 'Nashik'},
        '424': {'district': 'Dhule', 'state': 'Maharashtra', 'city': 'Dhule'},
        '425': {
          'district': 'Jalgaon',
          'state': 'Maharashtra',
          'city': 'Jalgaon'
        },
        '431': {
          'district': 'Chhatrapati Sambhaji Nagar',
          'state': 'Maharashtra',
          'city': 'Chhatrapati Sambhaji Nagar'
        },
        '440': {'district': 'Nagpur', 'state': 'Maharashtra', 'city': 'Nagpur'},
        '444': {
          'district': 'Amravati',
          'state': 'Maharashtra',
          'city': 'Amravati'
        },
        '380': {
          'district': 'Ahmedabad',
          'state': 'Gujarat',
          'city': 'Ahmedabad'
        },
        '390': {'district': 'Vadodara', 'state': 'Gujarat', 'city': 'Vadodara'},
        '395': {'district': 'Surat', 'state': 'Gujarat', 'city': 'Surat'},
        '360': {'district': 'Rajkot', 'state': 'Gujarat', 'city': 'Rajkot'},
        '560': {
          'district': 'Bengaluru',
          'state': 'Karnataka',
          'city': 'Bengaluru'
        },
        '500': {
          'district': 'Hyderabad',
          'state': 'Telangana',
          'city': 'Hyderabad'
        },
        '600': {
          'district': 'Chennai',
          'state': 'Tamil Nadu',
          'city': 'Chennai'
        },
        '110': {'district': 'Delhi', 'state': 'Delhi', 'city': 'New Delhi'},
        '122': {'district': 'Gurugram', 'state': 'Haryana', 'city': 'Gurugram'},
        '201': {
          'district': 'Gautam Buddha Nagar',
          'state': 'Uttar Pradesh',
          'city': 'Noida'
        },
        '700': {
          'district': 'Kolkata',
          'state': 'West Bengal',
          'city': 'Kolkata'
        },
        '302': {'district': 'Jaipur', 'state': 'Rajasthan', 'city': 'Jaipur'},
      };

      final prefix = cleanPin.substring(0, 3);
      final mapped = pinPrefixes[prefix];
      if (mapped != null) {
        if (_districtCtrl.text.trim().isEmpty) {
          _districtCtrl.text = mapped['district']!;
        }
        if (_stateCtrl.text.trim().isEmpty) {
          _stateCtrl.text = mapped['state']!;
        }
        if (_cityCtrl.text.trim().isEmpty && mapped['city'] != null) {
          _cityCtrl.text = mapped['city']!;
        }
      }
    }
  }

  Future<void> _verifyGst() async {
    if (_isVerifyingGst) return; // Prevent duplicate requests
    final gstin = _gstinCtrl.text.trim().toUpperCase();
    if (!_isValidGstin(gstin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 15-digit GSTIN with correct checksum'),
          backgroundColor: _warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingGst = true;
      _gstVerified = false;
      _gstProviderRef = null;
      _gstVerificationToken = null;
      _verifiedGstin = null;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(customersRepositoryProvider);
      final res = await repo.verifyGst(gstin);
      final data = res['data'] as Map<String, dynamic>? ?? res;

      if (data['valid'] == true) {
        final verificationToken = data['verificationToken']?.toString();
        final providerRef = data['providerRef']?.toString();
        if (verificationToken == null ||
            verificationToken.isEmpty ||
            providerRef != 'GSTINAPI_LIVE_LOOKUP' ||
            data['isLiveLookup'] != true) {
          throw const FormatException(
              'GST verification returned an incomplete provider response.');
        }

        final legalName = data['legalName']?.toString();
        final tradeName = data['tradeName']?.toString();
        final address = data['address']?.toString();
        final city = data['city']?.toString();
        final district = data['district']?.toString();
        final pincode = data['pincode']?.toString();
        final state = data['state']?.toString();
        final pan = data['pan']?.toString();

        if (mounted) {
          setState(() {
            _gstVerified = true;
            _gstProviderRef = providerRef;
            _gstVerificationToken = verificationToken;
            _verifiedGstin = gstin;
            _fillGstValueIfEmpty(_panCtrl, pan);
            _fillGstValueIfEmpty(_stateCtrl, state);
            _fillGstValueIfEmpty(_legalNameCtrl, legalName);
            _fillGstValueIfEmpty(
              _companyNameCtrl,
              tradeName != null && tradeName.isNotEmpty ? tradeName : legalName,
            );
            _fillGstValueIfEmpty(_tradeNameCtrl, tradeName);
            _fillGstValueIfEmpty(_addressCtrl, address);
            _fillGstValueIfEmpty(_cityCtrl, city);
            _fillGstValueIfEmpty(_districtCtrl, district);
            _fillGstValueIfEmpty(_pincodeCtrl, pincode);
          });
        }

        if (mounted) {
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
                          ? 'GSTIN Verified with Portal: $legalName'
                          : 'GSTIN verified with GSTIN Portal.',
                    ),
                  ),
                ],
              ),
              backgroundColor: _successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = parseDioError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: _warningColor,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _verifyGst,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingGst = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please correct the highlighted validation errors before saving'),
          backgroundColor: _errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final assignedHostName = _selectedStaffHost?.fullName ??
        (_ownerNameCtrl.text.trim().isEmpty
            ? null
            : _ownerNameCtrl.text.trim());

    final data = {
      'companyName': _companyNameCtrl.text.trim(),
      'legalName': _legalNameCtrl.text.trim().isNotEmpty
          ? _legalNameCtrl.text.trim()
          : _companyNameCtrl.text.trim(),
      'tradeName': _tradeNameCtrl.text.trim().isNotEmpty
          ? _tradeNameCtrl.text.trim()
          : null,
      'gstin':
          _gstStatus == 'GST_REGISTERED' && _gstinCtrl.text.trim().isNotEmpty
              ? _gstinCtrl.text.trim().toUpperCase()
              : null,
      'pan': _panCtrl.text.trim().isNotEmpty
          ? _panCtrl.text.trim().toUpperCase()
          : null,
      'gstStatus': _gstStatus,
      'noGstReason': _gstStatus == 'NO_GST' ? _noGstReason : null,
      if (_gstVerificationToken != null &&
          _verifiedGstin == _gstinCtrl.text.trim().toUpperCase())
        'gstVerificationToken': _gstVerificationToken,
      'companyType': _companyType,
      'customerType': _customerType,
      'contactPerson': _contactPersonCtrl.text.trim(),
      'designation': _designationCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'alternatePhone': _alternatePhoneCtrl.text.trim().isEmpty
          ? null
          : _alternatePhoneCtrl.text.trim(),
      'whatsapp': _whatsappCtrl.text.trim().isNotEmpty
          ? _whatsappCtrl.text.trim()
          : null,
      'website':
          _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'country': _country,
      'ownerName': assignedHostName,
      'assignedStaffId': _selectedStaffHost?.id,
      'numEmployees': int.tryParse(_staffCountCtrl.text) ?? 0,
      'staffCount': int.tryParse(_staffCountCtrl.text) ?? 0,
      'turnover':
          _turnoverCtrl.text.trim().isEmpty ? null : _turnoverCtrl.text.trim(),
      'industry': _industry,
      'source': _source,
      'productSystemIds': _selectedProductSystemIds.toList(),
    };

    try {
      final repo = ref.read(customersRepositoryProvider);

      if (!isEdit) {
        // Pre-check for duplicate company records
        final dupCheck = await repo.checkDuplicate({
          'gstin':
              _gstStatus == 'GST_REGISTERED' ? _gstinCtrl.text.trim() : null,
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'companyName': _companyNameCtrl.text.trim(),
        });

        final dataRes = dupCheck['data'] as Map<String, dynamic>? ?? dupCheck;
        final hasDup = dataRes['hasDuplicate'] == true;
        final duplicates = (dataRes['duplicates'] as List? ?? []);

        if (hasDup && duplicates.isNotEmpty) {
          setState(() => _isLoading = false);
          final proceed = await _showDuplicateWarningDialog(duplicates);
          if (proceed != true) return;
          setState(() => _isLoading = true);
        }
      }

      if (isEdit) {
        await repo.updateCustomer(widget.customerId!, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Company record updated successfully'),
              backgroundColor: _successColor,
            ),
          );
          context.go('/customers/${widget.customerId}');
        }
      } else {
        final result = await repo.createCustomer(data);
        final created = result['data'] as Map<String, dynamic>? ?? result;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Company registered successfully into CRM 360'),
              backgroundColor: _successColor,
            ),
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

  Future<bool?> _showDuplicateWarningDialog(List<dynamic> duplicates) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _borderColor),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _warningColor, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Possible Duplicate Company',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following matching company records exist in CRM:',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: duplicates.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: _borderColor, height: 12),
                  itemBuilder: (_, idx) {
                    final d = duplicates[idx] as Map<String, dynamic>;
                    final existing =
                        d['existingCompany'] as Map<String, dynamic>? ?? d;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        '${existing['companyName']} (${existing['customerCode'] ?? 'CUS'})',
                        style: const TextStyle(
                          color: _primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'Matched on: ${d['matchField']} (${d['value']}) | GST: ${existing['gstin'] ?? 'N/A'}',
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new,
                            color: _primaryAccent, size: 18),
                        onPressed: () {
                          Navigator.of(ctx).pop(false);
                          context.go('/customers/${existing['id']}');
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('CANCEL', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _warningColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'CREATE ANYWAY',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MAIN BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return const Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: CircularProgressIndicator(
              color: _primaryAccent, strokeWidth: 2.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildCompactHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideDesktop = constraints.maxWidth >= 980;
                    return Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_errorMessage != null)
                                _buildErrorMessageBanner(),
                              if (isWideDesktop)
                                _buildDesktopTwoColumnLayout()
                              else
                                _buildStackedLayout(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildStickyActionBar(),
          ],
        ),
      ),
    );
  }

  // ─── COMPACT PAGE HEADER ───────────────────────────────────────────────────

  Widget _buildCompactHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          // Back Navigation
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/crm/dashboard');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                  color: _cardBg,
                ),
                child:
                    const Icon(Icons.arrow_back, color: _textPrimary, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title, Subtitle, & Status Badges
          Expanded(
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isEdit ? 'Edit Company / Customer' : 'Add Company',
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEdit
                                ? _primaryAccent.withValues(alpha: 0.15)
                                : _successColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isEdit
                                  ? _primaryAccent.withValues(alpha: 0.4)
                                  : _successColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            isEdit ? 'RECORD EDIT' : 'NEW CUSTOMER',
                            style: TextStyle(
                              color: isEdit ? _primaryAccent : _successColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Customer 360 · Enterprise Company Registration',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                if (!isEdit)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _inputBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _borderColor),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            color: _primaryAccent, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Auto-ID: CUS-2026-XXXXX',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Header Quick Actions
          OutlinedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/crm/dashboard');
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _textSecondary,
              side: const BorderSide(color: _borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline, size: 15),
            label: Text(
              _isLoading
                  ? 'Saving...'
                  : (isEdit ? 'Update Company' : 'Save Company'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── DESKTOP TWO-COLUMN WORKSPACE ──────────────────────────────────────────

  Widget _buildDesktopTwoColumnLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Company Identity, GST, Product Interests)
        Expanded(
          flex: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGstIntelligenceCard(),
              const SizedBox(height: 12),
              _buildCompanyIdentityCard(),
              const SizedBox(height: 12),
              _buildProductInterestsCard(),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Right Column (Sales Owner, Key Decision Maker, Address)
        Expanded(
          flex: 11,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSalesOwnershipCard(),
              const SizedBox(height: 12),
              _buildPrimaryContactCard(),
              const SizedBox(height: 12),
              _buildAddressCard(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STACKED LAYOUT (TABLET / MOBILE) ──────────────────────────────────────

  Widget _buildStackedLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGstIntelligenceCard(),
        const SizedBox(height: 12),
        _buildCompanyIdentityCard(),
        const SizedBox(height: 12),
        _buildSalesOwnershipCard(),
        const SizedBox(height: 12),
        _buildPrimaryContactCard(),
        const SizedBox(height: 12),
        _buildProductInterestsCard(),
        const SizedBox(height: 12),
        _buildAddressCard(),
      ],
    );
  }

  // ─── ERROR BANNER ──────────────────────────────────────────────────────────

  Widget _buildErrorMessageBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _errorColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _errorColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: _errorColor, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. GST INTELLIGENCE CARD ──────────────────────────────────────────────

  Widget _buildGstIntelligenceCard() {
    return _buildSectionCard(
      icon: Icons.verified_user_outlined,
      title: 'GST Intelligence & Verification',
      subtitle:
          'Real-time GSTIN validation and automatic company profile filling',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Registration Selector
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _inputBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_gstStatus != 'GST_REGISTERED') {
                        setState(() => _gstStatus = 'GST_REGISTERED');
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _gstStatus == 'GST_REGISTERED'
                            ? _primaryAccent.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: _gstStatus == 'GST_REGISTERED'
                            ? Border.all(
                                color: _primaryAccent.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business,
                              size: 14,
                              color: _gstStatus == 'GST_REGISTERED'
                                  ? _primaryAccent
                                  : _textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'GST Registered Business',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _gstStatus == 'GST_REGISTERED'
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _gstStatus == 'GST_REGISTERED'
                                    ? _primaryAccent
                                    : _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_gstStatus != 'NO_GST') {
                        setState(() {
                          _gstStatus = 'NO_GST';
                          _gstVerified = false;
                          _gstProviderRef = null;
                          _gstVerificationToken = null;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _gstStatus == 'NO_GST'
                            ? _warningColor.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: _gstStatus == 'NO_GST'
                            ? Border.all(
                                color: _warningColor.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.money_off_csred_outlined,
                              size: 14,
                              color: _gstStatus == 'NO_GST'
                                  ? _warningColor
                                  : _textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'No GST / Unregistered',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _gstStatus == 'NO_GST'
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _gstStatus == 'NO_GST'
                                    ? _warningColor
                                    : _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Dynamic GST Inputs
          if (_gstStatus == 'GST_REGISTERED') ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCompactTextField(
                    controller: _gstinCtrl,
                    label: 'GSTIN (15-digit)',
                    required: true,
                    prefixIcon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) => _isValidGstin(value ?? '')
                        ? null
                        : 'Enter a valid 15-digit GSTIN with correct checksum',
                    onChanged: (value) {
                      if (_verifiedGstin != null &&
                          value.trim().toUpperCase() != _verifiedGstin) {
                        _clearUneditedGstAutoFilledValues();
                        setState(() {
                          _gstVerified = false;
                          _gstProviderRef = null;
                          _gstVerificationToken = null;
                          _verifiedGstin = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _isVerifyingGst ? null : _verifyGst,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _gstVerified ? _successColor : _primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      icon: _isVerifyingGst
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _gstVerified
                                  ? Icons.verified
                                  : Icons.cloud_download_outlined,
                              size: 16,
                            ),
                      label: Text(
                        _gstVerified ? 'VERIFIED' : 'VERIFY & FETCH',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_gstVerified)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: _successColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: _successColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GSTIN verified with GST Portal (${_gstProviderRef ?? "LIVE"})${_legalNameCtrl.text.isNotEmpty ? " · ${_legalNameCtrl.text}" : ""}',
                        style: const TextStyle(
                          color: _successColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            _buildCompactDropdown(
              label: 'Reason for No GST',
              required: true,
              value: _noGstReason,
              items: const {
                'UNREGISTERED_BUSINESS': 'Unregistered Small Business',
                'INDIVIDUAL_CONSUMER': 'Individual / Consumer (B2C)',
                'EXEMPTED_GOODS': 'Exempted Goods & Services',
                'BELOW_TURNOVER_THRESHOLD': 'Below Turnover Exemption Limit',
                'OTHER': 'Other Exemption Reason',
              },
              prefixIcon: Icons.info_outline,
              onChanged: (val) =>
                  setState(() => _noGstReason = val ?? 'UNREGISTERED_BUSINESS'),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 2. COMPANY IDENTITY CARD ──────────────────────────────────────────────

  Widget _buildCompanyIdentityCard() {
    return _buildSectionCard(
      icon: Icons.domain_outlined,
      title: 'Company Identity & Master Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Company Name
          _buildCompactTextField(
            controller: _companyNameCtrl,
            label: 'Company Name',
            required: true,
            prefixIcon: Icons.business,
          ),
          const SizedBox(height: 10),

          // Row 2: Legal Name & Trade Name
          Row(
            children: [
              Expanded(
                child: _buildCompactTextField(
                  controller: _legalNameCtrl,
                  label: 'Legal Name (As per GST / Reg)',
                  prefixIcon: Icons.gavel_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactTextField(
                  controller: _tradeNameCtrl,
                  label: 'Trade / Brand Name',
                  prefixIcon: Icons.storefront_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Customer Type & Entity Type
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdown(
                  label: 'Customer Type',
                  required: true,
                  value: _customerType,
                  items: AppConstants.customerTypes,
                  prefixIcon: Icons.category_outlined,
                  onChanged: (v) => setState(() => _customerType = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactDropdown(
                  label: 'Entity Type',
                  required: true,
                  value: _companyType,
                  items: const {
                    'PVT_LTD': 'Private Limited',
                    'PUBLIC_LTD': 'Public Limited',
                    'PROPRIETORSHIP': 'Proprietorship',
                    'PARTNERSHIP': 'Partnership / LLP',
                    'GOVT': 'Government Entity',
                    'OTHER': 'Other',
                  },
                  prefixIcon: Icons.account_balance_outlined,
                  onChanged: (v) => setState(() => _companyType = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 4: PAN & Website
          Row(
            children: [
              Expanded(
                child: _buildCompactTextField(
                  controller: _panCtrl,
                  label: 'PAN (10-digit)',
                  prefixIcon: Icons.credit_card_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactTextField(
                  controller: _websiteCtrl,
                  label: 'Website',
                  keyboardType: TextInputType.url,
                  prefixIcon: Icons.language_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. PRODUCT & SYSTEM INTERESTS CARD ────────────────────────────────────

  Widget _buildProductInterestsCard() {
    final systemOptions = _availableProductSystems.isNotEmpty
        ? _availableProductSystems
        : AppConstants.productsOfInterest
            .map((p) => {'id': p, 'name': p})
            .toList();

    return _buildSectionCard(
      icon: Icons.precision_manufacturing_outlined,
      title: 'Product & System Interests',
      subtitle:
          'Select all industrial pumping, automation and treatment systems for this account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: systemOptions.map((sys) {
              final sysId = sys['id']?.toString() ?? '';
              final sysName = sys['name']?.toString() ?? '';
              final isSelected = _selectedProductSystemIds.contains(sysId);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedProductSystemIds.remove(sysId);
                    } else {
                      _selectedProductSystemIds.add(sysId);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primaryAccent.withValues(alpha: 0.18)
                        : _inputBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSelected ? _primaryAccent : _borderColor,
                      width: isSelected ? 1.2 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 13,
                        color: isSelected ? _primaryAccent : _textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        sysName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? _textPrimary : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedProductSystemIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_selectedProductSystemIds.length} industrial systems selected',
              style: const TextStyle(
                  color: _primaryAccent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 4. SALES OWNERSHIP CARD ───────────────────────────────────────────────

  Widget _buildSalesOwnershipCard() {
    return _buildSectionCard(
      icon: Icons.badge_outlined,
      title: 'Sales Ownership & Account Assignment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedStaffHost?.id.isNotEmpty == true
                ? _selectedStaffHost!.id
                : null,
            decoration: _inputDecoration(
              label: 'Sales Owner / Relationship Manager',
              required: true,
              prefixIcon: Icons.person_pin_outlined,
            ),
            dropdownColor: _cardBg,
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            items: _staffMembers.map((s) {
              final initials = s.fullName
                  .trim()
                  .split(' ')
                  .map((e) => e.isNotEmpty ? e[0] : '')
                  .take(2)
                  .join()
                  .toUpperCase();
              return DropdownMenuItem<String>(
                value: s.id,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: _primaryAccent.withValues(alpha: 0.25),
                      child: Text(
                        initials.isNotEmpty ? initials : 'S',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _primaryAccent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.fullName}${s.designationName != null && s.designationName!.isNotEmpty ? " · ${s.designationName}" : ""}',
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final found =
                    _staffMembers.where((s) => s.id == val).firstOrNull;
                if (found != null) setState(() => _selectedStaffHost = found);
              }
            },
          ),
          const SizedBox(height: 5),
          const Text(
            'Defaulted to your account. Reassign to another authorized sales engineer if needed.',
            style: TextStyle(color: _textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  // ─── 5. PRIMARY CONTACT CARD ───────────────────────────────────────────────

  Widget _buildPrimaryContactCard() {
    return _buildSectionCard(
      icon: Icons.contact_phone_outlined,
      title: 'Key Decision Maker & Primary Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Contact Person & Designation
          Row(
            children: [
              Expanded(
                child: _buildCompactTextField(
                  controller: _contactPersonCtrl,
                  label: 'Contact Person',
                  required: true,
                  prefixIcon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactTextField(
                  controller: _designationCtrl,
                  label: 'Designation (MD / Purchase)',
                  prefixIcon: Icons.work_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Email Address
          _buildCompactTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            required: true,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 10),

          // Row 3: Mobile & WhatsApp
          Row(
            children: [
              Expanded(
                child: _buildCompactTextField(
                  controller: _phoneCtrl,
                  label: 'Mobile / Phone',
                  required: true,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactTextField(
                  controller: _whatsappCtrl,
                  label: 'WhatsApp Number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.chat_bubble_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 4: Alternate Phone
          _buildCompactTextField(
            controller: _alternatePhoneCtrl,
            label: 'Alternate Phone (Optional)',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_callback_outlined,
          ),
        ],
      ),
    );
  }

  // ─── 6. FACTORY / OFFICE ADDRESS CARD ──────────────────────────────────────

  Widget _buildAddressCard() {
    return _buildSectionCard(
      icon: Icons.location_city_outlined,
      title: 'Factory / Office Address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Street Address
          _buildCompactTextField(
            controller: _addressCtrl,
            label: 'Street Address',
            required: true,
            maxLines: 2,
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 10),

          // Row 2: City & District
          Row(
            children: [
              Expanded(
                child: _buildCompactTextField(
                  controller: _cityCtrl,
                  label: 'City',
                  required: true,
                  prefixIcon: Icons.location_city,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactTextField(
                  controller: _districtCtrl,
                  label: 'District',
                  prefixIcon: Icons.map_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: State & Pincode
          Row(
            children: [
              Expanded(
                child: _buildCompactTextField(
                  controller: _stateCtrl,
                  label: 'State',
                  required: true,
                  prefixIcon: Icons.flag_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactTextField(
                  controller: _pincodeCtrl,
                  label: 'Pincode (Auto-lookup)',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.pin_drop_outlined,
                  onChanged: _onPincodeChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── STICKY ACTION BAR ─────────────────────────────────────────────────────

  Widget _buildStickyActionBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: _textMuted),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              '* All marked fields are mandatory for CRM compliance and GST invoicing',
              style: TextStyle(color: _textMuted, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          OutlinedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/crm/dashboard');
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _textSecondary,
              side: const BorderSide(color: _borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline, size: 15),
            label: Text(
              _isLoading
                  ? 'Saving Record...'
                  : (isEdit
                      ? 'Update Company Record'
                      : 'Save Company (Customer 360)'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── REUSABLE UI BUILDERS ──────────────────────────────────────────────────

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: _primaryAccent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 7),
              Icon(icon, size: 15, color: _primaryAccent),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                subtitle,
                style: const TextStyle(color: _textMuted, fontSize: 10.5),
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    bool required = false,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      labelStyle: const TextStyle(color: _textSecondary, fontSize: 12),
      floatingLabelStyle: const TextStyle(color: _primaryAccent, fontSize: 12),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 16, color: _textSecondary)
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      isDense: true,
      fillColor: _inputBg,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _primaryAccent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _errorColor, width: 1.4),
      ),
      errorStyle:
          const TextStyle(fontSize: 10.5, color: _errorColor, height: 1.1),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    IconData? prefixIcon,
    ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      style: const TextStyle(color: _textPrimary, fontSize: 13),
      onChanged: onChanged,
      decoration: _inputDecoration(
        label: label,
        required: required,
        prefixIcon: prefixIcon,
      ),
      validator: validator ??
          (required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required' : null
              : null),
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required dynamic items,
    required ValueChanged<String?> onChanged,
    bool required = false,
    IconData? prefixIcon,
  }) {
    List<DropdownMenuItem<String>> menuItems;
    if (items is Map<String, String>) {
      menuItems = items.entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 12.5)),
              ))
          .toList();
    } else if (items is List<String>) {
      menuItems = items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 12.5)),
              ))
          .toList();
    } else {
      menuItems = [];
    }

    final isValidValue = menuItems.any((item) => item.value == value);

    return DropdownButtonFormField<String>(
      initialValue: isValidValue
          ? value
          : (menuItems.isNotEmpty ? menuItems.first.value : null),
      decoration: _inputDecoration(
        label: label,
        required: required,
        prefixIcon: prefixIcon,
      ),
      dropdownColor: _cardBg,
      style: const TextStyle(color: _textPrimary, fontSize: 13),
      items: menuItems,
      onChanged: onChanged,
    );
  }
}
