import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tool_detail_sheet.dart';

/// 工作台「焦点」tab（UI 稿 §4.3）：时间线工作日志——按事件顺序渲染
/// 「真实产物」：终端工具→命令+实况输出块、文件编辑→search/replace
/// 红绿 diff 块、读文件→内容片段块、用户消息/汇报/思考/计划各自样式块。
/// 新事件到来自动滚到底跟随；用户上滑暂停跟随，出现「回到最新」浮钮。
/// 点工具块打开完整详情抽屉。
class WorkbenchFocusTab extends ConsumerStatefulWidget {
  const WorkbenchFocusTab({required this.task, super.key});

  final AgentTask task;

  @override
  ConsumerState<WorkbenchFocusTab> createState() => _WorkbenchFocusTabState();
}

class _WorkbenchFocusTabState extends ConsumerState<WorkbenchFocusTab> {
  final ScrollController _scroll = ScrollController();
  bool _follow = true;
  int _lastCount = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  /// 事件数变化且处于跟随态时滚到底（帧末，等新块完成布局）。
  void _maybeFollow(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    if (!_follow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpToLatest();
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is UserScrollNotification || n is ScrollUpdateNotification) {
      final pos = _scroll.hasClients ? _scroll.position : null;
      if (pos == null) return false;
      final atBottom = pos.pixels >= pos.maxScrollExtent - 48;
      if (atBottom != _follow) setState(() => _follow = atBottom);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(agentTaskEventsProvider(widget.task.id));
    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载事件失败：$e')),
      data: (events) {
        if (events.isEmpty) return _empty(context);
        _maybeFollow(events.length);
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: events.length,
                itemBuilder: (context, i) => _WorklogBlock(event: events[i]),
              ),
            ),
            if (!_follow)
              Positioned(
                right: 16,
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
                child: FloatingActionButton.small(
                  tooltip: '回到最新',
                  onPressed: () {
                    setState(() => _follow = true);
                    _jumpToLatest();
                  },
                  child: const Icon(LucideIcons.arrowDown, size: 18),
                ),
              ),
          ],
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

bool _isTerminalTool(String toolName) {
  final n = toolName.toLowerCase();
  return n.contains('terminal') || n.contains('command');
}

bool _isReadTool(String toolName) {
  final n = toolName.toLowerCase();
  return n.contains('read') || n.contains('list') || n.contains('search');
}

/// 从 argsDetail（参数 JSON）里解析编辑类工具的 search/replace 对
/// （单对或 edits 数组）；写入类工具的全文内容返回 (null, content)。
List<({String? search, String replace})> _editPairsOf(ToolCallEvent e) {
  final raw = e.argsDetail;
  if (raw == null || raw.isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const [];
  }
  if (decoded is! Map) return const [];
  final pairs = <({String? search, String replace})>[];
  final edits = decoded['edits'];
  if (edits is List) {
    for (final item in edits) {
      if (item is Map && item['search'] is String) {
        pairs.add((
          search: item['search'] as String,
          replace: '${item['replace'] ?? ''}',
        ));
      }
    }
    if (pairs.isNotEmpty) return pairs;
  }
  if (decoded['search'] is String) {
    return [
      (search: decoded['search'] as String, replace: '${decoded['replace'] ?? ''}'),
    ];
  }
  final content = decoded['content'] ?? decoded['file_text'];
  if (content is String && content.isNotEmpty) {
    return [(search: null, replace: content)];
  }
  return const [];
}

/// 时间线里的一个事件块：按类型渲染真实产物。
class _WorklogBlock extends StatelessWidget {
  const _WorklogBlock({required this.event});

  final AgentEvent event;

  @override
  Widget build(BuildContext context) {
    return switch (event) {
      final UserMessageEvent e => _UserBlock(event: e),
      final AssistantTextEvent e => _TextBlock(
          icon: LucideIcons.messageSquareText,
          title: e.streaming ? '汇报中…' : '汇报',
          text: e.text,
        ),
      final ReasoningEvent e => _TextBlock(
          icon: LucideIcons.brain,
          title: e.streaming
              ? '思考中…'
              : (e.elapsed == null ? '思考' : '思考了 ${e.elapsed!.inSeconds}s'),
          text: e.text,
          muted: true,
        ),
      final ToolCallEvent e => _ToolBlock(event: e),
      final PlanUpdateEvent e => _PlanBlock(event: e),
      final CheckpointEvent e => _MarkerRow(
          icon: LucideIcons.flag,
          text: e.label.isEmpty ? '检查点 ${e.commit.substring(0, 7)}' : '检查点 · ${e.label}',
        ),
      final StatusChangeEvent e =>
        _MarkerRow(icon: LucideIcons.info, text: e.description),
      final CompactionEvent e =>
        _MarkerRow(icon: LucideIcons.foldVertical, text: '已压缩 ${e.coveredCount} 条历史事件'),
    };
  }
}

/// 用户消息：主色浅底卡片。
class _UserBlock extends StatelessWidget {
  const _UserBlock({required this.event});

  final UserMessageEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.user, size: 14, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              event.queued ? '${event.text}\n（排队追加）' : event.text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 汇报/思考文字块。
class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.icon,
    required this.title,
    required this.text,
    this.muted = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mutedColor = cs.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: mutedColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            text.isEmpty ? '（尚无内容）' : text,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.4,
              color: muted ? mutedColor : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// 工具块：终端→命令+输出、编辑→红绿 diff、读→内容片段、其他→紧凑行。
/// 点块打开完整详情抽屉。
class _ToolBlock extends StatelessWidget {
  const _ToolBlock({required this.event});

  final ToolCallEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mutedColor = cs.onSurface.withValues(alpha: 0.55);
    final (label, color) = _stateLabel(context, event.state);

    Widget? artifact;
    if (_isTerminalTool(event.toolName)) {
      artifact = _MonoPane(
        text: '\$ ${event.argSummary}\n'
            '${event.resultDetail ?? event.resultSummary}',
        dark: true,
      );
    } else {
      final pairs = _editPairsOf(event);
      if (pairs.isNotEmpty) {
        artifact = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in pairs) ...[
              if (p.search != null)
                _MonoPane(text: p.search!, tint: cs.error),
              _MonoPane(text: p.replace, tint: Colors.green),
            ],
          ],
        );
      } else if (_isReadTool(event.toolName) &&
          (event.resultDetail?.isNotEmpty ?? false)) {
        artifact = _MonoPane(text: event.resultDetail!);
      }
    }

    return InkWell(
      onTap: () => showToolDetailSheet(context, event),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_toolIcon(event.toolName), size: 13, color: mutedColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.argSummary.isEmpty
                        ? event.toolName
                        : '${event.toolName}  ${event.argSummary}',
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
            if (artifact != null) ...[
              const SizedBox(height: 6),
              artifact,
            ],
          ],
        ),
      ),
    );
  }
}

/// 等宽产物面板：限高内部滚动；[dark] 为终端风格深底，[tint] 为
/// diff 红/绿浅底。
class _MonoPane extends StatelessWidget {
  const _MonoPane({required this.text, this.dark = false, this.tint});

  final String text;
  final bool dark;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = dark
        ? const Color(0xFF14161B)
        : (tint?.withValues(alpha: 0.08) ??
            cs.onSurface.withValues(alpha: 0.04));
    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: SelectableText(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.4,
            color: dark ? Colors.white.withValues(alpha: 0.9) : tint,
          ),
        ),
      ),
    );
  }
}

/// 计划快照：三态勾选清单。
class _PlanBlock extends StatelessWidget {
  const _PlanBlock({required this.event});

  final PlanUpdateEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mutedColor = cs.onSurface.withValues(alpha: 0.55);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.listChecks, size: 13, color: mutedColor),
              const SizedBox(width: 6),
              Text(
                '计划更新',
                style: theme.textTheme.labelSmall?.copyWith(color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in event.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (item.status) {
                      AgentPlanItemStatus.completed => LucideIcons.circleCheck,
                      AgentPlanItemStatus.inProgress => LucideIcons.circleDot,
                      AgentPlanItemStatus.pending => LucideIcons.circle,
                    },
                    size: 13,
                    color: switch (item.status) {
                      AgentPlanItemStatus.completed => Colors.green,
                      AgentPlanItemStatus.inProgress => cs.primary,
                      AgentPlanItemStatus.pending => mutedColor,
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.content,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 轻量标记行（检查点/状态迁移/压缩）。
class _MarkerRow extends StatelessWidget {
  const _MarkerRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
