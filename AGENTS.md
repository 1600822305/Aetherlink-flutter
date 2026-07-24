# AGENTS.md

AI 助手在本仓库（`aetherlink_flutter`）工作时遵循以下约定。

## 项目概览

AetherLink：移动端优先的自主智能体环境 + IDE（Flutter/Dart）。核心是
`AgentEngine` 多轮推理循环 + MCP 工具编排 + RAG 知识库。技术栈：
Riverpod（状态）、Drift/SQLite（持久化）、GoRouter（路由）、
Freezed + build_runner（代码生成）、flutter_inappwebview（内置浏览器）。

分层为 Clean Architecture（presentation → application → domain ← data），
铁律与目录死规矩见 `docs/ARCHITECTURE.md`、`docs/PROJECT_STRUCTURE.md`；
命名与文件角色后缀（`*_page` / `*_controller` / `*_repository_impl` 等）见
`docs/CONVENTIONS.md`。设计文档集中在 `docs/`（智能体相关在 `docs/智能体/`，
浏览器升级设计在 `docs/design/`）。

## 项目结构

- `lib/features/<feature>/` — 按功能分包（agent / chat / workspace /
  knowledge / memory / voice / backup / browser / settings …），
  每个 feature 内再分 domain / data / application / presentation。
- `lib/shared/mcp_tools/` — 内置工具目录（文件编辑、浏览器、搜索等）。
- `lib/shared/config/builtin_skills/` — 内置技能，一个 skill 一个文件；
  改 skill 正文必须同步升 `version`（启动按 version 重种持久层）。
- `lib/app/di/` — 组合根与跨 feature 访问缝（如 `agent_runtime_access.dart`）。
- `lib/app/router/app_router.dart` — GoRouter 路由表。
- `packages/` — 本地插件包：`aetherlink_browser`（Headless WebView 浏览器
  内核）、`aetherlink_terminal`、`aetherlink_saf`、`native_keyboard_height` 等。
- `test/` — 与 `lib/` 同构（`test/features/agent/`、`test/shared/mcp_tools/`）；
  包内测试在各 package 自己的 `test/`。

## 常用命令

```bash
flutter pub get                       # 装依赖
dart run build_runner build -d        # Freezed/Riverpod 代码生成（改 @freezed/@riverpod 后必跑）
flutter analyze <改动的文件...>        # 静态分析（按文件跑，别全量）
dart format <改动的文件...>            # 格式化
flutter test test/features/agent      # 按目录跑测试，别默认全量
flutter test packages/aetherlink_browser
```

## 验证

改完代码后**必须**至少对改动到的文件跑一次 `flutter analyze`。

**禁止全量跑测试**（裸 `flutter test`）：全量非常慢。只按改动对应的
目录/文件跑（如 `flutter test test/features/agent`），没让你测就别测。

- 已知存量告警：`lib/features/chat/application/chat_controller.dart:3513` 的
  `curly_braces_in_flow_control_structures`，与新改动无关，不要顺手改它。
- 改到哪跑哪：
  - `lib/shared/mcp_tools/` → `flutter test test/shared/mcp_tools/`
  - `packages/aetherlink_browser/` → `flutter test packages/aetherlink_browser`
  - `lib/features/agent/` 引擎/压缩/权限 → `flutter test test/features/agent`
- 手写 `*.g.dart` / `*.freezed.dart` 是禁止的，一律 build_runner 生成。

## 代码约定

- 遵守分层依赖方向：domain 零框架依赖；presentation 不直接碰 data；
  业务逻辑不写在 Widget 里。
- 注释默认不写；要写就解释「为什么」，不解释 diff 本身。
- 全屏子页/设置子页导航用**零时长路由**（`PageRouteBuilder` +
  `transitionDuration: Duration.zero`），不要用自带 300ms 转场的
  `MaterialPageRoute`（参考 `mcp_server_edit_page.dart`）。
- 常量 `k` 前缀；provider 以 `Provider` 结尾；布尔 `is/has/can` 开头。
- 引擎与重放两侧共享的上下文视图逻辑（fold / microcompact / 工具结果预算）
  必须保持一致，改一侧要同步另一侧（见 `agent_runtime_access.dart` 注释）。

## 提交 / PR

1. 先看状态与改动：`git status --short`、`git diff --stat`、
   `git log --oneline -5`（对齐提交风格）。
2. `git add <明确列出改动文件>`，**不要用 `git add .`**。
3. 提交信息用 Conventional Commits，**正文中文**：
   `feat(scope): 简述` / `fix(scope): ...`（常见 scope：`agent`、`chat`、
   `browser`、`settings`）。正文说明「为什么」，可用要点列关键改动。
4. AI 提交结尾固定附带署名 trailer：

```
Generated with [Devin](https://devin.ai)

Co-Authored-By: Devin <158243242+devin-ai-integration[bot]@users.noreply.github.com>
```

5. 改动走分支 + PR，**不要直接推 main**。PR 描述说清动机与验证方式。

### Git 注意事项

- 不修改 git config；不使用交互式 `-i`；无改动时不提交。
- 不跑破坏性命令（`reset --hard`、`clean -fd` 等），除非用户明确要求。
- Windows 环境下行尾 `LF will be replaced by CRLF` warning 属正常，可忽略；
  PowerShell 里多条命令用 `;` 连接（没有 bash 的 `&&`/heredoc），
  Linux/macOS 正常用 bash。

## 常见坑

- 改内置 skill 正文忘了升 version → 用户端读到旧内容。
- 事件流（AgentEvent）是 append-only：修上下文问题改「视图」函数，
  不改写已落库事件。
- `flutter analyze` 全量很慢且有存量噪音，按文件跑。
