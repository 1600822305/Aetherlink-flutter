/// Detects whether a model natively supports built-in web search (Gemini
/// grounding, OpenAI `/responses` web_search, Claude web_search tool),
/// ported from Kelivo's `BuiltInToolsHelper`.
///
/// When a model has native search the chat controller can skip injecting
/// `builtin_web_search` and instead pass provider-specific tool configs
/// directly in the request body so the vendor performs the search.
library;

/// Whether the [providerType]+[modelId] combination supports built-in
/// (vendor-native) web search.
bool supportsBuiltInSearch({
  required String? providerType,
  required String? modelId,
  String? baseUrl,
  bool useResponsesAPI = false,
}) {
  if (providerType == null || modelId == null || modelId.trim().isEmpty) {
    return false;
  }
  final m = modelId.trim().toLowerCase();
  switch (providerType) {
    case 'gemini':
    case 'google':
      // All Gemini models support grounding via google_search_retrieval.
      return true;

    case 'anthropic':
      return _isClaudeSearchSupported(m);

    case 'openai':
    case 'openai-aisdk':
      if (_isGrokModel(m)) return true;
      if (useResponsesAPI && _isOpenAIResponsesSearchSupported(m)) return true;
      if (_isDashScopeHost(baseUrl)) {
        return useResponsesAPI
            ? _isDashScopeResponsesSearchSupported(m)
            : _isDashScopeChatSearchSupported(m);
      }
      return false;

    case 'grok':
      return true;

    case 'dashscope':
      return useResponsesAPI
          ? _isDashScopeResponsesSearchSupported(m)
          : _isDashScopeChatSearchSupported(m);

    case 'deepseek':
      // DeepSeek models via Claude-compatible API support search.
      return true;

    default:
      return false;
  }
}

/// The provider-specific tool type string to use in the request body when
/// native search is enabled. Returns `null` if native search is not supported.
String? nativeSearchToolType({
  required String? providerType,
  required String? modelId,
  bool useResponsesAPI = false,
}) {
  if (!supportsBuiltInSearch(
    providerType: providerType,
    modelId: modelId,
    useResponsesAPI: useResponsesAPI,
  )) {
    return null;
  }
  switch (providerType) {
    case 'gemini':
    case 'google':
      return 'google_search_retrieval';
    case 'anthropic':
      return _isClaudeDynamicSearchSupported(modelId) 
          ? 'web_search_20260209'
          : 'web_search_20250305';
    case 'openai':
    case 'openai-aisdk':
    case 'grok':
      return 'web_search';
    case 'dashscope':
      return 'web_search';
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Claude
// ---------------------------------------------------------------------------

bool _isClaudeSearchSupported(String m) {
  if (m.contains('mythos')) return true;
  const supported = <String>{
    'claude-fable-5',
    'claude-opus-4-8',
    'claude-opus-4-7',
    'claude-opus-4-6',
    'claude-sonnet-4-5-20250929',
    'claude-sonnet-4-20250514',
    'claude-3-7-sonnet-20250219',
    'claude-haiku-4-5-20251001',
    'claude-3-5-haiku-latest',
    'claude-sonnet-4-6',
    'claude-opus-4-1-20250805',
    'claude-opus-4-20250514',
  };
  return supported.contains(m);
}

bool _isClaudeDynamicSearchSupported(String? modelId) {
  final m = (modelId ?? '').trim().toLowerCase();
  return m.contains('mythos') ||
      m == 'claude-fable-5' ||
      m == 'claude-opus-4-8' ||
      m == 'claude-opus-4-7' ||
      m == 'claude-opus-4-6' ||
      m == 'claude-sonnet-4-6';
}

// ---------------------------------------------------------------------------
// OpenAI Responses API
// ---------------------------------------------------------------------------

bool _isOpenAIResponsesSearchSupported(String m) {
  return m.startsWith('gpt-4o') ||
      m.startsWith('gpt-4.1') ||
      m.startsWith('o4-mini') ||
      m == 'o3' ||
      m.startsWith('o3-') ||
      m.startsWith('gpt-5');
}

bool _isGrokModel(String m) => m.contains('grok');

// ---------------------------------------------------------------------------
// DashScope (阿里云百炼)
// ---------------------------------------------------------------------------

bool _isDashScopeHost(String? baseUrl) {
  if (baseUrl == null) return false;
  final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
  return host == 'dashscope.aliyuncs.com';
}

bool _matchesExactOrSnapshot(
  String m, {
  required String alias,
  String? minSnapshot,
  List<String> extraExact = const <String>[],
}) {
  if (m == alias) return true;
  if (extraExact.contains(m)) return true;
  if (minSnapshot == null || !m.startsWith('$alias-')) return false;
  final match = RegExp(r'-(\d{4}-\d{2}-\d{2})$').firstMatch(m);
  if (match == null) return false;
  try {
    final date = DateTime.parse(match.group(1)!);
    return !date.isBefore(DateTime.parse(minSnapshot));
  } catch (_) {
    return false;
  }
}

bool _isDashScopeChatSearchSupported(String m) {
  return _matchesExactOrSnapshot(
        m,
        alias: 'qwen-max',
        minSnapshot: '2024-09-19',
        extraExact: const ['qwen-max-latest'],
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen3-max',
        minSnapshot: '2025-09-23',
        extraExact: const ['qwen3-max-preview'],
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen-plus',
        minSnapshot: '2025-07-14',
        extraExact: const ['qwen-plus-latest'],
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen3.5-plus',
        minSnapshot: '2026-02-15',
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen-flash',
        minSnapshot: '2025-07-28',
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen3.5-flash',
        minSnapshot: '2026-02-23',
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen-turbo',
        minSnapshot: '2025-07-15',
        extraExact: const ['qwen-turbo-latest'],
      ) ||
      m == 'qwq-plus';
}

bool _isDashScopeResponsesSearchSupported(String m) {
  return _matchesExactOrSnapshot(
        m,
        alias: 'qwen3.6-plus',
        minSnapshot: '2026-04-02',
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen3.6-flash',
        minSnapshot: '2026-04-16',
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen3.5-plus',
        minSnapshot: '2026-02-15',
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen3.5-flash',
        minSnapshot: '2026-02-23',
      ) ||
      _matchesExactOrSnapshot(
        m,
        alias: 'qwen3-max',
        minSnapshot: '2026-01-23',
      );
}
