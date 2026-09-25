/// Platform saver stub.
///
/// Returns the saved file path (desktop), the file name (web / share sheet),
/// or `null` when nothing was written.
Future<String?> saveAndShareFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Saving files is not supported on this platform.');
}
