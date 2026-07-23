import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// 内置 skill：内置浏览器（@aether/browser）的完整用法。
/// 不用浏览器时上下文里只占一行描述，按需加载省 token
/// （对齐 ego-lite SKILL.md 模式）。
const Skill kBrowserSkill = Skill(
  id: 'builtin-browser',
  name: '内置浏览器',
  description: '内置浏览器工具（@aether/browser）的完整用法：fetch 与 browser '
      '的选择、语义快照与 @N 定位、交互与等待纪律、browser_run 批量脚本',
  emoji: '🌏',
  tags: ['浏览器', '网页', '自动化'],
  source: SkillSource.builtin,
  version: '1.1.0',
  author: 'AetherLink',
  enabled: true,
  content: '''
## 何时用浏览器

- 静态页面/API/文档：优先用 `fetch`——更快更省。
- 只有 JS 渲染页面（SPA、动态加载）、需要登录态/cookies、需要交互
  （点击/填表/搜索）时才升级到 browser 工具。
- browser 会话在多次调用间保留（cookies/登录态不丢失）。

## 标准工作流

1. `browser_open(url)` 打开页面（返回标题 + 首屏预览）。
2. `browser_snapshot_dom` 看语义快照：标题结构 + 可见交互元素，每个元素
   带 `@N` 编号、角色、名称、状态。比截图省 token，优先用它而非截图。
3. 用 `@N` 定位交互：`browser_click(target: "@3")` /
   `browser_input(target: "@2", text: "...", submit: true)`。
   定位优先级（按可靠度）：`@N` 最稳 > `role:角色:名称`（名称以
   snapshot 展示为准）> CSS（可用但失败时立即改 @N，不要反复试）。
4. **@N 生命周期**：页面导航或重新快照后旧编号一律失效，交互结果里
   会提示；失效后重新 `browser_snapshot_dom`。
5. 只在需要视觉理解（布局/图表/验证渲染）时用 `browser_snapshot` 截图；
   验证“是否写上字/是否勾选”用 snapshot_dom 的 value/checked，
   比截图省且更准。

## 先等待，再动作，后验证

- 动态页面点击前用 `browser_wait(selector: ...)` 等元素出现，
  不要盲目重试点击。selector 必须来自真实 snapshot/DOM，不要凭
  常识猜控件类型（如猜 `input[type=submit]` 而实际是 `button`）。
- click/input 返回"是否触发导航 + 当前标题/URL"——每步动作后核对
  这个结果再走下一步，不要假设动作已生效。
- **硬规则**：动作后以“当前 URL”为准——URL 相对动作前变了就是
  已导航，必须重新 `browser_snapshot_dom`，不要只信导航布尔。
- `browser_wait` 超时返回"未成立"而非报错：把它当分支条件用
  （成立→继续；未成立→重新快照换策略）。

## browser_run：一次调用完成多步

页内多步"读→判→点→等→验"用 `browser_run` 一段脚本完成，比逐个调用
单步工具更快更省 token。脚本内可用 `aether` 助手（都是页内操作）：

```
browser_run(script: `
  const rows = [...document.querySelectorAll('article')].map(a => ({
    title: a.querySelector('h2')?.innerText,
    href: a.querySelector('a')?.href,
  }));
  const hit = rows.find(r => r.title?.includes('Flutter'));
  if (!hit) return { rows };
  await aether.fill('@2', 'Flutter');           // 先 snapshot 拿 @N
  await aether.press('Enter');
  const ok = await aether.waitFor({ selector: '.results', timeoutMs: 8000 });
  const v = aether.read('@2');                   // 控件返回 value
  return { ok, v, count: document.querySelectorAll('.result').length };
`)
```

- 纪律：先把可预测的观察/动作/验证**编码进一段脚本**再调用，
  不要一步一调；`return` 只带结论数据，不要整页 HTML。
- 动作触发页面导航会中断脚本——跨页任务拆成多次调用
  （脚本走到导航为止，导航后重新快照再继续）。
- `aether.waitFor` 超时返回 false 不抛异常，用返回值分支。
- 校验输入是否写入：`aether.read('@N')` 对 input/textarea/select
  返回 value；`aether.query('@N')` 返回
  `{ tag, name, value?, checked?, ... }` 元数据，可直接断言。

## 表单工作流

1. open → snapshot_dom（确认 textbox/radio/checkbox/button 的 @N
   与 checked/value）。
2. input/click 用 @N；再 snapshot 或 run 内 `aether.read/query` 校验。
3. click 提交按钮；若 URL 变 → 重新 snapshot/read。
4. 提交控件以 snapshot 的 role/name 为准，不要假设是
   `input[type=submit]`。

## 多会话与人机共驾

- 工具的 `session` 参数：不同 id 是独立浏览器窗口（登录态/cookie
  全局共享），并行任务用不同 id 互不干扰；缺省共用 default。
- 遇到登录、验证码、滑块等自己搞不定的环节：`browser_hand_off`
  （带 note 说明要用户做什么）交给用户在「浏览共驾」页面亲自操作，
  完成后 `browser_take_over` 收回继续。
- 交接期间对该会话的工具调用会被拒绝（userControlled）——这是
  硬停止，**不要重试绕过**；收回后旧 @N 已不可信，先重新快照。

## 省 token 纪律

- 结果只要结论：browser_read 用 selector/分块，browser_run 用 return
  精简数据；避免重复快照同一未变化的页面。
- 失败换思路顺序：①重新 snapshot_dom（@N 可能已失效）→
  ②换定位方式（CSS 失败立即改 @N）→ ③核对 URL 是否已变
  （静默导航）→ ④run 内用 `document.querySelector` 探活 →
  ⑤连续 2-3 次仍失败再问用户；不要反复重试同一操作。''',
);
