import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:aetherlink_flutter/app/di/notion_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_export_service.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_export/export_image_renderer.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_export/export_sheet_chips.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Shows the export/share bottom sheet for one or more messages.
///
/// Port of Kelivo's `_ExportSheet` / `showChatExportSheet`: three export
/// formats (Markdown / TXT / Image) plus two boolean switches (include
/// thinking & tool blocks / expand thinking content). The sheet is compact,
/// has a safe area at the bottom, and replaces the previous verbose
/// `_ExportSheet` that lived inside `message_toolbar.dart`.
Future<void> showMessageExportSheet(
  BuildContext context, {
  required List<ChatMessageView> messages,
  String? topicTitle,
  bool showThinkingAndTools = false,
  bool expandThinking = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ExportSheet(
      messages: messages,
      topicTitle: topicTitle,
      showThinkingAndTools: showThinkingAndTools,
      expandThinking: expandThinking,
    ),
  );
}

/// Exports [messages] in [format] directly — no sheet — honouring the
/// 思考和工具/展开思考 toggles. Debate flow notices are always filtered, like
/// the sheet's default. Used by the multi-select bottom bar's format buttons.
Future<void> exportMessagesAs(
  BuildContext context, {
  required MessageExportFormat format,
  required List<ChatMessageView> messages,
  String? topicTitle,
  bool showThinkingAndTools = false,
  bool expandThinking = false,
}) async {
  final msgs = [
    for (final m in messages)
      if (m.debatePhase != 'notice') m,
  ];
  if (msgs.isEmpty) {
    AppToast.info(context, '没有可导出的内容');
    return;
  }
  try {
    switch (format) {
      case MessageExportFormat.txt:
        final content = buildTxtForExport(
          msgs,
          topicTitle: topicTitle,
          showThinkingAndTools: showThinkingAndTools,
          expandThinking: expandThinking,
        );
        final saved = await saveExportTextFile(
          content,
          'chat-export-${DateTime.now().millisecondsSinceEpoch}.txt',
          ['txt'],
        );
        if (saved && context.mounted) AppToast.info(context, '已导出');
      case MessageExportFormat.markdown:
        final content = buildMarkdownForExport(
          msgs,
          topicTitle: topicTitle,
          showThinkingAndTools: showThinkingAndTools,
          expandThinking: expandThinking,
        );
        final saved = await saveExportTextFile(
          content,
          'chat-export-${DateTime.now().millisecondsSinceEpoch}.md',
          ['md'],
        );
        if (saved && context.mounted) AppToast.info(context, '已导出');
      case MessageExportFormat.image:
        final file = await renderMessagesAsImage(
          context,
          messages: msgs,
          topicTitle: topicTitle,
          showThinking: showThinkingAndTools && expandThinking,
          showTools: showThinkingAndTools,
        );
        if (file == null) {
          if (context.mounted) AppToast.info(context, '渲染图片失败');
          return;
        }
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    }
  } catch (e) {
    if (context.mounted) AppToast.info(context, '导出失败: $e');
  }
}

// ---------------------------------------------------------------------------
// Export sheet widget
// ---------------------------------------------------------------------------

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet({
    required this.messages,
    this.topicTitle,
    this.showThinkingAndTools = false,
    this.expandThinking = false,
  });

  final List<ChatMessageView> messages;
  final String? topicTitle;
  final bool showThinkingAndTools;
  final bool expandThinking;

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  late bool _showThinkingAndTools = widget.showThinkingAndTools;
  late bool _expandThinking =
      widget.showThinkingAndTools && widget.expandThinking;
  bool _includeDebateNotices = false;
  bool _exporting = false;

  bool get _isSingle => widget.messages.length == 1;

  bool get _hasDebateNotices =>
      widget.messages.any((m) => m.debatePhase == 'notice');

  /// 实际参与导出的消息：辩论流程通告（开场/结束/错误提示）默认过滤，
  /// 发言、总结与裁决卡片保留。
  List<ChatMessageView> get _exportMessages => _includeDebateNotices
      ? widget.messages
      : [
          for (final m in widget.messages)
            if (m.debatePhase != 'notice') m,
        ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = _isSingle ? '导出/分享' : '导出 ${widget.messages.length} 条消息';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Export format buttons row (compact, Kelivo-style)
            Row(
              children: [
                Expanded(
                  child: CompactFormatButton(
                    icon: LucideIcons.fileText,
                    label: '纯文本',
                    color: cs.tertiary,
                    onTap: _exporting ? null : _exportTxt,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CompactFormatButton(
                    icon: LucideIcons.bookOpenText,
                    label: 'Markdown',
                    color: cs.primary,
                    onTap: _exporting ? null : _exportMarkdown,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CompactFormatButton(
                    icon: LucideIcons.image,
                    label: '图片',
                    color: cs.secondary,
                    onTap: _exporting ? null : _exportImage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Toggle chips row (thinking & tools)
            Row(
              children: [
                Expanded(
                  child: ToggleChip(
                    icon: LucideIcons.wrench,
                    label: '思考和工具',
                    selected: _showThinkingAndTools,
                    onTap: () => setState(() {
                      _showThinkingAndTools = !_showThinkingAndTools;
                      if (!_showThinkingAndTools) _expandThinking = false;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ToggleChip(
                    icon: LucideIcons.brain,
                    label: '展开思考',
                    selected: _expandThinking,
                    enabled: _showThinkingAndTools,
                    onTap: () {
                      if (!_showThinkingAndTools) return;
                      setState(() => _expandThinking = !_expandThinking);
                    },
                  ),
                ),
              ],
            ),
            if (_hasDebateNotices) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ToggleChip(
                      icon: LucideIcons.megaphone,
                      label: '含辩论流程通告',
                      selected: _includeDebateNotices,
                      onTap: () => setState(
                        () => _includeDebateNotices = !_includeDebateNotices,
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Quick actions row (copy & share)
            Row(
              children: [
                QuickActionChip(
                  icon: LucideIcons.copy,
                  label: '复制文本',
                  onTap: () => _copyContent(asMarkdown: false),
                ),
                const SizedBox(width: 8),
                QuickActionChip(
                  icon: LucideIcons.copy,
                  label: '复制 MD',
                  onTap: () => _copyContent(asMarkdown: true),
                ),
                const SizedBox(width: 8),
                QuickActionChip(
                  icon: LucideIcons.share2,
                  label: '分享',
                  onTap: _shareText,
                ),
                if (ref.watch(
                  notionSettingsProvider.select((s) => s.isConfigured),
                )) ...[
                  const SizedBox(width: 8),
                  QuickActionChip(
                    icon: LucideIcons.databaseZap,
                    label: 'Notion',
                    onTap: _exportToNotion,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Content builders
  // ---------------------------------------------------------------------------

  String _buildMarkdown() => buildMarkdownForExport(
    _exportMessages,
    topicTitle: widget.topicTitle,
    showThinkingAndTools: _showThinkingAndTools,
    expandThinking: _expandThinking,
  );

  String _buildTxt() => buildTxtForExport(
    _exportMessages,
    topicTitle: widget.topicTitle,
    showThinkingAndTools: _showThinkingAndTools,
    expandThinking: _expandThinking,
  );

  // ---------------------------------------------------------------------------
  // Export actions
  // ---------------------------------------------------------------------------

  Future<void> _exportMarkdown() async {
    setState(() => _exporting = true);
    try {
      final content = _buildMarkdown();
      final filename =
          'chat-export-${DateTime.now().millisecondsSinceEpoch}.md';
      await _saveFile(content, filename, ['md']);
    } catch (e) {
      _toast('导出失败: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportTxt() async {
    setState(() => _exporting = true);
    try {
      final content = _buildTxt();
      final filename =
          'chat-export-${DateTime.now().millisecondsSinceEpoch}.txt';
      await _saveFile(content, filename, ['txt']);
    } catch (e) {
      _toast('导出失败: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportImage() async {
    setState(() => _exporting = true);
    try {
      final file = await renderMessagesAsImage(
        context,
        messages: _exportMessages,
        topicTitle: widget.topicTitle,
        showThinking: _showThinkingAndTools && _expandThinking,
        showTools: _showThinkingAndTools,
      );
      if (file == null) {
        _toast('渲染图片失败');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      // Show share/save options for the image
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      _toast('导出图片失败: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _copyContent({required bool asMarkdown}) async {
    final content = asMarkdown ? _buildMarkdown() : _buildTxt();
    if (content.trim().isEmpty) {
      _toast('没有可复制的内容');
      return;
    }
    await Clipboard.setData(ClipboardData(text: content.trim()));
    if (mounted) {
      Navigator.of(context).pop();
      _toast(asMarkdown ? '已复制 Markdown' : '已复制文本');
    }
  }

  Future<void> _shareText() async {
    final content = _buildTxt().trim();
    if (content.isEmpty) {
      _toast('没有可分享的内容');
      return;
    }
    if (mounted) Navigator.of(context).pop();
    try {
      await SharePlus.instance.share(ShareParams(text: content));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: content));
      _toast('已复制到剪贴板');
    }
  }

  Future<void> _exportToNotion() async {
    if (_exporting) return;
    final content = _buildMarkdown().trim();
    if (content.isEmpty) {
      _toast('没有可导出的内容');
      return;
    }
    setState(() => _exporting = true);
    try {
      final settings = ref.read(notionSettingsProvider);
      final title = widget.topicTitle?.trim();
      await ref
          .read(notionExportServiceProvider)
          .exportMarkdown(
            settings: settings,
            title: title == null || title.isEmpty ? '对话导出' : title,
            markdown: content,
            date: DateTime.now(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        _toast('已导出到 Notion');
      }
    } catch (e) {
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // File save helper
  // ---------------------------------------------------------------------------

  Future<void> _saveFile(
    String content,
    String filename,
    List<String> extensions,
  ) async {
    final saved = await saveExportTextFile(content, filename, extensions);
    if (!saved || !mounted) return;
    Navigator.of(context).pop();
    _toast('已导出');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _toast(String message) {
    if (!mounted) return;
    AppToast.info(context, message);
  }
}
