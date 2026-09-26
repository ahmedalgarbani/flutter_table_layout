/// Cross-platform `saveAndShareFile`:
///
/// * **Web** – triggers a browser download.
/// * **Android / iOS** – writes a temporary file and opens the native share sheet.
/// * **Windows / macOS / Linux** – writes the file into the Downloads folder
///   (falls back to the documents folder) and returns its path.
library;

export 'file_saver_stub.dart'
    if (dart.library.io) 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart';
