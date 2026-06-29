# Aetherlink Flutter — 消息树模型重构 设计文档

> **版本**: v0.1（待评审）
> **日期**: 2026-06-28
> **状态**: 设计阶段（只出文档，未动代码）
> **范围**: 把「话题内消息」从扁平 + 时间戳排序，重构为 Cherry Studio v2 式的
> **树模型**（`parentId` + `activeNodeId` + 虚拟根），从根上消除分支错位，并为
> 「分支管理画布」「多模型兄弟组」「版本切换」提供统一结构。

---

## 0. 给「新会话」的导读（先读这一节）

这份文档是为**后续一个独立会话**准备的实施蓝图。那个会话开工前请按顺序读完：

### 0.1 需要看的仓库

| 仓库 | 角色 | 备注 |
|---|---|---|
| `1600822305/Aetherlink-flutter` | **重构目标**（Dart/Flutter） | 本次改动落在这里 |
| `CherryHQ/cherry-studio`（本机已克隆于 `~/repos/cherry-studio`） | **树模型参考实现**（TS/Electron） | 只读参考，不改 |
| `1600822305/AetherLink` | 旧 Web 版（TS） | 仅作历史类型来源参考，一般不必动 |

### 0.2 Cherry v2 参考文件（读这些理解「目标长什么样」）

- `cherry-studio/docs/references/chat/message-tree.md` — **树模型权威说明**（结构 / 不变量 / 删除语义 / 消费契约），必读。
- `cherry-studio/src/main/data/db/schemas/message.ts` — 目标 schema（`parentId` / `siblingsGroupId` / 虚拟根唯一索引 / CHECK 约束）。
- `cherry-studio/src/main/data/migration/v2/migrators/README-ChatMigrator.md` — 扁平→树迁移的字段映射与数据质量处理清单。
- `cherry-studio/src/main/data/migration/v2/migrators/mappings/ChatMappings.ts` — `buildMessageTree()`（扁平数组→`parentId`/`siblingsGroupId`）算法，可几乎直译到 Dart。
- `cherry-studio/v2-refactor-temp/docs/chat/message-tree-virtual-root.md` — 虚拟根设计补充。

### 0.3 AetherLink-flutter 现状文件（读这些理解「现在长什么样」）

| 文件 | 作用 |
|---|---|
| `lib/features/chat/domain/entities/message.dart` | `Message` 实体（JSON blob）。当前有 `askId`、`versions`、`currentVersionId`、`foldSelected`，**没有** `parentId`/`siblingsGroupId`。 |
| `lib/features/chat/domain/entities/message_version.dart` | `MessageVersion`（编辑/重生成历史）。 |
| `lib/shared/domain/topic.dart` | `Topic`（JSON blob）。有 `messageIds` 但**未被当作权威顺序**；**没有** `activeNodeId`。 |
| `lib/features/chat/domain/message_ordering.dart` | `compareMessagesChronologically` — 当前「权威顺序」的来源（createdAt + id 兜底），PR #468 的止血点。 |
| `lib/features/chat/application/chat_controller.dart` | 读取/渲染、多模型生成、版本管理。`L170` 处按 `compareMessagesChronologically` 排序得到展示列表。 |
| `lib/features/chat/application/sidebar_controllers.dart` | `createBranch`（`L531`）当前实现 = **克隆成新话题**（扁平），不是树内分支。 |
| `lib/features/chat/data/datasources/local/messages_table.dart` | Drift 表：`MessageRows(id, topicId, assistantId, data JSON)`。整条消息是 JSON blob。 |
| `lib/features/chat/data/datasources/local/message_dao.dart` | 消息 DAO（按 topicId 查询等）。 |
| `lib/features/chat/data/repositories/chat_repository_impl.dart` | `ChatRepository` 实现。 |
| `lib/features/chat/domain/repositories/chat_repository.dart` | `ChatRepository` 接口（约 30 个方法）。 |
| `lib/core/database/app_database.dart` | Drift 数据库，`schemaVersion = 6`，`MigrationStrategy`（下一版应为 v7）。 |
| `lib/features/backup/data/backup_service.dart` | 备份/恢复，依赖 `schemaVersion`，schema 改动需同步评估。 |

### 0.4 现有相关 PR（背景）

- **#467** 消息操作 Headless 重构（动作=数据，多渲染层）——本次树重构后，「创建分支 / 切换版本 / 多模型对比」等动作仍走这套 builder。
- **#468** 创建分支按确定性顺序截断（止血）——本次重构是它的**根治版**，落地后 `compareMessagesChronologically` 在分支路径上不再需要。

---

## 1. 背景与问题

### 1.1 现状

Aetherlink-flutter 一个话题的消息是**扁平集合**：`MessageRows` 按 `id` 主键存
JSON blob，按 `topicId` 建索引。展示顺序、创建分支的截断点，都靠
`compareMessagesChronologically`（`createdAt`，并列时用 `id` 兜底）**每次重排推断**
出来，而不是一个持久化的事实。多模型回复靠 `askId` 关联到提问的用户消息、
`foldSelected` 标记当前选中；版本历史挂在 `Message.versions` + `currentVersionId`。

### 1.2 问题（为什么要重构）

1. **顺序是「推断」不是「记录」**：`createdAt` 会并列（导入、批量、同一毫秒），
   `id` 兜底只是近似。PR #468 用确定性比较器止了血，但根因——**缺少权威顺序字段**
   ——仍在。
2. **分支语义弱**：`createBranch` 是「克隆整段前缀到新话题」，不是结构上的「从某
   节点长出一条新路径」。无法可视化整棵对话树、无法在同一话题内切换分支。
3. **同一能力多处实现**：多模型(`askId`/`foldSelected`)、版本切换(`versions`)、
   分支(克隆) 各写各的，彼此不共享结构。

### 1.3 目标 / 非目标

**目标**
- 顺序成为**结构性事实**：每条消息 `parentId` 指父，话题 `activeNodeId` 指当前叶
  子，「当前对话」= 从 `activeNodeId` 沿父链走到（不含）虚拟根。
- 分支 / 多模型兄弟组 / 编辑重发 统一为「在某父节点下挂子 / 兄弟 + 移动
  `activeNodeId`」。
- 提供「分支管理画布」所需的直接读库能力（整棵树 + 当前路径 + 禁用分支）。
- 平滑迁移存量数据（扁平→树），零丢失、可回滚。

**非目标**
- 不在本次引入 Cherry 的 FTS5 全文检索（`message_fts`）——与树模型正交，单列。
- 不改 `MessageBlock` 存储方式（Cherry 把 blocks inline 进 `data.parts`，我们保留
  现有「blocks 表 + blockIds」结构，降低迁移面）。
- 不改消息操作 Headless 架构（#467），只在其 builder 里替换分支/版本动作的底层调用。

---

## 2. 目标模型（对齐 Cherry v2）

### 2.1 结构

一个话题的消息是一棵**邻接表树**：

```
root            (role=root, parentId=NULL, 无内容, 不渲染)
 ├─ user "v1"  ┐
 ├─ user "v2"  ├─ 同一兄弟组（siblingsGroupId>0）：「重发第一条」= 普通兄弟
 └─ user "v3"  ┘
       └─ assistant → user → assistant → …
```

| 字段 | 含义 |
|---|---|
| `parentId` | 父消息 id；**仅虚拟根为 NULL**。 |
| `siblingsGroupId` | `0`=普通单分支；`>0`=同一父下的多模型兄弟组成员。 |
| `topic.activeNodeId` | 当前选中的叶子；读取路径从它往上走父链。空话题为 NULL。 |
| `role` | `user`/`assistant`/`system`，或 `root`（虚拟根哨兵）。 |

### 2.2 虚拟根

每个话题恰好一个**无内容虚拟根**（`role=root`, `parentId=NULL`）。所有真实消息挂
在它下面，第一轮用户消息及其重发就是虚拟根下的普通兄弟——「重发第一条」与任何兄
弟创建结构一致，不会出现多个物理根。

### 2.3 不变量（尽量交给存储层，而非约定）

| 不变量 | 由谁保证 |
|---|---|
| 每话题恰好一个（存活）虚拟根 | 偏 `UNIQUE` 索引 `(topicId) WHERE parentId IS NULL`。 |
| `role=root` ⇔ `parentId IS NULL` | CHECK `(role='root') = (parentId IS NULL)`；内容消息必有父。 |
| `activeNodeId` 不指向虚拟根 | 空话题为 NULL，否则为内容消息；读取时丢弃根。 |
| 虚拟根只能随话题删除而删除 | `delete()` 硬拒绝；话题 FK `ON DELETE CASCADE` 是唯一删除路径。 |

> **注**：当前 Aetherlink-flutter 把 `Message` 整条存成 JSON blob（`MessageRows.data`）。
> 要让上面这些「索引 / CHECK / 自引用 FK」生效，必须把 `parentId` / `role` /
> `siblingsGroupId` 提升为**真实列**（见 §3）。

---

## 3. Schema 改动（Drift, v6 → v7）

`messages_table.dart` 当前：`id`(PK) / `topicId` / `assistantId` / `data`(JSON)。
新增**真实列**（值同时仍冗余在 `data` JSON 里，保持单一实体序列化不变）：

```dart
class MessageRows extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text()();
  TextColumn get assistantId => text()();
  TextColumn get data => text().map(const MessageConverter())();

  // 新增（树模型）
  TextColumn get parentId => text().nullable()();          // 虚拟根为 NULL
  TextColumn get role => text()();                         // user/assistant/system/root
  IntColumn  get siblingsGroupId => integer().withDefault(const Constant(0))();
  // createdAt 已在 data 里；为排序/查询可选提升为列（见 §3.1）
}
```

索引 / 约束（drift 用 `@TableIndex` + 自定义 SQL 迁移补 CHECK/偏唯一索引）：

- `idx_messages_topic_id`（已有，保留）
- `idx_messages_parent_id`（新增，`on parentId`）—— 取子节点 / 建树
- 偏唯一索引 `messages_topic_root_uniq on (topicId) where parentId IS NULL`
- CHECK `messages_root_parent_check: (role='root') = (parentId IS NULL)`
- 自引用 FK `parentId -> messages.id ON DELETE CASCADE`（删子树一把删）

> Drift 对 `CHECK` / 偏唯一索引 / 自引用 FK 的声明支持有限，**用
> `Migrator.customStatement` 在 onUpgrade 里执行原始 SQL** 补齐，并在
> `onCreate` 后也补一遍（参考 Cherry `MESSAGE_FTS_STATEMENTS` 那种「Drizzle 不管的
> SQL 单独执行」的做法）。

`topics_table.dart` / `Topic`：新增 `activeNodeId: String?`（话题 blob 内即可，因
为话题本就整体 JSON 存储，无需列）。`messageIds` 字段可保留（兼容备份），但**不再
作为顺序来源**，最终可在后续清理中废弃。

### 3.1 createdAt 是否提列

Cherry 用 `index(topicId, createdAt)` 支持分页与时间序。我们当前 `createdAt` 在
JSON 里，排序在内存做。**建议**本次把 `createdAt` 也提为列（便于「兄弟组内按时间
定位」「分页」），但非强制；若不提列，兄弟排序退化为读出后内存排序，可接受。

---

## 4. 实体 / 仓库 / 控制器改动

### 4.1 实体

- `Message`：加 `String? parentId`、`@Default(0) int siblingsGroupId`。`role` 已有
  `MessageRole`，需新增 `root` 取值（见 `message_role.dart`）。`askId` /
  `foldSelected` 保留一段时间（迁移期回填用），后续清理。
- `Topic`：加 `String? activeNodeId`。

### 4.2 `ChatRepository`（domain 接口）新增/改动方法

> 命名对齐 Cherry `MessageService`，但用我们的 repo 风格。

- `getRootMessageId(topicId)` / 建话题时 `createRootMessage(topicId)`（事务内）。
- `getPathToNode(topicId, nodeId)` → 从 `activeNodeId`（或指定 node）走父链到根，
  **不含根**，得到「当前对话」列表（取代 `getMessagesByTopicId + sort`）。
- `getTree(topicId)` → 整棵树（节点 + 兄弟组 + `activeNodeId` + `rootId`），喂给
  分支管理画布。
- `getChildren(parentId)` / `getSiblings(parentId, siblingsGroupId)`。
- `setActiveNode(topicId, nodeId)`（切换分支 / 切换版本即移动指针）。
- `deleteMessage(id, {cascade})`：`cascade=false` 把子节点 reparent 到祖父再删；
  `cascade=true` 删整棵子树（靠自引用 FK CASCADE）。
- `clearTopicMessages(topicId)`：删所有非根行 + `activeNodeId=null`，保留虚拟根。

### 4.3 控制器

- `chat_controller.dart`
  - 展示列表：`L170` 的 `getMessagesByTopicId..sort(...)` → 改为 `getPathToNode`。
  - 新消息：把 user 节点挂到当前 `activeNodeId` 下，assistant 节点挂到该 user 下，
    生成后 `setActiveNode = 新叶子`。
  - 多模型：N 个 assistant 共享同一 `parentId` + 同一 `siblingsGroupId(>0)`，
    `foldSelected` 语义 → 「兄弟组内被选中的成员就是位于当前路径上的那个」。
  - 版本切换：编辑/重生成产生**兄弟**而非 `versions` 数组？（见 §6 决策点）。
- `sidebar_controllers.dart`
  - `createBranch`：从「克隆成新话题」改为可选两种语义（见 §6 决策点 B）。

---

## 5. 数据迁移（扁平 → 树）

参考 `ChatMigrator` + `buildMessageTree`，但我们是**库内原地迁移**（drift onUpgrade
v6→v7），不是跨库导入，所以更简单：没有 Dexie/Redux 双源、blocks 不需要 inline。

### 5.1 迁移步骤（每个话题独立处理，放在一个写事务里）

1. 建该话题的**虚拟根**行（`role=root`, `parentId=NULL`）。
2. 读出该话题全部消息，按 `compareMessagesChronologically` 得到**线性顺序**（与现
   有展示顺序一致，保证迁移前后看起来不变）。
3. 跑 `buildMessageTree(linear)`（直译 Cherry 算法）：
   - 普通顺序消息：`parentId = 上一条`。
   - 多模型：同 `askId` 且出现多次 → 分配 `siblingsGroupId>0`，`parentId = askId`
     指向的用户消息。
   - 用户消息跟在多模型组后：链到组内 `foldSelected`（或最后一个）成员。
   - 孤儿组（用户消息已删）：组内共享一个 fallback parent。
4. 第一轮消息（线性首条）的 `parentId` 从 `NULL` 改挂到**虚拟根 id**（满足 CHECK）。
5. 写回每条消息的 `parentId` / `siblingsGroupId` / `role`。
6. 计算并写话题 `activeNodeId`：原「当前/末选中」→ `foldSelected` → 最后一条
   （对齐 Cherry `findActiveNodeId`）。

### 5.2 数据质量处理（照搬 Cherry 清单的适用项）

- 重复 message id（跨话题）→ 重新生成并改 parent 引用。
- `topicId` 不一致 → 以所在话题为准。
- 全部消息为空的话题 → 保留话题，`activeNodeId=null`。
- `askId` 指向已删消息 → 孤儿组 fallback parent。

### 5.3 安全性

- 迁移前自动触发一次备份（`backup_service`），并记录 `schemaVersion`。
- 迁移在单事务内，失败回滚；提供 dry-run 校验（节点数、根唯一性、无环、每节点
  可达根）。
- **回滚策略**：v7 仅新增列 + 回填，不删旧字段（`askId`/`foldSelected`/`messageIds`
  保留），所以旧版本 App 读同库仍可用扁平路径——保证可回退一个版本。

---

## 6. 关键决策点（需用户/评审拍板）

**A. 版本历史是否并入树？**
Cherry 没有独立 `versions`，编辑/重生成都是「兄弟」。我们当前有
`Message.versions` + `currentVersionId`，UI 也按版本切换做。
- 选项 1（小步）：保留 `versions` 不动，只把**分支/多模型**上树。改动最小。
- 选项 2（彻底）：版本也变兄弟，删 `versions`。结构最统一，但 UI（版本切换
  popup/arrows）与迁移更复杂。
- **建议**：先选项 1，版本留到二期；先把树骨架和分支跑通。

**B. `createBranch` 的新语义**
- 选项 1：保留「克隆成新话题」（话题级分支），额外**新增**话题内树分支（同话题
  切换路径）。两种并存，UI 上「创建分支」可二选一。
- 选项 2：彻底改为话题内树分支，废弃克隆。
- **建议**：选项 1，先加话题内分支（这才是树模型的价值），克隆作为「另存为新话题」
  保留，避免破坏现有习惯。

**C. `createdAt` 是否提列**：见 §3.1，建议提列但可延后。

**D. 分支管理画布的范围**：本期是否做完整可视化画布（节点图 + 拖拽 + 禁用分支），
还是先做一个「分支列表 + 切换」的轻量版？建议轻量版先行。

---

## 7. 分阶段、可回滚的 PR 拆分

> 每个 PR 独立可合、行为可控；前半段「结构就绪但不改变用户可见行为」，后半段才接入
> 新交互。

1. **PR-1 Schema + 实体（仅新增，零行为变化）**
   - `MessageRows` 加列 + 索引/CHECK/FK（customStatement）；`Message`/`Topic` 加字
     段；`schemaVersion 6→7` 的 `onUpgrade` 只建列、不回填。
   - `MessageRole.root`。
   - 单测：迁移建列成功、读写新字段往返。
2. **PR-2 迁移回填（行为仍不变）**
   - onUpgrade 内跑 `buildMessageTree` 回填 `parentId/siblingsGroupId/activeNodeId`
     + 建虚拟根 + 迁移前备份。
   - 校验器 + 充分单测（多模型、孤儿组、空话题、并列时间戳、长历史）。
   - 此时读取路径仍走旧 `getMessagesByTopicId+sort`，确保「迁移不改变可见顺序」。
3. **PR-3 读取路径切换到树**
   - `getPathToNode` 取代展示排序；新消息写入挂树 + 移 `activeNodeId`。
   - 行为应与 PR-2 一致（同一条线性路径），但顺序此后由结构决定。回归测试对照。
4. **PR-4 多模型上树**
   - 多模型生成写兄弟组；渲染读兄弟组；`foldSelected`→当前路径成员。
5. **PR-5 话题内分支 + 删除语义**
   - `setActiveNode` 切换分支；`deleteMessage(cascade)` reparent/子树删除；
     `clearTopicMessages`。
   - 消息操作 builder（#467）接「从此节点分支」「切换分支」动作。
6. **PR-6 分支管理画布（轻量版→完整版）**
   - `getTree` + 画布 UI（节点/当前路径/禁用），对齐用户截图的 Cherry 画布。
7. **PR-7（二期，可选）版本并入树**：决策点 A 选项 2 时才做。

每个 PR 都满足：`flutter analyze` 改动文件零告警、带单测、不破坏备份/恢复。

---

## 8. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 迁移把存量历史弄乱顺序 | PR-2 保证「迁移后线性路径 == 迁移前排序」，对照测试；迁移前自动备份。 |
| Drift 对 CHECK/偏唯一/自引用 FK 支持有限 | 用 `customStatement` 原始 SQL；onCreate/onUpgrade 两路都补；测真机 SQLite。 |
| 备份跨版本兼容 | v7 只新增不删旧字段，旧版可读；`backup_service` 同步 bump 并测往返。 |
| 多模型/孤儿组边界 | 直译 Cherry `buildMessageTree` 的孤儿/fallback 分支并补对应单测。 |
| 改动面大、易回归 | 严格按 §7 分 PR，前 3 个 PR 不改变用户可见行为。 |

---

## 9. 附：Cherry `buildMessageTree` 输入/输出示例（迁移直译目标）

```
输入(线性): [u1, a1, u2, a2, a3(askId=u2,foldSelected), a4(askId=u2), u3]
输出:
 u1: {parentId: <root>, siblingsGroupId: 0}
 a1: {parentId: u1, siblingsGroupId: 0}
 u2: {parentId: a1, siblingsGroupId: 0}
 a2: {parentId: u2, siblingsGroupId: 1}
 a3: {parentId: u2, siblingsGroupId: 1}   // 选中
 a4: {parentId: u2, siblingsGroupId: 1}
 u3: {parentId: a3, siblingsGroupId: 0}   // 跟在选中的兄弟后
```
（注意：Cherry 里首条 `parentId=null`；我们改为挂到**虚拟根**以满足 CHECK。）
