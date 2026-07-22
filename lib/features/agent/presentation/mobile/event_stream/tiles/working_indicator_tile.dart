import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 等待指示行（Claude Code/Codex 同款）：任务运行中但暂无实况事件
/// （刚发消息等首 token、工具结果回填后等下一轮）时，时间线底部
/// 立即显示呼吸圆点 + "正在思考…"，首个流式事件到达即被真实内容顶替。
/// 有进行中的计划条目时文案改为该条目（对标 CC spinner 用
/// activeForm 驱动动词），一眼看到当前在做哪一步。
class WorkingIndicatorTile extends StatefulWidget {
  const WorkingIndicatorTile({this.label, super.key});

  /// 替代默认"正在思考"的文案（不含省略号）。
  final String? label;

  @override
  State<WorkingIndicatorTile> createState() => _WorkingIndicatorTileState();
}

class _WorkingIndicatorTileState extends State<WorkingIndicatorTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '${widget.label ?? '正在思考'}…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 是否需要显示等待指示：没有任何"实况中"的事件
/// （流式文本/流式思考/执行中或待审批的工具）时为真。
bool needsWorkingIndicator(List<AgentEvent> events) {
  for (final e in events) {
    final live = switch (e) {
      AssistantTextEvent(:final streaming) => streaming,
      ReasoningEvent(:final streaming) => streaming,
      ToolCallEvent(:final state) => state == AgentToolCallState.running ||
          state == AgentToolCallState.waitingApproval,
      _ => false,
    };
    if (live) return false;
  }
  return true;
}
