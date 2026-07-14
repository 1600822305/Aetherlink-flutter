import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/plan_panel.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/timeline_blocks.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/agent_event_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/plan_ready_card.dart';
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

  /// 上次键盘 inset，用于换算滚动补偿（与聊天页 bottomReserve 同一机制）。
  double _lastKeyboardInset = 0;

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
    // 用户发送或智能体提问 → 显式回底，确保交互卡立即进入视口。
    ref.listen(agentTaskEventsProvider(widget.task.id), (prev, next) {
      final before = (prev?.value?.whereType<UserMessageEvent>().length ?? 0) +
          (prev?.value?.whereType<UserQuestionEvent>().length ?? 0);
      final after = (next.value?.whereType<UserMessageEvent>().length ?? 0) +
          (next.value?.whereType<UserQuestionEvent>().length ?? 0);
      if (after > before) _autoScroll.pinToBottom();
    });

    // 键盘弹出/收起时 Scaffold 会缩放 body（adjustResize），普通列表锚点在
    // 顶部，视口底部内容会被键盘盖住。这里按 inset 变化量做同帧滚动补偿
    // （聊天页 bottomReserve 同一机制）：整体内容跟着键盘顶起/落下。
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if ((keyboardInset - _lastKeyboardInset).abs() > 0.5) {
      _scrollController.pendingAdjust += keyboardInset - _lastKeyboardInset;
      _lastKeyboardInset = keyboardInset;
    }

    final events =
        ref.watch(agentTaskEventsProvider(widget.task.id)).value ?? const [];
    final plan = latestPlan(events);
    // 工作段折叠由侧边栏设置控制（默认折叠，用户点段头展开）。
    final collapse = ref.watch(
      agentUiSettingsControllerProvider.select(
        (s) => s.autoCollapseWorkSessions,
      ),
    );
    final blocks = buildTimelineBlocks(events, collapse: collapse);
    final showWorking = widget.task.status == AgentTaskStatus.running &&
        needsWorkingIndicator(events);
    // Plan 模式收尾（方案已出完）→ 事件流末尾出「方案已就绪」卡，
    // 一键转 Code 继续执行（设计初稿 §七）。
    final showPlanReady = widget.task.mode == AgentSessionMode.plan &&
        widget.task.status == AgentTaskStatus.done;
    final trailing = (showWorking ? 1 : 0) + (showPlanReady ? 1 : 0);

    return Column(
      children: [
        if (plan != null) PlanPanel(task: widget.task, plan: plan),
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
                  itemCount: blocks.length + trailing,
                  itemBuilder: (context, i) => i >= blocks.length
                      ? (showPlanReady
                          ? PlanReadyCard(task: widget.task)
                          : const WorkingIndicatorTile())
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
