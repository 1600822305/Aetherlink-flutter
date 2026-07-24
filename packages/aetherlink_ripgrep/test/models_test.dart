import 'dart:convert';

import 'package:aetherlink_ripgrep/aetherlink_ripgrep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RgSearchRequest serializes all fields', () {
    const request = RgSearchRequest(
      directory: '/data/rootfs/root',
      query: 'needle',
      searchNames: true,
      searchContent: true,
      fileTypes: ['.dart'],
      skipDirs: ['node_modules', '.git'],
      maxResults: 50,
      useRegex: true,
      maxMatchesPerFile: 3,
      maxFileBytes: 1024,
    );
    expect(request.toJson(), {
      'directory': '/data/rootfs/root',
      'query': 'needle',
      'searchNames': true,
      'searchContent': true,
      'fileTypes': ['.dart'],
      'skipDirs': ['node_modules', '.git'],
      'maxResults': 50,
      'useRegex': true,
      'maxMatchesPerFile': 3,
      'maxFileBytes': 1024,
    });
  });

  test('RgSearchResponse parses hits with matches', () {
    final response = RgSearchResponse.fromJson(
      jsonDecode('''
{
  "ok": true,
  "error": "",
  "truncated": true,
  "hits": [
    {
      "path": "/data/rootfs/root/a.txt",
      "isDir": false,
      "size": 28,
      "mtimeMs": 1700000000000,
      "matchCount": 2,
      "matches": [
        {"lineNumber": 1, "line": "hello World"},
        {"lineNumber": 3, "line": "world again"}
      ]
    },
    {
      "path": "/data/rootfs/root/dir",
      "isDir": true,
      "size": 0,
      "mtimeMs": 0
    }
  ]
}
''')
          as Map<String, dynamic>,
    );
    expect(response.ok, isTrue);
    expect(response.truncated, isTrue);
    expect(response.hits, hasLength(2));
    final file = response.hits[0];
    expect(file.path, '/data/rootfs/root/a.txt');
    expect(file.matchCount, 2);
    expect(file.matches.map((m) => m.lineNumber), [1, 3]);
    expect(file.matches[0].line, 'hello World');
    final dir = response.hits[1];
    expect(dir.isDir, isTrue);
    expect(dir.matchCount, isNull);
    expect(dir.matches, isEmpty);
  });

  test('RgSearchResponse tolerates missing fields', () {
    final response = RgSearchResponse.fromJson(
      jsonDecode('{"ok": false, "error": "boom"}') as Map<String, dynamic>,
    );
    expect(response.ok, isFalse);
    expect(response.error, 'boom');
    expect(response.hits, isEmpty);
    expect(response.truncated, isFalse);
  });
}
