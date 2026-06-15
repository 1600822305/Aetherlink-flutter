# ADR-0002：状态层用 Riverpod（不用 Bloc）

- **状态**：Accepted
- **日期**：2026-06-15

## 背景
原项目状态层是 Redux Toolkit（14 slice）+ redux-persist + zustand + `@preact/signals-react` + reselect 的混合体，需要在 Flutter 重写。要选一个**主状态方案**收口。

## 选项
1. **Riverpod**（`Notifier` / `AsyncNotifier` + riverpod_generator + DI）。
2. **Bloc / Cubit**（event→state，模板较重）。
3. setState / Provider 裸用（不够支撑这个体量）。

## 决策
用 **Riverpod**，配 codegen（`riverpod_generator`）+ `riverpod_lint`。

## 理由
- **与原 Redux slice 近乎一一对应**：一个 slice → 一个 `Notifier`，迁移心智负担最小（见 `ARCHITECTURE.md` §3 的对应表）。
- Riverpod 同时充当 **DI 容器**：repository / client / dao 都用 provider 注入，测试时 `overrideWith` 注 fake，省掉额外 DI 框架。
- `reselect` 的派生选择器 → 普通 `Provider`（自动缓存 + 依赖追踪），概念平移。
- 选择性重建（`select` / 细粒度 provider）天然解决原项目用 signals 逃 redux re-render 的那类性能问题——那些 hack 直接消失。
- 编译期安全（codegen）+ 官方推荐目录结构，契合「企业级一致性」。

## 后果
- 正面：迁移直观、自带 DI、可测性强、性能可控。
- 负面：Riverpod 有学习曲线（provider 生命周期 / ref 规则），需在 `STATE_MANAGEMENT.md`（M1 时写）定细则。
- 推翻触发条件：基本不会；若团队已重度押注 Bloc 生态才重议。
