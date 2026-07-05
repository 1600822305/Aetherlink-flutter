import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Stable identity of a message action, independent of how it is rendered.
///
/// Used to special-case the few actions whose presentation differs from a plain
/// icon button (e.g. [tts] watches playback state to highlight) and to key the
/// behaviour-layer contract tests.
enum MessageActionId {
  copy,
  edit,
  export,
  resend,
  regenerate,
  tts,
  translate,
  versionHistory,
  fork,
  branch,
  saveToKnowledge,
  delete,
}

/// Static display metadata (icon + label) per action id, for surfaces that
/// list actions without a live message — e.g. 信息气泡管理 → 工具栏收纳
/// customization and its live preview. Icons/labels match
/// `MessageActionsBuilder.build`.
const Map<MessageActionId, ({IconData icon, String label})>
kMessageActionCatalog = {
  MessageActionId.copy: (icon: LucideIcons.copy, label: '复制内容'),
  MessageActionId.edit: (icon: LucideIcons.squarePen, label: '编辑'),
  MessageActionId.export: (icon: LucideIcons.fileText, label: '导出/分享'),
  MessageActionId.resend: (icon: LucideIcons.refreshCw, label: '重新发送'),
  MessageActionId.regenerate: (icon: LucideIcons.refreshCw, label: '重新生成'),
  MessageActionId.tts: (icon: LucideIcons.volume2, label: '语音播放'),
  MessageActionId.translate: (icon: LucideIcons.languages, label: '翻译'),
  MessageActionId.versionHistory: (icon: LucideIcons.history, label: '版本历史'),
  MessageActionId.fork: (icon: LucideIcons.gitBranch, label: '从此处分叉'),
  MessageActionId.branch: (icon: LucideIcons.save, label: '另存为新话题'),
  MessageActionId.saveToKnowledge: (icon: LucideIcons.bookOpen, label: '存入知识库'),
  MessageActionId.delete: (icon: LucideIcons.trash2, label: '删除'),
};

/// A single message action as pure data: *what* it is and *what it does*, with
/// no opinion on *how* it is laid out.
///
/// This is the shared contract produced by the headless behaviour layer
/// (`MessageActionsBuilder`) and consumed by every presentation surface — the
/// bottom toolbar (功能 toolbar 模式) and the bubble micro-bubbles + 三点菜单
/// (功能气泡模式). Adding or changing an action happens here + in the builder
/// once, and every mode stays in sync.
@immutable
class MessageAction {
  const MessageAction({
    required this.id,
    required this.icon,
    required this.tooltip,
    required this.onInvoke,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final MessageActionId id;

  final IconData icon;

  /// The button tooltip / menu label.
  final String tooltip;

  /// Performs the action. May be async (opens a sheet, awaits the controller).
  final FutureOr<void> Function() onInvoke;

  /// Whether this belongs to the small "功能气泡" set shown above the bubble in
  /// 气泡模式 (播放 / 版本切换), as opposed to the 三点菜单. Ignored in toolbar
  /// 模式, where every action is rendered inline.
  final bool isPrimary;

  /// Whether this is a destructive action (删除): rendered with the error color
  /// and a two-step confirmation in the toolbar / a confirm dialog in the menu.
  final bool isDestructive;
}
