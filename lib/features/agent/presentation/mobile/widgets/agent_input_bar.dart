import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 底部输入区（UI 稿输入区，已拍板）：
/// 上沿 chips 行 = 模式快切（Code/Ask/Plan）+ 模型选择（复用聊天选择器，
/// UI 阶段先占位）；下行 = ＋附件、输入框、发送/中断变形按钮（§五打断交互）。
class AgentInputBar extends StatefulWidget {
  const AgentInputBar({required this.task, super.key});

  final AgentTask task;

  @override
  State<AgentInputBar> createState() => _AgentInputBarState();
}

class _AgentInputBarState extends State<AgentInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  late AgentSessionMode _mode = widget.task.mode;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 有文字：发送不直接发——弹三选面板（排队/立即打断并发送/继续编辑）。
  Future<void> _onSendPressed() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.listPlus, size: 20),
              title: const Text('排队'),
              subtitle: const Text('不打断当前工具，下一轮生效'),
              onTap: () => Navigator.pop(context, 'queue'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.zap, size: 20),
              title: const Text('立即打断并发送'),
              subtitle: const Text('中止当前工具，模型下一轮先响应这条指令'),
              onTap: () => Navigator.pop(context, 'interrupt'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.pencil, size: 20),
              title: const Text('继续编辑'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
          ],
        ),
      ),
    );
    if (action == 'queue' || action == 'interrupt') {
      _controller.clear();
    }
  }

  /// 无文字：点一下=暂停；长按=强制终止二次确认。
  void _onPausePressed() {}

  Future<void> _onForceStopLongPress() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('强制终止任务？'),
        content: const Text('立即中止当前执行，任务转为已取消，不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('强制终止'),
          ),
        ],
      ),
    );
  }

  Future<void> _onModeTap() async {
    final mode = await showModalBottomSheet<AgentSessionMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (m, desc) in const [
              (AgentSessionMode.code, '执行模式：写/终端全能力，走审批+白名单'),
              (AgentSessionMode.ask, '只问答：仅只读工具，不改任何东西'),
              (AgentSessionMode.plan, '只读规划：先出完整方案，确认后转 Code'),
            ])
              ListTile(
                leading: Icon(
                  m == _mode ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 20,
                ),
                title: Text(agentModeLabel(m)),
                subtitle: Text(desc),
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (mode != null) setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final running = widget.task.status == AgentTaskStatus.running;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Chip(
                  icon: LucideIcons.keyboard,
                  label: '${agentModeLabel(_mode)} ▾',
                  onTap: _onModeTap,
                ),
                const Spacer(),
                _Chip(
                  icon: LucideIcons.brain,
                  label: '${widget.task.modelLabel} ▾',
                  onTap: () {}, // TODO(agent): 复用聊天模型选择器
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {}, // TODO(agent): 附件面板（图片/文件/引用工作区文件）
                  icon: const Icon(LucideIcons.plus, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '追加指令…',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: cs.onSurface.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (_hasText)
                  IconButton.filled(
                    onPressed: _onSendPressed,
                    icon: const Icon(LucideIcons.send, size: 18),
                    visualDensity: VisualDensity.compact,
                  )
                else if (running)
                  GestureDetector(
                    onLongPress: _onForceStopLongPress,
                    child: IconButton.filledTonal(
                      onPressed: _onPausePressed,
                      icon: const Icon(LucideIcons.pause, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  const IconButton.filled(
                    onPressed: null,
                    icon: Icon(LucideIcons.send, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13,
                  color: cs.onSurface.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
