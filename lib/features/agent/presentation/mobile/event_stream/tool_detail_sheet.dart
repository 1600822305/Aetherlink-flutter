import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_tool_detail.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/workbench/workbench_page.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 工具调用详情底部抽屉（UI 稿 §4.1）：完整参数 + 完整输出。
/// 面板固定屏高 2/3；各分区限高、内部滑动，面板也可整体滚动。
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
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                bottomPad > 0 ? bottomPad : 12,
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
                    const SizedBox(height: 14),
                    _Section(
                      title: '输出',
                      body: outputText,
                      maxHeight: 320,
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

/// 内容块：按 [maxHeight] 限高并内部滑动，内容不足时自适应。
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
    Widget box = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: SelectableText(
          body,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.4,
          ),
        ),
      ),
    );
    if (maxHeight != null) {
      box = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: box,
      );
    }
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
