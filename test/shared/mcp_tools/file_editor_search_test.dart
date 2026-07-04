import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_search.dart';

void main() {
  group('SearchLineMatcher', () {
    test('字面量默认大小写不敏感', () {
      final m = SearchLineMatcher.tryCreate('Hello')!;
      expect(m.matches('say hello world'), isTrue);
      expect(m.matches('say HELLO'), isTrue);
      expect(m.matches('nothing'), isFalse);
    });

    test('字面量 case_sensitive 区分大小写', () {
      final m = SearchLineMatcher.tryCreate('Hello', caseSensitive: true)!;
      expect(m.matches('say Hello'), isTrue);
      expect(m.matches('say hello'), isFalse);
    });

    test('正则匹配与大小写开关', () {
      final ci = SearchLineMatcher.tryCreate(r'fo+bar', useRegex: true)!;
      expect(ci.matches('xxFOOOBARxx'), isTrue);
      final cs = SearchLineMatcher.tryCreate(r'fo+bar',
          useRegex: true, caseSensitive: true)!;
      expect(cs.matches('xxFOOOBARxx'), isFalse);
      expect(cs.matches('xxfooobarxx'), isTrue);
    });

    test('非法正则返回 null', () {
      expect(SearchLineMatcher.tryCreate('[', useRegex: true), isNull);
    });
  });

  group('globToRegExp / globHits', () {
    bool hits(String glob, {required String name, required String rel}) =>
        globHits(globToRegExp(glob)!, glob, name: name, relPath: rel);

    test('不含 / 的模式按文件名匹配', () {
      expect(hits('*.dart', name: 'a.dart', rel: 'src/a.dart'), isTrue);
      expect(hits('*.dart', name: 'a.ts', rel: 'src/a.ts'), isFalse);
      expect(hits('a?.md', name: 'a1.md', rel: 'a1.md'), isTrue);
      expect(hits('a?.md', name: 'a12.md', rel: 'a12.md'), isFalse);
    });

    test('含 / 的模式按相对路径匹配，* 不跨目录', () {
      expect(hits('src/*.dart', name: 'a.dart', rel: 'src/a.dart'), isTrue);
      expect(
        hits('src/*.dart', name: 'a.dart', rel: 'src/sub/a.dart'),
        isFalse,
      );
    });

    test('** 跨目录，**/ 匹配零层', () {
      expect(
        hits('src/**/*.dart', name: 'a.dart', rel: 'src/x/y/a.dart'),
        isTrue,
      );
      expect(
        hits('src/**/*.dart', name: 'a.dart', rel: 'src/a.dart'),
        isTrue,
      );
      expect(
        hits('src/**/*.dart', name: 'a.dart', rel: 'lib/a.dart'),
        isFalse,
      );
    });
  });

  group('relativePathOf', () {
    test('普通 POSIX 路径去前缀', () {
      expect(
        relativePathOf('/root/proj', '/root/proj/src/a.dart', 'a.dart'),
        'src/a.dart',
      );
    });

    test('SAF URI 解码后取后缀', () {
      const dir = 'content://tree/primary%3Aproj';
      const path = 'content://tree/primary%3Aproj%2Fsrc%2Fa.dart';
      expect(relativePathOf(dir, path, 'a.dart'), 'src/a.dart');
    });

    test('推不出来退回文件名', () {
      expect(relativePathOf('/x', '/y/a.dart', 'a.dart'), 'a.dart');
    });
  });

  group('findMatchingLines / countMatchingLines', () {
    const content = 'alpha\nbeta match\ngamma\ndelta match\nepsilon';
    final matcher = SearchLineMatcher.tryCreate('match')!;

    test('返回 1-based 行号与内容', () {
      final ms = findMatchingLines(content, matcher);
      expect(ms.map((m) => m.line), [2, 4]);
      expect(ms.first.text, 'beta match');
      expect(ms.first.context, isNull);
    });

    test('context_lines 带上下文窗口（含命中行）', () {
      final ms = findMatchingLines(content, matcher, contextLines: 1);
      final ctx = ms.first.context!;
      expect(ctx.map((c) => c.line), [1, 2, 3]);
      expect(ctx[0].text, 'alpha');
      // 边界不越界
      final last = findMatchingLines('match', matcher, contextLines: 3);
      expect(last.single.context!.map((c) => c.line), [1]);
    });

    test('maxMatches 上限生效', () {
      final ms = findMatchingLines(content, matcher, maxMatches: 1);
      expect(ms, hasLength(1));
    });

    test('countMatchingLines 不受条数上限约束', () {
      expect(countMatchingLines(content, matcher), 2);
      expect(countMatchingLines('none', matcher), 0);
    });

    test('超长行截断', () {
      final long = 'match${'x' * 300}';
      final ms = findMatchingLines(long, matcher);
      expect(ms.single.text.length, kMaxMatchLineChars + 1);
      expect(ms.single.text.endsWith('…'), isTrue);
    });
  });
}
