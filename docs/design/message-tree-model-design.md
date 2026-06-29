# Aetherlink Flutter — 消息树模型重构 设计文档

> **版本**: v0.3（实施中，已落地 PR-1/2/3 + PR-5 后端）
> **日期**: 2026-06-28（v0.3 更新于 2026-06-30）
> **状态**: PR-1/2/3 已合入 main；PR-4(多模型发送 + 对比 UI) 已落地；PR-5(话题内分支 +
> 分支切换器 UI) 已落地；PR-6 分支管理**轻量版**(列表 sheet) 已落地，完整画布留后续。
> 实际落地与对本设计的偏离见 **§10 实施记录**（务必先读它再改代码）。
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

- **#467** 消息操作 Headless 重构（动作=数据，多渲染层）——本次树重构后，「创建分支 / 切换版本 / 多模型对比」等动作仍走这套 builder。按钮只发动作、不关心底层是扁平还是树，所以「点一下就切」的手感可原样保留（详见 §6-A）。
- **#468** 创建分支按确定性顺序截断（止血）——本次重构是它的**根治版**，落地后 `compareMessagesChronologically` 在分支路径上不再需要。
- **进行中（并行任务）** 备份导入器重构（分支 `devin/...-backup-domain-migration`）：分领域 migrator + 对数校验 + 自选 UI + 流式。约定「**存储名/表结构/键名不动，只改 UI 与新版代码**」，故**不**改 schemaVersion。与本任务的交叉点见 §5.4，**两者不可同时盲改 `backup_service.dart` 后硬合**。

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
JSON 里，排序在内存做。**已定（2026-06-29）：随 v7 一起把 `createdAt` 提为列**，不
延后。理由——这次本就在改 schema，顺手加一列几乎零成本（回填逻辑本来就要按
`createdAt` 排序），延后则将来又得为它单开一次迁移。提列后兄弟组内可按时间定位、分
页也更省。

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

### 5.4 与「备份导入器重构」并行任务的交叉点（重要）

备份导入器重构（见 §0.4）约定**不动 schema**，本任务则把 schema 升到 **v7** 并给每
个话题加一个虚拟根。两者会在 `backup_service.dart` 上产生**文本冲突**，且有两处
**语义**必须协调：

1. **对数校验要排除虚拟根**：v7 后每话题多一行 `role=root` 的消息。导入器若按「消息
   裸行数」做对数校验，老备份（无虚拟根）恢复进 v7 库会数不上、**误报「丢数据」**。
   校验应**只数内容消息（排除 `role=root`）**，或按领域计数而非裸行数。
2. **恢复路径要重建树**：把 v7 之前的老备份恢复进 v7 库时，消息没有
   `parentId/role/siblingsGroupId`、话题没有 `activeNodeId`，会违反 CHECK/FK。恢复需
   **复用 §5 的 `buildMessageTree` 回填 + 建虚拟根**（与 onUpgrade 同一套逻辑），不能
   直接裸写。另外恢复当前以 `messageIds` 作顺序来源（`backup_service.dart` 写
   `topicJson['messageIds']`），本任务降级 `messageIds` 后，恢复顺序应改由树/`createdAt`
   决定。

**落地顺序（已定）**：备份导入器重构不动 schema、风险低且已在做，**先合**；本任务
随后 rebase，并承接上述集成改动（导入器换实现的成本归本任务）。两边切忌同时盲改
`backup_service.dart` 后硬合。

---

## 6. 关键决策点（已于 2026-06-29 拍板）

**A. 版本历史是否并入树？**
Cherry 没有独立 `versions`，编辑/重生成都是「兄弟」。我们当前有
`Message.versions` + `currentVersionId`，UI 也按版本切换做。
- 选项 1（小步）：保留 `versions` 不动，只把**分支/多模型**上树。改动最小。
- 选项 2（彻底）：版本也变兄弟，删 `versions`。结构最统一，但 UI（版本切换
  popup/arrows）与迁移更复杂。
- **已定 → 选项 1**：保留 `versions` 不动，版本留到二期；先把树骨架、分支、多模型
  跑通。理由：版本切换 UI（`_VersionSwitcher` 的 popup/arrows，
  `message_bubble_actions.dart`）已可用，选项 2 要重写该 UI + 迁移更复杂，收益仅
  「结构更统一」，不值当。选项 1 下该按钮**一行不用改**，原版「点一下就切」手感 100%
  保留。

**B. `createBranch` 的新语义**
- 选项 1：保留「克隆成新话题」（话题级分支），额外**新增**话题内树分支（同话题
  切换路径）。两种并存，UI 上「创建分支」可二选一。
- 选项 2：彻底改为话题内树分支，废弃克隆。
- **已定 → 选项 1**：先加话题内分支（树模型的核心价值），克隆改名「另存为新话题」
  保留，避免破坏现有习惯。

**C. `createdAt` 是否提列**：**已定 → 这次就提列**（不延后），理由见 §3.1。

**D. 分支管理画布的范围**：**已定 → 轻量版先行**（分支列表 + 切换，PR-6 轻量版），
完整可视化画布（节点图 + 拖拽 + 禁用分支）留到后续或二期。

---

## 7. 分阶段、可回滚的 PR 拆分

> 每个 PR 独立可合、行为可控；前半段「结构就绪但不改变用户可见行为」，后半段才接入
> 新交互。
>
> **执行策略（已定）**：先只做 **PR-1 ~ PR-3**（建结构 + 回填 + 读取切换，对用户
> 完全无感），做完停下来复盘、验证稳定后，再决定是否继续 PR-4 及之后的交互部分。
> 即便中途叫停，也已收获「顺序变成结构性事实」的根治效果，沉没成本最小。

1. **PR-1 Schema + 实体（仅新增，零行为变化）** — ✅ 已合入（schema v6→v7）
   - `MessageRows` 加列 + `parentId` 普通索引；`Message`/`Topic` 加字段；
     `MessageRole.root`。CHECK/FK 不做(应用层保证)；**单根偏唯一索引已在 v8→v9 加上
     (`WHERE role='root'`)**，见 §10 偏离 1。
2. **PR-2 迁移回填（行为仍不变）** — ✅ 已合入（schema v7→v8）
   - onUpgrade 跑 `buildMessageTree` 回填 + 建虚拟根 + `activeNodeId`；幂等、非破坏。
   - **迁移前自动备份未做**（见 §10 偏离 2）。读取仍走旧排序。
3. **PR-3 读取路径切换到树** — ✅ 已合入（纯代码，无 schema 变更）
   - `getBranchMessages`（活动路径 + 兄弟摞平，**带按时间回退**）取代展示排序；
     `saveMessage` 中心化挂树（懒建根 + `parentId` + 推进 `activeNodeId`）。
4. **PR-4 多模型上树** — ✅ 已落地（发送管线 + mentions + 对比 UI）
   - 读取已能摞平兄弟组；发送管线 `ChatController.sendMultiModel`（建兄弟组 +
     并行流式）+ mentions 暂存 + 对比分组控件 + 「采用某兄弟」均已完成，见 §10 偏离 6。
5. **PR-5 话题内分支 + 删除语义** — ✅ 已落地（后端 + 分支 UI）
   - 后端：`setActiveNode`/`switchToBranch`/`switchActiveBranch`、`deleteMessage(cascade)`
     reparent/子树删、`clearTopicMessages`、`getChildren`/`getRootMessageId`。
   - UI：叉路 `◀ k/n ▶` 分支切换器 + 「从此处分叉」动作 + 克隆改名「另存为新话题」。
     见 §10 偏离 7（含 getBranchMessages 回退条件的改动）。
6. **PR-6 分支管理画布（轻量版→完整版）** — 🟡 轻量版已落地（分支管理列表 sheet）
   - 轻量版：顶部工具栏「分支管理」按钮（`TopToolbarComponent.branchManagerButton`）打开
     `branch_manager_sheet`——整棵树的缩进列表 + `N 分支 · M 节点` 统计 + 用户/助手/当前/
     已禁用 图例，点节点 = `switchToBranch`。见 §10 偏离 8。
   - 完整版（自绘节点图 + 平移缩放 + 小地图，对应 cs `TopicMessageFlow`/React Flow）留后续。
7. **PR-7（二期，可选）版本并入树**：决策点 A 选项 2 时才做。 — ⬜ 未开始

> 验证现状：单测覆盖树构建/回填/读写/排序；`flutter analyze lib` 0 error。仓库既有
> chat_page widget 测试因更早的工具栏 PR 已失效（与本重构无关）。

---

## 8. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 迁移把存量历史弄乱顺序 | PR-2 保证「迁移后线性路径 == 迁移前排序」，对照测试；迁移前自动备份。 |
| Drift 对 CHECK/偏唯一/自引用 FK 支持有限 | 用 `customStatement` 原始 SQL；onCreate/onUpgrade 两路都补；测真机 SQLite。 |
| 备份跨版本兼容 | v7 只新增不删旧字段，旧版可读；`backup_service` 同步 bump 并测往返。 |
| 多模型/孤儿组边界 | 直译 Cherry `buildMessageTree` 的孤儿/fallback 分支并补对应单测。 |
| 改动面大、易回归 | 严格按 §7 分 PR，前 3 个 PR 不改变用户可见行为。 |
| 与「备份导入器重构」并行改 `backup_service.dart` | 见 §5.4：备份任务不动 schema、**先合**，本任务后 rebase 承接集成；对数校验排除虚拟根、恢复走 `buildMessageTree`；两边不可同时盲改后硬合。 |

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
（注意：Cherry 里首条 `parentId=null`；我们改为挂到**虚拟根**。）

---

## 10. 实施记录（实际落地与对本设计的偏离）

> 实现期对原设计做了几处有意调整。改代码前**先读这里**，别按旧设计「纠正」回去。

### 已落地的关键实现点（与文件位置）

- **实体/列**：`Message.parentId`/`siblingsGroupId`、`Topic.activeNodeId`、`MessageRole.root`；
  `MessageRows` 把 `parentId/role/siblingsGroupId/createdAt` 提升为真实列 + `idx_messages_parent_id`。
- **树构建**：`lib/features/chat/domain/message_tree_builder.dart` — `buildMessageTree` /
  `findActiveNodeId` / `validateTree` / `orderBranchMessages`（活动路径 + 兄弟摞平）。
- **回填**：`lib/features/chat/data/message_tree_backfill.dart`，由 `app_database` v7→v8 调用。
- **读写挂树**：`ChatRepositoryImpl.saveMessage` 中心化挂树 + 懒建根；`getBranchMessages`
  做显示投影并**按时间回退**（投影不全则退化为时间排序，绝不丢消息）。
- **分支/删除后端**：`setActiveNode`/`getChildren`/`getRootMessageId`/`clearTopicMessages`、
  树感知 `deleteMessage({cascade})`；`ChatController.switchToBranch`。
- **根过滤**：`MessageDao.getByTopicId` 默认过滤 `role=root`（结构根不进任何展示/逻辑）。

### 与设计的偏离（及原因）

1. **DB 级 CHECK / 自引用 FK：不做，改应用层保证。** SQLite 不能对已存在表 ALTER 加表级
   CHECK/FK（需 12 步重建，重而险），Drift 声明式支持也有限。单根额外由下面的偏唯一索引
   在 DB 层兜底；root⇔null-parent 等其余不变量由 `buildMessageTree`/`saveMessage` 在应用
   层保证。

   **偏唯一索引：已加（v8→v9），但 scoping 改为 `WHERE role='root'`，不是设计里的
   `WHERE parentId IS NULL`。** 关键原因：Cherry 有 CHECK 使「null-parent ⇔ root」，我们
   没有——**内容消息也可能合法地 parentId=NULL**(回填前的扁平行、以及**老备份经 DAO 直接
   恢复**的行)，用 `parentId IS NULL` 会把第二条这种行误判为重复根而拒绝(恢复/seed 直接
   炸)。`role='root'` 精确只约束根。迁移按「**先 `repairMessageTree` 修复(去重根 + 重挂
   NULL-parent 残留) → 再 `CREATE UNIQUE INDEX`**」的标准配方,onCreate 也补建一次。

2. **PR-2 未在迁移内自动备份（§5.3 原计划）。** 原因：在 `onUpgrade` 里跑 backup_service
   有死锁/路径风险，且回填非破坏(不删旧字段)、可由回退代码恢复，备份收益不抵风险。

3. **`buildMessageTree` 修正了 Cherry 源码的一处 bug。** 当未选中成员排在 `foldSelected`
   成员之前时，Cherry 代码会让后续用户消息错挂到前者；我们按其**文档化意图**(跟随选中
   回复)在 foldSelected 命中时清空 fallback。见 builder 内注释 + 单测。

4. **PR-5 只落地后端，分支 UI 待做。** 切换器/「新建分支」按钮需成对才有意义(造分支入口
   = `switchToBranch(较早节点)` 后发送即自动分叉)。UI 层与 PR-4 多模型 UI 一并留给后续。

5. **`MessageRole.root` 引发的穷尽 switch 编译破坏**已在 `openai_compatible_adapter`、
   `chat_search_dialog` 补防御分支。**加枚举值后务必跑全量 `flutter analyze`**。

6. **PR-4 多模型发送已落地（发送管线 + mentions + 对比 UI）。** 关键实现点：
   - **发送管线**：`ChatController.sendMultiModel(text, models)` —— 建 1 条 user 消息
     （记 `mentions`），再为每个模型建 1 条 streaming assistant 兄弟（**共享 user 的
     `askId` + 同一 `siblingsGroupId(>0)`**），`Future.wait` 并行流式。直译自 web
     `useMultiModelSend` + cherry 兄弟组语义，结合本项目 `saveMessage` 中心化挂树。
   - **复用 `_streamInto`**：给它加 `finalizeTurn` 参数 —— 兄弟流各自持久化/更新自身视图
     但不提前结束话题 streaming、不重复跑「标题/建议/记忆/预览」副作用；协调器在全部
     兄弟 settle 后统一 finish + 跑一次副作用。**首个兄弟落到活动路径**（saveMessage 因
     其 parent==活动叶子而推进 activeNodeId），其余共享父+组，靠 `orderBranchMessages`
     摞平显示。
   - **`StreamingRegistry` 改为每话题多 token**（`Map<topicId, List<token>>`）：Stop 取消
     全部兄弟，原单 token 行为是其 1 元素特例。
   - **mentions 暂存**（同 web）：`multiModelMentionsProvider` 暂存所选模型，输入框上方显示
     芯片；`send()` 检测到 mentions 即路由到 `sendMultiModel` 并清空（一次性）。入口为既有
     `多模型发送` 输入框按钮（原 `_comingSoon` 占位）→ `多选模型 sheet`。
   - **对比 UI**：`ChatMessageView` 加 `askId`/`siblingsGroupId`/`foldSelected`；消息列表把
     连续同组兄弟收进 `MultiModelMessageGroup`（横向/纵向/单栏 fold，跟随 `多模型布局` 设置
     + 组内可切）。对齐 web/cs：**每个 cell 只是普通气泡 `ChatMessageBubble`（模型名由气泡
     自带页脚渲染，不再加 per-cell 模型名头）+ 选中边框**；模型名与「采用」统一收进菜单栏的
     **模型 chip 列表**（点击 chip = `selectSibling`）。唯一偏离：chip 列表在所有布局都显示
     （参考仅 fold 显示），以保留「采用」入口。「采用」→ `ChatController.selectSibling` =
     `setActiveNode` + 翻转组内 `foldSelected`，后续对话从该兄弟延续。
   - **决策回顾**：版本仍走 `versions`（决策 A 选项 1），多模型是当前唯一运行期 `siblingsGroupId`
     组的创建者；`siblingsGroupId` 取话题内 `max+1` 保证组内唯一。

7. **PR-5 分支 UI 已落地（分支切换器 + 从此处分叉 + 另存为新话题）。** 关键实现点：
   - **getBranchMessages 回退条件改动（重要）**：原来「投影长度 ≠ 全部内容 → 退化为时间
     排序」会让**任何叉路**都退化（off-path 分支永远摞平显示），导致分支切换不生效。改为
     「投影**非空**即采信」——非空投影是权威活动路径，**有意**排除 off-path 分支（叉路 +
     多模型未选成员）；仅当投影**为空**（无根/无活动节点/有环/活动节点不达根，即损坏或老
     扁平数据）才退化时间排序。既保证分支能真正隐藏另一支，又保留「损坏树不丢消息」。
   - **分支检测**：`ChatMessageView.branchSiblingIds` —— 在 `build()`/`_load` 里算：某显示
     消息的父节点若有多个 `siblingsGroupId==0` 的常规分支子节点，则记下这些兄弟 id（按时间
     序）。多模型组（gid>0）不参与（由对比控件负责），属有意 scoping。
   - **切换器控件**：`message_bubble_actions.dart` 的 `_BranchSwitcher`（仿 `_VersionSwitcher`
     箭头样式）在 `MessageMicroBubbles`（功能气泡模式）里显示 `◀ k/n ▶`，环形切换，调
     `ChatController.switchActiveBranch(headId)`；后者**下潜到该分支最深叶子**（沿 foldSelected
     或最后一个子节点）再 `setActiveNode`，从而切到整条分支而非只到分叉点。
   - **动作**：消息菜单加 `从此处分叉`（`MessageActionId.fork` → `switchToBranch(本节点)`，下次
     发送即在此分叉）；原克隆 `创建分支` 改名 `另存为新话题`（决策 B 选项 1），二者并存。
   - **已知小缺口**：通过「从此处分叉 + 发送」刚建出的叉路，切换器要到下次重载（切话题/刷新/
     再次切换分支）才出现——发送的实时视图不带 branchSiblingIds（在 `_load` 算）。不影响切换
     本身，留作后续优化。

8. **PR-6 完整画布（分支管理）已落地。** 对应 cherry `TopicMessageFlow` 画布
   （`src/renderer/components/chat/messages/flow/`，基于 React Flow）的**完整移植**——
   自绘节点图而非缩进列表：
   - **入口**：新增 `TopToolbarComponent.branchManagerButton`（GitBranch 图标，顶部工具栏，
     可在 DIY 布局里增删/摆放）。
   - **建图**：`flow/branch_flow_graph.dart` —— 纯函数 `buildBranchFlowGraph(messages, rootId,
     activeNodeId)`（直译 cherry `topicMessageFlowGraph`），算出节点 + 边 + stats，标
     `isActive/isOnActivePath/isInactiveBranch/isSiblingBranch`；边态 `active/inactive/sibling/
     normal`（直译 `getEdgeState`）。`branchCount` 直译 `countBranchPaths`（叶子数>1 取叶子数
     否则 0）。
   - **布局**：`flow/branch_flow_layout.dart` —— 自洽的 TB 树形坐标（叶子占列、父节点居中于子
     节点跨度），替代 cherry 的 dagre 依赖（数据是树，叶子打包布局即足够且确定）。
   - **画布**：`flow/branch_flow_canvas.dart` —— `InteractiveViewer + CustomPaint` 自绘：节点卡片
     （角色/模型/预览/状态/时间）+ 状态着色连线（绿=当前路径、灰虚线=已禁用、兄弟分支）+
     平移缩放 + 缩放控件（+/−/复位）+ 右下角小地图 + 图例。点节点 = `switchToBranch`（设为
     活动叶子，对话跳到该分支）。节点预览用 `getMessageBlocksByIds` 一次性批量取首个 main_text。
   - **测试**：`buildBranchFlowGraph` + `layoutBranchFlowGraph` 单测（线性 0 分支 / 叉路已禁用
     标记 + 叶子计数 / 助手兄弟分支 / 空话题 / 布局父子坐标）。

### §5.4 备份交叉点的现状
备份导入器重构（PR #473/#474）已先合入。恢复**老备份**进 v8 库时，消息无树字段，
`getBranchMessages` 的**按时间回退**会让其正常显示(只是该话题暂非严格树形)；尚未在恢复
路径接入 `buildMessageTree` 回填——留作后续（不影响当前显示）。
