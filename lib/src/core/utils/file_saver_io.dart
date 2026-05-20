import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves/shares files on Android, iOS, Windows, macOS, and Linux.
Future<void> saveAndShareFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$fileName');
  await tempFile.writeAsBytes(bytes);

  final xFile = XFile(tempFile.path, mimeType: mimeType);
  await Share.shareXFiles([xFile], text: fileName);
}
