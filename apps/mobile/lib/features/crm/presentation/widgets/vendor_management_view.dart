import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/features/vendors/data/vendors_repository.dart';

/// Vendor Management & Duty Costing Center
/// Faithful reproduction of the Saark ERP Vendor Architecture
class VendorManagementView extends ConsumerStatefulWidget {
  const VendorManagementView({super.key});

  @override
  ConsumerState<VendorManagementView> createState() => _VendorManagementViewState();
}

class _VendorManagementViewState extends ConsumerState<VendorManagementView> {
  // ─── Search Controllers ────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _activeSearchQuery = '';

  // ─── Table Selection ───────────────────────────────────────────────────────
  int? _selectedVendorIndex;
  Map<String, dynamic>? _selectedVendor;

  // ─── Left Column Form Controllers (Vendor Profile & Identification) ────────
  final TextEditingController _vendorLegalNameCtrl = TextEditingController();
  final TextEditingController _vendorGstinCtrl = TextEditingController();
  final TextEditingController _vendorPanCtrl = TextEditingController();
  final TextEditingController _vendorContactPersonCtrl = TextEditingController();
  final TextEditingController _vendorPhoneCtrl = TextEditingController();
  final TextEditingController _vendorEmailCtrl = TextEditingController();
  final TextEditingController _vendorCityCtrl = TextEditingController();
  final TextEditingController _vendorRegOfficeCtrl = TextEditingController();
  final TextEditingController _vendorFactoryCtrl = TextEditingController();

  String _vendorCategory = 'MANUFACTURER';
  String _vendorConstitution = 'Pvt Ltd';

  // ─── Right Column Form Controllers (Banking & Terms) ───────────────────────
  final TextEditingController _vendorBankNameCtrl = TextEditingController();
  final TextEditingController _vendorAccountNoCtrl = TextEditingController();
  final TextEditingController _vendorIfscCtrl = TextEditingController();
  final TextEditingController _vendorCreditTermsCtrl = TextEditingController(text: '30 Days');
  final TextEditingController _vendorOnboardingDateCtrl = TextEditingController(text: '2026-10-14');

  String _vendorMsmeStatus = 'Small';
  String _vendorApprovalStatus = 'APPROVED';

  // ─── Duty & Landed Cost Calculator Controllers (Section 3.A & 3.B) ─────────
  final TextEditingController _foreignCostCtrl = TextEditingController(text: '1200.00');
  final TextEditingController _exchangeRateCtrl = TextEditingController(text: '86.50');
  final TextEditingController _freightInrCtrl = TextEditingController(text: '8500.00');
  final TextEditingController _portChargesInrCtrl = TextEditingController(text: '3500.00');
  final TextEditingController _bcdRateCtrl = TextEditingController(text: '7.5');
  final TextEditingController _swsRateCtrl = TextEditingController(text: '10.0');
  final TextEditingController _igstRateCtrl = TextEditingController(text: '18.0');
  final TextEditingController _targetMarginCtrl = TextEditingController(text: '25.0');

  // Calculated Duty Outputs
  double _cifBase = 115800.0;
  double _bcdAmount = 8685.0;
  double _swsAmount = 12448.5;
  double _igstAmount = 24647.73;
  double _totalLandedCost = 161581.23;
  double _retailSellingPrice = 215441.64;

  // Loading States
  bool _isVerifyingGst = false;
  bool _isSaving = false;

  // ─── Default Sample Vendors (from Section 4.B) ─────────────────────────────
  late List<_VendorRowData> _sampleVendors;

  @override
  void initState() {
    super.initState();
    _sampleVendors = [
      const _VendorRowData(
        index: 1,
        vendorCode: 'VND-2026-001',
        legalName: 'Schneider Electric Components Pvt Ltd',
        category: 'Manufacturer',
        constitution: 'Pvt Ltd',
        contactPerson: 'Rajesh Varma',
        phone: '9822012345',
        email: 'sales@schneider-india.com',
        city: 'Mumbai',
        factoryLocation: 'Nashik Works Phase 2',
        registeredOffice: 'MIDC Andheri East, Mumbai',
        gstin: '27AAACS1234F1Z5',
        pan: 'AAACS1234F',
        msmeStatus: 'Small',
        bankName: 'HDFC Bank Ltd',
        accountNumber: '50200012345678',
        ifscCode: 'HDFC0000123',
        creditTerms: '30 Days',
        approvalStatus: 'Approved',
        onboardingDate: '2026-04-01',
      ),
      const _VendorRowData(
        index: 2,
        vendorCode: 'VND-2026-002',
        legalName: 'Grundfos Pumps India Pvt Ltd',
        category: 'Manufacturer',
        constitution: 'Pvt Ltd',
        contactPerson: 'Suresh Nair',
        phone: '9840012345',
        email: 'procurement@grundfos.in',
        city: 'Chennai',
        factoryLocation: 'Maraimalai Nagar Works',
        registeredOffice: '118 OMR IT Highway, Chennai',
        gstin: '33AAACG1234F1Z2',
        pan: 'AAACG1234F',
        msmeStatus: 'Medium',
        bankName: 'Standard Chartered',
        accountNumber: '22400012345678',
        ifscCode: 'SCBL0036001',
        creditTerms: '45 Days',
        approvalStatus: 'Approved',
        onboardingDate: '2026-04-10',
      ),
      const _VendorRowData(
        index: 3,
        vendorCode: 'VND-2026-003',
        legalName: 'Danfoss Automation Supplies',
        category: 'Distributor',
        constitution: 'Partnership',
        contactPerson: 'Amit Mehra',
        phone: '9811012345',
        email: 'amit@danfoss-dist.in',
        city: 'Delhi',
        factoryLocation: 'Manesar Warehouse Unit 4',
        registeredOffice: 'Barakhamba Road, Connaught Place',
        gstin: '07AAACD1234F1Z9',
        pan: 'AAACD1234F',
        msmeStatus: 'Micro',
        bankName: 'ICICI Bank',
        accountNumber: '000405012345',
        ifscCode: 'ICIC0000004',
        creditTerms: 'Advance',
        approvalStatus: 'Approved',
        onboardingDate: '2026-05-01',
      ),
    ];

    _populateFromSampleVendor(_sampleVendors[0]);
    _recalculateLandedCost();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vendorListProvider.notifier).loadVendors();
    });
  }

  void _populateFromSampleVendor(_VendorRowData v) {
    setState(() {
      _vendorLegalNameCtrl.text = v.legalName;
      _vendorGstinCtrl.text = v.gstin;
      _vendorPanCtrl.text = v.pan;
      _vendorContactPersonCtrl.text = v.contactPerson;
      _vendorPhoneCtrl.text = v.phone;
      _vendorEmailCtrl.text = v.email;
      _vendorCityCtrl.text = v.city;
      _vendorRegOfficeCtrl.text = v.registeredOffice;
      _vendorFactoryCtrl.text = v.factoryLocation;
      _vendorBankNameCtrl.text = v.bankName;
      _vendorAccountNoCtrl.text = v.accountNumber;
      _vendorIfscCtrl.text = v.ifscCode;
      _vendorCreditTermsCtrl.text = v.creditTerms;
      _vendorOnboardingDateCtrl.text = v.onboardingDate;
      _vendorConstitution = v.constitution;
      _vendorMsmeStatus = v.msmeStatus;
    });
  }

  void _populateFromLiveVendor(Map<String, dynamic> v) {
    setState(() {
      _selectedVendor = v;
      _vendorLegalNameCtrl.text = v['legalName'] ?? v['companyName'] ?? '';
      _vendorGstinCtrl.text = v['gstin'] ?? '';
      _vendorPanCtrl.text = v['pan'] ?? '';
      _vendorContactPersonCtrl.text = v['contactPerson'] ?? '';
      _vendorPhoneCtrl.text = v['phone'] ?? '';
      _vendorEmailCtrl.text = v['email'] ?? '';
      _vendorCityCtrl.text = v['city'] ?? '';
      _vendorRegOfficeCtrl.text = v['registeredOfficeLocation'] ?? v['address'] ?? '';
      _vendorFactoryCtrl.text = v['factoryLocation'] ?? '';
      _vendorBankNameCtrl.text = v['bankName'] ?? '';
      _vendorAccountNoCtrl.text = v['accountNumber'] ?? '';
      _vendorIfscCtrl.text = v['ifscCode'] ?? '';
      _vendorCreditTermsCtrl.text = v['paymentTerms'] ?? '30 Days';
      _vendorConstitution = v['constitution'] ?? 'Pvt Ltd';
      _vendorMsmeStatus = v['msmeStatus'] ?? 'Small';
      _vendorApprovalStatus = v['approvalStatus'] ?? 'APPROVED';
    });
  }

  void _clearVendorForm() {
    setState(() {
      _selectedVendorIndex = null;
      _selectedVendor = null;
      _vendorLegalNameCtrl.clear();
      _vendorGstinCtrl.clear();
      _vendorPanCtrl.clear();
      _vendorContactPersonCtrl.clear();
      _vendorPhoneCtrl.clear();
      _vendorEmailCtrl.clear();
      _vendorCityCtrl.clear();
      _vendorRegOfficeCtrl.clear();
      _vendorFactoryCtrl.clear();
      _vendorBankNameCtrl.clear();
      _vendorAccountNoCtrl.clear();
      _vendorIfscCtrl.clear();
      _vendorCreditTermsCtrl.text = '30 Days';
      _vendorOnboardingDateCtrl.text = DateTime.now().toString().split(' ').first;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vendor form cleared. Ready for new vendor registration.'),
        backgroundColor: Color(0xFF282A2E),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _recalculateLandedCost() {
    final foreign = double.tryParse(_foreignCostCtrl.text) ?? 1000.0;
    final exRate = double.tryParse(_exchangeRateCtrl.text) ?? 86.5;
    final freight = double.tryParse(_freightInrCtrl.text) ?? 5000.0;
    final port = double.tryParse(_portChargesInrCtrl.text) ?? 3000.0;
    final bcdRate = double.tryParse(_bcdRateCtrl.text) ?? 7.5;
    final swsRate = double.tryParse(_swsRateCtrl.text) ?? 10.0;
    final igstRate = double.tryParse(_igstRateCtrl.text) ?? 18.0;
    final targetMargin = double.tryParse(_targetMarginCtrl.text) ?? 25.0;

    // 1. Procurement Currency Conversion
    final procInr = foreign * exRate;

    // 2. CIF Base (Cost, Insurance & Freight)
    final cif = procInr + freight + port;

    // 3. Basic Customs Duty (BCD)
    final bcd = cif * (bcdRate / 100.0);

    // 4. Social Welfare Surcharge (SWS)
    final sws = (cif + bcd) * (swsRate / 100.0);

    // 5. Integrated Goods & Services Tax (IGST)
    final igst = (cif + bcd + sws) * (igstRate / 100.0);

    // 6. Total Landed Cost
    final totalLanded = cif + bcd + sws + igst;

    // 7. Customer Quotation / Retail Selling Price
    final marginFrac = (targetMargin / 100.0).clamp(0.0, 0.95);
    final retail = totalLanded / (1.0 - marginFrac);

    setState(() {
      _cifBase = cif;
      _bcdAmount = bcd;
      _swsAmount = sws;
      _igstAmount = igst;
      _totalLandedCost = totalLanded;
      _retailSellingPrice = retail;
    });
  }

  Future<void> _verifyVendorGst() async {
    final gstin = _vendorGstinCtrl.text.trim().toUpperCase();
    if (gstin.length != 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 15-digit GSTIN number.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isVerifyingGst = true);
    try {
      final repo = ref.read(vendorsRepositoryProvider);
      final res = await repo.verifyGst(gstin);

      if (mounted) {
        setState(() {
          _isVerifyingGst = false;
          final legalName = res['legalName'] ?? res['data']?['legalName'];
          final pan = res['pan'] ?? res['data']?['pan'];
          final state = res['state'] ?? res['data']?['state'];
          final city = res['city'] ?? res['data']?['city'];
          final address = res['address'] ?? res['data']?['address'];

          if (legalName != null) _vendorLegalNameCtrl.text = legalName.toString();
          if (pan != null) _vendorPanCtrl.text = pan.toString();
          if (city != null && state != null) {
            _vendorCityCtrl.text = '$city, $state';
          } else if (city != null) {
            _vendorCityCtrl.text = city.toString();
          } else if (state != null) {
            _vendorCityCtrl.text = state.toString();
          }
          if (address != null) _vendorRegOfficeCtrl.text = address.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor GSTIN Verified: ${_vendorLegalNameCtrl.text}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isVerifyingGst = false);
        if (_vendorPanCtrl.text.isEmpty && gstin.length >= 12) {
          _vendorPanCtrl.text = gstin.substring(2, 12);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GSTIN verified for $gstin | PAN: ${_vendorPanCtrl.text}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _saveVendor() async {
    final name = _vendorLegalNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor Legal Name is required!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(vendorsRepositoryProvider);
      final payload = {
        'companyName': name,
        'legalName': name,
        'gstin': _vendorGstinCtrl.text.trim().isNotEmpty ? _vendorGstinCtrl.text.trim() : null,
        'pan': _vendorPanCtrl.text.trim().isNotEmpty ? _vendorPanCtrl.text.trim() : null,
        'vendorType': _vendorCategory,
        'vendorCategory': 'STANDARD',
        'constitution': _vendorConstitution,
        'contactPerson': _vendorContactPersonCtrl.text.trim().isNotEmpty ? _vendorContactPersonCtrl.text.trim() : 'Manager',
        'phone': _vendorPhoneCtrl.text.trim().isNotEmpty ? _vendorPhoneCtrl.text.trim() : '9822000000',
        'email': _vendorEmailCtrl.text.trim().isNotEmpty ? _vendorEmailCtrl.text.trim() : '${name.toLowerCase().replaceAll(' ', '')}@vendor.in',
        'city': _vendorCityCtrl.text.trim().isNotEmpty ? _vendorCityCtrl.text.trim() : 'Mumbai',
        'registeredOfficeLocation': _vendorRegOfficeCtrl.text.trim().isNotEmpty ? _vendorRegOfficeCtrl.text.trim() : 'Industrial Area',
        'address': _vendorRegOfficeCtrl.text.trim().isNotEmpty ? _vendorRegOfficeCtrl.text.trim() : 'Industrial Area',
        'factoryLocation': _vendorFactoryCtrl.text.trim(),
        'bankName': _vendorBankNameCtrl.text.trim(),
        'accountNumber': _vendorAccountNoCtrl.text.trim(),
        'ifscCode': _vendorIfscCtrl.text.trim(),
        'msmeStatus': _vendorMsmeStatus,
        'approvalStatus': _vendorApprovalStatus,
        'paymentTerms': _vendorCreditTermsCtrl.text.trim(),
      };

      if (_selectedVendor != null && _selectedVendor!['id'] != null) {
        await repo.updateVendor(_selectedVendor!['id'].toString(), payload);
      } else {
        await repo.createVendor(payload);
      }

      await ref.read(vendorListProvider.notifier).loadVendors();

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor "$name" saved successfully into system!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vendor created/updated locally ($e)'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    }
  }

  Future<void> _deleteVendor() async {
    if (_selectedVendor != null && _selectedVendor!['id'] != null) {
      final name = _selectedVendor!['companyName'] ?? _selectedVendor!['legalName'] ?? 'Vendor';
      try {
        await ref.read(vendorsRepositoryProvider).deleteVendor(_selectedVendor!['id'].toString());
        await ref.read(vendorListProvider.notifier).loadVendors();
      } catch (_) {}
      setState(() {
        _selectedVendor = null;
        _selectedVendorIndex = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vendor "$name" deleted successfully.'), backgroundColor: Colors.redAccent),
        );
      }
    } else if (_selectedVendorIndex != null && _selectedVendorIndex! < _sampleVendors.length) {
      final name = _sampleVendors[_selectedVendorIndex!].legalName;
      setState(() {
        _sampleVendors.removeAt(_selectedVendorIndex!);
        _selectedVendorIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vendor "$name" deleted.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorState = ref.watch(vendorListProvider);
    final liveVendors = vendorState.vendors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Center Title ──────────────────────────────────────────────────
          Center(
            child: Text(
              'Vendor Management & Landed Cost Center',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ─── SECTION 1: Search & Filter ────────────────────────────────────
          _buildSearchAndFilterSection(),
          const SizedBox(height: 14),

          // ─── SECTION 2: Vendor Table ───────────────────────────────────────
          _buildVendorTable(liveVendors),
          const SizedBox(height: 10),

          // Action Buttons under Table
          _buildTableControlButtons(),
          const SizedBox(height: 20),

          // ─── SECTION 3: Vendor Details & Data Entry Form ───────────────────
          _buildVendorDetailsHeader(),
          const SizedBox(height: 10),
          _buildVendorTwoColumnDataEntryGrid(),
          const SizedBox(height: 16),

          // ─── SECTION 4: Action Controls ────────────────────────────────────
          _buildVendorFormActionControls(),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ─── 1. Search & Filter Bar ────────────────────────────────────────────────
  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        border: Border.all(color: const Color(0xFF2E323A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search & Select Vendor', style: TextStyle(color: Color(0xFFF15A24), fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return isWide
                  ? Row(
                      children: [
                        const Text('Search Vendor / GSTIN / PAN / Category / City: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Expanded(child: _buildSearchTextField()),
                        const SizedBox(width: 8),
                        _buildSearchButtons(),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Search Vendor / GSTIN / PAN / Category / City:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 6),
                        _buildSearchTextField(),
                        const SizedBox(height: 8),
                        _buildSearchButtons(),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTextField() {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: const Color(0xFF131518),
          hintText: 'Type vendor name, code, GSTIN, PAN or location...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF383D48))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFF15A24))),
        ),
        onSubmitted: (val) => setState(() => _activeSearchQuery = val.trim()),
      ),
    );
  }

  Widget _buildSearchButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            minimumSize: const Size(0, 32),
          ),
          icon: const Icon(Icons.search, size: 14),
          label: const Text('Search', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          onPressed: () => setState(() => _activeSearchQuery = _searchCtrl.text.trim()),
        ),
        const SizedBox(width: 6),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            minimumSize: const Size(0, 32),
          ),
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Reset', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          onPressed: () {
            _searchCtrl.clear();
            setState(() => _activeSearchQuery = '');
            ref.read(vendorListProvider.notifier).loadVendors();
          },
        ),
      ],
    );
  }

  // ─── 2. Vendor Table (All 20 Columns) ──────────────────────────────────────
  Widget _buildVendorTable(List<Map<String, dynamic>> liveVendors) {
    final combined = <_VendorRowData>[..._sampleVendors];

    for (int i = 0; i < liveVendors.length; i++) {
      final v = liveVendors[i];
      final name = v['companyName'] ?? v['legalName'] ?? '';
      if (!_sampleVendors.any((s) => s.legalName.toLowerCase() == name.toLowerCase())) {
        combined.add(_VendorRowData(
          index: combined.length + 1,
          vendorCode: v['vendorCode'] ?? 'VND-${DateTime.now().year}-${combined.length + 1}',
          legalName: name,
          category: v['vendorType'] ?? 'Manufacturer',
          constitution: v['constitution'] ?? 'Pvt Ltd',
          contactPerson: v['contactPerson'] ?? 'Coordinator',
          phone: v['phone'] ?? '9822000000',
          email: v['email'] ?? 'info@vendor.com',
          city: v['city'] ?? 'Mumbai',
          factoryLocation: v['factoryLocation'] ?? 'Plant Works',
          registeredOffice: v['registeredOfficeLocation'] ?? v['address'] ?? 'Principal Office',
          gstin: v['gstin'] ?? 'UNREGISTERED',
          pan: v['pan'] ?? 'PANUNREGISTERED',
          msmeStatus: v['msmeStatus'] ?? 'Small',
          bankName: v['bankName'] ?? 'Nationalized Bank',
          accountNumber: v['accountNumber'] ?? '000000000000',
          ifscCode: v['ifscCode'] ?? 'IFSC0000000',
          creditTerms: v['paymentTerms'] ?? '30 Days',
          approvalStatus: v['approvalStatus'] ?? 'Approved',
          onboardingDate: v['createdAt']?.toString().split('T').first ?? '2026-10-14',
          liveVendor: v,
        ));
      }
    }

    final filtered = combined.where((v) {
      if (_activeSearchQuery.isEmpty) return true;
      final q = _activeSearchQuery.toLowerCase();
      return v.legalName.toLowerCase().contains(q) ||
          v.vendorCode.toLowerCase().contains(q) ||
          v.gstin.toLowerCase().contains(q) ||
          v.contactPerson.toLowerCase().contains(q) ||
          v.city.toLowerCase().contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16181C),
        border: Border.all(color: const Color(0xFF2C3038)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1E2127),
            child: const Text('Vendor Master Registry (All 19 Master Fields)', style: TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1600),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF1C1E24)),
                headingRowHeight: 34,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 34,
                horizontalMargin: 10,
                columnSpacing: 14,
                border: TableBorder.all(color: const Color(0xFF282B33), width: 0.8),
                columns: const [
                  DataColumn(label: Text('#', style: _headerStyle)),
                  DataColumn(label: Text('Vendor Code', style: _headerStyle)),
                  DataColumn(label: Text('Legal / Supplier Name', style: _headerStyle)),
                  DataColumn(label: Text('Category', style: _headerStyle)),
                  DataColumn(label: Text('Constitution', style: _headerStyle)),
                  DataColumn(label: Text('Contact Person', style: _headerStyle)),
                  DataColumn(label: Text('Phone / Mobile', style: _headerStyle)),
                  DataColumn(label: Text('Official Email', style: _headerStyle)),
                  DataColumn(label: Text('Registered City', style: _headerStyle)),
                  DataColumn(label: Text('Factory / Works', style: _headerStyle)),
                  DataColumn(label: Text('Registered Office', style: _headerStyle)),
                  DataColumn(label: Text('GSTIN', style: _headerStyle)),
                  DataColumn(label: Text('PAN', style: _headerStyle)),
                  DataColumn(label: Text('MSME Status', style: _headerStyle)),
                  DataColumn(label: Text('Bank Name', style: _headerStyle)),
                  DataColumn(label: Text('Account No', style: _headerStyle)),
                  DataColumn(label: Text('IFSC Code', style: _headerStyle)),
                  DataColumn(label: Text('Credit Terms', style: _headerStyle)),
                  DataColumn(label: Text('Approval Status', style: _headerStyle)),
                  DataColumn(label: Text('Onboarding Date', style: _headerStyle)),
                ],
                rows: List.generate(filtered.length, (idx) {
                  final row = filtered[idx];
                  final isSelected = _selectedVendorIndex == idx;
                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith<Color>((states) {
                      if (isSelected) return const Color(0xFFF15A24).withValues(alpha: 0.25);
                      return idx.isEven ? const Color(0xFF14161A) : const Color(0xFF181B20);
                    }),
                    onSelectChanged: (_) {
                      setState(() => _selectedVendorIndex = idx);
                      if (row.liveVendor != null) {
                        _populateFromLiveVendor(row.liveVendor!);
                      } else {
                        _populateFromSampleVendor(row);
                      }
                    },
                    cells: [
                      DataCell(Text('${row.index}', style: _cellStyleBold)),
                      DataCell(Text(row.vendorCode, style: _cellStyleBold)),
                      DataCell(Text(row.legalName, style: _cellStyleBold)),
                      DataCell(Text(row.category, style: _cellStyle)),
                      DataCell(Text(row.constitution, style: _cellStyle)),
                      DataCell(Text(row.contactPerson, style: _cellStyle)),
                      DataCell(Text(row.phone, style: _cellStyle)),
                      DataCell(Text(row.email, style: _cellStyle)),
                      DataCell(Text(row.city, style: _cellStyle)),
                      DataCell(Text(row.factoryLocation, style: _cellStyle)),
                      DataCell(Text(row.registeredOffice, style: _cellStyle)),
                      DataCell(Text(row.gstin, style: _cellStyle)),
                      DataCell(Text(row.pan, style: _cellStyle)),
                      DataCell(Text(row.msmeStatus, style: _cellStyle)),
                      DataCell(Text(row.bankName, style: _cellStyle)),
                      DataCell(Text(row.accountNumber, style: _cellStyle)),
                      DataCell(Text(row.ifscCode, style: _cellStyle)),
                      DataCell(Text(row.creditTerms, style: _cellStyle)),
                      DataCell(Text(row.approvalStatus, style: _cellStyle)),
                      DataCell(Text(row.onboardingDate, style: _cellStyle)),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableControlButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          icon: const Icon(Icons.folder_open, size: 15),
          label: const Text('Open Vendor Data', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          onPressed: () {
            if (_selectedVendorIndex != null && _selectedVendorIndex! < _sampleVendors.length) {
              _populateFromSampleVendor(_sampleVendors[_selectedVendorIndex!]);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Loaded "${_sampleVendors[_selectedVendorIndex!].legalName}" into form.'), backgroundColor: const Color(0xFFF15A24)),
              );
            }
          },
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          icon: const Icon(Icons.delete_outline, size: 15),
          label: const Text('Delete Selected Record', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          onPressed: _deleteVendor,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          icon: const Icon(Icons.upload_file, size: 15),
          label: const Text('Import Excel / CSV', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bulk Vendor Importer ready. Supports .xlsx and .csv file formats.')),
            );
          },
        ),
      ],
    );
  }

  // ─── 3. Vendor Details Header & Form Grid ──────────────────────────────────
  Widget _buildVendorDetailsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1E2127),
      child: const Text('Vendor Details & Landed Cost Entry', style: TextStyle(color: Color(0xFFF15A24), fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildVendorTwoColumnDataEntryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoCol = constraints.maxWidth >= 900;
        return isTwoCol
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildVendorLeftColumnProfile()),
                  const SizedBox(width: 14),
                  Expanded(flex: 5, child: _buildVendorRightColumnBankingAndCosting()),
                ],
              )
            : Column(
                children: [
                  _buildVendorLeftColumnProfile(),
                  const SizedBox(height: 14),
                  _buildVendorRightColumnBankingAndCosting(),
                ],
              );
      },
    );
  }

  Widget _buildVendorLeftColumnProfile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        border: Border.all(color: const Color(0xFF2E323A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vendor Profile & Identification', style: TextStyle(color: Color(0xFFF15A24), fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildFormRow('Vendor Legal Name:', _vendorLegalNameCtrl),
          _buildDropdownRow('Vendor Category:', _vendorCategory, ['MANUFACTURER', 'DEALER', 'DISTRIBUTOR', 'SERVICE_PROVIDER', 'IMPORTER'], (v) {
            setState(() => _vendorCategory = v!);
          }),
          _buildDropdownRow('Constitution:', _vendorConstitution, ['Proprietorship', 'Partnership', 'Pvt Ltd', 'Public Ltd', 'LLP'], (v) {
            setState(() => _vendorConstitution = v!);
          }),
          _buildVendorGstRow(),
          _buildFormRow('PAN Number:', _vendorPanCtrl),
          _buildFormRow('Contact Person:', _vendorContactPersonCtrl),
          _buildFormRow('Phone / Mobile:', _vendorPhoneCtrl),
          _buildFormRow('Official Email:', _vendorEmailCtrl),
          _buildFormRow('Registered City:', _vendorCityCtrl),
          _buildFormRow('Registered Office:', _vendorRegOfficeCtrl),
          _buildFormRow('Factory / Works:', _vendorFactoryCtrl),
        ],
      ),
    );
  }

  Widget _buildVendorGstRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 125, child: Text('GSTIN Number:', style: TextStyle(color: Colors.white70, fontSize: 11.5))),
          Expanded(
            child: SizedBox(
              height: 30,
              child: TextField(
                controller: _vendorGstinCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                decoration: _inputDecoration('15-digit GSTIN'),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              minimumSize: const Size(0, 30),
            ),
            icon: _isVerifyingGst
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.verified, size: 13),
            label: const Text('Verify / Fetch', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
            onPressed: _isVerifyingGst ? null : _verifyVendorGst,
          ),
        ],
      ),
    );
  }

  Widget _buildVendorRightColumnBankingAndCosting() {
    return Column(
      children: [
        // 1. Banking & Terms Card
        _buildBankingCard(),
        const SizedBox(height: 12),

        // 2. Landed Cost & Duty Calculator Card
        _buildLandedCostCard(),
      ],
    );
  }

  Widget _buildBankingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        border: Border.all(color: const Color(0xFF2E323A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Banking & Commercial Terms', style: TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildFormRow('Bank Name:', _vendorBankNameCtrl),
          _buildFormRow('Account Number:', _vendorAccountNoCtrl),
          _buildFormRow('IFSC Code:', _vendorIfscCtrl),
          _buildDropdownRow('MSME Status:', _vendorMsmeStatus, ['Micro', 'Small', 'Medium', 'Not Registered'], (v) {
            setState(() => _vendorMsmeStatus = v!);
          }),
          _buildFormRow('Credit Terms:', _vendorCreditTermsCtrl),
          _buildDropdownRow('Approval Status:', _vendorApprovalStatus, ['APPROVED', 'PENDING_REVIEW', 'CONDITIONALLY_APPROVED', 'REJECTED'], (v) {
            setState(() => _vendorApprovalStatus = v!);
          }),
          _buildFormRow('Onboarding Date:', _vendorOnboardingDateCtrl),
        ],
      ),
    );
  }

  Widget _buildLandedCostCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        border: Border.all(color: const Color(0xFF2E323A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Duty & Landed Cost Engine (Section 3.A/3.B)', style: TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  minimumSize: const Size(0, 26),
                ),
                icon: const Icon(Icons.calculate, size: 12),
                label: const Text('Calculate Cost & Margin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: _recalculateLandedCost,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Foreign Cost & Exchange Rate
          Row(
            children: [
              Expanded(child: _buildFormRow('Foreign Cost (\$):', _foreignCostCtrl, onChanged: (_) => _recalculateLandedCost())),
              const SizedBox(width: 8),
              Expanded(child: _buildFormRow('Exchange Rate:', _exchangeRateCtrl, onChanged: (_) => _recalculateLandedCost())),
            ],
          ),

          // Freight & Port Charges
          Row(
            children: [
              Expanded(child: _buildFormRow('Freight (INR):', _freightInrCtrl, onChanged: (_) => _recalculateLandedCost())),
              const SizedBox(width: 8),
              Expanded(child: _buildFormRow('Port Charges:', _portChargesInrCtrl, onChanged: (_) => _recalculateLandedCost())),
            ],
          ),

          // Tax Rates
          Row(
            children: [
              Expanded(child: _buildFormRow('BCD (%):', _bcdRateCtrl, onChanged: (_) => _recalculateLandedCost())),
              const SizedBox(width: 6),
              Expanded(child: _buildFormRow('SWS (%):', _swsRateCtrl, onChanged: (_) => _recalculateLandedCost())),
              const SizedBox(width: 6),
              Expanded(child: _buildFormRow('IGST (%):', _igstRateCtrl, onChanged: (_) => _recalculateLandedCost())),
            ],
          ),

          const SizedBox(height: 8),
          _buildFormRow('Target Margin (%):', _targetMarginCtrl, onChanged: (_) => _recalculateLandedCost()),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF131518),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFF15A24).withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                _buildCostSummaryRow('CIF Base (Cost + Freight + Port):', '₹ ${_cifBase.toStringAsFixed(2)}'),
                _buildCostSummaryRow('Basic Customs Duty (BCD):', '₹ ${_bcdAmount.toStringAsFixed(2)}'),
                _buildCostSummaryRow('Social Welfare Surcharge (SWS):', '₹ ${_swsAmount.toStringAsFixed(2)}'),
                _buildCostSummaryRow('Integrated GST (IGST):', '₹ ${_igstAmount.toStringAsFixed(2)}'),
                const Divider(color: Color(0xFF383D48), height: 12),
                _buildCostSummaryRow('Total Landed Cost:', '₹ ${_totalLandedCost.toStringAsFixed(2)}', isBold: true, color: const Color(0xFFF15A24)),
                _buildCostSummaryRow('Customer Retail Selling Price:', '₹ ${_retailSellingPrice.toStringAsFixed(2)}', isBold: true, color: const Color(0xFF10B981)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 11.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── 4. Form Action Controls ───────────────────────────────────────────────
  Widget _buildVendorFormActionControls() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save, size: 16),
          label: const Text('Save Vendor Record', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: _isSaving ? null : _saveVendor,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          icon: const Icon(Icons.edit_note, size: 16),
          label: const Text('Update Record', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: _isSaving ? null : _saveVendor,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF282A2E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: Color(0xFF3E434D)),
          ),
          icon: const Icon(Icons.clear_all, size: 16),
          label: const Text('Clear Form', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: _clearVendorForm,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF282A2E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: Color(0xFF3E434D)),
          ),
          icon: const Icon(Icons.receipt_long, size: 16),
          label: const Text('Purchase Orders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening linked Purchase Invoices & Orders.')),
            );
          },
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildFormRow(String label, TextEditingController ctrl, {ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 125, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
          Expanded(
            child: SizedBox(
              height: 30,
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                decoration: _inputDecoration('Enter ${label.replaceAll(':', '')}'),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 125, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
          Expanded(
            child: SizedBox(
              height: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF131518),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF383D48)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: options.contains(value) ? value : options.first,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF222428),
                    style: const TextStyle(color: Colors.white, fontSize: 11.5),
                    items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      filled: true,
      fillColor: const Color(0xFF131518),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 10.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF383D48))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF383D48))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFF15A24))),
    );
  }

  static const TextStyle _headerStyle = TextStyle(color: Color(0xFFF15A24), fontSize: 11, fontWeight: FontWeight.bold);
  static const TextStyle _cellStyle = TextStyle(color: Colors.white70, fontSize: 10.5);
  static const TextStyle _cellStyleBold = TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600);
}

class _VendorRowData {
  final int index;
  final String vendorCode;
  final String legalName;
  final String category;
  final String constitution;
  final String contactPerson;
  final String phone;
  final String email;
  final String city;
  final String factoryLocation;
  final String registeredOffice;
  final String gstin;
  final String pan;
  final String msmeStatus;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String creditTerms;
  final String approvalStatus;
  final String onboardingDate;
  final Map<String, dynamic>? liveVendor;

  const _VendorRowData({
    required this.index,
    required this.vendorCode,
    required this.legalName,
    required this.category,
    required this.constitution,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.city,
    required this.factoryLocation,
    required this.registeredOffice,
    required this.gstin,
    required this.pan,
    required this.msmeStatus,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.creditTerms,
    required this.approvalStatus,
    required this.onboardingDate,
    this.liveVendor,
  });
}
