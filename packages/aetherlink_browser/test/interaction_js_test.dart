import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';

void main() {
  group('buildClickJs', () {
    test('@N 目标区分 stale 与可用性检查后点击', () {
      final js = buildClickJs(ElementTarget.parse('@3'));
      expect(js, contains('window.__aetherRefs'));
      expect(js, contains("return 'stale'"));
      expect(js, contains("return 'invisible'"));
      expect(js, contains("return 'disabled'"));
      expect(js, contains('el.click()'));
      expect(js, contains("return 'ok'"));
    });

    test('@N 编号不在快照中返回 notfound，失效才是 stale', () {
      final js = buildClickJs(ElementTarget.parse('@999'));
      expect(js, contains("if (!(999 in refs)) return 'notfound'"));
      expect(js, contains("return 'stale'"));
    });

    test('CSS 目标缺元素返回 notfound', () {
      final js = buildClickJs(ElementTarget.parse('#submit'));
      expect(js, contains('document.querySelector'));
      expect(js, contains("return 'notfound'"));
      expect(js, isNot(contains("return 'stale'")));
    });
  });

  group('buildFillJs', () {
    test('原生 value setter + input/change 事件，文本安全转义', () {
      final js = buildFillJs(ElementTarget.parse('@1'), "a'b\nc");
      expect(js, contains('Object.getOwnPropertyDescriptor'));
      expect(js, contains("new Event('input'"));
      expect(js, contains("new Event('change'"));
      expect(js, contains(r"'a\'b\nc'"));
      expect(js, isNot(contains('requestSubmit')));
    });

    test('submit=true 追加回车与表单提交回退', () {
      final js = buildFillJs(ElementTarget.parse('@1'), 'x', submit: true);
      expect(js, contains("key: 'Enter'"));
      expect(js, contains('requestSubmit'));
    });

    test('回车事件可取消：页面 preventDefault 后不再兜底提交', () {
      final js = buildFillJs(ElementTarget.parse('@1'), 'x', submit: true);
      expect(js, contains('cancelable: true'));
      expect(js, contains('const proceed = el.dispatchEvent'));
      expect(js, contains('if (proceed && el.form'));
    });

    test('select/非填写控件返回 notfillable 状态', () {
      final js = buildFillJs(ElementTarget.parse('@1'), 'x');
      expect(js, contains("return 'notfillable-select'"));
      expect(js, contains("return 'notfillable'"));
    });
  });

  group('buildSelectOptionJs', () {
    test('按 value/文本匹配并派发 change', () {
      final js = buildSelectOptionJs(ElementTarget.parse('select'), '北京');
      expect(js, contains("'北京'"));
      expect(js, contains('selectedIndex'));
      expect(js, contains("new Event('change'"));
    });
  });

  group('buildSelectorProbeJs', () {
    test('探测元素存在且可见，异常时返回 false', () {
      final js = buildSelectorProbeJs(ElementTarget.parse('role:button:登录'));
      expect(js, contains('getBoundingClientRect'));
      expect(js, contains('return false'));
    });
  });

  test('WaitForCondition.isEmpty', () {
    expect(const WaitForCondition().isEmpty, isTrue);
    expect(const WaitForCondition(selector: '@1').isEmpty, isFalse);
    expect(const WaitForCondition(urlContains: '/done').isEmpty, isFalse);
    expect(const WaitForCondition(jsPredicate: '1').isEmpty, isFalse);
  });
}
