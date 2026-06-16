# 迁移路线图

> 自底向上、UI 最后（见 `MIGRATION.md` §4）。每个里程碑都有明确验收标准，绿了才进下一个。

---

## M0 · 领域模型层
**目标**：把契约定死。
- TS types → freezed 模型（MessageBlock 15 联合、Message、Topic、Assistant、Model + 支撑类型）。
- codegen（freezed / json_serializable）跑通。

**验收**
- [ ] `dart run build_runner build` 通过。
- [ ] `flutter analyze` + `custom_lint` 零告警。
- [ ] 每个模型 round-trip 测试（`fromJson(toJson(x)) == x`）。

---

## M1 · 数据层（Drift / SQLite）
**目标**：本地持久化可跑、可单测。
- Drift schema（topic / message / message_block …）+ DAO + 迁移框架。
- `domain` repository 接口 + `data` 实现。
- 老数据迁移方案定稿（IndexedDB → SQLite）。

**验收**
- [ ] DAO 增删改查单测通过。
- [ ] repository 实现对接口的契约测试通过。
- [ ] schema 迁移（v1→vN）演练通过。

---

## M2 · 网络 / LLM 层
**目标**：headless 跑通流式对话。
- dio 实例 + 拦截器 + SSE 解析器（机械水电，跨协议共享）。
- **3 个协议 adapter**（`openaiCompatible` / `anthropic` / `gemini`）+ 单一 provider factory（按 `protocol` 选；DashScope/Grok 等并入 OpenAI 兼容族）。**统一接缝不统一内脏**，划线 + 抽象判据见 `adr/0006-provider-protocol-adapters.md`（refines `adr/0004`）。
- **全自写，不引第三方 LLM SDK**（已评估 `openai_dart`/`anthropic_sdk_dart`/`googleai_dart`）：兼容供应商动物园 + 非标流式字段强类型库扛不住，且少一份依赖风险。
- 补丁三分类落地：删 cors-proxy/polyfill；保留并测试②类业务修复。
- **E2E 验穿（PR #33）**：真 socket + 本地 mock SSE server 跑通「请求→SSE 分块→适配器→`LlmStreamChunk`」全链（3 协议 × happy/空流/坏块/截断/断流/HTTP500/拒连），+ `bin/llm_smoke.dart` dev 冒烟入口（不依赖 UI / 不要真 key）。**地基体检里「M2 未在运行时端到端验证」这一最后风险已退。**

**验收**
- [ ] 各 provider 的请求构造 + SSE 解析单测通过（用录制的响应做 fixture）。
- [ ] ②类边界条件全部有回归测试。
- [ ] 命令行/测试里能完成一轮流式问答（不依赖 UI）。

---

## M3 · 平台抽象层
**目标**：`UnifiedPlatformApi` 在移动 + 桌面落地。
- abstract class + 各平台插件实现（fs / 通知 / 剪贴板 / 设备 / 分享 / 图库 / TTS / STT…）。
- 按平台注入。

**验收**
- [ ] 移动端 + 桌面端各跑通文件读写、通知、剪贴板冒烟测试。
- [ ] 上层只依赖抽象，无平台判断散落。

---

## M4 · 移动端 UI
**目标**：逐页复刻（已验证可 1:1）。**分子阶段、逐页重写**——每页一个独立 PR，审一个合一个再发下一个（PR 小、好审、进度可见）。

**子阶段**
- **M4.0 地基**（✅ PR #17）：主题即数据（`ThemeSpec` token 化 → `ThemeData`+`ThemeExtension`，`useMaterial3:false`）+ `go_router` 导航骨架 + 关于页打通「主题→导航→脚手架」管线。导航/主题装配/`shared/widgets` 沉淀规则决策内嵌于该期交接提示词；主题系统全景见 `adr/0008-themeable-system-tokens-decoration-sharing.md`（M4.0 只落其地基，装饰层/配图/AI 生成/分享/持久化延后）。
- **M4.1 欢迎页（首屏进入页）**（✅ PR #19）：继关于页之后第二个验证「主题→`go_router` 导航→`Scaffold`」管线的低风险页——居中 logo + 渐变标题（`ShaderMask`，颜色全走主题 token）+ 副标题 + 「开始」按钮；首次进入门控做成内存态 `onboardingController` 接缝（`markStarted()`，持久化延后留 `restore()` 缝）。
- **M4.2 ChatPage 聊天主界面**（重头，拆子阶段）：消息列表（block 渲染 main_text/thinking/code）、输入框、发送、流式增量、话题/助手抽屉。串起 M0(block)+M1(存储)+M2(流式)。子阶段：骨架 ✅ → **M4.2.1 消息渲染**（✅ PR #24，已存 `main_text` 真画成气泡）→ 发送/流式闭环（✅ = M4.3.2 / PR #37，与模型配置落库合并一刀）→ 外围功能逐个（话题/助手抽屉、消息操作…未做）。
- **M4.3 模型/供应商设置**（拆子阶段）：DefaultModelSettings + AddProvider / EditModel / AdvancedAPIConfig + 配置持久化。子阶段：**M4.3-数据层**（✅ PR #34，Drift `ProviderRows` 表 + `ProviderDao` + `ModelRepository`）→ **M4.3.0 二级页「默认模型设置」UI**（✅ PR #31/#32）→ **M4.3.1 三级页 UI**（✅ PR #35，添加供应商 / 供应商详情枢纽 / 编辑模型 / 高级API，1:1 复刻、需数据控件置灰）→ **M4.3.2 接线 + 发送/流式闭环**（✅ PR #37：真 `ChatController` 只依赖端口（`ChatRepository`/`appCurrentModelProvider`/`LlmGatewayFactory`，Riverpod 注入），发送→订阅 `streamChat` 增量进 `main_text`/`thinking` block→`LlmDone` 定稿落库、stream error→错误态+error block；三级页控件解灰接 `ModelRepository`、`current_model` 选当前模型。DI 接缝 `app/di/model_access.dart`）。**M4.3.2 = 第一个可演示闭环 + 地基最后一件已点亮**（「打字→发送→真流式→落库→渲染」在 app 里跑通；真 key 由用户在配置页输入，本期用假网关/mock 验闭环）。
- **M4.4 设置主页外壳 + 高频页**：**M4.4.0 设置 hub 外壳**（✅ PR #26，提前于 M4.3 做 —— hub 是导航父级）+ 关于页（✅ PR #27/#28）；后续 Appearance / Behavior / ChatInterface…（未做条目置灰）。
- **M4.5+ 长尾**：KnowledgeBase、Voice（依赖 M3 延后能力）、MCP、WebSearch、AIDebate、ModelCombo、DataSettings…每页一阶段或小簇。

**验收（每子阶段逐页适用）**
- [ ] 核心页面与原版视觉对比 ≥ 95%。
- [ ] 富文本/代码/LaTeX 渲染正常。
- [ ] 状态全部来自 application 层（UI 无业务逻辑）。

---

## M5 · 桌面端 UI
**目标**：复用下层，只做桌面外壳。
- 桌面 shell：多栏 master-detail / 快捷键 / 窗口管理 / hover / 可拖拽分栏。
- 复用 M4 的叶子组件，只分叉导航与布局。
- 多窗口策略（若需要）影响状态作用域，需在本期前确认。

**验收**
- [ ] 桌面布局可用，复用移动端的业务层与叶子组件。
- [ ] 替代原 Tauri 桌面端功能对齐。

---

## 横切 · 老用户数据迁移
- 与 M1 schema 对齐后实现 IndexedDB → SQLite 一次性导入。
- 全表计数 + 抽样比对验证，确保历史会话无损。

---

## 进度看板（手动维护）

| 里程碑 | 状态 |
| --- | --- |
| M0 模型层 | ✅ 已完成（PR #5） |
| M1 数据层 | ✅ 已完成（PR #6；边界例外见 ADR-0005 / PR #7） |
| M2 网络/LLM | ✅ 已完成（PR #11）；E2E 验穿（PR #33） |
| M3 平台层 | ✅ 已完成（PR #14） |
| M4.0 移动 UI 地基（主题+导航+关于页） | ✅ 已完成（PR #17） |
| M4.1 欢迎页（首屏进入页） | ✅ 已完成（PR #19） |
| M4.2 ChatPage（骨架 + M4.2.1 消息渲染） | ✅ 骨架 + 消息渲染（PR #24）；发送/流式闭环入 M4.3.2（✅ PR #37） |
| M4.3-数据层（模型/供应商持久层） | ✅ 已完成（PR #34） |
| M4.3.0 默认模型设置（二级页 UI） | ✅ 已完成（PR #31/#32） |
| M4.3.1 模型配置三级页 UI | ✅ 已完成（PR #35；含详情枢纽页） |
| M4.3.2 接线 + 发送/流式闭环 | ✅ 已完成（PR #37；第一个可演示闭环、地基最后一件点亮；117 全绿） |
| M4.4.0 设置 hub 外壳 + 关于页 | ✅ 已完成（PR #26 / #27 / #28，提前于 M4.3） |
| M4.4 设置高频页（Appearance/Behavior…） | ⬜ |
| M4.5+ 设置长尾 | ⬜ |
| M5 桌面端 UI | ⬜ |
| 数据迁移 | ⬜ |
