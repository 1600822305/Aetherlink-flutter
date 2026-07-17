import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_bubble_settings.freezed.dart';
part 'message_bubble_settings.g.dart';

/// 消息操作显示模式 (`settings.messageActionMode`, `MessageBubbleSettings.tsx`):
/// `bubbles` 在气泡上方显示小功能气泡 + 右上角三点菜单；`toolbar` 在气泡底部
/// 显示完整操作工具栏（默认）。
enum MessageActionMode {
  bubbles('bubbles'),
  toolbar('toolbar');

  const MessageActionMode(this.id);

  /// The original string id persisted in `settings.messageActionMode`.
  final String id;

  static MessageActionMode fromId(String? id) {
    for (final v in MessageActionMode.values) {
      if (v.id == id) return v;
    }
    return MessageActionMode.toolbar;
  }
}

/// 版本切换样式 (`settings.versionSwitchStyle`): `popup` 点击弹出版本列表（默认）；
/// `arrows` 使用左右箭头在版本间切换（`< 2 >`）。
enum VersionSwitchStyle {
  popup('popup'),
  arrows('arrows');

  const VersionSwitchStyle(this.id);

  /// The original string id persisted in `settings.versionSwitchStyle`.
  final String id;

  static VersionSwitchStyle fromId(String? id) {
    for (final v in VersionSwitchStyle.values) {
      if (v.id == id) return v;
    }
    return VersionSwitchStyle.popup;
  }
}

/// 预设的底部工具栏「收纳进更多菜单」操作（按 `MessageActionId.name`）：低频的
/// 导出/分享、版本历史、分叉、另存新话题、存入知识库默认收进上拉菜单，
/// 高频的复制/编辑/重新生成/播放/翻译/删除保持外露。用户可在信息气泡管理
/// 页自定义；[MessageBubbleSettings.collapsedActionIds] 为 null 时用此预设。
const List<String> kDefaultCollapsedActionIds = [
  'export',
  'regenerateWithModel',
  'versionHistory',
  'fork',
  'branch',
  'saveToKnowledge',
];

/// 自定义气泡颜色 (`settings.customBubbleColors`): 用户/AI 气泡的背景色与字体色。
/// 空字符串表示「使用系统默认（主题）颜色」，对齐原版的留空回退行为。颜色以
/// `#RRGGBB` 字符串保存。
@freezed
abstract class CustomBubbleColors with _$CustomBubbleColors {
  const factory CustomBubbleColors({
    @Default('') String userBubbleColor,
    @Default('') String userTextColor,
    @Default('') String aiBubbleColor,
    @Default('') String aiTextColor,
  }) = _CustomBubbleColors;

  factory CustomBubbleColors.fromJson(Map<String, dynamic> json) =>
      _$CustomBubbleColorsFromJson(json);
}

/// The 信息气泡管理 configuration the appearance sub-page edits and the chat view
/// renders, a port of the original `settings` slice fields read by
/// `MessageBubbleSettings.tsx` / `BubbleStyleMessage.tsx`.
///
/// Defaults mirror the original component fallbacks: toolbar action mode, micro
/// bubbles + TTS on, popup version switch, widths 99/80/50 (%), avatars + names
/// shown, bubbles not hidden and empty custom colors (so the theme tokens win).
@freezed
abstract class MessageBubbleSettings with _$MessageBubbleSettings {
  const factory MessageBubbleSettings({
    @Default(MessageActionMode.toolbar) MessageActionMode messageActionMode,
    @Default(true) bool showMicroBubbles,
    @Default(true) bool showTTSButton,
    @Default(VersionSwitchStyle.popup) VersionSwitchStyle versionSwitchStyle,
    // AI 消息最大宽度（%），原版默认 99。
    @Default(99) int messageBubbleMaxWidth,
    // 用户消息最大宽度（%），原版默认 80。
    @Default(80) int userMessageMaxWidth,
    // 所有消息的最小宽度（%），原版默认 50。
    @Default(50) int messageBubbleMinWidth,
    @Default(true) bool showUserAvatar,
    @Default(true) bool showUserName,
    @Default(true) bool showModelAvatar,
    @Default(true) bool showModelName,
    @Default(false) bool hideUserBubble,
    @Default(false) bool hideAIBubble,
    // 底部工具栏收纳进「更多」上拉菜单的操作 id 列表（MessageActionId.name）。
    // null = 未自定义，用 [kDefaultCollapsedActionIds] 预设；空列表 = 全部外露。
    List<String>? collapsedActionIds,
    @Default(CustomBubbleColors()) CustomBubbleColors customBubbleColors,
  }) = _MessageBubbleSettings;

  factory MessageBubbleSettings.fromJson(Map<String, dynamic> json) =>
      _$MessageBubbleSettingsFromJson(json);
}
