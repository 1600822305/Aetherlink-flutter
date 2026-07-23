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
  // NOTE: `mm-` is intentionally NOT here — it's MiniMax shorthand handled by
  // [prefixExpansions] (`mm-m2-1` → `minimax-m2-1`). Stripping it as an
  // aggregator prefix would run BEFORE the expansion and orphan the id
  // (`m2-1`), so MiniMax could never claim it.
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
  // NOTE: `-medium` is intentionally NOT here — it's a real model-tier name
  // (`mistral-medium`, `devstral-medium`), so stripping it as a
  // reasoning-effort variant eats the tier and produces bogus stems.
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

/// Matches a registry-tag (OCI/Docker-style) COLON size/quant tag payload —
/// `<size>[-<variant>][-<quant>]` (`20b`, `8x7b`, `30b-a3b-q4_K_M`) or a bare
/// quant (`q4_K_M`, `fp16`). Local runners such as Ollama spell a variant this
/// way (`gpt-oss:20b`, `qwen2.5:7b`). Used to REALIGN the tag to the catalog's
/// hyphen spelling (see [colonVariantTagToHyphen]) so the size stays part of
/// the id; a size-agnostic word tag (`:free`) or a Bedrock revision (`:0`) is
/// intentionally excluded. Tested against the suffix WITHOUT its leading colon.
final RegExp _colonVariantTagPattern =
    RegExp(r'^(?:\d+(?:[.x]\d+)*b(?:$|[-.])|q\d|iq\d|fp16|bf16|f16)', caseSensitive: false);

/// Quantization markers denote the same logical model at a different precision
/// (e.g. `glm-4-5-fp8` is `glm-4-5`).
const List<String> quantizationSuffixes = [
  '-fp8',
  '-fp16',
  '-bf16',
  '-awq',
  '-int4',
  '-int8',
  '-gguf',
  '-gptq',
];

/// Trailing release-date stamps (`claude-sonnet-4-5-20250929`,
/// `gpt-4o-2024-08-06`, `kimi-k2-250905`) denote the same model line. A
/// trailing date may be a full YYYY[-]MM[-]DD, a YYMMDD, a YYMM, or an MMDD —
/// all requiring a valid month (01-12) and day (01-31), so sizes/versions
/// (`glm-4-9b`, `qwen3-235b`) are never touched.
final RegExp _dateSnapshotPattern = RegExp(
    r'-20\d{2}-(?:0[1-9]|1[0-2])-(?:[0-2]\d|3[01])$|-20\d{2}(?:0[1-9]|1[0-2])(?:[0-2]\d|3[01])$|-2\d(?:0[1-9]|1[0-2])(?:[0-2]\d|3[01])$|-(?:0[1-9]|1[0-2])(?:[0-2]\d|3[01])$|-2\d(?:0[1-9]|1[0-2])$');

/// Bedrock re-lists other creators' models as cross-vendor ARNs: a leading
/// region(s)+vendor DOTTED prefix (`us.anthropic.`), a vendor DASH prefix
/// (`meta-llama`), plus a trailing model revision (`…-v1:0`, `…:0`). Both are
/// stripped so `us.anthropic.claude-sonnet-4-5-v1:0` folds to the same
/// canonical id as `claude-sonnet-4-5`.
const String _bedrockVendor = 'anthropic|amazon|meta|google|mistralai|cohere|openai|ai21|microsoft|nvidia';
const String _bedrockDottedVendor =
    '$_bedrockVendor|deepseek|minimax|mistral|moonshot|moonshotai|qwen|writer|xai|zai';
final RegExp _bedrockVendorDotted = RegExp('^(?:[a-z]+\\.)*(?:$_bedrockDottedVendor)\\.');
final RegExp _bedrockVendorDash = RegExp('^(?:$_bedrockVendor)-{1,2}');
final RegExp _bedrockRevisionPattern = RegExp(r'(?:[-_]v?\d+)?:\d+$', caseSensitive: false);

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

/// Strip a Bedrock cross-vendor ARN's leading vendor prefix: region(s)+vendor
/// dotted segments (`us.anthropic.claude-…` → `claude-…`) then a vendor dash
/// prefix (`meta-llama-…` → `llama-…`). The final dotted segment must be a
/// known Bedrock vendor, so native dotted model ids such as `flux.2-pro` and
/// versions such as `qwen3.7` are never touched.
String stripBedrockVendorPrefix(String modelId) =>
    modelId.replaceFirst(_bedrockVendorDotted, '').replaceFirst(_bedrockVendorDash, '');

/// Strip a Bedrock ARN model revision: `claude-…-v1:0` / `…:0` → bare id
/// (keeps `whisper-v3`, no colon).
String stripBedrockRevision(String modelId) => modelId.replaceFirst(_bedrockRevisionPattern, '');

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
      // Only protect when the prefix is its OWN token (`...-no-think` → keep),
      // not a substring of the last word (`volcano-free`, `pino-search` must
      // still strip).
      if (_protectedCompoundPrefixes.any((p) => remaining == p || remaining.endsWith('-$p'))) {
        continue;
      }
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

/// `,` `.` `p` `_` between digits are all version separators:
/// 3.5 / 3,5 / 3p5 / 3_5 → 3-5.
String normalizeVersionSeparators(String modelId) =>
    modelId.replaceAllMapped(RegExp(r'(\d)[,._p](?=\d)'), (m) => '${m[1]}-');

String stripQuantization(String modelId) {
  for (final suffix in quantizationSuffixes) {
    if (modelId.endsWith(suffix)) {
      return modelId.substring(0, modelId.length - suffix.length);
    }
  }
  return modelId;
}

String stripDateSnapshot(String modelId) =>
    modelId.replaceFirst(RegExp(r'@.*$'), '').replaceFirst(_dateSnapshotPattern, '');

/// Iterate variant → quantization → date stripping to a fixpoint. A single
/// pass is order-dependent — a trailing date shields an inner variant from the
/// `endsWith` check (`…-thinking-2507` only exposes `-thinking` after the date
/// is gone) — so without the loop canonicalization is not idempotent.
String stripVariantQuantDateSuffixes(String modelId) {
  var result = modelId;
  for (;;) {
    final next = stripDateSnapshot(stripQuantization(stripVariantSuffixes(result)));
    if (next == result) return result;
    result = next;
  }
}

/// Realign a registry-tag colon size/quant tag to the catalog's hyphen
/// spelling: `gpt-oss:20b` → `gpt-oss-20b`, `qwen2.5:7b` → `qwen2.5-7b`. Only
/// a size/quant LEADER is realigned (see [_colonVariantTagPattern]), so a word
/// tag (`:free`) or a Bedrock revision (`:0`) is returned unchanged. This
/// keeps the SIZE inside the id so a size-preserving match can tell a `:20b`
/// pull apart from its `120b` sibling.
String colonVariantTagToHyphen(String modelId) {
  final colonIdx = modelId.lastIndexOf(':');
  if (colonIdx > 0 && _colonVariantTagPattern.hasMatch(modelId.substring(colonIdx + 1))) {
    return '${modelId.substring(0, colonIdx)}-${modelId.substring(colonIdx + 1)}';
  }
  return modelId;
}

/// Normalize a model ID to its canonical form. Single source of truth for
/// registry indexing/lookup.
///
/// [keepParameterSize] produces the SIZE-PRESERVING key: the parameter size is
/// realigned from any colon tag and kept (not stripped), so `qwen2.5:7b` →
/// `qwen2-5-7b` and `gpt-oss-20b`/`gpt-oss-120b` stay distinct. The registry
/// indexes on this to resolve a registry-tagged id to its exact-size row
/// before the default (size-agnostic) key would collapse it onto a
/// same-family sibling.
String normalizeModelId(String modelId, {bool keepParameterSize = false}) {
  final parts = modelId.split('/');
  var baseName = parts.last.toLowerCase();
  baseName = stripAggregatorPrefixes(baseName);
  // Bedrock cross-vendor ARNs: drop the `[region.]vendor.` / `vendor-` prefix
  // and the `…-v1:0` revision so `us.anthropic.claude-…-v1:0` resolves to the
  // catalog row.
  baseName = stripBedrockVendorPrefix(baseName);
  baseName = stripBedrockRevision(baseName);
  baseName = expandKnownPrefixes(baseName);
  if (keepParameterSize) {
    // Realign `:20b` → `-20b` so the size is a normal hyphen token the loop
    // below leaves intact (stripParameterSize is skipped in this mode).
    baseName = colonVariantTagToHyphen(baseName);
  }
  // Parameter size joins the fixpoint loop too: stripping `-30b` can expose a
  // variant suffix and vice versa, so iterate the whole strip stage until
  // stable.
  for (;;) {
    final stripped = stripVariantQuantDateSuffixes(baseName);
    final next = keepParameterSize ? stripped : stripParameterSize(stripped);
    if (next == baseName) break;
    baseName = next;
  }
  baseName = normalizeVersionSeparators(baseName);
  // Underscores are an interchangeable separator (HF-style
  // `bce-embedding-base_v1`). The catalog folds them to `-` (every base id is
  // dash-only), so fold here too or such ids would never resolve.
  baseName = baseName.replaceAll('_', '-');
  return baseName;
}
