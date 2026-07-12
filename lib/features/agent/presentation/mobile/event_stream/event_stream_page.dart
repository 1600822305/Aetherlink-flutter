import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/plan_panel.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/timeline_blocks.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/agent_event_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/work_segment_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/working_indicator_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_input_bar.dart';
import 'package:aetherlink_flutter/shared/widgets/auto_scroll_controller.dart';

/// 左页：事件流主视图（UI 稿 §4.1）——计划纪要条 + 时间线 + 底部输入区。
///
/// 粘底跟随（与聊天页同一套 [AutoScrollController] 状态机）：在底部时新事件
/// 自动跟随（布局期钉底，流式增长零延迟）；用户上滑立即解除跟随；滚回底部
/// 阈值内自动恢复。显式回底意图——进入页面、切换任务、用户发送——走
/// [AutoScrollController.pinToBottom]；解除跟随时右下角浮「回到最新」按钮。
class EventStreamPage extends ConsumerStatefulWidget {
  const EventStreamPage({required this.task, super.key});

  final AgentTask task;

  @override
  ConsumerState<EventStreamPage> createState() => _EventStreamPageState();
}

class _EventStreamPageState extends ConsumerState<EventStreamPage> {
  final AutoFollowScrollController _scrollController =
      AutoFollowScrollController();
  late final AutoScrollController _autoScroll;

  /// 「回到最新」按钮可见性（解除跟随时显示），随滚动通知刷新。
  bool _showJumpToLatest = false;

  /// 「折叠全部过程」：开启后所有已完结工具/思考都收进工作段。
  bool _collapseAll = false;

  @override
  void initState() {
    super.initState();
    _autoScroll = AutoScrollController(
      scrollController: _scrollController,
      isEnabled: () => true,
    );
    // 进入页面钉到底部（最新事件）。
    _autoScroll.pinToBottom();
  }

  @override
  void didUpdateWidget(covariant EventStreamPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.id != oldWidget.task.id) _autoScroll.pinToBottom();
  }

  @override
  void dispose() {
    _autoScroll.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncJumpButton() {
    final show = !_autoScroll.isSticking;
    if (show != _showJumpToLatest) {
      setState(() => _showJumpToLatest = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 用户发送 → 显式回底（事件流里多出新的用户消息）。
    ref.listen(agentTaskEventsProvider(widget.task.id), (prev, next) {
      final before =
          prev?.value?.whereType<UserMessageEvent>().length ?? 0;
      final after = next.value?.whereType<UserMessageEvent>().length ?? 0;
      if (after > before) _autoScroll.pinToBottom();
    });

    final events =
        ref.watch(agentTaskEventsProvider(widget.task.id)).value ?? const [];
    final plan = latestPlan(events);
    final blocks = buildTimelineBlocks(events, collapseAll: _collapseAll);
    final showWorking = widget.task.status == AgentTaskStatus.running &&
        needsWorkingIndicator(events);
    final hasProcess = events.any((e) => e is ToolCallEvent);

    return Column(
      children: [
        if (plan != null) PlanPanel(task: widget.task, plan: plan),
        if (hasProcess)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => setState(() => _collapseAll = !_collapseAll),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  _collapseAll
                      ? Icons.unfold_more_rounded
                      : Icons.unfold_less_rounded,
                  size: 14,
                ),
                label: Text(
                  _collapseAll ? '展开过程' : '折叠全部过程',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _syncJumpButton();
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  itemCount: blocks.length + (showWorking ? 1 : 0),
                  itemBuilder: (context, i) => i >= blocks.length
                      ? const WorkingIndicatorTile()
                      : switch (blocks[i]) {
                          final SegmentBlock b => WorkSegmentTile(
                              block: b,
                              taskId: widget.task.id,
                            ),
                          final SingleBlock b => AgentEventTile(
                              event: b.event,
                              taskId: widget.task.id,
                            ),
                        },
                ),
              ),
              if (_showJumpToLatest)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _JumpToLatestButton(
                    onTap: () {
                      _autoScroll.pinToBottom();
                      _syncJumpButton();
                    },
                  ),
                ),
            ],
          ),
        ),
        AgentInputBar(task: widget.task),
      ],
    );
  }
}

/// 右下角浮动「回到最新」按钮（解除跟随时出现）。
class _JumpToLatestButton extends StatelessWidget {
  const _JumpToLatestButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 2,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
