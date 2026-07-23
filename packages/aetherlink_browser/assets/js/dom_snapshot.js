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

  function nameOf(el) {
    var aria = el.getAttribute('aria-label');
    if (aria) return aria;
    var labelledBy = el.getAttribute('aria-labelledby');
    if (labelledBy) {
      var parts = [];
      labelledBy.split(/\s+/).forEach(function (id) {
        var ref = document.getElementById(id);
        if (ref) parts.push(ref.textContent || '');
      });
      if (parts.join(' ').trim()) return parts.join(' ');
    }
    if (el.labels && el.labels.length) {
      return el.labels[0].textContent || '';
    }
    var placeholder = el.getAttribute('placeholder');
    if (placeholder) return placeholder;
    var alt = el.getAttribute('alt');
    if (alt) return alt;
    var text = el.textContent || '';
    if (text.trim()) return text;
    var title = el.getAttribute('title');
    if (title) return title;
    if (el.tagName.toLowerCase() === 'input') {
      return el.getAttribute('value') || el.getAttribute('name') || '';
    }
    return '';
  }

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

  // 每次快照整体重建 ref 映射；旧 @N 一律失效（借 ego-lite 语义）。
  window.__aetherRefs = refs;
  window.__aetherRefSnapshotUrl = location.href;

  return lines.join('\n');
})()
