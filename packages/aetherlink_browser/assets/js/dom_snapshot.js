// 语义快照运行时（浏览器升级设计 §2.1 M4a，借鉴 ego-lite 的 snapshot+ref）。
// 遍历可见交互元素与标题结构，产出带 @N 编号的压缩文本快照；
// ref 映射保存在 window.__aetherRefs，每次快照重建，供后续交互工具解析。
(function () {
  'use strict';

  var MAX_ELEMENTS = 300;
  var MAX_NAME = 80;
  var MAX_VALUE = 60;
  var MAX_HREF = 100;

  function truncate(s, n) {
    if (!s) return '';
    s = s.replace(/\s+/g, ' ').trim();
    return s.length > n ? s.slice(0, n) + '…' : s;
  }

  function isVisible(el) {
    if (!(el instanceof Element)) return false;
    var style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden' ||
        style.opacity === '0') {
      return false;
    }
    var rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function roleOf(el) {
    var explicit = el.getAttribute('role');
    if (explicit) return explicit;
    var tag = el.tagName.toLowerCase();
    if (tag === 'a') return el.hasAttribute('href') ? 'link' : '';
    if (tag === 'button') return 'button';
    if (tag === 'select') return 'combobox';
    if (tag === 'textarea') return 'textbox';
    if (tag === 'summary') return 'button';
    if (tag === 'input') {
      var type = (el.getAttribute('type') || 'text').toLowerCase();
      if (type === 'hidden') return '';
      if (type === 'checkbox') return 'checkbox';
      if (type === 'radio') return 'radio';
      if (type === 'submit' || type === 'button' || type === 'reset' ||
          type === 'image') {
        return 'button';
      }
      if (type === 'range') return 'slider';
      if (type === 'file') return 'filepicker';
      return 'textbox';
    }
    if (el.hasAttribute('onclick') || el.getAttribute('tabindex') === '0') {
      return 'clickable';
    }
    if (typeof el.onclick === 'function') return 'clickable';
    return '';
  }

  // 可访问名称计算（对齐 accname 顺序）。必须与 element_target.dart 的
  // kAccessibleNameFallbackJs 及 run_helpers.js 保持同一份逻辑：快照展示
  // 的名称必须能直接用于 role:角色:名称 定位。
  var nameOf = function (el) {
    var t = function (s) {
      return s == null ? '' : String(s).replace(/\s+/g, ' ').trim();
    };
    var ids = el.getAttribute('aria-labelledby');
    if (ids) {
      var byIds = t(ids.split(/\s+/).map(function (id) {
        var n = document.getElementById(id);
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
  };

  function stateOf(el) {
    var bits = [];
    if (el.disabled) bits.push('disabled');
    var tag = el.tagName.toLowerCase();
    if (tag === 'input') {
      var type = (el.getAttribute('type') || 'text').toLowerCase();
      if (type === 'checkbox' || type === 'radio') {
        bits.push(el.checked ? 'checked' : 'unchecked');
      } else if (type !== 'password') {
        bits.push('value=' + JSON.stringify(truncate(el.value, MAX_VALUE)));
      }
    } else if (tag === 'textarea') {
      bits.push('value=' + JSON.stringify(truncate(el.value, MAX_VALUE)));
    } else if (tag === 'select') {
      var opt = el.selectedOptions && el.selectedOptions[0];
      if (opt) bits.push('selected=' + JSON.stringify(truncate(opt.textContent, MAX_VALUE)));
    } else if (tag === 'a') {
      var href = el.getAttribute('href');
      if (href && href !== '#' && !href.startsWith('javascript:')) {
        bits.push('href=' + JSON.stringify(truncate(href, MAX_HREF)));
      }
    }
    return bits.join(' ');
  }

  var refs = {};
  var seq = 0;
  var lines = [];

  var title = truncate(document.title, 200);
  lines.push('页面: ' + (title || '(无标题)'));
  lines.push('URL: ' + location.href);
  lines.push('');

  var headings = document.querySelectorAll('h1, h2, h3');
  var headingLines = [];
  headings.forEach(function (h) {
    if (!isVisible(h)) return;
    if (headingLines.length >= 40) return;
    var level = parseInt(h.tagName.slice(1), 10);
    var text = truncate(h.textContent, MAX_NAME);
    if (text) headingLines.push('  '.repeat(level - 1) + '# ' + text);
  });
  if (headingLines.length) {
    lines.push('结构:');
    lines.push.apply(lines, headingLines);
    lines.push('');
  }

  var selector = 'a, button, input, select, textarea, summary, ' +
      '[role], [onclick], [tabindex="0"]';
  var candidates = document.querySelectorAll(selector);
  var elementLines = [];
  var overflow = 0;
  candidates.forEach(function (el) {
    var role = roleOf(el);
    if (!role || role === 'presentation' || role === 'none') return;
    if (!isVisible(el)) return;
    if (elementLines.length >= MAX_ELEMENTS) {
      overflow++;
      return;
    }
    seq++;
    refs[seq] = el;
    var name = truncate(nameOf(el), MAX_NAME);
    var state = stateOf(el);
    elementLines.push(
      '@' + seq + ' ' + role +
      (name ? ' ' + JSON.stringify(name) : '') +
      (state ? ' ' + state : ''));
  });
  if (elementLines.length) {
    lines.push('交互元素:');
    lines.push.apply(lines, elementLines);
    if (overflow > 0) {
      lines.push('…（还有 ' + overflow + ' 个交互元素未列出）');
    }
  } else {
    lines.push('（页面无可见交互元素）');
  }

  // iframe 盲区显式标注：快照/交互不进 frame，避免模型误以为页面空白。
  var frameLines = [];
  document.querySelectorAll('iframe').forEach(function (f) {
    if (!isVisible(f)) return;
    if (frameLines.length >= 10) return;
    var src = f.getAttribute('src') || '';
    frameLines.push('[iframe' +
        (src ? ' src=' + JSON.stringify(truncate(src, MAX_HREF)) : '') +
        ' 内容未收录，无法用 @N/role 定位其内部元素]');
  });
  if (frameLines.length) {
    lines.push('');
    lines.push.apply(lines, frameLines);
  }

  // 每次快照整体重建 ref 映射；旧 @N 一律失效（借 ego-lite 语义）。
  window.__aetherRefs = refs;
  window.__aetherRefSnapshotUrl = location.href;
  // 暴露同一份名称计算供 role: 定位复用（快照展示名 ≡ 定位名）。
  window.__aetherNameOf = nameOf;

  return lines.join('\n');
})()
