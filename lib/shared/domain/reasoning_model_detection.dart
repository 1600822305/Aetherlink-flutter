// Reasoning model detection & per-model reasoning-effort option mapping.
//
// Direct port of web `src/config/models/reasoning.ts`, `openai.ts`, `utils.ts`.
// Determines the ThinkingModelType from a model ID, then maps it to the set of
// ReasoningEffortOption values the model supports.

import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';

// ─── ThinkingModelType ───────────────────────────────────────────────────────

enum ThinkingModelType {
  defaultType,
  o,
  openaiDeepResearch,
  gpt5,
  gpt5pro,
  gpt5Codex,
  gpt5_1,
  gpt5_1Codex,
  gpt5_1CodexMax,
  gpt5_2,
  gpt52pro,
  grok,
  grok4Fast,
  gemini2Flash,
  gemini2Pro,
  gemini3Flash,
  gemini3Pro,
  qwen,
  qwenThinking,
  doubao,
  doubaoNoAuto,
  doubaoAfter251015,
  mimo,
  hunyuan,
  zhipu,
  perplexity,
  deepseekHybrid,
}

// ─── MODEL_SUPPORTED_OPTIONS ─────────────────────────────────────────────────

const Map<ThinkingModelType, List<String>> _modelSupportedOptions = {
  ThinkingModelType.defaultType: ['default', 'none', 'low', 'medium', 'high'],
  ThinkingModelType.o: ['default', 'low', 'medium', 'high'],
  ThinkingModelType.openaiDeepResearch: ['default', 'medium'],
  ThinkingModelType.gpt5: ['default', 'minimal', 'low', 'medium', 'high'],
  ThinkingModelType.gpt5pro: ['default', 'high'],
  ThinkingModelType.gpt5Codex: ['default', 'low', 'medium', 'high'],
  ThinkingModelType.gpt5_1: ['default', 'none', 'low', 'medium', 'high'],
  ThinkingModelType.gpt5_1Codex: ['default', 'none', 'medium', 'high'],
  ThinkingModelType.gpt5_1CodexMax: [
    'default',
    'none',
    'medium',
    'high',
    'xhigh',
  ],
  ThinkingModelType.gpt5_2: [
    'default',
    'none',
    'low',
    'medium',
    'high',
    'xhigh',
  ],
  ThinkingModelType.gpt52pro: ['default', 'medium', 'high', 'xhigh'],
  ThinkingModelType.grok: ['default', 'low', 'high'],
  ThinkingModelType.grok4Fast: ['default', 'none', 'auto'],
  ThinkingModelType.gemini2Flash: [
    'default',
    'none',
    'low',
    'medium',
    'high',
    'auto',
  ],
  ThinkingModelType.gemini2Pro: ['default', 'low', 'medium', 'high', 'auto'],
  ThinkingModelType.gemini3Flash: [
    'default',
    'minimal',
    'low',
    'medium',
    'high',
  ],
  ThinkingModelType.gemini3Pro: ['default', 'low', 'high'],
  ThinkingModelType.qwen: ['default', 'none', 'low', 'medium', 'high'],
  ThinkingModelType.qwenThinking: ['default', 'low', 'medium', 'high'],
  ThinkingModelType.doubao: ['default', 'none', 'auto', 'high'],
  ThinkingModelType.doubaoNoAuto: ['default', 'none', 'high'],
  ThinkingModelType.doubaoAfter251015: [
    'default',
    'minimal',
    'low',
    'medium',
    'high',
  ],
  ThinkingModelType.mimo: ['default', 'none', 'auto'],
  ThinkingModelType.hunyuan: ['default', 'none', 'auto'],
  ThinkingModelType.zhipu: ['default', 'none', 'auto'],
  ThinkingModelType.perplexity: ['default', 'low', 'medium', 'high'],
  ThinkingModelType.deepseekHybrid: ['none', 'high', 'xhigh'],
};

// ─── Label map ───────────────────────────────────────────────────────────────

const Map<String, String> _reasoningEffortLabels = {
  'default': '默认',
  'none': '关闭',
  'off': '关闭',
  'minimal': '极简',
  'low': '低',
  'medium': '中 (推荐)',
  'high': '高',
  'xhigh': '最高',
  'auto': '自动',
};

// ─── Regex helpers (ported from web) ─────────────────────────────────────────

String _lowerBase(String id) {
  final parts = id.split('/');
  var base = parts.last.toLowerCase();
  if (base.endsWith(':free')) base = base.replaceAll(':free', '');
  return base;
}

// OpenAI series
final _gpt5Regex = RegExp(r'^gpt-5(?:-[\w-]+)?$', caseSensitive: false);
final _gpt5ProRegex = RegExp(r'^gpt-5-pro(?:-[\w-]+)?$', caseSensitive: false);
final _gpt51Regex = RegExp(r'^gpt-5\.1(?:-[\w-]+)?$', caseSensitive: false);
// _gpt51CodexRegex intentionally kept for future use if needed.
// final _gpt51CodexRegex =
//     RegExp(r'^gpt-5\.1-codex(?:-[\w-]+)?$', caseSensitive: false);
final _gpt51CodexMaxRegex =
    RegExp(r'^gpt-5\.1-codex-max(?:-[\w-]+)?$', caseSensitive: false);
final _gpt52Regex = RegExp(r'^gpt-5\.2(?:-[\w-]+)?$', caseSensitive: false);
final _gpt52ProRegex =
    RegExp(r'^gpt-5\.2-pro(?:-[\w-]+)?$', caseSensitive: false);
final _openaiReasoningRegex =
    RegExp(r'^(o1|o3|o4)(?:-[\w-]+)?$', caseSensitive: false);
final _openaiDeepResearchRegex =
    RegExp(r'^(o3-deep-research|o4-deep-research)(?:-[\w-]+)?$',
        caseSensitive: false);
final _openaiOpenWeightRegex =
    RegExp(r'^(o1-open|o3-open|o4-open)(?:-[\w-]+)?$', caseSensitive: false);

// Gemini
final _geminiFlashRegex = RegExp(r'gemini.*-flash.*$', caseSensitive: false);
final _gemini3FlashRegex =
    RegExp(r'gemini-3-flash(?!-image)(?:-[\w-]+)*$', caseSensitive: false);
final _gemini3ProRegex =
    RegExp(r'gemini-3-pro(?!-image)(?:-[\w-]+)*$', caseSensitive: false);

// Minimax
final _minimaxRegex = RegExp(r'minimax-m\d', caseSensitive: false);

// Reasoning catch-all
final _reasoningRegex = RegExp(
  r'^(?!.*-non-reasoning\b)'
  r'(o\d+(?:-[\w-]+)?'
  r'|.*\b(?:reasoning|reasoner|thinking|think)\b.*'
  r'|.*-[rR]\d+.*'
  r'|.*\bqwq(?:-[\w-]+)?\b.*'
  r'|.*\bhunyuan-t1(?:-[\w-]+)?\b.*'
  r'|.*\bglm-zero-preview\b.*'
  r'|.*\bgrok-(?:3-mini|3-thinking|4|4-fast)(?:-[\w-]+)?\b.*'
  r'|.*\bqwen3-omni(?:-[\w-]+)?\b.*)$',
  caseSensitive: false,
);

// ─── Model detection functions ───────────────────────────────────────────────

bool _isGPT5Series(String id) => _gpt5Regex.hasMatch(id);
bool _isGPT5Pro(String id) => _gpt5ProRegex.hasMatch(id);
bool _isGPT51Series(String id) => _gpt51Regex.hasMatch(id);
bool _isGPT51CodexMax(String id) => _gpt51CodexMaxRegex.hasMatch(id);
bool _isGPT52Series(String id) => _gpt52Regex.hasMatch(id);
bool _isGPT52Pro(String id) => _gpt52ProRegex.hasMatch(id);

bool _isOpenAIReasoning(String id) =>
    _openaiReasoningRegex.hasMatch(id) ||
    _isGPT5Series(id) ||
    _isGPT51Series(id) ||
    _isGPT52Series(id);
bool _isOpenAIDeepResearch(String id) => _openaiDeepResearchRegex.hasMatch(id);
bool _isOpenAIOpenWeight(String id) => _openaiOpenWeightRegex.hasMatch(id);
bool _isSupportedReasoningEffortOpenAI(String id) =>
    _isOpenAIReasoning(id) && !_isOpenAIOpenWeight(id);

bool _isGrokReasoning(String id) =>
    id.contains('grok-3-mini') || id.contains('grok-3-thinking');
bool _isGrok4Fast(String id) => id.contains('grok-4-fast');

// Claude detection kept for potential future use.
// bool _isClaudeReasoning(String id) => id.contains('claude-3');
// bool _isClaude45(String id) =>
//     id.contains('claude-4.5') || id.contains('claude-4-5');

bool _isGemini3Flash(String id) {
  if (id == 'gemini-flash-latest') return true;
  return _gemini3FlashRegex.hasMatch(id);
}

bool _isGemini3Pro(String id) {
  if (id == 'gemini-pro-latest') return true;
  return _gemini3ProRegex.hasMatch(id);
}

bool _isSupportedThinkingTokenGemini(String id) =>
    id.contains('gemini-2.5') ||
    id.contains('gemini-2.0') ||
    _isGemini3Flash(id) ||
    _isGemini3Pro(id);

bool _isQwenReasoning(String id) =>
    id.contains('qwen3') ||
    id.contains('qwen-max') ||
    id.contains('qwen-plus') ||
    id.contains('qwq') ||
    id.contains('qwen2.5') ||
    id.contains('qwen2');
bool _isQwenAlwaysThink(String id) =>
    id.contains('qwq') ||
    id.contains('qwen3-thinking') ||
    id.contains('qwen-omni-thinking');

bool _isDeepSeekHybrid(String id) => id.contains('deepseek-v4');
bool _isDeepSeekReasoning(String id) {
  if (_isDeepSeekHybrid(id)) return true;
  if (id.contains('deepseek-reasoner') || id.contains('deepseek-coder')) {
    return true;
  }
  return false;
}

bool _isZhipuReasoning(String id) =>
    id.contains('glm-z1') || id.contains('glm-4');

bool _isMinimaxReasoning(String id) => _minimaxRegex.hasMatch(id);

bool _isDoubaoReasoning(String id) =>
    id.contains('doubao') &&
    (id.contains('thinking') ||
        id.contains('reasoner') ||
        id.contains('seed-1-8'));
bool _isDoubao16Thinking(String id) =>
    id.contains('doubao-seed-1-6-thinking') || id.contains('doubao-seed-1-8');
bool _isDoubaoNoAuto(String id) =>
    id.contains('doubao') &&
    id.contains('thinking') &&
    !id.contains('seed-1-6') &&
    !id.contains('seed-1-8');

bool _isHunyuanReasoning(String id) => id.contains('hunyuan-t1');
bool _isMimoReasoning(String id) => id.contains('mimo');
bool _isPerplexityModel(String id) => id.contains('perplexity');

// ─── getThinkModelType ───────────────────────────────────────────────────────

ThinkingModelType getThinkModelType(String? modelId) {
  if (modelId == null || modelId.isEmpty) return ThinkingModelType.defaultType;
  final id = _lowerBase(modelId);

  if (_isOpenAIDeepResearch(id)) return ThinkingModelType.openaiDeepResearch;

  if (_isGPT51Series(id)) {
    if (id.contains('codex')) {
      return _isGPT51CodexMax(id)
          ? ThinkingModelType.gpt5_1CodexMax
          : ThinkingModelType.gpt5_1Codex;
    }
    return ThinkingModelType.gpt5_1;
  }
  if (_isGPT52Series(id)) {
    return _isGPT52Pro(id)
        ? ThinkingModelType.gpt52pro
        : ThinkingModelType.gpt5_2;
  }
  if (_isGPT5Series(id)) {
    if (id.contains('codex')) return ThinkingModelType.gpt5Codex;
    return _isGPT5Pro(id)
        ? ThinkingModelType.gpt5pro
        : ThinkingModelType.gpt5;
  }
  if (_isSupportedReasoningEffortOpenAI(id)) return ThinkingModelType.o;

  if (_isGrok4Fast(id)) return ThinkingModelType.grok4Fast;

  if (_isSupportedThinkingTokenGemini(id)) {
    if (_isGemini3Flash(id)) return ThinkingModelType.gemini3Flash;
    if (_isGemini3Pro(id)) return ThinkingModelType.gemini3Pro;
    if (_geminiFlashRegex.hasMatch(id)) return ThinkingModelType.gemini2Flash;
    return ThinkingModelType.gemini2Pro;
  }

  if (_isGrokReasoning(id)) return ThinkingModelType.grok;

  if (_isQwenReasoning(id)) {
    return _isQwenAlwaysThink(id)
        ? ThinkingModelType.qwenThinking
        : ThinkingModelType.qwen;
  }

  if (_isDeepSeekReasoning(id)) return ThinkingModelType.deepseekHybrid;
  if (_isZhipuReasoning(id)) return ThinkingModelType.zhipu;

  if (_isDoubaoReasoning(id)) {
    if (_isDoubao16Thinking(id)) return ThinkingModelType.doubaoAfter251015;
    if (_isDoubaoNoAuto(id)) return ThinkingModelType.doubaoNoAuto;
    return ThinkingModelType.doubao;
  }

  if (_isHunyuanReasoning(id)) return ThinkingModelType.hunyuan;
  if (_isMimoReasoning(id)) return ThinkingModelType.mimo;
  if (_isPerplexityModel(id)) return ThinkingModelType.perplexity;
  if (_isMinimaxReasoning(id)) return ThinkingModelType.defaultType;

  // Catch-all: check general reasoning regex
  if (_reasoningRegex.hasMatch(id)) return ThinkingModelType.defaultType;

  return ThinkingModelType.defaultType;
}

// ─── Public API ──────────────────────────────────────────────────────────────

/// Fallback options when no model info is available (matches web's
/// `DEFAULT_REASONING_EFFORT_OPTIONS`).
const List<SelectOption> _defaultReasoningEffortOptions = [
  SelectOption(value: 'off', label: '关闭'),
  SelectOption(value: 'low', label: '低'),
  SelectOption(value: 'medium', label: '中 (推荐)'),
  SelectOption(value: 'high', label: '高'),
];

/// Returns the reasoning-effort options available for [modelId].
///
/// When [modelId] is null/empty, returns the static defaults (off/low/medium/high).
/// Otherwise, detects the model type and returns the model-specific options with
/// Chinese labels (same as web's `getReasoningEffortOptions`).
List<SelectOption> getReasoningEffortOptions(String? modelId) {
  if (modelId == null || modelId.isEmpty) {
    return _defaultReasoningEffortOptions;
  }
  final type = getThinkModelType(modelId);
  final efforts = _modelSupportedOptions[type] ??
      _modelSupportedOptions[ThinkingModelType.defaultType]!;
  if (efforts.isEmpty) return _defaultReasoningEffortOptions;
  return efforts
      .map(
        (e) => SelectOption(value: e, label: _reasoningEffortLabels[e] ?? e),
      )
      .toList();
}
