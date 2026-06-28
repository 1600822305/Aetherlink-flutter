import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_ui.dart';

/// Terminal-style card for the `@aether/file-editor` `run_command` tool.
///
/// The header shows the executed command in monospace plus a status badge
/// (退出码 / 超时); expanding reveals the working directory and the captured
/// stdout / stderr in dark mono boxes. Mirrors [FileEditorReadBlockView]'s card
/// chrome so it sits naturally beside the other file-editor tool renderers.
class RunCommandBlockView extends StatefulWidget {
  const RunCommandBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  State<RunCommandBlockView> createState() => _RunCommandBlockViewState();
}

class _RunCommandBlockViewState extends State<RunCommandBlockView> {
  bool _expanded = false;

  ToolBlock get block => widget.block;
  Map<String, Object?> get _args => block.arguments ?? const {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = block.status;
    final isProcessing = status == MessageBlockStatus.pending ||
        status == MessageBlockStatus.processing ||
        status == MessageBlockStatus.streaming;
    final hasError = status == MessageBlockStatus.error;
    final data = _data();

    final command = (data?['command'] ?? _args['command'])?.toString() ?? '';
    final body = (!isProcessing && !hasError && data != null)
        ? _body(context, data)
        : null;
    final canExpand = body != null;

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
            onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (isProcessing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      hasError ? LucideIcons.circleAlert : LucideIcons.squareTerminal,
                      size: 15,
                      color: hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: isProcessing
                        ? Text(
                            command.isEmpty ? '执行命令中...' : '执行中：$command',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          )
                        : _commandText(theme, command, hasError),
                  ),
                  if (!isProcessing && !hasError && data != null) ...[
                    const SizedBox(width: 8),
                    _StatusBadge(data: data),
                  ],
                  if (canExpand)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: FileEditorErrorRow(message: _error() ?? '命令执行失败'),
            ),
          if (canExpand)
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: body,
              ),
              crossFadeState:
                  _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
        ],
      ),
    );
  }

  /// The `$ command` header line in monospace.
  Widget _commandText(ThemeData theme, String command, bool hasError) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '\$ ',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
          TextSpan(text: command),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['monospace'],
        color: hasError ? theme.colorScheme.error : null,
      ),
    );
  }

  // ----- body -----

  Widget _body(BuildContext context, Map<String, Object?> data) {
    final theme = Theme.of(context);
    final cwd = data['cwd']?.toString();
    final workspace = data['workspace']?.toString();
    final stdout = data['stdout']?.toString() ?? '';
    final stderr = data['stderr']?.toString() ?? '';
    final hasOutput = stdout.trim().isNotEmpty || stderr.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (workspace != null && workspace.isNotEmpty)
            _MetaRow(label: '工作区', value: workspace),
          if (cwd != null && cwd.isNotEmpty) _MetaRow(label: '目录', value: cwd),
          if (workspace != null || cwd != null) const SizedBox(height: 8),
          if (stdout.trim().isNotEmpty) ...[
            _OutputSection(label: 'stdout', text: stdout),
          ],
          if (stderr.trim().isNotEmpty) ...[
            if (stdout.trim().isNotEmpty) const SizedBox(height: 8),
            _OutputSection(label: 'stderr', text: stderr, isError: true),
          ],
          if (!hasOutput)
            Text(
              '（无输出）',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  // ----- result parsing -----

  Map<String, Object?>? _data() {
    final content = block.content;
    if (content is! String || content.isEmpty) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map) return data.cast<String, Object?>();
      }
    } catch (_) {}
    return null;
  }

  String? _error() {
    final content = block.content;
    if (content is String && content.isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map && decoded['error'] != null) {
          return decoded['error'].toString();
        }
      } catch (_) {}
    }
    final blockErr = block.error;
    if (blockErr != null && blockErr['message'] is String) {
      return blockErr['message'] as String;
    }
    return null;
  }
}

/// Exit-code / timeout pill shown in the header.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timedOut = data['timedOut'] == true;
    final exitCode = data['exitCode'];
    final code = exitCode is num ? exitCode.toInt() : null;

    final (Color color, IconData icon, String label) = timedOut
        ? (const Color(0xFFE8841A), LucideIcons.clock, '超时')
        : code == 0
            ? (const Color(0xFF2E9E5B), LucideIcons.check, '0')
            : (theme.colorScheme.error, LucideIcons.x, '退出码 ${code ?? '?'}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// A muted `label: value` meta line (workspace / cwd).
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.labelSmall?.copyWith(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['monospace'],
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled, height-capped, scrollable monospace output box (stdout / stderr).
class _OutputSection extends StatelessWidget {
  const _OutputSection({
    required this.label,
    required this.text,
    this.isError = false,
  });

  final String label;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text.trimRight(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['monospace'],
                fontSize: 12,
                height: 1.5,
                color: isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
