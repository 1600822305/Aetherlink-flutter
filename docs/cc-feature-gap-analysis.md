# Claude Code 功能对照与可移植性分析

> 对照仓库：[pengchengneo/Claude-Code](https://github.com/pengchengneo/Claude-Code)（可运行的 CC 源码）
> 对照对象：Aetherlink 智能体模式（`lib/features/agent/`）
> 更新时间：2026-07

## 0. 结论速览

Aetherlink 智能体的核心骨架与 CC 已基本对齐：计划模式（enter/exit_plan_mode）、
update_plan（全量覆盖 + 结果回填 + 严格校验 + 收尾清空）、子代理并行
（spawn_subagent，上下文隔离）、hooks、检查点、压缩 + 微压缩、权限规则、
技能、MCP、消息排队/打断注入、工作台（diff/终端/文件）。

剩余差距按性价比分三个梯队，建议从 **1.1 验证提醒** 和 **1.3 离开摘要** 开工。

| 优先级 | 功能 | 工作量 | 价值 |
| --- | --- | --- | --- |
| P0 | 验证提醒（verification nudge） | 极小 | 防"标完成不验证" |
| P0 | 离开摘要（awaySummary） | 中 | 移动端差异化最大 |
| P1 | 上下文可视化（/context） | 中 | 调参/排查利器 |
| P1 | 自动记忆抽取（extractMemories + /init） | 中大 | 长期体验差距最大 |
| P2 | Task V2（依赖/owner） | 大 | 多代理协作前置 |
| P2 | Git worktree 隔离 | 中大 | 实验性改动零污染 |
| P2 | 浏览器工具 | 大 | 补交互式网页能力 |
| P3 | 下一步建议、技能发现、review 预设 | 小中 | 锦上添花 |

## 1. 第一梯队：高价值、工作量可控

### 1.1 验证提醒（verification nudge）

CC 的 TodoWrite 在工具结果里做两层"验证闭环"约束：

- 一次提交中关闭 ≥3 个条目、且计划里没有"验证/测试"类条目时，
  结果文案追加"该运行验证步骤了"的提醒（`TodoWriteTool.ts`）；
- `VerifyPlanExecutionTool` 允许模型对照原计划核查执行结果。

Aetherlink 的 update_plan 结果回填（`agent_engine.dart`）已就位，追加提醒
只需在成功文案上按条件拼一句话，成本几行代码。

### 1.2 上下文可视化（/context, `ctx_viz`）

CC 的 `/context` 按 system prompt / 工具定义 / 消息历史 / todo 等分类展示
token 占用比例。Aetherlink 已有 contextTokens 总量与压缩阈值，缺分解视图。
建议做进工作台一个 tab：排查"上下文为什么爆了"、评估工具定义开销时非常直观。

### 1.3 离开摘要（awaySummary）

CC 检测用户长时间未交互后返回，自动生成"你离开期间我做了什么"的摘要。
移动端场景比 CC 终端更适合：任务后台跑完/被阻塞时推送通知 + 摘要卡。
`agent_notification_service.dart` 已有通知通道，缺"离开窗口检测 + 事件段
摘要生成"两块。

### 1.4 自动记忆抽取（extractMemories / SessionMemory + /init）

- CC 会话中自动识别"值得记住的项目约定"（构建命令、代码风格、坑）写入
  CLAUDE.md / 记忆目录；
- `/init` 扫描仓库一键生成项目说明文档。

Aetherlink 已读 AGENTS.md、有 memory 功能，缺"自动抽取 → 用户确认 → 回写"
的闭环。这是长期使用体验差距最大的一项：没有它，每个新任务都要重新踩坑。

## 2. 第二梯队：价值高但工作量大

### 2.1 Task V2（带依赖的任务系统）

CC 正从 TodoWrite 迁移到 Task 工具族（TaskCreate/TaskGet/TaskList/TaskStop）：

- 条目有稳定 id、`blockedBy` 依赖关系、owner（归属哪个 agent）；
- UI 能显示"被 X 阻塞"、多 agent 归属着色；
- 与后台 agent 群（swarm）协作配套。

是 update_plan 的下一代形态。建议等出现"多子代理长期协作"需求时再上，
否则复杂度收益比不划算。

### 2.2 Git worktree 隔离（Enter/ExitWorktreeTool）

让智能体在独立 git worktree 里做实验性改动：失败直接丢弃 worktree，
不污染主工作区。Aetherlink 有 git 集成与检查点（可回滚），worktree 是
更彻底的隔离——检查点是"事后恢复"，worktree 是"根本不碰"。

### 2.3 浏览器工具（WebBrowserTool）

CC 能驱动真浏览器（导航/点击/截图/读 DOM）。Aetherlink 目前只有
fetch / searxng / metaso 纯文本抓取，对需要登录、交互、JS 渲染的页面无能为力。
移动端可行路径是 WebView 桥接（InAppWebView + JS 注入），工程量不小。

## 3. 第三梯队：锦上添花

| 功能 | CC 对应 | Aetherlink 现状 | 备注 |
| --- | --- | --- | --- |
| 下一步建议 | PromptSuggestion | ask_user 建议答案面板已有交互位 | 回合结束后生成快捷回复条，复用现有面板 |
| 技能发现 | DiscoverSkillsTool + skillSearch | 有 skill_read_tool，无搜索 | 按需搜索技能而非全量注入定义，省上下文 |
| review 预设 | /review、/security-review | profile 体系可直接承载 | 做成一键启动的内置智能体档案 |
| 文件送达 | SendUserFileTool | — | 移动端对应"分享文件到系统" |

## 4. 不建议移植

- IDE / 桌面集成（teleport、chrome 扩展、statusline、vim 模式）——终端/桌面形态专属；
- 语音输入（voice/STT）——可用系统输入法语音替代；
- 插件市场、遥测/analytics、rate-limit 体系——投入产出比过低。

## 5. 已对齐项（无需移植）

| 能力 | CC | Aetherlink |
| --- | --- | --- |
| 计划工具 | TodoWrite（全量覆盖、结果回填、严格校验、全完成清空） | update_plan 同语义 |
| 计划模式 | Enter/ExitPlanModeTool | enter/exit_plan_mode |
| 计划提醒 | todo_reminder（10 轮/10 轮双阈值节流置尾） | 同款 system-reminder |
| 状态栏 | spinner 显示 in_progress activeForm | 状态条/等待指示同款 |
| 子代理 | AgentTool（隔离 + 并行 + background） | spawn_subagent 同款 |
| 压缩 | compact + microcompact（读写工具结果折叠） | 同有 |
| 检查点 | file snapshots + /rewind | CheckpointEvent + 回滚 |
| hooks | PreToolUse/PostToolUse/Stop 等 | agent hooks 同有 |
| 权限 | permission rules + 审批 | 权限规则 + approval gate |
| 打断/排队 | 运行中输入排队、Esc 打断 | L3 排队注入 + 立即打断 |
| 技能 / MCP | SkillTool / MCPTool | 技能 + MCP 同有 |
