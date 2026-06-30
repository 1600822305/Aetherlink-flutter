import 'package:aetherlink_flutter/shared/utils/api_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatApiHost', () {
    test('blank host returns empty', () {
      expect(formatApiHost(''), '');
      expect(formatApiHost(null), '');
      expect(formatApiHost('   '), '');
    });

    test('appends /v1 when the version is missing', () {
      expect(formatApiHost('https://api.example.com'),
          'https://api.example.com/v1');
      expect(formatApiHost('http://localhost:5173/'),
          'http://localhost:5173/v1');
      expect(formatApiHost(' https://api.openai.com '),
          'https://api.openai.com/v1');
    });

    test('keeps the host when a version is already present', () {
      expect(formatApiHost('https://api.volces.com/api/v3'),
          'https://api.volces.com/api/v3');
      expect(formatApiHost('http://localhost:5173/v2beta'),
          'http://localhost:5173/v2beta');
    });

    test('supports a custom api version', () {
      expect(formatApiHost('https://api.example.com', apiVersion: 'v2'),
          'https://api.example.com/v2');
    });

    test('leaves the host untouched when the version is unsupported', () {
      expect(formatApiHost('https://api.example.com', supportApiVersion: false),
          'https://api.example.com');
    });

    test('trailing # is the escape hatch: strip it, append nothing', () {
      expect(formatApiHost('https://api.example.com#'),
          'https://api.example.com');
      expect(formatApiHost('http://localhost:5173/#'),
          'http://localhost:5173/');
      expect(formatApiHost(' https://api.openai.com/# '),
          'https://api.openai.com/');
      expect(formatApiHost('https://api.example.com/v2#'),
          'https://api.example.com/v2');
    });
  });

  group('hasApiVersion', () {
    test('detects a trailing version segment', () {
      expect(hasApiVersion('https://api.example.com/v1'), isTrue);
      expect(hasApiVersion('http://localhost:3000/v2beta'), isTrue);
      expect(hasApiVersion('https://api.example.com/v1/chat'), isTrue);
    });

    test('false when no version segment', () {
      expect(hasApiVersion('https://api.example.com'), isFalse);
      expect(hasApiVersion('https://v2.example.com'), isFalse);
    });
  });
}
