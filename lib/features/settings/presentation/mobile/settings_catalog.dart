import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

/// Static navigation catalog for the settings hub — the grouped list of rows
/// the original renders (`src/pages/Settings/index.tsx` `settingsGroups`).
///
/// This is navigation chrome, so it lives in `presentation`: it carries Flutter
/// `IconData` (lucide, ADR-0009), which must never sink into `domain` /
/// `application`. Titles/descriptions are the verbatim original `settings.*`
/// zh-CN i18n strings, lifted to static constants (the M4.1/M4.2 approach — a
/// real i18n system is a separate later effort).
///
/// Icons are the original's lucide-react icons mapped to their `LucideIcons.*`
/// equivalents one-to-one — no `Icons.*` approximations (ADR-0009).
///
/// This milestone builds only the hub. Every row except "关于我们" is a
/// not-yet-implemented placeholder ([enabled] = false → rendered disabled); its
/// sub-page is a later milestone. "关于我们" is wired to the existing About page
/// ([route] = [AppRouter.aboutPath]) to prove the hub actually navigates. No
/// fake sub-pages, no fabricated data.

/// The settings hub title (`settings.title`).
const String kSettingsTitle = '设置';

/// Header toggle tooltips (`settings.compactMode` / `settings.detailedMode`,
/// which fell back to these literals in the original `t()` calls).
const String kSettingsCompactModeLabel = '精简模式';
const String kSettingsDetailedModeLabel = '详细模式';

/// A single settings hub row.
@immutable
class SettingItemData {
  const SettingItemData({
    required this.icon,
    required this.title,
    required this.description,
    this.route,
  });

  final IconData icon;
  final String title;
  final String description;

  /// The route this row navigates to, or `null` when its sub-page does not
  /// exist yet (rendered disabled this milestone).
  final String? route;

  /// A row is interactive only once its target route exists.
  bool get enabled => route != null;
}

/// A titled group of rows (a card in the hub).
@immutable
class SettingGroupData {
  const SettingGroupData({required this.title, required this.items});

  final String title;
  final List<SettingItemData> items;
}

/// The hub's groups, in the original's order. Only "关于我们" is wired.
const List<SettingGroupData> kSettingsGroups = <SettingGroupData>[
  SettingGroupData(
    title: '基本设置',
    items: <SettingItemData>[
      SettingItemData(
        icon: LucideIcons.palette,
        title: '外观',
        description: '主题、字体大小和语言设置',
        route: AppRouter.appearancePath,
      ),
      SettingItemData(
        icon: LucideIcons.settings,
        title: '行为',
        description: '消息发送和通知设置',
      ),
    ],
  ),
  SettingGroupData(
    title: '模型服务',
    items: <SettingItemData>[
      SettingItemData(
        icon: LucideIcons.bot,
        title: '配置模型',
        description: '管理AI模型和API密钥',
        route: AppRouter.defaultModelPath,
      ),
      SettingItemData(
        icon: LucideIcons.sliders,
        title: '辅助模型设置',
        description: '配置话题命名、AI 意图分析、视觉识别等辅助功能',
      ),
      SettingItemData(
        icon: LucideIcons.messageSquare,
        title: 'AI辩论设置',
        description: '配置AI互相辩论讨论功能',
      ),
      SettingItemData(
        icon: LucideIcons.gitBranch,
        title: '模型组合',
        description: '创建和管理多模型组合',
      ),
      SettingItemData(
        icon: LucideIcons.foldVertical,
        title: '上下文压缩',
        description: '智能压缩对话历史，节省Token成本',
      ),
    ],
  ),
  SettingGroupData(
    title: '提示词与工具',
    items: <SettingItemData>[
      SettingItemData(
        icon: LucideIcons.wand2,
        title: '智能体提示词集合',
        description: '浏览和使用内置的丰富提示词模板',
        route: AppRouter.agentPromptsPath,
      ),
      SettingItemData(
        icon: LucideIcons.zap,
        title: '技能管理 Skills',
        description: '管理AI技能，增强助手能力',
      ),
      SettingItemData(
        icon: LucideIcons.globe,
        title: '网络搜索',
        description: '配置网络搜索和相关服务',
      ),
      SettingItemData(
        icon: LucideIcons.settings,
        title: 'MCP 服务器',
        description: '高级服务器配置',
        route: AppRouter.mcpServerPath,
      ),
    ],
  ),
  SettingGroupData(
    title: '快捷方式',
    items: <SettingItemData>[
      SettingItemData(
        icon: LucideIcons.keyboard,
        title: '快捷短语',
        description: '创建常用短语模板',
      ),
    ],
  ),
  SettingGroupData(
    title: '数据与知识',
    items: <SettingItemData>[
      SettingItemData(
        icon: LucideIcons.folder,
        title: '工作区管理',
        description: '创建和管理文件工作区',
      ),
      SettingItemData(
        icon: LucideIcons.bookOpen,
        title: '知识库设置',
        description: '管理知识库配置和嵌入模型',
      ),
      SettingItemData(
        icon: LucideIcons.database,
        title: '记忆功能',
        description: '管理AI长期记忆，自动记住用户偏好',
      ),
      SettingItemData(
        icon: LucideIcons.fileText,
        title: '笔记设置',
        description: '配置本地笔记存储路径和显示选项',
      ),
      SettingItemData(
        icon: LucideIcons.database,
        title: '数据设置',
        description: '管理数据存储和隐私选项',
      ),
      SettingItemData(
        icon: LucideIcons.database,
        title: 'Notion 集成',
        description: '配置Notion数据库导出设置',
      ),
    ],
  ),
  SettingGroupData(
    title: '系统',
    items: <SettingItemData>[
      SettingItemData(
        icon: LucideIcons.mic,
        title: '语音功能',
        description: '语音识别和文本转语音设置',
      ),
      SettingItemData(
        icon: LucideIcons.shield,
        title: '网络代理',
        description: '配置HTTP/SOCKS代理服务器',
      ),
      SettingItemData(
        icon: LucideIcons.info,
        title: '关于我们',
        description: '应用信息和技术支持',
        route: AppRouter.aboutPath,
      ),
    ],
  ),
];
