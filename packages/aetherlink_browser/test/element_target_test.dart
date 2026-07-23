import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';

void main() {
  group('ElementTarget.parse', () {
    test('@N 解析为 ref', () {
      final t = ElementTarget.parse('@12');
      expect(t.kind, ElementTargetKind.ref);
      expect(t.ref, 12);
      expect(t.toString(), '@12');
    });

    test('@0 / @abc 无效', () {
      expect(
        () => ElementTarget.parse('@0'),
        throwsA(
          isA<BrowserException>().having(
            (e) => e.kind,
            'kind',
            BrowserErrorKind.elementNotFound,
          ),
        ),
      );
      expect(
        () => ElementTarget.parse('@abc'),
        throwsA(isA<BrowserException>()),
      );
    });

    test('role:button:登录 解析角色与名称', () {
      final t = ElementTarget.parse('role:button:登录');
      expect(t.kind, ElementTargetKind.role);
      expect(t.role, 'button');
      expect(t.name, '登录');
    });

    test('role:link 无名称', () {
      final t = ElementTarget.parse('role:link');
      expect(t.kind, ElementTargetKind.role);
      expect(t.role, 'link');
      expect(t.name, isNull);
    });

    test('role: 空角色无效', () {
      expect(
        () => ElementTarget.parse('role:'),
        throwsA(isA<BrowserException>()),
      );
    });

    test('其余输入按 CSS 选择器处理', () {
      final t = ElementTarget.parse('#main a.button');
      expect(t.kind, ElementTargetKind.css);
      expect(t.css, '#main a.button');
    });

    test('空目标无效', () {
      expect(() => ElementTarget.parse('  '), throwsA(isA<BrowserException>()));
    });
  });

  group('toResolveJs', () {
    test('ref 检查 __aetherRefs 与 isConnected', () {
      final js = ElementTarget.parse('@7').toResolveJs();
      expect(js, contains('__aetherRefs'));
      expect(js, contains('[7]'));
      expect(js, contains('isConnected'));
    });

    test('CSS 走 querySelector 并转义引号', () {
      final js = ElementTarget.parse("a[title='x']").toResolveJs();
      expect(js, contains('document.querySelector'));
      expect(js, contains(r"\'"));
    });

    test('role 生成过滤脚本', () {
      final js = ElementTarget.parse('role:button:提交').toResolveJs();
      expect(js, contains("'button'"));
      expect(js, contains("'提交'"));
      expect(js, contains('getBoundingClientRect'));
    });
  });

  test('jsStringLiteral 转义反斜杠/引号/换行', () {
    expect(
      jsStringLiteral(
        r"a\b'c"
        '\n',
      ),
      r"'a\\b\'c\n'",
    );
  });

  test('jsStringLiteral 转义 U+2028/U+2029 行分隔符（JS 字面量非法字符）', () {
    expect(jsStringLiteral('a\u2028b\u2029c'), r"'a\u2028b\u2029c'");
  });

  group('可访问名称计算三处实现同步（快照展示名 ≡ 定位名）', () {
    // accname 顺序的关键片段：三处实现都必须按同一顺序出现。
    const chain = [
      "aria-labelledby",
      "aria-label",
      "labels",
      "alt",
      "textContent",
      "placeholder",
      "title",
      "value",
    ];

    void expectChainOrder(String source, String label) {
      var from = 0;
      for (final key in chain) {
        final at = source.indexOf(key, from);
        expect(at, greaterThanOrEqualTo(0), reason: '$label 缺少或乱序：$key');
        from = at + key.length;
      }
    }

    test('element_target.dart 回退实现', () {
      expectChainOrder(kAccessibleNameFallbackJs, 'kAccessibleNameFallbackJs');
    });

    // 测试可能从仓库根或包目录运行，两处都试。
    String readAsset(String rel) {
      final local = File(rel);
      if (local.existsSync()) return local.readAsStringSync();
      return File('packages/aetherlink_browser/$rel').readAsStringSync();
    }

    test('dom_snapshot.js 与 run_helpers.js 资产实现', () {
      final snapshotJs = readAsset('assets/js/dom_snapshot.js');
      final nameOfStart = snapshotJs.indexOf('var nameOf');
      expect(nameOfStart, greaterThanOrEqualTo(0));
      expectChainOrder(
        snapshotJs.substring(
          nameOfStart,
          snapshotJs.indexOf('function stateOf', nameOfStart),
        ),
        'dom_snapshot.js nameOf',
      );
      // 快照暴露同一份实现供 role: 定位复用。
      expect(snapshotJs, contains('window.__aetherNameOf = nameOf'));

      final helpersJs = readAsset('assets/js/run_helpers.js');
      final fallbackStart = helpersJs.indexOf('const accNameFallback');
      expect(fallbackStart, greaterThanOrEqualTo(0));
      expectChainOrder(
        helpersJs.substring(
          fallbackStart,
          helpersJs.indexOf('};', fallbackStart),
        ),
        'run_helpers.js accNameFallback',
      );
      expect(helpersJs, contains('window.__aetherNameOf || accNameFallback'));
    });

    test('role 定位优先复用快照暴露的 __aetherNameOf', () {
      final js = ElementTarget.parse('role:button:提交').toResolveJs();
      expect(js, contains('window.__aetherNameOf'));
      expect(js, contains('aria-labelledby'));
    });
  });
}
