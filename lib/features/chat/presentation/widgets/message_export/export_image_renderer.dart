import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

// ---------------------------------------------------------------------------
// Image export: render messages off-screen → capture as PNG
// ---------------------------------------------------------------------------

Future<File?> renderMessagesAsImage(
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
