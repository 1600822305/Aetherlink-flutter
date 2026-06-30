# Aetherlink Flutter - 应用内开发者工具 (DevTools) 设计文档

> **版本**: v0.1
> **日期**: 2026-06-30
> **状态**: P0~P3 已完成（Console + 全局捕获 + 页面 + 关于页入口 + 悬浮按钮 + Network 网络面板 + Dio 收口 + Performance 性能面板），P4 待开工
> **目标**: 做一个「UI 对齐原版 Web、功能媲美 Chrome DevTools、整体比原版更强」的应用内开发者工具面板。

---

## 0. 给 AI / 新会话：先读这里（30 秒上手）

**这是什么**：在 Aetherlink Flutter App 内置一个开发者工具，包含 控制台(Console) / 网络(Network) / 性能(Performance) / 存储(Storage) / 设备(Device) 等面板，外加一个可拖拽悬浮入口。对标原版 Web 的 `/devtools` 页，但要做得更全。

**当前进度**：见本文件最后的 **§8 进度日志**。每完成一个阶段，必须回来更新 §6 状态表 + §8 日志。

**接手前必看**：
1. 本文件 §6（阶段拆分 + 状态）— 知道做到哪了。
2. 本文件 §3（参考清单）— 知道该去哪些仓库/文件抄设计。
3. 仓库根 `AGENTS.md` — 验证(`flutter analyze`)与提交/推送(Windows PowerShell)流程，**务必遵守**。

**关键背景约束**：
- 持久化用 **Drift/SQLite**（ADR-0003），不是 Hive。Storage 面板要查的是 Drift 表 + SharedPreferences。
- 网络用 **Dio ^5.9.2**，但**分散创建、无统一客户端**（这是 Network 面板的主要前置工程，见 §4.2）。
- 状态管理用 **Riverpod**（ADR-0002）。
- 图标用 **Lucide**（ADR-0009），保持与原版视觉一致。
- App 目前**几乎没有日志体系**（不像 Web 有 `createLogger`），所以 Console 面板靠「全局捕获」起步，而非「统一现有日志」（见 §4.1）。
- 已有 `packages/aetherlink_perf` 性能监控包（分线程帧时间 + 瓶颈诊断 + JSON 导出），Performance 面板直接整合它，不要重写。

---

## 1. 背景与目标

### 1.1 背景
原版 Web (AetherLink) 有一个成熟的 `/devtools` 全屏页（Console + Network）+ 两个全局悬浮层（性能监控、DevTools 入口按钮）。Flutter 版目前：
- ✅ 已有性能监控浮窗（`aetherlink_perf`），且比 Web 强。
- ⚠️ 设置里「显示开发者工具悬浮按钮」开关是**占位、非交互**。
- ❌ 没有 DevTools 页面（Console / Network 完全缺失）。

### 1.2 目标
| 维度 | 原版 Web | 本设计目标 |
|------|----------|-----------|
| 面板 | Console + Network | Console + Network + **Performance** + **Storage** + **Device/Env** |
| 数据 | 日志 / 请求 | 全量 + 检索 + 导出 + **一键导出给 AI 诊断** |
| 网络 | 普通请求列表 | + 详情抽屉(Headers/Payload/Response/Timing) + **SSE/LLM 流式渲染** + cURL 导出 |
| 入口 | 全屏页 + 悬浮按钮 | 同左，悬浮按钮复用 `aetherlink_perf` 已验证的拖拽逻辑 |
| 风格 | MUI 卡片 | 对齐 Flutter 项目现有卡片/分隔/Chip 风格 |

### 1.3 设计原则
- **UI 严格对齐原版 Flutter 项目现有风格**（卡片 `_AppearanceCard` + 细 `Divider` + Lucide Chip + 等宽字体）。
- **功能对齐 Chrome DevTools**。
- **零侵入优先**：能用全局钩子白嫖的数据，绝不逐处改业务代码。
- **独立 package**：做成 `packages/aetherlink_devtools`，仿 `aetherlink_perf`，洁净、可单测、release 可整包裁剪。

---

## 2. 总体架构

```
┌─ 采集层 Capture ───────────────────────────────────────┐
│  • LogSink           全局 logger sink → 环形缓冲(容量可配)   │
│      ← FlutterError.onError / PlatformDispatcher.onError   │
│      ← runZonedGuarded + 重写 debugPrint                    │
│  • DioDevInterceptor   注入所有 Dio → 请求/响应/计时/错误     │
│  • PerfMonitor        已存在 (aetherlink_perf)             │
└──────────────────────────┬─────────────────────────────┘
                           │ ValueListenable / Riverpod
┌─ 数据层 Store ───────────┴─────────────────────────────┐
│  • ConsoleStore / NetworkStore  环形缓冲 + 过滤索引        │
│  • 配置：preserveLog / 容量上限 / 脱敏规则 / 自动滚动        │
└──────────────────────────┬─────────────────────────────┘
┌─ UI 层 ──────────────────┴─────────────────────────────┐
│  DevToolsPage(TabBar) + 各 Panel + DevToolsFloatingButton │
└─────────────────────────────────────────────────────────┘
```

打包形态：**独立 package `packages/aetherlink_devtools`**（待最终拍板，见 §7 决策）。

---

## 3. 参考清单（接手时按需精读）

### 3.1 原版 Web 仓库：`K:\Flutterworkspace\Aetherlink-original`
| 文件 | 看什么 |
|------|--------|
| `src/pages/DevToolsPage.tsx` | 页面骨架：AppBar 操作栏、Tabs、设置弹窗、清空弹窗、选择/复制/分享逻辑 |
| `src/components/DevTools/ConsolePanel.tsx` | Console：等级过滤、搜索、context 过滤、时间戳、命令历史、选择复制 |
| `src/components/DevTools/NetworkPanel.tsx` | Network：请求列表、状态色标、详情 Accordion、复制/分享 |
| `src/components/debug/DevToolsFloatingButton.tsx` | 悬浮入口按钮：拖拽逻辑、位置持久化、点击跳转 |
| `src/components/debug/EnhancedPerformanceMonitor.tsx` | 性能浮窗（Flutter 已用 aetherlink_perf 替代，仅参考 UI） |
| `src/pages/Settings/AppearanceSettings.tsx` (≈802-905) | 「开发者工具」设置卡片：两个开关的组织方式 |
| `src/shared/services/infra/logger/logViewer.ts` | 日志数据模型（LogViewerEntry / Filter / Level） |
| `src/shared/services/network/EnhancedNetworkService.ts` | 网络数据模型（NetworkEntry / Filter）、拦截器思路 |
| `src/i18n/locales/zh-CN/devtools.json` | 文案对照 |

### 3.2 本仓库 Flutter：`K:\Flutterworkspace\aetherlink_flutter`
| 文件 | 看什么 |
|------|--------|
| `packages/aetherlink_perf/**` | **范本**：独立 package 结构、可拖拽浮窗 `PerfOverlay`、ValueNotifier 驱动、JSON 导出 |
| `lib/features/settings/presentation/mobile/appearance_settings_page.dart` (≈1035) | `_DeveloperToolsCard` / `_DevToolRow`：要把悬浮按钮开关接上；卡片风格范本 |
| `lib/features/settings/application/perf_monitor_controller.dart` | Riverpod 设置开关 controller **范本**（仿它写 DevTools 开关） |
| `lib/app/app.dart` (≈68, 150) | 浮层如何挂载（`PerfOverlayHost`）、路由如何上报 |
| `lib/app/di/memory_access.dart` (`buildLlmDio`) | Dio 工厂现状——Network 拦截器注入的关键切入点 |
| `docs/adr/0003-drift-for-persistence.md` | Storage 面板：持久化是 Drift |
| `docs/adr/0004-dio-handwritten-sse.md` | Network 面板：SSE 是手写的，流式渲染要对齐 |
| `AGENTS.md` | 验证 + 提交/推送流程（必须遵守） |

---

## 4. 关键前置与可行性

### 4.1 Console：不需要"统一日志"，用全局捕获起步
现状：App 几乎无日志、无 logger 服务。故**第一步不是统一日志**（没东西可统一），而是建采集点：

- **A（零侵入，先做）**：
  - `FlutterError.onError` → 框架/widget 异常
  - `PlatformDispatcher.instance.onError` → 未捕获异步错误
  - `runZonedGuarded` + 重写 `debugPrint` → 捕获所有 print/debugPrint
  - → Console 立刻有内容（崩溃、异常、堆栈、零散 print），不动业务代码。
- **B（结构化，后做、增量）**：引入 logger 门面 `createLogger('Context')`（level/context/结构化参数），再逐步在业务关键路径补 `logger.info(...)`。让日志"可按模块过滤分级"。

### 4.2 Network：必须统一 Dio 注入点（主要前置工程）
现状：Dio 在多处各自 `Dio(...)`（`skill_store_page`、`network_proxy_settings`、各 TTS/ASR、`buildLlmDio` 等），无单一客户端。要抓全流量两条路：
- **收口工厂（推荐）**：建 `buildAppDio()`，内部 `addAll([DioDevInterceptor()])`，逐步把各调用点改为用它。干净、可全量捕获，但要改多处。
- **注册表（快但不全）**：维护"已知 Dio 注册表"，只给主要请求加拦截器。先快后全。

### 4.3 Performance：整合现有 `aetherlink_perf`，不重写。
### 4.4 Storage：查 Drift 表 + SharedPreferences（注意脱敏 token/key）。

---

## 5. 面板设计（逐个，标注"比原版强"点）

### 5.1 Console（控制台）
- 对齐原版：等级过滤(ERROR/WARN/INFO/DEBUG/TRACE)、搜索、context 过滤、时间戳开关、选择/复制/分享、清空、自动滚动。
- **增强**：行展开看完整 stack + 结构化参数 JSON 树；按 context 分组折叠；错误计数徽标；正则搜索高亮；"复制为 AI 诊断"（带设备信息 + 最近 N 条上下文）。

### 5.2 Network（网络）
- 对齐原版：请求列表(method/url/status/耗时)、状态色标、搜索、详情。
- **增强**：详情抽屉 Headers/Payload/Response/Timing 四段 + JSON 折叠树；瀑布耗时条；状态码/大小/类型筛选；**SSE/LLM 流式逐 chunk 渲染**（杀手锏）；cURL 导出 / 复制响应体；失败重发(可选)。

### 5.3 Performance（性能）— 整合 aetherlink_perf
实时 FPS/Build/Raster 曲线、掉帧时间线、瓶颈诊断、内存、一键导出 JSON 给 AI。原版无此面板，天然领先。

### 5.4 Storage（存储）— 新增
查看/编辑 Drift 表 + SharedPreferences，仿 Chrome Application 面板。token/key 脱敏。

### 5.5 Device & Env（设备/环境）— 新增
设备型号/OS/屏幕/刷新率、App 版本/构建模式、内存、当前路由、Riverpod provider 快照。一键全量导出。

### 5.6 UI 风格要点
- 页面：`Scaffold`+`AppBar`(返回+标题+操作图标:选择/全选/复制/分享/设置/清空) + 顶部 `TabBar`(primary 选中 + 2px 指示条)。
- 复用 `_AppearanceCard` + `Divider(height:1)`；Lucide 图标；等级/状态 Chip 用 `alpha(color,.08~.1)` 底色；日志/JSON 等宽字体。
- 悬浮按钮：48px 圆形 Terminal 图标，蓝(普通)/绿(在 devtools 页)，复用 `aetherlink_perf` 拖拽逻辑 + 位置持久化。

---

## 6. 阶段拆分与状态

> 状态：⬜ 未开始 / 🟡 进行中 / ✅ 完成。每次变更同步更新此表 + §8 日志。

| 阶段 | 内容 | 状态 | 完成日期 |
|------|------|------|---------|
| **P0** | 独立 package 骨架 + `ConsoleStore` + 全局错误/print 捕获(§4.1-A) + DevToolsPage(Console tab) | ✅ | 2026-06-30 |
| **P1** | 可拖拽悬浮按钮 `DevToolsFloatingButton` + 设置开关接线(补占位项) | ✅ | 2026-06-30 |
| **P2** | `DioDevInterceptor` + 统一 Dio 工厂(§4.2) + Network 面板(含 SSE 流式) | ✅ | 2026-06-30 |
| **P3** | Performance tab（并入 aetherlink_perf） | ✅ | 2026-06-30 |
| **P4** | Storage / Device 面板 + AI 导出增强 + logger 门面(§4.1-B) | ⬜ | - |

**推荐起步**：P0（零前置依赖，立刻可用，验证整体 UI 风格）。

---

## 7. 已拍板决策（2026-06-30 定稿）

1. **抓网络流量方式 → A：收口工厂 `buildAppDio()`，分步迁移。**
   建统一工厂内置 `DioDevInterceptor`，新代码一律用它，老调用点（`skill_store_page`、`network_proxy_settings`、各 TTS/ASR、`buildLlmDio` 等）逐个迁移、每处迁完验证一次。**不在 P0 动它，放到 P2。** 理由：企业级要求全量可观测 + 横切关注点(鉴权/重试/脱敏)统一收口。
2. **打包形态 → A：独立 package `packages/aetherlink_devtools`。**
   照搬 `aetherlink_perf` 结构。理由：可裁剪不进 release 包、依赖边界清晰、可独立单测。先做单包即可，暂不拆"采集/UI"两包（避免过度设计）。
3. **入口位置 → 对齐原版：悬浮按钮 + 「关于」页开发者入口行。**
   - 在 `lib/features/settings/presentation/mobile/about_page.dart` 加一行（Terminal 图标 + "开发者工具"）跳 DevTools 页，对应原版 `AboutPage.tsx:147-155`（`PressableRow` → `navigate('/devtools')`）。
   - 外加可拖拽悬浮按钮（复用 `aetherlink_perf` 拖拽逻辑），开关接到外观→开发者工具卡片现有的占位项。

---

## 8. 进度日志

> 每完成一个阶段或重要节点，在此追加一条（日期 + 做了什么 + 关键文件 + 遗留问题）。最新在最上。

### 2026-06-30 — UI 打磨（统一 Tab 样式 + 紧凑化 + 详情段内滑动）
- **统一 Tab 样式**：DevTools 页 TabBar 此前用的是 Material 默认 primary tab（字体/样式与全 App 不一致）。现改为复刻项目统一的分段胶囊样式（`_SegmentedTabBar`：圆角容器 + 边框 + `primary@0.12` 胶囊指示条 + `isScrollable`/`TabAlignment.start` 内容自适应宽度 + `labelLarge/13/w600` + `labelPadding 8`）。因 `aetherlink_devtools` 包零依赖、不能 import `lib/`，故**在包内 1:1 复刻**而非引用（`devtools_page.dart` 用 `PreferredSize` 包裹，高 56）。
- **全页紧凑化**：Console/Network 过滤栏外边距 12/8→10/6、搜索框高 38→34、行距 6→4；日志行/请求行内边距收紧到 `10,4`/`10,6`；Performance `ListView`/卡片内边距与卡片间距收紧，卡片标题改 `labelLarge` 次级色。
- **网络详情段内滑动**：详情抽屉每段（请求头/请求体/响应头/响应体/错误）限制最大高度 260、段内独立滚动（`ConstrainedBox + Scrollbar(thumbVisibility) + SingleChildScrollView`），超长 JSON/响应体不再撑长整个抽屉；流式响应在 `didUpdateWidget` 里自动跟随到底部。
- 验证：包内 `flutter analyze` 零问题、`flutter test` 11/11。

### 2026-06-30 — 增强批次（Console / Network / Performance §5 增强项）
- **Console**（`console_store.dart` + `console_panel.dart`）：
  - 正则搜索:`ConsoleFilter.regex` + `compiledRegExp`(编译一次,无效模式匹配空并在输入框报错);搜索命中在日志行内 `Text.rich` 高亮(子/正则通用)。
  - 错误计数徽标:`ConsoleStore.levelCounts`,等级 Chip 显示 `ERROR 3` 计数。
  - 按 context 分组折叠:过滤栏「按来源分组」开关,分组视图每组可折叠、显示条数 + 错误数徽标。
- **Network**（`network_entry.dart` + `network_store.dart` + `network_panel.dart`）：
  - cURL 导出 `NetworkEntry.toCurl()`(脱敏头保持掩码,复制后需替换真实凭证)+ 详情抽屉「复制响应体 / 复制 cURL / 复制全部」三按钮。
  - 状态码/类型/大小筛选:`NetworkFilter` 加 `statusClasses`(2xx/3xx/4xx/5xx)、`onlyStream`、`minSize`;过滤栏「更多筛选」(tune 图标)展开二级行(类码 Chip + 仅流式 + 大小下拉)。
  - 瀑布耗时条:每行底部细条,宽度 ∝ 本行耗时/可见行最大耗时,按状态着色。
  - **失败重发**:经评估**不做真重发**——已脱敏鉴权头无法安全重放、包内触达不到 App 的 Dio 工厂、重发 POST 有真实副作用;cURL 导出即标准安全"重放"路径(同 Chrome DevTools)。
- **Performance**（`lib/app/devtools/performance_panel.dart`）：
  - 实时折线图:`CustomPainter` 手绘 FPS/Build/Raster 近 ~60s 曲线(零图表依赖,带预算虚线参考),面板内环形缓冲(120 样本 @2Hz)由 `live` 监听喂入。
  - 共用单例取舍:面板改为 `ConsumerStatefulWidget` 读 `perfMonitorControllerProvider`——浮窗开启时采集归浮窗驱动(面板仅观察、隐藏起停并提示),浮窗关闭时面板可独立「开始/停止采集」,且仅在「自身启动且浮窗关闭」时于 `dispose` 停止,避免泄漏与生命周期打架。
- 验证:包内 `flutter analyze` 零问题、`flutter test` 11/11;`performance_panel.dart` analyze 零问题。

### 2026-06-30 — P3 完成（Performance 性能面板，整合 aetherlink_perf）
- 新增桥接面板 `lib/app/devtools/performance_panel.dart`（`PerformancePanel implements DevToolsPanel`）：读 `PerfMonitor.instance`，展示「实时」(FPS/Build/Raster/慢帧率/RSS/图片缓存 + 瓶颈 Chip，随 `live` ~2Hz 刷新) + 「窗口汇总」(build/raster/total 的 p50/p95/p99/max、慢帧/严重/冻结、内存趋势、设备、预热、规则诊断) + 「停止采集 / 复制诊断 JSON」。`exportAsText()` 接到页面级「复制」(导出 AI 诊断 JSON)。
- **依赖归属**：面板放在主 App(组合根)而非 `aetherlink_devtools` 包内，桥接 `aetherlink_perf`，使 devtools 包保持零额外依赖；在 `main.dart` 用 `DevToolsRegistry.register(const PerformancePanel())` 注册(扩展点，紧跟 `DevToolsCapture.install()`)。Tab 顺序：控制台 / 网络 / 性能。
- **采集器共享**：与「外观→开发者工具→显示性能监控」浮窗共用 `PerfMonitor` 单例。面板未在采集时给「开始采集」按钮(显式启动，不在 initState 自动开)；停止会停掉共享采集器(已在 UI 注明，浮窗随之归零，属共享单例取舍)。不在 dispose 自动 start/stop，避免与 `app.dart` 的 `perfMonitorController` 监听打架。
- 验证：`flutter analyze lib/app/devtools/performance_panel.dart lib/main.dart` 零问题。
- 遗留/下一步：实时曲线目前是数值卡片(非折线图，避免引图表依赖)；P4 起 Storage(Drift 表 + SharedPreferences) / Device 面板 + logger 门面(§4.1-B)。

### 2026-06-30 — P2 完成（Network 网络面板 + Dio 收口）
- 包内新增 `src/network/`：
  - `network_entry.dart` — `NetworkEntry`(可变，随响应/流式逐 chunk 填充) / `NetworkStatus`(pending/success/error/cancelled) + `formatSize`/`formatDuration`(对齐原版 Web 辅助函数)。
  - `network_store.dart` — 环形缓冲(500 上限) + 过滤(`NetworkFilter`：方法/状态/搜索/仅错误)，`ValueListenable` 驱动，仿 `console_store.dart`。`filtered` 倒序(最新在上)。提供 `start`/`completeResponse`/`beginStream`/`appendStream`/`endStream`/`completeError`/`markCancelled`。
  - `dio_dev_interceptor.dart` — `DioDevInterceptor`（仅观察，不改请求）：`onRequest` 建条目并把 id 存入 `RequestOptions.extra`；`onResponse` 对 `ResponseType.stream` 的 `ResponseBody` 用 `StreamTransformer` **tee** 字节流，边消费边逐 chunk 写入 store(SSE/LLM 流式杀手锏)，非流式直接序列化记录；`onError` 记错误/取消；`CancelToken.whenCancel` 兜底把仍 pending 的条目置为 cancelled。敏感头(`authorization`/`*-api-key`/`cookie`…)做掩码脱敏。
  - `network_panel.dart` — Network UI：过滤栏(搜索 + 方法 Chip + 仅错误) + 请求行(方法色标/状态码/短 URL/流式图标/耗时/大小) + 详情抽屉(General + 请求头/请求体/响应头/响应体/错误，流式时实时刷新带进度圈)，复制全部。
  - **零额外 UI 依赖**(图标用 Material Icons)；新增 `dio: ^5.9.2` 依赖(拦截器必需，已是主 App 核心依赖，本地 path 包无新下载)。
- 接入：`DevToolsCapture.install()` 注册 `NetworkPanel`；`DevToolsPanel` 接口加可选 `onClear()`/`exportAsText()`，`DevToolsPage` 的「清空/复制」按当前 Tab 委派给对应面板(P0 时是 console 专用硬编码，现泛化，仍不破坏"加面板不改页面"扩展点)；Console/Network 各自实现。库入口导出 Network 相关类型。
- Dio 收口(§7-①，分步迁移)：`dio_client.dart` 新增 `buildAppDio({options, proxy})`(内置 `DioDevInterceptor`)；`buildLlmDio`/`buildMcpDio` 改为走它；逐个迁移老调用点 → `skill_store_page` / `skillsmp_service` / `network_proxy_settings_page` / `font_settings_controller` / TTS `network_tts_service` / ASR `step_asr`·`mimo_asr`·`whisper_asr`。全仓直接 `Dio(...)` 实例化仅剩 `buildAppDio` 内部一处。
- 验证：包内 `flutter analyze` 零问题、`flutter test` 11/11(console 5 + network 6)；迁移文件逐一 analyze 无新增问题(仅 `skill_store_page` 存量 `_total`/const 告警，与本次无关，按 AGENTS.md 不顺手改)。架构边界测试不受影响(新增导入均为 `core/network` 与外部包，非 feature→feature)。
- 遗留/下一步：流式每 chunk 都 `_publish` 与原版 Web 一致(未节流，devtools 关闭时仅多一次列表拷贝，开销可忽略)；cURL 导出 / 失败重发(§5.2 增强项)未做，可后续补。P3 起 Performance(并入 `aetherlink_perf`)。

### 2026-06-30 — P1 完成（悬浮按钮 + 设置开关）
- 包内新增 `src/ui/floating_button.dart`：`DevToolsFloatingButton`(48px 圆形 Terminal 蓝按钮，可拖拽，会话内记忆位置) + `DevToolsFloatingButtonHost`(仿 `PerfOverlayHost`，`enabled` 控制挂载，`onPressed` 由宿主注入以避开 router 依赖)。已在库入口导出。
- 主 App：新增 `dev_tools_button_controller.dart`(仿 `perf_monitor_controller`，设置键 `showDevToolsFloatingButton`，Drift 持久化，`keepAlive`)；`app.dart` 在 `PerfOverlayHost` 外再包 `DevToolsFloatingButtonHost`，点击用 `router.push('/devtools')`；`appearance_settings_page.dart` 把原「显示开发者工具悬浮按钮」占位开关接上该 controller（并更新过时注释）。
- 注意：改 riverpod 注解后必须跑**完整** `dart run build_runner build`，**不要用 `--build-filter`**（会删除其它 `.g.dart`，导致大量 Provider 未定义）。
- 验证：`flutter analyze`(7 个目标)零问题。
- 现状：性能监控浮窗、开发者工具悬浮按钮两个开关都在「外观→开发者工具」，悬浮按钮点按进入 Console。

### 2026-06-30 — P0 完成（Console + 骨架 + 入口）
- 新增独立包 `packages/aetherlink_devtools`（零额外依赖，仿 `aetherlink_perf`）。代码地图：
  - `lib/aetherlink_devtools.dart` — 对外导出。
  - `src/models/log_entry.dart` — `LogEntry` / `LogLevel`。
  - `src/panel.dart` — **扩展点**：`DevToolsPanel` 接口 + `DevToolsRegistry`。新面板 = 新 `DevToolsPanel` 子类 + `DevToolsRegistry.register(...)` 一行，**不改 `DevToolsPage`**（这是 P1~P4 可并行的关键）。
  - `src/console/console_store.dart` — 环形缓冲(2000 上限) + 过滤，`ValueListenable` 驱动。
  - `src/console/console_capture.dart` — `DevToolsCapture.install()`：链式接管 `FlutterError.onError` / `PlatformDispatcher.onError` / `debugPrint`，并注册内置 Console 面板；`zoneErrorHandler` 给 `runZonedGuarded`。
  - `src/console/console_panel.dart` — Console UI（搜索 + 等级 Chip + 等宽行 + 可展开堆栈 + 自动滚动）。
  - `src/ui/devtools_page.dart` — `DevToolsPage`：AppBar(复制/清空) + TabBar 宿主（按注册面板渲染 tab）。
  - `test/console_store_test.dart` — 5 个单测（环形/过滤/格式化），全过。
- 主 App 接入：`pubspec.yaml` 加路径依赖；`lib/main.dart` 用 `runZonedGuarded` 包裹 + `DevToolsCapture.install()`；`app_router.dart` 加 `devToolsPath='/devtools'` 路由；`about_page.dart` 的「开发者工具」行接通 `context.push('/devtools')`。
- 验证：`flutter analyze`（4 项目标）零问题；包内 `flutter test` 5/5 通过。
- 入口现状：**关于我们 → 开发者工具** 可进入 Console。悬浮按钮入口属 P1，尚未做。
- 遗留/下一步：P1 悬浮按钮 + 外观设置占位开关接线；P2 起 Network（需统一 Dio）。

### 2026-06-30 — 决策定稿
- §7 三项决策拍板：① 网络=收口工厂 `buildAppDio()` 分步迁移；② 独立 package `packages/aetherlink_devtools`；③ 入口=悬浮按钮 + 「关于」页开发者入口行（对齐原版 `AboutPage.tsx:147-155`）。
- 确认 Flutter 关于页位置：`lib/features/settings/presentation/mobile/about_page.dart`。
- 下一步：从 **P0** 开工（建 package 骨架 + 日志缓冲 + 全局捕获 + Console tab）。

### 2026-06-30 — 文档创建 / 设计阶段
- 调研原版 Web DevTools（DevToolsPage / ConsolePanel / NetworkPanel / DevToolsFloatingButton）与 Flutter 现状。
- 确认：Flutter 已有 `aetherlink_perf` 性能监控；缺 DevTools 页与悬浮按钮；App 几乎无日志；Dio 分散无统一客户端；持久化为 Drift。
- 产出本设计文档。**尚未开始编码。** 待拍板 §7 三个决策后从 P0 起步。
- 相关前置改动（已完成、非本功能）：移除聊天系统提示气泡实时模糊以降 raster 开销（commit `9e1ea04`）。
