import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/msgpack_encoder.dart';

void main() {
  group('msgpackEncode', () {
    test('encodes scalars', () {
      expect(msgpackEncode(null), [0xc0]);
      expect(msgpackEncode(true), [0xc3]);
      expect(msgpackEncode(false), [0xc2]);
      expect(msgpackEncode(7), [0x07]);
      expect(msgpackEncode(200), [0xcc, 200]);
      expect(msgpackEncode(300), [0xcd, 0x01, 0x2c]);
      expect(msgpackEncode(-1), [0xff]);
      expect(msgpackEncode(-100), [0xd0, 0x9c]);
      expect(msgpackEncode(1.5), [0xcb, 0x3f, 0xf8, 0, 0, 0, 0, 0, 0]);
    });

    test('encodes strings', () {
      expect(msgpackEncode('abc'), [0xa3, 0x61, 0x62, 0x63]);
      final long = 'x' * 40;
      final encoded = msgpackEncode(long);
      expect(encoded.sublist(0, 2), [0xd9, 40]);
      expect(encoded.length, 42);
    });

    test('encodes binary as bin format', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(msgpackEncode(bytes), [0xc4, 3, 1, 2, 3]);
      final big = Uint8List(300);
      expect(msgpackEncode(big).sublist(0, 3), [0xc5, 0x01, 0x2c]);
    });

    test('encodes nested maps/lists like a TTS references body', () {
      final encoded = msgpackEncode({
        'text': 'hi',
        'references': [
          {
            'audio': Uint8List.fromList([9, 8]),
            'text': 'ok',
          },
        ],
      });
      expect(encoded, [
        0x82, // map(2)
        0xa4, 0x74, 0x65, 0x78, 0x74, // "text"
        0xa2, 0x68, 0x69, // "hi"
        0xaa, 0x72, 0x65, 0x66, 0x65, 0x72, 0x65, 0x6e, 0x63, 0x65,
        0x73, // "references"
        0x91, // array(1)
        0x82, // map(2)
        0xa5, 0x61, 0x75, 0x64, 0x69, 0x6f, // "audio"
        0xc4, 0x02, 0x09, 0x08, // bin(2) [9,8]
        0xa4, 0x74, 0x65, 0x78, 0x74, // "text"
        0xa2, 0x6f, 0x6b, // "ok"
      ]);
    });
  });
}
