import 'dart:html' as html;
import 'package:flutter/foundation.dart';

void openWebUrl(String url) {
  try {
    html.window.open(url, '_blank');
  } catch (e) {
    debugPrint('Error opening web URL: $e');
  }
}

void pickAndUploadWebFile({
  required String fieldType,
  required Function(String fileName, List<int> bytes) onFilePicked,
}) {
  try {
    final uploadInput = html.FileUploadInputElement();
    if (fieldType == 'PHOTO') {
      uploadInput.accept = 'image/*';
    } else if (fieldType == 'AUDIO') {
      uploadInput.accept = 'audio/*';
    } else if (fieldType == 'EXCEL') {
      uploadInput.accept = '.xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv';
    } else {
      uploadInput.accept = '*/*'; // Accept ANY format
    }
    uploadInput.multiple = false;
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((e) {
          final bytes = (reader.result as List<int>);
          onFilePicked(file.name, bytes);
        });
      }
    });
  } catch (e) {
    debugPrint('Error picking file: $e');
  }
}

void downloadExcelFile(String content, String filename) {
  try {
    final isXls = filename.toLowerCase().endsWith('.xls');
    final mimeType = isXls ? 'application/vnd.ms-excel;charset=utf-8;' : 'text/csv;charset=utf-8;';
    
    // For CSV, add BOM for Excel compatibility, for HTML (.xls) we already have meta charset
    final bytes = isXls ? [content] : ['\uFEFF', content];
    
    final blob = html.Blob(bytes, mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    debugPrint('Error downloading file: $e');
  }
}
