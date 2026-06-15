# ADR-0001：单包 feature-first（暂不上 monorepo）

- **状态**：Accepted
- **日期**：2026-06-15

## 背景
原 Aetherlink 结构腐烂的根因是 type-first 布局 + 没有边界强制（详见 `PROJECT_STRUCTURE.md`）。新项目要从结构上根治。同时项目当前是单人/小团队规模。

## 选项
1. **单包 feature-first**：`lib/features/*` + `lib/core` + `lib/shared`，边界靠 `custom_lint` 在分析期卡。
2. **monorepo 多包**：`melos` + `packages/*`，`core/domain/data/features/*` 各独立 pub 包，非法依赖**编译期物理隔离、根本编不过**。

## 决策
现阶段用**选项 1（单包 feature-first + custom_lint 强制边界）**。monorepo 作为**未来升级路径**写进 `PROJECT_STRUCTURE.md` §8，现在不上。

## 理由
- 单人/小团队下，monorepo 的多包拆分 + melos 维护成本 > 收益。
- custom_lint 已能在分析期/CI 卡住绝大多数越界 import，达到「死规矩靠工具不靠自觉」的目的。
- feature-first 的目录纪律才是治原项目病的关键，这一点单包就能拿到。
- 升级到 monorepo 的迁移成本可控（把目录提成包即可），不是单向门。

## 后果
- 正面：上手快、构建简单、改一个 feature 只进一个目录。
- 负面：边界是「分析期」强制，不是「编译期」物理隔离——理论上有人能绕过 lint（但 CI 拦着）。
- 升级触发条件：多团队并行需物理隔离 / 某 feature 要作为独立产物复用 / 单包构建分析耗时不可接受。
