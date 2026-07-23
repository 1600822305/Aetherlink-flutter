// browser_run 的页内 helper facade（升级设计 §2.3 M4c，借鉴 ego-lite
// "code base" 思想）：一次工具调用执行一段脚本，脚本内通过 `aether`
// 多步"读→判→点→等→验"。定位语义与包侧 ElementTarget 保持一致
// （@N / role:角色:名称 / CSS）。所有动作 Promise 化。
(() => {
  'use strict';

  const ROLE_SELECTOR = {
    link: 'a[href]',
    button:
      'button, input[type=submit], input[type=button], [role=button], summary',
    textbox:
      'input:not([type]), input[type=text], input[type=search], ' +
      'input[type=email], input[type=url], input[type=tel], ' +
      'input[type=number], input[type=password], textarea, [role=textbox]',
    checkbox: 'input[type=checkbox], [role=checkbox]',
    radio: 'input[type=radio], [role=radio]',
    combobox: 'select, [role=combobox]',
  };

  function isVisible(el) {
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') return false;
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  // 可访问名称计算：优先复用快照暴露的同一份实现，未快照时用同语义
  // 回退（与 element_target.dart 的 kAccessibleNameFallbackJs 保持同步，
  // 单测锁两侧），保证 snapshot 展示的 role+name 可直接用于 role:角色:名称。
  const accNameFallback = (el) => {
    const t = (s) => (s == null ? '' : String(s).replace(/\s+/g, ' ').trim());
    const ids = el.getAttribute('aria-labelledby');
    if (ids) {
      const byIds = t(ids.split(/\s+/).map((id) => {
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
  };

  function nameOf(el) {
    return (window.__aetherNameOf || accNameFallback)(el);
  }

  function resolveOnce(target) {
    if (typeof target !== 'string' || !target.trim()) {
      throw new Error('元素定位目标不能为空');
    }
    const input = target.trim();
    if (input.startsWith('@')) {
      const n = parseInt(input.slice(1), 10);
      if (!Number.isInteger(n) || n <= 0) {
        throw new Error('无效的元素引用 ' + JSON.stringify(input));
      }
      const refs = window.__aetherRefs;
      if (!refs || !refs[n] || !refs[n].isConnected) {
        throw new Error(input + ' 引用已失效：可先 aether.snapshot() 重建，或改用 role:/CSS 定位');
      }
      return refs[n];
    }
    if (input.startsWith('role:')) {
      const rest = input.slice(5);
      const sep = rest.indexOf(':');
      const role = (sep < 0 ? rest : rest.slice(0, sep)).trim();
      const name = sep < 0 ? null : rest.slice(sep + 1).trim() || null;
      if (!role) throw new Error('无效的语义定位 ' + JSON.stringify(input));
      const sel = ROLE_SELECTOR[role] || '[role=' + JSON.stringify(role) + ']';
      const visible = [...document.querySelectorAll(sel)].filter(isVisible);
      if (name === null) return visible[0] || null;
      return visible.find((el) => nameOf(el) === name) ||
          visible.find((el) => nameOf(el).includes(name)) || null;
    }
    return document.querySelector(input);
  }

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  // 元素元数据（供脚本断言）：控件返回 value/checked 等可用字段。
  function describe(el) {
    if (!el) return null;
    const tag = el.tagName ? el.tagName.toLowerCase() : '';
    const info = { tag: tag, name: nameOf(el) };
    if ('value' in el && typeof el.value === 'string') info.value = el.value;
    if (typeof el.checked === 'boolean') info.checked = el.checked;
    if (typeof el.disabled === 'boolean' && el.disabled) info.disabled = true;
    const href = el.getAttribute && el.getAttribute('href');
    if (href) info.href = href;
    const role = el.getAttribute && el.getAttribute('role');
    if (role) info.role = role;
    if (tag === 'select' && el.selectedOptions && el.selectedOptions[0]) {
      info.selected = (el.selectedOptions[0].textContent || '').trim();
    }
    return info;
  }

  window.__aetherMakeHelpers = () => {
  // 协作式取消（generation token）：Dart 侧每次 browser_run 前递增
  // __aetherRunGen，超时后再递增一次；残留脚本在下一个轮询/延时检查点
  // 发现代数过期即抛出异常终止，不再与后续工具调用交错。
  const gen = window.__aetherRunGen || 0;
  const ensureAlive = () => {
    if ((window.__aetherRunGen || 0) !== gen) {
      throw new Error('脚本已被取消（超时或新脚本开始）');
    }
  };
  const guardedSleep = async (ms) => {
    await sleep(ms);
    ensureAlive();
  };

  async function resolveUsable(target, timeoutMs) {
    const deadline = Date.now() + (timeoutMs || 5000);
    for (;;) {
      ensureAlive();
      const el = resolveOnce(target);
      if (el && isVisible(el) && !el.disabled) {
        el.scrollIntoView({ block: 'center', inline: 'center' });
        return el;
      }
      if (Date.now() > deadline) {
        throw new Error(
          '元素 ' + JSON.stringify(target) +
          (el ? ' 不可见或被禁用' : ' 不存在'));
      }
      await guardedSleep(200);
    }
  }

  return {
    /**
     * 解析定位目标（不等待），返回元数据对象
     * { tag, name, value?, checked?, disabled?, href?, role?, selected? }；
     * 找不到返回 null。需要元素本身用 queryElement。
     */
    query: (target) => describe(resolveOnce(target)),

    /** 解析定位目标为元素本身（不等待），找不到返回 null。 */
    queryElement: (target) => resolveOnce(target),

    /**
     * 重建 @N ref 映射并返回语义快照文本（与顶层 browser_snapshot_dom
     * 同一套逻辑）：run 内 @N 失效或页面变化后调用，旧编号一律作废。
     */
    snapshot() {
      if (typeof window.__aetherSnapshot !== 'function') {
        throw new Error('snapshot 不可用：请改用顶层 browser_snapshot_dom');
      }
      return window.__aetherSnapshot();
    },

    /** auto-wait 后点击。 */
    async click(target) {
      (await resolveUsable(target)).click();
    },

    /** auto-wait 后覆盖填入文本（原生 setter + input/change 事件）。 */
    async fill(target, text) {
      const el = await resolveUsable(target);
      const value = String(text);
      if (el.isContentEditable) {
        el.focus();
        el.textContent = value;
        el.dispatchEvent(new InputEvent('input', { bubbles: true }));
        return;
      }
      if (el instanceof HTMLSelectElement) {
        throw new Error('目标是下拉框，请用 aether.selectOption(target, value)');
      }
      if (!(el instanceof HTMLInputElement ||
          el instanceof HTMLTextAreaElement)) {
        throw new Error('目标 ' + JSON.stringify(target) +
            ' 不是可填写控件（input/textarea/contenteditable）');
      }
      el.focus();
      const proto = el instanceof HTMLTextAreaElement
          ? HTMLTextAreaElement.prototype
          : HTMLInputElement.prototype;
      const desc = Object.getOwnPropertyDescriptor(proto, 'value');
      if (desc && desc.set) desc.set.call(el, value); else el.value = value;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    },

    /**
     * 向目标（缺省 activeElement）派发按键事件（如 'Enter'）。
     * 页面自己处理了 Enter（preventDefault）则不再兜底提交，避免重复提交。
     */
    async press(key, target) {
      const el = target
          ? await resolveUsable(target)
          : (document.activeElement || document.body);
      const init = {
        key: key, code: key, keyCode: key === 'Enter' ? 13 : 0,
        bubbles: true, cancelable: true,
      };
      const proceed = el.dispatchEvent(new KeyboardEvent('keydown', init));
      el.dispatchEvent(new KeyboardEvent('keypress', init));
      el.dispatchEvent(new KeyboardEvent('keyup', init));
      if (proceed && key === 'Enter' && el.form &&
          typeof el.form.requestSubmit === 'function') {
        // 给页面自身 handler 先跑的窗口，与顶层 browser_input 对齐。
        await sleep(100);
        if (el.isConnected) el.form.requestSubmit();
      }
    },

    /** auto-wait 后选择下拉项（按 value，其次可见文本）。 */
    async selectOption(target, value) {
      const el = await resolveUsable(target);
      const wanted = String(value);
      const options = [...(el.options || [])];
      let index = options.findIndex((o) => o.value === wanted);
      if (index < 0) {
        index = options.findIndex(
            (o) => (o.textContent || '').trim() === wanted);
      }
      if (index < 0) {
        index = options.findIndex((o) => (o.textContent || '').includes(wanted));
      }
      if (index < 0) throw new Error('没有匹配的选项 ' + JSON.stringify(wanted));
      el.selectedIndex = index;
      el.dispatchEvent(new Event('change', { bubbles: true }));
    },

    /**
     * 读取目标元素（缺省 body）：input/textarea/select 返回 value，
     * 其余返回可见文本。
     */
    read(target) {
      const el = target ? resolveOnce(target) : document.body;
      if (!el) throw new Error('未找到元素 ' + JSON.stringify(target));
      const tag = el.tagName ? el.tagName.toLowerCase() : '';
      if (tag === 'input' || tag === 'textarea' || tag === 'select') {
        return String(el.value == null ? '' : el.value);
      }
      return (el.innerText || el.textContent || '').trim();
    },

    /**
     * 等待条件成立（{selector?/urlContains?/predicate?, timeoutMs?}）；
     * 超时返回 false 不抛异常。
     */
    async waitFor(cond) {
      const c = cond || {};
      const deadline = Date.now() + (c.timeoutMs || 10000);
      for (;;) {
        ensureAlive();
        let met = true;
        if (c.selector) {
          const el = resolveOnce(c.selector);
          met = !!(el && isVisible(el));
        }
        if (met && c.urlContains) met = location.href.includes(c.urlContains);
        if (met && typeof c.predicate === 'function') {
          try { met = !!(await c.predicate()); } catch (e) { met = false; }
        }
        if (met) return true;
        if (Date.now() > deadline) return false;
        await guardedSleep(200);
      }
    },

    /** 短暂等待（毫秒）；脚本被取消（超时）时抛出异常终止。 */
    sleep: guardedSleep,
  };
  };
})();
