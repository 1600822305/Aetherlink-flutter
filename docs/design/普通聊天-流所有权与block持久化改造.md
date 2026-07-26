# 普通聊天 — 流所有权与 block 持久化改造

> 日期：2026-07-27
> 前置文档：[`docs/普通聊天模式-缺陷与性能分析.md`](../普通聊天模式-缺陷与性能分析.md)
> 调研对象（本地源码）：`K:\Flutterworkspace\cherry-studio`、`kelivo_ref`、`Aetherlink-original`

---

## 0. 为什么是这两件事

缺陷分析给出的 P0/P1 里，有两组不是笔误而是**架构选型的后果**，修单点只能治标：

| 症状 | 根 |
|---|---|
| P0 继续生成丢内容 | block 持久化是「删光重写」，任何调用方漏传都升级为数据丢失 |
| P2 checkpoint 写放大 | 同上 |
| P1 退出聊天页打断流 + 永久泄漏 | 流的执行体寄生在 autoDispose 的 `ChatController` 的 Ref 上 |
| P1 连发双流 + 停止失效 | 流的所有权没有单一归属，守卫是异步快照而非同步登记 |

本文记录调研结论与改造方案，并标注已落地与待办部分。

---

## 1. 调研：流的所有权

### 1.1 关键发现

`K:\Flutterworkspace\cherry-studio` 当前 HEAD **已不是我们当初参照的 v1**（Redux + messageThunk + abortMap），而是重构后的 v2。其设计文档 `docs/references/ai/stream-manager.md:26-36` 把 v1 的三个结构性 bug 列了出来，第一条是：

> window-bound lifecycle：卸载聊天组件会 abort 上游请求

**这正是我们的 P1-3。** 我们继承了 v1 的病，而上游已经给出了修法。

### 1.2 三个参考实现对比

| | Cherry v2 | kelivo_ref | Aetherlink-original |
|---|---|---|---|
| 流的宿主 | 主进程单例 `AiStreamManager`，`activeStreams: Map<topicId, ActiveStream>` | 常驻页面 controller，`_conversationStreams: Map<convId, StreamSubscription>` | 全局 thunk / module 单例 |
| UI 卸载 | **detach 不 abort**，切回时 attach + 环形缓冲回放 | 页面永不 pop，回避了问题 | 不穿透 UI 生命周期，天然无此问题 |
| cancel 归属 | 每 execution 自己的 `AbortController`，两级 key（topicId + modelId） | 全局静态表，key = conversationId | 全局 `abortMap`，key = askId |
| 并发互斥 | per-topic `KeyedMutex` + steer 队列 | loading 集合 + 深度 1 排队 | **无**（只有 UI 按钮软约束） |
| 收尾落盘 | 专职 `PersistenceListener` | ChatActions 各终态路径 | CompletionHandler（有双写竞争） |

证据锚点：
- `cherry-studio/src/main/ai/streamManager/AiStreamManager.ts:187`（activeStreams）、`:188-190,240-256`（KeyedMutex 注释直指「并发 open 竞争 hasLiveStream 快照产生孤儿 PENDING 行」——即我们 `chat_controller.dart:412→:540` 的竞态）、`:483-513`（steer 队列）
- `cherry-studio/src/renderer/services/aiTransport/IpcChatTransport.ts:212-222`（「Main keeps generating and persists the result; abort is a separate IPC」）
- `kelivo_ref/lib/features/home/controllers/chat_controller.dart:59-66`、`home_view_model.dart:366-377,443-460`（深度 1 排队）
- `Aetherlink-original/src/shared/utils/abortController.ts:9`（我们「finish 清空整个 token 列表」的来源）

### 1.3 结论

**移植 Cherry v2 的模型，取 kelivo 的两个务实细节（深度 1 排队、幂等收尾）。**

映射到 Riverpod 很自然：我们已经有 keepAlive 的 `StreamingRegistry`，问题只是它**只存产出**（liveViews、token），流的执行体与依赖读取仍寄生在 autoDispose controller 上。

不抄：
- Cherry v2 的 IPC / 多窗口 / 环形缓冲回放 —— 为多进程设计，Flutter 单 isolate 内 registry 状态天然共享
- kelivo 的「流跟着常驻页面走」—— 靠路由约定回避问题，我们的 ChatPage 会 pop，抄了就是原地复发
- kelivo 的同 key 自动 `cancel('replaced')` —— 静默打断上一条流，且与多模型并行冲突
- Cherry 的 steer 队列 —— 语义复杂（step 边界 yield、continuation 链），深度 1 排队足够
- Aetherlink-original 整套流控 —— 我们现在的两个 bug 都源自它，是被替换的对象而非范本

---

## 2. 调研：block 持久化粒度

### 2.1 关键发现

**这里结论与上一节相反：不要跟 Cherry v2。**

两个用 block 表的参考实现（Cherry v1、Aetherlink-original）语义完全一致：

> 块实体表（id 主键 + messageId 索引）+ `message.blocks` 引用数组 + **逐块节流 upsert** + 完成即终态单写 + **显式按 id 删除**

**从未使用 delete-all-rewrite。**

- Cherry v1：`message_blocks: 'id, messageId, file.id'`（`src/renderer/databases/index.ts:101`）；流式回调 dispatch `upsertOneBlock`，DB 侧 `throttledBlockDbUpdate`（`docs/references/messaging/message-system.md:115,153,189-192`）
- Aetherlink-original：`SmartThrottledBlockUpdater` 每个 blockId 一个独立 throttle（`ResponseChunkProcessor.ts:128-233`），默认 500ms；块完成时取消 throttler 并立即 flush（`:264-303`）；落库是单块 `update(blockId, {...})`（`DexieStorageService.ts:565-576`）

而 Cherry v2 反向演化成「取消独立 block 表、parts 内联 JSON、只在终态落盘」（`MessageServiceBackend.ts:26-34`）——桌面端接受崩溃丢整轮，**移动端进程随时被系统杀，不可接受**；parts 内联还会让每次更新重写整条消息，重新引入写放大。

### 2.2 我们反而更好的地方

启动自愈 `settleInterruptedMessages`（`interrupted_settlement.dart`）比两个 Dexie 参考都完整——它们崩溃后没有自愈，残留永久 streaming 态块。**保留。**

checkpoint 链（`checkpointChain`，串行 chained future）也优于 Aetherlink-original 的 fire-and-forget 非事务写。**保留。**

### 2.3 崩溃安全对比

| 实现 | 机制 | 崩溃丢多少 |
|---|---|---|
| Cherry v1 / Aetherlink-original | 边流边写（150ms / 500ms per-block throttle） | 最后一个节流窗口 |
| Cherry v2 | 只在终态写 | 整轮回复 |
| kelivo | 每 chunk 全量覆盖整条消息 | 几乎不丢，但 O(n²) 写放大 |
| 我们（改造前） | 每 2s 全量 delete+rewrite | 最后 2s，但代价是全量重写 |
| 我们（改造后） | 每 2s **增量** upsert 尾部脏块 | 最后 2s，写量降到 1~2 块 |

---

## 3. 改造方案

### 3.1 block 持久化 ✅ 已落地

**核心：把「删光重写」拆成「增量 upsert」+「显式 prune」，先 upsert 后 prune。**

任何时刻持久化的块集都是新旧内容的**超集**，交错的 checkpoint 或中途崩溃都不可能观察到空洞。

| 文件 | 改动 |
|---|---|
| `message_block_dao.dart` | 新增 `getIdsByMessageId` —— 只投影 id，不加载 payload |
| `chat_repository.dart` / `chat_repository_impl.dart` | 新增 `upsertMessageBlocksAndSync`（纯增量，**不删任何东西**）、`pruneMessageBlocks(keepIds)`；`replaceMessageBlocks` 重写为「事务内 upsert → save message → prune」 |
| `interrupted_settlement.dart` | `persistMessageBlocks` 保留为终态路径；新增 `checkpointMessageBlocks`（增量）；抽出 `_syncedMessage` 消除重复 |
| `turn_stream_binder.dart` | `checkpointBlocks()` → `checkpointDelta()`，返回 `(脏块, 完整有序 id 列表)`；新增 `persistedCompletedIds` 集合，完成块只写一次；failover 重置时清空该集合 |
| `chat_controller.dart` | 新增 `_checkpointMessageBlocks` 并注入 binder |

**无需 DB 迁移、无需新索引** —— 现有 id 主键 + messageId 索引已足够，且我们的块 id 在轮内本来就稳定（`roundBlockId`、`'$assistantMessageId::thinking'`）。

效果：
- 每 2s 的写从「该消息全部块 + 1 次 getMessage」降到「1~2 个尾部块」
- P0 的爆炸半径从「物理删除、不可恢复」降级为「引用不全、显示不全」——块实体仍在库里，可按 id 反查找回

### 3.2 P0 继续生成 ✅ 已落地

`chat_controller.dart` 的 `continueGenerating` 现在先读回并按 `message.blocks` 排序已有块，作为 `leadingBlocks` 传入 `_streamInto`，续写真正**追加**到它们后面——与该方法原本的注释一致。

### 3.3 流所有权 —— 分 5 阶段

**阶段 1（止血）✅ 已落地**

`StreamingRegistry` 改为 per-turn token 语义：
- 新增 `releaseToken(topicId, token)`，流结束时由 `emitTurnEnd` 归还
- `finish(topicId)` 在该话题**仍有未归还 token 时直接返回**，不再清空共享状态

这解掉「一条流结束导致同话题另一条流无法取消 + 绿点提前消失」。多模型场景不受影响：siblings 各自归还，协调者的 finish 在全部归还后才生效。

**阶段 2（根治 dispose 崩溃）⬜ 待办**

新建 `lib/features/chat/application/send/chat_turn_engine.dart`：

```dart
@Riverpod(keepAlive: true)
class ChatTurnEngine extends _$ChatTurnEngine { ... }
```

- 持有 `TurnStreamBinder`，binder 的 `_refOf` 改为返回**引擎的 ref**（keepAlive，永不失效，"ref used after dispose" 从根上消失）
- binder 现有 7 处 `_ref.read` 的目标全是 keepAlive provider，无需改动
- `TurnFinisher`、`MessageViewProjector` 同样挪到引擎名下
- 提供 `runTurn(TurnPlan)` 入口，`send/regenerate/resend` 与四个 mode service 改为交给它执行

验证：发送后立刻 pop ChatPage → 无异常，流跑完、消息落库、registry 条目清除、前台保活服务停止。

**阶段 3（订阅翻转）⬜ 待办**

`_emitTurn` 一分为二：registry 更新由引擎直接做；「若是当前话题则更新屏上 state」改为 controller 在 `build()` 里 listen registry。即 Cherry v2 attach/detach 语义的 Riverpod 表达——controller 死了流照跑，回来重建时 `chat_controller.dart:331` 的 liveViews 分支自然接上。

**阶段 4（互斥收口）⬜ 待办**

`runTurn` 内 `Map<String, Future<void>> _turnByTopic`，进入时同步检查 + 登记（检查与登记在同一同步段，无竞态窗口），替换 `send()` 的异步快照守卫。

**阶段 5（可选）⬜**

kelivo 式深度 1 排队；Cherry 式终态宽限期（终态后 registry 条目保留数秒，供刚好切回的页面拿到最终帧）。

### 3.4 阶段 2 的已知风险

- binder 回调对 `views` 列表存在**原地可变共享**（`_replace` 就地改传入的 list），搬迁时须确认引擎持有自己的副本，否则出现两处引用同一 list 的写竞争
- `_toolExecutor`（`chat_controller.dart:101-109`）依赖 `assistantId/topicId` 闭包，搬进引擎后须改为 per-turn 参数
- 工具审批（`toolConfirmationProvider.request` 是 await 用户点击）在页面 pop 后无人应答，需要决定：自动拒绝，还是保留等用户回来（Cherry 是后者）
- `_emitSuggestions`、`_truncatedMessageId` 等 controller 私有态与 turn 结果相关，翻转订阅后需经 registry 或独立 provider 传递

---

## 4. 当前状态

已落地（`flutter analyze` 零错误，chat 189 项测试全过，新增 2 项持久化语义测试）：

- ✅ block 持久化改为增量 upsert + 显式 prune
- ✅ checkpoint 只写尾部脏块
- ✅ P0 继续生成补传 `leadingBlocks`
- ✅ registry per-turn token（流所有权阶段 1）

待办：流所有权阶段 2–5。

> 注：`test/architecture/import_boundaries_test.dart` 的 2 项与 `workspace_file_history_test.dart` 的 1 项在改动前的干净树上即失败，与本次无关。
