import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class PurchaseRepository {
  final Dio _dio;

  PurchaseRepository(this._dio);

  Future<Map<String, dynamic>> getDashboardSummary({
    String? finYear,
    String? fromDate,
    String? toDate,
    String? vendorId,
    String? departmentId,
    String? status,
  }) async {
    final response = await _dio.get('/purchase/dashboard', queryParameters: {
      if (finYear != null && finYear.isNotEmpty) 'finYear': finYear,
      if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
      if (vendorId != null && vendorId.isNotEmpty) 'vendorId': vendorId,
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getPendingInvoices() async {
    final response = await _dio.get('/purchase/invoices/pending');
    final data = response.data['data'] as List? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> getInwardEntries({
    String? search,
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _dio.get('/purchase/inward', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getInwardEntry(String id) async {
    final response = await _dio.get('/purchase/inward/$id');
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createInwardEntry(Map<String, dynamic> data) async {
    final response = await _dio.post('/purchase/inward', data: data);
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> inspectQCItem(
    String inwardId,
    String itemId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.patch('/purchase/inward/$inwardId/items/$itemId/qc', data: data);
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> recordInvoicePayment(
    String invoiceId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post('/purchase/invoices/$invoiceId/payments', data: data);
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getCheques() async {
    final response = await _dio.get('/purchase/cheques');
    final data = response.data['data'] as List? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createCheque(Map<String, dynamic> data) async {
    final response = await _dio.post('/purchase/cheques', data: data);
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> updateChequeStatus(
    String id,
    String status, {
    String? reason,
  }) async {
    final response = await _dio.patch('/purchase/cheques/$id/status', data: {
      'status': status,
      if (reason != null) 'reason': reason,
    });
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getOutwardDocuments() async {
    final response = await _dio.get('/purchase/outward');
    final data = response.data['data'] as List? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createOutwardDocument(Map<String, dynamic> data) async {
    final response = await _dio.post('/purchase/outward', data: data);
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getPurchaseReturns() async {
    final response = await _dio.get('/purchase/returns');
    final data = response.data['data'] as List? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createPurchaseReturn(Map<String, dynamic> data) async {
    final response = await _dio.post('/purchase/returns', data: data);
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createVendorRegistration(Map<String, dynamic> data) async {
    final response = await _dio.post('/vendors', data: data);
    return (response.data['data'] as Map<String, dynamic>?) ?? (response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getVendors() async {
    final response = await _dio.get('/vendors');
    final data = response.data['data'] as Map<String, dynamic>? ?? response.data;
    final list = data['data'] as List? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final response = await _dio.get('/products');
    final data = response.data['data'] as Map<String, dynamic>? ?? response.data;
    final list = data['data'] as List? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }
}

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(dioProvider));
});

class PurchaseDashboardState {
  final Map<String, dynamic>? summary;
  final List<Map<String, dynamic>> pendingInvoices;
  final List<Map<String, dynamic>> recentInwards;
  final bool isLoading;
  final String? error;

  const PurchaseDashboardState({
    this.summary,
    this.pendingInvoices = const [],
    this.recentInwards = const [],
    this.isLoading = false,
    this.error,
  });

  PurchaseDashboardState copyWith({
    Map<String, dynamic>? summary,
    List<Map<String, dynamic>>? pendingInvoices,
    List<Map<String, dynamic>>? recentInwards,
    bool? isLoading,
    String? error,
  }) {
    return PurchaseDashboardState(
      summary: summary ?? this.summary,
      pendingInvoices: pendingInvoices ?? this.pendingInvoices,
      recentInwards: recentInwards ?? this.recentInwards,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PurchaseDashboardNotifier extends StateNotifier<PurchaseDashboardState> {
  final PurchaseRepository _repo;

  PurchaseDashboardNotifier(this._repo) : super(const PurchaseDashboardState());

  Future<void> loadDashboard({
    String? finYear,
    String? fromDate,
    String? toDate,
    String? vendorId,
    String? departmentId,
    String? status,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _repo.getDashboardSummary(
        finYear: finYear,
        fromDate: fromDate,
        toDate: toDate,
        vendorId: vendorId,
        departmentId: departmentId,
        status: status,
      );

      final summary = res['summary'] as Map<String, dynamic>? ?? {};
      final invoices = (res['pendingInvoices'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final inwards = (res['recentInwards'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      state = state.copyWith(
        summary: summary,
        pendingInvoices: invoices,
        recentInwards: inwards,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final purchaseDashboardProvider =
    StateNotifierProvider<PurchaseDashboardNotifier, PurchaseDashboardState>((ref) {
  return PurchaseDashboardNotifier(ref.watch(purchaseRepositoryProvider));
});
