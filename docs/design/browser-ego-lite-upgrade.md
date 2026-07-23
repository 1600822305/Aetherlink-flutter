# 浏览器升级设计：借鉴 ego-lite 的架构与功能

> 状态：提案（待拍板）
> 对标：[citrolabs/ego-lite](https://github.com/citrolabs/ego-lite)（MIT，2026-07 公开）
> 前置：`docs/design/browser-tool-design.md`（M0~M3 已落地的只读三件套）
> 定位：本篇是 M4+ 的重构升级蓝图——吸收 ego-lite 已被验证的设计，
> 落到 AetherLink 的 Flutter/HeadlessInAppWebView/mcp_tools 技术栈上。

## 1. ego-lite 深度分析

### 1.1 它是什么

ego lite = 闭源 Chromium 浏览器本体 + 开源 `ego-browser` harness（Node.js
CDP 运行时）+ agent skill 包。核心卖点："人和 agent 并行共用一个浏览器"：
agent 在隔离的 Task Space 里跑，复用用户真实登录态，但不抢用户标签页。

### 1.2 架构分层（开源部分，~9.4k 行 TS）

```
stdin JS（agent 写的脚本）
  → runMain()（run.ts：把脚本包进 async 函数，helper 注入为参数）
  → helperContext()（helpers.ts：唯一的 agent 可调用面，含 help()）
  → browser-runtime.ts（CDP 传输、session attach 缓存 2s TTL、
     事件队列 10k 上限、JS dialog 跟踪）
  → driver/*（nav/pointer/keyboard/observe/waits/files/element-ops）
  → element-resolver.ts（@N ref / loc=css|role|href / xpath / raw CSS
     统一解析；失败分类 transient/permanent）
  → learning/*（per-site 经验包发现/校验/执行）
  → console.log 输出
```

关键机制：

1. **"Code base, not CLI base"**——能力包装成 JS 函数（Playwright 风格的
   `page` / `locator` / `browser` / `taskSpaces` facade），agent 一次
   heredoc 写完"观察→决策→动作→等待→验证"整条链，官方数据：复杂任务比
   逐条 CLI 快 2.5×、工具调用次数大幅减少。**这是它最核心的差异化**。
2. **快照 + ref 定位**：`page.snapshot()` 产出压缩语义快照（AX 树），
   交互元素带 `@N` 编号（N = CDP backendNodeId）；ref map 每次快照重建，
   ref 失效时自动重快照。agent 用 `@N` 或稳定 `loc=...` 直接点击/填表，
   不必猜 CSS 选择器。号称"市面最强 snapshot"（内核级定制，深嵌套 iframe
   也能处理）。
3. **Task Space 所有权模型**：`ownership: agent | agentDelegatedToUser |
   user`；`useOrCreate/switch/claim/complete(keep)/handOff/takeOver/
   waitForAgentControl` 一整套生命周期 API。用户控制中 = 硬停止，agent
   不许自动抢；登录/验证码走 handOff→用户操作→takeOver 闭环。
4. **等待与验证纪律**：wait 系列超时返回 falsy 而非抛异常；"先注册
   request/response/navigation 等待、再触发动作"；点击不等于成功，必须
   读回状态验证；错误分 transient（可重试）/permanent（换策略）。
5. **Learnings 经验沉淀**：`learnings/<site>/manifest.json + notes +
   tools`，把成功的站点操作沉淀为可复用工具，越用越快。
6. **SKILL.md 即产品**：200 行精细 prompt 工程（单次调用完成整任务、
   已满足后置条件不重放、时间窗冻结、完成判据与执行分离），质量极高。

### 1.3 与我们现状的差距对照

| 能力 | ego-lite | AetherLink M0~M3 |
| --- | --- | --- |
| 只读（open/read/截图） | ✓ | ✓（open/read/snapshot） |
| 语义快照 + ref 定位 | ✓（AX 树 + @N） | ✗（只有 Readability 正文） |
| 交互（click/fill/press…） | ✓（全套 + auto-wait） | ✗（M4 计划中） |
| 等待原语（selector/URL/function） | ✓ | ✗（只有导航级超时） |
| 批量脚本执行（一次调用多步） | ✓（核心卖点） | ✗（一工具一动作） |
| 多会话隔离 + 所有权 | ✓（Task Spaces） | ✗（单 WebView 串行） |
| 人机共驾（handOff/takeOver） | ✓ | 设计稿 §12 有构想未实现 |
| 站点经验沉淀 | ✓（learnings） | ✗ |
| SSRF/安全策略 | 浏览器本体负责 | ✓（UrlPolicy，我们更显式） |
| 错误分类 | transient/permanent | kind 枚举（无重试语义） |

## 2. 升级重构方案

### 2.0 原则

- 平台差异：ego 是桌面真 Chromium + CDP；我们是移动端
  HeadlessInAppWebView + evaluateJavascript。借"设计"不硬搬"实现"——
  CDP backendNodeId 换成注入 JS 维护的 ref 映射；heredoc 换成
  `browser_run` 工具内嵌 JS。
- 保持既有分层：能力沉 `packages/aetherlink_browser`，schema/审批/事件留
  `lib/shared/mcp_tools/browser/`。
- 每个里程碑独立可用、独立成 PR，不搞大爆炸重构。

### 2.1 M4a 语义快照 + ref 定位（地基，优先级最高）

包内注入一段"快照运行时" JS（打包资产，类似 readability.js）：

- 遍历 DOM，输出**压缩语义快照**（文本形式）：可见的交互元素
  （链接/按钮/输入/选择器/可点击元素）+ 标题/地标结构，每个交互元素带
  `@N` 编号与角色/名称/状态，例如：
  `@12 button "登录"`、`@15 textbox "邮箱" value=""`。
- ref 映射保存在页面侧（`window.__aetherRefs = {12: WeakRef(el), ...}`），
  每次快照重建；导航后失效，使用失效 ref 报 permanent 错误提示重新快照。
- 新工具 `browser_snapshot_dom`（名称待定，或并进 browser_read 的
  `format: outline`）：返回语义快照文本。截图工具保持独立（视觉路径）。
- 元素解析器（Dart 侧 `element-resolver`）统一接受：`@N` ref、CSS
  选择器、`role:名称` 语义定位，供 M4b 所有交互工具复用；失败分类
  transient（未加载完/暂时不可见→内部小重试）/ permanent（不存在/歧义→
  直接报错带候选信息）。

### 2.2 M4b 交互工具 + 等待原语

包 API 新增（全部走 M4a 解析器 + auto-wait 可见/可用）：

- `click(target)` / `fill(target, text)` / `press(key)` /
  `selectOption(target, value)` / `scroll(target?/方向)`；
- `waitFor({selector?/urlContains?/jsPredicate?, timeout})`——超时**返回
  false 不抛异常**（借 ego 语义，让上层能分支处理）；
- 点击后自动解析导航结果（等 loadStart→readyState 或静默期），返回
  `{navigated, url, title}`，避免"点了但不知道跳没跳"。

主工程接入：`browser_click` / `browser_input` / `browser_wait` 工具；
交互类接 approval gate（Auto 默认需确认，对齐 §6 决策）；Ask/Plan 只读
模式继续隐藏。

### 2.3 M4c `browser_run` 批量脚本（借"code base"核心思想）

一次工具调用执行一段受限 JS，在 WebView 页面上下文运行，注入 helper
facade（`aether.click/fill/read/waitFor/snapshot/href...`，Promise 化），
脚本内可多步"读→判→点→等→验"，`return` 值作为工具结果：

```
browser_run(script: `
  const rows = [...document.querySelectorAll('article')].map(a => ({
    title: a.querySelector('h2')?.innerText, href: a.querySelector('a')?.href
  }));
  const hit = rows.find(r => r.title?.includes('Flutter'));
  if (!hit) return {rows};
  await aether.click(hit.href ? 'a[href="'+hit.href+'"]' : null);
  await aether.waitFor({jsPredicate: 'document.readyState==="complete"'});
  return {opened: location.href, title: document.title};
`)
```

- 收益：把 ego "2.5× 提速、省 token"的核心机制搬过来——把 N 轮工具调用
  压成 1 轮，对移动端流量/延迟更敏感的场景收益更大。
- 安全：脚本跑在页面沙箱（本来就能 evaluateJavascript，无新增权限面）；
  导航仍被 shouldOverrideUrlLoading SSRF 复检拦截；执行超时沿用 §19。
  归交互类审批档。
- 工具描述里写清"预先把可预测的观察/动作/验证编码进一段脚本"，对齐
  ego SKILL.md 的"一次调用完成整任务"纪律。

### 2.4 M4d 多会话 + 人机共驾（落地设计稿 §12，借 ego 所有权模型）

- SessionManager 从"单实例忽略 sessionId"升级为**真多会话池**：
  `run(sessionId)` 按 id 建/复用独立 WebView（上限 2~3 个，LRU 回收），
  cookie 全局共享（WebView 平台特性，正好对应 ego"复用登录态"卖点）。
- 引入所有权：`agent | delegatedToUser | user`。工作台新增"浏览" tab
  挂可见 `InAppWebView`；工具层加 `browser_hand_off`（交给用户登录/过
  验证码）与 `browser_take_over`（用户确认后收回）。用户控制中 = 硬停止
  （工具返回明确错误，agent 不得重试绕过）——直接借 ego 的规则表。
- headless↔可见切换需真机验证（§12.1 遗留问题），不可行则降级为
  "共驾会话恒可见 + 后台时暂停"。

### 2.5 M4e 站点经验沉淀（后期，可选）

对齐 ego learnings：`skills/browser-learnings/<site>/`（manifest + 备注 +
脚本片段），browser_open 命中站点时把该站点的注意事项/成熟脚本注入工具
结果或系统提示。依赖 M4c 的脚本载体。可与现有知识库/技能体系整合，暂缓。

### 2.6 顺带重构（小步）

- 错误模型：`BrowserException` 加 `transient` 标志，解析/等待类失败按
  ego 语义分类，manager 对 transient 保守小重试。
- 工具描述全面对齐 ego SKILL.md 的行为纪律（一次脚本多步、先注册等待再
  触发、验证后置条件、已满足不重放），这部分是纯 prompt 工程，零代码风险
  收益高。
- §13 fetch 家族统一（browser_fetch 别名）维持原计划，与本篇无冲突。

## 3. 里程碑与建议顺序

| 里程碑 | 内容 | 规模 | 依赖 |
| --- | --- | --- | --- |
| M4a | 语义快照 + ref + 元素解析器 | 中 | 无 |
| M4b | click/fill/press/wait + 审批 | 中 | M4a |
| M4c | browser_run 批量脚本 | 中 | M4a（helper 复用解析器） |
| M4d | 多会话 + 人机共驾 tab | 大 | M4b |
| M4e | 站点经验沉淀 | 中 | M4c |

建议 M4a → M4b → M4c 三连先做（agent 能力质变），M4d 单独一轮（UI 面
大），M4e 视效果再定。
