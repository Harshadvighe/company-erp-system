import 'dart:async';
import 'dart:html' as html;

/// Web implementation for selecting an image file or camera capture
Future<String?> pickFaceImageBase64() async {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp'
    ..multiple = false;
  input.click();

  input.onChange.listen((event) {
    final files = input.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is String) {
          // If image is larger than 1024x1024, optimize client-side via canvas
          final img = html.ImageElement()..src = result;
          img.onLoad.listen((_) {
            try {
              int w = img.naturalWidth;
              int h = img.naturalHeight;
              const maxDim = 1024;
              if (w > maxDim || h > maxDim) {
                if (w > h) {
                  h = (h * maxDim / w).round();
                  w = maxDim;
                } else {
                  w = (w * maxDim / h).round();
                  h = maxDim;
                }
                final canvas = html.CanvasElement(width: w, height: h);
                final ctx = canvas.context2D;
                ctx.drawImageScaled(img, 0, 0, w, h);
                final optimized = canvas.toDataUrl('image/jpeg', 0.88);
                completer.complete(optimized);
              } else {
                completer.complete(result);
              }
            } catch (_) {
              completer.complete(result);
            }
          });
          img.onError.listen((_) => completer.complete(result));
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((_) => completer.complete(null));
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
