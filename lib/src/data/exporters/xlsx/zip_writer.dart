import 'dart:convert';
import 'dart:typed_data';

import 'deflate_stub.dart' if (dart.library.io) 'deflate_io.dart';

/// A minimal ZIP archive writer (enough for `.xlsx` packages): UTF-8 names,
/// DEFLATE where the platform has a codec, stored entries otherwise.
class ZipWriter {
  final _entries = <_ZipEntry>[];

  /// Adds a file. [compress] `false` always stores it as-is.
  void addFile(String name, List<int> content, {bool compress = true}) {
    final data = content is Uint8List ? content : Uint8List.fromList(content);
    Uint8List? packed = compress && data.length > 64 ? deflateRaw(data) : null;
    if (packed != null && packed.length >= data.length) packed = null;
    _entries.add(
      _ZipEntry(
        name: Uint8List.fromList(utf8.encode(name)),
        crc: crc32(data),
        size: data.length,
        stored: packed ?? data,
        deflated: packed != null,
      ),
    );
  }

  /// The archive bytes.
  Uint8List encode() {
    final out = BytesBuilder(copy: false);
    final offsets = <int>[];
    for (final e in _entries) {
      offsets.add(out.length);
      out
        ..add(_header(e, local: true, offset: 0))
        ..add(e.name)
        ..add(e.stored);
    }
    final directoryStart = out.length;
    for (var i = 0; i < _entries.length; i++) {
      out
        ..add(_header(_entries[i], local: false, offset: offsets[i]))
        ..add(_entries[i].name);
    }
    final directorySize = out.length - directoryStart;
    final end = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(8, _entries.length, Endian.little)
      ..setUint16(10, _entries.length, Endian.little)
      ..setUint32(12, directorySize, Endian.little)
      ..setUint32(16, directoryStart, Endian.little);
    out.add(end.buffer.asUint8List());
    return out.toBytes();
  }

  // 1980-01-01 00:00: a fixed timestamp keeps the output reproducible.
  static const _dosTime = 0;
  static const _dosDate = 0x21;

  static Uint8List _header(
    _ZipEntry e, {
    required bool local,
    required int offset,
  }) {
    final b = ByteData(local ? 30 : 46);
    var p = 0;
    void u16(int v) {
      b.setUint16(p, v, Endian.little);
      p += 2;
    }

    void u32(int v) {
      b.setUint32(p, v, Endian.little);
      p += 4;
    }

    u32(local ? 0x04034b50 : 0x02014b50);
    if (!local) u16(20); // version made by
    u16(20); // version needed
    u16(0x0800); // UTF-8 file names
    u16(e.deflated ? 8 : 0);
    u16(_dosTime);
    u16(_dosDate);
    u32(e.crc);
    u32(e.stored.length);
    u32(e.size);
    u16(e.name.length);
    u16(0); // extra
    if (!local) {
      u16(0); // comment
      u16(0); // disk
      u16(0); // internal attributes
      u32(0); // external attributes
      u32(offset);
    }
    return b.buffer.asUint8List();
  }

  static final Uint32List _crcTable = () {
    final table = Uint32List(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = c & 1 != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      }
      table[n] = c;
    }
    return table;
  }();

  /// CRC-32 (IEEE 802.3) of [data].
  static int crc32(List<int> data) {
    var c = 0xFFFFFFFF;
    for (final byte in data) {
      c = _crcTable[(c ^ byte) & 0xFF] ^ (c >>> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}

class _ZipEntry {
  final Uint8List name;
  final int crc;
  final int size;
  final Uint8List stored;
  final bool deflated;

  const _ZipEntry({
    required this.name,
    required this.crc,
    required this.size,
    required this.stored,
    required this.deflated,
  });
}
