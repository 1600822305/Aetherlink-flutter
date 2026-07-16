// Markdown 预览：相对路径图片解析（POSIX 路径 join/归一化、opaque 路径跳过）。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/markdown_preview.dart';

void main() {
  group('resolveMarkdownImagePath', () {
    test('resolves a sibling-relative src', () {
      expect(
        resolveMarkdownImagePath('/proj/docs/readme.md', 'images/a.png'),
        '/proj/docs/images/a.png',
      );
    });

    test('resolves ./ and ../ segments', () {
      expect(
        resolveMarkdownImagePath('/proj/docs/readme.md', './a.png'),
        '/proj/docs/a.png',
      );
      expect(
        resolveMarkdownImagePath('/proj/docs/readme.md', '../assets/a.png'),
        '/proj/assets/a.png',
      );
    });

    test('keeps absolute srcs as-is (normalized)', () {
      expect(
        resolveMarkdownImagePath('/proj/readme.md', '/proj/img/./b.png'),
        '/proj/img/b.png',
      );
    });

    test('strips ?query and #fragment suffixes', () {
      expect(
        resolveMarkdownImagePath('/p/r.md', 'a.png?raw=true'),
        '/p/a.png',
      );
      expect(resolveMarkdownImagePath('/p/r.md', 'a.png#x'), '/p/a.png');
    });

    test('returns null for http(s)/data srcs', () {
      expect(
        resolveMarkdownImagePath('/p/r.md', 'https://x.com/a.png'),
        isNull,
      );
      expect(
        resolveMarkdownImagePath('/p/r.md', 'HTTP://x.com/a.png'),
        isNull,
      );
      expect(resolveMarkdownImagePath('/p/r.md', 'data:image/png;base64,AA'),
          isNull);
    });

    test('returns null for opaque (SAF content://) md paths', () {
      expect(
        resolveMarkdownImagePath(
          'content://com.android.externalstorage.documents/tree/x/document/y',
          'a.png',
        ),
        isNull,
      );
    });

    test('returns null when ../ escapes the root or src is empty', () {
      expect(resolveMarkdownImagePath('/r.md', '../../a.png'), isNull);
      expect(resolveMarkdownImagePath('/p/r.md', '   '), isNull);
    });
  });
}
