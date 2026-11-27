import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/terminal_icon_font.dart';

Uint8List _fakeTtf([int size = 200 * 1024]) {
  final b = Uint8List(size);
  b.setAll(0, [0x00, 0x01, 0x00, 0x00]);
  return b;
}

void main() {
  test('isTrueTypeFont：认 TrueType / OTTO 头，拒 HTML 错误页与过小文件', () {
    expect(isTrueTypeFont(_fakeTtf()), isTrue);
    final otto = _fakeTtf()..setAll(0, 'OTTO'.codeUnits);
    expect(isTrueTypeFont(otto), isTrue);
    final html = _fakeTtf()..setAll(0, '<!DO'.codeUnits);
    expect(isTrueTypeFont(html), isFalse);
    expect(isTrueTypeFont(_fakeTtf(1024)), isFalse);
  });

  test('extractTerminalIconFont：从发布 zip 里取出 Mono 版 ttf', () {
    final font = _fakeTtf();
    final archive = Archive()
      ..addFile(ArchiveFile('README.md', 3, 'hi!'.codeUnits))
      ..addFile(ArchiveFile('SymbolsNerdFont-Regular.ttf', 4, [1, 2, 3, 4]))
      ..addFile(
        ArchiveFile('SymbolsNerdFontMono-Regular.ttf', font.length, font),
      );
    final zip = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final out = extractTerminalIconFont(zip);
    expect(out, isNotNull);
    expect(out!.length, font.length);
    expect(isTrueTypeFont(out), isTrue);
  });

  test('extractTerminalIconFont：非 zip / 缺文件返回 null', () {
    expect(extractTerminalIconFont(Uint8List.fromList([1, 2, 3])), isNull);
    final archive = Archive()..addFile(ArchiveFile('a.txt', 1, [65]));
    expect(
      extractTerminalIconFont(Uint8List.fromList(ZipEncoder().encode(archive)!)),
      isNull,
    );
  });

  test('下载源：jsDelivr 优先，GitHub Release 兜底', () {
    expect(kTerminalIconFontUrls.first, contains('cdn.jsdelivr.net'));
    expect(kTerminalIconFontUrls.last, endsWith('.zip'));
  });
}
