# 测试策略

> `MIGRATION.md` 通篇押在「对拍 + 回归测试」上，这份定清楚怎么落地。
> 核心立场：**测试是迁移的安全网**——②类业务修复全靠测试钉死，否则「干净重写」会悄悄把已修的线上 bug 放回来。

---

## 1. 测试金字塔（哪类多写、哪类少写）

```
        ▲  少
        │   端到端 / 集成（integration_test）：关键用户旅程，慢、脆，只覆盖golden path
        │   Widget 测试：页面/组件渲染与交互，中等量
        │   单元测试：domain/data/application 逻辑，★ 主力，大量
   多 ──┘
```

- **单元测试**（主力）：纯 Dart 逻辑——use case、repository 实现、provider client 的请求构造/SSE 解析、model round-trip。快、稳、可大量写。
- **Widget 测试**：Widget 渲染正确、交互触发正确意图（mock 掉 application 层）。
- **集成测试**：只覆盖最关键旅程（发消息→流式→落库→渲染），数量克制。

---

## 2. 目录：test/ 镜像 lib/

```
lib/features/chat/domain/usecases/send_message_usecase.dart
test/features/chat/domain/usecases/send_message_usecase_test.dart
```

- 一一对应，路径可预测。
- 共享 fixture / 测试替身放 `test/support/`（fake repository、录制的 SSE 响应、样例 JSON）。
- golden 基线图放 `test/**/goldens/`。

---

## 3. 三类测试怎么写

### 3.1 单元（domain / data / application）
- **domain**：纯函数式，直接 new、直接断言。use case 用 fake repository。
- **data**：repository 实现对接口的**契约测试**；DAO 用内存版 Drift（`NativeDatabase.memory()`）；provider client 用录制的 HTTP/SSE fixture（不打真网络）。
- **application**：Riverpod 用 `ProviderContainer` + `overrideWith` 注入 fake，断言 state 流转。

```dart
test('send 流式：每个 token 聚合进最后一个块，结束落 success', () async {
  final container = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(FakeStreamingRepo(['你', '好'])),
  ]);
  final ctrl = container.read(chatControllerProvider.notifier);
  await ctrl.send('hi');
  final last = container.read(chatControllerProvider).blocks.last;
  expect(last.content, '你好');
  expect(last.status, MessageBlockStatus.success);
});
```

### 3.2 Widget
- mock application 层（`overrideWith` 一个固定 state），断言渲染 + 交互发出正确意图。
- 不连真 db/网络。

### 3.3 Golden（视觉回归）
- 对稳定的纯 UI 叶子组件（气泡 / 思考块 / 代码块）打 golden 基线。
- 锁字体（打包 fixture 字体）避免跨平台抖动；CI 与本地用同一套。
- `flutter test --update-goldens` 仅在有意改 UI 时跑，并在 PR 里说明。

---

## 4. 对拍（迁移专用，防丢②类修复）

迁移关键路径时，**同一输入喂老 React 逻辑和新 Dart 逻辑，比对输出**，揪出干净重写时漏掉的真修复。

落地方式（按成本从低到高）：

1. **Fixture 对拍（推荐主力）**：在老项目里对目标函数喂一批输入、把输出录成 JSON fixture（如「provider X 请求体」「SSE chunk → block 序列」），提交到 `test/support/golden/`。新 Dart 实现跑同样输入，断言 == fixture。
2. **边界条件清单 → 用例**：把每个补丁/特判翻成一条 given/when/then 测试（见 §5）。
3. **（可选）运行时对拍**：临时脚本同时调老 JS 和新 Dart，diff 输出，用于摸排未知差异。

---

## 5. ②类补丁 → 测试 的标准模板

`MIGRATION.md` 的②类（业务修复）必须**每条配一个测试**，命名带上来源：

```dart
// 来源：原 src/shared/api/openai/xxx.ts 的字段剥离补丁
test('provider=deepseek 时请求体剥离 frequency_penalty', () {
  final body = OpenAiClient(provider: deepseek).buildBody(req);
  expect(body.containsKey('frequency_penalty'), isFalse);
});
```

要求：
- 测试名写清**业务规则**，不是实现细节。
- 注释标**原始出处**（哪个文件/补丁），方便回溯。
- 这批测试是「已知边界条件清单」的可执行版本——迁移完它们应全绿。

---

## 6. 覆盖率与门槛

- 目标：**domain / data / application 的逻辑 ≥ 80% 行覆盖**；presentation 不强求行覆盖（靠 Widget/golden）。
- 覆盖率是**信号不是 KPI**——别为凑数写无断言测试。重点是「②类修复 100% 有测试」。
- CI：
  ```bash
  flutter test --coverage
  # 可选：用 lcov 过滤掉 *.g.dart / *.freezed.dart 再算阈值
  ```
- 每个里程碑（`ROADMAP.md`）的验收门槛都包含「相关测试全绿」。

---

## 7. CI 测试流水线（与 CONVENTIONS §2 合并为一条）

```bash
dart format --set-exit-if-changed .
flutter analyze
dart run custom_lint
dart run build_runner build --delete-conflicting-outputs && git diff --exit-code  # 生成物最新
flutter test --coverage
```
任一失败 → PR 不合并。
