/// Vendor identity regex patterns — the single source of truth for
/// "which vendor does this raw model ID belong to".
///
/// Faithful Dart port of cherry-studio's
/// `packages/provider-registry/src/patterns/vendor-patterns.ts`.
///
/// Patterns assume the id has already been lowercased and had the leading
/// namespace stripped — pair with [lowerBaseModelName] / [normalizeModelId].
library;

import 'package:aetherlink_flutter/shared/domain/model_detection/model_id_utils.dart';

/// Match raw (normalized) model IDs to their vendor. Matchers are mutually
/// exclusive at the vendor level (a model belongs to at most one vendor).
final Map<String, RegExp> vendorPatterns = {
  // Anthropic / Claude family. Also matches AWS Bedrock `anthropic.claude-*`.
  'anthropic': RegExp(r'^(?:anthropic\.)?claude', caseSensitive: false),
  // Google Gemini family.
  'gemini': RegExp(r'gemini|palm|veo|imagen|learnlm', caseSensitive: false),
  // Google Gemma family.
  'gemma': RegExp(r'gemma-|gemma4', caseSensitive: false),
  // xAI Grok family.
  'grok': RegExp(r'grok', caseSensitive: false),
  // OpenAI (chat + reasoning + legacy). GPT-n and bare o<digit>-series.
  'openai': RegExp(r'\bgpt\b|^o[134]', caseSensitive: false),
  // Alibaba Qwen family (qwen, qwq, qvq).
  'qwen': RegExp(r'^qwen|^qwq|^qvq|^tongyi', caseSensitive: false),
  // ByteDance Doubao family.
  'doubao': RegExp(r'doubao|seed|seedance|seedream|^ep-', caseSensitive: false),
  // Tencent Hunyuan family.
  'hunyuan': RegExp(r'^hunyuan|hy-', caseSensitive: false),
  // Moonshot / Kimi family.
  'kimi': RegExp(r'kimi|moonshot', caseSensitive: false),
  // DeepSeek family.
  'deepseek': RegExp(r'deepseek', caseSensitive: false),
  // Perplexity (sonar family).
  'perplexity': RegExp(r'^sonar', caseSensitive: false),
  // Baichuan family.
  'baichuan': RegExp(r'^baichuan', caseSensitive: false),
  // Xiaomi MiMo family.
  'mimo': RegExp(r'^mimo-', caseSensitive: false),
  // Ant Group Ling / Ring family.
  'ling': RegExp(r'^(?:ling|ring)-', caseSensitive: false),
  // MiniMax family.
  'minimax': RegExp(r'^minimax', caseSensitive: false),
  // StepFun family.
  'step': RegExp(r'^step-', caseSensitive: false),
  // Zhipu / GLM family.
  'zhipu': RegExp(r'glm|cogview|cogvideo', caseSensitive: false),
  // Mistral family.
  'mistral': RegExp(
    r'mistral|pixtral|codestral|ministral|voxtral|devstral|mixtral|magistral',
    caseSensitive: false,
  ),
};

/// Return the vendor slug for a normalized model ID, or `null` if no pattern
/// matches. Patterns don't overlap, so iteration order is not significant.
String? matchVendor(String normalizedId) {
  for (final entry in vendorPatterns.entries) {
    if (entry.value.hasMatch(normalizedId)) return entry.key;
  }
  return null;
}

/// Whether the raw [modelId] belongs to [vendor]. Applies [lowerBaseModelName]
/// before matching (delimiter `/`), matching the web vendor checks.
bool isVendorModel(String vendor, String modelId) {
  final pattern = vendorPatterns[vendor];
  if (pattern == null) return false;
  return pattern.hasMatch(lowerBaseModelName(modelId, '/'));
}
