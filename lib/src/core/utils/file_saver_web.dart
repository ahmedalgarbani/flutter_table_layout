import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves/downloads files on Web through a temporary object URL.
Future<String?> saveAndShareFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = web.Blob(
    <JSAny>[data.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Give the browser time to start the download before releasing the blob.
  Future<void>.delayed(
    const Duration(seconds: 2),
    () => web.URL.revokeObjectURL(url),
  );
  return fileName;
}
