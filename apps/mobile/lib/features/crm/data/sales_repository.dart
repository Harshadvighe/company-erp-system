import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class SalesRepository {
  final Dio _dio;
  SalesRepository(this._dio);

  // ─── Quotations ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getQuotations({
    String? customerId,
    String? opportunityId,
    String? status,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get('/sales/quotations', queryParameters: {
      if (customerId != null) 'customerId': customerId,
      if (opportunityId != null) 'opportunityId': opportunityId,
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getQuotation(String id) async {
    final response = await _dio.get('/sales/quotations/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createQuotation(Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/quotations', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createFromPanelSpec(String specId, Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/quotations/from-panel-spec/$specId', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createRevision(String id, Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/quotations/$id/revision', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateQuotationStatus(String id, String status, {String? notes}) async {
    final response = await _dio.patch('/sales/quotations/$id/status', data: {
      'status': status,
      if (notes != null) 'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> convertToSalesOrder(String quotationId, Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/quotations/$quotationId/convert-to-order', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Sales Orders ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSalesOrders({
    String? customerId,
    String? status,
    String? productionStatus,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get('/sales/orders', queryParameters: {
      if (customerId != null) 'customerId': customerId,
      if (status != null) 'status': status,
      if (productionStatus != null) 'productionStatus': productionStatus,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSalesOrder(String id) async {
    final response = await _dio.get('/sales/orders/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSalesOrderStatus(
    String id, {
    String? status,
    String? productionStatus,
    String? notes,
  }) async {
    final response = await _dio.patch('/sales/orders/$id/status', data: {
      if (status != null) 'status': status,
      if (productionStatus != null) 'productionStatus': productionStatus,
      if (notes != null) 'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  // ─── Commercial Invoices & Billing ─────────────────────────────────────────

  Future<Map<String, dynamic>> getInvoices({
    String? customerId,
    String? salesOrderId,
    String? status,
    String? paymentStatus,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get('/sales/invoices', queryParameters: {
      if (customerId != null) 'customerId': customerId,
      if (salesOrderId != null) 'salesOrderId': salesOrderId,
      if (status != null) 'status': status,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInvoice(String id) async {
    final response = await _dio.get('/sales/invoices/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/invoices', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createInvoiceFromSalesOrder(String orderId, Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/invoices/from-order/$orderId', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recordPayment(String invoiceId, Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/invoices/$invoiceId/payments', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Accounts Summary ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAccountsSummary() async {
    final response = await _dio.get('/sales/accounts/summary');
    return response.data as Map<String, dynamic>;
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(dioProvider));
});

final quotationDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(salesRepositoryProvider);
  return repo.getQuotation(id);
});

final salesOrderDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(salesRepositoryProvider);
  return repo.getSalesOrder(id);
});
