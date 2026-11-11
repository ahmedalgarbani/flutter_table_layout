import 'dart:io';
import 'dart:typed_data';

/// Raw DEFLATE of [data] (no zlib header), as ZIP entries need it.
Uint8List? deflateRaw(Uint8List data) {
  try {
    return Uint8List.fromList(ZLibCodec(raw: true).encode(data));
  } catch (_) {
    return null;
  }
}
