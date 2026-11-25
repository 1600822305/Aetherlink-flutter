import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/event_stream_page.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_page.dart';
import 'package:aetherlink_flutter/shared/widgets/keep_alive_page.dart';
import 'package:aetherlink_flutter/shared/widgets/page_swipe_lock.dart';

/// 任务工作台两页横滑壳（已拍板 2 页，工作区页同款 `PageView` 交互）：
/// 左页=事件流（主视图，默认落这）、右页=工作台（UI 稿 §四）。
/// [topBar]（聊天顶栏）归事件流页所有，随整屏横滑；工作台页只有
/// 自己的精简顶栏，不再叠两层顶栏浪费竖向空间。
class AgentTaskShell extends StatefulWidget {
  const AgentTaskShell({required this.task, this.topBar, super.key});

  final AgentTask task;

  /// 事件流页顶部的聊天顶栏（AppBar）；为 null 时不渲染。
  final PreferredSizeWidget? topBar;

  @override
  State<AgentTaskShell> createState() => _AgentTaskShellState();
}

class _AgentTaskShellState extends State<AgentTaskShell> {
  final PageController _controller = PageController();

  /// 终端拖选等子组件临时禁滑用（见 PageSwipeLock）。
  final PageSwipeLock _swipeLock = PageSwipeLock();

  /// 只驱动底部页指示器；不用 setState，避免翻页过半时整页重建两侧子树。
  final ValueNotifier<int> _page = ValueNotifier(0);

  @override
  void didUpdateWidget(covariant AgentTaskShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final switchedTask = widget.task.id != oldWidget.task.id;
    final startedWaiting =
        widget.task.status == AgentTaskStatus.waitingInput &&
        oldWidget.task.status != AgentTaskStatus.waitingInput;
    if (switchedTask || startedWaiting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.animateToPage(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        _page.value = 0;
      });
    }
  }

  void _backToChat() {
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _swipeLock.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          // 终端拖选期间禁滑（只在手指按着时，见 TerminalSelectionPageLock）。
          child: PageSwipeLockScope(
            lock: _swipeLock,
            child: ListenableBuilder(
            listenable: _swipeLock,
            builder: (context, _) {
              return PageView(
                controller: _controller,
                physics: _swipeLock.locked
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (i) => _page.value = i,
                // 两页都保活：PageView 默认销毁滑出视口的页，下次滑入要在
                // 拖动途中整页重建（事件流列表 / 终端挂接 / diff 加载）。
                children: [
                  KeepAlivePage(
                    child: Column(
                      children: [
                        if (widget.topBar != null) widget.topBar!,
                        Expanded(child: EventStreamPage(task: widget.task)),
                      ],
                    ),
                  ),
                  KeepAlivePage(
                    child: WorkbenchPage(
                      task: widget.task,
                      onBackToChat: _backToChat,
                    ),
                  ),
                ],
              );
            },
          ),
          ),
        ),
        // 页指示器（工作区页同款的两点样式）。
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ValueListenableBuilder<int>(
            valueListenable: _page,
            builder: (context, page, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
