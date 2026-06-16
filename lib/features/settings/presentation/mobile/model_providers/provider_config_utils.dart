/// Pure helpers shared by the provider-detail page and its sub-pages, ported
/// 1:1 from the original `src/pages/Settings/ModelProviders/components/
/// constants.ts` and `src/shared/utils/modelUtils.ts`. Kept Flutter-free so the
/// URL-preview / grouping behaviour matches the web app exactly.
library;

/// The original `providerTypeOptions` (value, label), verbatim and in order.
/// Used by the 编辑供应商 dialog's type dropdown.
const List<(String, String)> providerTypeOptions = [
  ('openai', 'OpenAI'),
  ('openai-aisdk', 'OpenAI (AI SDK) - 流式优化'),
  ('azure-openai', 'Azure OpenAI'),
  ('gemini', 'Gemini'),
  ('anthropic', 'Anthropic'),
  ('grok', 'xAI (Grok)'),
  ('deepseek', 'DeepSeek'),
  ('zhipu', '智谱AI'),
  ('siliconflow', '硅基流动 (SiliconFlow)'),
  ('volcengine', '火山引擎'),
  ('minimax', 'MiniMax'),
  ('dashscope', '阿里云百炼 (DashScope)'),
  ('google', 'Google (通用)'),
  ('custom', '自定义'),
];

const String _volcesEndpoint = 'volces.com/api/v3';
const String _openaiResponseType = 'openai-response';

/// Whether [providerType] is treated as an OpenAI-compatible provider for the
/// URL preview (everything except `anthropic` / `gemini`). Mirrors
/// `isOpenAIProvider`.
bool isOpenAIProvider(String? providerType) =>
    !['anthropic', 'gemini'].contains(providerType ?? '');

/// Normalizes a base URL host the way `formatApiHost` does: trims a trailing
/// `/`, keeps VolcEngine / `openai-response` hosts as-is, otherwise appends
/// `/v1`.
String _formatApiHost(String host, String? providerType) {
  final trimmed = host.trim();
  if (trimmed.isEmpty) return '';
  final normalized = trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  if (normalized.endsWith(_volcesEndpoint)) return normalized;
  if (providerType == _openaiResponseType) return normalized;
  return '$normalized/v1';
}

/// The full endpoint preview shown under the base-URL field — `getCompleteApiUrl`
/// / `getPreviewUrl`. Appends `/responses` when [useResponsesAPI] is on (or the
/// type is `openai-response`), else `/chat/completions`.
String getCompleteApiUrl(
  String baseUrl,
  String? providerType, {
  bool useResponsesAPI = false,
}) {
  if (baseUrl.trim().isEmpty) return '';
  final host = _formatApiHost(baseUrl, providerType);
  if (useResponsesAPI || providerType == _openaiResponseType) {
    return '$host/responses';
  }
  return '$host/chat/completions';
}

/// Auto-derives a model's group name from its id, ported from
/// `getDefaultGroupName`. First-class delimiters split off the leading segment;
/// failing that, `-`/`_` join the first two segments unless the second is
/// purely numeric.
String getDefaultGroupName(String id, [String? provider]) {
  final str = id.toLowerCase();

  var firstDelimiters = ['/', ' ', ':'];
  var secondDelimiters = ['-', '_'];

  if (provider != null &&
      [
        'aihubmix',
        'silicon',
        'ocoolai',
        'o3',
        'dmxapi',
      ].contains(provider.toLowerCase())) {
    firstDelimiters = ['/', ' ', '-', '_', ':'];
    secondDelimiters = [];
  }

  for (final delimiter in firstDelimiters) {
    if (str.contains(delimiter)) {
      return str.split(delimiter).first;
    }
  }

  for (final delimiter in secondDelimiters) {
    if (str.contains(delimiter)) {
      final parts = str.split(delimiter);
      if (parts.length > 1) {
        if (RegExp(r'^\d+$').hasMatch(parts[1])) {
          return parts[0];
        }
        return '${parts[0]}-${parts[1]}';
      }
      return parts[0];
    }
  }

  return str;
}

/// Groups [models] by [getDefaultGroupName] (or the model's explicit group) and
/// returns the groups sorted alphabetically, matching the page's `groupedModels`
/// memo. [T] is kept generic so the page can pass its `Model` without this file
/// importing the domain layer.
List<(String, List<T>)> groupModels<T>(
  Iterable<T> models, {
  required String Function(T) idOf,
  required String? Function(T) groupOf,
  required String providerId,
}) {
  final groups = <String, List<T>>{};
  for (final model in models) {
    final explicit = groupOf(model);
    final name = (explicit != null && explicit.isNotEmpty)
        ? explicit
        : getDefaultGroupName(idOf(model), providerId);
    groups.putIfAbsent(name, () => <T>[]).add(model);
  }
  final names = groups.keys.toList()..sort((a, b) => a.compareTo(b));
  return [for (final name in names) (name, groups[name]!)];
}
