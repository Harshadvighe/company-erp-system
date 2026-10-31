import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';
import '../../data/b2b_trading_repository.dart';

class B2bProductManagerModal extends ConsumerStatefulWidget {
  final B2bProductModel? productToEdit;
  final VoidCallback? onProductSaved;

  const B2bProductManagerModal({
    super.key,
    this.productToEdit,
    this.onProductSaved,
  });

  @override
  ConsumerState<B2bProductManagerModal> createState() => _B2bProductManagerModalState();
}

class _B2bProductManagerModalState extends ConsumerState<B2bProductManagerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 2);

  // Tab 1: Taxonomy & Identification
  String _primaryCategory = 'Domestic';
  String _subCategory = '';
  final _internalTagsCtrl = TextEditingController();
  final _originalNameCtrl = TextEditingController();
  final _originalModelCtrl = TextEditingController();
  final _rebrandedNameCtrl = TextEditingController();
  final _rebrandedModelCtrl = TextEditingController();
  final _collectionCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Tab 2: Supplier & Sourcing
  String? _selectedSupplierId;
  final _moqCtrl = TextEditingController(text: '100');
  final _sampleCostCtrl = TextEditingController(text: '5000');
  final _leadTimeCtrl = TextEditingController(text: '25');
  final _ratingCtrl = TextEditingController(text: '5.0');
  List<Map<String, dynamic>> _suppliers = [];

  // Tab 3: Technical Specs & Variants
  final _materialCtrl = TextEditingController(text: 'SS304');
  final _dimensionsCtrl = TextEditingController(text: '250x180x90 mm');
  final _weightCtrl = TextEditingController(text: '2.5');
  final _hsCodeCtrl = TextEditingController(text: '841370');
  final List<Map<String, dynamic>> _variants = [];

  // Tab 4: White-Labeling & Branding
  final _logoPathCtrl = TextEditingController(text: 'assets/branding/saark_logo.png');
  final _insertCardCtrl = TextEditingController(text: 'assets/branding/warranty_card.pdf');
  final _pkgDimsCtrl = TextEditingController(text: 'Standard Export Carton');
  final _printingSpecsCtrl = TextEditingController(text: 'CMYK 4-Color Print');
  final _barcodePlacementCtrl = TextEditingController(text: 'Side Panel Lower Right');
  final _brandCopyCtrl = TextEditingController(text: 'High Efficiency White-Label Product');
  final _seoMetaCtrl = TextEditingController(text: 'industrial, valve, pump, b2b');

  // Tab 5: Financials & Costing
  final _baseCostCtrl = TextEditingController(text: '10.00');
  final _brandingFeeCtrl = TextEditingController(text: '876.00');
  final _sampleShippingCtrl = TextEditingController(text: '876.00');
  final _freightPerUnitCtrl = TextEditingController(text: '876.00');
  final _retailPriceCtrl = TextEditingController(text: '87600.00');
  final _targetMarginCtrl = TextEditingController();

  // Import Customs calculation toggle
  bool _isImportCustoms = false;
  final _exchangeRateCtrl = TextEditingController(text: '87.5');
  final _portChargesCtrl = TextEditingController(text: '250');
  final _bcdRateCtrl = TextEditingController(text: '7.5');
  final _swsRateCtrl = TextEditingController(text: '10.0');
  final _igstRateCtrl = TextEditingController(text: '18.0');

  // Derived financials
  double _calculatedLandedCost = 2638.00;
  double _calculatedMarginPct = 96.99;
  double _calculatedGrossProfit = 84962.00;

  // Tab 6: Media & Document Vault
  final List<Map<String, dynamic>> _documents = [];
  bool _isUploadingDoc = false;

  bool _isSaving = false;

  final List<String> _primaryCategories = [
    'Domestic',
    'Industrial',
    'Commercial',
    'Custom',
    'domastic',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadSuppliers();

    if (widget.productToEdit != null) {
      _populateFromProduct(widget.productToEdit!);
    } else {
      _recalculateFinancials();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _internalTagsCtrl.dispose();
    _originalNameCtrl.dispose();
    _originalModelCtrl.dispose();
    _rebrandedNameCtrl.dispose();
    _rebrandedModelCtrl.dispose();
    _collectionCtrl.dispose();
    _descriptionCtrl.dispose();
    _moqCtrl.dispose();
    _sampleCostCtrl.dispose();
    _leadTimeCtrl.dispose();
    _ratingCtrl.dispose();
    _materialCtrl.dispose();
    _dimensionsCtrl.dispose();
    _weightCtrl.dispose();
    _hsCodeCtrl.dispose();
    _logoPathCtrl.dispose();
    _insertCardCtrl.dispose();
    _pkgDimsCtrl.dispose();
    _printingSpecsCtrl.dispose();
    _barcodePlacementCtrl.dispose();
    _brandCopyCtrl.dispose();
    _seoMetaCtrl.dispose();
    _baseCostCtrl.dispose();
    _brandingFeeCtrl.dispose();
    _sampleShippingCtrl.dispose();
    _freightPerUnitCtrl.dispose();
    _retailPriceCtrl.dispose();
    _targetMarginCtrl.dispose();
    _exchangeRateCtrl.dispose();
    _portChargesCtrl.dispose();
    _bcdRateCtrl.dispose();
    _swsRateCtrl.dispose();
    _igstRateCtrl.dispose();
    super.dispose();
  }

  void _populateFromProduct(B2bProductModel p) {
    _primaryCategory = p.primaryCategory;
    _subCategory = p.subCategory ?? '';
    _internalTagsCtrl.text = p.internalTag ?? '';
    _originalNameCtrl.text = p.originalName;
    _originalModelCtrl.text = p.originalModel;
    _rebrandedNameCtrl.text = p.rebrandedName;
    _rebrandedModelCtrl.text = p.rebrandedModel;
    _collectionCtrl.text = p.collection ?? '';
    _descriptionCtrl.text = p.description ?? '';
    _selectedSupplierId = p.supplierId;
    _moqCtrl.text = p.moq.toString();
    _sampleCostCtrl.text = p.sampleCost.toString();
    _leadTimeCtrl.text = p.leadTime.toString();
    _ratingCtrl.text = p.rating.toString();
    _materialCtrl.text = p.material ?? '';
    _dimensionsCtrl.text = p.dimensions ?? '';
    _weightCtrl.text = p.weight?.toString() ?? '';
    _hsCodeCtrl.text = p.hsCode ?? '';
    _logoPathCtrl.text = p.logoPath ?? '';
    _insertCardCtrl.text = p.insertCardPath ?? '';
    _pkgDimsCtrl.text = p.pkgDims ?? '';
    _printingSpecsCtrl.text = p.printingSpecs ?? '';
    _barcodePlacementCtrl.text = p.barcodePlacement ?? '';
    _brandCopyCtrl.text = p.brandCopy ?? '';
    _seoMetaCtrl.text = p.seoMeta ?? '';
    _baseCostCtrl.text = p.baseCost.toStringAsFixed(2);
    _brandingFeeCtrl.text = p.brandingFee.toStringAsFixed(2);
    _sampleShippingCtrl.text = p.sampleShipping.toStringAsFixed(2);
    _freightPerUnitCtrl.text = p.freightPerUnit.toStringAsFixed(2);
    _retailPriceCtrl.text = p.retailPrice.toStringAsFixed(2);

    _variants.clear();
    for (final v in p.variants) {
      if (v is Map) {
        _variants.add(Map<String, dynamic>.from(v));
      }
    }

    _documents.clear();
    for (final d in p.documents) {
      if (d is Map) {
        _documents.add(Map<String, dynamic>.from(d));
      }
    }

    _recalculateFinancials();
  }

  Future<void> _loadSuppliers() async {
    try {
      final repo = ref.read(b2bTradingRepositoryProvider);
      final list = await repo.getSuppliers();
      if (mounted) {
        setState(() {
          _suppliers = list;
          if (_selectedSupplierId == null && _suppliers.isNotEmpty) {
            _selectedSupplierId = _suppliers.first['id']?.toString();
          }
        });
      }
    } catch (_) {}
  }

  // ─── Direct Formula Execution: Landed Cost & Gross Margin ──────────────────
  void _recalculateFinancials() {
    final base = double.tryParse(_baseCostCtrl.text.trim()) ?? 0.0;
    final branding = double.tryParse(_brandingFeeCtrl.text.trim()) ?? 0.0;
    final packaging = double.tryParse(_sampleShippingCtrl.text.trim()) ?? 0.0;
    final freight = double.tryParse(_freightPerUnitCtrl.text.trim()) ?? 0.0;
    var retail = double.tryParse(_retailPriceCtrl.text.trim()) ?? 0.0;
    final targetMargin = double.tryParse(_targetMarginCtrl.text.trim());

    double landed = base + branding + packaging + freight;

    if (_isImportCustoms) {
      final exRate = double.tryParse(_exchangeRateCtrl.text.trim()) ?? 87.5;
      final portCharges = double.tryParse(_portChargesCtrl.text.trim()) ?? 250.0;
      final bcdRate = double.tryParse(_bcdRateCtrl.text.trim()) ?? 7.5;
      final swsRate = double.tryParse(_swsRateCtrl.text.trim()) ?? 10.0;
      final igstRate = double.tryParse(_igstRateCtrl.text.trim()) ?? 18.0;

      final procurementInr = base * exRate;
      final freightInr = freight * exRate;
      final cifBase = procurementInr + freightInr + portCharges;
      final bcdAmount = (cifBase * bcdRate) / 100.0;
      final swsAmount = ((cifBase + bcdAmount) * swsRate) / 100.0;
      final igstAmount = ((cifBase + bcdAmount + swsAmount) * igstRate) / 100.0;

      landed = cifBase + bcdAmount + swsAmount + igstAmount + branding + packaging;
    }

    if (targetMargin != null && targetMargin > 0 && targetMargin < 100 && retail == 0) {
      retail = landed / (1 - (targetMargin / 100.0));
      _retailPriceCtrl.text = retail.toStringAsFixed(2);
    }

    double margin = 0.0;
    if (retail > 0) {
      margin = ((retail - landed) / retail) * 100.0;
    }

    setState(() {
      _calculatedLandedCost = landed;
      _calculatedMarginPct = margin;
      _calculatedGrossProfit = retail - landed;
    });
  }

  // ─── File Pick & Upload Handlers ───────────────────────────────────────────
  void _pickAndUploadAsset(String type, TextEditingController controller) {
    pickAndUploadWebFile(
      fieldType: type,
      onFilePicked: (fileName, bytes) async {
        setState(() => _isSaving = true);
        try {
          final repo = ref.read(b2bTradingRepositoryProvider);
          final res = await repo.uploadMediaFile(
            bytes: bytes,
            fileName: fileName,
            assetType: type == 'LOGO' ? 'LOGO' : 'INSERT_CARD',
            productId: widget.productToEdit?.id,
          );
          final path = res['filePath'] ?? res['fileUrl'] ?? '';
          if (mounted) {
            setState(() {
              _isSaving = false;
              if (path.isNotEmpty) {
                controller.text = path;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$type "$fileName" uploaded successfully!'),
                backgroundColor: const Color(0xFF2ECC71),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
            );
          }
        }
      },
    );
  }

  void _pickAndUploadMedia(String assetType, String label) {
    String filter = 'PDF';
    if (assetType == 'IMAGE') filter = 'IMAGE';
    if (assetType == 'ARTWORK') filter = 'ARTWORK';

    pickAndUploadWebFile(
      fieldType: filter,
      onFilePicked: (fileName, bytes) async {
        setState(() => _isUploadingDoc = true);
        try {
          final repo = ref.read(b2bTradingRepositoryProvider);
          final res = await repo.uploadMediaFile(
            bytes: bytes,
            fileName: fileName,
            assetType: assetType,
            productId: widget.productToEdit?.id,
            description: label,
          );
          if (mounted) {
            setState(() {
              _isUploadingDoc = false;
              _documents.add({
                'id': res['id'] ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
                'assetType': assetType,
                'fileName': fileName,
                'filePath': res['filePath'] ?? res['fileUrl'] ?? '',
                'fileSize': res['fileSize'] ?? bytes.length,
                'description': label,
              });
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Uploaded $label: $fileName'),
                backgroundColor: const Color(0xFF2ECC71),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isUploadingDoc = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
            );
          }
        }
      },
    );
  }

  // ─── Comprehensive Validation & Saving ────────────────────────────────────
  Future<void> _saveProduct(String targetStatus) async {
    final origName = _originalNameCtrl.text.trim();
    final origModel = _originalModelCtrl.text.trim();
    final rebrName = _rebrandedNameCtrl.text.trim();
    final rebrModel = _rebrandedModelCtrl.text.trim();

    final List<String> validationErrors = [];

    if (origName.isEmpty) validationErrors.add('Original Product Name is required.');
    if (origModel.isEmpty) validationErrors.add('Original Model Number is required.');
    if (rebrName.isEmpty) validationErrors.add('Rebranded Product Name is required.');
    if (rebrModel.isEmpty) validationErrors.add('Rebranded Model Number is required.');

    final baseCost = double.tryParse(_baseCostCtrl.text.trim());
    if (baseCost == null || baseCost < 0) {
      validationErrors.add('Unit Purchase Cost must be a valid non-negative number.');
    }

    final retailPrice = double.tryParse(_retailPriceCtrl.text.trim());
    if (retailPrice == null || retailPrice < 0) {
      validationErrors.add('Retail Selling Price must be a valid non-negative number.');
    }

    final moq = int.tryParse(_moqCtrl.text.trim());
    if (moq == null || moq < 1) {
      validationErrors.add('MOQ must be at least 1 unit.');
    }

    final rating = double.tryParse(_ratingCtrl.text.trim());
    if (rating == null || rating < 1.0 || rating > 5.0) {
      validationErrors.add('Factory rating must be between 1.0 and 5.0.');
    }

    if (targetStatus == 'published') {
      if (_selectedSupplierId == null || _selectedSupplierId!.isEmpty) {
        validationErrors.add('Please select a Supplier before publishing.');
      }
      if (retailPrice != null && retailPrice <= 0) {
        validationErrors.add('A published product must have a positive Retail Selling Price.');
      }
    }

    if (validationErrors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF222428),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
              SizedBox(width: 8),
              Text('Validation Warnings', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: validationErrors
                .map((err) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.orangeAccent)),
                          Expanded(
                              child: Text(err,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12))),
                        ],
                      ),
                    ))
                .toList(),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(b2bTradingRepositoryProvider);
      final payload = {
        'primaryCategory': _primaryCategory,
        'subCategory': _subCategory.isEmpty ? null : _subCategory,
        'internalTag': _internalTagsCtrl.text.trim(),
        'originalName': origName,
        'originalModel': origModel,
        'rebrandedName': rebrName,
        'rebrandedModel': rebrModel,
        'collection': _collectionCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'supplierId': _selectedSupplierId,
        'moq': moq ?? 1,
        'sampleCost': double.tryParse(_sampleCostCtrl.text.trim()) ?? 0,
        'leadTime': int.tryParse(_leadTimeCtrl.text.trim()) ?? 0,
        'rating': rating ?? 5.0,
        'material': _materialCtrl.text.trim(),
        'dimensions': _dimensionsCtrl.text.trim(),
        'weight': double.tryParse(_weightCtrl.text.trim()),
        'hsCode': _hsCodeCtrl.text.trim(),
        'logoPath': _logoPathCtrl.text.trim(),
        'insertCardPath': _insertCardCtrl.text.trim(),
        'pkgDims': _pkgDimsCtrl.text.trim(),
        'printingSpecs': _printingSpecsCtrl.text.trim(),
        'barcodePlacement': _barcodePlacementCtrl.text.trim(),
        'brandCopy': _brandCopyCtrl.text.trim(),
        'seoMeta': _seoMetaCtrl.text.trim(),
        'baseCost': baseCost ?? 0,
        'brandingFee': double.tryParse(_brandingFeeCtrl.text.trim()) ?? 0,
        'sampleShipping': double.tryParse(_sampleShippingCtrl.text.trim()) ?? 0,
        'freightPerUnit': double.tryParse(_freightPerUnitCtrl.text.trim()) ?? 0,
        'retailPrice': retailPrice ?? 0,
        'status': targetStatus,
        'variants': _variants,
        'documents': _documents,
      };

      if (widget.productToEdit != null) {
        await repo.updateProduct(widget.productToEdit!.id, payload);
      } else {
        await repo.createProduct(payload);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
        widget.onProductSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Product successfully saved as ${targetStatus.toUpperCase()}!'),
            backgroundColor: const Color(0xFFF15A24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save product: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─── Modal Shell & Header ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Dialog(
      backgroundColor: const Color(0xFF191A1E),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 8 : 20,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: isMobile ? size.width * 0.98 : 1060,
        height: isMobile ? size.height * 0.96 : 720,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Action Header
            if (isMobile) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'PIM Sourcing & White-Label Workflow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildHeaderButton(
                    label: 'Edit Draft',
                    icon: Icons.edit_note,
                    onTap: _isSaving ? null : () => _saveProduct('Draft'),
                  ),
                  _buildHeaderButton(
                    label: 'Save Draft',
                    icon: Icons.save_outlined,
                    onTap: _isSaving ? null : () => _saveProduct('Draft'),
                  ),
                  _buildHeaderButton(
                    label: 'Publish Product',
                    icon: Icons.publish_rounded,
                    onTap: _isSaving ? null : () => _saveProduct('published'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Product Sourcing & White-Labeling Workflow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  _buildHeaderButton(
                    label: 'Edit Draft',
                    icon: Icons.edit_note,
                    onTap: _isSaving ? null : () => _saveProduct('Draft'),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderButton(
                    label: 'Save Draft',
                    icon: Icons.save_outlined,
                    onTap: _isSaving ? null : () => _saveProduct('Draft'),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderButton(
                    label: 'Publish Product',
                    icon: Icons.publish_rounded,
                    onTap: _isSaving ? null : () => _saveProduct('published'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Tab Bar Strip
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF141518),
                border: Border.all(color: const Color(0xFF2E3138)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFFF15A24),
                indicatorWeight: 2.5,
                labelColor: const Color(0xFFF15A24),
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: '1. Taxonomy & Mapping'),
                  Tab(text: '2. Supplier'),
                  Tab(text: '3. Specifications'),
                  Tab(text: '4. Branding'),
                  Tab(text: '5. Financials'),
                  Tab(text: '6. Media & Docs'),
                  Tab(text: '7. Review'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab Views Container
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTab1Taxonomy(isMobile),
                  _buildTab2Supplier(isMobile),
                  _buildTab3Specs(isMobile),
                  _buildTab4Branding(isMobile),
                  _buildTab5Financials(isMobile),
                  _buildTab6MediaDocs(isMobile),
                  _buildTab7Review(isMobile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF15A24),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── TAB 1: TAXONOMY & IDENTIFICATION MAPPING ──────────────
  Widget _buildTab1Taxonomy(bool isMobile) {
    final leftCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181A1F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2E3138)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supplier / Original Details',
            style: TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildFieldWithLabel('Original Product Name:*', _originalNameCtrl),
          const SizedBox(height: 8),
          _buildFieldWithLabel('Original Model Number:*', _originalModelCtrl),
        ],
      ),
    );

    final rightCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181A1F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2E3138)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Brand / Rebranded Details',
            style: TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildFieldWithLabel('Rebranded Product Name:*', _rebrandedNameCtrl),
          const SizedBox(height: 8),
          _buildFieldWithLabel('Rebranded Model Number:*', _rebrandedModelCtrl),
        ],
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product Classification', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Primary Category
          Row(
            children: [
              const SizedBox(
                width: 130,
                child: Text('Primary Category:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              ),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: DropdownButtonFormField<String>(
                    initialValue: _primaryCategories.contains(_primaryCategory) ? _primaryCategory : _primaryCategories.first,
                    dropdownColor: const Color(0xFF222428),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _primaryCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _primaryCategory = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildAddButton(() => _showAddCategoryDialog()),
            ],
          ),
          const SizedBox(height: 8),

          // Sub-Category
          Row(
            children: [
              const SizedBox(
                width: 130,
                child: Text('Sub-Category:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              ),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: TextEditingController(text: _subCategory),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hint: 'e.g. dom1, Residential, Factory'),
                    onChanged: (v) => _subCategory = v,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildAddButton(() => _showAddCategoryDialog()),
            ],
          ),
          const SizedBox(height: 8),

          // Internal Tags
          Row(
            children: [
              const SizedBox(
                width: 130,
                child: Text('Internal Tags:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              ),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _internalTagsCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hint: 'e.g. Sourcing, High Margin, Tier 1'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2E3138)),
          const SizedBox(height: 8),

          // Section 2: Product Identification Mapping
          const Text(
            'Product Identification Mapping',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Responsive Mapping Cards
          if (isMobile) ...[
            leftCard,
            const SizedBox(height: 10),
            rightCard,
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftCard),
                const SizedBox(width: 14),
                Expanded(child: rightCard),
              ],
            ),
          ],

          const SizedBox(height: 12),
          _buildSimpleField('Collection / Brand Assignment:', _collectionCtrl),
          const SizedBox(height: 12),
          const Text('Detailed Product Description:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
          const SizedBox(height: 4),
          TextField(
            controller: _descriptionCtrl,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF141518),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: Color(0xFF2E3138))),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: SUPPLIERS & SOURCING LOGISTICS ──────────────────
  Widget _buildTab2Supplier(bool isMobile) {
    final selectedSup = _suppliers.where((s) => s['id']?.toString() == _selectedSupplierId).firstOrNull;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Supplier & Logistics Parameters', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 120, child: Text('Supplier Selection:*', style: TextStyle(color: Colors.white70, fontSize: 11.5))),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSupplierId,
                    dropdownColor: const Color(0xFF222428),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _suppliers.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text(s['name'] ?? ''))).toList(),
                    onChanged: (val) {
                      setState(() => _selectedSupplierId = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildAddButton(() => _showAddSupplierDialog()),
            ],
          ),
          const SizedBox(height: 12),

          // Supplier Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF181A1F),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2E3138)),
            ),
            child: selectedSup == null
                ? const Text('No supplier selected. Click "+" to onboard a supplier.', style: TextStyle(color: Colors.white54, fontSize: 11.5))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Supplier: ${selectedSup['name']}', style: const TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Contact: ${selectedSup['contactPerson'] ?? '-'} | Country: ${selectedSup['country'] ?? '-'}', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                      const SizedBox(height: 2),
                      Text('Rating: ${selectedSup['rating'] ?? 5} / 5.0 ★ | Standard MOQ: ${selectedSup['moq'] ?? 100}', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // Sourcing Parameters
          if (isMobile) ...[
            _buildSimpleField('MOQ (Minimum Order Quantity):*', _moqCtrl),
            const SizedBox(height: 8),
            _buildSimpleField('Sample Cost (Rs.):', _sampleCostCtrl),
            const SizedBox(height: 8),
            _buildSimpleField('Lead Time (Days):', _leadTimeCtrl),
            const SizedBox(height: 8),
            _buildSimpleField('Factory Rating (1.0 to 5.0):', _ratingCtrl),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildSimpleField('MOQ (Minimum Order Quantity):*', _moqCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildSimpleField('Sample Cost (Rs.):', _sampleCostCtrl)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildSimpleField('Lead Time (Days):', _leadTimeCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildSimpleField('Factory Rating (1.0 to 5.0):', _ratingCtrl)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── TAB 3: TECHNICAL SPECIFICATIONS & VARIANTS ─────────────
  Widget _buildTab3Specs(bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Physical & Technical Specifications', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (isMobile) ...[
            _buildSimpleField('Material:', _materialCtrl),
            const SizedBox(height: 8),
            _buildSimpleField('Dimensions (L x W x H):', _dimensionsCtrl),
            const SizedBox(height: 8),
            _buildSimpleField('Weight (kg):', _weightCtrl),
            const SizedBox(height: 8),
            _buildSimpleField('HS Code (Customs):', _hsCodeCtrl),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildSimpleField('Material:', _materialCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildSimpleField('Dimensions (L x W x H):', _dimensionsCtrl)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildSimpleField('Weight (kg):', _weightCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildSimpleField('HS Code (Customs):', _hsCodeCtrl)),
              ],
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2E3138)),
          const SizedBox(height: 8),

          // Variants Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SKU & Product Variants', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF15A24), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Variant', style: TextStyle(fontSize: 11, color: Colors.white)),
                onPressed: () {
                  setState(() {
                    _variants.add({
                      'sku': 'SKU-${_variants.length + 1}',
                      'color': 'Black',
                      'size': 'Standard',
                      'packageType': 'Carton',
                      'baseCost': double.tryParse(_baseCostCtrl.text) ?? 10.0,
                      'retailPrice': double.tryParse(_retailPriceCtrl.text) ?? 87600.0,
                    });
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181A1F),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2E3138)),
            ),
            child: _variants.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No custom variants added yet. Base product model will be used.',
                        style: TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ),
                  )
                : Column(
                    children: _variants.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final v = entry.value;
                      return ListTile(
                        dense: true,
                        title: Text('${v['sku']} • ${v['color']} • ${v['size']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        subtitle: Text('Pkg: ${v['packageType']} | Cost: ₹${v['baseCost']} | Retail: ₹${v['retailPrice']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                          onPressed: () => setState(() => _variants.removeAt(idx)),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 4: BRANDING & WHITE-LABELING ───────────────────────
  Widget _buildTab4Branding(bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('White-Labeling & Branding Assets', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Brand Logo Upload
          Row(
            children: [
              Expanded(child: _buildSimpleField('Brand Logo File Path / URL:', _logoPathCtrl)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF282A30),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.upload_file, size: 14, color: Color(0xFFF15A24)),
                  label: const Text('Upload Logo', style: TextStyle(fontSize: 11)),
                  onPressed: () => _pickAndUploadAsset('LOGO', _logoPathCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Insert Card Upload
          Row(
            children: [
              Expanded(child: _buildSimpleField('Insert Card / Warranty Card Path / URL:', _insertCardCtrl)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF282A30),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.upload_file, size: 14, color: Color(0xFFF15A24)),
                  label: const Text('Upload Card', style: TextStyle(fontSize: 11)),
                  onPressed: () => _pickAndUploadAsset('PDF', _insertCardCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _buildSimpleField('Packaging Specifications / Carton Grade:', _pkgDimsCtrl),
          const SizedBox(height: 10),

          if (isMobile) ...[
            _buildSimpleField('Printing Specifications:', _printingSpecsCtrl),
            const SizedBox(height: 8),
            _buildSimpleField('Barcode Placement:', _barcodePlacementCtrl),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildSimpleField('Printing Specifications:', _printingSpecsCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildSimpleField('Barcode Placement:', _barcodePlacementCtrl)),
              ],
            ),
          ],

          const SizedBox(height: 10),
          _buildSimpleField('Rewritten Sales Title / Commercial Brand Copy:', _brandCopyCtrl),
          const SizedBox(height: 10),
          _buildSimpleField('SEO Metadata / Keywords for Marketplace Search:', _seoMetaCtrl),
        ],
      ),
    );
  }

  // ─── TAB 5: FINANCIALS, LANDED COST & MARGIN CALCULATOR ─────
  Widget _buildTab5Financials(bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Costing, Financials & Margin Formulation', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Text('Import Customs: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Switch(
                    value: _isImportCustoms,
                    activeThumbColor: const Color(0xFFF15A24),
                    onChanged: (val) {
                      setState(() => _isImportCustoms = val);
                      _recalculateFinancials();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Direct Cost Inputs
          if (isMobile) ...[
            Row(
              children: [
                Expanded(child: _buildCalcInput('Unit Purchase Cost (Rs.):*', _baseCostCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _buildCalcInput('Branding Fee per Unit:', _brandingFeeCtrl)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildCalcInput('Packaging Cost per Unit:', _sampleShippingCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _buildCalcInput('Freight per Unit:', _freightPerUnitCtrl)),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildCalcInput('Unit Purchase Cost (Rs.):*', _baseCostCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _buildCalcInput('Branding Fee per Unit (Rs.):', _brandingFeeCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _buildCalcInput('Packaging Cost per Unit (Rs.):', _sampleShippingCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _buildCalcInput('Freight per Unit (Rs.):', _freightPerUnitCtrl)),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Target Selling Price and Desired Margin
          Row(
            children: [
              Expanded(child: _buildCalcInput('Target Retail Selling Price (Rs.):*', _retailPriceCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildCalcInput('Target Gross Margin % (Optional auto-calc):', _targetMarginCtrl)),
            ],
          ),

          // Warning for Negative Margin
          if (_calculatedMarginPct < 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF381B1B),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.redAccent, width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: Retail price is below landed cost! Operating at a loss of ${_currencyFormat.format(_calculatedGrossProfit.abs())} per unit (${_calculatedMarginPct.toStringAsFixed(2)}% margin).',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Results KPI Display Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF181A1F),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2E3138)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Margin & Landed Formulation Output', style: TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _buildKpiCard('ESTIMATED LANDED COST', _currencyFormat.format(_calculatedLandedCost), Colors.white),
                    _buildKpiCard('ESTIMATED GROSS MARGIN', '${_calculatedMarginPct.toStringAsFixed(2)}%', _calculatedMarginPct >= 20 ? const Color(0xFF2ECC71) : (_calculatedMarginPct > 0 ? Colors.orangeAccent : Colors.redAccent)),
                    _buildKpiCard('GROSS PROFIT PER UNIT', _currencyFormat.format(_calculatedGrossProfit), _calculatedGrossProfit >= 0 ? Colors.white : Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFF2E3138)),
                const SizedBox(height: 6),
                Text(
                  'Formula: Landed Cost = Base (${_baseCostCtrl.text}) + Branding (${_brandingFeeCtrl.text}) + Packaging (${_sampleShippingCtrl.text}) + Freight (${_freightPerUnitCtrl.text}) = ${_currencyFormat.format(_calculatedLandedCost)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
                ),
                Text(
                  'Margin % = ((${_retailPriceCtrl.text} - $_calculatedLandedCost) / ${_retailPriceCtrl.text}) × 100 = ${_calculatedMarginPct.toStringAsFixed(2)}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 6: MEDIA & DOCUMENT VAULT ──────────────────────────
  Widget _buildTab6MediaDocs(bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Media & Document Vault', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              if (_isUploadingDoc)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF15A24)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDocCategoryRow('Spec Sheets & Datasheets (PDF)', 'SPEC_SHEET', Icons.description_outlined),
          const SizedBox(height: 8),
          _buildDocCategoryRow('User & Operation Manuals (PDF)', 'USER_MANUAL', Icons.menu_book_rounded),
          const SizedBox(height: 8),
          _buildDocCategoryRow('Quality & Safety Certifications (PDF)', 'CERTIFICATE', Icons.verified_outlined),
          const SizedBox(height: 8),
          _buildDocCategoryRow('Packaging / Printing Artworks (PDF/AI)', 'ARTWORK', Icons.draw_outlined),
          const SizedBox(height: 8),
          _buildDocCategoryRow('High-Resolution Photo Gallery (JPG/PNG)', 'IMAGE', Icons.photo_library_outlined),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2E3138)),
          const SizedBox(height: 8),

          // Uploaded Documents List
          Text('Attached Documents (${_documents.length})', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181A1F),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2E3138)),
            ),
            child: _documents.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No documents attached yet. Click "Attach / Upload" above to upload spec sheets, manuals, or images.',
                        style: TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ),
                  )
                : Column(
                    children: _documents.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final d = entry.value;
                      final fileName = d['fileName'] ?? 'Document';
                      final type = d['assetType'] ?? 'FILE';
                      final filePath = d['filePath'] ?? d['fileUrl'] ?? '';

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          type == 'IMAGE' ? Icons.image : Icons.picture_as_pdf,
                          color: type == 'IMAGE' ? const Color(0xFF2ECC71) : Colors.redAccent,
                          size: 18,
                        ),
                        title: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        subtitle: Text('$type • $filePath', style: const TextStyle(color: Colors.white54, fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (filePath.toString().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.open_in_new, color: Color(0xFFF15A24), size: 16),
                                tooltip: 'View / Download Document',
                                onPressed: () => openWebUrl(filePath.toString()),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                              tooltip: 'Delete Document',
                              onPressed: () async {
                                if (d['id'] != null && !d['id'].toString().startsWith('doc_')) {
                                  try {
                                    await ref.read(b2bTradingRepositoryProvider).deleteMediaFile(d['id']);
                                  } catch (_) {}
                                }
                                setState(() => _documents.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCategoryRow(String title, String key, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181A1F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2E3138)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF15A24), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11.5))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF222428),
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
            onPressed: () => _pickAndUploadMedia(key, title),
            child: const Text('Attach / Upload', style: TextStyle(fontSize: 10.5)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 7: REVIEW & PUBLISH ────────────────────────────────
  Widget _buildTab7Review(bool isMobile) {
    final hasTaxonomy = _rebrandedNameCtrl.text.trim().isNotEmpty && _originalNameCtrl.text.trim().isNotEmpty;
    final hasSupplier = _selectedSupplierId != null;
    final hasSpecs = _materialCtrl.text.trim().isNotEmpty;
    final hasBranding = _brandCopyCtrl.text.trim().isNotEmpty;
    final hasFinancials = _calculatedLandedCost > 0 && double.tryParse(_retailPriceCtrl.text.trim()) != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pre-Publish Verification & Summary', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Completeness Checklist
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF181A1F),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2E3138)),
            ),
            child: Column(
              children: [
                _buildCheckItem('Taxonomy & Identification Mapping', hasTaxonomy),
                _buildCheckItem('Supplier & Sourcing Logistics Linked', hasSupplier),
                _buildCheckItem('Technical Specifications & Material', hasSpecs),
                _buildCheckItem('Branding & White-Label Assets', hasBranding),
                _buildCheckItem('Costing, Landed Cost & Margins Formulated', hasFinancials),
                _buildCheckItem('Media & Vault Attachments', _documents.isNotEmpty),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Product Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1D22),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2A2C32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Commercial Listing Preview', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Title: ${_rebrandedNameCtrl.text.isNotEmpty ? _rebrandedNameCtrl.text : "Untitled"}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('Model Code: ${_rebrandedModelCtrl.text}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Category: $_primaryCategory ${_subCategory.isNotEmpty ? "• $_subCategory" : ""}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Landed Cost: ${_currencyFormat.format(_calculatedLandedCost)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Retail Price: ${_currencyFormat.format(double.tryParse(_retailPriceCtrl.text) ?? 0)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                Text('Gross Margin: ${_calculatedMarginPct.toStringAsFixed(2)}%', style: TextStyle(color: _calculatedMarginPct >= 20 ? const Color(0xFF2ECC71) : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: isOk ? const Color(0xFF2ECC71) : Colors.white30,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isOk ? Colors.white : Colors.white54,
                fontSize: 11.5,
                fontWeight: isOk ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Input Helper Builders ─────────────────────────────────────────────────
  Widget _buildFieldWithLabel(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcInput(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            decoration: _inputDecoration(),
            onChanged: (_) => _recalculateFinancials(),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAddButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(color: const Color(0xFFF15A24), borderRadius: BorderRadius.circular(3)),
        child: const Icon(Icons.add, color: Colors.white, size: 16),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
      filled: true,
      fillColor: const Color(0xFF141518),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: Color(0xFF2E3138))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: Color(0xFF2E3138))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: Color(0xFFF15A24))),
    );
  }

  // ─── Add Category & Add Supplier Quick Modals ──────────────────────────────
  void _showAddCategoryDialog() {
    final catCtrl = TextEditingController();
    final subCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222428),
        title: const Text('Add B2B Category', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField('Primary Category', catCtrl),
            const SizedBox(height: 8),
            _buildDialogField('Sub-Category', subCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF15A24)),
            onPressed: () async {
              if (catCtrl.text.trim().isEmpty) return;
              final repo = ref.read(b2bTradingRepositoryProvider);
              await repo.createCategory({
                'primaryCategory': catCtrl.text.trim(),
                'subCategory': subCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() {
                  if (!_primaryCategories.contains(catCtrl.text.trim())) {
                    _primaryCategories.add(catCtrl.text.trim());
                  }
                  _primaryCategory = catCtrl.text.trim();
                  _subCategory = subCtrl.text.trim();
                });
              }
            },
            child: const Text('Save Category', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final countryCtrl = TextEditingController();
    final moqCtrl = TextEditingController(text: '100');
    final leadCtrl = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222428),
        title: const Text('Add B2B Supplier', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField('Supplier Company Name', nameCtrl),
            const SizedBox(height: 8),
            _buildDialogField('Contact Person', contactCtrl),
            const SizedBox(height: 8),
            _buildDialogField('Country', countryCtrl),
            const SizedBox(height: 8),
            _buildDialogField('Default MOQ', moqCtrl),
            const SizedBox(height: 8),
            _buildDialogField('Lead Time (Days)', leadCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF15A24)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final repo = ref.read(b2bTradingRepositoryProvider);
              final newSup = await repo.createSupplier({
                'name': nameCtrl.text.trim(),
                'contactPerson': contactCtrl.text.trim(),
                'country': countryCtrl.text.trim(),
                'moq': int.tryParse(moqCtrl.text.trim()) ?? 1,
                'leadTime': int.tryParse(leadCtrl.text.trim()) ?? 0,
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              await _loadSuppliers();
              setState(() => _selectedSupplierId = newSup['id']);
            },
            child: const Text('Save Supplier', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: _inputDecoration(),
          ),
        ),
      ],
    );
  }
}
