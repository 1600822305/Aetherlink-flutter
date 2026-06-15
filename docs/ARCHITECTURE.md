# 架构设计

> 配套阅读：`PROJECT_STRUCTURE.md`（目录死规矩）、`DOMAIN_MODEL.md`（模型）、`MIGRATION.md`（迁移策略）。

---

## 1. 分层与依赖方向

采用 Clean Architecture 的分层，依赖**单向指向内层**：

```
┌─────────────────────────────────────────────┐
│ presentation   Widget / Page（只 watch 状态）   │
│      │ 依赖                                     │
│      ▼                                          │
│ application    Riverpod Notifier（状态 + 编排）  │
│      │ 依赖                                     │
│      ▼                                          │
│ domain         实体 + Repository 接口 + UseCase  │ ← 纯 Dart，零框架依赖
│      ▲ 实现                                     │
│      │                                          │
│ data           Repository 实现 + DAO + 远端 client│
└─────────────────────────────────────────────┘
```

**铁律：**
- `domain` 是圆心，**不依赖任何外层、不依赖任何框架/IO**（不 import Flutter / dio / drift / riverpod）。
- `data` **实现** `domain` 声明的接口（依赖倒置）。
- `presentation` 只跟 `application` 打交道，**不许**直接碰 `data`。
- 业务逻辑一行都不写在 Widget 里。

这套保证：**UI 与业务解耦** → 桌面端 UI 以后可直接复用下面三层；**每层可独立单测** → 不开 UI 也能验数据/网络/逻辑。

---

## 2. 各层技术选型（及其替换的原 React 方案）

| 层 | 选型 | 替换原项目的 |
| --- | --- | --- |
| 模型 | `freezed` + `json_serializable` | TS `interface` / `type` |
| 状态 | **Riverpod**（`Notifier` / `AsyncNotifier` + codegen） | Redux Toolkit + zustand + `@preact/signals-react` |
| 持久化 | **Drift（SQLite）** | Dexie / IndexedDB（`aetherlink-db-new` v9） |
| 网络/LLM | **dio** + 自写 SSE 解析 + 每 provider 一个 client | Vercel AI SDK（`ai`/`@ai-sdk/*`）+ axios + `cors-proxy.js` |
| 平台能力 | `abstract class` + Flutter 插件实现 | `UnifiedPlatformAPI` + Capacitor + Tauri |
| DI | Riverpod provider | React context / 单例 |
| 路由 | `go_router`（待定） | react-router |

**白赚的简化：**
- 原生无 CORS → `cors-proxy` 直接删除。
- Flutter 一套工具链同时出移动 + 桌面 → **Capacitor + Tauri 双栈报废**。

> 选型理由细节见各文档；状态层为何选 Riverpod 而非 Bloc：`NotifierProvider` 与原 Redux slice 近乎一一对应，迁移心智负担最小。

---

## 3. 状态层：Riverpod 与原 Redux slice 的对应

原项目 `src/shared/store/slices`（14 个 slice：assistants / groups / newMessages / messageBlocks / runtime / settings / ui / webSearch …）→ 每个对应一个 Riverpod `Notifier`：

```
assistantsSlice      → AssistantsNotifier         (features/assistants/application)
newMessagesSlice     → MessagesNotifier           (features/chat/application)
messageBlocksSlice   → MessageBlocksNotifier      (features/chat/application)
settingsSlice        → SettingsNotifier           (features/settings/application)
uiSlice / runtime    → 拆到各自 feature 或 app 层
```

- reducer/thunk/selector 的逻辑**不迁移代码，用 Dart 重写**（这是最大一块重写，见 `MIGRATION.md`）。
- `reselect` 的派生选择器 → Riverpod 的 `Provider`（自动缓存 + 依赖追踪）。
- `redux-persist` 的持久化 → 落到 Drift，由 repository 负责，不在状态层做。

---

## 4. 核心数据流：流式聊天端到端

以最硬的「发消息 → 流式接收」为例，证明分层立得住：

```
[presentation]  ref.watch(chatControllerProvider)        // 只读状态、只发意图
      │ user 点发送
      ▼
[application]   ChatController.send(text)
      │ 调 use case
      ▼
[domain]        SendMessageUseCase(repo)                  // 编排：存用户消息 → 调模型 → 落库
      │ 依赖抽象接口
      ▼
[domain]        abstract ChatRepository
      ▲ 实现
      │
[data]          ChatRepositoryImpl
      ├─ MessageDao.insert(userMsg)                       // Drift 落库
      └─ LlmClient.streamChat(req) ── Stream<ChatDelta>   // dio + SSE
      ▲ 订阅
      │
[application]   Controller 订阅 Stream：
                  - 节流聚合 token（每 ~16–32ms 合一帧）
                  - 只更新「最后一个还在变的块」，已完成块冻结
                  - 收尾时把块状态落入终态（success/error/paused）
      │ state 变更
      ▼
[presentation]  Widget 重建，渲染 MessageBlock 列表
```

**关键点：**
- 流式解析、落库、节流全在 `data` + `application`，**UI 只是 `watch` 一个 state**。
- 这套逻辑写一次，**移动端与桌面端共用**；以后加桌面 UI = 再 `watch` 同一个 `chatControllerProvider`。
- 「节流 + 冻结已完成块」是原项目踩出来的性能经验（属于要保留的「业务修复」，见 `MIGRATION.md` 补丁三分类）。

---

## 5. 数据层模型：topic → message → block

关系结构（与原 Dexie schema 同构，落到 SQLite）：

```
Topic 1 ──< Message 1 ──< MessageBlock
            (blocks: List<blockId>，按顺序)
```

- `Message.blocks` 存 block id 列表（顺序敏感）。
- `MessageBlock` 是 14 种判别联合（见 `DOMAIN_MODEL.md`）。
- Drift 用关系表 + 类型安全查询；block 的多态用「`type` 列 + 各自字段表 / 或 JSON 列」二选一，迁移文档中定方案。

---

## 6. 平台层抽象

原项目的 `UnifiedPlatformAPI`（filesystem / notifications / clipboard / device / 可选 window[桌面] / camera[移动]）是个**好设计**，直接平移为 Dart `abstract class`：

```dart
abstract class UnifiedPlatformApi {
  FileSystemApi get fileSystem;
  NotificationApi get notifications;
  ClipboardApi get clipboard;
  DeviceApi get device;
  WindowApi? get window;   // 桌面端才有
  CameraApi? get camera;   // 移动端才有
}
```

- 实现用 Flutter 插件：`path_provider` / `flutter_local_notifications` / `share_plus` / `image_picker` / `flutter_tts` / `speech_to_text` …
- 按平台注入不同实现；上层只依赖抽象。**设计模式照搬，实现换 Dart 包。**

---

## 7. 桌面 / 移动双 UI

- 下面四层（domain / data / application / 平台）**100% 共享**。
- 只有 `presentation` 按形态分叉：`presentation/mobile`（底部导航 / 抽屉 / 全屏 / 手势）与 `presentation/desktop`（多栏 master-detail / 快捷键 / 窗口管理 / hover）。
- **共享叶子组件**（气泡 / 思考块 / 列表项 / 输入框），**只分叉外壳与导航**。
- 桌面端具体布局本期不定，留接口，见 `ROADMAP.md` 的 M5。
