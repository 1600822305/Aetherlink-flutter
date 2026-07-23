import '../snapshot/element_target.dart';

/// 交互动作的页内 JS 生成（升级设计 §2.2 M4b）：解析 + 可用性检查 +
/// 动作在**一次 evaluate**里完成，避免跨 evaluate 持有元素引用。
/// 返回值协议（字符串）：
/// - `ok`        —— 动作已执行；
/// - `notfound`  —— 元素不存在（permanent）；
/// - `stale`     —— @N ref 已失效（页面导航/快照重建，permanent）；
/// - `invisible` —— 元素存在但不可见（transient，可等待重试）；
/// - `disabled`  —— 元素存在但被禁用（transient）；
/// - 其他        —— 动作抛出的异常消息。

/// ref 目标专用：区分 `notfound`（从未有映射）与 `stale`（映射被重建）。
String _resolveWithStatusJs(ElementTarget target) {
  if (target.kind == ElementTargetKind.ref) {
    return '''
      const refs = window.__aetherRefs;
      if (!refs) return 'stale';
      const el = refs[${target.ref}];
      if (!el || !el.isConnected) return 'stale';
    ''';
  }
  return '''
      const el = ${target.toResolveJs()};
      if (!el) return 'notfound';
  ''';
}

String _checkUsableJs() => '''
      const style = getComputedStyle(el);
      const rect = el.getBoundingClientRect();
      if (style.display === 'none' || style.visibility === 'hidden' ||
          rect.width === 0 || rect.height === 0) {
        return 'invisible';
      }
      if (el.disabled) return 'disabled';
      el.scrollIntoView({ block: 'center', inline: 'center' });
''';

String _wrap(ElementTarget target, String actionJs) => '''
(() => {
  try {
${_resolveWithStatusJs(target)}
${_checkUsableJs()}
$actionJs
    return 'ok';
  } catch (e) {
    return 'error: ' + (e && e.message ? e.message : String(e));
  }
})()''';

/// 点击。
String buildClickJs(ElementTarget target) => _wrap(target, '''
    el.click();
''');

/// 填表：原生 value setter（兼容 React 受控组件）+ input/change 事件；
/// contenteditable 走 textContent。[submit] 追加回车键事件，仍无导航
/// 时回退 form.requestSubmit()。
String buildFillJs(ElementTarget target, String text, {bool submit = false}) =>
    _wrap(target, '''
    const value = ${jsStringLiteral(text)};
    if (el.isContentEditable) {
      el.focus();
      el.textContent = value;
      el.dispatchEvent(new InputEvent('input', { bubbles: true }));
    } else {
      el.focus();
      const proto = el instanceof HTMLTextAreaElement
          ? HTMLTextAreaElement.prototype
          : HTMLInputElement.prototype;
      const desc = Object.getOwnPropertyDescriptor(proto, 'value');
      if (desc && desc.set) desc.set.call(el, value); else el.value = value;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }
    ${submit ? _submitJs() : ''}
''');

String _submitJs() => '''
    const keyInit = { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true };
    el.dispatchEvent(new KeyboardEvent('keydown', keyInit));
    el.dispatchEvent(new KeyboardEvent('keypress', keyInit));
    el.dispatchEvent(new KeyboardEvent('keyup', keyInit));
    if (el.form && typeof el.form.requestSubmit === 'function') {
      setTimeout(() => {
        if (el.isConnected) el.form.requestSubmit();
      }, 100);
    }
''';

/// 下拉选择：按 value 精确匹配，其次按可见文本精确/包含匹配。
String buildSelectOptionJs(ElementTarget target, String value) =>
    _wrap(target, '''
    const wanted = ${jsStringLiteral(value)};
    const options = [...el.options || []];
    let index = options.findIndex((o) => o.value === wanted);
    if (index < 0) {
      index = options.findIndex((o) => (o.textContent || '').trim() === wanted);
    }
    if (index < 0) {
      index = options.findIndex((o) => (o.textContent || '').includes(wanted));
    }
    if (index < 0) return 'error: 没有匹配的选项 ' + JSON.stringify(wanted);
    el.selectedIndex = index;
    el.dispatchEvent(new Event('change', { bubbles: true }));
''');

/// waitFor 的单次探测 JS：selector 存在且可见 → true。
String buildSelectorProbeJs(ElementTarget target) => '''
(() => {
  try {
    const el = ${target.toResolveJs()};
    if (!el) return false;
    const style = getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' &&
        rect.width > 0 && rect.height > 0;
  } catch (e) {
    return false;
  }
})()''';
