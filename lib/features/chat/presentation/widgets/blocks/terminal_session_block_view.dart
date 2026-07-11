import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_ui.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/run_command_block_view.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/running_commands_service.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';

/// Terminal-style card for the `@aether/terminal` session tools
/// (terminal_session_create / list / exec / output / close).
///
/// `terminal_session_exec` mirrors the run_command card: `$ command` header
/// with an exit-code badge, expandable output box, and the inline HITL
/// 确认/拒绝 bar while awaiting approval. The other session tools render as a
/// compact row (新建/关闭/会话列表) with expandable detail where useful.
class TerminalSessionBlockView extends ConsumerStatefulWidget {
  const TerminalSessionBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  ConsumerState<TerminalSessionBlockView> createState() =>
      _TerminalSessionBlockViewState();
}

class _TerminalSessionBlockViewState
    extends ConsumerState<TerminalSessionBlockView> {
  bool _expanded = false;

  ToolBlock get block => widget.block;
  String get _tool => block.toolName ?? '';
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

    final needsConfirmation =
        block.metadata?['needsConfirmation'] == true && isProcessing;
    final pending = needsConfirmation
        ? ref.watch(toolConfirmationProvider)[block.id]
        : null;
    final warning = pending != null;

    // terminal_session_exec 正在执行（已过审批）：可中断（向会话发
    // Ctrl-C），并实时展示输出尾部。
    final isRunning = _tool == 'terminal_session_exec' &&
        isProcessing &&
        pending == null &&
        ref.watch(runningCommandsProvider).contains(block.id);
    final liveText = isRunning
        ? ref.watch(
            commandLiveOutputProvider.select((m) => m[block.id] ?? ''),
          )
        : '';

    final body = (!isProcessing && !hasError && data != null)
        ? _body(context, data)
        : null;
    final canExpand = body != null;

    final borderColor = warning
        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
        : theme.dividerColor;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap:
                canExpand ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (isProcessing && !warning)
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
                      warning
                          ? LucideIcons.shieldAlert
                          : hasError
                              ? LucideIcons.circleAlert
                              : _icon(),
                      size: 15,
                      color: warning
                          ? const Color(0xFFF59E0B)
                          : hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: (isProcessing && !warning)
                        ? Text(
                            _processingLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          )
                        : _headerText(theme, data, hasError),
                  ),
                  if (_tool == 'terminal_session_exec' &&
                      !isProcessing &&
                      !hasError &&
                      data != null) ...[
                    const SizedBox(width: 8),
                    CommandStatusBadge(data: data),
                  ],
                  if (isRunning) ...[
                    const SizedBox(width: 8),
                    CommandInterruptButton(
                      onTap: () => ref
                          .read(runningCommandsProvider.notifier)
                          .cancel(block.id),
                    ),
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
          if (isRunning && liveText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: CommandLiveOutputBox(text: liveText),
            ),
          if (pending != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: FileEditorConfirmBar(
                summary: pending.summary,
                onApprove: (grace) => _respond(pending, true, grace: grace),
                onReject: () => _respond(pending, false),
              ),
            )
          else if (hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: FileEditorErrorRow(message: _error() ?? '终端会话操作失败'),
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
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
        ],
      ),
    );
  }

  void _respond(
    ToolConfirmationRequest req,
    bool approved, {
    ConfirmationGrace grace = ConfirmationGrace.none,
  }) {
    ref
        .read(toolConfirmationProvider.notifier)
        .respond(req.id, approved: approved, grace: grace);
  }

  // ----- header -----

  IconData _icon() => switch (_tool) {
        'terminal_session_create' => LucideIcons.terminal,
        'terminal_session_list' => LucideIcons.list,
        'terminal_session_exec' => LucideIcons.squareTerminal,
        'terminal_session_output' => LucideIcons.scrollText,
        'terminal_session_close' => LucideIcons.squareX,
        _ => LucideIcons.terminal,
      };

  String _processingLabel() => switch (_tool) {
        'terminal_session_create' => '创建会话中...',
        'terminal_session_exec' => '会话执行中...',
        'terminal_session_output' => '读取输出中...',
        'terminal_session_close' => '关闭会话中...',
        _ => '执行中...',
      };

  Widget _headerText(ThemeData theme, Map<String, Object?>? data, bool hasError) {
    if (_tool == 'terminal_session_exec') {
      final command =
          (data?['command'] ?? _args['command'])?.toString() ?? '';
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
    return Text(
      _headerLabel(data),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: hasError ? theme.colorScheme.error : null,
      ),
    );
  }

  String _headerLabel(Map<String, Object?>? data) {
    switch (_tool) {
      case 'terminal_session_create':
        final name = data?['name'] ?? _args['name'] ?? '';
        final workspace = data?['workspace']?.toString();
        final suffix =
            (workspace != null && workspace.isNotEmpty) ? ' · $workspace' : '';
        return '新建会话 $name$suffix';
      case 'terminal_session_list':
        final sessions = data?['sessions'];
        final count = sessions is List ? sessions.length : 0;
        return '终端会话 · $count 个';
      case 'terminal_session_output':
        final id = data?['sessionId'] ?? _args['session_id'] ?? '';
        final busy = data?['busy'] == true ? '（运行中）' : '';
        return '会话输出 · $id$busy';
      case 'terminal_session_close':
        final id = data?['sessionId'] ?? _args['session_id'] ?? '';
        return '关闭会话 $id';
    }
    return _tool;
  }

  // ----- body -----

  Widget? _body(BuildContext context, Map<String, Object?> data) {
    switch (_tool) {
      case 'terminal_session_create':
        return _metaBody([
          ('会话', data['sessionId']?.toString()),
          ('名称', data['name']?.toString()),
          ('工作区', data['workspace']?.toString()),
        ]);
      case 'terminal_session_list':
        return _sessionListBody(data['sessions']);
      case 'terminal_session_exec':
      case 'terminal_session_output':
        return _outputBody(data);
      case 'terminal_session_close':
        return null;
    }
    return null;
  }

  Widget? _metaBody(List<(String, String?)> rows) {
    final visible = [
      for (final (label, value) in rows)
        if (value != null && value.isNotEmpty) (label, value),
    ];
    if (visible.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in visible)
            CommandMetaRow(label: label, value: value),
        ],
      ),
    );
  }

  Widget _sessionListBody(Object? sessions) {
    final theme = Theme.of(context);
    if (sessions is! List || sessions.isEmpty) {
      return const FileEditorEmptyBody();
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in sessions)
            if (s is Map)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      s['busy'] == true
                          ? LucideIcons.loaderCircle
                          : LucideIcons.terminal,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${s['name'] ?? s['sessionId'] ?? ''} · ${s['workspace'] ?? ''}'
                        '${s['busy'] == true ? '（运行中）' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          fontFamilyFallback: const ['monospace'],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _outputBody(Map<String, Object?> data) {
    final theme = Theme.of(context);
    final sessionId = data['sessionId']?.toString();
    final workspace = data['workspace']?.toString();
    final hint = data['hint']?.toString();
    final output = data['output']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sessionId != null && sessionId.isNotEmpty)
            CommandMetaRow(label: '会话', value: sessionId),
          if (workspace != null && workspace.isNotEmpty)
            CommandMetaRow(label: '工作区', value: workspace),
          if (sessionId != null || workspace != null)
            const SizedBox(height: 8),
          if (hint != null && hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                hint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFE8841A),
                ),
              ),
            ),
          if (output.trim().isNotEmpty)
            CommandOutputSection(label: 'output', text: output)
          else
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
