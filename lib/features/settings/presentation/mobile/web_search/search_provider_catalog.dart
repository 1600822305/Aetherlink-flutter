import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Static metadata for every preset search provider — visual properties that
/// drive the UI (icon, color, descriptions) but are never persisted. The
/// persisted part is [SearchProviderConfig] in `web_search_settings.dart`.
@immutable
class SearchProviderPreset {
  const SearchProviderPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accent,
    this.apiHost = '',
    this.needsApiKey = false,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color accent;
  final String apiHost;
  final bool needsApiKey;
}

/// All available search provider presets — aligned with the Kelivo project's
/// provider catalog (16 providers). The user picks from these when adding a
/// provider; only the ones they add show up on the second-level page.
const List<SearchProviderPreset> kSearchProviderPresets = [
  // ── 免费 / 无需 API Key ──────────────────────────────────────────────────
  SearchProviderPreset(
    id: 'searxng',
    name: 'SearXNG',
    description: '聚合 Google、Bing、DuckDuckGo 等 70+ 搜索引擎',
    icon: LucideIcons.search,
    accent: Color(0xFF3B82F6),
    apiHost: 'http://154.37.208.52:39281',
  ),
  SearchProviderPreset(
    id: 'bing-free',
    name: 'Bing (Local)',
    description: '免费 Bing 网页抓取，无需 API 密钥',
    icon: LucideIcons.globe,
    accent: Color(0xFF0078D4),
    apiHost: 'https://www.bing.com',
  ),
  SearchProviderPreset(
    id: 'duckduckgo',
    name: 'DuckDuckGo',
    description: '注重隐私的免费搜索，无需 API 密钥',
    icon: LucideIcons.shield,
    accent: Color(0xFFDE5833),
  ),

  // ── 需要 API Key ─────────────────────────────────────────────────────────
  SearchProviderPreset(
    id: 'tavily',
    name: 'Tavily',
    description: 'AI 优化的搜索 API，高质量结果',
    icon: LucideIcons.sparkles,
    accent: Color(0xFF8B5CF6),
    apiHost: 'https://api.tavily.com/search',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'exa',
    name: 'Exa',
    description: '神经搜索引擎，语义理解能力强',
    icon: LucideIcons.brain,
    accent: Color(0xFFEC4899),
    apiHost: 'https://api.exa.ai/search',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'bocha',
    name: '博查 (Bocha)',
    description: 'AI 搜索引擎，支持时效过滤和摘要',
    icon: LucideIcons.bot,
    accent: Color(0xFF06B6D4),
    apiHost: 'https://api.bochaai.com',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'firecrawl',
    name: 'Firecrawl',
    description: '网页抓取和结构化提取',
    icon: LucideIcons.flame,
    accent: Color(0xFFEF4444),
    apiHost: 'https://api.firecrawl.dev',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'zhipu',
    name: '智谱搜索',
    description: '智谱 AI 网络搜索服务',
    icon: LucideIcons.zap,
    accent: Color(0xFF10B981),
    apiHost: 'https://open.bigmodel.cn/api/paas/v4/web_search',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'jina',
    name: 'Jina',
    description: '搜索 + 网页阅读，支持内容提取',
    icon: LucideIcons.fileSearch,
    accent: Color(0xFFF59E0B),
    apiHost: 'https://s.jina.ai',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'brave',
    name: 'Brave Search',
    description: '独立搜索引擎，注重隐私的 API',
    icon: LucideIcons.compass,
    accent: Color(0xFFFF5500),
    apiHost: 'https://api.search.brave.com/res/v1/web/search',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'serper',
    name: 'Serper',
    description: 'Google 搜索结果 API，速度快',
    icon: LucideIcons.radar,
    accent: Color(0xFF4285F4),
    apiHost: 'https://google.serper.dev/search',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'perplexity',
    name: 'Perplexity',
    description: 'AI 搜索引擎，自动综合多源信息',
    icon: LucideIcons.sparkle,
    accent: Color(0xFF20B2AA),
    apiHost: 'https://api.perplexity.ai/chat/completions',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'metaso',
    name: '秘塔 (Metaso)',
    description: '中文 AI 搜索引擎',
    icon: LucideIcons.languages,
    accent: Color(0xFF6366F1),
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'linkup',
    name: 'LinkUp',
    description: '链接聚合搜索服务',
    icon: LucideIcons.link,
    accent: Color(0xFF0EA5E9),
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'querit',
    name: 'Querit',
    description: '搜索聚合，支持站点和时间过滤',
    icon: LucideIcons.filter,
    accent: Color(0xFF84CC16),
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'grok',
    name: 'Grok',
    description: 'xAI 搜索，基于 Grok 模型实时联网',
    icon: LucideIcons.cpu,
    accent: Color(0xFF000000),
    apiHost: 'https://api.x.ai/v1/responses',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'ollama',
    name: 'Ollama',
    description: '本地模型搜索服务',
    icon: LucideIcons.server,
    accent: Color(0xFF737373),
    needsApiKey: true,
  ),
];

/// Looks up a preset by its id. Returns `null` if not found (custom provider).
SearchProviderPreset? presetForId(String id) {
  for (final p in kSearchProviderPresets) {
    if (p.id == id) return p;
  }
  return null;
}
