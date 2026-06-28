# 用人脑记忆科学设计聊天记忆系统

> 范围：**仅普通聊天记忆**（智能体记忆项目尚未开发，暂不涉及）。
> 目的：不再只照搬 mem0/CS 的工程经验，而是用被研究最透彻的"记忆系统"——人脑——的结构、生命周期、检索算法，反推一套更像"会记会忘会归纳"的设计。

---

## 0. 一句话动机

mem0 / Cherry Studio 这类记忆系统，本质只实现了人脑记忆的**一小块**：语义事实的"写入 + 向量检索"。它们普遍缺三样人脑必备的东西——**巩固（把零散经历归纳成知识）**、**遗忘曲线（不重要的自然淡出）**、**激活式检索（近因/频率/重要性共同决定能否想起）**。这正是"记忆库越用越脏、越查越不准"的根因。人脑早就解决了，照着抄。

---

## 1. 人脑记忆的三根支柱

### 1.1 结构：多存储模型 + 互补学习系统(CLS)

- **多存储模型（Atkinson–Shiffrin, 1968）**：感觉记忆 → 短期/工作记忆 → 长期记忆。
- **工作记忆（Baddeley & Hitch, 1974）**：容量极小（~4 chunks），是"当前在想的东西"，不是要存的东西。
- **长期记忆类型（Tulving, 1972）**：
  - **情景记忆 episodic**：带时间地点的具体经历（"上周二用户说他要去日本出差"）。
  - **语义记忆 semantic**：去情景化的事实/知识（"用户偏好简洁回答"）。
  - （程序记忆 procedural 对聊天不适用，略。）
- **互补学习系统 CLS（McClelland et al., 1995）**：**海马**快速学单条情景、易变；**新皮层**慢速沉淀成稳定语义；睡眠期海马"重放(replay)"把情景固化进新皮层。
  → 这是整套设计最重要的一根支柱：**先快写情景，再慢慢提炼成语义**。

### 1.2 过程：编码 → 巩固 → 检索 → 遗忘/再巩固

- **编码（levels of processing, Craik & Lockhart 1972）**：深加工（语义、关联）比浅加工记得牢 → 写入时要做语义提炼、存"要义"而非逐字。
- **巩固（systems consolidation；Diekelmann & Born 2010）**：记忆不是写完就定，要经历（尤其睡眠期的）巩固，把情景重组为知识。
- **检索（cue-dependent；encoding specificity, Tulving & Thomson 1973）**：靠线索触发；线索越匹配编码时的上下文越易想起。
- **遗忘（Ebbinghaus 1885）**：遗忘曲线近似幂律/指数衰减；间隔重复（spacing effect）能对抗遗忘。
- **存储强度 vs 检索强度（Bjork 新失用理论）**：一条记忆有两个量——**存储强度**（学得多牢，几乎不掉）和**检索强度**（此刻多容易想起，会随时间掉）。**"忘了"≠"删了"，只是检索强度低**。
- **检索即练习（testing effect, Roediger & Karpicke 2006）**：每成功回忆一次，记忆被强化。
- **再巩固（reconsolidation, Nader et al. 2000）**：被唤起的记忆会短暂变"可塑"，可被新信息修改后重新存储 → 这就是"更新"而非"新增"的生物学依据。

### 1.3 算法：扩散激活 + ACT-R 基础激活

- **语义网络的扩散激活（Collins & Loftus 1975）**：相关概念互相激活 → 对应向量相似检索 + 记忆间关联。
- **ACT-R 声明性记忆激活方程（Anderson）**：一条记忆能否被取出，取决于
  `激活 A = 基础激活 B + 上下文扩散 + 噪声`，其中基础激活 `B = ln(Σ tₖ⁻ᵈ)` 把**使用频率 + 幂律时间衰减**写进一个值，`A` 超过阈值才"想得起来"。
  → 这给了我们一个**可直接实现的检索打分函数**，比纯余弦相似度更像人。

---

## 2. 映射到聊天记忆系统（核心对照表）

| 人脑机制 | 聊天记忆系统对应实现 |
|---|---|
| 工作记忆（当前在想） | 对话上下文窗口 / 最近 N 轮（**不持久**，不进记忆库） |
| 情景记忆 episodic | 低成本快写的"事件条目"：原话/语境 + 时间戳（海马快写） |
| 语义记忆 semantic | 提炼后的偏好/事实条目（mem0 式，去情景化） |
| 编码（深加工） | LLM 事实提取：存"要义"，标 category、关联线索 |
| 互补学习 / 睡眠 replay | **Dream 巩固**：把 episodic 聚类→提炼成 semantic |
| 遗忘曲线 / 检索强度衰减 | 每条记忆带"基础激活"随时间幂律衰减，作为检索排序项 |
| 存储强度 vs 检索强度 | 两个分离的量：`importance`(近存储强度，不衰减) + `retrievalStrength`(随时间衰减) |
| 检索即练习 / 间隔效应 | 命中且被用到 → `accessCount++`、刷新 `lastAccessedAt`、提升强度 |
| 再巩固 | 检索到旧记忆 + 新冲突信息 → **UPDATE**（重写并记 history），而非新增 |
| 扩散激活 / 语义网络 | 向量相似检索 + 记忆间 `associations` 关联 |
| 情绪显著性（杏仁核） | `importance` 权重；用户标"重要"或强情绪事件→高保留 |
| 线索依赖 / 编码特异性 | 存检索线索（assistantId、topic、实体），检索时匹配加分 |
| 模式分离/补全（海马） | 写入去重(0.85) + 巩固聚类，区分近重复、补全部分线索 |
| 重构性记忆（Bartlett） | 只存要义、容忍有损；不追求逐字还原 |

---

## 3. 数据模型增量（在现有 MemoryItem 上加）

在前面《设计文档》的 `Memories` 表基础上，为"脑科学化"补这些字段：

```dart
TextColumn  get memType    => text()();        // 'episodic' | 'semantic'
RealColumn  get importance => real().withDefault(const Constant(0.5))(); // 存储强度/显著性 0..1，几乎不衰减
IntColumn   get accessCount=> integer().withDefault(const Constant(0))(); // 被成功召回次数(频率)
DateTimeColumn get lastAccessedAt => dateTime().nullable()();             // 最近一次召回(近因)
RealColumn  get decayRate  => real().withDefault(const Constant(0.5))();  // d，幂律衰减系数
TextColumn  get associations => text().nullable()();   // JSON: 关联记忆 id 列表(扩散激活)
TextColumn  get cues         => text().nullable()();   // JSON: 编码线索(实体/topic/情绪)
// 已有：embedding, hash, category, validFrom/validUntil(双时态), isDeleted, createdAt, updatedAt
```

> `importance`≈存储强度（学得牢不牢，由显著性/重复/用户标记决定），`基础激活`≈检索强度（此刻好不好取，随时间掉）。两者分离正是 Bjork 理论的关键。

---

## 4. 生命周期落地（编码 → 巩固 → 检索 → 遗忘/再巩固）

### 4.1 编码（写入）——双速：海马快写 + 皮层深加工
- **工作记忆**：最近 N 轮只做上下文，不落库。
- **情景快写（低成本）**：对话里出现"可记的事件"时，先以 `memType=episodic` **低成本存下原话/语境 + 时间戳**，**不立刻跑昂贵的 LLM 提炼**（对应海马快写，也对应 Memanto"写时不抽取"省成本的取舍）。
- **语义深加工**：`autoAnalyze` 仍做 LLM 事实提取，产出 `memType=semantic` 条目；写入做 hash + 0.85 相似去重（模式分离）。
- **显著性打分**：编码时给 `importance`：用户显式标记 / 强情绪 / 重复出现 → 高。

### 4.2 巩固（Dream = 睡眠 replay）——把"经历"变"知识"
现有 Dream 升级为真正的"系统巩固"：
- **replay/cluster**：把近期 `episodic` 聚类。
- **consolidate**：每簇用 LLM 提炼成稳定 `semantic`（情景→语义），合并近重复，**用再巩固逻辑解决冲突**（新信息推翻旧的→UPDATE + 设旧条 `validUntil`）。
- **decay/forget**：重算各条"基础激活"；长期低激活 + 低 importance 的 episodic 标记淡出。
- 保留你已有的 **API 预算保护**。

### 4.3 检索（recall）——ACT-R 激活打分（见 §5）
- 用当前输入做检索，按"激活分"排序，过阈值的 top-k 注入 `<user_memories>`。
- **检索即练习**：被召回且实际用到的条目 → `accessCount++`、刷新 `lastAccessedAt`、小幅提 `importance`（间隔重复/测试效应）。

### 4.4 遗忘 & 再巩固——不删，只是想不起来
- **不硬删**：激活低于阈值的条目自然"想不起来"，但仍保留（存储强度还在，将来线索强时还能召回）。
- **purge** 只清"长期极低激活 + 低 importance + 已软删"的，控制库体积。
- **再巩固**：检索命中旧记忆且出现冲突新信息时，走 **UPDATE**（重写、记 history、必要时设 `validUntil`），而不是堆一条新的——从根上抑制"记忆库越堆越乱"。

---

## 5. 检索激活公式（可直接实现）

把 ACT-R 思想简化成端上可算的打分：

```
基础激活(近因+频率)：
  B = ln(accessCount + 1) − d · ln(ageHours + 1)
  // d=decayRate；ageHours 用 lastAccessedAt 或 createdAt
  // 频率越高、越近 → B 越大；久不用 → 幂律衰减

激活分：
  A = w_sim · sim(query, mem)              // 扩散激活：向量余弦(无向量→BM25/文本)
    + w_act · sigmoid(B)                   // 基础激活：近因+频率
    + w_imp · importance                   // 情绪/显著性(存储强度)
    + w_cue · cueMatch(query, mem.cues)    // 编码特异性：线索匹配(同助手/同topic/同实体)

召回条件：A ≥ θ_retrieval  → 取 top-k 注入
```

- 默认权重（待调）：`w_sim=0.5, w_act=0.2, w_imp=0.2, w_cue=0.1`；`d=0.5`；`θ=0.5`。
- **退化**：无 embedding 时 `sim` 用 BM25/文本匹配，其余项不变——仍保留近因/频率/重要性的"人脑味"。
- 这比纯余弦强在：**同样相似度下，最近聊过的、反复确认过的、用户标重要的，会优先被想起**。

---

## 6. 与现有方案的关系（说明为什么这样更好）

| 方案 | 对应人脑的哪部分 | 缺什么 |
|---|---|---|
| mem0 / CS v1 主记忆 | 只有语义记忆 + 写时提取 + 向量检索 | 无巩固、无遗忘曲线、检索不含近因/频率/重要性 |
| 你的 Dream 维护 | 已是"睡眠巩固"雏形（聚类/合并/过期） | 还没显式区分 episodic→semantic、没接遗忘曲线 |
| **本设计** | 结构(情景/语义) + 生命周期(编码/巩固/检索/遗忘/再巩固) + ACT-R 激活检索 | —— |

落点：**情景/语义双类型 + 双速写入 + Dream 系统巩固 + ACT-R 激活检索 + 不删只衰减**。

---

## 7. 落地顺序（仅聊天，渐进）

1. **数据模型**：加 `memType / importance / accessCount / lastAccessedAt / decayRate / cues / associations`。
2. **激活检索**：检索打分从"纯余弦"升级为 §5 的激活分（先上 `sim + 近因 + importance`，cue/association 后补）。
3. **检索强化**：命中并被使用 → 更新 access/lastAccessed/importance（测试效应）。
4. **双速写入**：情景快写(episodic, 低成本) + 语义提炼(semantic, autoAnalyze)。
5. **Dream 系统巩固**：episodic→semantic 提炼、冲突再巩固、遗忘衰减。
6. 之后再叠 §双时态、混合检索(BM25+rerank)。

> 顺序原则：先把"激活检索"和"情景/语义"立起来（立竿见影改善召回质量），巩固/遗忘作为后台 Dream 慢慢加，风险可控。

---

## 8. 参考的记忆科学（便于查证）

Atkinson & Shiffrin 1968（多存储）· Baddeley & Hitch 1974（工作记忆）· Tulving 1972（情景/语义）· Craik & Lockhart 1972（加工层次）· Collins & Loftus 1975（扩散激活）· Ebbinghaus 1885（遗忘曲线/间隔）· McClelland, McNaughton & O'Reilly 1995（互补学习系统）· Nader et al. 2000（再巩固）· Roediger & Karpicke 2006（检索练习）· Bjork & Bjork（新失用理论：存储/检索强度）· Anderson ACT-R（声明性记忆激活方程）· Diekelmann & Born 2010（睡眠与巩固）。
