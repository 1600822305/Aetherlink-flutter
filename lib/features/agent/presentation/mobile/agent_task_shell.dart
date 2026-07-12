import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/event_stream_page.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench_page.dart';

/// 任务工作台两页横滑壳（已拍板 2 页，工作区页同款 `PageView` 交互）：
/// 左页=事件流（主视图，默认落这）、右页=工作台（UI 稿 §四）。
class AgentTaskShell extends StatefulWidget {
  const AgentTaskShell({required this.task, super.key});

  final AgentTask task;

  @override
  State<AgentTaskShell> createState() => _AgentTaskShellState();
}

class _AgentTaskShellState extends State<AgentTaskShell> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              EventStreamPage(task: widget.task),
              WorkbenchPage(task: widget.task),
            ],
          ),
        ),
        // 页指示器（工作区页同款的两点样式）。
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 2; i++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
