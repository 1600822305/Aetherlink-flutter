# ADR-0005：`core/database` 作为持久化组装根，对边界规则 4 开一个 narrow 例外

- **状态**：Accepted
- **日期**：2026-06-15

## 背景
持久化用 Drift（见 `ADR-0003`）。Drift 一个 app 对应**单个** `@DriftDatabase` 类（一个 SQLite 文件），它必须在一处**聚合所有 feature 的 table + DAO**。按 `PROJECT_STRUCTURE.md`，数据库属于 `core/database/`；而每个 feature 的 table/DAO 定义按 feature-first 归属各自的 `features/<f>/data/datasources/local/`（它们的 JSON-blob `TypeConverter` 还要引用被持久化的 `domain` 实体，生成的 `*.g.dart` 也会直接点名这些实体）。

这就和边界死规矩 4 直接撞车：

> **规则 4**：`core` / `shared` 不许 import `features`（`CONVENTIONS.md` §2、`PROJECT_STRUCTURE.md` §5）。

`core/database/app_database.dart` 要 `@DriftDatabase(tables: [...], daos: [...])` 聚合各 feature 的表，就必然 import `features/*/data` —— 违反规则 4。

## 选项
1. **给规则 4 开一个 narrow 例外**：只放 `core/database/*` import `features/*/data` 定义 + `domain` 实体；其余 `core → features/shared` 照样拦。
2. **把数据库组装根挪到 `app/`**：`app/` 是组装层，本就允许 import features，不用动规则 4。代价是偏离文档把 `database` 放在 `core/` 的既定结构。
3. **Drift 模块化 schema**（`include:` / 跨库 `DatabaseAccessor` 组合），让 `core` 不直接 import feature 内部。代价是结构更绕、收益有限。

## 决策
采用**选项 1**：保持数据库在 `core/database/`（与 `PROJECT_STRUCTURE.md` 一致），对规则 4 开一个**有明确边界**的例外。

边界测试（`test/architecture/import_boundaries_test.dart`）里的例外**严格限定**为：

- **只有** `core/database/` 下的文件可以越界；`core` 其它任何位置（`core/result`、`core/network` 等）→ `features` 仍然**判失败**。
- **只能** import 两类目标：feature 的 `data/datasources`（表/DAO/converter 定义）与 `domain` 实体（后者本就纯 Dart、无框架依赖，见规则 2）。
- 其余所有 `core → features/shared`、`core → shared` 越界**保持拦截**。

## 理由
- 单库聚合全 feature 是 Drift 的固有约束，「组装根需要看见各 feature 的表」是**真实且不可避免**的依赖；这跟 `app/` 组装 feature 是同一性质。
- 把它显式限定在 `core/database/` 这一个组装点，比「让 `core` 整体能引 `features`」**窄得多**，规矩没被掏空。
- `domain` 纯净性（规则 2：`domain` ✗→ 框架/IO）**完全不受影响**——例外只放开 `core/database` → `data`/`domain`，没碰 domain 自身。
- 与文档既定结构（`database` 在 `core/`）一致，不引入「数据库为什么跑到 app 里」的认知成本。

## 后果
- 正面：单一 `AppDatabase` 组装根清晰；feature-first 的表归属不变；规则 4 的其余部分仍由测试硬卡。
- 负面：规则 4 有一处例外，必须**靠这条 ADR + 测试注释**说明，否则后人易困惑或顺手扩大。
- **护栏（务必遵守）**：
  - 新增 feature 的持久化时，table/DAO 仍放该 feature 的 `data/datasources/local/`，由 `core/database` 统一注册——**复用同一模式，不要新开口子**。
  - 例外**只准**停留在 `core/database/`；任何把它扩到 `core` 其它目录、或放开 `core → features` 业务/`presentation`/`application` 的改动都应被拒。
  - 已用反向注入验证过例外的窄度：非 `core/database` 的 core 文件 import feature → 边界测试仍红。改动边界测试后须保持该性质。
- 推翻触发条件：若改用每 feature 独立库/模块化 schema 能在不越界的前提下达成单库体验，或数据库组装根迁往 `app/`，则新开 ADR 取代本条。
