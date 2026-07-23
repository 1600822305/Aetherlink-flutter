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

  function nameOf(el) {
    return (el.getAttribute('aria-label') || el.textContent ||
        el.getAttribute('placeholder') || el.getAttribute('title') ||
        el.getAttribute('alt') || el.value || '').replace(/\s+/g, ' ').trim();
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
        throw new Error(input + ' 引用已失效，请重新 aether.snapshot()');
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

  async function resolveUsable(target, timeoutMs) {
    const deadline = Date.now() + (timeoutMs || 5000);
    for (;;) {
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
      await sleep(200);
    }
  }

  window.__aetherMakeHelpers = () => ({
    /** 解析定位目标为元素（不等待），找不到返回 null。 */
    query: (target) => resolveOnce(target),

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
      el.focus();
      const proto = el instanceof HTMLTextAreaElement
          ? HTMLTextAreaElement.prototype
          : HTMLInputElement.prototype;
      const desc = Object.getOwnPropertyDescriptor(proto, 'value');
      if (desc && desc.set) desc.set.call(el, value); else el.value = value;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    },

    /** 向目标（缺省 activeElement）派发按键事件（如 'Enter'）。 */
    async press(key, target) {
      const el = target
          ? await resolveUsable(target)
          : (document.activeElement || document.body);
      const init = { key: key, code: key, bubbles: true };
      el.dispatchEvent(new KeyboardEvent('keydown', init));
      el.dispatchEvent(new KeyboardEvent('keypress', init));
      el.dispatchEvent(new KeyboardEvent('keyup', init));
      if (key === 'Enter' && el.form &&
          typeof el.form.requestSubmit === 'function') {
        el.form.requestSubmit();
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

    /** 读取目标元素（缺省 body）的可见文本。 */
    read(target) {
      const el = target ? resolveOnce(target) : document.body;
      if (!el) throw new Error('未找到元素 ' + JSON.stringify(target));
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
        await sleep(200);
      }
    },

    /** 短暂等待（毫秒）。 */
    sleep: sleep,
  });
})();
