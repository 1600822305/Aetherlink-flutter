import 'dart:typed_data';

/// Shared helpers used across the network TTS engines.

/// Joins a base URL with a path, avoiding a duplicated `/`.
String joinUrl(String base, String path) {
  final trimmed = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  return '$trimmed$path';
}

/// Escapes XML special characters (used when building SSML).
String escapeXml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Decodes a hex string into raw bytes.
Uint8List hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

/// Wraps raw PCM data in a WAV header.
Uint8List pcmToWav(
  Uint8List pcm, {
  int sampleRate = 24000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataSize = pcm.length;
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  // RIFF header
  buffer.setUint8(0, 0x52); // R
  buffer.setUint8(1, 0x49); // I
  buffer.setUint8(2, 0x46); // F
  buffer.setUint8(3, 0x46); // F
  buffer.setUint32(4, fileSize, Endian.little);
  buffer.setUint8(8, 0x57); // W
  buffer.setUint8(9, 0x41); // A
  buffer.setUint8(10, 0x56); // V
  buffer.setUint8(11, 0x45); // E
  // fmt sub-chunk
  buffer.setUint8(12, 0x66); // f
  buffer.setUint8(13, 0x6d); // m
  buffer.setUint8(14, 0x74); // t
  buffer.setUint8(15, 0x20); // (space)
  buffer.setUint32(16, 16, Endian.little); // sub-chunk size
  buffer.setUint16(20, 1, Endian.little); // PCM format
  buffer.setUint16(22, channels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, blockAlign, Endian.little);
  buffer.setUint16(34, bitsPerSample, Endian.little);
  // data sub-chunk
  buffer.setUint8(36, 0x64); // d
  buffer.setUint8(37, 0x61); // a
  buffer.setUint8(38, 0x74); // t
  buffer.setUint8(39, 0x61); // a
  buffer.setUint32(40, dataSize, Endian.little);
  // PCM data
  final bytes = buffer.buffer.asUint8List();
  bytes.setRange(44, 44 + dataSize, pcm);
  return bytes;
}

/// Generates a v4-style UUID (used by Volcano request ids).
String generateUuid() {
  final r = DateTime.now().microsecondsSinceEpoch;
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
    RegExp('[xy]'),
    (m) {
      final c = m.group(0)!;
      final v = (r + (DateTime.now().microsecond * 16)).abs() % 16;
      final d = c == 'x' ? v : (v & 0x3 | 0x8);
      return d.toRadixString(16);
    },
  );
}
