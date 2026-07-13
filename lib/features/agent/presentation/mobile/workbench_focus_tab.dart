import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tool_detail_sheet.dart';

/// 工作台「焦点」tab（UI 稿 §4.3）：智能体正在干什么，由事件流驱动，
/// 跟随最新活动自动切换——工具调用→参数与实况输出、思考→思考内容、
/// 叙述→当前汇报文字。下方附最近工具活动列表，点任意一条看完整详情。
class WorkbenchFocusTab extends ConsumerWidget {
  const WorkbenchFocusTab({required this.task, super.key});

  final AgentTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(agentTaskEventsProvider(task.id));
    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载事件失败：$e')),
      data: (events) {
        AgentEvent? focus;
        final recentTools = <ToolCallEvent>[];
        for (var i = events.length - 1; i >= 0; i--) {
          final e = events[i];
          if (e is ToolCallEvent) {
            if (recentTools.length < 8) recentTools.add(e);
            focus ??= e;
          } else if (focus == null &&
              (e is ReasoningEvent || e is AssistantTextEvent)) {
            focus = e;
          }
          if (focus != null && recentTools.length >= 8) break;
        }
        if (focus == null) {
          return _empty(context);
        }
        return SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _FocusCard(event: focus)),
              if (recentTools.isNotEmpty) ...[
                const Divider(height: 1),
                _RecentTools(tools: recentTools),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.eye, size: 40, color: muted),
          const SizedBox(height: 12),
          Text(
            '暂无活动\n智能体开始工作后，这里实时显示它正在干什么',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

IconData _toolIcon(String toolName) {
  final n = toolName.toLowerCase();
  if (n.contains('terminal') || n.contains('command')) {
    return LucideIcons.terminal;
  }
  if (n.contains('search')) return LucideIcons.search;
  if (n.contains('write') || n.contains('edit')) return LucideIcons.filePen;
  if (n.contains('read') || n.contains('file') || n.contains('list')) {
    return LucideIcons.fileText;
  }
  if (n.contains('web') || n.contains('fetch') || n.contains('http')) {
    return LucideIcons.globe;
  }
  if (n.contains('knowledge') || n.contains('memory')) {
    return LucideIcons.bookOpen;
  }
  return LucideIcons.wrench;
}

(String, Color) _stateLabel(BuildContext context, AgentToolCallState state) {
  final cs = Theme.of(context).colorScheme;
  final muted = cs.onSurface.withValues(alpha: 0.55);
  return switch (state) {
    AgentToolCallState.running => ('执行中…', cs.primary),
    AgentToolCallState.success => ('成功 ✓', Colors.green),
    AgentToolCallState.failure => ('失败 ✗', cs.error),
    AgentToolCallState.denied => ('已拒绝', muted),
    AgentToolCallState.waitingApproval => ('等待授权', Colors.orange),
  };
}

/// 焦点主区：当前活动的标题行 + 实况内容（各自类型渲染）。
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.event});

  final AgentEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    final IconData icon;
    final String title;
    Widget? trailing;
    final String body;
    switch (event) {
      case final ToolCallEvent e:
        icon = _toolIcon(e.toolName);
        title = e.argSummary.isEmpty
            ? e.toolName
            : '${e.toolName}  ${e.argSummary}';
        final (label, color) = _stateLabel(context, e.state);
        trailing = Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        );
        body = _toolBody(e);
      case final ReasoningEvent e:
        icon = LucideIcons.brain;
        title = e.streaming ? '思考中…' : '思考';
        body = e.text.isEmpty ? '（思考中，尚无内容）' : e.text;
      case final AssistantTextEvent e:
        icon = LucideIcons.messageSquareText;
        title = e.streaming ? '汇报中…' : '汇报';
        body = e.text;
      default:
        icon = LucideIcons.eye;
        title = '当前活动';
        body = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: event is ToolCallEvent
              ? () => showToolDetailSheet(context, event as ToolCallEvent)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                body.isEmpty ? '（暂无内容）' : body,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 工具事件的实况正文：执行中显示完整参数，结束后显示输出
  /// （截断内容/摘要；完整详情走底部抽屉）。
  String _toolBody(ToolCallEvent e) {
    if (e.state == AgentToolCallState.running ||
        e.state == AgentToolCallState.waitingApproval) {
      return e.argsDetail ?? e.argSummary;
    }
    if (e.resultDetail?.isNotEmpty ?? false) return e.resultDetail!;
    if (e.resultSummary.isNotEmpty) return e.resultSummary;
    return e.argsDetail ?? e.argSummary;
  }
}

/// 最近工具活动（新→旧），点任意一条打开完整详情抽屉。
class _RecentTools extends StatelessWidget {
  const _RecentTools({required this.tools});

  final List<ToolCallEvent> tools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    return SizedBox(
      height: 132,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final e = tools[index];
          final (label, color) = _stateLabel(context, e.state);
          return InkWell(
            onTap: () => showToolDetailSheet(context, e),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Icon(_toolIcon(e.toolName), size: 13, color: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.argSummary.isEmpty
                          ? e.toolName
                          : '${e.toolName}  ${e.argSummary}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
