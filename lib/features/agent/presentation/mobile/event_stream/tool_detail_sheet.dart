import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 工具调用详情底部抽屉（UI 稿 §4.1）：完整参数 + 完整输出。
/// 大输出这里只显截断内容；「查看全文」等落盘能力接真引擎时补。
Future<void> showToolDetailSheet(BuildContext context, ToolCallEvent event) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ToolDetailSheet(event: event),
  );
}

class _ToolDetailSheet extends StatelessWidget {
  const _ToolDetailSheet({required this.event});

  final ToolCallEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final stateLabel = switch (event.state) {
      AgentToolCallState.running => '执行中…',
      AgentToolCallState.success => '成功 ✓',
      AgentToolCallState.failure => '失败 ✗',
      AgentToolCallState.denied => '已拒绝',
      AgentToolCallState.waitingApproval => '等待授权',
    };
    final stateColor = switch (event.state) {
      AgentToolCallState.failure => cs.error,
      AgentToolCallState.success => Colors.green,
      AgentToolCallState.waitingApproval => Colors.orange,
      _ => muted,
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                Icon(LucideIcons.wrench, size: 16, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.toolName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Text(
                  event.elapsed == null
                      ? stateLabel
                      : '$stateLabel · ${event.elapsed!.inMilliseconds < 1000 ? '${event.elapsed!.inMilliseconds}ms' : '${(event.elapsed!.inMilliseconds / 1000).toStringAsFixed(1)}s'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: stateColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                bottomPad > 0 ? bottomPad : 12,
              ),
              children: [
                _Section(
                  title: '参数',
                  body: event.argsDetail ?? event.argSummary,
                ),
                const SizedBox(height: 14),
                _Section(
                  title: '输出',
                  body: (event.resultDetail?.isNotEmpty ?? false)
                      ? event.resultDetail!
                      : (event.resultSummary.isEmpty
                            ? '（暂无输出）'
                            : event.resultSummary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
