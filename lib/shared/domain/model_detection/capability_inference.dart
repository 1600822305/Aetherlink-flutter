/// Model capability inference from a raw model ID.
///
/// Faithful Dart port of the "Model-ID inference helpers" in cherry-studio's
/// `src/shared/utils/model.ts` (the `inferXxxFromModelId` family) and the
/// `inferCapabilities` combiner in `src/renderer/config/models/bridge.ts`.
///
/// These regexes are the **fallback** path: the bundled `models.json` registry
/// is the authoritative source. When a model is not in the registry (custom
/// endpoints, brand-new SKUs), inference fills [ModelCapabilities] from the id.
///
/// Runtime checks must NOT call these — they read the populated
/// [Model.capabilities] field instead (see `model_checks.dart`).
library;

import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_id_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Regex constants (ported 1:1 from model.ts)
// ─────────────────────────────────────────────────────────────────────────────

final RegExp _reasoningRegex = RegExp(
  r'^(?!.*-non-reasoning\b)(o\d+(?:-[\w-]+)?'
  r'|.*\b(?:reasoning|reasoner|thinking|think)\b.*'
  r'|.*-[rR]\d+.*'
  r'|.*\bqwq(?:-[\w-]+)?\b.*'
  r'|.*\bhunyuan-t1(?:-[\w-]+)?\b.*'
  r'|.*\bglm-zero-preview\b.*'
  r'|.*\bgrok-(?:3-mini|4|4-fast)(?:-[\w-]+)?\b.*)$',
  caseSensitive: false,
);

final RegExp _geminiThinkingRegex = RegExp(
  r'gemini-(?:2\.5.*(?:-latest)?|3(?:\.\d+)?-(?:flash|pro)(?:-preview)?|flash-latest|pro-latest|flash-lite-latest)(?:-[\w-]+)*$',
  caseSensitive: false,
);

final RegExp _doubaoThinkingRegex = RegExp(
  r'doubao-(?:1[.-]5-thinking-vision-pro|1[.-]5-thinking-pro-m|seed-1[.-][68](?:-flash)?(?!-(?:thinking)(?:-|$))|seed-code(?:-preview)?(?:-\d+)?|seed-2[.-]0(?:-[\w-]+)?)(?:-[\w-]+)*',
  caseSensitive: false,
);

final RegExp _deepSeekV4PlusRegex = RegExp(
  r'deepseek-v(?:[4-9]\d*|[1-9]\d{1,})(?:\.\d+)?(?:-[\w]+)*(?=$|[:/])',
  caseSensitive: false,
);

final RegExp _embeddingRegex = RegExp(
  r'(?:^text-|embed|bge-|e5-|LLM2Vec|retrieval|uae-|gte-|jina-clip|jina-embeddings|voyage-)',
  caseSensitive: false,
);

final RegExp _rerankingRegex = RegExp(
  r'(?:rerank|re-rank|re-ranker|re-ranking|retrieval|retriever)',
  caseSensitive: false,
);

const List<String> _dedicatedImageModels = [
  r'dall-e(?:-[\w-]+)?',
  r'gpt-image(?:-[\w-]+)?',
  r'grok-2-image(?:-[\w-]+)?',
  r'imagen(?:-[\w-]+)?',
  r'flux(?:-[\w-]+)?',
  r'stable-?diffusion(?:-[\w-]+)?',
  r'stabilityai(?:-[\w-]+)?',
  r'sd-[\w-]+',
  r'sdxl(?:-[\w-]+)?',
  r'cogview(?:-[\w-]+)?',
  r'qwen-image(?:-[\w-]+)?',
  r'janus(?:-[\w-]+)?',
  r'midjourney(?:-[\w-]+)?',
  r'mj-[\w-]+',
  r'z-image(?:-[\w-]+)?',
  r'longcat-image(?:-[\w-]+)?',
  r'hunyuanimage(?:-[\w-]+)?',
  r'seedream(?:-[\w-]+)?',
  r'kandinsky(?:-[\w-]+)?',
];

final RegExp _dedicatedImageRegex = RegExp(_dedicatedImageModels.join('|'), caseSensitive: false);

const List<String> _imageEnhancementModels = [
  r'grok-2-image(?:-[\w-]+)?',
  r'qwen-image-edit',
  r'gpt-image-1',
  r'gemini-2.5-flash-image(?:-[\w-]+)?',
  r'gemini-2.0-flash-preview-image-generation',
  r'gemini-3(?:\.\d+)?-(?:flash|pro)-image(?:-[\w-]+)?',
];

final RegExp _imageEnhancementRegex = RegExp(_imageEnhancementModels.join('|'), caseSensitive: false);

const List<String> _visionAllowedModels = [
  'llava',
  'moondream',
  'minicpm',
  r'gemini-1\.5',
  r'gemini-2\.0',
  r'gemini-2\.5',
  r'gemini-3(?:\.\d)?-(?:flash|pro)(?:-preview)?',
  'gemini-(flash|pro|flash-lite)-latest',
  'gemini-exp',
  'claude-3',
  r'claude-(?:haiku|sonnet|opus)-[4-9]',
  'vision',
  r'glm-4(?:\.\d+)?v(?:-[\w-]+)?',
  'qwen-vl',
  'qwen2-vl',
  'qwen2.5-vl',
  'qwen3-vl',
  r'qwen3\.[5-9](?:-[\w-]+)?',
  'qwen2.5-omni',
  r'qwen3-omni(?:-[\w-]+)?',
  'qvq',
  'internvl2',
  'grok-vision-beta',
  r'grok-4(?:-[\w-]+)?',
  'pixtral',
  r'gpt-4(?:-[\w-]+)',
  r'gpt-4.1(?:-[\w-]+)?',
  r'gpt-4o(?:-[\w-]+)?',
  r'gpt-4.5(?:-[\w-]+)',
  r'gpt-5(?:-[\w-]+)?',
  r'chatgpt-4o(?:-[\w-]+)?',
  r'o1(?:-[\w-]+)?',
  r'o3(?:-[\w-]+)?',
  r'o4(?:-[\w-]+)?',
  r'deepseek-vl(?:[\w-]+)?',
  r'kimi-k2\.[56](?:-[\w-]+)?',
  'kimi-latest',
  r'gemma-?[3-4](?:[-.\w]+)?',
  r'doubao-seed-1[.-][68](?:-[\w-]+)?',
  r'doubao-seed-2[.-]0(?:-[\w-]+)?',
  r'doubao-seed-code(?:-[\w-]+)?',
  'kimi-thinking-preview',
  r'gemma3(?:[-:\w]+)?',
  r'kimi-vl-a3b-thinking(?:-[\w-]+)?',
  r'llama-guard-4(?:-[\w-]+)?',
  r'llama-4(?:-[\w-]+)?',
  'step-1o(?:.*vision)?',
  r'step-1v(?:-[\w-]+)?',
  r'qwen-omni(?:-[\w-]+)?',
  'mistral-large-(2512|latest)',
  'mistral-medium-(2508|latest)',
  'mistral-small-(2506|2603|latest)',
  r'mimo-v2\.5(?!-)',
  r'mimo-v2-omni(?:-[\w-]+)?',
  'glm-5v-turbo',
];

const List<String> _visionExcludedModels = [
  r'gpt-4-\d+-preview',
  'gpt-4-turbo-preview',
  'gpt-4-32k',
  r'gpt-4-\d+',
  'o1-mini',
  'o3-mini',
  'o1-preview',
  'AIDC-AI/Marco-o1',
];

final RegExp _visionRegex = RegExp(
  r'\b(?!(?:' '${_visionExcludedModels.join('|')}' r')\b)(' '${_visionAllowedModels.join('|')}' r')\b',
  caseSensitive: false,
);

final RegExp _claudeWebSearchRegex = RegExp(
  r'\b(?:claude-3(-|\.)(7|5)-sonnet(?:-[\w-]+)|claude-3(-|\.)5-haiku(?:-[\w-]+)|claude-(haiku|sonnet|opus)-[4-9](?:-[\w-]+)?)\b',
  caseSensitive: false,
);

final RegExp _geminiSearchRegex = RegExp(
  r'gemini-(?:2(?!.*-image-preview).*(?:-latest)?|3(?:\.\d+)?-(?:flash|pro)(?:-(?:image-)?preview)?|flash-latest|pro-latest|flash-lite-latest)(?:-[\w-]+)*$',
  caseSensitive: false,
);

const List<String> _functionCallingAllowedModels = [
  'gpt-4o',
  'gpt-4o-mini',
  'gpt-4',
  'gpt-4.5',
  r'gpt-oss(?:-[\w-]+)?',
  r'gpt-5(?:-[0-9-]+)?',
  r'o(1|3|4)(?:-[\w-]+)?',
  'claude',
  'qwen',
  'qwen3',
  'hunyuan',
  'deepseek',
  r'glm-4(?:-[\w-]+)?',
  r'glm-4.5(?:-[\w-]+)?',
  r'glm-4.7(?:-[\w-]+)?',
  r'glm-5(?:-[\w-]+)?',
  r'learnlm(?:-[\w-]+)?',
  r'gemini(?:-[\w-]+)?',
  r'gemma-?4(?:[-.\w]+)?',
  r'grok-3(?:-[\w-]+)?',
  r'grok-4(?:-[\w-]+)?',
  r'doubao-seed-1[.-][68](?:-[\w-]+)?',
  r'doubao-seed-2[.-]0(?:-[\w-]+)?',
  r'doubao-seed-code(?:-[\w-]+)?',
  r'kimi-k2(?:-[\w-]+)?',
  r'ling-\w+(?:-[\w-]+)?',
  r'ring-\w+(?:-[\w-]+)?',
  r'minimax-m[23](?:\.\d+)?(?:-[\w-]+)?',
  r'mimo-v2\.5(?:-pro)?(?!-)',
  'mimo-v2-flash',
  'mimo-v2-pro',
  'mimo-v2-omni',
  'glm-5v-turbo',
];

const List<String> _functionCallingExcludedModels = [
  r'aqa(?:-[\w-]+)?',
  r'imagen(?:-[\w-]+)?',
  'o1-mini',
  'o1-preview',
  'AIDC-AI/Marco-o1',
  r'gemini-1(?:\.[\w-]+)?',
  r'qwen-mt(?:-[\w-]+)?',
  r'gpt-5-chat(?:-[\w-]+)?',
  r'glm-4\.5v',
  r'gemini-2.5-flash-image(?:-[\w-]+)?',
  'gemini-2.0-flash-preview-image-generation',
  r'gemini-3(?:\.\d+)?-pro-image(?:-[\w-]+)?',
  'deepseek-v3.2-speciale',
  r'deepseek-r1(?:[-:][\w.-]+)?',
];

final RegExp _functionCallingRegex = RegExp(
  r'\b(?!(?:' '${_functionCallingExcludedModels.join('|')}' r')\b)(?:'
  '${_functionCallingAllowedModels.join('|')}'
  r')\b',
  caseSensitive: false,
);

// ─────────────────────────────────────────────────────────────────────────────
// Internal vendor-specific reasoning sub-inferences
// ─────────────────────────────────────────────────────────────────────────────

bool _inferClaudeReasoning(String id) =>
    id.contains('claude-3-7-sonnet') ||
    id.contains('claude-3.7-sonnet') ||
    RegExp(r'claude-(?:haiku|sonnet|opus)-[4-9]').hasMatch(id);

bool _inferGeminiReasoning(String id) {
  if (id.startsWith('gemini') && id.contains('thinking')) return true;
  if (_geminiThinkingRegex.hasMatch(id)) {
    if (id.contains('gemini-3-pro-image')) return true;
    if (id.contains('image') || id.contains('tts')) return false;
    return true;
  }
  return false;
}

bool _inferQwenReasoning(String id) {
  if (id.startsWith('qwen3') && id.contains('thinking')) return true;
  if (id.contains('qwq') || id.contains('qvq')) return true;
  if (const ['coder', 'asr', 'tts', 'reranker', 'embedding', 'instruct', 'thinking'].any(id.contains)) {
    return false;
  }
  if (RegExp(r'^qwen3\.[5-9]').hasMatch(id)) return true;
  if (RegExp(r'^(?:qwen3-max(?!-2025-09-23)|qwen-max-latest)(?:-|$)', caseSensitive: false).hasMatch(id)) {
    return true;
  }
  if (RegExp(r'^qwen(?:3\.[5-9])?-(?:plus|flash|turbo)(?:-|$)', caseSensitive: false).hasMatch(id)) {
    return true;
  }
  if (RegExp(r'^qwen3-\d', caseSensitive: false).hasMatch(id)) return true;
  return false;
}

bool _inferDoubaoReasoning(String id) => _doubaoThinkingRegex.hasMatch(id) || _reasoningRegex.hasMatch(id);

bool _inferOpenAIReasoning(String id) {
  if (id.contains('o1') && !id.contains('o1-preview') && !id.contains('o1-mini')) return true;
  if (id.contains('o3') && !id.contains('o3-mini')) return true;
  if (id.startsWith('o3') || id.startsWith('o4')) return true;
  if (id.contains('gpt-oss')) return true;
  if (id.contains('gpt-5') && !id.contains('chat')) return true;
  return false;
}

bool _inferDeepSeekHybrid(String id) =>
    RegExp(r'(\w+-)?deepseek-v3(?:\.\d|-\d)(?:(\.|-)(?!speciale$)\w+)?$').hasMatch(id) ||
    id.contains('deepseek-chat-v3.1') ||
    id.contains('deepseek-chat') ||
    _deepSeekV4PlusRegex.hasMatch(id);

bool _inferOpenAIWebSearch(String id) =>
    id.contains('gpt-4o-search-preview') ||
    id.contains('gpt-4o-mini-search-preview') ||
    (id.contains('gpt-4.1') && !id.contains('gpt-4.1-nano')) ||
    (id.contains('gpt-4o') && !id.contains('gpt-4o-image')) ||
    id.contains('o3') ||
    id.contains('o4') ||
    (id.contains('gpt-5') && !id.contains('chat'));

// ─────────────────────────────────────────────────────────────────────────────
// Public per-capability inference (raw model id in, bool out)
// ─────────────────────────────────────────────────────────────────────────────

bool inferReasoningFromModelId(String rawModelId) {
  final id = lowerBaseModelName(rawModelId);
  return _reasoningRegex.hasMatch(id) ||
      _inferClaudeReasoning(id) ||
      _inferGeminiReasoning(id) ||
      _inferQwenReasoning(id) ||
      _inferDoubaoReasoning(id) ||
      _inferOpenAIReasoning(id) ||
      id.contains('hunyuan-t1') ||
      id.contains('hunyuan-a13b') ||
      RegExp(r'glm-?5|glm-4\.[567]|glm-z1').hasMatch(id) ||
      RegExp(r'mimo-v2\.5(?:-pro)?(?!-)|mimo-v2-(?:flash|pro|omni)').hasMatch(id) ||
      RegExp(r'^kimi-k2-thinking(?:-turbo)?$|^kimi-k(?:2\.[5-9]\d*|[3-9]\d*(?:\.\d+)?)(?:-[\w-]+)?$').hasMatch(id) ||
      id.contains('magistral') ||
      id.contains('mistral-small-2603') ||
      id.contains('grok-build') ||
      id.contains('pangu-pro-moe') ||
      id.contains('seed-oss') ||
      id.contains('deepseek-v3.2-speciale') ||
      id.contains('gemma-4') ||
      id.contains('gemma4') ||
      id.contains('step-3') ||
      id.contains('step-r1-v-mini') ||
      const ['minimax-m1', 'minimax-m2', 'minimax-m2.1', 'minimax-m3'].any(id.contains) ||
      id == 'baichuan-m2' ||
      id == 'baichuan-m3' ||
      const ['ring-1t', 'ring-mini', 'ring-flash'].any(id.contains) ||
      id.contains('sonar-deep-research') ||
      _inferDeepSeekHybrid(id);
}

bool inferVisionFromModelId(String rawModelId) {
  final id = lowerBaseModelName(rawModelId);
  if (RegExp(r'^qwen(?:3\.[5-9]-?max|[-]?max)(?:-|$)?').hasMatch(id)) return false;
  return _visionRegex.hasMatch(id) || _imageEnhancementRegex.hasMatch(id);
}

bool inferEmbeddingFromModelId(String rawModelId) {
  final id = lowerBaseModelName(rawModelId);
  if (_rerankingRegex.hasMatch(id)) return false;
  return _embeddingRegex.hasMatch(id);
}

bool inferRerankFromModelId(String rawModelId) => _rerankingRegex.hasMatch(lowerBaseModelName(rawModelId));

bool inferImageGenerationFromModelId(String rawModelId) {
  final id = lowerBaseModelName(rawModelId);
  return _dedicatedImageRegex.hasMatch(id) || _imageEnhancementRegex.hasMatch(id);
}

bool inferWebSearchFromModelId(String rawModelId) {
  final id = lowerBaseModelName(rawModelId, '/');
  if (_claudeWebSearchRegex.hasMatch(id)) return true;
  if (_inferOpenAIWebSearch(id)) return true;
  if (_geminiSearchRegex.hasMatch(id)) return true;
  // Hunyuan: every SKU except hunyuan-lite ships with web search.
  if (id.startsWith('hunyuan') && id != 'hunyuan-lite') return true;
  // Perplexity sonar family.
  if (RegExp(r'^sonar(?:-|$)').hasMatch(id)) return true;
  return false;
}

bool inferFunctionCallingFromModelId(String rawModelId) {
  final id = lowerBaseModelName(rawModelId);
  if (_embeddingRegex.hasMatch(id)) return false;
  if (_rerankingRegex.hasMatch(id)) return false;
  if (_dedicatedImageRegex.hasMatch(id)) return false;
  return _functionCallingRegex.hasMatch(id);
}

// ─────────────────────────────────────────────────────────────────────────────
// Combiner — raw id → ModelCapabilities (port of bridge.ts inferCapabilities)
// ─────────────────────────────────────────────────────────────────────────────

/// Infer a [ModelCapabilities] purely from a model id. Inference runs on the
/// id only (running it on the display name would conflate unrelated strings).
/// Returns `null` when nothing is inferred, so callers can leave the field
/// unset rather than storing an all-false object.
ModelCapabilities? inferCapabilitiesFromModelId(String rawModelId) {
  if (rawModelId.isEmpty) return null;

  final reasoning = inferReasoningFromModelId(rawModelId);
  final vision = inferVisionFromModelId(rawModelId);
  final imageGen = inferImageGenerationFromModelId(rawModelId);
  final embedding = inferEmbeddingFromModelId(rawModelId);
  final rerank = inferRerankFromModelId(rawModelId);
  final webSearch = inferWebSearchFromModelId(rawModelId);
  final functionCalling = inferFunctionCallingFromModelId(rawModelId);

  if (!reasoning &&
      !vision &&
      !imageGen &&
      !embedding &&
      !rerank &&
      !webSearch &&
      !functionCalling) {
    return null;
  }

  return ModelCapabilities(
    reasoning: reasoning ? true : null,
    vision: vision ? true : null,
    multimodal: vision ? true : null,
    imageGeneration: imageGen ? true : null,
    embedding: embedding ? true : null,
    rerank: rerank ? true : null,
    webSearch: webSearch ? true : null,
    functionCalling: functionCalling ? true : null,
    toolUse: functionCalling ? true : null,
  );
}
