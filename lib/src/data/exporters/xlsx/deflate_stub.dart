import 'dart:typed_data';

/// Raw DEFLATE of [data], or `null` where no codec is available (web): the
/// entry is then stored uncompressed, which every spreadsheet app accepts.
Uint8List? deflateRaw(Uint8List data) => null;
