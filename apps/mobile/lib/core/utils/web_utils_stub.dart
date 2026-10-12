import 'package:flutter/foundation.dart';

void openWebUrl(String url) {
  debugPrint('openWebUrl (non-web): $url');
}

void pickAndUploadWebFile({
  required String fieldType,
  required Function(String fileName, List<int> bytes) onFilePicked,
}) {
  debugPrint('pickAndUploadWebFile (non-web): $fieldType');
}

void downloadExcelFile(String content, String filename) {
  debugPrint('downloadExcelFile (non-web): $filename');
}
