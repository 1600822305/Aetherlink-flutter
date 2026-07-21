import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench_diff_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench_files_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench_focus_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench_terminal_tab.dart';

/// 右页：工作台（UI 稿 §4.3）——顶部小 tab 切换
/// 「终端 / 焦点 / 改动 diff / 文件」：终端实时围观任务工作区
/// 的 AI 会话（[WorkbenchTerminalTab]）；焦点由事件流驱动，跟随最新
/// 工具/思考/叙述活动自动切内容，附最近工具列表（[WorkbenchFocusTab]）；
/// diff 为任务工作区的未提交改动清单 + 复用 Git 只读 diff 组件
/// （[WorkbenchDiffTab]）。
class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({required this.task, super.key});

  final AgentTask task;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage>
    with SingleTickerProviderStateMixin {
  /// 各任务上次选中的 tab（内存级记忆：切回聊天再进工作台不丢选中态）。
  static final Map<String, int> _lastTabByTask = {};

  late int _tab = _lastTabByTask[widget.task.id] ?? 0;

  late final TabController _tabController = TabController(
    length: _tabs.length,
    initialIndex: _tab,
    vsync: this,
  )..addListener(() {
      if (_tab != _tabController.index) {
        setState(() => _tab = _tabController.index);
        _lastTabByTask[widget.task.id] = _tabController.index;
      }
    });

  static const _tabs = [
    (LucideIcons.terminal, '终端'),
    (LucideIcons.eye, '焦点'),
    (LucideIcons.gitCompareArrows, 'diff'),
    (LucideIcons.fileText, '文件'),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        // 项目统一的分段式 tab 条（浅底胶囊 + 白底浮起指示器，
        // 与侧边栏/聊天侧边栏同款）。
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            labelColor: cs.onSurface,
            unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.08),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            labelPadding: EdgeInsets.zero,
            tabs: [
              for (final (icon, label) in _tabs)
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14),
                      const SizedBox(width: 4),
                      Text(label),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_tab) {
            0 => WorkbenchTerminalTab(task: widget.task),
            1 => WorkbenchFocusTab(task: widget.task),
            2 => WorkbenchDiffTab(task: widget.task),
            _ => WorkbenchFilesTab(task: widget.task),
          },
        ),
      ],
    );
  }
}

