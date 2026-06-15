# 架构决策记录（ADR）

> ADR（Architecture Decision Record）= 把「**为什么这么选**」钉死成不可变记录，免得以后有人翻旧账重新争。

## 规则
- 每个**有取舍、影响全局**的技术决策写一条 ADR。
- ADR **一旦 Accepted 不改**；要推翻就**新开一条**标 `Supersedes: ADR-XXXX`，把旧的标 `Superseded by`。
- 编号递增、四位：`0001-xxx.md`。
- 新决策从 `TEMPLATE.md` 复制。

## 状态机
`Proposed → Accepted → (Deprecated | Superseded)`

## 索引

| # | 决策 | 状态 |
| --- | --- | --- |
| [0001](./0001-single-package-feature-first.md) | 单包 feature-first（暂不上 monorepo） | Accepted |
| [0002](./0002-riverpod-for-state.md) | 状态层用 Riverpod（不用 Bloc） | Accepted |
| [0003](./0003-drift-for-persistence.md) | 持久化用 Drift/SQLite（不用 Isar/sqflite 裸写） | Accepted |
| [0004](./0004-dio-handwritten-sse.md) | 网络/LLM 用 dio + 自写 SSE（不移植 Vercel AI SDK） | Accepted |
| [0005](./0005-core-database-composition-root.md) | `core/database` 作为持久化组装根，对边界规则 4 开 narrow 例外 | Accepted |
| [0006](./0006-provider-protocol-adapters.md) | LLM provider 按协议族收口成 3 个 adapter，统一接缝不统一内脏（refines 0004） | Accepted |
