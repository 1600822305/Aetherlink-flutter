import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/tts_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/translate_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action_sheets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// The **headless behaviour layer** for message actions: the single source of
/// truth for *which* actions a message has, *when* they show, and *what* they
/// do — with no rendering opinion.
///
/// It ports every handler that used to live inside `MessageToolbar`'s `State`
/// (复制 / 编辑 / 导出·分享 / 重新发送 / 重新生成 / 语音播放 / 翻译 / 版本历史 /
/// 创建分支 / 删除) and exposes them as a [MessageAction] list via [build]. Both
/// presentation surfaces — the bottom toolbar (toolbar 模式) and the bubble
/// micro-bubbles + 三点菜单 (气泡模式) — consume this same list, so adding or
/// changing an action is a one-place edit and the two modes never drift apart.
///
/// Ephemeral *view* state (删除 two-tap confirmation, 语音播放 highlight,
/// 版本切换 popup/arrows) stays in the rendering widgets; this layer only models
/// the durable behaviour.
class MessageActionsBuilder {
  const MessageActionsBuilder({
    required this.ref,
    required this.context,
    required this.view,
    required this.showTtsButton,
    required this.isMounted,
  });

  final WidgetRef ref;
  final BuildContext context;
  final ChatMessageView view;

  /// Mirrors 信息气泡管理 → 显示播放按钮 (`showTTSButton`); when off the 语音播放
  /// action is omitted, like the original `enableTTS && showTTSButton` gate.
  final bool showTtsButton;

  /// Whether the host widget is still mounted, guarding `context` use after an
  /// `await` (the original toolbar checked its `State.mounted`).
  final bool Function() isMounted;

  bool get _isUser => view.role == MessageRole.user;

  String get _mainText => view.text;

  void _toast(String message) {
    if (!isMounted()) return;
    AppToast.info(context, message);
  }

  /// Builds the ordered, visibility-filtered action list. The order matches the
  /// original toolbar: 复制 · 编辑 · 导出 · (重新发送|重新生成) · 语音播放 · 翻译 ·
  /// 版本历史 · 创建分支 · 删除.
  List<MessageAction> build() {
    return <MessageAction>[
      MessageAction(
        id: MessageActionId.copy,
        icon: LucideIcons.copy,
        tooltip: '复制内容',
        onInvoke: copyContent,
      ),
      MessageAction(
        id: MessageActionId.edit,
        icon: LucideIcons.squarePen,
        tooltip: '编辑',
        onInvoke: openEditor,
      ),
      MessageAction(
        id: MessageActionId.export,
        icon: LucideIcons.share2,
        tooltip: '导出/分享',
        onInvoke: enterSelectionMode,
      ),
      if (_isUser)
        MessageAction(
          id: MessageActionId.resend,
          icon: LucideIcons.refreshCw,
          tooltip: '重新发送',
          onInvoke: resend,
        )
      else
        MessageAction(
          id: MessageActionId.regenerate,
          icon: LucideIcons.refreshCw,
          tooltip: '重新生成',
          onInvoke: regenerate,
        ),
      if (!_isUser && showTtsButton)
        MessageAction(
          id: MessageActionId.tts,
          icon: LucideIcons.volume2,
          tooltip: '语音播放',
          onInvoke: toggleTts,
          isPrimary: true,
        ),
      if (!_isUser)
        MessageAction(
          id: MessageActionId.translate,
          icon: LucideIcons.languages,
          tooltip: '翻译',
          onInvoke: openTranslateMenu,
        ),
      if (!_isUser && view.versions.isNotEmpty)
        MessageAction(
          id: MessageActionId.versionHistory,
          icon: LucideIcons.history,
          tooltip: '版本历史',
          onInvoke: openVersionHistory,
        ),
      MessageAction(
        id: MessageActionId.branch,
        icon: LucideIcons.gitBranch,
        tooltip: '创建分支',
        onInvoke: createBranch,
      ),
      MessageAction(
        id: MessageActionId.delete,
        icon: LucideIcons.trash2,
        tooltip: '删除',
        onInvoke: delete,
        isDestructive: true,
      ),
    ];
  }

  // -- Handlers --------------------------------------------------------------

  Future<void> copyContent() async {
    final content = _mainText.trim();
    if (content.isEmpty) {
      _toast('没有可复制的内容');
      return;
    }
    await Clipboard.setData(ClipboardData(text: content));
    _toast('已复制到剪贴板');
  }

  Future<void> openEditor() async {
    final blocks = view.blocks.whereType<MainTextBlock>().toList();
    if (blocks.isEmpty) {
      _toast('没有可编辑的内容');
      return;
    }
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MessageEditorSheet(isUser: _isUser, blocks: blocks),
    );
    if (result != null && result.isNotEmpty) {
      await ref
          .read(chatControllerProvider.notifier)
          .editMessageText(view.id, result);
    }
  }

  void enterSelectionMode() {
    final messages =
        ref.read(chatControllerProvider).value?.messages ??
        const <ChatMessageView>[];
    final index = messages.indexWhere((m) => m.id == view.id);
    ref
        .read(messageSelectionProvider.notifier)
        .enterSelectionMode(anchorIndex: index, messages: messages);
  }

  void resend() => ref.read(chatControllerProvider.notifier).resend(view.id);

  void regenerate() =>
      ref.read(chatControllerProvider.notifier).regenerate(view.id);

  void toggleTts() {
    final text = _mainText.trim();
    if (text.isEmpty) {
      _toast('没有可播放的内容');
      return;
    }
    ref.read(ttsActionsProvider).speak(text, messageId: view.id);
  }

  /// Opens the 翻译 language picker and translates this message into the chosen
  /// language. Port of `MessageTranslateButton`. Guards on empty content / no
  /// configured model before opening.
  Future<void> openTranslateMenu() async {
    if (_mainText.trim().isEmpty) {
      _toast('没有可翻译的内容');
      return;
    }
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final model = await ref.read(translateModelProvider.future);
    if (!isMounted()) return;
    if (model == null) {
      _toast('请先在「模型」中配置可用模型');
      return;
    }
    final language = await showModalBottomSheet<TranslateLanguage>(
      // Guarded by isMounted() above; the analyzer can't see that across the
      // function boundary.
      // ignore: use_build_context_synchronously
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const TranslateLanguageSheet(),
    );
    if (language == null || !isMounted()) return;
    await ref
        .read(chatControllerProvider.notifier)
        .translateMessage(view.id, language);
  }

  Future<void> openVersionHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MessageVersionHistorySheet(messageId: view.id),
    );
  }

  Future<void> createBranch() async {
    final created = await ref
        .read(topicsProvider.notifier)
        .createBranch(view.id);
    _toast(created == null ? '创建分支失败' : '已创建分支');
  }

  void delete() =>
      ref.read(chatControllerProvider.notifier).deleteMessage(view.id);
}
