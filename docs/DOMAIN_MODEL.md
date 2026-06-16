# 领域模型规范（模型先行）

> 「领域模型先行」= 动手写任何 db / 网络 / UI 之前，**第一步先把核心实体用纯 Dart 定死**。
> 模型是所有层的契约（SSOT）：db 存它、网络解析成它、状态持有它、UI 渲染它。模型不稳，每层都返工。
> 数据来源：原项目 `src/shared/types/newMessage.ts`、`index.ts`、`Assistant.ts`。

---

## 1. 映射总规则（TS → Dart）

| TS | Dart（freezed + json_serializable） |
| --- | --- |
| `interface` / `type {}` | `@freezed class X with _$X` |
| 判别联合（`A \| B \| C`，带 `type` 字段） | `sealed class` + 多个 `const factory` + `@FreezedUnionValue` |
| `as const` 枚举对象 | `enum`（`@JsonValue('xxx')` 对齐字符串值） |
| `string \| undefined`（`?`） | 可空 `String?` |
| `string[]` | `List<String>` |
| `Record<string, any>` | `Map<String, dynamic>`（尽量收敛成强类型） |
| `Date` / ISO 字符串 | `DateTime`（自定义 JsonConverter 解析 ISO） |
| `ReactNode` / 任何 React-only 字段 | **丢弃**（框架税，见 §5） |

**联合类型 JSON 约定**：`@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.none)`，每个 factory 标 `@FreezedUnionValue('main_text')` 对齐原字符串值。

---

## 2. 枚举（逐字段对齐原值）

```dart
enum MessageBlockType {
  @JsonValue('unknown') unknown,
  @JsonValue('main_text') mainText,
  @JsonValue('thinking') thinking,
  @JsonValue('image') image,
  @JsonValue('video') video,
  @JsonValue('code') code,
  @JsonValue('tool') tool,
  @JsonValue('file') file,
  @JsonValue('error') error,
  @JsonValue('citation') citation,
  @JsonValue('translation') translation,
  @JsonValue('chart') chart,
  @JsonValue('math') math,
  @JsonValue('knowledge_reference') knowledgeReference,
  @JsonValue('context_summary') contextSummary,
}

enum MessageBlockStatus {
  @JsonValue('pending') pending,
  @JsonValue('processing') processing,
  @JsonValue('streaming') streaming,
  @JsonValue('success') success,
  @JsonValue('error') error,
  @JsonValue('paused') paused,
}

// 终态：流结束后块必须落入其一（计时冻结/收尾不变量）
const kTerminalBlockStatuses = {
  MessageBlockStatus.success,
  MessageBlockStatus.error,
  MessageBlockStatus.paused,
};

enum MessageRole {
  @JsonValue('user') user,
  @JsonValue('assistant') assistant,
  @JsonValue('system') system,
}
```

> Message 的 `status` 在原项目是 `UserMessageStatus | AssistantMessageStatus` 两套并集（sending/processing/searching/streaming/success/error/paused）。Dart 侧合并为一个 `MessageStatus` 枚举，覆盖全部取值。

---

## 3. MessageBlock：14 种判别联合（核心）

原 `MessageBlock` 是 `BaseMessageBlock` + 14 个变体的联合。Dart 用 `sealed` 联合，**编译期穷尽检查**——渲染时漏处理某种块会直接编译报错（强于 TS 的运行期 `switch(type)` + default 兜底）。

```dart
@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.none)
sealed class MessageBlock with _$MessageBlock {
  // 公共字段在每个 factory 重复声明（freezed 联合无共享基类字段，故逐个列）

  @FreezedUnionValue('main_text')
  const factory MessageBlock.mainText({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    required DateTime createdAt,
    DateTime? updatedAt,
    required String content,
  }) = MainTextBlock;

  @FreezedUnionValue('thinking')
  const factory MessageBlock.thinking({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    required DateTime createdAt,
    required String content,
    int? thinkingMillsec,        // 思考耗时（ms），收尾时由时间戳差定格
    int? thinkingStartTime,
  }) = ThinkingBlock;

  @FreezedUnionValue('code')
  const factory MessageBlock.code({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    required DateTime createdAt,
    required String content,
    String? language,
  }) = CodeBlock;

  @FreezedUnionValue('image')
  const factory MessageBlock.image({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    required DateTime createdAt,
    required String url,
    required String mimeType,
    String? base64Data,
    int? width,
    int? height,
    int? size,
  }) = ImageBlock;

  // … video / tool / file / error / citation / translation /
  //    chart / math / knowledgeReference / contextSummary / unknown(占位)
  //   逐一对齐 newMessage.ts 的字段

  factory MessageBlock.fromJson(Map<String, dynamic> json) =>
      _$MessageBlockFromJson(json);
}
```

UI 渲染靠 sealed 的穷尽 `switch`：

```dart
Widget buildBlock(MessageBlock b) => switch (b) {
  MainTextBlock(:final content)            => MarkdownView(content),
  ThinkingBlock(:final content, :final thinkingMillsec)
                                           => ThinkingView(content, ms: thinkingMillsec),
  CodeBlock(:final content, :final language) => CodeView(content, language),
  ImageBlock(:final url)                   => ImageView(url),
  // 少写一种 → 编译报错，不会漏
  _                                        => const SizedBox.shrink(),
};
```

> 14 种变体全表与逐字段对照见随 M0 提交的 `features/chat/domain/entities/message_block.dart`，本文件只示范规范。

---

## 4. Message / Topic / Assistant / Model（顶层实体）

### Message（`newMessage.ts`）
```dart
@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required MessageRole role,
    required String assistantId,
    required String topicId,
    required DateTime createdAt,
    DateTime? updatedAt,
    required MessageStatus status,
    String? modelId,
    Model? model,
    String? askId,                 // 多模型分组：关联的问题消息 id
    @Default(<String>[]) List<String> blocks,   // block id 列表，顺序敏感
    Usage? usage,
    Metrics? metrics,
    Map<String, dynamic>? metadata,
  }) = _Message;
  factory Message.fromJson(Map<String, dynamic> j) => _$MessageFromJson(j);
}
```

### Topic（`index.ts` 的 `ChatTopic`）
```dart
@freezed
class Topic with _$Topic {
  const factory Topic({
    required String id,
    required String assistantId,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool isNameManuallyEdited,
    @Default(<String>[]) List<String> messageIds,
    String? lastMessageTime,
    String? lastMessagePreview,
    @Default(false) bool pinned,
  }) = _Topic;
  factory Topic.fromJson(Map<String, dynamic> j) => _$TopicFromJson(j);
}
```
> 原 `ChatTopic` 的 `@deprecated` 字段（`messages` / `title` / `prompt`）**不迁移**——属于该清理的历史包袱（见 `MIGRATION.md` ③类）。

### Assistant（`Assistant.ts`，跨 feature → 放 `shared/domain`）
迁移持久化字段（id/name/description/avatar/emoji/tags/model 参数/systemPrompt/topicIds…），**丢弃 `icon?: ReactNode`**（React-only）；`topics: ChatTopic[]` 这类运行时聚合字段不进持久化模型，由 repository 组装。

### Model（`index.ts`）
迁移 id/name/provider/providerType/apiKey/baseUrl/能力 `capabilities{...}` 等；`providerName`（运行时注入、非持久化）不进模型。

### ModelProvider（`src/shared/config/defaultModels.ts`，跨 feature → 放 `shared/domain`）
模型供应商配置。1:1 迁移原版 `ModelProvider` 的持久化字段：

| 字段 | Dart 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | 主键 |
| `name` | `String` | 显示名 |
| `avatar` | `String` | 头像标识（原版即字符串：字母 `O`、emoji `🧠`、或资源键 `dashscope`）——**存原始 `String`，不转 Flutter `IconData`** |
| `color` | `String` | 主题色，原版即十六进制串 `#10a37f`——**存原始 `String`，不转 Flutter `Color`/`int`**（保证与原版 JSON 1:1 round-trip，零有损编码） |
| `isEnabled` | `bool`（默认 `false`） | 是否启用 |
| `apiKey` | `String?` | 单 key（向后兼容字段） |
| `baseUrl` | `String?` | 接口地址 |
| `models` | `List<Model>`（默认 `[]`） | 该供应商下的模型，复用既有 `Model` |
| `providerType` | `String?` | 适配器类型（`openai`/`gemini`/`anthropic`/`volcengine`/`zhipu`/`dashscope`…） |
| `isSystem` | `bool?` | 系统内置供应商 |
| `extraHeaders` | `Map<String, String>?` | 附加请求头 |
| `extraBody` | `Map<String, dynamic>?` | 附加请求体 |

**多 key 取舍（`apiKeys` / `keyManagement` / `ApiKeyConfig`）**：原版的多 key 轮询/配额是一整套 web 端运行时调度逻辑，本仓 SSOT 暂未 spec 其领域语义。按「没 spec 不擅自发明」原则，本期只迁单 `apiKey`，多 key 留 `// TODO(multi-key)` 待 SSOT 补齐后再建对应 freezed 类型（`ApiKeyConfig` / `KeyManagement`），不预先发明。

---

## 5. 明确「丢弃」清单（不迁移的 React-only / 历史字段）

| 字段/类型 | 出处 | 原因 |
| --- | --- | --- |
| `icon?: ReactNode` | `Assistant` | React 专属，Flutter 用 `emoji`/`avatar` 表达 |
| `ChatTopic.messages / title / prompt` | `index.ts` | 已 `@deprecated` |
| `Model.providerName` | `index.ts` | 运行时注入，非持久化 |
| `Assistant.topics`（运行时聚合） | `Assistant.ts` | 由 repository 组装，不入持久化模型 |
| `Model.useCorsPlugin` | `index.ts` | CORS 是 webview 概念，原生无 → 评估后大概率删 |
| `ModelProvider.useCorsPlugin` | `defaultModels.ts` | 同上，webview-only CORS，原生无 |
| `ModelProvider.useResponsesAPI / customModelEndpoint` | `defaultModels.ts` | web 端 Responses API / 自定义端点开关，本仓未 spec，暂不迁移 |

> 每丢一个字段都要在对应 PR 说明，避免「干净重写」时误删②类必要字段。

---

## 6. 落地清单（M0 验收）

- [ ] 枚举（MessageBlockType / Status / MessageRole / MessageStatus）值与原字符串逐一对齐。
- [ ] MessageBlock 14 变体齐全，`fromJson/toJson` 走 `type` 判别。
- [ ] Message / Topic / Assistant / Model + 支撑类型（Usage/Metrics/MessageVersion/引用项）。
- [ ] `dart run build_runner build` 通过，`flutter analyze` 零告警。
- [ ] 每个模型有最小 round-trip 测试（`fromJson(toJson(x)) == x`）。
