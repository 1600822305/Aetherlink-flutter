# Hooks 系统：剩余任务交接文档（跨会话）

> **给 AI 助手 / 未来会话的说明**：这份文档是 Hooks 系统**剩余差距**的交接台账，
> 与《Hooks系统-对比与升级计划.md》（已完成阶段 1–9 + UI 重构 + 差距补齐 ①–⑤ 的
> 主台账）配套使用。
> 接手时：① 先通读主台账了解已完成能力与架构；② 再读本文档，找到「剩余任务」里
> 第一个未完成（`⬜`）且优先级最高的项；③ 与用户确认要做哪几项（用户习惯逐项点单，
> 如「开始 6」）；④ 按该项的「验收标准」实施；⑤ 完成后把状态改为 ✅、填 commit 号，
> **并把本文档 + 主台账变更日志的更新包含在同一次提交里**；⑥ 推送后在回复里告知
> 用户完成情况与剩余项。
> 一项一次提交，不跨项合并；文档 commit 号占位先写「（本提交）」，推送拿到 hash 后
> 再补一条 docs 提交回填（与主台账既有做法一致）。

---

## 1. 环境与规范（每次必看）

| 项 | 值 |
|---|---|
| 主仓库 | `~/repos/Aetherlink-flutter`，分支 `main`，**直接推 main，不开 PR** |
| 对标源码（只读） | `~/repos/Claude-Code`（TypeScript 还原版 Claude Code） |
| Flutter | 装在 `~/flutter`，用前 `export PATH=$PATH:~/flutter/bin`（Flutter 3.44.6 / Dart 3.12.2） |

- **验证**：改完对改动文件跑 `flutter analyze <文件...>`；纯逻辑改动补/改
  `test/features/agent/` 下单测，跑 `flutter test <相关测试>`。
- **已知存量告警**：`lib/features/chat/application/chat_controller.dart:3513` 的
  `curly_braces_in_flow_control_structures`，与新改动无关，**不要顺手改**。
- **提交**：Conventional Commit，正文中文，末尾固定 Devin 署名 trailer。提交信息写到
  `.git/COMMIT_MSG_TMP.txt` 再 `git commit -F`，提交后删除；`git add` 明确列文件，
  **不用 `git add .`**；提交前先看 `git status --short` / `git diff --stat` /
  `git log --oneline -5`。
- **架构硬约束**：`agent` 与 `chat` feature **互不 import**；依赖 chat 工具路由 / LLM /
  terminal / 网络的执行层放 `lib/app/di/`（如 `agent_hooks_access.dart`）；领域纯逻辑放
  `lib/features/agent/domain/`（不引 Flutter / dio / terminal / LLM）。

---

## 2. 现状快照（已做完的，勿重复造）

**当前事件（11 个）**：`taskStart` / `userPromptSubmit` / `turnStart` / `preToolUse` /
`postToolUse` / `postToolUseFailure` / `turnEnd` / `stop` / `subagentStart` /
`subagentStop` / `taskEnd`。

**当前 hook 类型（4 种）**：`command` / `prompt`（单轮 LLM 裁决）/ `http`（POST 回调）/
`agent`（多轮带工具的小智能体校验器）。

**输出协议**：`decision`（block/deny/allow/approve/ask）、`continue:false` + `stopReason`、
`additionalContext`、`updatedInput`、`systemMessage`、首行 `{"async":true}`。

**配置字段**：`type` / `matcher` / `pattern` / `command|prompt|url` / `headers` / `timeout` /
`model`（prompt/agent）/ `statusMessage` / `once` / `asyncRewake`（command）。

**其他能力**：pre/post/stop/生命周期/userPromptSubmit 全部并行执行 + 聚合裁决；
两路配置来源（手动全局 hooks + 工作区 `.aetherlink/hooks.json` 信任门槛）；
http hook SSRF 防护；时间线状态行（运行中→结果原位改写）；设置页专业化 UI
（信息架构重排、全屏编辑页、试跑、信任 diff、模板）。

> 详细实现与 commit 号见主台账《Hooks系统-对比与升级计划.md》第 4/5 节。

**关键文件**（改这些）：
- `lib/features/agent/domain/agent_hooks.dart` —— 纯逻辑：枚举、解析、匹配、协议、聚合。
- `lib/app/di/agent_hooks_access.dart` —— 执行层：加载/信任/command/prompt/http/agent、
  并行、聚合、时间线、SSRF、once、asyncRewake、生命周期、userPromptSubmit。
- `lib/app/di/agent_runtime_access.dart` —— `forProfile` 组装执行器、回调注入点。
- `lib/features/agent/application/agent_task_runner.dart` —— 引擎接线、时间线/rewake sink。
- `lib/features/agent/application/engine/agent_engine.dart` —— 主循环、安全点、stopGuard/
  hookStopSignal 消费。
- `lib/features/agent/application/agent_manual_hooks.dart` —— 手动 hooks 存储编解码。
- `lib/features/agent/presentation/mobile/agent_hooks_page.dart` —— 设置页 UI。
- 测试：`test/features/agent/agent_hooks_test.dart`、`agent_manual_hooks_test.dart`、
  `agent_hooks_trust_test.dart`、`engine/agent_engine_test.dart`。

---

## 3. 剩余任务（按优先级，逐项独立提交）

> 优先级依据用户此前排序：⑥ > ⑦ > 其余。用户通常逐项点单，动手前先确认范围。

### ✅ 6. `disableAllHooks` 全局开关（2026-07-19，commit fb696966）

**目标**：对标 CC 的全局 hooks 总开关，用户可一键停用所有 hooks（应急/调试/信任存疑时），
不必逐条删除。

**CC 参考**：`src/utils/hooks.ts` 里 `disableAllHooks` 配置项（读自 settings），为真时
所有 hook 执行前置短路。

**建议实现**：
- 存储：新增一个 App 级布尔设置（复用手动 hooks 的持久化层或 settings provider），
  **默认 false**（不改变现有行为）。
- 短路点：`HookedAgentToolExecutor` 的统一入口（`_hooks()` 返回后、`_runHooksParallel`
  之前，或 `_hooks()` 内直接在开关开时返回空配置），确保 pre/post/stop/生命周期/
  userPromptSubmit **全部**被短路；`runUserPromptSubmitHooks` 顶层函数同样要判开关。
- 时间线：开关开且本可命中 hooks 时，可选落一条「[hook] 已被全局开关停用」提示（避免用户
  以为 hooks 生效了）。斟酌噪音，倾向只在确有命中时提示一次。
- UI：设置页顶部加一个显眼的总开关（开时给出警告色 + 说明「所有事件的 hooks 暂停执行」）。

**注意/边界**：
- 开关只停「执行」，不改配置/信任状态（关掉后原样恢复）。
- 与仓库信任解耦：即使某工作区已信任，开关开时也不跑。
- 试跑（tryRunAgentHook）是否受开关影响需决策：建议**试跑不受开关限制**（试跑是显式用户
  操作，目的就是验证单条 hook），但要在 UI 上说明。

**验收标准**：
- 开关开 → 任意事件都不执行任何 hook（单测/手测覆盖 pre/post/stop/userPromptSubmit 至少各一）。
- 开关关 → 行为与现在完全一致（回归）。
- `flutter analyze` 无问题；相关单测通过。

**涉及**：`agent_hooks_access.dart`、可能新增 settings provider、`agent_hooks_page.dart`、
（若存储走 domain 可测则）对应单测。

**实现记录（2026-07-19）**：
- 存储：新增 `lib/features/agent/application/agent_hooks_settings.dart`，
  `agentDisableAllHooksProvider`（Notifier<bool>，默认 false，复用
  appSettingsStore 持久化，key `agent_disable_all_hooks`，编解码纯函数可单测）。
- 短路点：`HookedAgentToolExecutor._hooks()` 开关开时返回 null（pre/post/stop/
  subagentStop/生命周期全部短路）；`runUserPromptSubmitHooks` 顶部同样判开关。
- 时间线：开关开且本有 hooks 配置时，每次任务落一条「[hook] 已被全局开关停用」提示。
- UI：设置页顶部新增「停用所有 Hooks」总开关卡片（开时警告色 + 说明）。
- 试跑（tryRunAgentHook）不受开关限制（UI 文案已说明）；配置与信任状态不受影响。
- 单测：`test/features/agent/agent_hooks_settings_test.dart`（编解码 + 默认回退）。

---

### ✅ 7. 按产品能力补事件（全部完成：①②③ + preCompact/postCompact）

**目标**：补齐对本项目**有实际意义**的 CC 事件（不盲目对齐全部 27 个；多数 CC 事件绑定
其特有产品面——worktree/teammates/elicitation——本项目无对应，低优先级不做）。

**优先补（价值高）**：

1. **`permissionRequest` / `permissionDenied`**（审批门前后）
   - 语义：审批弹窗弹出前触发 `permissionRequest`（hook 可 allow/deny/ask，编程决定是否
     免审或强制拒绝）；用户拒绝审批后触发 `permissionDenied`（观测型，可用于记录/通知）。
   - 接线点：`_PolicyApprovalGate.evaluate`（`agent_hooks_access.dart`），已有
     `preToolUseVerdict` 的裁决聚合可复用；注意与现有 preToolUse allow/ask 的关系
     （避免重复裁决——preToolUse 已能 allow/ask，permissionRequest 的差异在于它发生在
     审批决策点、拿得到「即将要求审批的原因」）。
   - 这是与本项目审批体系集成度最高、最有价值的一项。
   - ✅ **已完成（2026-07-19）**：枚举新增 `permissionRequest` / `permissionDenied`
     （均按工具 matcher/pattern 匹配）。`_PolicyApprovalGate.evaluate` 拆为
     `_evaluateBase` + 包装层：仅当基础裁决为 needsUser（即将弹审批）时跑
     `permissionRequestVerdict`（allow → 免审直通，越 root 硬约束不可覆盖；
     block → forbid 强制拒绝；其余照常审批），与 preToolUse 不重复裁决。
     用户拒绝审批后 `waitForVerdict` fire-and-forget 跑
     `runPermissionDeniedHooks`（拒绝原因经 `tool_response` 传入）。设置页
     TOOL 阶段新增两事件；试跑支持；单测覆盖解析 + 匹配。

2. **`notification`**（观测型）
   - 语义：需要用户注意的时刻（如长时间等待、审批挂起）触发，hook 可用于外部通知
     （桌面通知 / webhook）。观测型，不阻断。
   - 接线点：审批挂起 / ask_user 等待处。
   - ✅ **已完成（2026-07-19）**：枚举新增 `notification`（matcher 匹配通知
     类型 approval / question，pattern 忽略）。引擎新增 `onNotification`
     回调：审批挂起（type=approval）/ ask_user 等待（type=question）时
     同步触发、不阻断；task runner 接 `runNotificationHooks`
     （fire-and-forget）。消息经 stdin JSON `message` / `notification_type`
     及环境变量 AETHER_MESSAGE / AETHER_NOTIFICATION_TYPE 传入。设置页
     TOOL 阶段新增事件 + 试跑支持；单测覆盖解析 + 类型匹配 + stdin 字段。

3. **`fileChanged`**（文件监听触发）
   - 语义：工作区文件变更时触发 hook（CC 用于 lint-on-save 类场景）。
   - **成本较高**：需要文件监听基础设施（本项目当前无 hooks 侧文件 watcher），且触发频率
     高、需去抖/过滤。**动手前先与用户确认是否值得**，或降级为「工具写文件后」的
     postToolUse pattern 匹配（现已支持文件路径 pattern，可能已覆盖大部分诉求）。
   - ✅ **已完成（2026-07-19，用户确认上文件监听）**：复用后端已有的
     `WorkspaceBackend.watch()` 广播流（SAF/SSH/PRoot 均 canWatch），无需新
     监听基础设施。模块化拆分：去抖纯逻辑在领域层
     `agent_file_watch.dart`（按路径合并首末变更类型 + 静默窗口 500ms，
     新建后即删抵消）；watcher 组装在 `agent_file_watch_access.dart`
     （app/di，订阅 watch 流 + 定时冲刷，生命周期随任务 start/stop，
     无配置时不订阅）。matcher 匹配变更类型（created/modified/deleted/
     moved），pattern 匹配文件路径；路径经 `file_path`、变更类型经
     `event`（对标 CC）及 AETHER_FILE_EVENT 传入。观测型不阻断。设置页
     TOOL 阶段新增事件 + 试跑支持；单测覆盖解析 + 匹配 + stdin 字段 +
     去抖逻辑（`agent_file_watch_test.dart`）。

**视功能补（有则补，无则跳过）**：
- **`preCompact` / `postCompact`**：仅当项目有上下文压缩流程时有意义。查
  `agent_engine.dart` 是否有 compaction（主台账提到 `foldCompactedEvents` 单测，说明**有**
  压缩逻辑）→ 值得补：压缩前后各触发一次，hook 可注入/记录。接线在压缩发生处。
  - ✅ **已完成（2026-07-19）**：枚举新增 `preCompact` / `postCompact`（观测型，
    matcher 匹配触发方式——目前仅 auto，pattern 忽略）。引擎 `_maybeCompact`
    新增 `onPreCompact`（摘要生成前）/ `onPostCompact`（摘要落库后，带摘要）
    回调；task runner 接 `runCompactionHooks`（fire-and-forget）；摘要经
    stdin JSON `tool_response` 传入。设置页 AGENT 阶段新增两事件；单测覆盖
    解析 + 匹配 + 引擎压缩回调时机。
- **`sessionEnd`**：本项目已有 `taskEnd`（任务正常结束），语义近似；若要区分「会话级结束
  vs 单任务结束」再评估，否则跳过避免重复。

**不做（明确排除，除非用户特别要求）**：
`Setup` / `CwdChanged` / `WorktreeCreate|Remove` / `ConfigChange` / `Elicitation(+Result)` /
`TeammateIdle` / `TaskCreated|Completed` / `StopFailure` / `InstructionsLoaded` —— 绑定 CC
特有产品面，本项目无对应场景。

**每个新事件的通用改动清单**：
1. `agent_hooks.dart`：`AgentHookEvent` 加枚举值 + 解析（事件键）+（如需匹配）matcher/pattern
   处理；观测型无需裁决聚合。
2. `agent_hooks_access.dart`：新增触发函数或在对应生命周期点调用；决定是否阻断（观测型走
   fire-and-forget，可阻断型走聚合裁决 + stopGuard/signal）。
3. 触发点接线：`agent_task_runner.dart` / `agent_engine.dart` / `_PolicyApprovalGate`。
4. `agent_hooks_page.dart`：设置页事件列表 + 阶段分组 + 文案（说明该事件能否阻断）。
5. 单测：事件解析 + 匹配（如适用）。

**验收标准**：每个新事件——配一条对应 hook 能在该时机触发；可阻断型能 block 并见效；
观测型不阻断；`flutter analyze` 无问题；单测覆盖解析。

**涉及**：见通用清单。

---

### ⬜ 8.（低优先，需用户确认价值）其余协议/基础设施差距

这些是主台账差距清单里剩下的、优先级明确较低或与本项目形态不完全契合的项，**默认不做**，
仅在用户点名时评估：

- **`suppressOutput`**：hook 输出不写时间线（我们已有 systemMessage 反向能力，价值小）。
- **`decision:"approve"` 的更多变体 / 结构化 `hookSpecificOutput`**：我们目前平铺字段已
  覆盖主要语义，是否重构为 CC 的嵌套结构需权衡（会动协议解析，成本中，收益小）。
- **`updatedMCPToolOutput`**（postToolUse 改写工具输出）：与 updatedInput 对称，可做，价值中。
- **多层配置合并**（user/project/local/企业策略/插件/技能 frontmatter）：本项目是两路来源
  （手动 + 工作区文件 + 信任门槛），CC 的多层 settings 与本项目配置形态差异大，**不建议
  照搬**；如有需求应按 Aetherlink 自己的配置体系设计。
- **配置快照 + ConfigChange 热重载**：当前任务运行内配置只读一次（`_configLoaded`），
  简单可靠；热重载价值有限。
- **hook 执行事件广播 / 流式 stdout 进度**：我们有时间线状态行（运行中→结果），无逐字节
  流式；对当前 UI 足够。
- **prompt elicitation 双向交互**（hook 运行中向用户提问、stdin 回传选择）：成本高、场景少。
- **`allowedEnvVars`**（http header 环境变量插值）：**刻意不做**——安全考量，http hook 不读
  任何环境变量，避免信任的仓库 hook 外泄环境敏感值。这是**有意的安全边界，勿"补齐"**。

---

## 4. 安全边界（贯穿所有剩余任务，勿破坏）

- 工作区 hooks 必须经信任门槛；内容变更即失效需重新审阅。
- http hook：SSRF 防护保留（阻断私网/metadata/链路本地/CGNAT，loopback 放行）；不读环境
  变量；日志/审阅 UI 不展示 header 值。
- 不为了追赶 CC 而无条件放宽网络策略或环境变量访问。
- 新增可阻断事件时，hook 自身失败/超时/异常一律按「不阻断任务」处理（只记录），只有明确
  的 block 裁决才阻断——与现有所有事件一致。

---

## 5. 交接变更日志（本文档自身的维护记录）

| 日期 | 事项 | commit |
|---|---|---|
| 2026-07-19 | 建立剩余任务交接文档（覆盖 ⑥ disableAllHooks、⑦ 补事件、⑧ 低优先协议/基础设施） | 34b41b15 |
| 2026-07-19 | ⑥ disableAllHooks 全局开关完成（状态改 ✅ + 实现记录） | fb696966 |
| 2026-07-19 | ⑦-1 permissionRequest / permissionDenied 事件完成 | 2da6aa06 |
| 2026-07-19 | ⑦-2 notification 事件完成 | 7708017c |
| 2026-07-19 | ⑦-3 preCompact / postCompact 事件完成 | 6f96ff12 |
| 2026-07-19 | ⑦-4 fileChanged 事件（文件监听 + 去抖）完成 | 791b27eb |
