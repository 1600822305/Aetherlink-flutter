import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 底部输入区（UI 稿输入区，已拍板）：与普通聊天输入框同款视觉——
/// 圆角纸面卡片，上层无边框文本区域，下层单独一行按钮工具条
/// （左：＋附件、模式快切 Code/Ask/Plan、模型 chip；右：发送/中断变形按钮，
/// §五打断交互）。
class AgentInputBar extends ConsumerStatefulWidget {
  const AgentInputBar({this.task, super.key});

  /// null = 干净新话题（草稿态）：发第一条消息才开始任务，
  /// 此时发送直接发（没有可打断的执行，不弹三选面板）。
  final AgentTask? task;

  @override
  ConsumerState<AgentInputBar> createState() => _AgentInputBarState();
}

class _AgentInputBarState extends ConsumerState<AgentInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  late AgentSessionMode _mode = widget.task?.mode ?? AgentSessionMode.code;

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

  /// 有文字：任务执行中发送不直接发——弹三选面板（排队/立即打断并
  /// 发送/继续编辑）；草稿态/非执行中任务直接发。
  Future<void> _onSendPressed() async {
    final task = widget.task;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final runner = ref.read(agentTaskRunnerProvider.notifier);

    if (task == null) {
      // 草稿态：发第一条消息 = 创建任务 + 启动引擎。
      final profileId = ref.read(selectedAgentProfileIdProvider);
      final profile = ref
          .read(agentProfilesProvider)
          .where((p) => p.id == profileId)
          .firstOrNull;
      if (profile == null) return;
      _controller.clear();
      final created = await runner.startNewTask(
          profile: profile, text: text, mode: _mode);
      ref.read(selectedAgentTaskIdProvider.notifier).select(created.id);
      return;
    }

    final executing = task.status == AgentTaskStatus.running ||
        task.status == AgentTaskStatus.waitingApproval;
    if (!executing) {
      // paused/waitingInput/done/failed/cancelled：落消息并续跑。
      _controller.clear();
      await runner.sendMessage(task, text);
      return;
    }
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
    if (action == 'queue') {
      _controller.clear();
      await runner.sendMessage(task, text, queued: true);
    } else if (action == 'interrupt') {
      _controller.clear();
      await runner.interruptAndSend(task, text);
    }
  }

  /// 无文字：点一下=暂停；长按=强制终止二次确认。
  void _onPausePressed() {
    final task = widget.task;
    if (task != null) {
      ref.read(agentTaskRunnerProvider.notifier).pause(task.id);
    }
  }

  Future<void> _onForceStopLongPress() async {
    final confirmed = await showDialog<bool>(
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
    final task = widget.task;
    if (confirmed == true && task != null) {
      ref.read(agentTaskRunnerProvider.notifier).forceStop(task.id);
    }
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
    final isDark = theme.brightness == Brightness.dark;
    final running = widget.task?.status == AgentTaskStatus.running;

    // 与普通聊天输入框同款卡片 chrome（InputBoxComposer defaultStyle：
    // 圆角 8、细边框、轻投影、纸面 surface），外围透明 + 8px gutter。
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xCC3C3C3C) : const Color(0xCCE6E6E6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 上层：无边框文本区域。
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 2),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                  decoration: const InputDecoration(
                    hintText: '追加指令…',
                    hintStyle: TextStyle(fontSize: 16, height: 1.4),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              // 下层：单独一行按钮工具条（space-between，36px 高）。
              SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          // TODO(agent): 附件面板（图片/文件/引用工作区文件）
                          onPressed: () {},
                          icon: const Icon(LucideIcons.plus, size: 18),
                          padding: const EdgeInsets.all(6),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                        const SizedBox(width: 2),
                        _Chip(
                          icon: LucideIcons.keyboard,
                          label: '${agentModeLabel(_mode)} ▾',
                          onTap: _onModeTap,
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          icon: LucideIcons.brain,
                          label: '${widget.task?.modelLabel ?? 'GLM-4.6'} ▾',
                          onTap: () {}, // TODO(agent): 复用聊天模型选择器
                        ),
                      ],
                    ),
                    if (_hasText)
                      IconButton(
                        onPressed: _onSendPressed,
                        icon: Icon(
                          LucideIcons.send,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF09BB07),
                        ),
                        padding: const EdgeInsets.all(6),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      )
                    else if (running)
                      GestureDetector(
                        onLongPress: _onForceStopLongPress,
                        child: IconButton(
                          onPressed: _onPausePressed,
                          icon: const Icon(
                            LucideIcons.pause,
                            size: 18,
                            color: Color(0xFFFF4D4F),
                          ),
                          padding: const EdgeInsets.all(6),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                      )
                    else if (widget.task?.status == AgentTaskStatus.paused ||
                        widget.task?.status == AgentTaskStatus.waitingInput)
                      IconButton(
                        onPressed: () {
                          final task = widget.task;
                          if (task != null) {
                            ref
                                .read(agentTaskRunnerProvider.notifier)
                                .resume(task);
                          }
                        },
                        icon: Icon(
                          LucideIcons.play,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        padding: const EdgeInsets.all(6),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      )
                    else
                      IconButton(
                        onPressed: null,
                        icon: Icon(
                          LucideIcons.send,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF555555)
                              : const Color(0xFFCCCCCC),
                        ),
                        padding: const EdgeInsets.all(6),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: card,
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
