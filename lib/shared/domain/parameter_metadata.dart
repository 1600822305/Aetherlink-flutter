// Parameter metadata configuration.
//
// Defines all supported parameters, their UI controls, value ranges, provider
// compatibility and conditional-display rules — a direct port of the web
// `parameterMetadata.ts`.

/// The set of AI providers a parameter can belong to.
enum ProviderType { openai, anthropic, gemini, openaiCompatible }

/// How a parameter is rendered in the editor UI.
enum ParameterInputType { slider, number, select, switchToggle, text }

/// Functional category a parameter belongs to — drives the UI section headings.
enum ParameterCategory { basic, advanced, reasoning, tools }

/// A mark rendered on a slider track.
class SliderMark {
  const SliderMark({required this.value, required this.label});
  final double value;
  final String label;
}

/// A selectable option for [ParameterInputType.select].
class SelectOption {
  const SelectOption({required this.value, required this.label});
  final Object value;
  final String label;
}

/// Conditional-display rule: show this parameter only when [key] equals one of
/// [values].
class ShowWhen {
  const ShowWhen({required this.key, required this.values});
  final String key;
  final List<Object> values;
}

/// Describes one parameter's metadata for UI rendering and provider filtering.
class ParameterMeta {
  const ParameterMeta({
    required this.key,
    required this.label,
    required this.description,
    required this.inputType,
    required this.defaultValue,
    required this.category,
    required this.providers,
    this.rangeMin,
    this.rangeMax,
    this.rangeStep,
    this.options,
    this.marks,
    this.unit,
    this.showWhen,
    this.defaultEnabled = false,
  });

  final String key;
  final String label;
  final String description;
  final ParameterInputType inputType;
  final Object? defaultValue;
  final ParameterCategory category;
  final List<ProviderType> providers;

  /// Range constraints (slider / number inputs).
  final double? rangeMin;
  final double? rangeMax;
  final double? rangeStep;

  /// Select-type options.
  final List<SelectOption>? options;

  /// Slider marks.
  final List<SliderMark>? marks;

  /// Unit label shown after the value (e.g. "tokens").
  final String? unit;

  /// Conditional display rule.
  final ShowWhen? showWhen;

  /// Whether this parameter is enabled by default in a fresh configuration.
  final bool defaultEnabled;

  ParameterMeta copyWith({List<SelectOption>? options}) => ParameterMeta(
        key: key,
        label: label,
        description: description,
        inputType: inputType,
        defaultValue: defaultValue,
        category: category,
        providers: providers,
        rangeMin: rangeMin,
        rangeMax: rangeMax,
        rangeStep: rangeStep,
        options: options ?? this.options,
        marks: marks,
        unit: unit,
        showWhen: showWhen,
        defaultEnabled: defaultEnabled,
      );
}

// ─── All parameter definitions ───────────────────────────────────────────────

const List<ParameterMeta> kParameterMetadata = [
  // ==================== 基础参数 ====================
  ParameterMeta(
    key: 'temperature',
    label: '温度',
    description: '控制输出随机性。较高值产生更多样化的输出，较低值更确定性',
    inputType: ParameterInputType.slider,
    defaultValue: 0.7,
    category: ParameterCategory.basic,
    providers: ProviderType.values,
    rangeMin: 0,
    rangeMax: 2,
    rangeStep: 0.1,
    marks: [
      SliderMark(value: 0, label: '精确'),
      SliderMark(value: 0.7, label: '平衡'),
      SliderMark(value: 1.5, label: '创意'),
      SliderMark(value: 2, label: '随机'),
    ],
  ),
  ParameterMeta(
    key: 'topP',
    label: 'Top P (核采样)',
    description: '从概率和达到 P 的 token 中采样。建议不与温度同时调整',
    inputType: ParameterInputType.slider,
    defaultValue: 1.0,
    category: ParameterCategory.basic,
    providers: ProviderType.values,
    rangeMin: 0,
    rangeMax: 1,
    rangeStep: 0.05,
    marks: [
      SliderMark(value: 0.1, label: '0.1'),
      SliderMark(value: 0.5, label: '0.5'),
      SliderMark(value: 0.9, label: '0.9'),
      SliderMark(value: 1, label: '1'),
    ],
  ),
  ParameterMeta(
    key: 'maxOutputTokens',
    label: '最大输出 Token',
    description: '限制生成回复的最大长度',
    inputType: ParameterInputType.slider,
    defaultValue: 4096,
    defaultEnabled: true,
    category: ParameterCategory.basic,
    providers: ProviderType.values,
    rangeMin: 256,
    rangeMax: 65536,
    rangeStep: 256,
    marks: [
      SliderMark(value: 2048, label: '2K'),
      SliderMark(value: 8192, label: '8K'),
      SliderMark(value: 32768, label: '32K'),
      SliderMark(value: 65536, label: '64K'),
    ],
    unit: 'tokens',
  ),
  ParameterMeta(
    key: 'topK',
    label: 'Top K',
    description: '从概率最高的 K 个 token 中采样',
    inputType: ParameterInputType.slider,
    defaultValue: 40,
    category: ParameterCategory.basic,
    providers: [
      ProviderType.anthropic,
      ProviderType.gemini,
      ProviderType.openaiCompatible,
    ],
    rangeMin: 1,
    rangeMax: 100,
    rangeStep: 1,
    marks: [
      SliderMark(value: 1, label: '1'),
      SliderMark(value: 40, label: '40'),
      SliderMark(value: 100, label: '100'),
    ],
  ),

  // ==================== 高级参数 ====================
  ParameterMeta(
    key: 'frequencyPenalty',
    label: '频率惩罚',
    description: '降低重复使用相同词语的可能性',
    inputType: ParameterInputType.slider,
    defaultValue: 0.0,
    category: ParameterCategory.advanced,
    providers: [ProviderType.openai, ProviderType.openaiCompatible],
    rangeMin: -2,
    rangeMax: 2,
    rangeStep: 0.1,
    marks: [
      SliderMark(value: -2, label: '-2'),
      SliderMark(value: 0, label: '0'),
      SliderMark(value: 2, label: '2'),
    ],
  ),
  ParameterMeta(
    key: 'presencePenalty',
    label: '存在惩罚',
    description: '降低重复已出现主题的可能性',
    inputType: ParameterInputType.slider,
    defaultValue: 0.0,
    category: ParameterCategory.advanced,
    providers: [ProviderType.openai, ProviderType.openaiCompatible],
    rangeMin: -2,
    rangeMax: 2,
    rangeStep: 0.1,
    marks: [
      SliderMark(value: -2, label: '-2'),
      SliderMark(value: 0, label: '0'),
      SliderMark(value: 2, label: '2'),
    ],
  ),
  ParameterMeta(
    key: 'seed',
    label: '随机种子',
    description: '设置相同种子可获得确定性输出',
    inputType: ParameterInputType.number,
    defaultValue: null,
    category: ParameterCategory.advanced,
    providers: [ProviderType.openai, ProviderType.openaiCompatible],
  ),
  ParameterMeta(
    key: 'stopSequences',
    label: '停止序列',
    description: '遇到这些文本时停止生成 (逗号分隔)',
    inputType: ParameterInputType.text,
    defaultValue: '',
    category: ParameterCategory.advanced,
    providers: ProviderType.values,
  ),
  ParameterMeta(
    key: 'responseFormat',
    label: '响应格式',
    description: '指定输出格式',
    inputType: ParameterInputType.select,
    defaultValue: 'text',
    category: ParameterCategory.advanced,
    providers: [ProviderType.openai, ProviderType.openaiCompatible],
    options: [
      SelectOption(value: 'text', label: '文本'),
      SelectOption(value: 'json_object', label: 'JSON 对象'),
    ],
  ),
  ParameterMeta(
    key: 'streamOutput',
    label: '流式输出',
    description: '启用流式输出，实时显示生成内容。关闭后将等待完整响应后一次性显示',
    inputType: ParameterInputType.switchToggle,
    defaultValue: true,
    defaultEnabled: true,
    category: ParameterCategory.advanced,
    providers: ProviderType.values,
  ),
  ParameterMeta(
    key: 'parallelToolCalls',
    label: '并行工具调用',
    description: '允许模型同时调用多个工具',
    inputType: ParameterInputType.switchToggle,
    defaultValue: true,
    category: ParameterCategory.advanced,
    providers: [ProviderType.openai, ProviderType.openaiCompatible],
  ),
  ParameterMeta(
    key: 'logprobs',
    label: 'Token 概率',
    description: '返回每个 token 的概率信息',
    inputType: ParameterInputType.switchToggle,
    defaultValue: false,
    category: ParameterCategory.advanced,
    providers: [ProviderType.openai],
  ),
  ParameterMeta(
    key: 'user',
    label: '用户标识',
    description: '用于追踪和分析的用户 ID',
    inputType: ParameterInputType.text,
    defaultValue: '',
    category: ParameterCategory.advanced,
    providers: [ProviderType.openai, ProviderType.anthropic],
  ),

  // ==================== 推理参数 ====================
  ParameterMeta(
    key: 'reasoningEffort',
    label: '推理努力程度',
    description: '控制模型思考的深度',
    inputType: ParameterInputType.select,
    defaultValue: 'medium',
    category: ParameterCategory.reasoning,
    providers: ProviderType.values,
    options: [
      SelectOption(value: 'off', label: '关闭'),
      SelectOption(value: 'low', label: '低'),
      SelectOption(value: 'medium', label: '中 (推荐)'),
      SelectOption(value: 'high', label: '高'),
    ],
  ),
  ParameterMeta(
    key: 'thinkingBudget',
    label: '思考预算',
    description: '分配给思考过程的 token 数量',
    inputType: ParameterInputType.slider,
    defaultValue: 2048,
    category: ParameterCategory.reasoning,
    providers: ProviderType.values,
    rangeMin: 128,
    rangeMax: 32768,
    rangeStep: 128,
    marks: [
      SliderMark(value: 128, label: '128'),
      SliderMark(value: 4096, label: '4K'),
      SliderMark(value: 16384, label: '16K'),
      SliderMark(value: 32768, label: '32K'),
    ],
    unit: 'tokens',
    showWhen: ShowWhen(
      key: 'reasoningEffort',
      values: ['minimal', 'low', 'medium', 'high', 'xhigh', 'auto'],
    ),
  ),
  ParameterMeta(
    key: 'includeThoughts',
    label: '显示思考过程',
    description: '在响应中包含模型的思考过程',
    inputType: ParameterInputType.switchToggle,
    defaultValue: true,
    category: ParameterCategory.reasoning,
    providers: [ProviderType.gemini],
    showWhen: ShowWhen(
      key: 'reasoningEffort',
      values: ['minimal', 'low', 'medium', 'high', 'xhigh', 'auto'],
    ),
  ),

  // ==================== Anthropic 特有参数 ====================
  ParameterMeta(
    key: 'cacheControl',
    label: '提示缓存',
    description: '启用提示缓存以加速重复请求',
    inputType: ParameterInputType.switchToggle,
    defaultValue: false,
    category: ParameterCategory.advanced,
    providers: [ProviderType.anthropic],
  ),

  ParameterMeta(
    key: 'structuredOutputMode',
    label: '结构化输出模式',
    description: '控制结构化输出的生成方式',
    inputType: ParameterInputType.select,
    defaultValue: 'auto',
    category: ParameterCategory.advanced,
    providers: [ProviderType.anthropic],
    options: [
      SelectOption(value: 'auto', label: '自动'),
      SelectOption(value: 'outputFormat', label: '输出格式'),
      SelectOption(value: 'jsonTool', label: 'JSON 工具'),
    ],
  ),

  // ==================== 工具参数 ====================
  ParameterMeta(
    key: 'webSearchEnabled',
    label: 'Web 搜索',
    description: '允许模型搜索网络获取最新信息',
    inputType: ParameterInputType.switchToggle,
    defaultValue: false,
    category: ParameterCategory.tools,
    providers: [ProviderType.anthropic],
  ),
  ParameterMeta(
    key: 'codeExecutionEnabled',
    label: '代码执行',
    description: '允许模型执行 Python 代码',
    inputType: ParameterInputType.switchToggle,
    defaultValue: false,
    category: ParameterCategory.tools,
    providers: [ProviderType.anthropic],
  ),
  ParameterMeta(
    key: 'useSearchGrounding',
    label: 'Google 搜索',
    description: '使用 Google 搜索获取最新信息',
    inputType: ParameterInputType.switchToggle,
    defaultValue: false,
    category: ParameterCategory.tools,
    providers: [ProviderType.gemini],
  ),

  // ==================== Gemini 安全设置 ====================
  ParameterMeta(
    key: 'safetyLevel',
    label: '安全级别',
    description: '控制内容安全过滤强度',
    inputType: ParameterInputType.select,
    defaultValue: 'BLOCK_MEDIUM_AND_ABOVE',
    category: ParameterCategory.advanced,
    providers: [ProviderType.gemini],
    options: [
      SelectOption(value: 'BLOCK_NONE', label: '无限制'),
      SelectOption(value: 'BLOCK_ONLY_HIGH', label: '仅阻止高风险'),
      SelectOption(value: 'BLOCK_MEDIUM_AND_ABOVE', label: '阻止中等及以上风险'),
      SelectOption(value: 'BLOCK_LOW_AND_ABOVE', label: '阻止低等及以上风险'),
    ],
  ),
];

/// Returns only the parameters applicable to [provider].
List<ParameterMeta> getParametersForProvider(ProviderType provider) {
  return kParameterMetadata
      .where((p) => p.providers.contains(provider))
      .toList();
}

/// Detects the provider type from a model id string.
ProviderType detectProviderFromModel(String? modelId) {
  if (modelId == null || modelId.isEmpty) return ProviderType.openaiCompatible;
  final id = modelId.toLowerCase();
  if (id.contains('claude') || id.contains('anthropic')) {
    return ProviderType.anthropic;
  }
  if (id.contains('gemini') || id.contains('palm')) {
    return ProviderType.gemini;
  }
  if (id.contains('gpt') ||
      id.contains('o1') ||
      id.contains('o3') ||
      id.contains('o4')) {
    return ProviderType.openai;
  }
  return ProviderType.openaiCompatible;
}

/// Maps the LLM protocol string to [ProviderType].
ProviderType providerTypeFromProtocolKey(String key) {
  final k = key.toLowerCase();
  if (k == 'anthropic' || k == 'claude') return ProviderType.anthropic;
  if (k == 'gemini' || k == 'google') return ProviderType.gemini;
  if (k == 'openai') return ProviderType.openai;
  return ProviderType.openaiCompatible;
}

/// Category display labels (Chinese).
String categoryLabel(ParameterCategory c) => switch (c) {
  ParameterCategory.basic => '基础参数',
  ParameterCategory.advanced => '高级参数',
  ParameterCategory.reasoning => '推理参数',
  ParameterCategory.tools => '工具参数',
};
