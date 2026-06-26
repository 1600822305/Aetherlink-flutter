import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';

/// The built-in MCP server catalog, ported verbatim from the web
/// `src/shared/config/builtinMCPServers.ts` (`BUILTIN_MCP_SERVERS`). Adding a
/// new built-in tool is a matter of adding an entry here. The templates default
/// to `isActive: false`; [McpServers.addBuiltin] flips that on when a user adds
/// one (mirroring `MCPService.addBuiltinServer`).
const List<McpServer> kBuiltinMcpServers = [
  McpServer(
    id: 'builtin-time',
    name: '@aether/time',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description: '获取当前时间和日期，支持多种格式（本地化、ISO 8601、时间戳）和时区设置',
    provider: 'AetherAI',
    tags: ['时间', '日期', '工具'],
  ),
  McpServer(
    id: 'builtin-fetch',
    name: '@aether/fetch',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description: '获取网页内容并转为 Markdown（遵循 MCP 官方 Fetch Server 规范）。支持分块读取大页面、自定义请求头',
    provider: 'AetherAI',
    tags: ['网页', '抓取', 'HTTP', 'Markdown', '工具'],
  ),
  McpServer(
    id: 'builtin-calculator',
    name: '@aether/calculator',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description: '高级计算器，支持基本运算、科学计算、进制转换、单位转换和统计计算',
    provider: 'AetherAI',
    tags: ['计算', '数学', '转换', '统计', '工具'],
  ),
  McpServer(
    id: 'builtin-calendar',
    name: '@aether/calendar',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description: '日历管理工具，支持创建、查询、修改和删除日历事件，查看日历列表',
    provider: 'AetherAI',
    tags: ['日历', '事件', '提醒', '时间管理', '工具'],
  ),
  McpServer(
    id: 'builtin-alarm',
    name: '@aether/alarm',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description: '闹钟和提醒工具，支持设置单次或重复闹钟，管理所有提醒',
    provider: 'AetherAI',
    tags: ['闹钟', '提醒', '通知', '时间管理', '工具'],
  ),
  McpServer(
    id: 'builtin-metaso-search',
    name: '@aether/metaso-search',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description: '秘塔AI官方API，提供网页搜索、内容阅读器和AI智能对话。支持5种知识范围、3种模型、引用来源和关键要点提取',
    provider: 'AetherAI',
    tags: ['搜索', 'AI', '对话', '阅读器', '工具'],
    env: {'METASO_API_KEY': ''},
  ),
  McpServer(
    id: 'builtin-file-editor',
    name: '@aether/file-editor',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description: 'AI 文件浏览工具，支持列出工作区、浏览目录、读取文件、查看文件信息与搜索（当前为只读；写入/编辑能力将在后续版本开放）。',
    provider: 'AetherAI',
    tags: ['文件', '编辑', 'AI', '工作区', '笔记', '工具'],
  ),
  McpServer(
    id: 'builtin-dex-editor',
    name: '@aether/dex-editor',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description:
        'DEX 文件编辑工具，让 AI 可以浏览、搜索、查看和修改 APK 中的 Smali 代码。支持列出类、获取方法、搜索代码、编辑保存和签名。',
    provider: 'AetherAI',
    tags: ['DEX', 'Smali', 'APK', '逆向', '编辑', 'Android', '工具'],
  ),
  McpServer(
    id: 'builtin-grok-search',
    name: '@aether/grok-search',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description:
        'xAI Grok 实时搜索工具。使用 Grok API 原生 search_parameters 在 Web 和 X (Twitter) '
        '上搜索最新信息，返回带引用的回答。支持搜索模式、日期范围、数据源筛选',
    provider: 'AetherAI',
    tags: ['搜索', 'AI', '联网', 'Grok', 'xAI', '工具'],
    env: {
      'XAI_API_KEY': '',
      'XAI_MODEL_ID': 'grok-3',
      'XAI_API_URL': 'https://api.x.ai',
      'XAI_TIMEOUT': '60',
    },
  ),
  McpServer(
    id: 'builtin-searxng',
    name: '@aether/searxng',
    type: McpServerType.inMemory,
    category: McpServerCategory.builtin,
    description:
        '基于自部署 SearXNG 的元搜索引擎，聚合 Google、Bing、DuckDuckGo 等 70+ 搜索引擎。支持互联网搜索和网页内容抓取',
    provider: 'AetherAI',
    tags: ['搜索', '网页', '抓取', '工具'],
    env: {'SEARXNG_BASE_URL': 'http://154.37.208.52:39281'},
  ),
  McpServer(
    id: 'builtin-settings',
    name: '@aether/settings',
    type: McpServerType.inMemory,
    category: McpServerCategory.assistant,
    description: '智能设置助手，让 AI 管理知识库（创建、编辑、删除、搜索）和应用设置。支持自然语言操作，危险操作需用户确认。',
    provider: 'AetherAI',
    tags: ['设置', '知识库', '管理', 'AI', '工具'],
  ),
];

/// Whether [name] matches a built-in server (mirrors the web `isBuiltinServer`).
/// Used to split the 外部服务器 tab from the built-in/assistant catalogs.
bool isBuiltinMcpServerName(String name) =>
    kBuiltinMcpServers.any((server) => server.name == name);
