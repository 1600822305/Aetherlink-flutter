# 参数能力范围 (Parameter Scope) 设计文档

## 背景

参数管理系统需要根据当前模型决定显示哪些参数。当前逻辑存在缺陷：

- **第三方综合 API**（OpenRouter、one-api、new-api 等）使用 OpenAI 兼容协议转发各种模型
- `providerType` 字段表示的是**协议类型**（怎么发请求），而非模型能力
- 同一个第三方供应商下可能有 Claude、Gemini、GPT 等不同模型

## 核心矛盾

两个不同维度的概念被混为一体：

| 维度 | 含义 | 决定什么 |
|---|---|---|
| **协议类型** (protocol) | API endpoint 使用的请求格式 | 选择哪个 Adapter 发请求 |
| **参数能力** (parameterScope) | 底层模型实际支持的参数集 | 参数编辑器显示哪些参数 |

第三方 API 场景下两者分裂：
- OpenRouter 用 OpenAI 协议 → Adapter = OpenAI-compatible
- 底层模型是 Claude → 用户期望看到 Anthropic 参数

## 设计方案

### 1. 新增 `parameterScope` 字段

在 `Model` 和 `ModelProvider` 上各新增一个可选字段：

```dart
// Model
String? parameterScope;  // e.g., 'anthropic', 'gemini', 'openai', null

// ModelProvider
String? parameterScope;  // provider 级别的默认值
```

用户可在编辑供应商/模型页面手动设置。设置后优先级最高。

### 2. 参数显示解析优先级

```dart
ProviderType resolveParameterScope(CurrentModel current) {
  // ① 用户手动指定（最高优先级）
  final override = current.model.parameterScope 
      ?? current.provider.parameterScope;
  if (override != null && override.isNotEmpty) {
    return providerTypeFromProtocolKey(override);
  }

  // ② 从模型 ID 自动检测
  final fromModel = detectProviderFromModel(current.model.id);
  if (fromModel != ProviderType.openaiCompatible) {
    return fromModel;
  }

  // ③ 从 providerType 推断（协议类型作为 fallback）
  final explicit = current.model.providerType 
      ?? current.provider.providerType;
  if (explicit != null && explicit.isNotEmpty) {
    return providerTypeFromProtocolKey(explicit);
  }

  // ④ 兜底
  return ProviderType.openaiCompatible;
}
```

**对比旧逻辑：**
- 旧：`providerType > 模型ID`
- 新：`parameterScope > 模型ID > providerType > 兜底`

关键变化：模型 ID 优先于 providerType，因为 providerType 是"协议"不是"能力"。

### 3. 增强模型 ID 检测

`detectProviderFromModel` 新增覆盖：

```dart
// 现有
'claude' / 'anthropic' → anthropic
'gemini' / 'palm' → gemini
'gpt' / 'o1' / 'o3' / 'o4' → openai

// 新增（归为 openaiCompatible，但未来可独立）
'deepseek' → openaiCompatible  // DeepSeek 走 OpenAI 协议，参数相同
'qwen' → openaiCompatible
'glm' / 'chatglm' → openaiCompatible
'minimax' → openaiCompatible
'doubao' / 'ep-' → openaiCompatible  // 火山引擎 endpoint
'yi-' / 'yi_' → openaiCompatible
'moonshot' → openaiCompatible
```

这些模型当前都走 OpenAI-compatible 协议且参数集相同，保持 `openaiCompatible` 即可。
关键是 `claude`/`gemini` 的模型 ID 能正确识别，不被 provider 的 `providerType: 'openai'` 覆盖。

### 4. 协议不匹配提示

当 `parameterScope`（参数显示类型）和实际 Adapter 协议不同时，在专属参数旁显示灰色提示：

```
⚠️ 当前 API 协议可能不支持此参数
```

场景：用户通过 OpenRouter（OpenAI 协议）使用 Claude 模型，parameterScope 检测为 Anthropic，
但 `cacheControl` 等参数需要原生 Anthropic API 才能发送。

### 5. 实现计划

| PR | 内容 | 涉及文件 |
|---|---|---|
| PR 1 | 设计文档 + `parameterScope` 字段 | `docs/`, `model.dart`, `model_provider.dart`, JSON 序列化 |
| PR 2 | 重构解析逻辑 | `parameter_metadata.dart`, `parameter_editor.dart` |
| PR 3 | UI 编辑入口 + 协议提示 | 供应商编辑页、参数编辑器 |

### 6. 覆盖率分析

| 场景 | 覆盖方式 |
|---|---|
| 官方 API（providerType 准确） | ② 模型ID 或 ③ providerType |
| 第三方 API + 标准模型名 | ② 模型ID 自动检测 |
| 第三方 API + 前缀模型名（如 `anthropic/claude-3.5`） | ② 模型ID（contains 匹配） |
| 自定义/重命名模型 | ① parameterScope 手动指定 |
| Azure 部署名（任意字符串） | ③ providerType → openai（正确） |
| 无任何信号 | ④ openaiCompatible 兜底 |

**预期覆盖率：~98% 自动正确，~2% 需用户手动设置 parameterScope。**

### 7. 向后兼容性

- `parameterScope` 字段可选，默认 `null` → 走自动检测逻辑
- 现有数据无需迁移
- 旧版本 JSON 反序列化时忽略未知字段（freezed 默认行为）
