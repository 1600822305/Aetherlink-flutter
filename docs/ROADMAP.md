# 迁移路线图

> 自底向上、UI 最后（见 `MIGRATION.md` §4）。每个里程碑都有明确验收标准，绿了才进下一个。

---

## M0 · 领域模型层
**目标**：把契约定死。
- TS types → freezed 模型（MessageBlock 14 联合、Message、Topic、Assistant、Model + 支撑类型）。
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
- 补丁三分类落地：删 cors-proxy/polyfill；保留并测试②类业务修复。

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
**目标**：逐页复刻（已验证可 1:1）。
- 主题装配（MUI themes.ts token → ThemeData，`useMaterial3: false`）。
- 按 feature 逐页：聊天主界面 → 模型设置 → 关于 → 其余。
- 共享叶子组件沉淀到 `shared/widgets` / feature 内 `widgets`。

**验收**
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
| M2 网络/LLM | ⬜ 下一个 |
| M3 平台层 | ⬜ |
| M4 移动端 UI | ⬜ |
| M5 桌面端 UI | ⬜ |
| 数据迁移 | ⬜ |
