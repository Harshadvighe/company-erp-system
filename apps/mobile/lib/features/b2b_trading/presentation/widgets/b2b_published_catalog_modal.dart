import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/b2b_trading_repository.dart';

class B2bPublishedCatalogModal extends ConsumerStatefulWidget {
  const B2bPublishedCatalogModal({super.key});

  @override
  ConsumerState<B2bPublishedCatalogModal> createState() => _B2bPublishedCatalogModalState();
}

class _B2bPublishedCatalogModalState extends ConsumerState<B2bPublishedCatalogModal> {
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.', decimalDigits: 2);
  final _searchCtrl = TextEditingController();

  List<B2bProductModel> _products = [];
  bool _isLoading = true;
  B2bProductModel? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _loadPublishedProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPublishedProducts() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(b2bTradingRepositoryProvider);
      final list = await repo.getPublishedProducts(_searchCtrl.text.trim());
      if (mounted) {
        setState(() {
          _products = list;
          _isLoading = false;
          if (_products.isNotEmpty && _selectedProduct == null) {
            _selectedProduct = _products.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showProductDetails(B2bProductModel prod) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_rounded, color: Color(0xFFF15A24)),
            const SizedBox(width: 8),
            Text(
              prod.rebrandedName.isNotEmpty ? prod.rebrandedName : prod.originalName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailSection('Product Identification', [
                  'Product ID: ${prod.id}',
                  'Rebranded Title: ${prod.rebrandedName}',
                  'Model Code: ${prod.rebrandedModel}',
                  'Original Factory Name: ${prod.originalName}',
                  'Original Model: ${prod.originalModel}',
                  'Category: ${prod.primaryCategory} ${prod.subCategory != null ? "• ${prod.subCategory}" : ""}',
                  'Collection: ${prod.collection ?? "Standard"}',
                  'Status: ${prod.status.toUpperCase()}',
                ]),
                const SizedBox(height: 10),
                _buildDetailSection('Technical Specifications', [
                  'Material: ${prod.material ?? "N/A"}',
                  'Dimensions: ${prod.dimensions ?? "N/A"}',
                  'Weight: ${prod.weight != null ? "${prod.weight} kg" : "N/A"}',
                  'HS Code (Customs): ${prod.hsCode ?? "N/A"}',
                ]),
                const SizedBox(height: 10),
                _buildDetailSection('Commercial Financials', [
                  'Target Retail Price: ${_currencyFormat.format(prod.retailPrice)}',
                  'Procurement Base Cost: ${_currencyFormat.format(prod.baseCost)}',
                  'Branding Fee: ${_currencyFormat.format(prod.brandingFee)}',
                  'Packaging Fee: ${_currencyFormat.format(prod.sampleShipping)}',
                  'Freight / Unit: ${_currencyFormat.format(prod.freightPerUnit)}',
                  'Landed Cost: ${_currencyFormat.format(prod.landedCost)}',
                  'Gross Margin: ${prod.marginPct.toStringAsFixed(2)}%',
                  'Available Stock: ${prod.stock} units',
                ]),
                if (prod.description != null && prod.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailSection('Description & Features', [
                    prod.description!,
                  ]),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF33363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFF15A24), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...lines.map((l) => Text('• $l', style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Dialog(
      backgroundColor: const Color(0xFF191A1E),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 40,
        vertical: isMobile ? 8 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: isMobile ? size.width * 0.98 : 1000,
        height: isMobile ? size.height * 0.96 : 620,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Icon + Published Product Catalog + Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Published Product Catalog',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF15A24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Search Products: [ Search Input Field ]
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'Search Products: ',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                SizedBox(
                  width: isMobile ? (size.width - 64).clamp(180.0, 260.0) : 240,
                  height: 32,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF141518),
                      hintText: 'Filter by title, model, category...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: Color(0xFF383A42)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: Color(0xFF383A42)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: Color(0xFFF15A24)),
                      ),
                    ),
                    onChanged: (_) => _loadPublishedProducts(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Products Grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double gridWidth = constraints.maxWidth < 650 ? 650.0 : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: gridWidth,
                      height: constraints.maxHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF15161A),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2E3138)),
                        ),
                        child: Column(
                          children: [
                            // Grid Header
                            Container(
                              height: 34,
                              color: const Color(0xFF222428),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: const Row(
                                children: [
                                  Expanded(flex: 3, child: Text('ID', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 4, child: Text('Rebranded Name', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('Model', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('Category', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('Retail Price', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),

                            // Grid Items
                            Expanded(
                              child: _isLoading
                                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF15A24)))
                                  : _products.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No published products found.',
                                            style: TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _products.length,
                                          itemBuilder: (ctx, index) {
                                            final p = _products[index];
                                            final isSelected = _selectedProduct?.id == p.id;
                                            return InkWell(
                                              onTap: () => setState(() => _selectedProduct = p),
                                              child: Container(
                                                height: 36,
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? const Color(0xFF282A32) : (index % 2 == 0 ? Colors.transparent : const Color(0xFF191A1E)),
                                                  border: isSelected ? const Border(left: BorderSide(color: Color(0xFFF15A24), width: 3)) : null,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(flex: 3, child: Text(p.id, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                                                    Expanded(flex: 4, child: Text(p.rebrandedName.isNotEmpty ? p.rebrandedName : p.originalName, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600))),
                                                    Expanded(flex: 3, child: Text(p.rebrandedModel.isNotEmpty ? p.rebrandedModel : p.originalModel, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                                                    Expanded(flex: 3, child: Text(p.primaryCategory, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                                                    Expanded(flex: 3, child: Text('₹ ${p.retailPrice > 0 ? _currencyFormat.format(p.retailPrice).replaceAll("Rs.", "").trim() : "-"}', style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11.5, fontWeight: FontWeight.bold))),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                                                          borderRadius: BorderRadius.circular(3),
                                                        ),
                                                        child: Text(
                                                          p.status,
                                                          style: const TextStyle(color: Color(0xFF81C784), fontSize: 10.5, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // Bottom Right Action: [ View Detailed Specifications ]
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                ),
                onPressed: _selectedProduct != null ? () => _showProductDetails(_selectedProduct!) : null,
                child: const Text(
                  'View Detailed Specifications',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
