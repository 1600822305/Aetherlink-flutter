import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

/// A single searchable settings entry.
@immutable
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    this.group = '',
    this.keywords = const <String>[],
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
  final String group;

  /// Extra keywords that the user might type but aren't in the title/description.
  final List<String> keywords;

  /// Whether [query] (lowercased) matches this entry.
  bool matches(String query) {
    if (title.toLowerCase().contains(query)) return true;
    if (description.toLowerCase().contains(query)) return true;
    if (group.toLowerCase().contains(query)) return true;
    for (final kw in keywords) {
      if (kw.toLowerCase().contains(query)) return true;
    }
    return false;
  }
}

/// The flat search index covering all navigable settings entries.
/// Each entry has a direct route so the search result can navigate there.
const List<SettingsSearchEntry> kSettingsSearchIndex = <SettingsSearchEntry>[
  // ── 基本设置 ──
  SettingsSearchEntry(
    icon: LucideIcons.palette,
    title: '外观',
    description: '主题、字体大小和语言设置',
    route: AppRouter.appearancePath,
    group: '基本设置',
    keywords: [
      'theme',
      '主题',
      '字体',
      '语言',
      '深色',
      '浅色',
      '暗黑',
      'dark',
      'light',
      '外观设置',
    ],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.sun,
    title: '主题和字体',
    description: '自定义应用的外观主题和全局字体大小设置',
    route: AppRouter.appearancePath,
    group: '外观',
    keywords: ['theme', '主题', '字体大小', '深色模式', '浅色模式', '跟随系统', 'font'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.type,
    title: '全局字体大小',
    description: '调整应用中所有文本的基础字体大小',
    route: AppRouter.appearancePath,
    group: '外观',
    keywords: ['font size', '字号', '文字大小', '极小', '标准', '极大'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.paintbrush,
    title: '主题风格',
    description: '选择预设的主题风格配色方案',
    route: AppRouter.themeStyleSettingsPath,
    group: '外观',
    keywords: ['theme style', '配色', '风格', '色彩'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.messageSquare,
    title: '输入框设置',
    description: '自定义输入框外观和功能按钮',
    route: AppRouter.inputBoxSettingsPath,
    group: '外观',
    keywords: ['input', '输入', '按钮', '工具栏'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.panelTop,
    title: '顶部工具栏',
    description: '自定义聊天页面顶部工具栏',
    route: AppRouter.topToolbarSettingsPath,
    group: '外观',
    keywords: ['toolbar', '工具栏', '顶栏', '导航'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.layoutDashboard,
    title: '聊天界面设置',
    description: '自定义聊天界面的布局和显示选项',
    route: AppRouter.chatInterfaceSettingsPath,
    group: '外观',
    keywords: ['chat', '聊天', '界面', '布局', '气泡'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.messageCircle,
    title: '消息气泡',
    description: '自定义消息气泡的外观样式',
    route: AppRouter.messageBubbleSettingsPath,
    group: '外观',
    keywords: ['bubble', '气泡', '消息样式'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.brain,
    title: '思考设置',
    description: '配置AI思考过程的显示方式',
    route: AppRouter.thinkingSettingsPath,
    group: '外观',
    keywords: ['thinking', '思考', '推理', '思维链'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.settings,
    title: '行为',
    description: '消息发送和通知设置',
    route: AppRouter.behaviorPath,
    group: '基本设置',
    keywords: ['behavior', '行为', '发送', '通知', '设置'],
  ),

  // ── 模型服务 ──
  SettingsSearchEntry(
    icon: LucideIcons.bot,
    title: '配置模型',
    description: '管理AI模型和API密钥',
    route: AppRouter.defaultModelPath,
    group: '模型服务',
    keywords: ['model', '模型', 'API', '密钥', 'key', '供应商', 'provider'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.sliders,
    title: '辅助模型',
    description: '聊天、标题、翻译、OCR 等默认模型与提示词',
    route: AppRouter.auxiliaryModelPath,
    group: '模型服务',
    keywords: [
      'auxiliary',
      '辅助',
      '标题模型',
      '翻译模型',
      'OCR',
      '压缩',
      '建议',
      '快速模型',
      '聊天模型',
      '提示词',
    ],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.gitBranch,
    title: '模型组合',
    description: '创建和管理多模型组合',
    route: AppRouter.modelComboPath,
    group: '模型服务',
    keywords: ['combo', '组合', '多模型', '顺序', '路由'],
  ),

  // ── 提示词与工具 ──
  SettingsSearchEntry(
    icon: LucideIcons.wand2,
    title: '智能体提示词集合',
    description: '浏览和使用内置的丰富提示词模板',
    route: AppRouter.agentPromptsPath,
    group: '提示词与工具',
    keywords: ['prompt', '提示词', '模板', 'agent', '智能体'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.zap,
    title: '技能管理 Skills',
    description: '管理AI技能，增强助手能力',
    route: AppRouter.skillsPath,
    group: '提示词与工具',
    keywords: ['skill', '技能', 'MCP', '工具'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.store,
    title: '技能商店',
    description: '浏览和安装 AI 技能扩展',
    route: AppRouter.skillStorePath,
    group: '提示词与工具',
    keywords: ['skill store', '技能商店', '扩展', '插件', '安装'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.globe,
    title: '网络搜索',
    description: '配置网络搜索和相关服务',
    route: AppRouter.webSearchPath,
    group: '提示词与工具',
    keywords: [
      'search',
      '搜索',
      'Brave',
      'Bing',
      'Google',
      'Tavily',
      'Exa',
      'SearXNG',
    ],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.settings,
    title: 'MCP 服务器',
    description: '高级服务器配置',
    route: AppRouter.mcpServerPath,
    group: '提示词与工具',
    keywords: ['MCP', '服务器', 'server', '工具'],
  ),

  // ── 快捷方式 ──
  SettingsSearchEntry(
    icon: LucideIcons.keyboard,
    title: '快捷短语',
    description: '创建常用短语模板',
    route: AppRouter.quickPhrasesPath,
    group: '快捷方式',
    keywords: ['phrase', '短语', '快捷', '模板', '常用语'],
  ),

  // ── 系统 ──
  SettingsSearchEntry(
    icon: LucideIcons.mic,
    title: '语音功能',
    description: '语音识别和文本转语音设置',
    route: AppRouter.voiceSettingsPath,
    group: '系统',
    keywords: [
      'voice',
      '语音',
      'TTS',
      'ASR',
      '语音合成',
      '语音识别',
      '朗读',
      '文本转语音',
    ],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.volume2,
    title: '系统 TTS 配置',
    description: '引擎选择、语言、语速和音调设置',
    route: AppRouter.voiceSettingsPath,
    group: '语音功能',
    keywords: [
      'TTS',
      'system tts',
      '系统语音',
      '引擎',
      '语速',
      '音调',
      'engine',
      'pitch',
      'rate',
      '朗读',
    ],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.shield,
    title: '网络代理',
    description: '配置HTTP/SOCKS代理服务器',
    route: AppRouter.networkProxyPath,
    group: '系统',
    keywords: ['proxy', '代理', 'HTTP', 'SOCKS', '网络', 'VPN'],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.hardDrive,
    title: '备份与恢复',
    description: '本地/WebDAV/S3 备份、数据恢复、备份提醒',
    route: AppRouter.backupSettingsPath,
    group: '数据与知识',
    keywords: [
      'backup',
      'restore',
      '备份',
      '恢复',
      'WebDAV',
      'S3',
      'R2',
      'MinIO',
      '云存储',
      '数据',
      '导出',
      '导入',
      'export',
      'import',
      '提醒',
      'reminder',
    ],
  ),
  SettingsSearchEntry(
    icon: LucideIcons.info,
    title: '关于我们',
    description: '应用信息和技术支持',
    route: AppRouter.aboutPath,
    group: '系统',
    keywords: ['about', '关于', '版本', '信息'],
  ),
];
