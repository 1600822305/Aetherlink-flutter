import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_ui.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/running_commands_service.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';

/// Terminal-style card for the `@aether/file-editor` `run_command` tool.
///
/// The header shows the executed command in monospace plus a status badge
/// (退出码 / 超时); expanding reveals the working directory and the captured
/// stdout / stderr in dark mono boxes. `run_command` is a high-risk tool, so a
/// pending HITL request renders the inline 确认/拒绝 bar (mirrors the write-tool
/// cards). Sits naturally beside the other file-editor tool renderers.
class RunCommandBlockView extends ConsumerStatefulWidget {
  const RunCommandBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  ConsumerState<RunCommandBlockView> createState() =>
      _RunCommandBlockViewState();
}

class _RunCommandBlockViewState extends ConsumerState<RunCommandBlockView> {
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

    // High-risk HITL gate: while awaiting approval the block carries the
    // `needsConfirmation` flag and a pending request keyed by its id.
    final needsConfirmation =
        block.metadata?['needsConfirmation'] == true && isProcessing;
    final pending = needsConfirmation
        ? ref.watch(toolConfirmationProvider)[block.id]
        : null;

    // The command is mid-flight (post-approval) and can be interrupted.
    final isRunning = isProcessing &&
        pending == null &&
        ref.watch(runningCommandsProvider).contains(block.id);

    // 运行中的实时输出尾部（命令结束后改读结果 JSON 里的最终输出）。
    final liveText = isRunning
        ? ref.watch(
            commandLiveOutputProvider.select((m) => m[block.id] ?? ''),
          )
        : '';

    final command = (data?['command'] ?? _args['command'])?.toString() ?? '';
    final body = (!isProcessing && !hasError && data != null)
        ? _body(context, data)
        : null;
    final canExpand = body != null;

    final warning = pending != null;
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
            onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
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
                              : LucideIcons.squareTerminal,
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
                            command.isEmpty ? '执行命令中...' : '执行中：$command',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          )
                        : _commandText(theme, command, hasError),
                  ),
                  if (!isProcessing && !hasError && data != null) ...[
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

  void _respond(
    ToolConfirmationRequest req,
    bool approved, {
    ConfirmationGrace grace = ConfirmationGrace.none,
  }) {
    ref
        .read(toolConfirmationProvider.notifier)
        .respond(req.id, approved: approved, grace: grace);
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
    final sessionId = data['sessionId']?.toString();
    final stdout = data['stdout']?.toString() ?? '';
    final stderr = data['stderr']?.toString() ?? '';
    final hasOutput = stdout.trim().isNotEmpty || stderr.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (workspace != null && workspace.isNotEmpty)
            CommandMetaRow(label: '工作区', value: workspace),
          if (cwd != null && cwd.isNotEmpty)
            CommandMetaRow(label: '目录', value: cwd),
          if (sessionId != null && sessionId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: OpenInTerminalButton(sessionId: sessionId),
            ),
          if (workspace != null || cwd != null) const SizedBox(height: 8),
          if (stdout.trim().isNotEmpty) ...[
            CommandOutputSection(label: 'stdout', text: stdout),
          ],
          if (stderr.trim().isNotEmpty) ...[
            if (stdout.trim().isNotEmpty) const SizedBox(height: 8),
            CommandOutputSection(label: 'stderr', text: stderr, isError: true),
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

/// 「在终端中查看」：跳到工作区终端页并打开对应的 AI 会话 tab，
/// 实时围观 / 接管该长驻会话。终端系列工具卡片共用。
class OpenInTerminalButton extends ConsumerWidget {
  const OpenInTerminalButton({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return GestureDetector(
      onTap: () {
        ref.read(terminalFocusSessionProvider.notifier).request(sessionId);
        context.push(AppRouter.workspacePath);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.terminal, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              '在终端中查看',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact 中断 pill shown in the header while the command is running.
/// Shared with the terminal session card (terminal_session_exec).
class CommandInterruptButton extends StatelessWidget {
  const CommandInterruptButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.square, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              '中断',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Exit-code / timeout pill shown in the header. Shared with the terminal
/// session card, which reports the same exitCode/timedOut/canceled fields.
class CommandStatusBadge extends StatelessWidget {
  const CommandStatusBadge({required this.data, super.key});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canceled = data['canceled'] == true;
    final timedOut = data['timedOut'] == true;
    final exitCode = data['exitCode'];
    final code = exitCode is num ? exitCode.toInt() : null;

    final (Color color, IconData icon, String label) = canceled
        ? (const Color(0xFFE8841A), LucideIcons.circleSlash, '已中断')
        : timedOut
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

/// A muted `label: value` meta line (workspace / cwd / session).
class CommandMetaRow extends StatelessWidget {
  const CommandMetaRow({required this.label, required this.value, super.key});

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

/// 命令运行期间的实时输出框：高度封顶、反向滚动自动跟随尾部。与终端
/// 会话卡片共用（两者都通过 commandLiveOutputProvider 拿实时输出）。
class CommandLiveOutputBox extends StatelessWidget {
  const CommandLiveOutputBox({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 180),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
      ),
      // reverse 滚动默认钉在底部，新输出到来时自动跟随尾部。
      child: SingleChildScrollView(
        reverse: true,
        child: SelectableText(
          text.trimRight(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: const ['monospace'],
            fontSize: 12,
            height: 1.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// A labelled, height-capped, scrollable monospace output box (stdout / stderr).
class CommandOutputSection extends StatelessWidget {
  const CommandOutputSection({
    required this.label,
    required this.text,
    this.isError = false,
    super.key,
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
