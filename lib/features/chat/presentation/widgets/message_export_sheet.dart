import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

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
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ExportSheet(messages: messages, topicTitle: topicTitle),
  );
}

// ---------------------------------------------------------------------------
// Export sheet widget
// ---------------------------------------------------------------------------

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.messages, this.topicTitle});

  final List<ChatMessageView> messages;
  final String? topicTitle;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _showThinkingAndTools = false;
  bool _expandThinking = false;
  bool _exporting = false;

  bool get _isSingle => widget.messages.length == 1;

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
                  child: _CompactFormatButton(
                    icon: LucideIcons.fileText,
                    label: '纯文本',
                    color: cs.tertiary,
                    onTap: _exporting ? null : _exportTxt,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactFormatButton(
                    icon: LucideIcons.bookOpenText,
                    label: 'Markdown',
                    color: cs.primary,
                    onTap: _exporting ? null : _exportMarkdown,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactFormatButton(
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
                  child: _ToggleChip(
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
                  child: _ToggleChip(
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
            const SizedBox(height: 8),
            // Quick actions row (copy & share)
            Row(
              children: [
                _QuickActionChip(
                  icon: LucideIcons.copy,
                  label: '复制文本',
                  onTap: () => _copyContent(asMarkdown: false),
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  icon: LucideIcons.copy,
                  label: '复制 MD',
                  onTap: () => _copyContent(asMarkdown: true),
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  icon: LucideIcons.share2,
                  label: '分享',
                  onTap: _shareText,
                ),
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

  String _buildMarkdown() {
    final buf = StringBuffer();
    final title = widget.topicTitle?.trim();
    if (title != null && title.isNotEmpty) {
      buf.writeln('# $title\n');
    }
    for (final msg in widget.messages) {
      final isUser = msg.role == MessageRole.user;
      final roleName = isUser ? '用户' : (msg.modelName ?? 'AI助手');
      final time = _formatTimeFull(msg.createdAt);
      buf.writeln('> $time · $roleName\n');

      if (_showThinkingAndTools && _expandThinking && msg.thinking.isNotEmpty) {
        buf.writeln('**思考过程**\n');
        buf.writeln('```text');
        buf.writeln(msg.thinking.trim());
        buf.writeln('```\n');
      }

      if (_showThinkingAndTools) {
        for (final block in msg.blocks) {
          if (block is ToolBlock) {
            final name = block.toolName ?? block.toolId;
            final failed = block.status == MessageBlockStatus.error;
            buf.writeln('> 🔧 **$name** → ${failed ? "错误" : "完成"}\n');
          }
        }
      }

      if (msg.text.trim().isNotEmpty) {
        buf.writeln(msg.text.trim());
        buf.writeln();
      }
      buf.writeln('---\n');
    }
    return buf.toString();
  }

  String _buildTxt() {
    final buf = StringBuffer();
    final title = widget.topicTitle?.trim();
    if (title != null && title.isNotEmpty) {
      buf.writeln('$title\n');
    }
    for (final msg in widget.messages) {
      final isUser = msg.role == MessageRole.user;
      final roleName = isUser ? '用户' : (msg.modelName ?? 'AI助手');
      final time = _formatTimeFull(msg.createdAt);
      buf.writeln('$time · $roleName\n');

      if (_showThinkingAndTools && _expandThinking && msg.thinking.isNotEmpty) {
        buf.writeln('[思考过程]');
        buf.writeln(msg.thinking.trim());
        buf.writeln();
      }

      if (_showThinkingAndTools) {
        for (final block in msg.blocks) {
          if (block is ToolBlock) {
            final name = block.toolName ?? block.toolId;
            final failed = block.status == MessageBlockStatus.error;
            buf.writeln('[工具] $name → ${failed ? "错误" : "完成"}');
          }
        }
      }

      if (msg.text.trim().isNotEmpty) {
        buf.writeln(msg.text.trim());
        buf.writeln();
      }
      buf.writeln('---\n');
    }
    return buf.toString();
  }

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
      final file = await _renderMessagesAsImage(
        context,
        messages: widget.messages,
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

  // ---------------------------------------------------------------------------
  // File save helper
  // ---------------------------------------------------------------------------

  Future<void> _saveFile(
    String content,
    String filename,
    List<String> extensions,
  ) async {
    final bytes = utf8.encode(content);
    final path = await FilePicker.saveFile(
      dialogTitle: '导出文件',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: extensions,
      bytes: Uint8List.fromList(bytes),
    );
    if (path == null) return; // user cancelled
    // On desktop, FilePicker.saveFile doesn't write bytes — write manually.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await File(path).writeAsString(content);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    _toast('已导出');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  static String _formatTimeFull(DateTime? time) {
    if (time == null) return '';
    final t = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}

// ---------------------------------------------------------------------------
// Image export: render messages off-screen → capture as PNG
// ---------------------------------------------------------------------------

Future<File?> _renderMessagesAsImage(
  BuildContext context, {
  required List<ChatMessageView> messages,
  String? topicTitle,
  bool showThinking = false,
  bool showTools = false,
}) async {
  final theme = Theme.of(context);
  const double width = 480;
  const double pixelRatio = 3.0;

  final boundaryKey = GlobalKey();

  // Build the widget tree to render
  Widget buildContent() {
    final cs = theme.colorScheme;
    return Container(
      width: width,
      color: cs.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topicTitle != null && topicTitle.trim().isNotEmpty) ...[
            Text(
              topicTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < messages.length; i++) ...[
            _ExportMessageCard(
              message: messages[i],
              showThinking: showThinking,
              showTools: showTools,
            ),
            if (i < messages.length - 1)
              Divider(
                height: 24,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              'AetherLink',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final overlay = Overlay.of(context);
  final completer = Completer<void>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      int frameCount = 0;
      void scheduleCompletion() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          frameCount++;
          if (frameCount < 3) {
            scheduleCompletion();
          } else if (!completer.isCompleted) {
            completer.complete();
          }
        });
      }

      scheduleCompletion();

      return Positioned(
        left: -10000,
        top: -10000,
        child: MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.noScaling),
          child: Theme(
            data: theme,
            child: RepaintBoundary(key: boundaryKey, child: buildContent()),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  try {
    await completer.future.timeout(const Duration(seconds: 5));

    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/chat-export-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  } catch (_) {
    return null;
  } finally {
    entry.remove();
  }
}

/// A single message card for the export image.
class _ExportMessageCard extends StatelessWidget {
  const _ExportMessageCard({
    required this.message,
    required this.showThinking,
    required this.showTools,
  });

  final ChatMessageView message;
  final bool showThinking;
  final bool showTools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUser = message.role == MessageRole.user;
    final roleName = isUser ? '用户' : (message.modelName ?? 'AI助手');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role + time header
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isUser ? cs.primary : cs.secondary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                isUser ? 'U' : 'AI',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              roleName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Thinking
        if (showThinking && message.thinking.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              message.thinking.trim(),
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        // Tool blocks
        if (showTools)
          for (final block in message.blocks)
            if (block is ToolBlock) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.wrench,
                      size: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      block.toolName ?? block.toolId,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
        // Main text
        if (message.text.trim().isNotEmpty)
          Text(
            message.text.trim(),
            style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compact option row
// ---------------------------------------------------------------------------

/// Compact colored format button (Kelivo-style).
class _CompactFormatButton extends StatelessWidget {
  const _CompactFormatButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? color.withValues(alpha: 0.15)
        : color.withValues(alpha: 0.08);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle chip (like Kelivo's selection bar toggle)
// ---------------------------------------------------------------------------

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = !enabled
        ? cs.onSurface.withValues(alpha: 0.3)
        : selected
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.7);
    final bg = selected
        ? cs.primary.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick action chip
// ---------------------------------------------------------------------------

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
