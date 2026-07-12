import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 工具调用详情底部抽屉（UI 稿 §4.1）：完整参数 + 完整输出。
/// 面板固定屏高 2/3；参数区限高、输出区占满余下高度，各自内部滑动。
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

    return FractionallySizedBox(
      heightFactor: 2 / 3,
      child: Column(
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                bottomPad > 0 ? bottomPad : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: '参数',
                    body: event.argsDetail ?? event.argSummary,
                    maxHeight: 140,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _Section(
                      title: '输出',
                      body: (event.resultDetail?.isNotEmpty ?? false)
                          ? event.resultDetail!
                          : (event.resultSummary.isEmpty
                                ? '（暂无输出）'
                                : event.resultSummary),
                      fill: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 内容块：固定高度内部滑动。[fill] 时占满父约束（外层配 Expanded），
/// 否则按 [maxHeight] 限高，内容不足时自适应。
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.fill = false,
    this.maxHeight,
  });

  final String title;
  final String body;
  final bool fill;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Widget box = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: SelectableText(
          body,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.4,
          ),
        ),
      ),
    );
    if (!fill && maxHeight != null) {
      box = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: box,
      );
    }
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
        if (fill) Expanded(child: box) else box,
      ],
    );
  }
}
