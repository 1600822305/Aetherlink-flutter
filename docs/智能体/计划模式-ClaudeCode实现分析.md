# Claude Code 计划模式（Plan Mode）完整实现分析

> 源码基准：`pengchengneo/Claude-Code`（可运行还原版）。
> 目的：为 Aetherlink Agent 引入 CC 式计划模式提供实现蓝本。

---

## 一、总体架构：计划模式不是一个「工具」，而是一个「权限模式」

CC 的权限系统有一个全局的 `toolPermissionContext.mode` 状态机（`src/types/permissions.ts` + `src/utils/permissions/PermissionMode.ts`）：

```
default → acceptEdits → plan → bypassPermissions/auto → default   （Shift+Tab 循环切换）
```

`plan` 是其中一个模式。计划模式的进入/退出有三条路径：

1. **用户手动**：Shift+Tab 循环切换（`getNextPermissionMode.ts`）
2. **模型主动进入**：`EnterPlanMode` 工具（模型判断任务复杂时自己调用）
3. **模型请求退出**：`ExitPlanMode`（V2）工具（方案写完后请求用户批准）

模式切换统一走 `transitionPermissionMode()`（`permissionSetup.ts`），保证无论哪条路径进出，副作用（prePlanMode 存取、退出通知附件）都一致。

---

## 二、三层防护：计划模式如何阻止写入

CC 的只读约束是**三层叠加**，而不是单点拦截：

### 第 1 层：每轮注入的强约束系统提醒（主要手段）

在 plan 模式下，每轮请求前通过 attachment 机制注入 system-reminder（`src/utils/messages.ts:3227`）：

```
Plan mode is active. The user indicated that they do not want you to execute
yet -- you MUST NOT make any edits (with the exception of the plan file
mentioned below), run any non-readonly tools (including changing configs or
making commits), or otherwise make any changes to the system. This supercedes
any other instructions you have received.
```

- 首轮注入完整版（含 Plan Workflow 分阶段指引，见第五节）
- 后续轮注入精简版（`messages.ts:3392`）：「Plan mode still active... Read-only except plan file」
- **唯一例外**：计划文件本身允许编辑（见第 3 层）

### 第 2 层：权限系统兜底（HITL 硬约束）

计划模式下写类工具**并没有从工具列表里移除**（模型仍能看到 Edit/Write/Bash）。
但任何写操作在权限判定里会落到 `behavior: 'ask'`——必须弹窗经用户批准。
即使模型无视提醒去调用写工具，也过不了用户这一关。
（`hasPermissionsToUseToolInner`，`src/utils/permissions/permissions.ts:1158`；
plan 模式唯一放宽是「用户原本就在 bypassPermissions 时进 plan 可继承 bypass」，1270 行。）

### 第 3 层：计划文件白名单

`checkEditableInternalPath()`（`filesystem.ts`）把**本会话的计划文件**列为免审白名单：

```
// 1.5. Allow writes to internal editable paths (plan files, scratchpad)
if (isSessionPlanFile(normalizedPath)) return { behavior: 'allow', ... }
```

这是计划模式里唯一可以静默写入的路径。

> **要点**：CC 靠「提示词约束 + 审批兜底」而不是「隐藏工具」。这样模型在规划时仍知道
> 自己将来有哪些执行能力（能写出更准确的计划），越权时由审批层兜住。
> Aetherlink 现有 Ask/Plan 模式采用的是「从目录移除写工具」的更硬做法，两者可结合。

---

## 三、计划文件（Plan File）机制

CC v2 计划模式的核心改进：**计划不放在对话里，而是落到磁盘文件**（`src/utils/plans.ts`）。

- 路径：`~/.claude/plans/{slug}.md`（slug 为随机词组，会话级缓存；子代理为 `{slug}-agent-{agentId}.md`）
- 首轮 plan_mode 附件告诉模型：
  - 文件已存在 → 「read it and make incremental edits using Edit」
  - 不存在 → 「create your plan at {path} using Write」
- 模型**增量迭代**计划文件（探索一点、写一点），而不是最后一口气输出
- `ExitPlanMode` 被调用时，工具**从磁盘读取计划**（`getPlan()`），不依赖模型把全文塞进工具参数
- 好处：
  1. 长计划不占对话上下文（microcompact/compact 也不会截掉计划）
  2. 用户批准前可在 `$EDITOR` 里直接编辑计划（Ctrl+G），编辑后的版本回写磁盘并标注 `planWasEdited`
  3. 实现阶段可随时 `Read` 回读计划

---

## 四、EnterPlanMode 工具（`src/tools/EnterPlanModeTool/`）

- **无参数**；`isReadOnly=true`、`isConcurrencySafe=true`
- 子代理上下文禁止调用（`context.agentId` 非空直接抛错）
- `call()` 做两件事：
  1. `handlePlanModeTransition(旧mode, 'plan')` —— 清理挂起的退出通知标志
  2. `setAppState`：`mode='plan'`，并通过 `prepareContextForPlanMode()` 把**当前模式存进 `prePlanMode`**（退出时恢复）
- 工具结果注入行为指令：

```
Entered plan mode. ...
1. Thoroughly explore the codebase to understand existing patterns
2. Identify similar features and architectural approaches
3. Consider multiple approaches and their trade-offs
4. Use AskUserQuestion if you need to clarify the approach
5. Design a concrete implementation strategy
6. When ready, use ExitPlanMode to present your plan for approval
Remember: DO NOT write or edit any files yet.
```

- **工具描述（prompt.ts）非常长**，详细列举「什么时候该用/不该用」：
  - 该用：新功能、多种可行方案、改动既有行为、架构决策、多文件改动、需求不明、用户偏好敏感
  - 不该用：单行修复、明确指令、纯调研任务

## 五、计划模式工作流指引（plan_mode 附件全文结构）

首轮注入的完整指引（`messages.ts:3227` 起）把规划过程分成明确阶段：

- **Phase 1 Initial Understanding**：只用 explore 类子代理并行探索代码（最多 N 个），
  主动找可复用的既有函数/模式，避免规划新造轮子
- **Phase 2 Design**：派 plan 类子代理设计实现方案（复杂任务可多个视角并行）
- 期间用 `AskUserQuestion` 澄清需求（明确禁止用它问「计划好了吗」）
- 增量把结论写进计划文件
- 完成后调 `ExitPlanMode` 请求批准

## 六、ExitPlanMode 工具（V2，`src/tools/ExitPlanModeTool/ExitPlanModeV2Tool.ts`）

关键设计：

1. **入参几乎为空**（可选 `allowedPrompts`：申请实现阶段需要的语义化权限，如 "run tests"）——计划正文从磁盘读
2. `validateInput`：**不在 plan 模式时直接拒绝**（错误信息教模型：「计划已批准就继续实现」），防止模型在批准后又误调
3. `checkPermissions` 返回 `behavior:'ask'`、`requiresUserInteraction()=true` —— **必须经用户批准，任何自动放行模式都不能跳过**
4. 批准 UI（`ExitPlanModePermissionRequest.tsx`）提供多个选项：
   - **Yes** —— 批准，恢复 `prePlanMode`
   - **Yes, and auto-accept edits** —— 批准并升级到 `acceptEdits`（实现阶段编辑免审）
   - **No** —— 拒绝，**留在 plan 模式**
   - Ctrl+G 在编辑器里改计划后再批准
5. 批准后 `call()`：
   - `mode` 恢复为 `prePlanMode ?? 'default'`，清空 `prePlanMode`
   - 置 `hasExitedPlanMode` / `needsPlanModeExitAttachment` 标志
6. **工具结果把批准后的计划全文回填给模型**：

```
User has approved your plan. You can now start coding.
Start with updating your todo list if applicable
Your plan has been saved to: {filePath}
## Approved Plan:   （用户改过则标 "edited by user"）
{plan}
```

7. **拒绝路径**：留在 plan 模式，给模型注入
   `PLAN_REJECTION_PREFIX = 'The agent proposed a plan that was rejected by the user.
   The user chose to stay in plan mode rather than proceed... Rejected plan:\n'`
   + 用户的拒绝理由 → 模型据此修订计划再次提交

## 七、退出通知（一次性附件）

不管以哪种方式退出 plan（批准、手动切模式），`needsPlanModeExitAttachment` 标志触发
一次性 `plan_mode_exit` 附件（`attachments.ts:1244`），告诉模型「已不在计划模式，
计划文件在 {path}，可以开始执行」。快速来回切换时标志会被清掉防止双发。

---

## 八、映射到 Aetherlink：现状与差距

### Aetherlink 已有的（不需要重做）

| 能力 | 现状 |
|---|---|
| 任务级 Plan 模式 | `AgentSessionMode.plan` 已存在：只读工具目录（`_catalogFor` readOnly 过滤）、系统提示注入、MCP 外部工具整组不注入 |
| 计划维护 | `update_plan` 控制工具 + PlanPanel 置顶 + 系统提示计划置尾 |
| 一键转执行 | `PlanReadyCard` → `convertPlanToCode()`：改 mode 重启运行 |
| HITL 审批层 | `_PolicyApprovalGate` 三层规则 + `agentApprovalRegistry` 持久化挂起 |
| 澄清问题 | `ask_user` 控制工具（waitingInput 可跨进程恢复） |
| 探索子代理 | plan 模式下已限制只能派 explore 子代理 |

### 相对 CC 的差距（本次要补的）

1. **模型不能主动进入计划模式**：CC 的 EnterPlanMode 让模型在 code 模式遇到复杂任务时
   自己请求先规划；我们只能建任务时手选。
2. **退出没有「方案审批」语义**：我们的 plan 任务跑完（finish_task）后靠 PlanReadyCard
   一键转 code，但没有「模型提交方案 → 用户批准/拒绝（带理由）→ 拒绝留在 plan 修订」
   的闭环；拒绝反馈回不到模型。
3. **没有 prePlanMode 恢复**：从 auto 进 plan、批准后应回 auto 而不是固定 code。
4. **计划正文没有随批准回填**：转 code 后模型只看到「方案已确认」一句话 +
   update_plan 快照，没有完整方案文本的权威版本。

### 实现方案（贴合现有架构，不照搬 CC 的进程内状态）

Aetherlink 的模式绑定在 `AgentTask.mode` 上、每次 `_run` 时按 mode 构建工具目录，
模式切换 = 停当前 leg → 更新 task → 重启（`convertPlanToCode` 已是这个模式）。
沿用这个机制实现两个新的引擎控制工具：

1. **`enter_plan_mode`**（仅 code/auto 模式暴露，子代理不暴露）
   - 引擎内部处理：落 StatusChange 事件、`task.prePlanMode = 当前mode`、
     `task.mode = plan`，结束当前 leg 并以 plan 模式重启循环
   - 工具结果注入 CC 式行为指令（只读探索 + 用 update_plan 维护方案 +
     完成后调 exit_plan_mode）
2. **`exit_plan_mode`**（仅 plan 模式暴露，取代 plan 模式下的「跑完等卡片」）
   - 参数：`plan`（markdown 方案全文）——我们没有会话计划文件，方案随调用提交并落事件
   - 引擎转 `waitingApproval`，走既有审批注册表挂起（无超时、跨进程可恢复）
   - UI：方案审批卡（渲染 markdown 方案 + 批准 / 拒绝并填理由）
   - 批准 → mode 恢复 `prePlanMode`（默认 code），工具结果回填
     「用户已批准方案 + 方案全文」，循环继续进入实现
   - 拒绝 → 留在 plan 模式，工具结果 = 拒绝前缀 + 用户理由，模型修订再提交
3. **`prePlanMode` 持久化**：AgentTask 新字段（进 plan 时记录，退出清空）
4. **每轮提醒**：plan 模式系统提示已有，按 CC 措辞强化（「本消息优先级高于任何其他指令」+
   指向 exit_plan_mode）；退出后首轮由工具结果本身承担「exit 通知」职责
5. **PlanReadyCard 兼容保留**：手动建的 plan 任务跑完仍显示；exit_plan_mode 是模型主动路径

不做的（与移动端架构冲突或收益低）：
- 计划落磁盘文件（我们多后端 + SAF，没有稳定的本地纯文本目录约定；方案走事件流持久化，
  已有落库与置顶展示）
- auto 分类器联动、teammate 邮箱审批、Shift+Tab 循环切换（无对应交互）
- 「写工具仍暴露但靠审批拦」——沿用现有更硬的「只读目录过滤」，规避移动端误触风险
