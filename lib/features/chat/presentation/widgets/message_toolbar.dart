import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/translate_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/token_display.dart';
import 'package:aetherlink_flutter/features/voice/application/tts_controller.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// The message bubble bottom toolbar (`MessageActions` `renderMode === 'toolbar'`).
///
/// Renders below the bubble whenever 外观设置 → 信息气泡管理 sets 操作显示模式 to
/// `toolbar`. It reproduces the original toolbar's full button set and per-role
/// layout:
///
/// * 用户消息: 复制 · 编辑 · 导出/保存 · 重新发送 · 创建分支 · 删除
/// * AI 消息: 复制 · 编辑 · 导出/保存 · 重新生成 · 语音播放 · 翻译 · 版本历史 ·
///   创建分支 · 删除
///
/// 复制 / 编辑 / 删除 / 导出·分享 / 重新发送 / 重新生成 / 创建分支 / 版本历史 /
/// 翻译 are wired to real behaviour (版本历史 only appears once a message has
/// saved versions, e.g. after 重新生成; 翻译 opens a language picker and streams
/// a TranslationBlock onto the message). The remaining button depends on a
/// system not yet ported (语音播放) — it is drawn for UI parity but surfaces a
/// 「即将支持」 hint on tap rather than faking success.
class MessageToolbar extends ConsumerStatefulWidget {
  const MessageToolbar({
    required this.view,
    required this.showTtsButton,
    this.customTextColor,
    super.key,
  });

  final ChatMessageView view;

  /// Mirrors 信息气泡管理 → 显示播放按钮 (`showTTSButton`); when off the 语音播放
  /// button is hidden, like the original `enableTTS && showTTSButton` gate.
  final bool showTtsButton;

  /// The bubble's custom text color when 自定义气泡颜色 is set, else null. Tints
  /// the toolbar icons to match, mirroring the original `customTextColor` prop.
  final Color? customTextColor;

  @override
  ConsumerState<MessageToolbar> createState() => _MessageToolbarState();
}

class _MessageToolbarState extends ConsumerState<MessageToolbar> {
  static const Duration _deleteResetDelay = Duration(seconds: 3);

  bool _deleteConfirming = false;
  Timer? _deleteTimer;

  @override
  void dispose() {
    _deleteTimer?.cancel();
    super.dispose();
  }

  ChatMessageView get _view => widget.view;

  bool get _isUser => _view.role == MessageRole.user;

  String get _mainText => _view.text;

  void _toast(String message) {
    if (!mounted) return;
    AppToast.info(context, message);
  }

  void _toggleTts() {
    final text = _mainText.trim();
    if (text.isEmpty) {
      _toast('没有可播放的内容');
      return;
    }
    ref.read(ttsControllerProvider.notifier).speak(text, messageId: _view.id);
  }

  void _regenerate() {
    ref.read(chatControllerProvider.notifier).regenerate(_view.id);
  }

  void _resend() {
    ref.read(chatControllerProvider.notifier).resend(_view.id);
  }

  Future<void> _createBranch() async {
    final created = await ref
        .read(topicsProvider.notifier)
        .createBranch(_view.id);
    _toast(created == null ? '创建分支失败' : '已创建分支');
  }

  /// Opens the 翻译 language picker and translates this message into the chosen
  /// language. Port of `MessageTranslateButton` (anchored Menu → bottom sheet on
  /// mobile). Guards on empty content / no configured model before opening.
  Future<void> _openTranslateMenu() async {
    if (_mainText.trim().isEmpty) {
      _toast('没有可翻译的内容');
      return;
    }
    final model = await ref.read(translateModelProvider.future);
    if (!mounted) return;
    if (model == null) {
      _toast('请先在「模型」中配置可用模型');
      return;
    }
    final language = await showModalBottomSheet<TranslateLanguage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _TranslateLanguageSheet(),
    );
    if (language == null || !mounted) return;
    await ref
        .read(chatControllerProvider.notifier)
        .translateMessage(_view.id, language);
  }

  Future<void> _openVersionHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _VersionHistorySheet(messageId: _view.id),
    );
  }

  Future<void> _copyContent() async {
    final content = _mainText.trim();
    if (content.isEmpty) {
      _toast('没有可复制的内容');
      return;
    }
    await Clipboard.setData(ClipboardData(text: content));
    _toast('已复制到剪贴板');
  }

  void _handleDeleteTap() {
    if (!_deleteConfirming) {
      setState(() => _deleteConfirming = true);
      _deleteTimer?.cancel();
      _deleteTimer = Timer(_deleteResetDelay, () {
        if (mounted) setState(() => _deleteConfirming = false);
      });
      return;
    }
    _deleteTimer?.cancel();
    setState(() => _deleteConfirming = false);
    ref.read(chatControllerProvider.notifier).deleteMessage(_view.id);
  }

  Future<void> _openEditor() async {
    final blocks = _view.blocks.whereType<MainTextBlock>().toList();
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
      builder: (_) => _MessageEditorSheet(isUser: _isUser, blocks: blocks),
    );
    if (result != null && result.isNotEmpty) {
      await ref
          .read(chatControllerProvider.notifier)
          .editMessageText(_view.id, result);
    }
  }

  void _enterSelectionMode() {
    final messages =
        ref.read(chatControllerProvider).value?.messages ??
        const <ChatMessageView>[];
    final index = messages.indexWhere((m) => m.id == _view.id);
    ref
        .read(messageSelectionProvider.notifier)
        .enterSelectionMode(anchorIndex: index, messages: messages);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.customTextColor ?? theme.colorScheme.onSurface;
    final errorColor = theme.colorScheme.error;

    final buttons = <Widget>[
      _ToolbarIconButton(
        icon: LucideIcons.copy,
        tooltip: '复制内容',
        color: baseColor,
        onTap: _copyContent,
      ),
      _ToolbarIconButton(
        icon: LucideIcons.squarePen,
        tooltip: '编辑',
        color: baseColor,
        onTap: _openEditor,
      ),
      _ToolbarIconButton(
        icon: LucideIcons.share2,
        tooltip: '导出/分享',
        color: baseColor,
        onTap: _enterSelectionMode,
      ),
      if (_isUser)
        _ToolbarIconButton(
          icon: LucideIcons.refreshCw,
          tooltip: '重新发送',
          color: baseColor,
          onTap: _resend,
        )
      else
        _ToolbarIconButton(
          icon: LucideIcons.refreshCw,
          tooltip: '重新生成',
          color: baseColor,
          onTap: _regenerate,
        ),
      if (!_isUser && widget.showTtsButton)
        Consumer(
          builder: (context, ref, _) {
            TtsPlaybackState? ttsState;
            try {
              ttsState = ref.watch(ttsControllerProvider);
            } catch (_) {
              // Provider not ready — show default icon.
            }
            final isPlayingThis = ttsState != null &&
                ttsState.messageId == _view.id &&
                (ttsState.status == TtsStatus.playing ||
                    ttsState.status == TtsStatus.loading);
            return _ToolbarIconButton(
              icon: isPlayingThis ? LucideIcons.volumeOff : LucideIcons.volume2,
              tooltip: isPlayingThis ? '停止播放' : '语音播放',
              color: isPlayingThis
                  ? theme.colorScheme.primary
                  : baseColor,
              onTap: _toggleTts,
            );
          },
        ),
      if (!_isUser)
        _ToolbarIconButton(
          icon: LucideIcons.languages,
          tooltip: '翻译',
          color: baseColor,
          onTap: _openTranslateMenu,
        ),
      if (!_isUser && _view.versions.isNotEmpty)
        _ToolbarIconButton(
          icon: LucideIcons.history,
          tooltip: '版本历史',
          color: baseColor,
          onTap: _openVersionHistory,
        ),
      _ToolbarIconButton(
        icon: LucideIcons.gitBranch,
        tooltip: '创建分支',
        color: baseColor,
        onTap: _createBranch,
      ),
      _ToolbarIconButton(
        icon: LucideIcons.trash2,
        tooltip: _deleteConfirming ? '再次点击确认删除' : '删除',
        color: _deleteConfirming ? errorColor : baseColor,
        emphasized: _deleteConfirming,
        onTap: _handleDeleteTap,
      ),
    ];

    final buttonGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final button in buttons)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: button,
          ),
      ],
    );

    // Token usage chip: pushed flush against the far edge of the toolbar — the
    // right for AI replies, the left for user messages — with the button group
    // hugging the opposite edge (matching `MessageActions`' toolbar layout,
    // where the button group is `flex: 1`). The row fills the bubble width
    // ([BubbleFooterLayout] stretches the footer), so a [Spacer] separates the
    // two groups.
    final tokenDisplay = TokenDisplay(view: _view, baseColor: baseColor);

    return Row(
      children: _isUser
          ? [tokenDisplay, const Spacer(), buttonGroup]
          : [buttonGroup, const Spacer(), tokenDisplay],
    );
  }
}

/// A single toolbar icon button: opacity 0.8 at rest, brightening to 1 and
/// scaling to 1.1 on hover, matching `getToolbarIconButtonStyle`. The delete
/// button passes [emphasized] to hold the brightened/scaled state while it is
/// awaiting confirmation.
class _ToolbarIconButton extends StatefulWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  State<_ToolbarIconButton> createState() => _ToolbarIconButtonState();
}

class _ToolbarIconButtonState extends State<_ToolbarIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovering || widget.emphasized;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: active ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: active ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(widget.icon, size: 16, color: widget.color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 编辑 bottom drawer (`MessageEditor`): one multiline field per `main_text`
/// block with 取消/保存 actions. Pops a `{blockId: content}` map on save.
class _MessageEditorSheet extends StatefulWidget {
  const _MessageEditorSheet({required this.isUser, required this.blocks});

  final bool isUser;
  final List<MainTextBlock> blocks;

  @override
  State<_MessageEditorSheet> createState() => _MessageEditorSheetState();
}

class _MessageEditorSheetState extends State<_MessageEditorSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final block in widget.blocks)
        TextEditingController(text: block.content),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasContent =>
      _controllers.any((controller) => controller.text.trim().isNotEmpty);

  void _save() {
    final result = <String, String>{};
    for (var i = 0; i < widget.blocks.length; i++) {
      final text = _controllers[i].text.trim();
      if (text.isNotEmpty) result[widget.blocks[i].id] = text;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multi = widget.blocks.length > 1;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '编辑${widget.isUser ? '消息' : '回复'}',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (multi) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${widget.blocks.length} 个文本块)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _controllers.length; i++) ...[
                      if (multi)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '文本块 ${i + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      TextField(
                        controller: _controllers[i],
                        autofocus: i == 0,
                        minLines: multi ? 3 : 6,
                        maxLines: multi ? 8 : 12,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '请输入内容...',
                        ),
                      ),
                      if (i != _controllers.length - 1)
                        const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _hasContent ? _save : null,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 翻译 language picker (`MessageTranslateButton`'s anchored Menu, rendered
/// as a bottom sheet). Lists the builtin languages with emoji + label and pops
/// the chosen [TranslateLanguage].
class _TranslateLanguageSheet extends StatelessWidget {
  const _TranslateLanguageSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '翻译为',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final lang in builtinTranslateLanguages)
                    ListTile(
                      leading: Text(
                        lang.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(lang.label),
                      onTap: () => Navigator.of(context).pop(lang),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 版本历史 bottom sheet (`MessageActions` version Popover). Lists the saved
/// versions plus a 最新版本 entry, highlights the one on display, and wires 切换 /
/// 删除 / 保存当前 to [ChatController]. Watches the conversation so the list
/// reflects saves/deletes without closing; switching pops the sheet.
class _VersionHistorySheet extends ConsumerWidget {
  const _VersionHistorySheet({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(chatControllerProvider).value;
    ChatMessageView? view;
    if (state != null) {
      for (final candidate in state.messages) {
        if (candidate.id == messageId) {
          view = candidate;
          break;
        }
      }
    }
    final versions = view?.versions ?? const <MessageVersion>[];
    final currentVersionId = view?.currentVersionId;

    // Nothing left to show (e.g. the last version was deleted): close the sheet.
    if (view == null || versions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      });
      return const SizedBox.shrink();
    }

    final notifier = ref.read(chatControllerProvider.notifier);
    final latestNumber = versions.length + 1;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  '消息版本历史',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => notifier.createManualVersion(messageId),
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text('保存当前'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ),
          if (versions.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '已保存 ${versions.length}/20 个版本',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          const Divider(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < versions.length; i++)
                  _VersionTile(
                    label: '版本 ${i + 1}',
                    sourceText: _sourceText(versions[i]),
                    timeText: _formatTime(versions[i].createdAt),
                    isCurrent: versions[i].id == currentVersionId,
                    onTap: () async {
                      await notifier.switchToVersion(messageId, versions[i].id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    onDelete: () =>
                        notifier.deleteVersion(messageId, versions[i].id),
                  ),
                _VersionTile(
                  label: '版本 $latestNumber',
                  sourceText: '最新',
                  timeText: '最新版本',
                  isCurrent: currentVersionId == null,
                  onTap: () async {
                    await notifier.switchToLatest(messageId);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  onDelete: null,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Mirrors `getVersionSourceText`: maps a version's `source` metadata to the
  /// label chip shown beside it.
  String _sourceText(MessageVersion version) {
    final source = version.metadata?['source'];
    if (source is! String) return '';
    switch (source) {
      case 'regenerate':
        return '重新生成';
      case 'manual':
        return '手动保存';
      case 'auto_before_switch':
        return '自动保存';
      default:
        return '';
    }
  }

  /// A short relative timestamp like the original `dayjs().fromNow()`.
  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    required this.label,
    required this.sourceText,
    required this.timeText,
    required this.isCurrent,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final String sourceText;
  final String timeText;
  final bool isCurrent;
  final Future<void> Function() onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: isCurrent
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: ListTile(
        onTap: isCurrent ? null : onTap,
        title: Row(
          children: [
            Flexible(
              child: Text(
                isCurrent ? '$label (当前)' : label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (sourceText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sourceText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(timeText),
        trailing: onDelete == null
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.trash2, size: 16),
                tooltip: '删除版本',
                onPressed: onDelete,
              ),
      ),
    );
  }
}
