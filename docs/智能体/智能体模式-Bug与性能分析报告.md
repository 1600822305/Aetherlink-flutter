# 智能体模式 — 可复现 Bug 与性能问题分析报告

> 分析范围：`lib/features/agent/`（引擎核心、任务编排、事件落库、流式循环、状态管理、事件流 UI）。
> 分析日期：2026-07-27。
> 结论概要：整体架构（append-only 事件流 + seq 尾链串行化 + 前缀增量折叠 + 按行解码缓存）设计扎实；
> 问题集中在 **runner 层状态机竞态**（用户可感知的"卡死"）与 **长任务的 O(N) 读放大**（卡顿主因）。

---

## 一、可复现 / 高风险 Bug

### BUG-1 「暂停后立刻续跑」竞态 → 任务卡在 running 且无引擎（严重度：高）

**位置**
- `application/agent_task_runner.dart:446-450`（`_run()` 入口守卫）
- `application/agent_task_runner.dart:536-549`（`whenComplete` 清理）
- `application/agent_task_runner.dart:204-213`（`sendMessage` 先落 running 再 `_run`）
- `application/agent_task_runner.dart:285-293`（`resume` 同款路径）

**机制**
`_run()` 开头：

```dart
if (state.contains(task.id)) return;   // 静默 no-op
```

引擎收到 pause 请求后，会在安全点内部先把任务落成 `paused`
（`TaskTransitions.transition` 写穿 → UI 立即显示「已暂停」），
但 runner 要等 `engine.run(...).whenComplete` 执行完才把 taskId 从
`state`（运行中集合）移除。这两个时刻之间存在一个窗口：

1. 用户点「暂停」；
2. 引擎落 `paused`，UI 显示可续跑；
3. **`whenComplete` 尚未执行**（引擎还在做善后：failPendingToolEvents、
   compaction 兜底清理等异步收尾）；
4. 用户立刻点「继续」或发消息 → `resume()`/`sendMessage()` 把任务状态
   写成 `running` 并调用 `_run()`；
5. `_run()` 看到 `state.contains(task.id)` 仍为 true → **静默 return**；
6. 旧引擎随后退出，`whenComplete` 清掉 state；
7. 结果：任务状态是 `running`，但没有任何引擎实例在跑，
   永久停在「运行中」，只能强杀或重启 App 恢复。

**复现步骤**
1. 启动一个长任务（让模型进入多轮工具调用）；
2. 在一次工具执行中点「暂停」；
3. UI 显示「已暂停」后 **立即（<1s）** 点「继续」；
4. 多试几次（窗口大小取决于本轮善后耗时；工具输出大 / 有 compaction
   兜底时窗口更大，成功率更高）；
5. 观察：任务显示「运行中」但事件流不再有任何新事件。

**修复建议**
- `_run()` 无法启动时不要静默返回：要么把刚写的 `running` 状态回滚，
  要么等待旧引擎的 `whenComplete`（可以把在跑 future 存进 map，
  `await` 后重试启动）；
- 或者：`resume`/`sendMessage` 在写 `running` 之前先检查
  `state.contains`，运行中直接拒绝/转排队。

---

### BUG-2 `switchMode` 挂起的模式切换可能残留并延迟错误生效（严重度：中高）

**位置**
- `application/agent_task_runner.dart:345-359`（`switchMode`）
- `application/agent_task_runner.dart:550-571`（`whenComplete` 消费 pending）

**机制**
运行中切模式的流程：`state.contains(task.id)` 为 true →
挂 `_pendingUserModeSwitch[task.id] = newMode` → 请求引擎暂停 →
`whenComplete` 里消费 pending 并以新模式续跑。

问题：`state.contains` 检查与写 map 之间不是原子的。若引擎恰在此刻
自然结束（done/failed/cancelled）且 `whenComplete` 已经跑完，
pending 条目就永远躺在 map 里。后果：

- 该任务**下一次**运行结束时（可能是几小时后的另一次续跑），
  `whenComplete` 突然消费这个陈旧的模式切换；
- 若那次运行以 `paused` 结束，还会把任务**意外自动续跑**
  （`resume: latest.status == paused` 分支）。

**复现步骤**
1. 让任务进入收尾阶段（模型正在输出最终回复）；
2. 恰在任务转 done 的瞬间从模式选择器切换模式（时机敏感，
   可用慢速模型放大窗口）；
3. 之后再让该任务续跑一轮并暂停；
4. 观察：暂停后任务被自动切换到之前选的模式并自动续跑。

**修复建议**
- 挂 pending 后二次校验 `state.contains(task.id)`，已退出则立即
  走非运行中分支（直接落模式）并移除 pending；
- 或给 pending 条目加时间戳，`whenComplete` 消费时丢弃过期条目。

---

### BUG-3 `sendMessage` 中途切模式绕过 `prePlanMode` 簿记（严重度：中）

**位置**
- `application/agent_task_runner.dart:189-207`（`sendMessage` 直接 `copyWith(mode: mode)`）
- `application/agent_task_runner.dart:363-374`（`_withMode`：正确维护 `prePlanMode` / `clearPrePlanMode`）

**机制**
两条切模式路径行为不一致：

| 路径 | prePlanMode 维护 |
|---|---|
| `switchMode()` → `_withMode()` | ✅ 切入 Plan 记录来源模式，切出清除 |
| `sendMessage(mode: …)` → `copyWith(mode: mode)` | ❌ 完全不碰 |

后果：
- 用户经输入栏 chips 把非运行中任务切到 Plan 再发消息 →
  `prePlanMode` 缺失，之后 `exit_plan_mode` 批准时无法恢复原模式
  （`PlanApprovalFlow` 依赖它决定回落到 code 还是 auto）；
- 反向从 Plan 切出时残留的 `prePlanMode` 也不会被清掉，
  留下脏状态影响后续 Plan 流程。

**复现步骤**
1. 建一个 Auto 模式任务，跑完一轮进入 paused/done；
2. 在输入栏用模式 chip 切到 Plan，直接发一条消息（不经模式选择器）；
3. 让模型完成方案并 `exit_plan_mode`，批准；
4. 观察：任务恢复的模式不是 Auto（丢失了 prePlanMode）。

**修复建议**
`sendMessage` 内改用 `_withMode(task, mode)` 生成新任务快照，
与 `switchMode` 共用同一处簿记。

---

### BUG-4 截断续跑额度耗尽后半成品被判 done（严重度：中）

**位置**
- `application/engine/agent_engine.dart:134-135`（`_kMaxLengthContinues = 3`，run 级累计）
- `application/engine/agent_engine.dart:505-519`（截断续跑分支）
- `application/engine/agent_engine.dart:144-145`（`_emptyRetries` 同款问题）

**机制**
`_lengthContinues` 是**整个 run 的累计计数**，不按「连续截断」重置。
长任务中如果出现 3 次彼此独立、都已成功续上的 token 截断
（例如三次长报告输出各截断一次），额度即耗尽；第 4 次截断时
`turn.truncated && _lengthContinues < 3` 不成立，直接落入下方
收尾判定——被截断的半成品输出被当作最终回复标成 `done`。

`_emptyRetries`（整 run 只有 2 次额度）同理：供应商偶发空回复
分散出现 3 次即把零产出判收尾。

**复现建议**
把模型 max_tokens 调小（或选输出上限低的模型）跑一个要求多次长输出
的任务，观察第 4 次截断后任务直接完成且最后一段输出明显被截断。

**修复建议**
成功续跑（后续轮次正常返回非截断 turn）后重置计数器，
把「上限」语义从 run 级改为**连续失败**级；对标聊天侧
`_kMaxAutoContinues` 的重置时机。

---

### BUG-5 冷启动竞态误触发孤儿档案兜底（严重度：中）

**位置**
- `application/agent_task_runner.dart:461-473`

**机制**
`_run()` 用 `ref.read(agentProfilesProvider)` **同步**读取档案列表。
该 provider 是 `build() { _hydrate(); return const []; }` 的异步
hydrate 模式——冷启动早期读到的是空列表。此时若用户（或恢复流程）
立刻续跑一个任务，`.firstOrNull ?? 兜底` 会命中「档案已删」分支：

```dart
AgentProfile(id: …, name: '', systemPrompt: '',
             tools: AgentToolGroup.values.toSet());  // 全工具组！
```

后果双重：
1. **静默劣化**：丢失档案的系统提示词/专长配置，任务行为异常但无提示；
2. **权限扩大**：兜底给了全部工具组，比原档案配置的授权范围更大。

**复现步骤**
1. 让一个任务停在 paused（进程中断恢复语义会自动产生）；
2. 冷启动 App 后立刻（在侧栏加载完成前）点该任务的「继续」；
3. 观察本轮系统提示为空、可用工具为全集。

**修复建议**
`_run()` 开头 `await` 档案 hydrate 完成（暴露一个
`Future<void> ready` 或改用 `FutureProvider`）再解析 profile；
兜底分支同时落一条状态事件明示「档案缺失，已用默认配置」。

---

## 二、性能问题

### PERF-1 引擎每轮全量读取 + 解码事件表（最大热点）

**位置**
- `application/engine/agent_engine.dart:284`（每轮 `store.getEvents`）
- `application/engine/agent_engine.dart:539`、`loop/control_tool_flow.dart:280`（收尾判定再各全读一次）
- `data/datasources/local/agent_dao.dart:129-145`（`getEvents`：无缓存逐行 `jsonDecode`）

**影响**
数千事件的长任务里，每轮 LLM 调用前都要 O(N) 全表读取 + JSON 解码；
工具输出大（argsDetail/resultDetail 上百 KB）时解码开销显著，
且运行在主 isolate 上，直接体现为流式期间掉帧。

**建议**
`watchEvents` 已实现按行缓存（`agent_dao.dart:95-126`，
payload 未变复用已解码实例）——把同一套行缓存下沉共享给
`getEvents`，未变更行零解码；或引擎侧维护事件列表增量
（事件基本 append-only，只需追加新事件 + 替换原位更新的行）。

### PERF-2 drift watch 每次写库全表读回

**位置**
- `data/datasources/local/agent_dao.dart:95`（注释自述该问题）
- 写频来源：`loop/streaming_event_writer.dart:20`（文本 200ms 节流）、
  `loop/turn_stream_binder.dart:28`（工具参数 500ms 节流）、工具状态更新

**影响**
流式期间多路节流叠加 ≈ 每秒 3-7 次写库，每次触发 watch 全表
SELECT + 行传输（解码有缓存但查询/IO 本身 O(N)）。
事件数越多 UI 越卡，长任务体验线性劣化。

**建议**
watch 查询窗口化：只 watch 尾部 N 条（如 200）+ 历史一次性读取，
配合时间线折叠器的前缀缓存，语义不变。

### PERF-3 任务行写放大 + 侧栏全量重建

**位置**
- `application/engine/agent_engine.dart:277-282`（每轮 rounds++ save）
- `application/engine/agent_engine.dart:462-477`（每轮 token 统计 save）
- `application/agent_task_providers.dart:89-98`（`AgentTasks.apply` 重建整个列表 state）

**影响**
引擎每轮至少两次任务写回，每次 `apply` 重建整个 `List<AgentTask>` →
所有 watch `agentTasksProvider` 的组件（侧栏话题列表等）每轮
至少重建两次；同时任务 JSON 全量序列化写库两次。

**建议**
合并每轮的两次 save（rounds 与 token 统计一次写回）；
侧栏等消费方用 `select` 只取自己关心的切片。

### PERF-4 `_seqCache` / `_seqLocks` 永不清理

**位置**
- `application/engine/agent_event_store.dart:148-153`

**影响**
按 taskId 的 seq 缓存与锁链只增不减，删除任务后残留。
单条目很小，但属于明确的缓慢内存泄漏（store 是 keepAlive 单例）。

**建议**
`AgentTasks.remove/removeByProfile` 时联动清理对应 taskId 条目。

### PERF-5 多个 running 工具行常驻动画

**位置**
- `presentation/mobile/event_stream/tiles/tool_row.dart:37-44`
  （每个 running 工具一个 `CircularProgressIndicator`）
- `tiles/working_indicator_tile.dart`（WorkingIndicator 同屏叠加）

**影响**
只读并发批次最多 `kMaxConcurrentReadTools` 个工具同时 running，
加上等待指示器，同屏多个无限动画持续逐帧重绘；
与流式文本重建叠加，低端机掉帧明显。

**建议**
running 态换成低频旋转图标（`AnimatedRotation` 慢速）或
多个指示器共享一个 ticker；也可只给视口内最新的 running 行上动画。

---

## 三、低风险观察（不必立即处理）

| 位置 | 观察 |
|---|---|
| `agent_engine.dart:770` | `maybeCompact(current, events)` 复用轮首事件快照，压缩摘要不含本轮产出——注释声明有意为之，语义一致，仅提示。 |
| `work_segment_tile.dart:38` | 缺失 `elapsed` 的工具按 500ms 估算计入段头总耗时，展示值失真。 |
| `agent_tool_stream.dart` | 全局非 autoDispose provider；引擎异常路径若未 `clear`，详情抽屉可能显示残留的旧参数前缀。 |
| `finish_guards.dart:32-40` | `hasFinalReply` 把 `[系统]` 注入消息也当 UserMessageEvent，每次系统注入都重置「有正文」判断；当前与 `finishGuardFired` 一次性标记勉强闭环，改动此处需注意。 |

---

## 四、修复优先级建议

| 优先级 | 项目 | 理由 |
|---|---|---|
| P0 | BUG-1、BUG-2 | 状态机竞态，用户可感知「卡死」/行为错乱 |
| P1 | PERF-1、PERF-2 | 长任务卡顿的主要来源，收益最大 |
| P1 | BUG-3、BUG-5 | 行为正确性（模式簿记 / 权限扩大） |
| P2 | BUG-4、PERF-3 | 边界场景 / 中等收益优化 |
| P3 | PERF-4、PERF-5、低风险观察 | 卫生类清理 |
