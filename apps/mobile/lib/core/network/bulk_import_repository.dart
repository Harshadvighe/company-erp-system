import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';

class BulkImportRepository {
  final Dio _dio;

  BulkImportRepository(this._dio);

  Future<Map<String, dynamic>> parseAndPreview({
    required String target, // 'CUSTOMER' | 'VENDOR'
    required String fileName,
    required List<int> bytes,
    String? sheetName,
    Map<String, String>? columnMapping,
    bool enableGstEnrichment = true,
    bool checkDuplicates = true,
  }) async {
    final base64String = base64Encode(bytes);

    final payload = {
      'target': target,
      'fileName': fileName,
      'fileBase64': base64String,
      'sheetName': sheetName,
      'columnMapping': columnMapping,
      'enableGstEnrichment': enableGstEnrichment,
      'checkDuplicates': checkDuplicates,
    };

    final response = await _dio.post(
      '/bulk-import/parse-preview',
      data: payload,
    );

    final data = response.data;
    if (data is Map && data['data'] != null) {
      return Map<String, dynamic>.from(data['data']);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> executeImport({
    required String target,
    required List<Map<String, dynamic>> rows,
    Map<String, String>? columnMapping,
    bool skipDuplicates = true,
    bool updateExisting = false,
    String? fileName,
  }) async {
    final payload = {
      'target': target,
      'rows': rows,
      'columnMapping': columnMapping,
      'skipDuplicates': skipDuplicates,
      'updateExisting': updateExisting,
      'fileName': fileName,
    };

    final response = await _dio.post(
      '/bulk-import/execute',
      data: payload,
    );

    final data = response.data;
    if (data is Map && data['data'] != null) {
      return Map<String, dynamic>.from(data['data']);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> downloadSampleTemplate(String target) async {
    try {
      final response = await _dio.get(
        '/bulk-import/template/$target',
        options: Options(responseType: ResponseType.plain),
      );
      final content = response.data.toString();
      final filename = 'saark_${target.toLowerCase()}_sample_template.csv';
      downloadExcelFile(content, filename);
    } catch (e) {
      // Fallback local template if network is unavailable
      final fallbackContent = target == 'CUSTOMER'
          ? 'Company Name,GSTIN,Contact Person,Mobile,Email,Address,City,State,PIN Code,PAN,Customer Type,Industry,Turnover,Payment Terms,Notes\r\nAcme Industrial Automation Pvt Ltd,27AAACA1234A1Z5,Rajesh Sharma,9820123456,rajesh@acmeautomation.in,"Plot 12, Bhosari MIDC",Pune,Maharashtra,411026,AAACA1234A,END_CUSTOMER,Manufacturing,5 Cr,NET_30,Key client for VFD panels\r\nShree Ganesh Engineering,,Ganesh Patil,9890112233,ganesh@sge.com,"Sector 5, Rabale MIDC",Navi Mumbai,Maharashtra,400701,,DEALER,Automation,1.5 Cr,NET_15,Unregistered small scale dealer'
          : 'Vendor Name,GSTIN,Contact Person,Mobile,Email,Address,City,State,PIN Code,PAN,Vendor Type,Constitution,Products Supplied,MSME Status,Payment Terms,Notes\r\nSiemens Switchgear Suppliers,27AAACS9821F1ZM,Amit Kulkarni,9822012345,amit.kulkarni@siemensdealer.com,"MIDC Phase II",Pune,Maharashtra,411018,AAACS9821F,MANUFACTURER,PVT_LTD,VFD Drives & Contactors,YES,NET_30,Authorized channel partner';
      downloadExcelFile(fallbackContent, 'saark_${target.toLowerCase()}_sample_template.csv');
    }
  }

  Future<void> downloadErrorReport({
    required String target,
    required List<Map<String, dynamic>> errors,
  }) async {
    try {
      final response = await _dio.post(
        '/bulk-import/error-report',
        data: {'target': target, 'errors': errors},
        options: Options(responseType: ResponseType.plain),
      );
      final content = response.data.toString();
      final filename = 'saark_${target.toLowerCase()}_import_errors_${DateTime.now().millisecondsSinceEpoch}.csv';
      downloadExcelFile(content, filename);
    } catch (e) {
      // Build client-side fallback CSV
      final buffer = StringBuffer();
      buffer.writeln('Row Number,Company Name,GSTIN,Error Code,Error Reason,Recommended Correction');
      for (final err in errors) {
        final rowNum = err['rowNumber']?.toString() ?? '';
        final name = (err['companyName']?.toString() ?? '').replaceAll('"', '""');
        final gst = (err['gstin']?.toString() ?? '').replaceAll('"', '""');
        final code = (err['code']?.toString() ?? 'IMPORT_ERR').replaceAll('"', '""');
        final msg = (err['message']?.toString() ?? err['error']?.toString() ?? '').replaceAll('"', '""');
        final rec = (err['recommendation']?.toString() ?? 'Verify source data').replaceAll('"', '""');
        buffer.writeln('"$rowNum","$name","$gst","$code","$msg","$rec"');
      }
      final filename = 'saark_${target.toLowerCase()}_import_errors_${DateTime.now().millisecondsSinceEpoch}.csv';
      downloadExcelFile(buffer.toString(), filename);
    }
  }
}

final bulkImportRepositoryProvider = Provider<BulkImportRepository>((ref) {
  return BulkImportRepository(ref.watch(dioProvider));
});
