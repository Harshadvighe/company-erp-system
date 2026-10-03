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
  final int staffCount;
  final String? turnover;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.customerCode,
    required this.companyName,
    this.gstin,
    this.pan,
    required this.customerType,
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
    required this.staffCount,
    this.turnover,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      customerCode: json['customerCode'] ?? '',
      companyName: json['companyName'] ?? '',
      gstin: json['gstin'],
      pan: json['pan'],
      customerType: json['customerType'] ?? 'END_CUSTOMER',
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
      ownerName: json['ownerName'],
      staffCount: json['staffCount'] ?? 0,
      turnover: json['turnover'],
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
  }) async {
    final response = await _dio.get('/customers', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomer(String id) async {
    final response = await _dio.get('/customers/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final response = await _dio.post('/customers', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCustomer(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/customers/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteCustomer(String id) async {
    await _dio.delete('/customers/$id');
  }

  Future<Map<String, dynamic>> addContact(String customerId, Map<String, dynamic> data) async {
    final response = await _dio.post('/customers/$customerId/contacts', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getInteractions(String customerId, {String? type}) async {
    final response = await _dio.get(
      '/customers/$customerId/interactions',
      queryParameters: {if (type != null) 'type': type},
    );
    final data = response.data;
    if (data is Map) return data['data'] as List? ?? [];
    return data as List? ?? [];
  }

  Future<Map<String, dynamic>> recordInteraction(
      String customerId, Map<String, dynamic> data) async {
    final response = await _dio.post('/customers/$customerId/interactions', data: data);
    return response.data as Map<String, dynamic>;
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
  final int page;
  final int totalPages;

  const CustomerListState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
  });

  CustomerListState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
    int? total,
    int? page,
    int? totalPages,
  }) {
    return CustomerListState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
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
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getCustomers(search: search, type: type, page: page);
      final data = result['data'] as Map<String, dynamic>? ?? result;
      final customers = (data['data'] as List? ?? [])
          .map((c) => Customer.fromJson(c as Map<String, dynamic>))
          .toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};

      state = state.copyWith(
        customers: customers,
        isLoading: false,
        total: meta['total'] as int? ?? customers.length,
        page: meta['page'] as int? ?? page,
        totalPages: meta['totalPages'] as int? ?? 1,
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

