# 项目结构规范（死规矩）

> 本文是 **强制规范**，不是建议。所有代码必须落在本文定义的位置；不符合的 PR 不予合并。
> 目标只有一个：**不重蹈原 Aetherlink（React 版）结构混乱的覆辙。**

---

## 0. 为什么要有这份文档

原 Aetherlink（`1600822305/Aetherlink`，React + MUI）的结构问题不是个例，而是**系统性的结构腐烂**。迁移到 Flutter 是**重订结构的唯一窗口**，必须趁这次把规矩立死，否则新项目会以同样的方式烂掉。

### 原项目的真实病灶（数据来自源码扫描）

| 病灶 | 证据 | 后果 |
| --- | --- | --- |
| **按文件类型分目录（type-first）** | `components/` `hooks/` `utils/` `services/` `store/` 平行铺开 | 一个「聊天」功能被摊到 5+ 个目录，改一处要开 5 个文件夹 |
| **重复的抽象层（没有唯一的家）** | `src/utils`(9) **与** `src/shared/utils`(63) 并存；`src/hooks`(13) 与 `src/shared/hooks`(19) 并存；`src/config`(9) 与 `src/shared/config`(34) 并存；`src/types`(3) 与 `src/shared/types`(19) 并存 | 同类东西两边都能放，没规矩 → 熵增 |
| **God-folder（全堆一个文件夹）** | `src/shared/services` = **245 个文件**；`src/shared/utils` = 63 个 | 无法导航，无人敢动，膨胀无上限 |
| **同一概念散落多处** | provider 逻辑散在 `api/openai`、`api/openai-aisdk`、`shared/providers`、`api/providerFactory.ts`、`services/ai/ProviderFactory.ts`（**两个 ProviderFactory！**）、`pages/Settings/ModelProviders`、`solid/.../WebSearchProviderSelector` 共 7 处 | 同一职责长了好几份，没人收口 |
| **体量失控** | 972 个 TS 文件 / 207 个目录，且缺乏边界约束 | 「能跑但会烂」 |

**本规范就是逐条治这些病。**

---

## 1. 八条铁律

1. **按功能分，不按文件类型分（feature-first）。** 目录的第一级划分是「业务功能」，不是「文件种类」。
2. **每个 feature 内部分层。** `presentation → application → domain ← data`，依赖单向指向内层（见 `ARCHITECTURE.md`）。
3. **边界靠工具强制，不靠自觉。** 用 `custom_lint` + 自定义 import 边界规则，把非法依赖卡在 CI/分析期。
4. **`core`/`shared` 有准入门槛。** 只有「≥2 个 feature 用到 **且** 不含任何 feature 专属逻辑」才准进。
5. **一个概念只有一个家（SSOT）。** 禁止重复抽象层；每类东西唯一规范位置。
6. **依赖倒置 + 注入。** feature 依赖抽象（domain 里的接口），实现由 Riverpod provider 注入。
7. **一致性机械化。** linter / formatter / codegen / CI 门禁 / 命名约定 / 大小护栏 —— 约定优先于个人判断。
8. **规模化靠模块化。** 现阶段单包；当某 feature 大到要独立交付/独立团队，再升级为多包（见 §8）。

---

## 2. 顶层目录树（标准答案）

```
aetherlink_flutter/
├─ lib/
│  ├─ main.dart                    # 仅启动：runApp(ProviderScope(child: App()))
│  ├─ app/                         # 应用外壳：根 Widget、路由表、主题装配、平台分流
│  │  ├─ app.dart
│  │  ├─ router/
│  │  └─ theme/                    # ThemeData（从 MUI themes.ts 抠的 token）
│  │
│  ├─ core/                        # 跨 feature 的底座（准入门槛见 §4）
│  │  ├─ database/                 # Drift 实例、DAO 基类、迁移
│  │  ├─ network/                  # dio 实例、拦截器、SSE 解析器
│  │  ├─ platform/                 # UnifiedPlatformApi 抽象 + 各平台实现
│  │  ├─ error/                    # Failure 体系、异常映射
│  │  ├─ result/                   # Result/Either 类型
│  │  ├─ utils/                    # 真·全局工具（严格把关，不是垃圾桶）
│  │  └─ constants/
│  │
│  ├─ shared/                      # 跨 feature 的「领域级」共享（比 core 高一层）
│  │  ├─ domain/                   # 跨 feature 的实体：Model、Assistant…（被多个 feature 引用）
│  │  └─ widgets/                  # 跨 feature 的纯 UI 叶子组件（按钮、空态、加载…）
│  │
│  └─ features/                    # ★ 业务功能，每个自成一体
│     ├─ chat/
│     │  ├─ domain/                # 实体 + repository 接口 + use case（纯 Dart）
│     │  │  ├─ entities/
│     │  │  ├─ repositories/       # 抽象接口
│     │  │  └─ usecases/
│     │  ├─ data/                  # 接口实现：dao / dto / repository_impl / 远端 client
│     │  │  ├─ datasources/
│     │  │  ├─ dto/
│     │  │  └─ repositories/
│     │  ├─ application/           # 状态：Riverpod Notifier / Provider
│     │  └─ presentation/          # UI：pages / widgets（先 mobile，desktop 以后并列）
│     │     ├─ mobile/
│     │     └─ widgets/            # 本 feature 专用叶子组件
│     ├─ assistants/
│     ├─ topics/
│     ├─ settings/
│     ├─ knowledge/
│     ├─ models/                   # 模型/供应商配置管理
│     └─ ...
│
├─ test/                          # 镜像 lib/ 结构
├─ docs/
└─ pubspec.yaml
```

**层级关系（从外到内允许依赖的方向）：**

```
app  ──►  features/*  ──►  shared  ──►  core
                    └──────────────────►  core
```

- `app` 知道所有 feature（负责装配/路由）。
- `feature` 之间**互不可见**（要协作走 §5 的规则）。
- `feature → shared → core`，**反向禁止**：`core` 不许 import `shared`/`features`，`shared` 不许 import `features`。

---

## 3. feature 切分原则

- **一个 feature = 一个业务能力**，对应用户脑子里的一块功能（chat / assistants / topics / settings / knowledge / models…），**不是**一个页面、也不是一个技术层。
- feature 的命名用**名词、业务语言**，不用技术词（✅ `chat` `knowledge`；❌ `services` `helpers` `common2`）。
- 一个 feature 内若出现明显独立的子能力，可再开**子 feature 目录**，但仍遵守同一套内部分层。
- **判断标准**：如果删掉这个 feature 目录，应该恰好删掉「一个完整业务能力」的全部代码，不多不少。

---

## 4. `core` / `shared` 准入门槛（治 God-folder）

进 `core` 或 `shared` 必须**同时**满足：

1. **被 ≥2 个 feature 真实引用**（只被 1 个用 → 留在那个 feature 里）。
2. **不含任何 feature 专属业务逻辑**（纯技术能力或跨域领域概念）。
3. **依赖稳定、向内**（不 import 任何 feature）。

`core` vs `shared` 怎么分：

- `core` = **技术底座**（数据库、网络、平台、错误、工具）。与业务无关，换个 App 也能用。
- `shared` = **跨 feature 的领域概念**（如 `Model`、`Assistant` 实体被 chat/settings/models 都用到）和**跨 feature 的纯 UI 叶子**。

> **反面教材**：原项目 `shared/services` 245 个文件，就是因为没门槛——什么都往里塞。本项目 `core/shared` 出现「单目录 > 15 文件」必须触发拆分评审（见 §7）。

---

## 5. 依赖规则（lint 强制）

### 规则

1. **feature 之间不许互相 import 内部文件。** feature A 需要 feature B 的能力时，只能：
   - 依赖 B 暴露在其 `domain` 层的**接口/实体**（B 的对外契约），或
   - 通过 `app` 层做编排（把 B 的 provider 注入 A）。
2. **UI 不许跨层。** `presentation` 只依赖 `application`；`application` 只依赖 `domain`；`data` 实现 `domain` 接口。`presentation` **禁止**直接 import `data`。
3. **`domain` 是纯 Dart。** 不许 import Flutter、dio、drift、riverpod 等任何框架/IO 包。
4. **依赖方向单向向内。** `core` 不 import 上层，`shared` 不 import `features`。

### 强制手段

- 引入 `custom_lint` + `riverpod_lint`，并增加 import 边界规则（可用社区包如 import boundary lint，或自定义 lint）。
- `analysis_options.yaml` 打开严格 lint；CI 跑 `flutter analyze` + `dart run custom_lint`，**有告警即失败**。
- 详细落地（`analysis_options.yaml` + custom_lint 规则 + CI 命令）见 `CONVENTIONS.md` §2。

---

## 6. 「X 该放哪」决策树

```
要加一个新东西 X：

X 是某个业务功能的一部分吗？
├─ 是 → 它属于哪一层？
│       ├─ 实体/接口/纯业务规则     → features/<f>/domain/
│       ├─ 状态/编排                → features/<f>/application/
│       ├─ DB/网络/DTO/接口实现      → features/<f>/data/
│       └─ 页面/组件                → features/<f>/presentation/
│
└─ 否（跨 feature）→ 满足 core/shared 准入门槛吗（§4）？
        ├─ 否 → 退回，它其实只属于某个 feature，放回去
        └─ 是 → 它是什么？
                ├─ 技术能力（db/网络/平台/工具/错误）→ core/<...>
                ├─ 跨 feature 的领域实体             → shared/domain/
                └─ 跨 feature 的纯 UI 叶子           → shared/widgets/
```

**默认倾向：能放进 feature 就别放进 shared/core。** 共享是有成本的（耦合面变大），门槛要高。

---

## 7. 大小护栏（防膨胀）

软性上限，超过即触发「拆分 / 评审」，写进 PR checklist：

- **单目录文件数 > 15** → 评估是否该拆子目录或拆 feature。
- **单文件行数 > 300**（Widget/逻辑）→ 评估拆分；UI 大组件优先拆子 Widget。
- **单个 Notifier/Service 职责 > 1 个清晰主题** → 拆。
- **出现「`utils2` / `common` / `helpers` / `misc`」这类名字** → 一律打回，它们是垃圾桶的前兆。

> 护栏是「触发评审」而非「硬性报错」，但 reviewer 有义务在 PR 中追问超标项。

---

## 8. 何时升级为多包（monorepo）

现在是**单包 feature-first**，足够。出现以下信号再考虑用 `melos` + `packages/*` 拆多包：

- 多个团队并行、需要物理隔离与独立 CI；
- 某 feature 要作为独立产物复用（如 SDK）；
- 单包构建/分析时间变得不可接受。

升级时把 `core` / `shared` / 各 `feature` 拆成独立 pub 包，靠包的 `dependencies` 做编译期物理隔离。**在此之前不做，避免过度工程。**

---

## 9. 命名约定（摘要）

- 文件名：`snake_case.dart`。类型：`UpperCamelCase`。成员/变量：`lowerCamelCase`。
- 文件名体现角色：`*_page.dart` / `*_notifier.dart` / `*_repository.dart` / `*_repository_impl.dart` / `*_dao.dart` / `*_dto.dart` / `*_entity` 放 `entities/`。
- 一个文件一个主类型（codegen 的 `*.freezed.dart` / `*.g.dart` 除外）。
- 不用无意义聚合名（`common`/`misc`/`helpers`/`utils2`）。

---

## 10. PR Checklist（structure 相关）

- [ ] 新增文件都能用 §6 决策树解释「为什么在这」。
- [ ] 没有跨 feature 直接 import 内部文件。
- [ ] `domain` 层没引入框架/IO 依赖。
- [ ] 没有新建重复抽象层（不在 core 和 feature 各放一份同类工具）。
- [ ] 没有目录/文件超过 §7 护栏且未说明。
- [ ] `flutter analyze` + `custom_lint` 零告警。
