import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench_diff_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench_focus_tab.dart';

/// 右页：工作台（UI 稿 §4.3）——顶部小 tab 切换
/// 「终端 / 焦点 / 改动 diff」。焦点已接真（[WorkbenchFocusTab]）：由事件流
/// 驱动，跟随最新工具/思考/叙述活动自动切内容，附最近工具列表；
/// diff 已接真：任务工作区的未提交改动清单 + 复用 Git 只读 diff 组件
/// （[WorkbenchDiffTab]）。终端仍为占位（接真实现时复用工作区终端会话视图）。
class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({required this.task, super.key});

  final AgentTask task;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  late final TabController _tabController =
      TabController(length: _tabs.length, vsync: this)
        ..addListener(() {
          if (_tab != _tabController.index) {
            setState(() => _tab = _tabController.index);
          }
        });

  static const _tabs = [
    (LucideIcons.terminal, '终端'),
    (LucideIcons.eye, '焦点'),
    (LucideIcons.gitCompareArrows, 'diff'),
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
            0 => const _Placeholder(
                icon: LucideIcons.terminal,
                label: '终端实况\n（接真实现时复用工作区终端会话视图）',
              ),
            1 => WorkbenchFocusTab(task: widget.task),
            _ => WorkbenchDiffTab(task: widget.task),
          },
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: muted),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
