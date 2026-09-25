import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves/shares files on Android, iOS, Windows, macOS, and Linux.
///
/// Mobile platforms open the native share sheet and return the file name.
/// Desktop platforms write into the Downloads folder (or documents folder)
/// and return the full path of the written file.
Future<String?> saveAndShareFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(tempFile.path, mimeType: mimeType)],
        subject: fileName,
      ),
    );
    return fileName;
  }

  final dir =
      await _tryDir(getDownloadsDirectory) ??
      await _tryDir(getApplicationDocumentsDirectory) ??
      await getTemporaryDirectory();
  final file = await _uniqueFile(dir, fileName);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Directory?> _tryDir(Future<Directory?> Function() getter) async {
  try {
    final dir = await getter();
    if (dir == null) return null;
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  } catch (_) {
    return null;
  }
}

/// Avoids overwriting: `report.pdf`, `report (1).pdf`, `report (2).pdf`…
Future<File> _uniqueFile(Directory dir, String fileName) async {
  final sep = Platform.pathSeparator;
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '';
  var candidate = File('${dir.path}$sep$fileName');
  var i = 1;
  while (await candidate.exists()) {
    candidate = File('${dir.path}$sep$base ($i)$ext');
    i++;
  }
  return candidate;
}
