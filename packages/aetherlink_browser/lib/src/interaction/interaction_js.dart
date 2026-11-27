import '../snapshot/element_target.dart';

/// 交互动作的页内 JS 生成（升级设计 §2.2 M4b）：解析 + 可用性检查 +
/// 动作在**一次 evaluate**里完成，避免跨 evaluate 持有元素引用。
/// 返回值协议（字符串）：
/// - `ok`        —— 动作已执行；
/// - `notfound`  —— 元素不存在（permanent）；
/// - `stale`     —— @N ref 已失效（页面导航/快照重建，permanent）；
/// - `invisible` —— 元素存在但不可见（transient，可等待重试）；
/// - `disabled`  —— 元素存在但被禁用（transient）；
/// - `notfillable-select` / `notfillable` —— fill 的目标不是可填写控件
///   （permanent：下拉框改用 browser_select，其余换定位）；
/// - 其他        —— 动作抛出的异常消息。

/// ref 目标专用：区分 `notfound`（编号不在当前快照中）与 `stale`
/// （曾在快照中但已失效：页面导航/快照重建/元素移除/元素被复用成别的控件）。
String _resolveWithStatusJs(ElementTarget target) {
  if (target.kind == ElementTargetKind.ref) {
    return '''
      const refs = window.__aetherRefs;
      if (!refs) return 'stale';
      if (!(${target.ref} in refs)) return 'notfound';
      const el = refs[${target.ref}];
      if (!el || !el.isConnected) return 'stale';
      if (window.__aetherRefSnapshotUrl !== location.href) return 'stale';
      const ids = window.__aetherRefIds, idOf = window.__aetherRefIdentity;
      if (ids && idOf && ids[${target.ref}] !== idOf(el)) return 'stale';
    ''';
  }
  if (target.kind == ElementTargetKind.css) {
    // CSS 深度查询：主文档 + 开放 shadow root + 同源 iframe，要求唯一。
    return '''
      const __sel = ${jsStringLiteral(target.css!)};
      const __roots = [];
      const __visit = (root) => {
        __roots.push(root);
        for (const n of root.querySelectorAll('*')) {
          if (n.shadowRoot) __visit(n.shadowRoot);
          if (n.tagName === 'IFRAME') {
            try { if (n.contentDocument) __visit(n.contentDocument); } catch (_) {}
          }
        }
      };
      let __matches = [...document.querySelectorAll(__sel)];
      if (__matches.length === 0) {
        __visit(document);
        __matches = __roots.flatMap((r) => [...r.querySelectorAll(__sel)]);
      }
      if (__matches.length > 1) {
        const shown = __matches.filter((m) => {
          const r = m.getBoundingClientRect();
          return r.width > 0 && r.height > 0;
        });
        if (shown.length !== 1) return 'ambiguous';
        __matches = shown;
      }
      const el = __matches[0];
      if (!el) return 'notfound';
    ''';
  }
  return '''
      const el = ${target.toResolveJs()};
      if (!el) return 'notfound';
  ''';
}

/// 可用性 + 视口准备：不可见/禁用为 transient；需要时滚动进视口
/// （含祖先滚动容器与同源 iframe），再做命中测试判断是否被遮挡。
String _checkUsableJs() => '''
      const __view = el.ownerDocument.defaultView || window;
      const style = __view.getComputedStyle(el);
      let rect = el.getBoundingClientRect();
      if (style.display === 'none' || style.visibility === 'hidden' ||
          Number(style.opacity) === 0 || rect.width === 0 || rect.height === 0) {
        return 'invisible';
      }
      if (el.disabled || el.getAttribute('aria-disabled') === 'true') return 'disabled';
      const __abs = (node) => {
        const r = node.getBoundingClientRect();
        let x = r.x, y = r.y, v = node.ownerDocument.defaultView;
        while (v && v !== window && v.frameElement) {
          const f = v.frameElement.getBoundingClientRect();
          x += f.x + v.frameElement.clientLeft; y += f.y + v.frameElement.clientTop;
          v = v.frameElement.ownerDocument.defaultView;
        }
        return {x, y, w: r.width, h: r.height};
      };
      let __a = __abs(el);
      if (__a.y < 0 || __a.x < 0 || __a.y + __a.h > innerHeight ||
          __a.x + __a.w > innerWidth ||
          rect.top < 0 || rect.bottom > __view.innerHeight) {
        el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'instant' });
        let v = __view;
        while (v && v !== window && v.frameElement) {
          v.frameElement.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'instant' });
          v = v.frameElement.ownerDocument.defaultView;
        }
        __a = __abs(el);
      }
      const __cx = Math.max(0, Math.min(innerWidth - 1, __a.x + __a.w / 2));
      const __cy = Math.max(0, Math.min(innerHeight - 1, __a.y + __a.h / 2));
      let __hit = document.elementFromPoint(__cx, __cy), __hx = __cx, __hy = __cy;
      while (__hit) {
        if (__hit.shadowRoot) {
          const inner = __hit.shadowRoot.elementFromPoint(__hx, __hy);
          if (inner && inner !== __hit) { __hit = inner; continue; }
        }
        if (__hit.tagName === 'IFRAME') {
          try {
            const fr = __hit.getBoundingClientRect();
            const dx = fr.x + __hit.clientLeft, dy = fr.y + __hit.clientTop;
            const child = __hit.contentDocument && __hit.contentDocument.elementFromPoint(__hx - dx, __hy - dy);
            if (child) { __hx -= dx; __hy -= dy; __hit = child; continue; }
          } catch (_) {}
        }
        break;
      }
      const __inside = (n) => {
        for (let c = n; c; c = c.parentNode || c.host) if (c === el) return true;
        return false;
      };
      if (!__hit || !(__hit === el || __inside(__hit) || el.contains(__hit))) {
        return 'covered';
      }
''';

String _wrap(ElementTarget target, String actionJs) =>
    '''
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
    try { el.focus({ preventScroll: true }); } catch (_) {}
    el.click();
''');

/// 填表：原生 value setter（兼容 React 受控组件）+ input/change 事件；
/// contenteditable 走 textContent。[submit] 追加回车键事件，仍无导航
/// 时回退 form.requestSubmit()。
String buildFillJs(ElementTarget target, String text, {bool submit = false}) =>
    _wrap(target, '''
    const value = ${jsStringLiteral(text)};
    const __w = el.ownerDocument.defaultView || window;
    if (el.isContentEditable) {
      el.focus();
      el.textContent = value;
      el.dispatchEvent(new __w.InputEvent('input', { bubbles: true, inputType: 'insertText' }));
    } else {
      if (el instanceof __w.HTMLSelectElement) return 'notfillable-select';
      if (!(el instanceof __w.HTMLInputElement ||
          el instanceof __w.HTMLTextAreaElement)) {
        return 'notfillable';
      }
      if (el.readOnly) return 'notfillable';
      el.focus();
      const proto = el instanceof __w.HTMLTextAreaElement
          ? __w.HTMLTextAreaElement.prototype
          : __w.HTMLInputElement.prototype;
      const desc = Object.getOwnPropertyDescriptor(proto, 'value');
      if (desc && desc.set) desc.set.call(el, value); else el.value = value;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }
    // 记录写入目标，供稍后回读校验（框架重渲染可能把值改回去）。
    window.__aetherLastWrite = { el, value, kind: 'fill' };
    ${submit ? _submitJs() : ''}
''');

/// Enter 提交：页面自己处理了 Enter（keydown 被 preventDefault，
/// dispatchEvent 返回 false）则不再兜底 requestSubmit，避免重复提交。
String _submitJs() => '''
    const keyInit = {
      key: 'Enter', code: 'Enter', keyCode: 13,
      bubbles: true, cancelable: true,
    };
    const proceed = el.dispatchEvent(new KeyboardEvent('keydown', keyInit));
    el.dispatchEvent(new KeyboardEvent('keypress', keyInit));
    el.dispatchEvent(new KeyboardEvent('keyup', keyInit));
    if (proceed && el.form && typeof el.form.requestSubmit === 'function') {
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
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    window.__aetherLastWrite = { el, value: options[index].value, kind: 'select' };
''');

/// 写入后回读校验（下一帧执行）：返回 `ok` / `rejected`（页面把值改回去
/// 或替换了控件）/ `gone`（目标已不在页面上，通常是提交后导航）。
const String kVerifyLastWriteJs = '''
(() => {
  const w = window.__aetherLastWrite;
  window.__aetherLastWrite = null;
  if (!w) return 'ok';
  if (!w.el.isConnected) return 'gone';
  const now = w.el.isContentEditable ? w.el.textContent : w.el.value;
  return now === w.value ? 'ok' : 'rejected';
})()''';

/// waitFor 的单次探测 JS：selector 存在且可见 → true。
String buildSelectorProbeJs(ElementTarget target) =>
    '''
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
