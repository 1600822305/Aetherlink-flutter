/// Model ID normalization utilities.
///
/// Faithful Dart port of cherry-studio's
/// `packages/provider-registry/src/utils/normalize.ts` plus the
/// `getLowerBaseModelName` helper from `@shared/utils/model`.
///
/// Two levels of canonicalization:
///  - [lowerBaseModelName]: strip the provider/namespace prefix, lowercase,
///    drop a few free/cloud variant suffixes. Used by the regex inference
///    helpers (matches the web `getLowerBaseModelName`).
///  - [normalizeModelId]: the heavier canonical form (strip aggregator
///    prefixes, expand abbreviations, strip variant suffixes + parameter
///    size, normalize version separators). Used to index/look up the bundled
///    `models.json` registry so e.g. `siliconflow-deepseek-v3:free` and
///    `deepseek/DeepSeek-V3` resolve to the same preset entry.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Constants (ported 1:1 from normalize.ts)
// ─────────────────────────────────────────────────────────────────────────────

const List<String> commonAggregatorPrefixes = [
  // AIHubMix routing prefixes
  'aihubmix-',
  'aihub-',
  'ahm-',
  // Cloud provider routing
  'alicloud-',
  'azure-',
  'baidu-',
  'cbs-',
  'cc-',
  'sf-',
  's-',
  'bai-',
  'mm-',
  'web-',
  // Platform aggregators
  'deepinfra-',
  'groq-',
  'nvidia-',
  'sophnet-',
  // Legacy prefixes
  'zai-org-', // Must be before zai-
  'zai-',
  'lucidquery-',
  'lucidnova-',
  'lucid-',
  'siliconflow-',
  'chutes-',
  'huoshan-',
  'meta-',
  'cohere-',
  'coding-',
  'dmxapi-',
  'perplexity-',
  'ai21-',
  'openai-',
  // Underscore-based prefixes
  'dmxapi_',
  'aistudio_',
];

/// Abbreviation → canonical prefix expansions.
const List<(String, String)> prefixExpansions = [
  ('mm-', 'minimax-'), // MiniMax shorthand: mm-m2-1 → minimax-m2-1
];

const List<String> colonVariantSuffixes = [
  ':free',
  ':nitro',
  ':extended',
  ':beta',
  ':preview',
  ':thinking',
  ':exacto',
  ':latest',
  ':cloud',
];

const List<String> hyphenVariantSuffixes = [
  '-free',
  '-search',
  '-online',
  '-think',
  '-reasoning',
  '-classic',
  '-low',
  '-high',
  '-minimal',
  '-medium',
  '-nothink',
  '-no-think',
  '-ssvip',
  '-thinking',
  '-nothinking',
  '-aliyun',
  '-huoshan',
  '-tee',
  '-cc',
  '-fw',
  '-di',
  '-t',
  '-reverse',
];

const List<String> parenVariantSuffixes = [
  '(free)',
  '(beta)',
  '(preview)',
  '(thinking)',
];

const List<String> _protectedCompoundPrefixes = ['non', 'no', 'pre', 'anti', 'post'];

final RegExp _parameterSizePattern = RegExp(r'-(\d+(?:\.\d+)?b)(?=-|$)', caseSensitive: false);

// ─────────────────────────────────────────────────────────────────────────────
// lowerBaseModelName (port of getLowerBaseModelName)
// ─────────────────────────────────────────────────────────────────────────────

/// Last segment after [delimiter] (the provider/namespace prefix stripped).
String getBaseModelName(String id, [String delimiter = '/']) {
  final idx = id.lastIndexOf(delimiter);
  return idx < 0 ? id : id.substring(idx + delimiter.length);
}

/// Lowercased base model name with a few free/cloud variant suffixes removed.
/// Mirrors web `getLowerBaseModelName(id, delimiter)`.
String lowerBaseModelName(String id, [String delimiter = '/']) {
  // Fireworks ids use `p` as a decimal separator: 3p1 → 3.1
  final normalizedId = id.toLowerCase().startsWith('accounts/fireworks/models/')
      ? id.replaceAllMapped(RegExp(r'(\d)p(?=\d)'), (m) => '${m[1]}.')
      : id;

  var base = getBaseModelName(normalizedId, delimiter).toLowerCase();
  if (base.endsWith(':free')) base = base.replaceAll(':free', '');
  if (base.endsWith('(free)')) base = base.replaceAll('(free)', '');
  if (base.endsWith(':cloud')) base = base.replaceAll(':cloud', '');
  return base;
}

// ─────────────────────────────────────────────────────────────────────────────
// normalizeModelId (registry lookup canonical form)
// ─────────────────────────────────────────────────────────────────────────────

String stripAggregatorPrefixes(String modelId, [List<String> additionalPrefixes = const []]) {
  final allPrefixes = [...additionalPrefixes, ...commonAggregatorPrefixes];
  for (final prefix in allPrefixes) {
    if (modelId.startsWith(prefix)) {
      return modelId.substring(prefix.length);
    }
  }
  return modelId;
}

String expandKnownPrefixes(String modelId) {
  for (final (abbrev, canonical) in prefixExpansions) {
    if (modelId.startsWith(abbrev)) {
      return canonical + modelId.substring(abbrev.length);
    }
  }
  return modelId;
}

String stripVariantSuffixes(String modelId) {
  final colonIdx = modelId.lastIndexOf(':');
  if (colonIdx > 0) {
    final suffix = modelId.substring(colonIdx);
    if (colonVariantSuffixes.contains(suffix)) {
      return modelId.substring(0, colonIdx);
    }
  }

  for (final suffix in hyphenVariantSuffixes) {
    if (modelId.endsWith(suffix)) {
      final remaining = modelId.substring(0, modelId.length - suffix.length);
      if (_protectedCompoundPrefixes.any(remaining.endsWith)) continue;
      return remaining;
    }
  }

  for (final suffix in parenVariantSuffixes) {
    if (modelId.endsWith(suffix)) {
      var result = modelId.substring(0, modelId.length - suffix.length);
      if (result.endsWith(' ')) result = result.substring(0, result.length - 1);
      return result;
    }
  }

  return modelId;
}

String stripParameterSize(String modelId) => modelId.replaceAll(_parameterSizePattern, '');

String normalizeVersionSeparators(String modelId) =>
    modelId.replaceAllMapped(RegExp(r'(\d)[,.p](?=\d)'), (m) => '${m[1]}-');

/// Normalize a model ID to its canonical form. Single source of truth for
/// registry indexing/lookup.
String normalizeModelId(String modelId) {
  final parts = modelId.split('/');
  var baseName = parts.last.toLowerCase();
  baseName = stripAggregatorPrefixes(baseName);
  baseName = expandKnownPrefixes(baseName);
  baseName = stripVariantSuffixes(baseName);
  baseName = stripParameterSize(baseName);
  baseName = normalizeVersionSeparators(baseName);
  return baseName;
}
