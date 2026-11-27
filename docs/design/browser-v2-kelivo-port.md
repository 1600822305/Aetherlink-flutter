# 内置浏览器 v2：移植 kelivo 浏览器内核（重构方案）

> 状态：方案待确认。来源：kelivo master（`lib/core/services/browser/*`、`lib/features/browser/*`）。
> 直接移植代码，不加任何来源/协议注释。

## 0. 现版本为什么"用起来是屎"（读代码定位到的根因）

| # | 现象 | 根因（文件:位置） |
|---|---|---|
| 1 | 登录态不持久，重启就掉；Windows 上尤其 | `HeadlessInAppWebView` 没传 `WebViewEnvironment(userDataFolder)`，没有固定 profile（browser_session.dart `_ensureWebView`） |
| 2 | 打开共驾页后页面弹 alert/confirm 就卡死，后续全部超时 | `CoDriveWebView` 只接了 load/nav 回调，headless 上的 `onJsAlert/Confirm/Prompt`、`onCreateWindow`、`onRenderProcessGone` 在转可见后全丢 |
| 3 | 第三方登录 / OAuth / 支付弹窗流程全挂 | `onCreateWindow` 降级成当前窗口 `loadUrl` 并 `return false`，`window.opener` 关系断了 |
| 4 | open 慢、重站点经常"加载超时" | 判定条件是 `readyState=='complete'`（等全部图片/字体/广告），没有 commit / DOMContentLoaded 阶段 |
| 5 | 每次点击都要干等 1.2~4s，还经常误判导航/结果丢失 | `_resolveNavigation` 靠轮询 URL + 宽限期猜导航；没有引擎级导航事件 |
| 6 | 点了没反应 / 点错 | 点击前不 scrollIntoView、不做遮挡检测；`@N` 不校验元素身份，不穿透 shadow DOM / iframe |
| 7 | 网站识别为机器人、布局奇怪 | 固定 1024×1536 的无头尺寸、默认 UA，不可见时页面 visibility=hidden |
| 8 | 多会话互相踩 | 全局单 WebView 串行，`session` 是模型随便传的字符串，不按对话隔离 |
| 9 | Agent 模式里每次 click/input 都弹审批，跑不动 | `kBrowserInteractiveTools` 一律走审批门 |
| 10 | 超时之后模型盲目重试，把表单提交两次 | 超时没有"结果未知→必须先观察"的约束 |
| 11 | 每次 read 都很慢 | 每次重新注入 2786 行 readability.js |
| 12 | 模型还得先加载 `builtin-browser` 延迟工具组，11 个工具名，常用错 | 工具面太碎 |

结论：问题不在工具"功能少"，而在**引擎层**（profile、回调、加载阶段、弹窗、可见性）和**执行纪律**（导航判定、超时、并发）。kelivo 恰好把这两层做扎实了，所以按层整体替换，只保留我们自己更好的部分。

## 1. 保留 / 替换 / 新增

**保留（我们的长处）**
- `UrlPolicy` + `private_networks` SSRF 防护 → 接到新引擎 `shouldOverrideUrlLoading` / `navigate` 入口。
- `wrapUntrustedWebContent` nonce 包裹 → 工具结果层继续用。
- `readability.js` → 作为 `extract(format: markdown)` 的实现，只在每个文档注入一次（缓存在 `window`）。
- 主工程接入点：`McpToolResult`、审批门、事件流 `tool_row.dart`、Ask/Plan 只读集。

**整体替换为 kelivo 实现**
- `HeadlessBrowserSession` → `BrowserEngine` 接口 + `NativeBrowserEngine`（headless 启动→转可见同一实例、全套回调、加载阶段、对话框、下载、崩溃恢复、Windows 固定 WebView2 profile）。
- `BrowserSessionManager` → `BrowserService`（对话→标签页归属、每对话 ≤3 tab、引擎池 LRU、agent 动作队列 + Zone 守卫、超时 outcome_unknown + 强制先观察、真正的人工接管暂停、state.json 持久化）。
- `dom_snapshot.js` / `interaction_js.dart` / `run_helpers.js` / `element_target.dart` → `BrowserAutomationScript`（ref 身份校验、shadow/iframe 穿透、scrollIntoView + 遮挡检测、type 回读校验、select_option、press、scroll、wait_for）。
- `CoDriveWebView` / `BrowserCoDrivePage` → 完整浏览器页（多 tab、地址栏、前进后退、查找、接管/交还按钮）。

**新增**
- 聊天/智能体事件流里的浏览器步骤卡片（缩略图 + 点开到对应 tab）。
- 书签 / 历史 / 下载（P3，可后做）。

## 2. 目标结构

```
packages/aetherlink_browser/lib/src/
  engine/browser_engine.dart              ← kelivo browser_engine.dart
  engine/native_browser_engine.dart       ← kelivo browser_native_engine.dart（去掉 workspace app 部分，P3 再补）
  engine/windows_environment.dart         ← kelivo browser_windows_environment.dart
  engine/scroll_observer*.dart / viewport_anchor.dart
  service/browser_service.dart            ← kelivo browser_service.dart（去掉 l10n/provider 依赖）
  service/browser_store.dart              ← state.json 持久化
  service/browser_failure.dart            ← 合并现有 BrowserException
  automation/browser_automation_script.dart
  automation/readability.dart             ← 复用 assets/js/readability.js
  security/url_policy.dart, private_networks.dart（保留）
  models/browser_models.dart              ← BrowserTab / BrowserSettings / pause
  ui/browser_viewport.dart                ← _BrowserViewHost（挂载/可见性同步）
lib/shared/mcp_tools/browser/browser_tool.dart   ← 重写：工具定义 + 分发 + 结果适配
lib/features/browser/presentation/...            ← 浏览器页、tab 条、步骤卡片
```

kelivo 依赖到的外部件需要替换的：`ToolCallCancellation`（→ 用我们 agent 引擎的取消令牌适配）、`AppLocalizations`（→ 直接中文常量）、`AppDirectories`（→ path_provider）、`BrowserWorkspaceResources`（P3）。

## 3. 工具面（模型可见）

改为**单一 `browser` 工具 + action**，并默认常驻（不再放延迟组）：

`open / extract / snapshot / screenshot / click / type / select_option / press / scroll / wait / back / forward / reload / evaluate / new_tab / switch_tab / close_tab / list_tabs / hand_off`

- `extract` 默认 markdown（Readability），`snapshot` 返回可交互元素 ref + 前 4000 字正文。
- 截图图片按现有多模态约束（§14.4：图片不进 tool turn）走我们已有的 imagePath 通道。
- 审批策略（可配置）：
  - Ask/Plan：只读 action（open/extract/snapshot/screenshot/wait/list_tabs/back/forward/reload）。
  - Code/Auto：默认**不审批**；只对 `evaluate` 和"疑似提交"的 click（按钮 type=submit / 表单内最后一步）审批，设置里可改成全部审批或全部放行。
- 兼容：旧工具名 `browser_open` 等在分发层映射到新 action 一个版本，`builtin_skills/browser_skill.dart` 重写。

## 4. 实施阶段（每阶段可独立编译、跑测试、提交）

| 阶段 | 内容 | 验收 |
|---|---|---|
| P0 引擎 | 移植 BrowserEngine + NativeBrowserEngine + Windows profile；接 UrlPolicy | 单 tab：打开 github 登录→重启 app 仍登录；alert 页不卡；`window.open` 登录弹窗能完成 |
| P1 服务 | 移植 BrowserService（tab 归属、队列、超时纪律、接管、持久化） | 两个对话并行开页互不干扰；超时后 mutation 被拒直到 snapshot |
| P2 自动化 + 工具 | 移植 AutomationScript，重写 browser_tool.dart、审批、只读集、skill 文案、tool_row 映射 | 典型任务：百度搜索→点结果→提取；表单填写；shadow DOM 站点点击 |
| P3 UI | 浏览器页替换共驾页：多 tab、地址栏、接管/交还、步骤卡片 | 用户中途接管登录/验证码后交还，agent 继续 |
| P4 可选 | 书签/历史/下载、kelivo:// 工作区页面、find-in-page | — |

旧实现（`session/`、`interaction/`、`snapshot/`、`codrive/`）在 P2 完成后删除，对应测试一并替换。

## 5. 风险

- kelivo 用的是它 fork 在 `dependencies/` 里的 `flutter_inappwebview_windows/macos/ios/android`（改了 WebView2 文档保留、截图尺寸等）。**P0 先用上游 6.1.5 跑；若 Windows 上 headless→可见切换或截图有问题，再把它的 fork 拷进 `packages/` 并 dependency_overrides。**
- 移动端低内存杀渲染进程：沿用 kelivo 的 `rendererTerminated` 恢复 + liveViewLimit（移动 2、桌面 4）。
- 我无法在你机器上运行 `flutter analyze/test`，每阶段写完需要你跑一次并把报错贴给我。
