import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

// ─── B2B Trading Models ──────────────────────────────────────────────────────

class B2bProductModel {
  final String id;
  final String primaryCategory;
  final String? subCategory;
  final String? internalTag;
  final String originalName;
  final String originalModel;
  final String rebrandedName;
  final String rebrandedModel;
  final String? collection;
  final String? description;

  final String? supplierId;
  final String? supplierName;
  final int moq;
  final double sampleCost;
  final int leadTime;
  final double rating;

  final String? material;
  final String? dimensions;
  final double? weight;
  final String? hsCode;

  final String? logoPath;
  final String? insertCardPath;
  final String? pkgDims;
  final String? printingSpecs;
  final String? barcodePlacement;
  final String? brandCopy;
  final String? seoTitle;
  final String? seoMeta;

  final double baseCost;
  final double brandingFee;
  final double sampleShipping;
  final double freightPerUnit;
  final double landedCost;
  final double retailPrice;
  final double marginPct;
  final int stock;
  final String status;
  final DateTime createdAt;
  final List<dynamic> variants;
  final List<dynamic> documents;

  const B2bProductModel({
    required this.id,
    required this.primaryCategory,
    this.subCategory,
    this.internalTag,
    required this.originalName,
    required this.originalModel,
    required this.rebrandedName,
    required this.rebrandedModel,
    this.collection,
    this.description,
    this.supplierId,
    this.supplierName,
    this.moq = 1,
    this.sampleCost = 0,
    this.leadTime = 0,
    this.rating = 5.0,
    this.material,
    this.dimensions,
    this.weight,
    this.hsCode,
    this.logoPath,
    this.insertCardPath,
    this.pkgDims,
    this.printingSpecs,
    this.barcodePlacement,
    this.brandCopy,
    this.seoTitle,
    this.seoMeta,
    this.baseCost = 0,
    this.brandingFee = 0,
    this.sampleShipping = 0,
    this.freightPerUnit = 0,
    this.landedCost = 0,
    this.retailPrice = 0,
    this.marginPct = 0,
    this.stock = 0,
    this.status = 'Draft',
    required this.createdAt,
    this.variants = const [],
    this.documents = const [],
  });

  factory B2bProductModel.fromJson(Map<String, dynamic> json) {
    return B2bProductModel(
      id: json['id']?.toString() ?? '',
      primaryCategory: json['primaryCategory'] ?? 'Domestic',
      subCategory: json['subCategory'],
      internalTag: json['internalTag'],
      originalName: json['originalName'] ?? '',
      originalModel: json['originalModel'] ?? '',
      rebrandedName: json['rebrandedName'] ?? '',
      rebrandedModel: json['rebrandedModel'] ?? '',
      collection: json['collection'],
      description: json['description'],
      supplierId: json['supplierId'],
      supplierName: json['supplier']?['name'],
      moq: (json['moq'] as num?)?.toInt() ?? 1,
      sampleCost: (json['sampleCost'] as num?)?.toDouble() ?? 0,
      leadTime: (json['leadTime'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      material: json['material'],
      dimensions: json['dimensions'],
      weight: (json['weight'] as num?)?.toDouble(),
      hsCode: json['hsCode'],
      logoPath: json['logoPath'],
      insertCardPath: json['insertCardPath'],
      pkgDims: json['pkgDims'],
      printingSpecs: json['printingSpecs'],
      barcodePlacement: json['barcodePlacement'],
      brandCopy: json['brandCopy'],
      seoTitle: json['seoTitle'],
      seoMeta: json['seoMeta'],
      baseCost: (json['baseCost'] as num?)?.toDouble() ?? 0,
      brandingFee: (json['brandingFee'] as num?)?.toDouble() ?? 0,
      sampleShipping: (json['sampleShipping'] as num?)?.toDouble() ?? 0,
      freightPerUnit: (json['freightPerUnit'] as num?)?.toDouble() ?? 0,
      landedCost: (json['landedCost'] as num?)?.toDouble() ?? 0,
      retailPrice: (json['retailPrice'] as num?)?.toDouble() ?? 0,
      marginPct: (json['marginPct'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'Draft',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      variants: json['variants'] as List? ?? [],
      documents: json['documents'] as List? ?? [],
    );
  }

  String get prodId => id;
}

// ─── B2B Trading Repository ──────────────────────────────────────────────────

class B2bTradingRepository {
  final Dio _dio;

  B2bTradingRepository(this._dio);

  Future<List<B2bProductModel>> getProducts({String? status, String? search, String? category}) async {
    final response = await _dio.get(
      '/b2b/products',
      queryParameters: {
        if (status != null && status != 'ALL') 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    final data = response.data;
    final list = (data is Map && data.containsKey('data')) ? data['data'] : data;
    if (list is List) {
      return list.map((item) => B2bProductModel.fromJson(Map<String, dynamic>.from(item))).toList();
    }
    return [];
  }

  Future<List<B2bProductModel>> getPublishedProducts([String? search]) async {
    return getProducts(status: 'published', search: search);
  }

  Future<B2bProductModel> getProductById(String id) async {
    final response = await _dio.get('/b2b/products/$id');
    final data = response.data;
    final item = (data is Map && data.containsKey('data')) ? data['data'] : data;
    return B2bProductModel.fromJson(Map<String, dynamic>.from(item));
  }

  Future<B2bProductModel> createProduct(Map<String, dynamic> body) async {
    final response = await _dio.post('/b2b/products', data: body);
    final data = response.data;
    final item = (data is Map && data.containsKey('data')) ? data['data'] : data;
    return B2bProductModel.fromJson(Map<String, dynamic>.from(item));
  }

  Future<B2bProductModel> updateProduct(String id, Map<String, dynamic> body) async {
    final response = await _dio.put('/b2b/products/$id', data: body);
    final data = response.data;
    final item = (data is Map && data.containsKey('data')) ? data['data'] : data;
    return B2bProductModel.fromJson(Map<String, dynamic>.from(item));
  }

  Future<void> deleteProduct(String id) async {
    await _dio.delete('/b2b/products/$id');
  }

  Future<Map<String, dynamic>> calculateFinancials(Map<String, dynamic> body) async {
    final response = await _dio.post('/b2b/products/calculate-financials', data: body);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final response = await _dio.get('/b2b/suppliers');
    final data = response.data;
    final list = (data is Map && data.containsKey('data')) ? data['data'] : data;
    if (list is List) {
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> body) async {
    final response = await _dio.post('/b2b/suppliers', data: body);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _dio.get('/b2b/categories');
    final data = response.data;
    final list = (data is Map && data.containsKey('data')) ? data['data'] : data;
    if (list is List) {
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> body) async {
    final response = await _dio.post('/b2b/categories', data: body);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> uploadMediaFile({
    required List<int> bytes,
    required String fileName,
    String assetType = 'SPEC_SHEET',
    String? productId,
    String? description,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'assetType': assetType,
      'productId': productId ?? '',
      'description': description ?? '',
    });
    final response = await _dio.post('/b2b/upload', data: formData);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    return (data as Map).cast<String, dynamic>();
  }

  Future<void> deleteMediaFile(String mediaId) async {
    await _dio.delete('/b2b/media/$mediaId');
  }
}

final b2bTradingRepositoryProvider = Provider<B2bTradingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return B2bTradingRepository(dio);
});
