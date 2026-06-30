# Aetherlink Flutter - 应用内开发者工具 (DevTools) 设计文档

> **版本**: v0.1
> **日期**: 2026-06-30
> **状态**: 设计定稿（§7 三项决策已拍板，待从 P0 开工）
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
| **P0** | 独立 package 骨架 + `LogSink`/`ConsoleStore` + 全局错误/print 捕获(§4.1-A) + DevToolsPage(Console tab) | ⬜ | - |
| **P1** | 可拖拽悬浮按钮 `DevToolsFloatingButton` + 设置开关接线(补占位项) | ⬜ | - |
| **P2** | `DioDevInterceptor` + 统一 Dio 工厂(§4.2) + Network 面板(含 SSE 流式) | ⬜ | - |
| **P3** | Performance tab（并入 aetherlink_perf） | ⬜ | - |
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

### 2026-06-30 — 决策定稿
- §7 三项决策拍板：① 网络=收口工厂 `buildAppDio()` 分步迁移；② 独立 package `packages/aetherlink_devtools`；③ 入口=悬浮按钮 + 「关于」页开发者入口行（对齐原版 `AboutPage.tsx:147-155`）。
- 确认 Flutter 关于页位置：`lib/features/settings/presentation/mobile/about_page.dart`。
- 下一步：从 **P0** 开工（建 package 骨架 + 日志缓冲 + 全局捕获 + Console tab）。

### 2026-06-30 — 文档创建 / 设计阶段
- 调研原版 Web DevTools（DevToolsPage / ConsolePanel / NetworkPanel / DevToolsFloatingButton）与 Flutter 现状。
- 确认：Flutter 已有 `aetherlink_perf` 性能监控；缺 DevTools 页与悬浮按钮；App 几乎无日志；Dio 分散无统一客户端；持久化为 Drift。
- 产出本设计文档。**尚未开始编码。** 待拍板 §7 三个决策后从 P0 起步。
- 相关前置改动（已完成、非本功能）：移除聊天系统提示气泡实时模糊以降 raster 开销（commit `9e1ea04`）。
