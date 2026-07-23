import '../models/browser_exception.dart';

/// 可访问名称计算的页内回退实现（对齐 accname 顺序：aria-labelledby →
/// aria-label → label → alt → 内容文本 → placeholder → title → value/name）。
/// 快照运行后优先复用 `window.__aetherNameOf`（dom_snapshot.js 暴露的
/// 同一份实现），保证快照展示名 ≡ role: 定位名；未快照时用本回退。
/// run_helpers.js 中有一份语义相同的副本，单测锁两侧同步。
const String kAccessibleNameFallbackJs = '''
(el) => {
  const t = (s) => (s == null ? '' : String(s).replace(/\\s+/g, ' ').trim());
  const ids = el.getAttribute('aria-labelledby');
  if (ids) {
    const byIds = t(ids.split(/\\s+/).map((id) => {
      const n = document.getElementById(id);
      return n ? n.textContent || '' : '';
    }).join(' '));
    if (byIds) return byIds;
  }
  return t(el.getAttribute('aria-label')) ||
      t(el.labels && el.labels.length ? el.labels[0].textContent : '') ||
      t(el.getAttribute('alt')) || t(el.textContent) ||
      t(el.getAttribute('placeholder')) || t(el.getAttribute('title')) ||
      (el.tagName && el.tagName.toLowerCase() === 'input'
          ? t(el.getAttribute('value')) || t(el.getAttribute('name'))
          : '');
}''';

/// 元素定位方式（浏览器升级设计 §2.1 M4a，借鉴 ego-lite element-resolver）。
enum ElementTargetKind {
  /// `@N`——语义快照产出的编号，映射存在页面侧 `window.__aetherRefs`。
  ref,

  /// `role:名称`——按角色 + 可见名称语义定位（如 `role:button:登录`）。
  role,

  /// 原生 CSS 选择器。
  css,
}

/// 统一的元素定位目标：交互/读取类工具共用一种入参写法。
/// 解析规则：`@N` → ref；`role:xxx[:名称]` → role；其余 → CSS。
class ElementTarget {
  const ElementTarget._(this.kind, {this.ref, this.role, this.name, this.css});

  final ElementTargetKind kind;
  final int? ref;
  final String? role;
  final String? name;
  final String? css;

  static ElementTarget parse(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      throw const BrowserException(
        BrowserErrorKind.elementNotFound,
        '元素定位目标不能为空',
      );
    }
    if (input.startsWith('@')) {
      final n = int.tryParse(input.substring(1));
      if (n == null || n <= 0) {
        throw BrowserException(
          BrowserErrorKind.elementNotFound,
          '无效的元素引用 "$input"：@ 后应为快照给出的正整数编号（如 @12）',
        );
      }
      return ElementTarget._(ElementTargetKind.ref, ref: n);
    }
    if (input.startsWith('role:')) {
      final rest = input.substring(5);
      final sep = rest.indexOf(':');
      final role = sep < 0 ? rest : rest.substring(0, sep);
      final name = sep < 0 ? null : rest.substring(sep + 1);
      if (role.trim().isEmpty) {
        throw BrowserException(
          BrowserErrorKind.elementNotFound,
          '无效的语义定位 "$input"：应为 role:角色[:可见名称]（如 role:button:登录）',
        );
      }
      return ElementTarget._(
        ElementTargetKind.role,
        role: role.trim(),
        name: name?.trim().isEmpty == true ? null : name?.trim(),
      );
    }
    return ElementTarget._(ElementTargetKind.css, css: input);
  }

  /// 生成"解析到单个元素"的 JS 表达式，供 evaluateJavascript 拼装。
  /// 求值结果：元素本身（页内后续使用）；找不到为 null。
  /// ref 失效（导航后/快照过期）由调用方检查 `__aetherRefs` 判定。
  String toResolveJs() {
    switch (kind) {
      case ElementTargetKind.ref:
        return '(window.__aetherRefs || {})[$ref] && '
            '(window.__aetherRefs[$ref].isConnected ? window.__aetherRefs[$ref] : null)';
      case ElementTargetKind.css:
        return 'document.querySelector(${jsStringLiteral(css!)})';
      case ElementTargetKind.role:
        final nameJs = name == null ? 'null' : jsStringLiteral(name!);
        return '''
(() => {
  const role = ${jsStringLiteral(role!)};
  const name = $nameJs;
  const tagMap = {
    link: 'a[href]', button: 'button, input[type=submit], input[type=button], [role=button], summary',
    textbox: 'input:not([type]), input[type=text], input[type=search], input[type=email], input[type=url], input[type=tel], input[type=number], input[type=password], textarea, [role=textbox]',
    checkbox: 'input[type=checkbox], [role=checkbox]',
    radio: 'input[type=radio], [role=radio]',
    combobox: 'select, [role=combobox]',
  };
  const sel = tagMap[role] || '[role=' + JSON.stringify(role) + ']';
  const nodes = [...document.querySelectorAll(sel)];
  const visible = nodes.filter((el) => {
    const s = getComputedStyle(el);
    if (s.display === 'none' || s.visibility === 'hidden') return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  });
  if (name === null) return visible[0] ?? null;
  // 优先用快照暴露的同一份名称计算，未快照时用同语义回退：
  // 保证 snapshot 展示的 role+name 可直接用于 role:角色:名称。
  const nameOf = window.__aetherNameOf || ($kAccessibleNameFallbackJs);
  return visible.find((el) => nameOf(el) === name) ||
      visible.find((el) => nameOf(el).includes(name)) || null;
})()''';
    }
  }

  @override
  String toString() {
    switch (kind) {
      case ElementTargetKind.ref:
        return '@$ref';
      case ElementTargetKind.role:
        return name == null ? 'role:$role' : 'role:$role:$name';
      case ElementTargetKind.css:
        return css!;
    }
  }
}

/// Dart 字符串 → JS 单引号字符串字面量（转义反斜杠/引号/换行，
/// 含 JS 字面量中同样非法的 U+2028/U+2029 行分隔符）。
String jsStringLiteral(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n').replaceAll('\r', r'\r').replaceAll('\u2028', r'\u2028').replaceAll('\u2029', r'\u2029')}'";
