import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 右页：工作台（UI 稿 §4.3）——顶部小 tab 切换
/// 「终端 / 焦点 / 改动 diff」。焦点 = 智能体正在干什么，跟随最新工具
/// 活动自动切内容（读/改文件→文件只读视图定位相关行、跑命令→该命令
/// 实况输出、网搜/知识库→查询与结果摘要、思考→当前步骤说明）。
/// UI 先行阶段三个 tab 均为占位；接真实现时：终端复用工作区终端会话
/// 视图、焦点由最新 ToolCallEvent 驱动、diff 复用 Git 只读 diff 组件。
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
          child: _Placeholder(
            icon: _tabs[_tab].$1,
            label: switch (_tab) {
              0 => '终端实况\n（接真实现时复用工作区终端会话视图）',
              1 =>
                '焦点：智能体正在干什么\n（跟随最新工具活动自动切换：读/改文件、'
                    '跑命令、网搜、思考…）',
              _ => '改动 diff（P1）\n（复用 Git 只读 diff 组件）',
            },
          ),
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
