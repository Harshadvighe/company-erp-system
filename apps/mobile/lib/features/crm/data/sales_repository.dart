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

  Future<Map<String, dynamic>> updateInvoice(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/sales/invoices/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteInvoice(String id) async {
    await _dio.delete('/sales/invoices/$id');
  }

  Future<Map<String, dynamic>> recordPayment(String invoiceId, Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/invoices/$invoiceId/payments', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ─── Bank & Cash Management ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBankAccounts() async {
    final response = await _dio.get('/sales/bank-cash/accounts');
    final raw = response.data;
    final list = raw is Map && raw['data'] != null ? raw['data'] : raw;
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveBankAccount(Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/bank-cash/accounts', data: data);
    final raw = response.data;
    return raw is Map && raw['data'] != null ? Map<String, dynamic>.from(raw['data'] as Map) : Map<String, dynamic>.from(raw as Map);
  }

  Future<void> deleteBankAccount(String id) async {
    await _dio.delete('/sales/bank-cash/accounts/$id');
  }

  Future<List<Map<String, dynamic>>> getBankTransactions() async {
    final response = await _dio.get('/sales/bank-cash/transactions');
    final raw = response.data;
    final list = raw is Map && raw['data'] != null ? raw['data'] : raw;
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveBankTransaction(Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/bank-cash/transactions', data: data);
    final raw = response.data;
    return raw is Map && raw['data'] != null ? Map<String, dynamic>.from(raw['data'] as Map) : Map<String, dynamic>.from(raw as Map);
  }

  Future<void> deleteBankTransaction(String id) async {
    await _dio.delete('/sales/bank-cash/transactions/$id');
  }

  Future<Map<String, dynamic>> getBankCashSummary() async {
    final response = await _dio.get('/sales/bank-cash/summary');
    final raw = response.data;
    return raw is Map && raw['data'] != null ? Map<String, dynamic>.from(raw['data'] as Map) : Map<String, dynamic>.from(raw as Map);
  }

  // ─── Expense Management ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getExpenses({String? category, String? search}) async {
    final response = await _dio.get('/sales/expenses', queryParameters: {
      if (category != null && category != 'All') 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final raw = response.data;
    final list = raw is Map && raw['data'] != null ? raw['data'] : raw;
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveExpense(Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/expenses', data: data);
    final raw = response.data;
    return raw is Map && raw['data'] != null ? Map<String, dynamic>.from(raw['data'] as Map) : Map<String, dynamic>.from(raw as Map);
  }

  Future<void> deleteExpense(String id) async {
    await _dio.delete('/sales/expenses/$id');
  }

  Future<Map<String, dynamic>> getExpenseSummary() async {
    final response = await _dio.get('/sales/expenses/summary');
    final raw = response.data;
    return raw is Map && raw['data'] != null ? Map<String, dynamic>.from(raw['data'] as Map) : Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> getAccountsSummary() async {
    final response = await _dio.get('/sales/accounts/summary');
    final raw = response.data;
    return raw is Map && raw['data'] != null ? Map<String, dynamic>.from(raw['data'] as Map) : Map<String, dynamic>.from(raw as Map);
  }

  // ─── Outward Documents (Other Documents) ──────────────────────────────────

  Future<List<Map<String, dynamic>>> getOutwardDocuments({String? documentType, String? search}) async {
    final response = await _dio.get('/sales/outward', queryParameters: {
      if (documentType != null && documentType != 'All') 'documentType': documentType,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final raw = response.data;
    final list = raw is Map && raw['data'] != null ? raw['data'] : raw;
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<String> getNextOutwardNumber(String type, String date) async {
    final response = await _dio.get('/sales/outward/next-number', queryParameters: {
      'type': type,
      'date': date,
    });
    final raw = response.data;
    final data = raw is Map && raw['data'] != null ? raw['data'] : raw;
    if (data is Map && data['documentNo'] != null) {
      return data['documentNo'].toString();
    }
    return '';
  }

  Future<Map<String, dynamic>> saveOutwardDocument(Map<String, dynamic> data) async {
    final response = await _dio.post('/sales/outward', data: data);
    final raw = response.data;
    return raw is Map && raw['data'] != null ? Map<String, dynamic>.from(raw['data'] as Map) : Map<String, dynamic>.from(raw as Map);
  }

  Future<void> deleteOutwardDocument(String docNo) async {
    await _dio.delete('/sales/outward/$docNo');
  }

  Future<List<String>> getOutwardCustomers() async {
    final response = await _dio.get('/sales/outward/customers');
    final raw = response.data;
    final list = raw is Map && raw['data'] != null ? raw['data'] : raw;
    if (list is List) {
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getOutwardCatalog() async {
    final response = await _dio.get('/sales/outward/catalog');
    final raw = response.data;
    final list = raw is Map && raw['data'] != null ? raw['data'] : raw;
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ─── Financial Reports ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFinancialReports({String? period}) async {
    final response = await _dio.get('/sales/financial-reports', queryParameters: {
      if (period != null && period.isNotEmpty && period != 'All') 'period': period,
    });
    final raw = response.data;
    return raw is Map && raw['data'] != null ? Map<String, dynamic>.from(raw['data'] as Map) : Map<String, dynamic>.from(raw as Map);
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
