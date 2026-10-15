import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

// ─── Customer Model ───────────────────────────────────────────────────────────

class Customer {
  final String id;
  final String customerCode;
  final String companyName;
  final String? gstin;
  final String? pan;
  final String customerType;
  final String? gstStatus;
  final String contactPerson;
  final String? designation;
  final String email;
  final String phone;
  final String? alternatePhone;
  final String address;
  final String city;
  final String state;
  final String district;
  final String pincode;
  final String country;
  final String? industry;
  final String? source;
  final String? website;
  final double customerRating;
  final String status;
  final String? ownerName;
  final String? salesOwnerName;
  final String? addedByName;
  final int staffCount;
  final String? turnover;
  final List<String> products;
  final double valuationPercentage;
  final int activityCount;
  final int enquiryCount;
  final int opportunityCount;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.customerCode,
    required this.companyName,
    this.gstin,
    this.pan,
    required this.customerType,
    this.gstStatus,
    required this.contactPerson,
    this.designation,
    required this.email,
    required this.phone,
    this.alternatePhone,
    required this.address,
    required this.city,
    required this.state,
    required this.district,
    required this.pincode,
    required this.country,
    this.industry,
    this.source,
    this.website,
    required this.customerRating,
    required this.status,
    this.ownerName,
    this.salesOwnerName,
    this.addedByName,
    required this.staffCount,
    this.turnover,
    this.products = const [],
    this.valuationPercentage = 50.0,
    this.activityCount = 0,
    this.enquiryCount = 0,
    this.opportunityCount = 0,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final createdByUser = json['createdByUser'] as Map<String, dynamic>?;
    final assignedStaff = json['assignedStaff'] as Map<String, dynamic>?;
    final valuations = json['valuations'] as Map<String, dynamic>?;
    final counts = json['_count'] as Map<String, dynamic>? ?? {};
    final rawInterests = json['productInterests'] as List? ?? [];
    final prods = rawInterests
        .map((pi) => pi is Map && pi['productSystem'] is Map
            ? pi['productSystem']['name']?.toString()
            : null)
        .whereType<String>()
        .toList();

    return Customer(
      id: json['id'] ?? '',
      customerCode: json['customerCode'] ?? '',
      companyName: json['companyName'] ?? '',
      gstin: json['gstin'],
      pan: json['pan'],
      customerType: json['customerType'] ?? 'END_CUSTOMER',
      gstStatus: json['gstStatus'] ??
          (json['gstin'] != null && json['gstin'].toString().isNotEmpty
              ? 'GST_REGISTERED'
              : 'NO_GST'),
      contactPerson: json['contactPerson'] ?? '',
      designation: json['designation'],
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      alternatePhone: json['alternatePhone'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      district: json['district'] ?? '',
      pincode: json['pincode'] ?? '',
      country: json['country'] ?? 'India',
      industry: json['industry'],
      source: json['source'],
      website: json['website'],
      customerRating: (json['customerRating'] ?? 5.0).toDouble(),
      status: json['status'] ?? 'ACTIVE',
      ownerName: json['ownerName'] ?? assignedStaff?['fullName'],
      salesOwnerName: assignedStaff?['fullName'] ?? json['ownerName'],
      addedByName: createdByUser?['fullName'],
      staffCount: json['staffCount'] ?? json['numEmployees'] ?? 0,
      turnover: json['turnover'],
      products: prods,
      valuationPercentage:
          (valuations?['valuablePercentage'] as num?)?.toDouble() ?? 50.0,
      activityCount: ((counts['activities'] as int? ?? 0) +
          (counts['interactions'] as int? ?? 0) +
          (counts['followUps'] as int? ?? 0)),
      enquiryCount: counts['enquiries'] as int? ?? 0,
      opportunityCount: counts['leads'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  String get typeLabel {
    const map = {
      'END_CUSTOMER': 'End Customer',
      'DEALER': 'Dealer',
      'DISTRIBUTOR': 'Distributor',
      'OEM': 'OEM',
      'GOVERNMENT': 'Government',
      'OTHER': 'Other',
    };
    return map[customerType] ?? customerType;
  }

  String get initials {
    final parts = companyName.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C';
  }
}

// ─── Trashed Customer Model ───────────────────────────────────────────────────

class TrashedCustomer {
  final String id;
  final String customerCode;
  final String companyName;
  final String customerType;
  final String contactPerson;
  final String email;
  final String phone;
  final String city;
  final String state;
  final String status;
  final DateTime? deletedAt;
  final String? deletedBy;
  final bool hasStatutoryRecords;
  final String? statutoryReason;

  const TrashedCustomer({
    required this.id,
    required this.customerCode,
    required this.companyName,
    required this.customerType,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.city,
    required this.state,
    required this.status,
    this.deletedAt,
    this.deletedBy,
    this.hasStatutoryRecords = false,
    this.statutoryReason,
  });

  factory TrashedCustomer.fromJson(Map<String, dynamic> json) {
    return TrashedCustomer(
      id: json['id'] ?? '',
      customerCode: json['customerCode'] ?? '',
      companyName: json['companyName'] ?? '',
      customerType: json['customerType'] ?? 'END_CUSTOMER',
      contactPerson: json['contactPerson'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      status: json['status'] ?? 'DELETED',
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'].toString())
          : null,
      deletedBy: json['deletedBy'],
      hasStatutoryRecords: json['hasStatutoryRecords'] == true,
      statutoryReason: json['statutoryReason'],
    );
  }

  String get initials {
    final parts = companyName.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C';
  }
}

// ─── Customers Repository ─────────────────────────────────────────────────────

class CustomersRepository {
  final Dio _dio;

  CustomersRepository(this._dio);

  Future<Map<String, dynamic>> getCustomers({
    String? search,
    String? type,
    String? status,
    int page = 1,
    int limit = 25,
    String? sortBy,
    Map<String, dynamic> filters = const {},
  }) async {
    final response = await _dio.get('/customers', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (sortBy != null) 'sortBy': sortBy,
      ...filters,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCompanyFilterOptions({String? state}) async {
    final response = await _dio.get('/customers/filter-options', queryParameters: {
      if (state != null && state.isNotEmpty) 'state': state,
    });
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Unexpected company filter options response');
  }

  Future<Map<String, dynamic>> getCustomer(String id) async {
    final response = await _dio.get('/customers/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final response = await _dio.post('/customers', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCustomer(
      String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/customers/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteCustomer(String id) async {
    await _dio.delete('/customers/$id');
  }

  Future<Map<String, dynamic>> bulkTrash(List<String> ids, {String? reason}) async {
    final response = await _dio.post('/customers/bulk-trash', data: {
      'ids': ids,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTrash({
    String? search,
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _dio.get('/customers/trash', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> restoreCustomer(String id) async {
    final response = await _dio.post('/customers/$id/restore');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bulkRestore(List<String> ids) async {
    final response = await _dio.post('/customers/bulk-restore', data: {
      'ids': ids,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> permanentDeleteCustomer(String id) async {
    final response = await _dio.delete('/customers/$id/permanent');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bulkPermanentDelete(List<String> ids) async {
    final response = await _dio.post('/customers/bulk-permanent-delete', data: {
      'ids': ids,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> emptyRecycleBin() async {
    final response = await _dio.post('/customers/recycle-bin/empty');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addContact(
      String customerId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/customers/$customerId/contacts', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getInteractions(String customerId,
      {String? type}) async {
    final response = await _dio.get(
      '/customers/$customerId/interactions',
      queryParameters: {if (type != null) 'type': type},
    );
    final data = response.data;
    if (data is Map) return data['data'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<Map<String, dynamic>> checkDuplicate(
    dynamic dataOrGstin, {
    String? phone,
    String? email,
    String? companyName,
  }) async {
    Map<String, dynamic> body;
    if (dataOrGstin is Map<String, dynamic>) {
      body = dataOrGstin;
    } else {
      body = {
        if (dataOrGstin != null) 'gstin': dataOrGstin,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (companyName != null) 'companyName': companyName,
      };
    }
    final response =
        await _dio.post('/crm/companies/duplicate-check', data: body);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mergeCustomers({
    required String sourceId,
    required String targetId,
  }) async {
    final response = await _dio.post('/customers/merge', data: {
      'sourceId': sourceId,
      'targetId': targetId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recordInteraction(
      String customerId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/customers/$customerId/interactions', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyGst(String gstin) async {
    final response =
        await _dio.post('/crm/companies/gst-verify', data: {'gstin': gstin});
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getProductSystems() async {
    final response = await _dio.get('/crm/product-systems');
    if (response.data is List) return response.data as List;
    if (response.data is Map && response.data['data'] is List) {
      return response.data['data'] as List;
    }
    return [];
  }

  Future<dynamic> updateProductInterests(
      String customerId, List<String> productSystemIds) async {
    final response = await _dio.put(
        '/crm/companies/$customerId/product-interests',
        data: {'productSystemIds': productSystemIds});
    return response.data;
  }

  Future<Map<String, dynamic>> updateValuation(
      String customerId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/crm/companies/$customerId/valuation', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> respondMeeting(
      String meetingId, Map<String, dynamic> data) async {
    final response =
        await _dio.patch('/crm/meetings/$meetingId/respond', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadCallRecording(
      String callId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/crm/calls/$callId/recordings', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadDocument({
    required List<int> bytes,
    required String fileName,
    String entityType = 'CUSTOMER',
    String? entityId,
    String documentType = 'ATTACHMENT',
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'entityType': entityType,
      'entityId': entityId ?? 'SYS',
      'documentType': documentType,
    });
    final response = await _dio.post('/documents/upload', data: formData);
    final responseData = response.data;
    if (responseData is Map && responseData['data'] is Map) {
      return Map<String, dynamic>.from(responseData['data'] as Map);
    }
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    throw const FormatException('Unexpected document upload response');
  }

  Future<List<dynamic>> getCustomerDocuments(String customerId) async {
    try {
      final response = await _dio.get('/documents/entity', queryParameters: {
        'type': 'CUSTOMER',
        'id': customerId,
      });
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      return [];
    }
  }
}

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.watch(dioProvider));
});

// ─── Providers ────────────────────────────────────────────────────────────────

class CustomerListState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;
  final int total;
  final int systemTotal;
  final int page;
  final int totalPages;
  final int pageSize;

  const CustomerListState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.systemTotal = 0,
    this.page = 1,
    this.totalPages = 1,
    this.pageSize = 25,
  });

  CustomerListState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
    int? total,
    int? systemTotal,
    int? page,
    int? totalPages,
    int? pageSize,
  }) {
    return CustomerListState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      systemTotal: systemTotal ?? this.systemTotal,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

class CustomerListNotifier extends StateNotifier<CustomerListState> {
  final CustomersRepository _repo;

  CustomerListNotifier(this._repo) : super(const CustomerListState());

  Future<void> loadCustomers({
    String? search,
    String? type,
    int page = 1,
    int? pageSize,
    String? sortBy,
    Map<String, dynamic> filters = const {},
  }) async {
    final effectivePageSize = pageSize ?? state.pageSize;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result =
          await _repo.getCustomers(
            search: search,
            type: type,
            page: page,
            limit: effectivePageSize,
            sortBy: sortBy,
            filters: filters,
          );
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final customers = (data['data'] as List? ?? [])
          .map((c) => Customer.fromJson(c as Map<String, dynamic>))
          .toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};

      state = state.copyWith(
        customers: customers,
        isLoading: false,
        total: meta['total'] as int? ?? customers.length,
        systemTotal: meta['systemTotal'] as int? ?? meta['total'] as int? ?? customers.length,
        page: meta['page'] as int? ?? page,
        totalPages: meta['totalPages'] as int? ?? 1,
        pageSize: effectivePageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, CustomerListState>((ref) {
  return CustomerListNotifier(ref.watch(customersRepositoryProvider));
});

final customerDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.watch(customersRepositoryProvider);
  final result = await repo.getCustomer(id);
  return result['data'] as Map<String, dynamic>? ?? result;
});

final customerTimelineProvider =
    FutureProvider.family<List<dynamic>, String>((ref, id) async {
  final repo = ref.watch(customersRepositoryProvider);
  final response = await repo._dio.get('/customers/$id/timeline');
  final data = response.data;
  if (data is Map) return data['data'] as List? ?? [];
  return data as List? ?? [];
});
