import 'dart:convert';
import 'dart:typed_data';

/// Minimal MessagePack encoder covering the types needed by TTS request
/// bodies: null, bool, int, double, String, Uint8List (bin), List and Map.
/// Spec: https://github.com/msgpack/msgpack/blob/master/spec.md
Uint8List msgpackEncode(Object? value) {
  final builder = BytesBuilder(copy: false);
  _encode(value, builder);
  return builder.toBytes();
}

void _encode(Object? value, BytesBuilder out) {
  switch (value) {
    case null:
      out.addByte(0xc0);
    case bool v:
      out.addByte(v ? 0xc3 : 0xc2);
    case int v:
      _encodeInt(v, out);
    case double v:
      final b = ByteData(9)
        ..setUint8(0, 0xcb)
        ..setFloat64(1, v);
      out.add(b.buffer.asUint8List());
    case String v:
      _encodeString(v, out);
    case Uint8List v:
      _encodeBinary(v, out);
    case List<Object?> v:
      _encodeLength(v.length, out, fix: 0x90, b16: 0xdc, b32: 0xdd);
      for (final item in v) {
        _encode(item, out);
      }
    case Map<Object?, Object?> v:
      _encodeLength(v.length, out, fix: 0x80, b16: 0xde, b32: 0xdf);
      v.forEach((key, item) {
        _encode(key, out);
        _encode(item, out);
      });
    default:
      throw ArgumentError(
        'msgpackEncode: unsupported type ${value.runtimeType}',
      );
  }
}

void _encodeInt(int v, BytesBuilder out) {
  if (v >= 0) {
    if (v < 0x80) {
      out.addByte(v);
    } else if (v <= 0xff) {
      out.add([0xcc, v]);
    } else if (v <= 0xffff) {
      out.add([0xcd, v >> 8, v & 0xff]);
    } else if (v <= 0xffffffff) {
      final b = ByteData(5)
        ..setUint8(0, 0xce)
        ..setUint32(1, v);
      out.add(b.buffer.asUint8List());
    } else {
      final b = ByteData(9)
        ..setUint8(0, 0xcf)
        ..setUint64(1, v);
      out.add(b.buffer.asUint8List());
    }
  } else {
    if (v >= -32) {
      out.addByte(0xe0 | (v + 32));
    } else if (v >= -128) {
      final b = ByteData(2)
        ..setUint8(0, 0xd0)
        ..setInt8(1, v);
      out.add(b.buffer.asUint8List());
    } else if (v >= -32768) {
      final b = ByteData(3)
        ..setUint8(0, 0xd1)
        ..setInt16(1, v);
      out.add(b.buffer.asUint8List());
    } else if (v >= -2147483648) {
      final b = ByteData(5)
        ..setUint8(0, 0xd2)
        ..setInt32(1, v);
      out.add(b.buffer.asUint8List());
    } else {
      final b = ByteData(9)
        ..setUint8(0, 0xd3)
        ..setInt64(1, v);
      out.add(b.buffer.asUint8List());
    }
  }
}

void _encodeString(String v, BytesBuilder out) {
  final bytes = utf8.encode(v);
  final len = bytes.length;
  if (len < 32) {
    out.addByte(0xa0 | len);
  } else if (len <= 0xff) {
    out.add([0xd9, len]);
  } else if (len <= 0xffff) {
    out.add([0xda, len >> 8, len & 0xff]);
  } else {
    final b = ByteData(5)
      ..setUint8(0, 0xdb)
      ..setUint32(1, len);
    out.add(b.buffer.asUint8List());
  }
  out.add(bytes);
}

void _encodeBinary(Uint8List v, BytesBuilder out) {
  final len = v.length;
  if (len <= 0xff) {
    out.add([0xc4, len]);
  } else if (len <= 0xffff) {
    out.add([0xc5, len >> 8, len & 0xff]);
  } else {
    final b = ByteData(5)
      ..setUint8(0, 0xc6)
      ..setUint32(1, len);
    out.add(b.buffer.asUint8List());
  }
  out.add(v);
}

void _encodeLength(
  int len,
  BytesBuilder out, {
  required int fix,
  required int b16,
  required int b32,
}) {
  if (len < 16) {
    out.addByte(fix | len);
  } else if (len <= 0xffff) {
    out.add([b16, len >> 8, len & 0xff]);
  } else {
    final b = ByteData(5)
      ..setUint8(0, b32)
      ..setUint32(1, len);
    out.add(b.buffer.asUint8List());
  }
}
