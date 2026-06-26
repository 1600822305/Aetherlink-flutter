import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';

const Color _addedColor = Color(0xFF22863A);
const Color _removedColor = Color(0xFFCB2431);
const Color _warningColor = Color(0xFFF59E0B);
const Color _successColor = Color(0xFF2E7D32);

/// Best-effort human-readable file name for an opaque SAF `content://` path.
/// Decodes percent-encoding and returns the final path segment.
String fileNameFromPath(String? path) {
  if (path == null || path.isEmpty) return '未命名';
  try {
    final decoded = Uri.decodeComponent(path).replaceAll('\\', '/');
    final segments =
        decoded.split('/').where((s) => s.trim().isNotEmpty).toList();
    if (segments.isEmpty) return path;
    var tail = segments.last;
    final colon = tail.lastIndexOf(':');
    if (colon >= 0 && colon < tail.length - 1) tail = tail.substring(colon + 1);
    return tail;
  } catch (_) {
    return path;
  }
}

/// The card shell for an edit tool: a file header (icon + name + `+N −M` badge
/// + collapse toggle) over an expandable [child] body.
class FileEditorCard extends StatelessWidget {
  const FileEditorCard({
    required this.fileName,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.addedLines,
    this.removedLines,
    super.key,
  });

  final String fileName;
  final String subtitle;
  final IconData icon;
  final MessageBlockStatus status;
  final int? addedLines;
  final int? removedLines;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.5)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              color: headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const Spacer(),
                  _DiffStatsBadge(added: addedLines, removed: removedLines),
                  const SizedBox(width: 6),
                  _StatusIcon(status: status),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: child,
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

/// Compact single-row card for light file ops (rename / move / copy / delete).
class FileEditorOpCard extends StatelessWidget {
  const FileEditorOpCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.status,
    this.pending,
    this.onApprove,
    this.onReject,
    this.errorText,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final MessageBlockStatus status;
  final ToolConfirmationRequest? pending;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pending != null
              ? _warningColor.withValues(alpha: 0.5)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 6),
              _StatusIcon(status: status),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            FileEditorErrorRow(message: errorText!),
          ],
          if (pending != null && onApprove != null && onReject != null) ...[
            const SizedBox(height: 8),
            FileEditorConfirmBar(
              summary: pending!.summary,
              onApprove: onApprove!,
              onReject: onReject!,
            ),
          ],
        ],
      ),
    );
  }
}

/// `+N −M` line-stats pill shown in the file header.
class _DiffStatsBadge extends StatelessWidget {
  const _DiffStatsBadge({this.added, this.removed});

  final int? added;
  final int? removed;

  @override
  Widget build(BuildContext context) {
    final a = added ?? 0;
    final r = removed ?? 0;
    if (a == 0 && r == 0) return const SizedBox.shrink();
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 11);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (a > 0)
          Text('+$a', style: style?.copyWith(color: _addedColor)),
        if (a > 0 && r > 0) const SizedBox(width: 5),
        if (r > 0)
          Text('−$r', style: style?.copyWith(color: _removedColor)),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageBlockStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case MessageBlockStatus.pending:
      case MessageBlockStatus.processing:
      case MessageBlockStatus.streaming:
        return SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        );
      case MessageBlockStatus.error:
        return Icon(LucideIcons.circleAlert, size: 14,
            color: theme.colorScheme.error);
      case MessageBlockStatus.success:
        return const Icon(LucideIcons.circleCheck, size: 14,
            color: _successColor);
      case MessageBlockStatus.paused:
        return Icon(LucideIcons.circlePause, size: 14,
            color: theme.colorScheme.onSurfaceVariant);
    }
  }
}

/// Inline confirm/reject bar for a pending HITL request.
class FileEditorConfirmBar extends StatelessWidget {
  const FileEditorConfirmBar({
    required this.summary,
    required this.onApprove,
    required this.onReject,
    super.key,
  });

  final String summary;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _warningColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldAlert, size: 15,
                  color: _warningColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ConfirmButton(
                label: '拒绝',
                color: theme.colorScheme.onSurfaceVariant,
                filled: false,
                onTap: onReject,
              ),
              const SizedBox(width: 8),
              _ConfirmButton(
                label: '确认执行',
                color: _warningColor,
                filled: true,
                onTap: onApprove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: filled ? color : color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

/// Spinner + label shown while a tool is executing.
class FileEditorProcessingRow extends StatelessWidget {
  const FileEditorProcessingRow({this.label = '执行中...', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Red error row shown when a tool failed, with an optional highlighted
/// [suggestion] (e.g. "改用 create_file 新建") rendered as an amber call-out.
class FileEditorErrorRow extends StatelessWidget {
  const FileEditorErrorRow({required this.message, this.suggestion, super.key});

  final String message;
  final String? suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.circleAlert, size: 13,
                  color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (suggestion != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _warningColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.lightbulb, size: 13, color: _warningColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    suggestion!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Small muted hint line (e.g. "在第 N 行插入").
class FileEditorHint extends StatelessWidget {
  const FileEditorHint({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Placeholder shown when there's nothing to diff.
class FileEditorEmptyBody extends StatelessWidget {
  const FileEditorEmptyBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        '（无内容变更）',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
