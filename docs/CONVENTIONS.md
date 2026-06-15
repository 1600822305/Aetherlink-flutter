# 代码与协作约定

> 把 `PROJECT_STRUCTURE.md` 的「死规矩」从文字变成**工具能卡的配置**。
> 原则：**约定 > 个人判断**。新人照着走不会走歪；走歪了 CI 拦住。

---

## 1. 命名

| 对象 | 规则 | 例 |
| --- | --- | --- |
| 文件 | `snake_case.dart` | `message_block.dart` |
| 类型/枚举 | `UpperCamelCase` | `MessageBlock` `ChatController` |
| 成员/变量/参数 | `lowerCamelCase` | `thinkingMillsec` |
| 常量 | `lowerCamelCase`，全局加 `k` 前缀 | `kTerminalBlockStatuses` |
| 私有 | 前缀 `_` | `_buildBlock` |
| Riverpod provider | `xxxProvider` | `chatControllerProvider` |
| 布尔 | `is/has/can/should` 开头 | `isStreaming` `hasError` |

**文件名体现角色**（reviewer 一眼知道它在哪层）：

| 后缀 | 角色 | 所在层 |
| --- | --- | --- |
| `*_page.dart` | 整页 Widget | presentation |
| `*_view.dart` / `*_widget.dart` | 组件 | presentation |
| `*_controller.dart` / `*_notifier.dart` | Riverpod 状态 | application |
| `*_usecase.dart` | 用例 | domain |
| `*_repository.dart` | 仓库**接口** | domain |
| `*_repository_impl.dart` | 仓库**实现** | data |
| `*_dao.dart` | Drift DAO | data |
| `*_dto.dart` | 传输对象 | data |
| 实体 | 放 `entities/`，文件名即概念 | domain |

**禁止的名字**（垃圾桶前兆，一律打回）：`common` `misc` `helpers` `utils2` `stuff` `index.dart`（聚合导出除外）。

---

## 2. `analysis_options.yaml`（边界强制的核心配置）

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
    strict-inference: true
  errors:
    # 把关键约定从 warning 提到 error，CI 直接红
    invalid_use_of_protected_member: error
    always_use_package_imports: error          # 禁止 ../../ 相对 import 跨层
    unused_import: error
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.drift.dart"
  plugins:
    - custom_lint

linter:
  rules:
    prefer_relative_imports: false             # 与 always_use_package_imports 配套
    public_member_api_docs: false
    require_trailing_commas: true
    prefer_const_constructors: true
    avoid_print: true                          # 用 logger，不准 print
    unnecessary_late: true
    sort_constructors_first: true
```

### custom_lint：依赖边界规则

边界（`PROJECT_STRUCTURE.md` §5）靠 `custom_lint` 卡死，**不靠自觉**：

```yaml
# pubspec.yaml (dev_dependencies)
custom_lint: ^latest
riverpod_lint: ^latest
# 二选一的 import 边界 lint（社区包，或自写规则）：
# - 用现成包：如基于 layer/feature 的 import 限制 lint
# - 或在本仓写一个 custom_lint plugin，规则见下
```

要卡死的规则（plugin 实现或等价社区规则）：

1. **`presentation` 不许 import `data`**（只能到 `application`）。
2. **`domain` 不许 import** Flutter / dio / drift / riverpod 等框架/IO 包（保持纯 Dart）。
3. **feature A 不许 import feature B 的内部文件**（只能引 B `domain` 的对外契约）。
4. **`core` / `shared` 不许 import `features`**；`core` 不许 import `shared`。

CI 跑：

```bash
dart run custom_lint        # 边界违规 → 失败
flutter analyze             # 静态分析 → 零告警才过
dart format --set-exit-if-changed .   # 未格式化 → 失败
```

> 任一红，PR 不合并。

---

## 3. 代码生成（codegen）

用到 codegen 的：`freezed` / `json_serializable` / `riverpod_generator` / `drift`。

```bash
# 一次性生成
dart run build_runner build --delete-conflicting-outputs

# 开发时监听
dart run build_runner watch --delete-conflicting-outputs
```

规则：
- **生成文件（`*.g.dart` / `*.freezed.dart` / `*.drift.dart`）提交进仓库**（保证 clone 即可编译、CI 不必每次重生成）。
- 但 **CI 必须验证「生成物是最新的」**：跑一次 build_runner，若 `git diff` 非空 → 失败（防止手改生成文件或忘记重生成）。
- **永远不手改生成文件。** 改源 `.dart` 再重跑。

---

## 4. 格式化与导入

- 统一 `dart format`（默认 80 列；如团队要更宽在 CI 固定一个值，别各写各的）。
- **一律 `package:` 绝对导入**，禁止 `../../` 跨目录相对导入（配合 §2 的 `always_use_package_imports`）。
- 导入分组顺序：dart SDK → flutter → 第三方包 → 本项目 `package:aetherlink_flutter/...`，组间空行。

---

## 5. 分支 / commit / PR

### 分支
```
<type>/<简短描述>
feat/chat-streaming
fix/topic-rename
docs/architecture
chore/deps-bump
```

### Commit（Conventional Commits）
```
<type>(<scope>): <subject>

feat(chat): add streaming token throttling
fix(data): correct drift migration for v2
docs(structure): add core/shared admission bar
```
type：`feat` `fix` `docs` `refactor` `test` `chore` `perf`。

### PR
- 标题同 commit 规范；一个 PR 聚焦一件事。
- 描述必含：**改了什么 / 为什么**；迁移类 PR 额外写明「扔了哪些①框架税、保留哪些②业务修复、修了哪些③技术债」（见 `MIGRATION.md`）。
- 合并前过 `PROJECT_STRUCTURE.md` §10 的 structure checklist。
- 默认 squash merge，保持主线整洁。

---

## 6. Definition of Done（每个 PR 的合并门槛）

- [ ] `flutter analyze` 零告警。
- [ ] `dart run custom_lint` 零违规（边界没破）。
- [ ] `dart format` 无改动。
- [ ] 生成物最新（CI 重跑 build_runner 后无 diff）。
- [ ] 测试通过且新增逻辑有测试（见 `TESTING.md`）。
- [ ] 新增文件能用 §6 决策树解释位置；未超大小护栏（`PROJECT_STRUCTURE.md` §7）。
- [ ] PR 描述完整。
