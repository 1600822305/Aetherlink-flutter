import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 右页：工作台（UI 稿 §4.3）——顶部小 tab 切换
/// 「终端 / AI 正在看的文件 / 改动 diff」。UI 先行阶段三个 tab 均为占位；
/// 接真实现时：终端复用工作区终端会话视图、文件跟随复用编辑器只读态、
/// diff 复用 Git 只读 diff 组件。
class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({required this.task, super.key});

  final AgentTask task;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  int _tab = 0;

  static const _tabs = [
    (LucideIcons.terminal, '终端'),
    (LucideIcons.eye, '正在看的文件'),
    (LucideIcons.gitCompareArrows, '改动 diff'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: i == _tab
                        ? cs.primary.withValues(alpha: 0.12)
                        : cs.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => setState(() => _tab = i),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _tabs[i].$1,
                              size: 14,
                              color: i == _tab
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _tabs[i].$2,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: i == _tab
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.7),
                                fontWeight:
                                    i == _tab ? FontWeight.w700 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _Placeholder(
            icon: _tabs[_tab].$1,
            label: switch (_tab) {
              0 => '终端实况\n（接真实现时复用工作区终端会话视图）',
              1 => 'AI 正在看的文件\n（跟随 read_file 实时定位，复用编辑器只读态）',
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
