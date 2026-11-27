import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_terminal_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_terminal_focus.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_tool_detail.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_page.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 工具调用详情底部抽屉（UI 稿 §4.1）：完整参数 + 完整输出。
/// 面板固定屏高 2/3：参数等固定在上方（最多占 45%，超出自身滚动），
/// 输出区填满剩余高度并内部滚动，两块互不嵌套，输出再长参数也可见。
/// 大输出默认显截断内容，「查看全文」从落盘文件回读。
/// 传入 [taskId] 时抽屉订阅事件流，参数/状态/输出随执行实时更新。
Future<void> showToolDetailSheet(
  BuildContext context,
  ToolCallEvent event, {
  String? taskId,
}) {
  // 先释放输入框焦点，避免面板关闭时焦点恢复自动顶起输入法。
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ToolDetailSheet(event: event, taskId: taskId),
  );
}

class _ToolDetailSheet extends ConsumerStatefulWidget {
  const _ToolDetailSheet({required this.event, this.taskId});

  final ToolCallEvent event;
  final String? taskId;

  @override
  ConsumerState<_ToolDetailSheet> createState() => _ToolDetailSheetState();
}

class _ToolDetailSheetState extends ConsumerState<_ToolDetailSheet> {
  /// 实时事件：有 taskId 时 build 里从事件流按 id 解析最新版本缓存于此，
  /// 否则保持开启抽屉时的快照（回调里直接读，避免 build 外 watch）。
  ToolCallEvent? _event;

  ToolCallEvent get event => _event ?? widget.event;

  ToolCallEvent _resolveEvent() {
    final taskId = widget.taskId;
    if (taskId == null) return widget.event;
    final events = ref.watch(agentTaskEventsProvider(taskId)).value;
    if (events == null) return widget.event;
    for (var i = events.length - 1; i >= 0; i--) {
      final e = events[i];
      if (e is ToolCallEvent && e.id == widget.event.id) return e;
    }
    return widget.event;
  }

  /// 面板整体滚动；「跳到底部」按钮只在滑动时浮现，停手后自动隐藏。
  final ScrollController _scroll = ScrollController();
  bool _showJump = false;
  Timer? _hideJump;

  static const double _kJumpThreshold = 48;

  @override
  void dispose() {
    _hideJump?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    // 只看输出区这一层。
    if (n.depth != 0) return false;
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      final farFromBottom = n.metrics.extentAfter > _kJumpThreshold;
      if (!farFromBottom) {
        _setJump(false);
      } else if (n is ScrollUpdateNotification) {
        _setJump(true);
        _hideJump?.cancel();
        _hideJump = Timer(
          const Duration(milliseconds: 1500),
          () => _setJump(false),
        );
      }
    }
    return false;
  }

  void _setJump(bool v) {
    if (!mounted || v == _showJump) return;
    setState(() => _showJump = v);
  }

  void _jumpToBottom() {
    _hideJump?.cancel();
    _setJump(false);
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// 落盘全文（点「查看全文」后加载，替换输出区内容）。
  String? _fullText;
  bool _loadingFull = false;

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) AppToast.success(context, '已复制');
    } catch (error) {
      if (mounted) AppToast.error(context, '复制失败：$error');
    }
  }

  void _openDiff(String path) {
    final task = ref.read(agentTasksProvider)
        .where((task) => task.id == widget.taskId)
        .firstOrNull;
    if (task == null) {
      AppToast.info(context, '未找到关联任务，无法打开工作台');
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push<void>(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          body: SafeArea(
            top: false,
            child: WorkbenchPage(
              task: task,
              initialFilePath: path,
              onBackToChat: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadFullText() async {
    final path = event.resultOverflowPath;
    if (path == null || _loadingFull) return;
    setState(() => _loadingFull = true);
    String text;
    try {
      text = await File(path).readAsString();
    } catch (e) {
      text = '读取全文失败（$path）：$e';
    }
    if (!mounted) return;
    setState(() {
      _fullText = text;
      _loadingFull = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _event = _resolveEvent();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final argsText = ref.watch(
      agentToolStreamProvider.select((m) => m[event.id]?.argsText),
    ) ?? event.argsDetail ?? event.argSummary;
    final outputText = _fullText ??
        ((event.resultDetail?.isNotEmpty ?? false)
            ? event.resultDetail!
            : (event.resultSummary.isEmpty ? '（暂无输出）' : event.resultSummary));
    final command = toolCommandText(event.toolName, argsText);
    final changedFiles = toolChangedFilePaths(
      event.toolName,
      argsText,
      resultText: _fullText ?? event.resultDetail,
    );
    final stateLabel = switch (event.state) {
      AgentToolCallState.running => '执行中…',
      AgentToolCallState.success => '成功 ✓',
      AgentToolCallState.failure => '失败 ✗',
      AgentToolCallState.denied => '已拒绝',
      AgentToolCallState.waitingApproval => '等待授权',
    };
    final stateColor = switch (event.state) {
      AgentToolCallState.failure => cs.error,
      AgentToolCallState.success => Colors.green,
      AgentToolCallState.waitingApproval => Colors.orange,
      _ => muted,
    };

    return FractionallySizedBox(
      heightFactor: 2 / 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                Icon(LucideIcons.wrench, size: 16, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.toolName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Text(
                  event.elapsed == null
                      ? stateLabel
                      : '$stateLabel · ${event.elapsed!.inMilliseconds < 1000 ? '${event.elapsed!.inMilliseconds}ms' : '${(event.elapsed!.inMilliseconds / 1000).toStringAsFixed(1)}s'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: stateColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 上半区（参数/变更文件/截图）固定在顶部，最多占 45% 且超出时自身滚动；
          // 输出区填满剩余高度并内部滚动——输出再长参数也始终可见。
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                bottomPad > 0 ? bottomPad : 12,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.45,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Section(
                              title: '参数',
                              body: argsText,
                              maxHeight: 140,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (command != null)
                                    TextButton(
                                      onPressed: () => _copy(command),
                                      style: _headerButtonStyle,
                                      child: Text('复制命令', style: theme.textTheme.labelSmall),
                                    ),
                                  _CopyButton(
                                    tooltip: '复制参数',
                                    onPressed: () => _copy(argsText),
                                  ),
                                ],
                              ),
                            ),
                            if (changedFiles.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                '变更的文件',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 120),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      for (final path in changedFiles)
                                        InkWell(
                                          onTap: () => _openDiff(path),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            child: Row(
                                              children: [
                                                Icon(LucideIcons.fileText, size: 14, color: muted),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(path, style: theme.textTheme.labelSmall),
                                                ),
                                                Icon(LucideIcons.chevronRight, size: 14, color: muted),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (event.imagePath != null) ...[
                              const SizedBox(height: 14),
                              _ImageSection(path: event.imagePath!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionHeader(
                      title: '输出',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event.resultOverflowPath != null && _fullText == null)
                            TextButton(
                              onPressed: _loadingFull ? null : _loadFullText,
                              style: _headerButtonStyle,
                              child: Text(
                                _loadingFull ? '加载中…' : '查看全文',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          _CopyButton(
                            tooltip: '复制输出',
                            onPressed: () => _copy(outputText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            NotificationListener<ScrollNotification>(
                              onNotification: _onScroll,
                              child: SingleChildScrollView(
                                controller: _scroll,
                                padding: const EdgeInsets.all(10),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: SelectableText(
                                    outputText,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: IgnorePointer(
                                ignoring: !_showJump,
                                child: AnimatedOpacity(
                                  opacity: _showJump ? 1 : 0,
                                  duration: const Duration(milliseconds: 160),
                                  child: Material(
                                    color: cs.surfaceContainerHigh,
                                    elevation: 3,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: '跳到底部',
                                      onPressed: _jumpToBottom,
                                      icon: const Icon(LucideIcons.arrowDown, size: 18),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 终端命令：跳到工作台终端 tab 里这条命令所在的会话。
                    if (_isTerminalTool(event.toolName) && widget.taskId != null)
                      _OpenInTerminalBar(
                        taskId: widget.taskId!,
                        sessionRef: terminalToolSessionRef(
                          argsDetail: argsText,
                          resultDetail: event.resultDetail,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 跑在工作区长驻会话里的终端工具（run_command 是聊天侧一次性执行，不联动）。
bool _isTerminalTool(String name) =>
    name == 'terminal_execute' || name == 'terminal_session';

/// 详情面板底部「在终端中查看」：左侧显示会话 ID 与状态（点之前就知道
/// 会跳去哪），点击关面板并发出跳转请求（任务壳翻页 → 工作台切终端 tab
/// → 终端 tab 选中会话）。
class _OpenInTerminalBar extends ConsumerWidget {
  const _OpenInTerminalBar({required this.taskId, this.sessionRef});

  final String taskId;
  final String? sessionRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final manager = ref.watch(agentSessionPoolManagerProvider);
    final target = sessionRef;
    final session = target == null
        ? null
        : manager.allSessions().where((s) => s.id == target).firstOrNull ??
              manager.allSessions().where((s) => s.name == target).firstOrNull;
    final String label;
    if (target == null) {
      label = '默认会话';
    } else if (session == null || !session.alive) {
      label = '会话 $target · 已关闭';
    } else {
      label = '会话 ${session.id} · ${session.busy ? '运行中' : '空闲'}';
    }
    final closed = target != null && (session == null || !session.alive);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(LucideIcons.terminal, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                fontFamily: 'monospace',
              ),
            ),
          ),
          FilledButton(
            onPressed: closed
                ? null
                : () {
                    Navigator.of(context).pop();
                    ref
                        .read(agentTerminalFocusProvider.notifier)
                        .request(taskId, sessionRef: target);
                  },
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: theme.textTheme.labelMedium,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('在终端中查看'),
                SizedBox(width: 2),
                Icon(LucideIcons.chevronRight, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _headerButtonStyle = TextButton.styleFrom(
  visualDensity: VisualDensity.compact,
  minimumSize: const Size(0, 32),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: const Icon(LucideIcons.copy, size: 14),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    padding: const EdgeInsets.all(6),
  );
}

/// 图片结果缩略图（截图类工具）：从落盘文件渲染，文件丢失时降级为提示行。
class _ImageSection extends StatelessWidget {
  const _ImageSection({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '截图',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Image.file(
              File(path),
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: cs.onSurface.withValues(alpha: 0.04),
                child: Text(
                  '截图文件已丢失（$path）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 分区标题行：左标题 + 右侧动作。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 内容块：给了 [maxHeight] 时限高并内部滑动；不给则按内容全高展开。
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.maxHeight,
    this.trailing,
  });

  final String title;
  final String body;
  final double? maxHeight;

  /// 标题行右侧动作（如「查看全文」）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = SelectableText(
      body,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        height: 1.4,
      ),
    );
    final decoration = BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(8),
    );
    // 限高时内部滑动；不限高时随面板整体滚动（不嵌套滚动）。
    final Widget box = maxHeight == null
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: decoration,
            child: text,
          )
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight!),
            child: Container(
              width: double.infinity,
              decoration: decoration,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: text,
              ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        box,
      ],
    );
  }
}
