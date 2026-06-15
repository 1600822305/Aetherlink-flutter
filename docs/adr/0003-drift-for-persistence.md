# ADR-0003：持久化用 Drift/SQLite（不用 Isar / 裸 sqflite）

- **状态**：Accepted
- **日期**：2026-06-15

## 背景
原项目用 Dexie/IndexedDB（`aetherlink-db-new` v9），数据是 topic → message → block 的关系结构 + 版本迁移。需要在 Flutter 选本地持久化方案，并支持老用户数据一次性迁移（见 `MIGRATION.md` §5）。

## 选项
1. **Drift**（SQLite 之上的类型安全 ORM + 编译期校验 SQL + 迁移框架）。
2. **Isar**（NoSQL，快，但关系建模/迁移弱，且生态维护状态需评估）。
3. **裸 sqflite**（手写 SQL，无类型安全，样板多）。

## 决策
用 **Drift（SQLite）**。

## 理由
- 数据本质是**关系型**（topic 1—N message 1—N block，blocks 顺序敏感）——SQLite/Drift 天然契合，比 NoSQL 更顺。
- **类型安全 + 编译期校验**：查询写错编译就报，符合「机械化一致性」。
- **迁移框架成熟**：对应原 Dexie 的版本迁移，且能承接 IndexedDB→SQLite 的一次性导入。
- 测试友好：`NativeDatabase.memory()` 跑内存库，DAO 单测快而稳（见 `TESTING.md`）。
- 跨移动 + 桌面一致（SQLite 全平台可用）。

## 后果
- 正面：类型安全、关系建模自然、迁移可控、可单测。
- 负面：block 多态落库需定方案（`type` 列 + JSON 列 vs 每类一张表）——留到 M1 的 `DATA_PERSISTENCE.md` 定稿。
- 推翻触发条件：出现极端写入吞吐需求且 profiling 证明 SQLite 是瓶颈（概率极低）。
