import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_terminal_focus.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_context_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_diff_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_files_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_focus_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_terminal_tab.dart';

/// 右页：工作台（UI 稿 §4.3）——顶部小 tab 切换
/// 「终端 / 焦点 / 改动 diff / 文件」：终端实时围观任务工作区
/// 的 AI 会话（[WorkbenchTerminalTab]）；焦点由事件流驱动，跟随最新
/// 工具/思考/叙述活动自动切内容，附最近工具列表（[WorkbenchFocusTab]）；
/// diff 为任务工作区的未提交改动清单 + 复用 Git 只读 diff 组件
/// （[WorkbenchDiffTab]）。
class WorkbenchPage extends ConsumerStatefulWidget {
  const WorkbenchPage({
    required this.task,
    this.onBackToChat,
    this.initialFilePath,
    super.key,
  });

  final AgentTask task;
  final String? initialFilePath;

  /// 顶栏左侧返回键：滑回事件流页（不会横滑的用户的退路）。
  final VoidCallback? onBackToChat;

  @override
  ConsumerState<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends ConsumerState<WorkbenchPage>
    with SingleTickerProviderStateMixin {
  /// 各任务上次选中的 tab（内存级记忆：切回聊天再进工作台不丢选中态）。
  static final Map<String, int> _lastTabByTask = {};

  late int _tab = widget.initialFilePath != null
      ? 2
      : _lastTabByTask[widget.task.id] ?? 0;

  /// 终端 tab 首次进入后常驻（离屏保活），切回时复用已有视图与滚动位置。
  late bool _hasShownTerminal = _tab == 0;

  late final TabController _tabController =
      TabController(length: _tabs.length, initialIndex: _tab, vsync: this)
        ..addListener(() {
          if (_tab != _tabController.index) {
            setState(() {
              _tab = _tabController.index;
              if (_tab == 0) _hasShownTerminal = true;
            });
            _lastTabByTask[widget.task.id] = _tabController.index;
          }
        });

  static const _tabs = [
    (LucideIcons.terminal, '终端'),
    (LucideIcons.eye, '焦点'),
    (LucideIcons.gitCompareArrows, 'diff'),
    (LucideIcons.fileText, '文件'),
    (LucideIcons.chartPie, '上下文'),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 事件流里点「终端」：切到终端 tab（首次进入会创建终端 tab，
    // 由它在 initState 里取走请求选中会话）。
    ref.listen(agentTerminalFocusProvider, (_, next) {
      if (next == null || next.taskId != widget.task.id) return;
      if (_tabController.index != 0) _tabController.animateTo(0);
    });
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        // 工作台页自己的精简顶栏：返回键 + 分段式 tab 条（浅底胶囊 +
        // 白底浮起指示器，与侧边栏/聊天侧边栏同款），随整屏横滑，
        // 不再叠聊天 AppBar。
        SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (widget.onBackToChat != null)
                IconButton(
                  tooltip: '返回聊天',
                  icon: const Icon(LucideIcons.chevronLeft, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onBackToChat,
                ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: widget.onBackToChat == null ? 12 : 0,
                    right: 12,
                    top: 8,
                    bottom: 8,
                  ),
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
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_hasShownTerminal)
                Offstage(
                  offstage: _tab != 0,
                  child: TickerMode(
                    enabled: _tab == 0,
                    child: ExcludeFocus(
                      excluding: _tab != 0,
                      child: WorkbenchTerminalTab(task: widget.task),
                    ),
                  ),
                ),
              if (_tab != 0)
                switch (_tab) {
                  1 => WorkbenchFocusTab(task: widget.task),
                  2 => WorkbenchDiffTab(
                    task: widget.task,
                    initialFilePath: widget.initialFilePath,
                  ),
                  3 => WorkbenchFilesTab(task: widget.task),
                  _ => WorkbenchContextTab(task: widget.task),
                },
            ],
          ),
        ),
      ],
    );
  }
}
