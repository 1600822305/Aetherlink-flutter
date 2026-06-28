# 聊天记忆系统设计文档（最终 · 务实版）

> 状态：定稿候选 v1
> 范围：**仅普通聊天记忆**。智能体记忆项目尚未开发，本文不实现，仅在隔离模型里预留位置。
> 技术栈：Dart + drift (^2.34) + sqlite3_flutter_libs，纯端上、离线可用、移动优先。
> 本文合并并取代前三份草稿：`memory-system-design.md`（架构）、`memory-brain-science-design.md`（脑科学）、可行性评估。
>
> **三档标注**：【必做】先落地、低风险、立竿见影；【可选】有价值但 ROI 待验证、做成开关；【后置】重、依赖前置、放后面。

---

## 1. 设计原则

1. **脑科学指导，但务实裁剪**：借鉴人脑的"情景/语义双类型、巩固、激活检索、再巩固"，但凡 ROI 不明或移动端做不到的，降级为可选/后置。
2. **永远可退化**：整套检索能一键退回"纯向量相似度"，保证不比现状差。
3. **省钱优先**：用户自带 API key，每轮额外 LLM/embedding 是真金白银（CS v2 砍记忆的头号原因）。默认把昂贵操作批处理、可关。
4. **移动端现实**：没有可靠后台 cron，"巩固"只能机会式触发，不假设真后台。
5. **强隔离**：聊天/智能体两形态、全局/私有两级，召回层绝不串味。
6. **小数据量假设**：单用户记忆约千级，性能非瓶颈；重点在质量、成本、可维护。

---

## 2. 总体架构

```
┌────────────────────────────────────────────────────┐
│  L2 策略  ChatMemoryStore   （本文实现）              │
│           AgentMemoryStore  （预留，未实现）          │
├────────────────────────────────────────────────────┤
│  L1 隔离  MemoryScope { kind, level, ownerId }        │
├────────────────────────────────────────────────────┤
│  L0 内核  MemoryEngine                                │
│    drift 存储 · 向量检索(sqlite-vec/Dart余弦) ·        │
│    Embedding · 去重 · 激活打分 · history 审计          │
└────────────────────────────────────────────────────┘
```

---

## 3. 隔离模型【必做】

```dart
enum MemoryKind  { chat, agent }      // agent 预留
enum MemoryLevel { global, owner }    // 全局 / 私有

class MemoryScope {
  final MemoryKind  kind;   // 本文恒为 chat
  final MemoryLevel level;  // global | owner
  final String? ownerId;    // level=owner 时：assistantId
}
```

聊天记忆两级：

| 级别 | scope | 含义 | 注入哪些会话 |
|---|---|---|---|
| 全局记忆 | `chat / global` | 所有助手通用的用户偏好/事实 | 所有聊天 |
| 助手记忆 | `chat / owner / <assistantId>` | 仅属于某助手 | 仅该助手 |

- 检索某助手会话：召回集 = **全局 ∪ 该助手**。
- 所有 `search/list` 必须带 scope，内部强制 `WHERE scope_kind='chat' AND (scope_level='global' OR owner_id=?)`。
- `话题(topic)` 不作隔离维度，仅存 metadata `topicId` 供溯源/维护。
- `kind=agent` 永不出现在聊天召回里（未来智能体接入时天然隔离）。

---

## 4. 记忆结构：情景 / 语义【必做】

| 类型 | memType | 内容 | 来源 | 是否衰减 |
|---|---|---|---|---|
| 情景记忆 | `episodic` | 带时间的具体经历/原话语境 | 低成本快写 | 是（弱） |
| 语义记忆 | `semantic` | 去情景化的偏好/事实 | LLM 提炼 / 工具 / 手动 | 否（或极弱） |

- **存储强度 vs 检索强度**分离：`importance`（学得牢，几乎不衰减）与"基础激活"（此刻好不好取，随时间掉）是两个独立量。
- **忘 ≠ 删**：低激活只是"想不起来"，仍保留；只有 purge 才真正清理。

---

## 5. 生命周期

### 5.1 编码 / 写入
- **工作记忆**【必做】：最近 N 轮仅作上下文，不落库。
- **语义提炼 autoAnalyze**【必做】：对话后 LLM 提取事实 → 取相关旧记忆 → `ADD/UPDATE/DELETE/NONE` 决策 → 写 `semantic`；hash + 0.85 相似去重。（沿用原版 web `MemoryProcessor` 逻辑翻 Dart。）
- **记忆工具 memoryTool**【可选】：暴露 `create/edit/delete_memory`，模型主动记。
- **手动**【必做】：「记忆」tab 增删改 + 在 全局↔私有 间移动标记。
- **情景快写**【可选】：可记事件先低成本存 `episodic`（不立刻跑贵 LLM），延后由巩固提炼。**注意**：开了它就依赖巩固能跑起来（见 §8 移动端约束），否则会堆积——所以默认可关，先把 autoAnalyze 跑通。

#### 5.1.1 写入级别策略【必做】
全局/私有都可开自动提取，用户自由开关 + 手动标记：
- 两个独立开关：`自动写入私有记忆`(默认开)、`自动写入全局记忆`(默认关/可选)。
- 两个都开时，决策多一步分级：LLM 判断"通用偏好→全局 / 仅本助手相关→私有"。
- 用户随时手动在 全局↔私有 间移动（改 `scope_level`/`owner_id`，记 history）。

### 5.2 检索 / recall【必做】
见 §6 激活打分。命中且**实际被用到**的条目 → `accessCount++`、刷新 `lastAccessedAt`、小幅提 `importance`（测试效应/间隔重复）。

### 5.3 巩固（Dream）
- **purge**【必做】：清"已软删 + 超 retentionDays"的，控体积。
- **reembed**【必做】：embedding 模型变更时重算（见 §9）。
- **cluster + consolidate**【后置】：把近期 `episodic` 聚类 → LLM 提炼成 `semantic`、合并近重复、冲突走再巩固（UPDATE + 设旧条 `validUntil`）。带 API 预算保护。
- **decay/forget**【可选·保守】：重算基础激活；衰减**只作用于 `episodic` + 低 `importance`**，语义/高重要性设地板不衰减。默认弱衰减、可关。

### 5.4 再巩固 / 冲突【必做】
检索命中旧记忆 + 新冲突信息 → **UPDATE**（重写、记 history、必要时设 `validUntil`），而非堆新条目。这是抑制"记忆库越堆越乱"的核心。

---

## 6. 检索激活打分【必做（相似度主导）】

```
基础激活(近因+频率)：
  B = ln(accessCount + 1) − d · ln(ageHours + 1)        // d=decayRate，默认 0.5

激活分：
  A = w_sim · sim                  // 向量余弦；无向量 → BM25/文本
    + w_act · sigmoid(B)           // 近因+频率
    + w_imp · importance           // 显著性(存储强度)
    + w_cue · cueMatch             // 线索匹配(同助手/同topic/同实体)【可选】

召回：A ≥ θ → 取 top-k 注入 <user_memories>
```

- **默认相似度主导**：`w_sim=0.7, w_act=0.15, w_imp=0.15, w_cue=0`；`d=0.5`；`θ` 按现状的 0.5 起步。其余项只当"平局打破"。
- **一键退化**：把 `w_act=w_imp=w_cue=0` 即回到纯向量检索，保证不翻车。
- 全部参数可配，先观察命中日志再调（见 §11），不盲调。

### 6.1 记忆提供（注入）策略：用户可选【必做】

> 决策：**注入方式由用户自己选**，系统给合理默认。注意"提供记忆"**不需要本地小模型**——检索的 embedding 用用户已配置的 embedding API 模型（与提取共用），端上只做余弦计算（千级向量、微秒级）。

设置项 `memoryInjectionMode`（设置页 + 可助手级覆盖）：

| 模式 | 行为 | 适用 | 代价 |
|---|---|---|---|
| `auto`（默认，推荐） | 全局记忆**全量注入**；助手/会话记忆走**向量 top-k**；某 scope 总数 < 阈值时该 scope 自动改全量 | 多数用户 | 仅查询 1 次 embedding；小库零漏召回 |
| `full` 全量注入 | 把该 scope 记忆全塞进 prompt | 记忆少、想零漏召回 | token 随条数涨、上下文稀释、查询时不调 embedding |
| `semantic` 向量检索 | 仅注入向量 top-k | 记忆多、要精准/省 token | 每轮 1 次 embedding 调用 |
| `keyword` 文本检索 | BM25/LIKE top-k，**不调 embedding** | 没配 embedding 模型 / 极致省钱 | 语义匹配弱 |
| `tool` 工具自取 | 给模型 `search_memory` 工具，按需查【可选】 | 支持工具调用的模型 | 需要时多一轮 |
| `off` | 不注入 | 临时关闭 | — |

通用约束（所有模式）：
- **token 预算上限** `maxMemoryTokens`（可配）：超了按激活分排序截断。
- **全量阈值** `fullDumpMaxCount`（默认 ~30）：`auto` 下决定某 scope 何时退回全量。
- **未配 embedding 模型**：`auto`/`semantic` 自动降级为 `keyword`，功能不中断。
- **缓存**：按 `messageId` 缓存检索结果，同一条消息不重复查。
- 注入块统一包成 `<user_memories>...</user_memories>` 放进 system prompt。

---

## 7. drift schema（最终）【必做】

```dart
class Memories extends Table {
  TextColumn  get id => text()();
  // 隔离
  TextColumn  get scopeKind  => text()();                 // 'chat'(本文) | 'agent'(预留)
  TextColumn  get scopeLevel => text()();                 // 'global' | 'owner'
  TextColumn  get ownerId    => text().nullable()();      // owner 时=assistantId
  // 类型与内容
  TextColumn  get memType => text().withDefault(const Constant('semantic'))(); // 'episodic'|'semantic'
  TextColumn  get content => text()();
  TextColumn  get hash    => text()();                    // sha256 去重
  TextColumn  get category=> text().nullable()();
  TextColumn  get source  => text().nullable()();         // auto|manual|tool|dream
  // 向量
  BlobColumn  get embedding        => blob().nullable()();    // F32_BLOB
  TextColumn  get embeddingModelId => text().nullable()();    // 跨模型隔离
  // 脑科学量
  RealColumn  get importance   => real().withDefault(const Constant(0.5))();   // 存储强度，几乎不衰减
  IntColumn   get accessCount  => integer().withDefault(const Constant(0))();  // 频率
  DateTimeColumn get lastAccessedAt => dateTime().nullable()();                // 近因
  RealColumn  get decayRate    => real().withDefault(const Constant(0.5))();   // d
  TextColumn  get cues         => text().nullable()();    // JSON 线索【可选】
  TextColumn  get associations => text().nullable()();    // JSON 关联记忆id【可选】
  // 双时态【可选】
  DateTimeColumn get validFrom  => dateTime().nullable()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  // 状态
  BoolColumn  get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn  get metadata => text().nullable()();        // JSON: topicId/messageId/tags
}

class MemoryHistory extends Table {                       // 审计【必做】
  IntColumn  get id => integer().autoIncrement()();
  TextColumn get memoryId => text()();
  TextColumn get action => text()();                      // ADD|UPDATE|DELETE
  TextColumn get previousValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
// 索引: (scopeKind, scopeLevel, ownerId, isDeleted)、hash、createdAt、lastAccessedAt
```

> 字段一次性建好，但带【可选】的列初期可空置/不参与逻辑，按 roadmap 逐步启用，避免反复迁移。

---

## 8. 向量检索与移动端约束【必做】

- **向量检索**：优先用 `sqlite-vec`（与 `sqlite3_flutter_libs` 一起加载）做原生相似度；若目标平台(iOS/Android)加载不稳，**降级为 Dart 端余弦相似度 + 模长缓存**（原版 web 做法）。两种实现都藏在 `MemoryEngine.vectorSearch` 之后，对上层透明。先做 Dart 降级保底，sqlite-vec 作为优化项验证后再切。
- **巩固调度（关键现实约束）**：移动 OS 无可靠后台 cron，**"睡眠巩固"只能机会式触发**：
  - App 切前台 / 空闲若干秒；
  - 打开「记忆」页时；
  - 待处理 episodic 累计超阈值；
  - 「整理记忆」手动按钮兜底。
  - 不依赖真后台；每次巩固带 API 预算上限，可中断续跑。

---

## 9. Embedding 模型变更处理【必做】

- 每条记忆记 `embeddingModelId`；检索只在**同模型**向量间算相似度。
- 用户换模型 → 标记需 reembed → 机会式后台分批重算（带预算）。重算完成前，旧模型记忆走文本检索降级，不崩。

---

## 10. 模块与接口（Dart）【必做】

```dart
class MemoryEngine {                         // L0 共享内核
  Future<List<double>> embed(String text);
  Future<List<ScoredMemory>> activationSearch(String q, MemoryScope s, {int k, double theta});
  Future<void> recordHit(String id);         // 命中强化
  // 去重/history/软删/reembed...
}

abstract class MemoryStore {                 // L2
  Future<MemoryItem?> add(String content, MemoryScope scope, {MemoryMeta? meta});
  Future<List<ScoredMemory>> search(String q, MemoryScope scope, {int k});
  Future<MemoryItem?> update(String id, {String? content, MemoryLevel? level});
  Future<bool> delete(String id);            // 软删
  Future<List<MemoryItem>> list(MemoryScope scope, {int limit, int offset});
}
class ChatMemoryStore extends MemoryStore { /* autoAnalyze + 工具 + Dream */ }
```

UI 接线：助手编辑「记忆」tab（开关 + 条目 CRUD + 全局/私有标记）、设置「记忆功能」页（全局记忆管理 + 自动写入开关 + 整理按钮）。

---

## 11. 可观测 / 评估【必做（轻量）】

- 记**命中日志**：每次检索的 query、召回条目、激活分、是否被实际使用。
- 据此再调权重/阈值，**禁止盲调**。
- 可选：一个最简离线 eval（给定对话→期望召回），验证激活分是否优于纯余弦。

---

## 12. 落地顺序（roadmap）

**第一阶段【必做】——立竿见影、低风险、可退化**
1. drift schema（建全字段）+ `MemoryScope`/level + `MemoryEngine`（Dart 余弦保底）。
2. `ChatMemoryStore`：翻 web 版 autoAnalyze + 去重 + 软删 + history。
3. 激活检索（相似度主导，可一键退回纯向量）。
4. 写入级别策略（全局/私有开关 + 手动标记）。
5. 接上占位 UI；命中日志。
6. purge + reembed + embedding 模型隔离。

**第二阶段【可选】——验证 ROI 后开**
7. 情景快写(episodic) + 机会式巩固调度。
8. 命中强化（access/importance）、cue 线索匹配。
9. sqlite-vec 原生向量（验证移动端可加载后切换）。

**第三阶段【后置】——重、依赖前置**
10. Dream cluster+consolidate（episodic→semantic、再巩固冲突解决）。
11. decay/forget（保守、可关）、双时态生效。
12. 混合检索 BM25 + rerank。

---

## 13. 待确认

1. **跨形态桥接**（未来智能体接入时）：是否允许智能体读「聊天-全局」用户偏好（默认关、严格隔离）。
2. **sqlite-vec 移动端可加载性**：决定是否一阶段就只走 Dart 余弦。
3. 第一阶段 UI 范围：是否包含「整理记忆」手动按钮（建议含，作巩固兜底）。

---

## 14. 参考

记忆科学：Atkinson & Shiffrin 1968 · Baddeley & Hitch 1974 · Tulving 1972 · Craik & Lockhart 1972 · Collins & Loftus 1975 · Ebbinghaus 1885 · McClelland et al. 1995(CLS) · Nader et al. 2000(再巩固) · Roediger & Karpicke 2006 · Bjork(存储/检索强度) · Anderson(ACT-R) · Diekelmann & Born 2010。
工程参考：mem0(TS SDK)、Cherry Studio v1 主记忆、Zep/Graphiti(双时态)、MemMachine(分层)、Memanto(写时不抽取)、原版 AetherLink web 记忆 + Dream。
