# Hooks 系统：对比分析与升级计划（跨会话任务追踪）

> **给 AI 助手 / 未来会话的说明**：这份文档是 Hooks 系统升级的**唯一任务台账**。
> 接手时：① 通读本文档；② 找到「升级计划」里第一个未完成（`[ ]` 或 🚧）的阶段；
> ③ 按该阶段的验收标准实施；④ 完成后把复选框改为 `[x]`、状态改为 ✅，
> 填上完成日期和 commit/PR 号，**并把这份文档的更新包含在同一次提交里**；
> ⑤ 推送后在回复里告知用户本阶段完成、下一阶段是什么。
> 每个阶段一次提交（或一个 PR），不要跨阶段合并提交。

---

## 1. 参考仓库

| 仓库 | 位置（本机克隆路径） | 说明 |
|---|---|---|
| `1600822305/Aetherlink-flutter` | `~/repos/Aetherlink-flutter` | 本项目，Flutter 版 AetherLink，hooks 在 `lib/features/agent/` |
| `pengchengneo/Claude-Code` | `~/repos/Claude-Code` | 可运行的 Claude Code 还原源码（TypeScript），hooks 的**对标目标** |
| `NousResearch/hermes-agent` | `~/repos/hermes-agent` | Hermes Agent（Python），hooks 仅作横向参考 |

### 关键源码位置

**本项目（Aetherlink-flutter）**
- `lib/features/agent/domain/agent_hooks.dart` —— 纯逻辑：事件枚举、hooks.json 解析、matcher/pattern 匹配、exit 协议（`interpretAgentHookExit`）
- `lib/app/di/agent_runtime_access.dart`（`_HookedAgentToolExecutor`，约 1188-1398 行）—— 执行器装饰层：pre/postToolUse 拦截、生命周期/stop hooks、`_runHook` 经 `terminal_execute` 跑命令
- `lib/features/agent/application/agent_hooks_trust.dart` —— 仓库 hooks.json 信任存储（内容变更即失效）
- `lib/features/agent/application/agent_manual_hooks.dart` —— 设置页手动全局 hooks
- `lib/features/agent/application/engine/agent_engine.dart` —— `stopGuard` 接线
- `lib/features/agent/presentation/mobile/agent_hooks_page.dart` —— Hooks 设置页 UI
- 测试：`test/features/agent/agent_hooks_test.dart`、`agent_hooks_trust_test.dart`、`agent_manual_hooks_test.dart`

**Claude Code（对标源码）**
- `src/entrypoints/sdk/coreTypes.ts` —— `HOOK_EVENTS` 全部 27 个事件
- `src/types/hooks.ts` —— 输出协议 zod schema（`syncHookResponseSchema`：continue/stopReason/suppressOutput/systemMessage/decision/hookSpecificOutput）
- `src/schemas/hooks.ts` —— 4 种 hook 类型：`command` / `prompt` / `agent` / `http`
- `src/utils/hooks.ts` —— 执行核心：stdin 写入 JSON、async hooks、prompt elicitation 双向交互
- `src/utils/hooks/hooksSettings.ts`、`hooksConfigManager.ts` —— 多层 settings 配置
- `src/query/stopHooks.ts` —— Stop hook 接线

**Hermes（横向参考）**
- `gateway/hooks.py` —— `HookRegistry`：从 `~/.hermes/hooks/<dir>/HOOK.yaml + handler.py` 加载，纯观测型（不可阻断），事件：gateway:startup / session:* / agent:start|step|end / command:*

---

## 2. 现状：本项目 hooks 已有能力

- **配置来源**（两路合并，手动在前）：
  1. 设置页手动添加的全局 hooks（App 内持久化，天然可信）；
  2. 工作区 `.aetherlink/hooks.json`（须经信任门槛：用户审阅原文后信任，内容一变即失效——防恶意仓库拿执行权）。
- **事件（6 个）**：`taskStart` / `turnStart` / `preToolUse` / `postToolUse` / `turnEnd` / `stop`。
- **匹配**：`matcher` 匹配权限域（工具名 / `mcp:<server>/<tool>`，`*` 通配），`pattern` 匹配终端子命令或文件路径（复用权限规则 `permissionWildcardMatch`）。
- **执行**：hook 命令经 `terminal_execute` 跑在任务绑定工作区的长驻终端会话，上下文经环境变量传入：`AETHER_TOOL` / `AETHER_ARGS_JSON`（截断 4000 字符）/ `AETHER_FILE_PATH`；每条 hook 有超时（默认 30s）。
- **退出协议**（对标 CC 基础版）：exit 2 → block（原因取输出）；exit 0 + stdout `{"decision":"block"|"deny","reason":...}` → block；其他非零 → hook 自身失败，只记日志不阻断。
- **语义**：preToolUse block → 本次调用不执行，原因作为失败结果回给模型；postToolUse block → 反馈追加进工具结果；stop block → 阻止收尾，原因作为新输入续跑；taskStart/turnStart/turnEnd 为观测型不阻断。
- **配置读取时机**：任务运行内只读一次（`_configLoaded`）。

## 3. 与 Claude Code 的差距清单（对照源码核实）

### 3.1 输入通道
| 项 | Claude Code | 本项目 | 差距 |
|---|---|---|---|
| 传入方式 | 完整 JSON 写入 **stdin**（`src/utils/hooks.ts` L1006/L1210） | 3 个环境变量 | 大 |
| 内容 | session_id、cwd、event 名、完整 tool_input、PostToolUse 含 **tool_response** | 工具名 + args（截断 4000）+ 文件路径 | 大 |
| 双向交互 | hook 可发起 prompt elicitation，stdin 保持打开回传用户选择（L1096） | 无 | 大（低优先级） |

### 3.2 输出协议
| 字段/能力 | Claude Code（`src/types/hooks.ts`） | 本项目 | 差距 |
|---|---|---|---|
| `decision: block` + `reason` | ✅ | ✅ | 无 |
| exit 2 → block | ✅（原因读 **stderr**） | ✅（但只读 stdout，`_interpretTerminalResult` 里 stderr 传空串——terminal_execute 未分离 stderr） | 中：写惯 CC hooks 的脚本迁移过来拿不到原因 |
| `continue:false` + `stopReason`（终止整个任务） | ✅ | ❌ | 中 |
| `suppressOutput` / `systemMessage` | ✅ | ❌ | 小 |
| PreToolUse `permissionDecision: allow\|deny\|ask` | ✅（allow 直接跳过审批弹窗） | ❌（只能 block） | **大** |
| PreToolUse `updatedInput`（改写工具入参） | ✅ | ❌ | 大 |
| PreToolUse/PostToolUse `additionalContext` | ✅ | ❌ | 中 |
| PostToolUse `updatedMCPToolOutput`（改写工具输出） | ✅ | ❌ | 小 |
| `{"async":true}` 异步 hook（后台跑不阻塞） | ✅ | ❌ | 中 |

### 3.3 事件覆盖
CC 共 **27 个**事件（`coreTypes.ts` L25-53）。对映射关系：

| CC 事件 | 本项目 | 备注 |
|---|---|---|
| PreToolUse / PostToolUse / Stop | preToolUse / postToolUse / stop | ✅ 已有 |
| SessionStart（近似） | taskStart | ✅ 近似 |
| **PostToolUseFailure** | ❌（postToolUse 只在工具**成功**时触发，`!toolResult.ok` 直接返回） | 优先补 |
| **UserPromptSubmit**（可拦截/注入上下文） | ❌ | 优先补 |
| SessionEnd | ❌（任务正常结束无事件） | 补 |
| SubagentStart / SubagentStop | ❌（项目有子智能体） | 补 |
| PreCompact / PostCompact | ❌（若有上下文压缩则补） | 视功能 |
| PermissionRequest / PermissionDenied | ❌ | 与审批门集成，价值高 |
| Notification / Setup / FileChanged / CwdChanged / Worktree* / ConfigChange / Elicitation* / TeammateIdle / Task* / StopFailure | ❌ | 多数与 CC 特有功能绑定，低优先级 |
| （本项目独有）turnStart / turnEnd | — | CC 无对应，保留 |

### 3.4 hook 类型与执行模型
| 项 | Claude Code | 本项目 |
|---|---|---|
| hook 类型 | 4 种：`command` / `prompt`（LLM 判定）/ `agent`（子 agent 验证）/ `http` | 仅 shell command |
| 并行执行 | 命中的 hooks **并行** + 去重 | 顺序 await，慢 hook 拖住整条链 |
| matcher | 正则 | `*` 通配符（但 pattern 能匹配子命令/文件路径，CC 无此能力，是本项目优势） |
| 配置层级 | user / project / local settings 叠加 + `/hooks` 菜单 | 手动全局 + 单工作区文件（+ 信任门槛，比 CC 严谨） |
| 进度可视化 | hook 运行事件流 + UI 展示（`hookEvents.ts`） | 无（静默执行） |

### 3.5 本项目的优势（保留，勿在升级中破坏）
- pattern 匹配终端子命令 / 文件路径（CC matcher 只匹配工具名）。
- 仓库 hooks 信任机制：内容变更即失效，需重新审阅。
- 手动 hooks 设置页（增删改 + 启用开关），CC 需编辑 settings 文件。

---

## 4. 升级计划（按阶段执行，每阶段独立提交）

> 状态标记：⬜ 未开始 ｜ 🚧 进行中 ｜ ✅ 已完成（附日期 + commit/PR）
> 每阶段必做：改动文件跑 `flutter analyze`；纯逻辑改动补/改 `test/features/agent/` 下单测；更新本文档状态。

### - [x] 阶段 1：postToolUse 失败也触发 + 传工具输出 ✅（2026-07-19）
**目标**：对齐 CC 的 PostToolUse/PostToolUseFailure 语义。
- 新增事件 `postToolUseFailure`（工具失败时触发；现有 postToolUse 保持只在成功时触发）。
- `_runHook` 增加环境变量 `AETHER_TOOL_OUTPUT`（工具结果 detail，截断 4000 字符）与 `AETHER_TOOL_OK`（true/false），postToolUse / postToolUseFailure 均传入。
- hooks.json 解析、设置页事件下拉、`agent_hooks_page.dart` 说明文案同步补充。
**验收**：单测覆盖新事件解析与匹配；手动 hook 配 postToolUseFailure 能在工具失败时收到 `AETHER_TOOL_OK=false`。
**涉及**：`agent_hooks.dart`、`agent_runtime_access.dart`、`agent_hooks_page.dart`、`agent_hooks_test.dart`。

### - [x] 阶段 2：stdin JSON 输入（兼容 CC 脚本的输入形态） ✅（2026-07-19）
**目标**：hook 命令能从 stdin 读到一份完整 JSON（对齐 CC 输入协议），环境变量保留兼容。
- 实现：`buildAgentHookStdinJson`（agent_hooks.dart，纯逻辑可单测）组装 JSON，字段：`hook_event_name` / `tool_name` / `tool_input`（可解析则嵌入对象）/ `file_path` / `tool_response` / `tool_ok` / `session_id`（工作区 id）/ `cwd`（工作区根）。
- 注入方式：`printf %s '<json>' | ( <hook 命令> )` 管道喷入（不依赖终端后端 stdin 能力）；管道退出码即 hook 退出码，退出协议不变。
- 长度保险：JSON 超 60000 字符时退化为不含 tool_input 原文的精简版（避免命令行过长）。
- 环境变量（AETHER_*）保留，旧 hooks 不受影响。
**验收**：单测覆盖 JSON 组装（含/缺可选字段、args 不可解析退化）。

### - [x] 阶段 3：preToolUse 支持 allow / ask（打通审批门） ✅（2026-07-19）
**目标**：对齐 CC `permissionDecision`，hook 可编程放行审批。
- 实现：`AgentHookOutcome` 扩展为 proceed/block/allow/ask/failed；stdout JSON `{"decision":"allow"|"approve"}` → 免审直通，`{"decision":"ask"}` → 强制审批；block/deny 语义不变。
- 接线：`_PolicyApprovalGate.evaluate` 先跑 `preToolUseVerdict`（聚合裁决 block > ask > allow > proceed，结果缓存给执行器复用——同一次调用 hooks 只执行一次）：hook allow 优先级高于权限规则，但越 root 终端命令硬约束仍强制审批；hook block 时审批门直接放行到执行器由其拦截（避免先弹审批再被拦）。
**验收**：单测覆盖 allow/approve/ask 裁决解析；flutter analyze 无问题。

### - [x] 阶段 4：stderr 分离 + exit 2 原因读 stderr ✅（2026-07-19）
**目标**：对齐 CC「exit 2 原因读 stderr」约定，CC hooks 脚本可直接迁移。
- 实现：终端后端 stdout/stderr 合流（PTY 会话），包装命令把 hook stderr `2>` 重定向到临时文件，命令结束后紧跟标记行 `<<<AETHER_HOOK_STDERR>>>` 回放；`splitAgentHookOutput`（agent_hooks.dart，可单测）拆回两路，末尾子 shell `( exit $? )` 透传 hook 退出码。
- `interpretAgentHookExit` 接线处传入真实 stderr：exit 2 时 stderr 优先作为原因，hook 自身失败时 stderr 作为错误信息。
**验收**：单测覆盖拆分（有/无标记、空 stderr）；hook 脚本 `echo reason >&2; exit 2` 的 reason 能回给模型。

### - [x] 阶段 5：additionalContext 注入 + userPromptSubmit 事件 ✅（2026-07-19）
**目标**：hook 能向对话注入上下文；用户发消息时可拦截/加工。
- 新事件 `userPromptSubmit`：任务运行器（`agent_task_runner.dart` 的 startDraft / startNewTask / sendMessage / answerUserQuestion）在用户消息落库前调用 `runUserPromptSubmitHooks`（agent_runtime_access.dart 顶层函数，配置来源与执行器一致）：block → 消息不进上下文，落状态事件说明拦截原因；additionalContext → 追加到消息后注入模型上下文。stdin JSON 带 `prompt` 字段（对齐 CC），另有 AETHER_PROMPT 环境变量。
- `AgentHookResult` 新增 `additionalContext` 字段：stdout JSON `{"additionalContext":"..."}` 可单独出现（proceed 带注入）或与 decision 同时出现；preToolUse / postToolUse(Failure) 的 additionalContext 聚合后以 `[hook additionalContext]` 段追加进工具结果 detail（回到下一轮模型输入）。
**验收**：单测覆盖事件解析、prompt stdin 字段、additionalContext 解析（单独/与 decision 同时）；flutter analyze 无问题。

### - [x] 阶段 6：`continue:false` 全局终止 + 并行执行 ✅（2026-07-19）
**目标**：对齐 CC 的任务级终止与执行性能。
- stdout JSON 支持 `{"continue":false,"stopReason":...}`：任一 hook 返回即终止整个任务，stopReason 展示给用户。实现：`AgentHookResult` 新增 `preventContinuation`/`stopReason` 字段（可与任意 decision 同时出现）；执行层（`HookedAgentToolExecutor`）收集终止信号，引擎经新增 `hookStopSignal` 回调（与 stopGuard 同款注入）在安全点（循环顶部 / 每个工具执行后）消费并转 cancelled，stopReason 落状态事件展示给用户；userPromptSubmit 的 continue:false 在任务运行器拦截消息并落状态事件。
- 同事件命中的多条 hooks 由顺序 await 改为 `Future.wait` 并行（同命令去重），裁决由新增纯函数 `aggregateAgentHookResults` 聚合：任一 block 即 block（原因拼接），优先级 block > ask > allow > proceed；pre/post/stop/生命周期/userPromptSubmit 全部切换为并行。
**验收**：单测覆盖 continue:false 解析（单独/与 decision 同时）与聚合逻辑（9 个新用例，共 34 个全部通过）；flutter analyze 无问题。
**涉及**：`agent_hooks.dart`、`agent_hooks_access.dart`、`agent_runtime_access.dart`、`agent_engine.dart`、`agent_task_runner.dart`。

### - [x] 阶段 7：subagent / session 生命周期事件 ✅（2026-07-19）
**目标**：`subagentStart` / `subagentStop`（可 block 子智能体收尾）、`taskEnd`（任务正常结束，观测型）。
- 新事件 3 个：`subagentStart`（子智能体启动时，观测型，`_runChildEngine` fire-and-forget 触发）；`subagentStop`（子智能体收尾前，对标 CC SubagentStop，作为子引擎的 stopGuard 接入——子智能体不再跑主任务的 stop hooks，改跑 subagentStop，可 block 收尾并把原因作为新输入续跑）；`taskEnd`（主任务转 done 后，观测型，引擎新增 `onTaskEnd` 回调接线）。
- `HookedAgentToolExecutor` 新增 `runSubagentStopHooks`（与 runStopHooks 共用 `_runFinalizeHooks`，并行 + 聚合）；`forProfile` 返回记录新增 `subagentStopGuard`；Hooks 设置页新增 SUBAGENT 阶段分组与 taskEnd 文案。
**验收**：单测覆盖 3 个新事件解析（共 35 个全部通过）；flutter analyze 无问题。
**涉及**：`agent_hooks.dart`、`agent_hooks_access.dart`、`agent_runtime_access.dart`、`agent_engine.dart`、`agent_task_runner.dart`、`agent_hooks_page.dart`。

### - [x] 阶段 8：async hooks + 进度可视化 ✅（2026-07-19）
**目标**：stdout `{"async":true}` → hook 转后台不阻塞主链；任务时间线上展示 hook 运行状态（运行中/放行/阻断），替代当前静默执行。
- async 协议（对标 CC）：hook 把 `{"async":true}` 作为 stdout 首行输出即视为 async hook——不参与裁决（按放行处理），余下输出/退出码忽略（`AgentHookResult.isAsync`）。注：执行走 terminal_execute（无流式首行检测），要真正不阻塞主链，hook 需自行把耗时部分放后台（`(long_task &)`）并在输出 async 首行后立即退出；与 CC 的流式首行检测存在实现差异。
- 进度可视化：执行层新增 `AgentHookTimelineSink` 通道（任务运行器在引擎启动时注入，携带 taskId，主任务/子智能体各自接线）；每批命中的 hooks 先落一条「[hook] 事件(工具) 运行中 · N 条」状态事件，完成后原位改写为结果（放行/阻断+原因/免审/强制审批，另标注转后台/失败条数/要求终止，含耗时）；文案由纯函数 `formatAgentHookStatusLine` 生成；`AgentEventStore` 新增 `updateStatusChange`（状态行原位改写，id/seq 不变）。
**验收**：单测覆盖 async 首行解析（含非首行/async!=true 不触发）与状态行文案（5 个新用例，hooks 40 个 + 引擎 12 个全部通过）；flutter analyze 无问题。
**涉及**：`agent_hooks.dart`、`agent_hooks_access.dart`、`agent_runtime_access.dart`、`agent_task_runner.dart`、`agent_event_store.dart`。

### - [x] 阶段 9：扩展 hook 类型（command / prompt / http） ✅（2026-07-19）
**目标**：对标 CC 的 `prompt`（LLM 判定型）与 `http`（HTTP 回调）hook 类型；`agent` 型暂不做。
- 配置格式标准重构（按用户要求不做兼容层）：hooks.json 每条 hook **必须**带 `type` 字段（`command` / `prompt` / `http` 区分联合，对标 CC 的 discriminatedUnion），缺 type、type 未知或缺对应载体（command/prompt/url）的条目丢弃；旧的无 type 格式不再默认按 command 解释。仅手动 hooks 的 App 内存储解码保留无 type → command 的存储迁移（避免用户已保存的手动 hooks 静默丢失）。
- `prompt` 型：提示词里 `$ARGUMENTS` 替换为 hook 输入 JSON（无占位符时追加到末尾），用当前默认模型做一次非交互裁决；回复协议 `{"ok":true}` → 放行，`{"ok":false,"reason":...}` → block 带原因（容忍 围栏 包裹）；非 JSON / 不符合协议 / 未配模型 / 超时 → hook 自身失败（不阻断）。CC 的 `model` 字段未实现（固定用当前默认模型），后续可加。
- `http` 型：把 hook 输入 JSON POST 到配置 URL（Content-Type: application/json，可选自定义 `headers`，走带代理配置的 dio）；2xx 响应体按 stdout 同款协议解析（decision / additionalContext / continue:false / 首行 async）；非 2xx / 网络错误 / 超时 → hook 自身失败（不阻断）。CC 的 `allowedEnvVars` header 插值未实现（不读任何环境变量，避免意外泄露）；URL 不做 allowlist，但 hooks 本身受手动添加/仓库信任门槛管控。
- 执行器按 type 分派（`_execAgentHook` → command/prompt/http），并行/聚合/时间线/stop signal 全部复用；同事件去重键由 `hook.command` 改为 `type + payload`（不同类型同文本不会误去重）；设置页新增类型切换（命令/提示词/HTTP）与对应载体输入。
**验收**：单测覆盖新类型解析（含丢弃规则/headers 过滤）、prompt 协议、http 协议、手动 hooks 往返+存储迁移（hooks 51 个 + 手动 5 个 + 引擎 12 个全部通过）；flutter analyze 无问题。
**涉及**：`agent_hooks.dart`、`agent_manual_hooks.dart`、`agent_hooks_access.dart`、`agent_hooks_page.dart`。

---

## 5. 变更日志（每阶段完成后追加）

| 日期 | 阶段 | 状态 | commit / PR | 备注 |
|---|---|---|---|---|
| 2026-07-19 | 文档建立 | ✅ | 867da359 | 初版对比分析 + 9 阶段计划 |
| 2026-07-19 | 阶段 1 | ✅ | 3f2d0e05 | 新增 postToolUseFailure 事件；post 事件传入 AETHER_TOOL_OUTPUT / AETHER_TOOL_OK |
| 2026-07-19 | 阶段 2 | ✅ | 9824939f | stdin JSON 输入（buildAgentHookStdinJson + 管道喷入），字段命名对齐 CC |
| 2026-07-19 | 阶段 3 | ✅ | 13104088 | preToolUse allow/ask 打通审批门，裁决缓存避免重复执行 |
| 2026-07-19 | 阶段 4 | ✅ | c9e1a905 | stderr 经临时文件+标记行回传，exit 2 原因读 stderr |
| 2026-07-19 | 阶段 5 | ✅ | 54bb2a87 | userPromptSubmit 事件 + additionalContext 注入（prompt/pre/post） |
| 2026-07-19 | 阶段 5.5 | ✅ | b79d36ec | 重构：hooks 执行层拆到 app/di/agent_hooks_access.dart，统一配置加载 |
| 2026-07-19 | 阶段 6 | ✅ | c3d857c4 | continue:false 全局终止（hookStopSignal 接线引擎）+ 同事件 hooks 并行执行（同命令去重，aggregateAgentHookResults 聚合） |
| 2026-07-19 | 阶段 7 | ✅ | b19a999e | 新事件 subagentStart / subagentStop（子引擎 stopGuard，可 block 收尾）/ taskEnd（引擎 onTaskEnd 回调） |
| 2026-07-19 | 阶段 8 | ✅ | ac539994 | async hooks（首行 {"async":true} 协议）+ hook 运行状态写入任务时间线（运行中→结果原位改写） |
| 2026-07-19 | 阶段 9 | ✅ | 8642afb5 | hook 类型扩展：配置标准重构（必带 type，不兼容无 type 旧格式）+ prompt（LLM 裁决）/ http（POST 回调）型 hook |
| 2026-07-19 | 设置 UI 重构 | ✅ | 3d1dbc19 | 按类型的编辑表单（http headers 键值编辑 + URL 校验）、列表类型徽标、事件文案类型中立化、仓库 hooks 结构化审阅（http URL 高亮） |
| 2026-07-19 | 设置 UI 完整重构 | ✅ | 6965cb9c | 信息架构重排（仓库信任状态置顶 + 已配置优先 + 空事件收阶段折叠 + 模板）、全屏编辑页（matcher 建议 chips、pattern 动态说明、header 值遮蔽、删除确认、超时校验）、hook 试跑、信任 diff |
| 2026-07-19 | 差距补齐 ①② | ✅ | 136d2086 | http hook SSRF 防护（对标 CC ssrfGuard：DNS 解析后阻断私网/链路本地/云 metadata/CGNAT，loopback 放行）+ 输出协议新增 updatedInput（preToolUse 改写工具入参后放行，改写事实落时间线）与 systemMessage（展示给用户的提示，落时间线不进模型上下文） |
| 2026-07-19 | 差距补齐 ③④ | ✅ | 623bba6d | 配置字段 once（本次任务内只触发一次）/ statusMessage（运行中自定义时间线文案）/ model（prompt/agent 型按模型 id 指定裁决模型，缺省回退当前默认模型）+ 新增 agent 型 hook（对标 CC execAgentHook：多轮函数调用循环的小智能体校验器，工具为工作区终端 run_command + submit_result 结构化交回 {"ok":...} 裁决，协议同 prompt 型；轮数上限 10）；设置页支持 agent 类型表单与新字段 |
| 2026-07-19 | 差距补齐 ⑤ | ✅ | （本提交） | asyncRewake（command 型配置字段，对标 CC）：hook 直接转后台不阻塞主链，后台跑完若阻断（退出码 2）把反馈作为排队消息注入任务，引擎在安全点消费叫醒模型（任务已结束时留待续跑进上下文）；时间线落「转后台→后台完成/后台阻断·反馈已注入」；设置页 command 型加 asyncRewake 开关 |
