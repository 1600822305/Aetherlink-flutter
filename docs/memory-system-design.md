# AetherLink Flutter 记忆系统设计文档

> 状态：设计稿 v1　|　目标：在 Flutter 版从零构建全新记忆系统
> 技术栈：Dart + drift (^2.34) + sqlite3_flutter_libs（端上、离线可用）

---

## 0. 背景与目标

Flutter 版目前没有记忆系统，仅有占位 UI（助手编辑的「记忆」tab、设置里的「记忆功能」入口，均为"即将支持"）。

本设计要实现一个**全新的记忆系统**，满足：

1. **两种记忆形态**：普通聊天用 / 智能体用（项目后续会新增独立的智能体聊天界面）。
2. **强隔离**：两种形态在召回层绝不互相串味。
3. **端上自洽**：纯 Dart + drift，不依赖外部服务，离线可用，移动端友好。

参考来源：原版 AetherLink(web) 记忆系统、Cherry Studio v1 主记忆系统、Cherry Studio v2 cherryclaw agent 工作区记忆、以及 mem0 / Zep(Graphiti) / Letta / MemMachine 的公开设计。

---

## 1. 总体架构：一个内核，两种形态

```
┌─────────────────────────────────────────────────────────┐
│  L2 记忆策略层 (Strategy)                                  │
│    ├─ ChatMemoryStore   普通聊天记忆（全局 / 助手）         │
│    └─ AgentMemoryStore  智能体记忆（FACT / JOURNAL / 图）   │
├─────────────────────────────────────────────────────────┤
│  L1 隔离层 (MemoryScope) —— 检索强制过滤，永不跨形态        │
├─────────────────────────────────────────────────────────┤
│  L0 共享内核 (MemoryEngine)                                │
│    drift 存储 · sqlite-vec 向量检索 · Embedding · 去重 ·   │
│    混合检索 · history 审计                                  │
└─────────────────────────────────────────────────────────┘
```

- **L0 共享内核**：所有记忆共用一套底层能力（embedding 生成、向量检索、去重、drift 读写、历史审计）。不关心是 chat 还是 agent。
- **L1 隔离层**：每条记忆都带 `MemoryScope`，所有检索 API 必须传 scope，内部强制 WHERE 过滤。
- **L2 策略层**：两种 Store 实现不同的写入策略 / 数据结构 / 检索时机，但都复用 L0。

---

## 2. 隔离模型（核心）

### 2.1 统一 Scope

两种形态用**同一套对称的两级模型**：都分「全局」和「私有」。

```dart
enum MemoryKind  { chat, agent }
enum MemoryLevel { global, owner }   // 全局 / 私有(归某个助手或智能体)

class MemoryScope {
  final MemoryKind  kind;     // chat | agent —— 硬隔离第一维
  final MemoryLevel level;    // global | owner —— 共享/私有第二维
  final String? ownerId;      // level=owner 时：chat=assistantId；agent=agentId
}
```

四个记忆桶（kind × level），彼此在召回层隔离：

| 桶 | kind / level / ownerId | 含义 |
|---|---|---|
| 聊天-全局 | chat / global / — | 所有助手通用的用户偏好 |
| 聊天-助手 | chat / owner / assistantId | 某助手私有 |
| 智能体-全局 | agent / global / — | 所有智能体通用的知识/约定 |
| 智能体-私有 | agent / owner / agentId | 某智能体私有 |

### 2.2 普通聊天记忆的两级（按用户确认）

聊天记忆分**全局记忆**和**助手记忆**两级：

| 级别 | scope | 含义 | 注入哪些会话 |
|---|---|---|---|
| 全局记忆 | `kind=chat, level=global` | 用户级、所有助手通用的偏好/事实 | 所有聊天 |
| 助手记忆 | `kind=chat, level=owner, ownerId=<assistantId>` | 仅属于某个助手的记忆 | 仅该助手的聊天 |

> 检索某个助手的对话时，召回集 = **全局记忆 ∪ 该助手记忆**；写入时由策略 / 工具决定写到哪一级（默认自动提取写助手级，用户手动标记"全局"时写全局级）。
> 备注：`话题(topic)` 不作为记忆隔离维度，只作为 metadata（`topicId`）记录来源，便于溯源与维护。

### 2.3 智能体记忆的隔离（与聊天对称：全局 + 单个智能体）

智能体记忆和聊天记忆**采用同样的两级**：

| 级别 | scope | 含义 | 注入哪些会话 |
|---|---|---|---|
| 全局记忆 | `kind=agent, level=global` | 所有智能体通用的知识、约定、教训 | 所有智能体 |
| 智能体记忆 | `kind=agent, level=owner, ownerId=<agentId>` | 仅属于某个智能体 | 仅该智能体 |

> 检索某智能体时，召回集 = **智能体-全局 ∪ 该智能体私有**。和聊天完全对称，心智负担最小。

**关于「会话/工作记忆」**：这是和"全局/私有"**正交的另一根轴**——它是*时效*问题不是*归属*问题，因此不放进 scope，而是用 `memType` + `sessionId(metadata)` 表达：
- `FACT`（长期）、`JOURNAL`（事件）→ 持久，按上面两级归属。
- `working`（会话工作记忆）→ 临时，绑定 `sessionId`，会话结束即清理/过期，不参与长期召回。

这样既满足你"智能体也分全局和私有"的诉求，又不丢掉智能体做任务时需要的短期暂存。

> 跨形态桥接（可选，默认关闭）：是否允许智能体读取「聊天-全局」里的用户偏好，做成开关；默认严格隔离。

### 2.4 物理隔离策略

- **单表 + scope 列**（推荐）：备份/同步/迁移简单，靠复合索引 `(scope_kind, owner_id, sub_scope, is_deleted)` 保证查询性能。
- 所有 `search/list` 必须传 `MemoryScope`，Store 内部强制拼 `WHERE scope_kind=? AND scope_level=? AND (owner_id=? OR scope_level='global') ...`。
- **跨形态绝对隔离**：`kind=chat` 与 `kind=agent` 永不出现在同一次召回里。

---

## 3. 两种形态对比

| 维度 | 普通聊天记忆 (chat) | 智能体记忆 (agent) |
|---|---|---|
| 目的 | 记住**用户**偏好/事实，跨会话个性化 | 记住**任务/工作区**的知识、决策、教训 |
| 主体 | 全局用户 / 助手 | 智能体 / 会话 |
| 写入方式 | **被动自动**：对话后 LLM 提取事实 + ADD/UPDATE/DELETE 决策；+ 可选记忆工具 | **主动**：agent 调 `agent_memory` 工具 remember/update/append；+ 可选自动 |
| 数据结构 | 扁平记忆条目 + category | 分层：FACT(长期) / JOURNAL(事件) / WorkingMemory / 可选实体-关系图 |
| 检索时机 | 每轮对话前语义检索 → 注入 `<user_memories>` | 工具按需查 + 会话开头注入 `## Workspace Knowledge`(FACT) |
| 维护 | Dream 自维护（聚类/合并/过期/重嵌入） | 轻量，主要靠 agent 自更新 + 定期整理 |
| 时效处理 | 双时态可选 | 双时态更重要（任务状态频繁变化） |

---

## 4. 普通聊天记忆设计（借鉴 mem0 + 原版 web）

直接把原版 web 的 `MemoryService` / `MemoryProcessor` / maintenance(Dream) 逻辑翻成 Dart。

### 4.1 写入
- **autoAnalyze（默认）**：对话后取最近 N 轮 → LLM 提取事实(`fact_retrieval` prompt) → 取现有记忆 → LLM 给出 `ADD/UPDATE/DELETE/NONE` 决策 → 落库。
- **memoryTool（可选）**：暴露 `create_memory / edit_memory / delete_memory`，让模型在对话中主动记。
- **手动**：用户在「记忆」tab 手动增删改；可标记为"全局"或"私有级"。

### 4.1.1 写入级别策略（按用户确认）
**全局级和私有级都可以开自动提取，由用户自由开关 + 也支持手动标记。** 具体：
- 两个独立开关：`自动写入私有记忆`、`自动写入全局记忆`（默认：私有开、全局可选）。
- 当两个都开时，自动流程在 `ADD/UPDATE` 决策里**多一步分级判断**：LLM 判断该事实是"通用偏好"(→全局) 还是"仅当前助手/智能体相关"(→私有)；写入对应 level。
- 用户随时可在「记忆」tab 手动把某条记忆在 全局 ↔ 私有 之间**移动 / 标记**（移动即改 `scope_level`/`owner_id`，并记 history）。
- 同一策略适用于聊天(助手)与智能体两侧——开关与标记入口各自独立。

### 4.2 检索
- 每轮对话前用用户输入做 `search(scope = 全局 ∪ 助手)`，向量余弦 + 文本降级，结果注入 system prompt 的 `<user_memories>` 块。

### 4.3 维护（Dream）
- harvest（回顾补提）/ purge（清软删）/ reembed（重算向量）/ cluster（近重复聚类）/ consolidate（LLM 合并/过期/冲突解决），带 API 预算保护。

---

## 5. 智能体记忆设计（借鉴 CS v2 cherryclaw + Letta + 知识图谱）

三类记忆（参考 MemMachine 的 Working/Episodic/Profile）：

- **WorkingMemory（短期）**：当前 session 上下文，可不持久或短持久。
- **FACT（长期知识）**：约定、教训、项目惯例、之前失败过的参数形态等。会话开头注入系统提示（CS v2 `buildFactsSection` 模式）：
  ```
  ## Workspace Knowledge
  <facts> ... </facts>
  ```
- **JOURNAL（事件日志）**：完成的任务、会话笔记，可搜索。
- **可选 EntityGraph**：entities / relations / observations（CS 的 MCP memory server 那套），做结构化关系记忆。

### 5.1 接口：`agent_memory` MCP 工具
让智能体**主动**管理记忆：
```
agent_memory(action: "update" | "append" | "search" | "recall", ...)
  update  → 覆盖写 FACT（长期知识）
  append  → 追加 JOURNAL 事件
  search  → 检索 JOURNAL / 记忆
  recall  → 召回相关记忆注入上下文
```

---

## 6. 共享内核与抽象（Dart 代码层）

```dart
// L0 内核：被两种 Store 共用
class MemoryEngine {
  final AppDatabase db;            // drift
  final EmbeddingService embedder; // OpenAI 兼容 /embeddings
  Future<List<double>> embed(String text);
  Future<List<ScoredMemory>> vectorSearch(List<double> q, MemoryScope s, {...});
  Future<List<MemoryItem>> textSearch(String q, MemoryScope s, {...});
  // 去重(hash + 相似度)、history 审计、软删除等
}

// L2 策略
abstract class MemoryStore {
  Future<MemoryItem?> add(String content, MemoryScope scope, {MemoryMetadata? meta});
  Future<List<MemoryItem>> search(String query, MemoryScope scope, {int limit, double threshold});
  Future<MemoryItem?> update(String id, String content, {MemoryMetadata? meta});
  Future<bool> delete(String id);          // 软删除
  Future<List<MemoryItem>> list(MemoryScope scope, {int limit, int offset});
}

class ChatMemoryStore  extends MemoryStore { /* 向量 + 提取 + Dream */ }
class AgentMemoryStore extends MemoryStore { /* FACT/JOURNAL/graph + 工具 */ }
```

所有查询经 `MemoryScope` 强制隔离。

---

## 7. drift schema 草案

```dart
// 主记忆表
class Memories extends Table {
  TextColumn get id => text()();
  TextColumn get scopeKind => text()();          // 'chat' | 'agent'
  TextColumn get ownerId => text()();            // userId/'global' | agentId
  TextColumn get subScope => text().nullable()(); // assistantId | sessionId
  TextColumn get memType => text()();            // chat: 'fact'; agent: 'fact'|'journal'|'working'
  TextColumn get content => text()();
  TextColumn get hash => text()();               // sha256 去重
  BlobColumn get embedding => blob().nullable()(); // F32_BLOB（配合 sqlite-vec）
  TextColumn get embeddingModelId => text().nullable()(); // 跨模型向量隔离
  TextColumn get category => text().nullable()();
  TextColumn get source => text().nullable()();  // auto | manual | dream | agent
  RealColumn get confidence => real().nullable()();
  // 双时态（借鉴 Zep）：解决"记忆过期/被推翻"
  DateTimeColumn get validFrom => dateTime().nullable()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get metadata => text().nullable()(); // JSON: topicId/messageId/tags...
}

// 历史审计表（借鉴 CS v1 memory_history）
class MemoryHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get memoryId => text()();
  TextColumn get previousValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get action => text()();             // ADD | UPDATE | DELETE
  DateTimeColumn get createdAt => dateTime()();
}

// 索引: (scopeKind, ownerId, subScope, isDeleted)、hash、createdAt
```

### 向量检索：sqlite-vec
- 用 `sqlite-vec` 扩展（可与 `sqlite3_flutter_libs` 一起加载）做原生向量相似度，等价 CS v1 用 libsql 向量列的方案。
- 若移动端加载扩展受限，降级为 **Dart 端余弦相似度 + 模长缓存**（原版 web 的做法）。两种实现都藏在 `MemoryEngine.vectorSearch` 后面。

---

## 8. 落地顺序

1. **共享内核 + 隔离 + schema**：drift 表、`MemoryScope`、`MemoryEngine`、sqlite-vec 接入（含 Dart 端降级）。
2. **ChatMemory（先上）**：翻译 web 版 `MemoryService`/`MemoryProcessor`，把占位 UI（助手记忆 tab + 设置「记忆功能」）接上 → 普通聊天先能用。
3. **AgentMemory（后上）**：FACT/JOURNAL + `agent_memory` MCP 工具，等新智能体聊天界面就绪再接。
4. **增量增强**：Dream 维护、双时态生效、BM25 + Rerank 混合检索（原版 `AdvancedSearchOptions` 已预留）。

---

## 9. 待确认事项

1. ~~全局记忆的写入触发~~ ✅ 已定（§4.1.1）：全局/私有都可开自动提取，用户自由开关 + 手动标记。
2. **跨形态桥接**：是否需要"智能体读取聊天-全局用户偏好"的开关（默认关闭、严格隔离）。
3. **sqlite-vec 在目标移动平台（iOS/Android）能否稳定加载**：决定是否一开始就走 Dart 端余弦降级。
