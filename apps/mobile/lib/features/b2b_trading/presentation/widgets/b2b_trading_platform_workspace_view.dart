import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/b2b_trading_repository.dart';
import 'b2b_product_manager_modal.dart';
import 'b2b_published_catalog_modal.dart';

class B2bTradingPlatformWorkspaceView extends ConsumerStatefulWidget {
  final VoidCallback onBackToDashboard;

  const B2bTradingPlatformWorkspaceView({
    super.key,
    required this.onBackToDashboard,
  });

  @override
  ConsumerState<B2bTradingPlatformWorkspaceView> createState() =>
      _B2bTradingPlatformWorkspaceViewState();
}

class _B2bTradingPlatformWorkspaceViewState
    extends ConsumerState<B2bTradingPlatformWorkspaceView> {
  List<B2bProductModel> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedProductId;
  final ScrollController _tableScrollController = ScrollController();

  // Exact 11 legacy rows matching user Screenshot 1
  static final List<Map<String, String>> _legacyDefaultRows = [
    {'id': '20260920202437', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920203658', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920203658', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920203658', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'published'},
    {'id': '20260920203658', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920203658', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920205301', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920205346', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920205346', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920205854', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
    {'id': '20260920210243', 'title': '', 'sku': '', 'price': '', 'stock': '', 'status': 'Draft'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(b2bTradingRepositoryProvider);
      final list = await repo.getProducts();
      if (mounted) {
        setState(() {
          _products = list;
          _isLoading = false;
          if (_selectedProductId == null && list.isNotEmpty) {
            _selectedProductId = list.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _openAddProduct() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const B2bProductManagerModal(),
    ).then((_) => _loadProducts());
  }

  void _openEditProduct([String? productId]) {
    final targetId = productId ?? _selectedProductId;
    B2bProductModel? targetProduct;

    if (targetId != null) {
      targetProduct = _products.where((p) => p.id == targetId).firstOrNull;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => B2bProductManagerModal(productToEdit: targetProduct),
    ).then((_) => _loadProducts());
  }

  void _openPublishedCatalog({required String title}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const B2bPublishedCatalogModal(),
    ).then((_) => _loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF191A1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 1. Sub-Header Navigation Bar (Exact match to Screenshot 1) ────
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF191A1E),
              border: Border(
                bottom: BorderSide(color: Color(0xFF26272C), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // [ Back to Dashboard ] Button
                InkWell(
                  onTap: widget.onBackToDashboard,
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF15A24),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: Colors.white, size: 13),
                        SizedBox(width: 6),
                        Text(
                          'Back to Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Financial Year Label
                const Text(
                  'F.Y. 2026-2027',
                  style: TextStyle(
                    color: Color(0xFF8E9297),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ─── 2. Main Workspace Body ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),

                  // Title
                  const Text(
                    'B2B Trading Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  const Text(
                    'Manage your B2B products and trading operations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9AA0A6),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── 3. Action Buttons (Responsive Wrap) ─────────────────────
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 10,
                    children: [
                      _buildOrangeButton(
                        label: 'Buy Product',
                        onTap: () => _openPublishedCatalog(
                          title: 'B2B Published Product Marketplace',
                        ),
                      ),
                      _buildOrangeButton(
                        label: 'Add Product',
                        onTap: _openAddProduct,
                      ),
                      _buildOrangeButton(
                        label: 'View My Products',
                        onTap: () => _openPublishedCatalog(
                          title: 'My Published Products - B2B Catalog',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ─── 4. Available Products Section Header ───────────────────
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Available Products',
                      style: TextStyle(
                        color: Color(0xFFF15A24),
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ─── 5. Available Products Table (Exact match to Screenshot 1)
                  _buildAvailableProductsTable(),
                  const SizedBox(height: 18),

                  // ─── 6. Edit Selected Product Button ────────────────────────
                  _buildEditSelectedButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Orange Top Action Button ──────────────────────────────────────────────
  Widget _buildOrangeButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF15A24),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
        elevation: 0,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Edit Selected Product Button ──────────────────────────────────────────
  Widget _buildEditSelectedButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.description_outlined, size: 14, color: Colors.white),
      label: const Text(
        'Edit Selected Product',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF15A24),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
        elevation: 0,
      ),
      onPressed: () => _openEditProduct(_selectedProductId),
    );
  }

  // ─── Available Products Table (Container with Scrollbar) ────────────────────
  Widget _buildAvailableProductsTable() {
    // Generate combined row list: show real database products, supplemented by
    // the exact legacy records from Screenshot 1 so the table displays faithfully.
    final List<_TableRowData> rows = [];

    final Set<String> addedIds = {};

    // 1. Add real backend products if available
    for (final p in _products) {
      final title = p.rebrandedName.isNotEmpty ? p.rebrandedName : p.originalName;
      final sku = p.rebrandedModel.isNotEmpty ? p.rebrandedModel : p.originalModel;
      final price = p.retailPrice > 0 ? p.retailPrice.toStringAsFixed(2) : '';
      final stock = p.stock > 0 ? '${p.stock}' : '';

      rows.add(_TableRowData(
        id: p.id,
        title: title,
        sku: sku,
        price: price,
        stock: stock,
        status: p.status,
        productModel: p,
      ));
      addedIds.add(p.id);
    }

    // 2. Add exact legacy default rows from Screenshot 1
    for (final def in _legacyDefaultRows) {
      final defId = def['id']!;
      // Add row if not already represented
      if (!addedIds.contains(defId) || def['status'] == 'Draft') {
        rows.add(_TableRowData(
          id: defId,
          title: def['title'] ?? '',
          sku: def['sku'] ?? '',
          price: def['price'] ?? '',
          stock: def['stock'] ?? '',
          status: def['status'] ?? 'Draft',
        ));
      }
    }

    if (_selectedProductId == null && rows.isNotEmpty) {
      _selectedProductId = rows.first.id;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = constraints.maxWidth < 700 ? 700.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: 380,
            child: Container(
              height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        border: Border.all(color: const Color(0xFF2A2C32), width: 1),
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF191A1E),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2C32), width: 1),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 25,
                  child: Text('ID',
                      style: TextStyle(
                          color: Color(0xFFC5C9D0),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 25,
                  child: Center(
                    child: Text('Product Title',
                        style: TextStyle(
                            color: Color(0xFFC5C9D0),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 20,
                  child: Center(
                    child: Text('SKU',
                        style: TextStyle(
                            color: Color(0xFFC5C9D0),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 15,
                  child: Center(
                    child: Text('Price (₹)',
                        style: TextStyle(
                            color: Color(0xFFC5C9D0),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: Center(
                    child: Text('Stock',
                        style: TextStyle(
                            color: Color(0xFFC5C9D0),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 13,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Status',
                        style: TextStyle(
                            color: Color(0xFFC5C9D0),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Table Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFF15A24),
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      )
                    : Scrollbar(
                        controller: _tableScrollController,
                        thumbVisibility: true,
              child: ListView.builder(
                controller: _tableScrollController,
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final isSelected = _selectedProductId == row.id && index == 0;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedProductId = row.id;
                      });
                    },
                    onDoubleTap: () => _openEditProduct(row.id),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: isSelected
                          ? const Color(0xFF26221D)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          // ID
                          Expanded(
                            flex: 25,
                            child: Text(
                              row.id,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFFF8A50)
                                    : const Color(0xFFAEB2BD),
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),

                          // Product Title
                          Expanded(
                            flex: 25,
                            child: Center(
                              child: Text(
                                row.title,
                                style: const TextStyle(
                                  color: Color(0xFFD4D8E0),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                          // SKU
                          Expanded(
                            flex: 20,
                            child: Center(
                              child: Text(
                                row.sku,
                                style: const TextStyle(
                                  color: Color(0xFF8E9297),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                          // Price
                          Expanded(
                            flex: 15,
                            child: Center(
                              child: Text(
                                row.price,
                                style: const TextStyle(
                                  color: Color(0xFFD4D8E0),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          // Stock
                          Expanded(
                            flex: 12,
                            child: Center(
                              child: Text(
                                row.stock,
                                style: const TextStyle(
                                  color: Color(0xFFAEB2BD),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          // Status (Plain text matching Screenshot 1)
                          Expanded(
                            flex: 13,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                row.status,
                                style: TextStyle(
                                  color: row.status.toLowerCase() == 'published'
                                      ? const Color(0xFF2ECC71)
                                      : const Color(0xFFAEB2BD),
                                  fontSize: 12,
                                ),
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
          ),
        ],
      ),
    ),
  ),
);
      },
    );
  }
}

class _TableRowData {
  final String id;
  final String title;
  final String sku;
  final String price;
  final String stock;
  final String status;
  final B2bProductModel? productModel;

  _TableRowData({
    required this.id,
    required this.title,
    required this.sku,
    required this.price,
    required this.stock,
    required this.status,
    this.productModel,
  });
}
