# 浏览器工具审查修复方案（R5）

针对 2026-07-23 M1~M4d 升级的静态审查发现的 13 项问题，逐项给出修复方案。
方案对齐业界实现（Playwright / WAI-ARIA accname 规范 / OWASP SSRF 指南 /
提示注入防护通行做法），按"最小改动、语义一致、可单测"原则设计。

## 高严重度

### 1. role: 定位与快照 nameOf 不一致

**最佳实践**：Playwright 的 getByRole 名称匹配遵循 W3C accname 计算顺序
（aria-labelledby → aria-label → 原生 label/alt → 内容文本 → title/placeholder），
且快照展示名与定位名必须同源。

**修复**：抽取单一 nameOf 实现，三处（dom_snapshot.js 快照、element_target.dart
role 解析 JS、run_helpers.js）统一为同一顺序：
`aria-labelledby → aria-label → labels → alt → 内容文本 → placeholder → title → value/name`。
dom_snapshot.js 把 nameOf/isVisible 挂到 `window.__aetherNameOf/__aetherIsVisible`，
element_target 与 run_helpers 优先复用页内实现、无快照时内联同一份副本
（保持字符串级一致，加对照单测锁住两份源码同步）。

### 2. Enter 提交重复提交

**最佳实践**：合成键盘事件应尊重 `preventDefault`——`dispatchEvent` 返回
false 即页面已接管，不应再兜底提交（Playwright 真实按键由浏览器处理默认
行为，天然不会双提交）。

**修复**：`_submitJs` 与 run_helpers 的 `press` 统一为：keydown 的
`dispatchEvent` 返回 false（被 preventDefault）则跳过 requestSubmit；
否则延迟 100ms 后仅在 `el.isConnected` 且所在 document 未开始卸载时
requestSubmit。两处行为对齐（press 同样加 100ms 延迟，等页面自身 handler 先跑）。

### 3. runScript 超时后残留脚本继续跑

**最佳实践**：无法强杀 WebView JS 上下文时用**协作式取消**（generation
token）：每次 run 前递增代数，helper 的所有循环/延时点检查代数，
过期即抛出终止。

**修复**：`runScript` 注入 `window.__aetherRunGen = N`；run_helpers 的
`sleep/resolveUsable/waitFor` 每次轮询检查捕获的代数是否仍等于全局代数，
不等则抛 `AetherRunCancelled`。Dart 侧超时后先递增代数（一次
evaluateJavascript），再抛 scriptTimeout——残留脚本在下一个检查点自杀，
不再与后续工具调用交错。

### 4. SSRF DNS rebinding（TOCTOU）

**最佳实践**：OWASP 建议"解析一次、按 IP 连接（pin）"，但 WebView 不允许
按 IP 连接 + Host 头。可行的收窄手段：校验期 DNS 结果做短 TTL 缓存供
逐跳复检复用，保证决策一致；并把残余风险显式文档化。

**修复**：UrlPolicy 增加 host→IP 结果的 30s 缓存（validate 与逐跳
policeNavigation 用同一份结果，避免两次解析被 rebind 出不同结论）；
在 url_policy.dart 顶部注释与 docs 中明确"WebView 自行解析 DNS，
无法连接级 pin，短 TTL rebinding 存在残余风险"。私网段判定已完备，不动。

### 5. 不可信内容边界可被逃逸

**最佳实践**：提示注入隔离用**每次随机 nonce 的定界符**（OpenAI/Anthropic
通行做法），并中和内容中出现的定界符字面量。

**修复**：`wrapUntrustedWebContent` 改为
`<untrusted-web-content-{8位随机hex} src="...">`；src 做属性转义
（`"`、`<`、`>`）；正文中出现 `</untrusted-web-content` 前缀的字面量
统一替换为全角 `＜` 开头的无害形式。补单测。

## 中严重度

### 6. `_entries` 幽灵条目 / 只增不删

**修复**：handOff/takeOver/userClaim/ownershipOf 改用"只查不建"的
`_existingEntry`（handOff 不存在的会话直接报错返回，不再创建）；
`_disposeEntry` 后若条目无特殊状态（ownership==agent 且无 handOff 信息）
从 map 移除。补单测：dispose 后 sessionInfos 不残留。

### 7. 空闲回收干掉用户正看的页面

**修复**：idle timer 回调与 LRU 回收均跳过 `visibleAttached == true` 的
会话（HeadlessBrowserSession 暴露该状态，SessionFactory 产物做类型探测，
接口加 `bool get visibleAttached` 默认 false）。用户离开共驾页不重置
attach 状态，但此类会话仍受 maxConsecutiveFailures 重建保护，不致泄漏。

### 8. fill 用于 select / selectOption 未暴露

**最佳实践**：Playwright 的 fill 对不可填元素抛明确错误并指引 selectOption。

**修复**：
- buildFillJs 对 `<select>` 返回专用状态 `notfillable`，Dart 侧翻译为
  "目标是下拉框，请用 browser_select"；对非 input/textarea/contenteditable
  同样报明确错误。
- 新增顶层工具 `browser_select(target, value)`：接 BrowserSession.selectOption，
  进 kBrowserInteractiveTools（审批门）+ catalog schema + 确认摘要 +
  skill 文档（version 升 1.4.0）。

### 9. LRU 回收异步导致瞬时超限

**修复**：`_evictIfNeeded` 返回被回收条目的 dispose Future，`run()` 把
"等待回收完成"串进新会话首个动作之前（挂在新条目 queue 头），保证存活
WebView 数不超过 maxSessions。

## 低严重度

### 10. UTF-16 切片切断代理对

**修复**：browser_read 分块与 open 预览截断处，若切点落在代理对中间则
回退 1 个码元；start_index 同理前移。不引依赖，两行边界函数 + 单测。

### 11. jsStringLiteral 未转义 U+2028/2029

**修复**：补 `\u2028/\u2029` 转义；run_helpers 侧无需改（值经
jsStringLiteral 注入）。补单测。

### 12. hash-only 变化误判导航

**修复**：`_resolveNavigation` 的 URL 兑底比较改为忽略 fragment；
fragment-only 变化返回 navigated=false 但在结果文本注明"URL 锚点已变化"。
onLoadStart 触发的真导航路径不受影响（hash 变化不触发 onLoadStart）。

### 13. iframe 盲区

**范围裁剪**：完整跨 frame 定位改动大、收益不确定，本轮只做：
dom_snapshot.js 对可见 iframe 输出一行
`[iframe src=... 内容未收录]`；skill「已知限制」补充说明。
完整支持另立设计（可后续借鉴 Playwright frame locator）。

## 验证

- 包内单测：nameOf 一致性对照、边界 nonce、UTF-16 切块、jsStringLiteral、
  session_manager（幽灵条目/超限/visibleAttached 跳过回收）、
  interaction_js（notfillable/preventDefault 分支为字符串断言）。
- `flutter test packages/aetherlink_browser`、
  `flutter test test/shared/mcp_tools/`；
  `flutter analyze` 仅改动文件。
- skill 正文改动 → version 1.3.0 → 1.4.0。
