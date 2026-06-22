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

/// All available search provider presets, matching the web version's
/// `getDefaultProviders()` list. The user picks from these when adding a
/// provider; only the ones they add show up on the second-level page.
const List<SearchProviderPreset> kSearchProviderPresets = [
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
    name: 'Bing 免费搜索',
    description: '免费 Bing 网页抓取，无需 API 密钥',
    icon: LucideIcons.globe,
    accent: Color(0xFF0078D4),
    apiHost: 'https://www.bing.com',
  ),
  SearchProviderPreset(
    id: 'tavily',
    name: 'Tavily',
    description: 'AI 优化的搜索 API，高质量结果',
    icon: LucideIcons.sparkles,
    accent: Color(0xFF8B5CF6),
    apiHost: 'https://api.tavily.com',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'exa',
    name: 'Exa',
    description: '神经搜索引擎，语义理解能力强',
    icon: LucideIcons.brain,
    accent: Color(0xFFEC4899),
    apiHost: 'https://api.exa.ai',
    needsApiKey: true,
  ),
  SearchProviderPreset(
    id: 'bocha',
    name: 'Bocha',
    description: 'AI 搜索引擎',
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
];

/// Looks up a preset by its id. Returns `null` if not found (custom provider).
SearchProviderPreset? presetForId(String id) {
  for (final p in kSearchProviderPresets) {
    if (p.id == id) return p;
  }
  return null;
}
