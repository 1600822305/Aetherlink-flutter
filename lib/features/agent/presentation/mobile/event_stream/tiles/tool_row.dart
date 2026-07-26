import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tool_detail_sheet.dart';

/// 工具行（collapsed 单行）：图标+名称+关键参数+结果摘要；
/// 点击 → 底部抽屉看完整参数/输出。
class ToolRow extends StatelessWidget {
  const ToolRow({required this.event, required this.taskId, super.key});

  final ToolCallEvent event;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final (icon, iconColor) = switch (event.state) {
      AgentToolCallState.running => (LucideIcons.loaderCircle, cs.primary),
      AgentToolCallState.success => (LucideIcons.circleCheck, Colors.green),
      AgentToolCallState.failure => (LucideIcons.circleX, cs.error),
      AgentToolCallState.denied => (LucideIcons.ban, muted),
      AgentToolCallState.waitingApproval => (
        LucideIcons.circleAlert,
        Colors.orange,
      ),
    };
    return EventRail(
      node: event.state == AgentToolCallState.running
          ? SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            )
          : Icon(icon, size: 14, color: iconColor),
      child: InkWell(
        onTap: () => showToolDetailSheet(context, event, taskId: taskId),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    event.toolName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.argSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
              if (event.resultSummary.isNotEmpty)
                Text(
                  '↳ ${event.resultSummary}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: event.state == AgentToolCallState.failure
                        ? cs.error
                        : muted,
                  ),
                ),
              // 自动检测漏网时的手动兜底：用户看到命令在等交互输入，
              // 点一下让正在等结果的 exec 提前把控制权和已有输出还给模型。
              if (event.state == AgentToolCallState.running &&
                  event.toolName == 'terminal_execute')
                _WaitingInputButton(argsDetail: event.argsDetail),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「在等交互输入」手动标记按钮：把本次调用目标会话（能从参数里解析出
/// session 时）或所有正在等命令结果的会话标记为等交互，对应 exec 带
/// 已有输出提前返回，模型随即可写 stdin 回答。
class _WaitingInputButton extends ConsumerWidget {
  const _WaitingInputButton({this.argsDetail});

  /// 工具调用的完整参数 JSON；解析出 session 参数时只标记该会话，
  /// 避免并行任务时把无关的长命令也提前打断。
  final String? argsDetail;

  String? _sessionRef() {
    final raw = argsDetail;
    if (raw == null || raw.isEmpty) return null;
    try {
      final args = jsonDecode(raw);
      if (args is! Map) return null;
      final ref = args['session'] ?? args['session_id'];
      final text = ref?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(LucideIcons.keyboard, size: 13),
        label: Text('在等交互输入？点此告知 AI', style: theme.textTheme.labelSmall),
        onPressed: () {
          final count = ref
              .read(workspaceSessionPoolManagerProvider)
              .markWaitingInputAll(sessionRef: _sessionRef());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(count > 0 ? '已告知 AI：命令在等交互输入' : '当前没有正在等结果的命令'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
