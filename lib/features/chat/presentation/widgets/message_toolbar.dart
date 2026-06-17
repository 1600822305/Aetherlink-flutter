import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

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
/// 复制 / 编辑 / 删除 / 导出·分享 / 重新生成 are wired to real behaviour. The
/// remaining buttons depend on the request layer or systems not yet ported
/// (重新发送/语音播放/翻译/版本历史/创建分支) — they are drawn for UI parity but
/// surface a 「即将支持」 hint on tap rather than faking success.
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

  String get _thinkingText => _view.thinking;

  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _comingSoon() => _toast('即将支持');

  void _regenerate() {
    ref.read(chatControllerProvider.notifier).regenerate(_view.id);
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

  /// Builds the message Markdown, mirroring `exportUtils.messageToMarkdown` /
  /// `messageToMarkdownWithReasoning`: a `## 用户`/`## 助手` title, optional
  /// 思考过程/回答 sections, then the main text.
  String _toMarkdown({required bool includeReasoning}) {
    final title = _isUser ? '## 用户' : '## 助手';
    final content = _mainText.trim();
    if (includeReasoning && _thinkingText.trim().isNotEmpty) {
      return '$title\n\n### 思考过程\n\n${_thinkingText.trim()}'
          '\n\n### 回答\n\n$content';
    }
    return '$title\n\n$content';
  }

  Future<void> _copyMarkdown({required bool includeReasoning}) async {
    final markdown = _toMarkdown(includeReasoning: includeReasoning).trim();
    if (markdown.isEmpty) {
      _toast('没有可复制的内容');
      return;
    }
    await Clipboard.setData(ClipboardData(text: markdown));
    _toast(includeReasoning ? '已复制 Markdown（含思考）' : '已复制为 Markdown');
  }

  Future<void> _share({required bool asMarkdown}) async {
    final content = asMarkdown
        ? _toMarkdown(includeReasoning: false).trim()
        : _mainText.trim();
    if (content.isEmpty) {
      _toast('没有可分享的内容');
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(text: content));
    } catch (_) {
      // Desktop platforms may lack a native share sheet; fall back to copy so
      // the action is never a silent no-op.
      await Clipboard.setData(ClipboardData(text: content));
      _toast('已复制到剪贴板');
    }
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

  Future<void> _openExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _ExportSheet(
        onCopyMarkdown: () {
          Navigator.of(sheetContext).pop();
          _copyMarkdown(includeReasoning: false);
        },
        onCopyMarkdownWithReasoning: () {
          Navigator.of(sheetContext).pop();
          _copyMarkdown(includeReasoning: true);
        },
        onShareText: () {
          Navigator.of(sheetContext).pop();
          _share(asMarkdown: false);
        },
        onShareMarkdown: () {
          Navigator.of(sheetContext).pop();
          _share(asMarkdown: true);
        },
        onComingSoon: () {
          Navigator.of(sheetContext).pop();
          _comingSoon();
        },
      ),
    );
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
        icon: LucideIcons.fileText,
        tooltip: '导出/保存',
        color: baseColor,
        onTap: _openExportSheet,
      ),
      if (_isUser)
        _ToolbarIconButton(
          icon: LucideIcons.refreshCw,
          tooltip: '重新发送',
          color: baseColor,
          onTap: _comingSoon,
        )
      else
        _ToolbarIconButton(
          icon: LucideIcons.refreshCw,
          tooltip: '重新生成',
          color: baseColor,
          onTap: _regenerate,
        ),
      if (!_isUser && widget.showTtsButton)
        _ToolbarIconButton(
          icon: LucideIcons.volume2,
          tooltip: '语音播放',
          color: baseColor,
          onTap: _comingSoon,
        ),
      if (!_isUser)
        _ToolbarIconButton(
          icon: LucideIcons.languages,
          tooltip: '翻译',
          color: baseColor,
          onTap: _comingSoon,
        ),
      if (!_isUser)
        _ToolbarIconButton(
          icon: LucideIcons.history,
          tooltip: '版本历史',
          color: baseColor,
          onTap: _comingSoon,
        ),
      _ToolbarIconButton(
        icon: LucideIcons.gitBranch,
        tooltip: '创建分支',
        color: baseColor,
        onTap: _comingSoon,
      ),
      _ToolbarIconButton(
        icon: LucideIcons.trash2,
        tooltip: _deleteConfirming ? '再次点击确认删除' : '删除',
        color: _deleteConfirming ? errorColor : baseColor,
        emphasized: _deleteConfirming,
        onTap: _handleDeleteTap,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: _isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          for (final button in buttons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: button,
            ),
        ],
      ),
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

/// The 导出/保存 bottom sheet (`UnifiedExportMenu`). Wires the actions that work
/// without extra systems (复制为 Markdown / 分享文本·Markdown) and surfaces the
/// ones that need note storage / image capture / Obsidian as 「即将支持」.
class _ExportSheet extends StatelessWidget {
  const _ExportSheet({
    required this.onCopyMarkdown,
    required this.onCopyMarkdownWithReasoning,
    required this.onShareText,
    required this.onShareMarkdown,
    required this.onComingSoon,
  });

  final VoidCallback onCopyMarkdown;
  final VoidCallback onCopyMarkdownWithReasoning;
  final VoidCallback onShareText;
  final VoidCallback onShareMarkdown;
  final VoidCallback onComingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '导出/保存',
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
                _sectionLabel(theme, '快捷保存'),
                ListTile(
                  leading: const Icon(LucideIcons.notebookPen, size: 20),
                  title: const Text('保存为笔记'),
                  subtitle: const Text('保存到应用笔记'),
                  onTap: onComingSoon,
                ),
                ListTile(
                  leading: const Icon(LucideIcons.save, size: 20),
                  title: const Text('保存为文件'),
                  subtitle: const Text('导出为文本文件'),
                  onTap: onComingSoon,
                ),
                const Divider(height: 8),
                _sectionLabel(theme, 'Markdown'),
                ListTile(
                  leading: const Icon(LucideIcons.copy, size: 20),
                  title: const Text('复制为 Markdown'),
                  onTap: onCopyMarkdown,
                ),
                ListTile(
                  leading: const Icon(LucideIcons.brain, size: 20),
                  title: const Text('复制 Markdown（含思考）'),
                  onTap: onCopyMarkdownWithReasoning,
                ),
                const Divider(height: 8),
                _sectionLabel(theme, '分享'),
                ListTile(
                  leading: const Icon(LucideIcons.share2, size: 20),
                  title: const Text('分享文本'),
                  onTap: onShareText,
                ),
                ListTile(
                  leading: const Icon(LucideIcons.share2, size: 20),
                  title: const Text('分享 Markdown'),
                  onTap: onShareMarkdown,
                ),
                const Divider(height: 8),
                _sectionLabel(theme, '第三方应用'),
                ListTile(
                  leading: const Icon(LucideIcons.externalLink, size: 20),
                  title: const Text('导出到 Obsidian'),
                  subtitle: const Text('通过 URL Scheme'),
                  onTap: onComingSoon,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
