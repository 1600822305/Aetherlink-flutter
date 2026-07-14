import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/model_selector_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_attachment_menu.dart';
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
  // 模式 chip 与侧边栏「执行设置」同源：无话题时取全局默认模式（持久化），
  // 有话题时跟话题自身模式走。
  late AgentSessionMode _mode =
      widget.task?.mode ??
      ref.read(agentUiSettingsControllerProvider).defaultMode;
  final List<AgentUserAttachment> _attachments = [];
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final text = _controller.text;
      final has = text.trim().isNotEmpty || _attachments.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
      // 刚敲出一个 @（光标处新增字符）→ 弹工作区文件搜索浮层。
      if (text.length == _lastText.length + 1) {
        final sel = _controller.selection;
        if (sel.isCollapsed &&
            sel.baseOffset > 0 &&
            text[sel.baseOffset - 1] == '@') {
          _onAtTyped(sel.baseOffset);
        }
      }
      _lastText = text;
    });
  }

  @override
  void didUpdateWidget(covariant AgentInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切话题 / 任务模式外部变更（如 Plan→Code 一键转）时同步 chip。
    final mode = widget.task?.mode;
    if (mode != null && mode != oldWidget.task?.mode && mode != _mode) {
      setState(() => _mode = mode);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _workspaceId {
    final task = widget.task;
    if (task != null) return task.workspaceId;
    final profileId = ref.read(selectedAgentProfileIdProvider);
    return ref
        .read(agentProfilesProvider)
        .where((p) => p.id == profileId)
        .firstOrNull
        ?.workspaceId;
  }

  void _addAttachment(AgentUserAttachment? attachment) {
    if (attachment == null) return;
    setState(() {
      _attachments.add(attachment);
      _hasText = true;
    });
  }

  Future<void> _onAttachmentPressed() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final attachment = await showAgentAttachmentMenu(
      context,
      ref,
      workspaceId: _workspaceId,
    );
    _addAttachment(attachment);
  }

  /// 输入框内敲 @：弹工作区文件搜索，选中后把相对路径接在 @ 后，
  /// 并把文件内容作为附件随消息发送。
  Future<void> _onAtTyped(int atEnd) async {
    final attachment = await showAgentWorkspaceFilePicker(
      context,
      ref,
      workspaceId: _workspaceId,
    );
    if (attachment == null) return;
    final text = _controller.text;
    if (atEnd <= text.length && atEnd > 0 && text[atEnd - 1] == '@') {
      final inserted = '${attachment.name} ';
      _controller.value = TextEditingValue(
        text: text.replaceRange(atEnd, atEnd, inserted),
        selection: TextSelection.collapsed(offset: atEnd + inserted.length),
      );
    }
    _addAttachment(attachment);
  }

  /// 有文字：任务执行中发送不直接发——弹三选面板（排队/立即打断并
  /// 发送/继续编辑）；草稿态/非执行中任务直接发。
  Future<void> _onSendPressed() async {
    final task = widget.task;
    var text = _controller.text.trim();
    final attachments = List<AgentUserAttachment>.unmodifiable(_attachments);
    if (text.isEmpty && attachments.isEmpty) return;
    if (text.isEmpty) text = '请查看附件';
    final runner = ref.read(agentTaskRunnerProvider.notifier);

    void clearInput() {
      _controller.clear();
      setState(() {
        _attachments.clear();
        _hasText = false;
      });
    }

    if (task == null) {
      // 草稿态：发第一条消息 = 创建任务 + 启动引擎。
      final profileId = ref.read(selectedAgentProfileIdProvider);
      final profile = ref
          .read(agentProfilesProvider)
          .where((p) => p.id == profileId)
          .firstOrNull;
      if (profile == null) return;
      clearInput();
      final created = await runner.startNewTask(
        profile: profile,
        text: text,
        mode: _mode,
        attachments: attachments,
      );
      ref.read(selectedAgentTaskIdProvider.notifier).select(created.id);
      return;
    }

    if (task.status == AgentTaskStatus.draft) {
      // 空白草稿话题：发第一条消息 = 定标题 + 启动引擎。
      clearInput();
      await runner.startDraft(
        task,
        text,
        mode: _mode,
        attachments: attachments,
      );
      return;
    }

    if (task.status == AgentTaskStatus.waitingInput) {
      // 等待回答：输入框承接自定义回答，建议答案在上方面板点选。
      if (attachments.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('回答暂不支持附件')));
        return;
      }
      try {
        await runner.answerLatestUserQuestion(task, text);
        if (!mounted) return;
        clearInput();
      } on StateError catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message.toString())));
      }
      return;
    }

    final executing =
        task.status == AgentTaskStatus.running ||
        task.status == AgentTaskStatus.waitingApproval;
    if (!executing) {
      // paused/done/failed/cancelled：落消息并续跑（带上
      // chips 当前模式，中途切模式在这里生效）。
      clearInput();
      await runner.sendMessage(
        task,
        text,
        mode: _mode,
        attachments: attachments,
      );
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
      clearInput();
      await runner.sendMessage(
        task,
        text,
        queued: true,
        attachments: attachments,
      );
    } else if (action == 'interrupt') {
      clearInput();
      await runner.interruptAndSend(task, text, attachments: attachments);
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
    // 先释放焦点，面板关闭后不自动顶起输入法。
    FocusManager.instance.primaryFocus?.unfocus();
    final mode = await showModalBottomSheet<AgentSessionMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (m, desc) in const [
              (AgentSessionMode.code, '执行模式：写/终端全能力，走审批+白名单'),
              (AgentSessionMode.auto, '自动模式：工作区内写/执行免审批，越界仍审批'),
              (AgentSessionMode.ask, '只问答：仅只读工具，不改任何东西'),
              (AgentSessionMode.plan, '只读规划：先出完整方案，确认后转 Code'),
            ])
              ListTile(
                selected: m == _mode,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                leading: Icon(
                  m == _mode ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 20,
                ),
                title: Text(
                  agentModeLabel(m),
                  style: m == _mode
                      ? const TextStyle(fontWeight: FontWeight.w600)
                      : null,
                ),
                subtitle: Text(desc),
                trailing: m == _mode ? const Text('当前') : null,
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (mode == null) return;
    // auto 二次确认：选中才生效，取消保持原模式。
    if (mode == AgentSessionMode.auto && _mode != AgentSessionMode.auto) {
      final confirmed = await _confirmAutoMode();
      if (confirmed != true) return;
    }
    setState(() => _mode = mode);
    final task = widget.task;
    if (task == null || task.status == AgentTaskStatus.draft) {
      // 新话题/草稿态：写回全局默认模式（持久化，与侧边栏执行设置同步）。
      ref.read(agentUiSettingsControllerProvider.notifier).setDefaultMode(mode);
    }
    if (task != null) {
      // 立即持久化到话题（切页/重启不丢，侧边栏「执行设置」同步显示）；
      // 运行中话题下一轮引擎现取该模式。
      await ref
          .read(agentTasksProvider.notifier)
          .apply(task.copyWith(mode: mode, updatedAt: DateTime.now()));
    }
  }

  Future<bool?> _confirmAutoMode() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('启用 Auto 模式？'),
        content: const Text(
          '绑定工作区内的文件写入与命令执行将不再逐条审批，'
          '越出工作区的操作仍会请求授权。未绑定工作区时不会免审。\n\n'
          '仅在信任当前任务时启用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
            ),
            child: const Text('启用 Auto'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final running = widget.task?.status == AgentTaskStatus.running;

    // 侧边栏「执行设置」改默认模式时同步无话题态的 chip（同源双向）。
    ref.listen(agentUiSettingsControllerProvider, (_, next) {
      if (widget.task == null && next.defaultMode != _mode) {
        setState(() => _mode = next.defaultMode);
      }
    });

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
              // 已选附件 chips（可删）。
              if (_attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < _attachments.length; i++)
                        InputChip(
                          avatar: Icon(switch (_attachments[i].kind) {
                            AgentAttachmentKind.image => LucideIcons.image,
                            AgentAttachmentKind.file => LucideIcons.fileText,
                            AgentAttachmentKind.snippet => LucideIcons.quote,
                          }, size: 14),
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              _attachments[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => setState(() {
                            _attachments.removeAt(i);
                            _hasText =
                                _controller.text.trim().isNotEmpty ||
                                _attachments.isNotEmpty;
                          }),
                        ),
                    ],
                  ),
                ),
              // 上层：无边框文本区域。
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 2),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                  decoration: InputDecoration(
                    hintText:
                        widget.task == null ||
                            widget.task!.status == AgentTaskStatus.draft
                        ? '输入指令开始任务…'
                        : widget.task!.status == AgentTaskStatus.waitingInput
                            ? '点选上方建议答案，或输入自定义回答…'
                            : '追加指令…',
                    hintStyle: const TextStyle(fontSize: 16, height: 1.4),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                          onPressed: _onAttachmentPressed,
                          icon: const Icon(LucideIcons.plus, size: 18),
                          padding: const EdgeInsets.all(6),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 2),
                        _Chip(
                          icon: _mode == AgentSessionMode.auto
                              ? LucideIcons.zap
                              : LucideIcons.keyboard,
                          label: '${agentModeLabel(_mode)} ▾',
                          color: _mode == AgentSessionMode.auto
                              ? Colors.amber.shade800
                              : null,
                          onTap: _onModeTap,
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          icon: LucideIcons.brain,
                          // 智能体跟随 App 级当前模型（引擎每轮现取），
                          // chip 实时显示选中项而非任务创建时的快照。
                          label:
                              '${ref.watch(appCurrentModelProvider).value?.model.name ?? '选择模型'} ▾',
                          maxWidth: 150,
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            showAppModelSelectorDialog(context);
                          },
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          icon: LucideIcons.lightbulb,
                          // 与聊天共用全局思考档位（参数设置
                          // reasoningEffort），引擎每轮现取。单一图标，
                          // 档位靠 tooltip 展示，不占输入行宽度。
                          tooltip: '思考 ${appReasoningEffortLabel(ref)}',
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            showAppReasoningEffortPicker(context, ref);
                          },
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
                          minWidth: 32,
                          minHeight: 32,
                        ),
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
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      )
                    else if (widget.task?.status == AgentTaskStatus.paused)
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
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      )
                    else if (widget.task?.status ==
                        AgentTaskStatus.waitingInput)
                      IconButton(
                        onPressed: null,
                        icon: Icon(
                          LucideIcons.circleHelp,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        padding: const EdgeInsets.all(6),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
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
                          minWidth: 32,
                          minHeight: 32,
                        ),
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
        child: Padding(padding: const EdgeInsets.all(8), child: card),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    this.color,
    this.maxWidth,
  });

  final IconData icon;

  /// 非空时在图标右侧显示文字；为空则只显示图标（如思考档位）。
  final String? label;

  /// 图标模式下的长按/悬浮提示。
  final String? tooltip;
  final VoidCallback onTap;

  /// 非空时用作醒目强调色（如 auto 模式的琥珀色）。
  final Color? color;

  /// 非空时限制 chip 总宽，超长标签省略号截断（如模型名）。
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = this.label;
    final chip = Material(
      color:
          color?.withValues(alpha: 0.14) ??
          cs.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: color ?? cs.onSurface.withValues(alpha: 0.7),
              ),
              if (label != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color ?? cs.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final wrapped = tooltip == null
        ? chip
        : Tooltip(message: tooltip!, child: chip);
    final limit = maxWidth;
    if (limit == null) return wrapped;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: limit),
      child: wrapped,
    );
  }
}
