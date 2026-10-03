import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/constants/app_constants.dart';
import 'package:saark_erp_mobile/features/products/data/products_repository.dart';

class ProductsListPage extends ConsumerStatefulWidget {
  const ProductsListPage({super.key});

  @override
  ConsumerState<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends ConsumerState<ProductsListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  final _typeFilters = ['ALL', 'FINISHED_PRODUCT', 'RAW_MATERIAL', 'SERVICE', 'COMPONENT'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _typeFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final type = _typeFilters[_tabController.index];
        ref.read(productListProvider.notifier).loadProducts(
              type: type == 'ALL' ? null : type,
              search: _searchController.text,
            );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productListProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildTypeTabs(),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _buildError(state.error!)
                    : state.products.isEmpty
                        ? _buildEmpty()
                        : isWide
                            ? _buildTable(state.products)
                            : _buildCards(state.products),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
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
        onChanged: (v) {
          final type = _typeFilters[_tabController.index];
          ref.read(productListProvider.notifier).loadProducts(search: v, type: type == 'ALL' ? null : type);
        },
        decoration: InputDecoration(
          hintText: 'Search by name, SKU, HSN…',
          prefixIcon: const Icon(Icons.search, size: 18),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.darkBorder)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildTypeTabs() {
    return Container(
      color: AppTheme.darkSurface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppTheme.primary,
        labelColor: AppTheme.primary,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: _typeFilters.map((t) => Tab(text: t.replaceAll('_', ' '))).toList(),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> products) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
          columns: const [
            DataColumn(label: Text('SKU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Product Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Sale Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ],
          rows: products.map((p) {
            final stock = p['currentStock'] as num? ?? 0;
            final reorder = p['reorderLevel'] as num? ?? 0;
            final isLowStock = stock <= reorder;

            return DataRow(cells: [
              DataCell(Text(p['sku'] as String? ?? '', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.primary))),
              DataCell(Text(p['name'] as String? ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              DataCell(Text((p['category'] as Map?)?['name'] as String? ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text((p['productType'] as String? ?? '').replaceAll('_', ' '), style: const TextStyle(fontSize: 11))),
              DataCell(Text((p['unit'] as Map?)?['code'] as String? ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text('₹${p['sellingPrice'] ?? 0}', style: const TextStyle(fontSize: 12))),
              DataCell(Row(children: [
                Text('$stock', style: TextStyle(fontSize: 12, color: isLowStock ? AppTheme.error : Colors.white)),
                if (isLowStock) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.warning_amber, size: 12, color: AppTheme.warning),
                ],
              ])),
              DataCell(_StatusBadge(status: p['status'] as String? ?? 'ACTIVE')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCards(List<Map<String, dynamic>> products) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = products[i];
        final stock = p['currentStock'] as num? ?? 0;
        final reorder = p['reorderLevel'] as num? ?? 0;
        final isLow = stock <= reorder;

        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.category, color: AppTheme.primary, size: 20),
            ),
            title: Text(p['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('SKU: ${p['sku'] ?? '—'} · ₹${p['sellingPrice'] ?? 0}', style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Stock: $stock', style: TextStyle(fontSize: 11, color: isLow ? AppTheme.error : Colors.grey)),
                if (isLow) const Text('LOW STOCK', style: TextStyle(fontSize: 9, color: AppTheme.error, fontWeight: FontWeight.bold)),
              ],
            ),
            onTap: () => _showProductForm(context, product: p),
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
          Icon(Icons.category_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text('No products found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showProductForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: Colors.grey)),
      ElevatedButton(onPressed: () => ref.read(productListProvider.notifier).loadProducts(), child: const Text('Retry')),
    ]));
  }

  void _showProductForm(BuildContext context, {Map<String, dynamic>? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductFormSheet(product: product, onSuccess: () {
        ref.read(productListProvider.notifier).loadProducts();
      }),
    );
  }
}

class _ProductFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? product;
  final VoidCallback onSuccess;

  const _ProductFormSheet({this.product, required this.onSuccess});

  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _skuCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _hsnCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  String _productType = 'FINISHED_PRODUCT';
  String? _categoryId;
  bool _isLoading = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final p = widget.product!;
      _skuCtrl.text = p['sku'] as String? ?? '';
      _nameCtrl.text = p['name'] as String? ?? '';
      _hsnCtrl.text = p['hsnSac'] as String? ?? '';
      _purchasePriceCtrl.text = p['purchasePrice']?.toString() ?? '';
      _sellingPriceCtrl.text = p['sellingPrice']?.toString() ?? '';
      _reorderCtrl.text = p['reorderLevel']?.toString() ?? '';
      _stockCtrl.text = p['currentStock']?.toString() ?? '';
      _productType = p['productType'] as String? ?? 'FINISHED_PRODUCT';
      _categoryId = (p['category'] as Map?)?['id'] as String?;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(productCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.92,
        initialChildSize: 0.8,
        builder: (_, ctrl) => Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: ctrl,
              children: [
                Text(isEdit ? 'Edit Product' : 'New Product', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _field(_skuCtrl, 'SKU *', required: true),
                _field(_nameCtrl, 'Product Name *', required: true),
                DropdownButtonFormField<String>(
                  initialValue: _productType,
                  decoration: const InputDecoration(labelText: 'Product Type'),
                  items: AppConstants.productTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) => setState(() => _productType = v!),
                ),
                const SizedBox(height: 12),
                categoriesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (cats) => DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...cats.map((c) {
                        final cat = c as Map<String, dynamic>;
                        return DropdownMenuItem(value: cat['id'] as String, child: Text(cat['name'] as String? ?? ''));
                      }),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(height: 12),
                _field(_hsnCtrl, 'HSN / SAC Code'),
                Row(children: [
                  Expanded(child: _field(_purchasePriceCtrl, 'Purchase Price', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_sellingPriceCtrl, 'Selling Price', keyboardType: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(child: _field(_reorderCtrl, 'Reorder Level', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_stockCtrl, 'Opening Stock', keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text(isEdit ? 'Update Product' : 'Create Product'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'sku': _skuCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'productType': _productType,
      'categoryId': _categoryId,
      'hsnSac': _hsnCtrl.text.trim().isEmpty ? null : _hsnCtrl.text.trim(),
      'purchasePrice': double.tryParse(_purchasePriceCtrl.text) ?? 0,
      'sellingPrice': double.tryParse(_sellingPriceCtrl.text) ?? 0,
      'reorderLevel': int.tryParse(_reorderCtrl.text) ?? 10,
      'openingStock': int.tryParse(_stockCtrl.text) ?? 0,
    };

    try {
      final repo = ref.read(productsRepositoryProvider);
      if (isEdit) {
        await repo.updateProduct(widget.product!['id'] as String, data);
      } else {
        await repo.createProduct(data);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Product updated' : 'Product created'), backgroundColor: AppTheme.success),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
