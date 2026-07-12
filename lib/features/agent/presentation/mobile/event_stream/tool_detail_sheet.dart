import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 工具调用详情底部抽屉（UI 稿 §4.1）：完整参数 + 完整输出。
/// 面板固定屏高 2/3；参数区限高、输出区占满余下高度，各自内部滑动。
/// 大输出默认显截断内容，「查看全文」从落盘文件回读。
Future<void> showToolDetailSheet(BuildContext context, ToolCallEvent event) {
  // 先释放输入框焦点，避免面板关闭时焦点恢复自动顶起输入法。
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ToolDetailSheet(event: event),
  );
}

class _ToolDetailSheet extends StatefulWidget {
  const _ToolDetailSheet({required this.event});

  final ToolCallEvent event;

  @override
  State<_ToolDetailSheet> createState() => _ToolDetailSheetState();
}

class _ToolDetailSheetState extends State<_ToolDetailSheet> {
  ToolCallEvent get event => widget.event;

  /// 落盘全文（点「查看全文」后加载，替换输出区内容）。
  String? _fullText;
  bool _loadingFull = false;

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: '参数',
                    body: event.argsDetail ?? event.argSummary,
                    maxHeight: 140,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _Section(
                      title: '输出',
                      body: _fullText ??
                          ((event.resultDetail?.isNotEmpty ?? false)
                              ? event.resultDetail!
                              : (event.resultSummary.isEmpty
                                    ? '（暂无输出）'
                                    : event.resultSummary)),
                      fill: true,
                      trailing: event.resultOverflowPath != null &&
                              _fullText == null
                          ? TextButton(
                              onPressed: _loadingFull ? null : _loadFullText,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: Text(
                                _loadingFull ? '加载中…' : '查看全文',
                                style: theme.textTheme.labelSmall,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 内容块：固定高度内部滑动。[fill] 时占满父约束（外层配 Expanded），
/// 否则按 [maxHeight] 限高，内容不足时自适应。
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.fill = false,
    this.maxHeight,
    this.trailing,
  });

  final String title;
  final String body;
  final bool fill;
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
    if (!fill && maxHeight != null) {
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
        if (fill) Expanded(child: box) else box,
      ],
    );
  }
}
