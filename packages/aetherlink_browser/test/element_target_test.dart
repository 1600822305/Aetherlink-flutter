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
        throwsA(isA<BrowserException>().having(
          (e) => e.kind,
          'kind',
          BrowserErrorKind.elementNotFound,
        )),
      );
      expect(() => ElementTarget.parse('@abc'), throwsA(isA<BrowserException>()));
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
      expect(() => ElementTarget.parse('role:'), throwsA(isA<BrowserException>()));
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
    expect(jsStringLiteral(r"a\b'c" '\n'), r"'a\\b\'c\n'");
  });
}
