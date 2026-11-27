import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xterm3/flutter.dart';

import 'package:aetherlink_flutter/app/di/agent_terminal_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_terminal_focus.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/approval_card.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_tool_detail.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/session_terminal.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/loop/finish_guards.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/application/timeline_view.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/devin_diff_lines.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tool_detail_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';

/// 工作台「焦点」tab（UI 稿 §4.3）：默认**跟随**最新活动，活动切换时整块
/// 跟着变——终端工具→命令 + 实况输出（执行中直接接会话 PTY）、文件编辑→
/// search/replace 红绿 diff、读文件→内容片段、思考/汇报/用户消息→正文。
///
/// 顶部「历史」按钮从底部弹出本轮活动面板（可按命令 / 改动 / 失败筛选），
/// 点某条即**锁定**到它，不再被新活动顶走；锁定条显示有几条更新的活动，
/// 「回到最新」恢复跟随。
class WorkbenchFocusTab extends ConsumerStatefulWidget {
  const WorkbenchFocusTab({required this.task, super.key});

  final AgentTask task;

  @override
  ConsumerState<WorkbenchFocusTab> createState() => _WorkbenchFocusTabState();
}

/// 历史面板列出的活动条数上限。
const int _kFocusHistoryLimit = 50;

bool _isFocusable(AgentEvent e) =>
    e is ToolCallEvent ||
    e is ReasoningEvent ||
    e is AssistantTextEvent ||
    e is UserMessageEvent ||
    e is PlanUpdateEvent;

/// 最近的可聚焦活动（新→旧）。按元素**实例**比较相等：provider select
/// 每次都会得到新列表，用默认 List 相等会让焦点 tab 每个事件 delta 都
/// 重建；这里只有窗口内某条活动真的变了（DAO 对未变行复用同一实例）
/// 才算变化，检查点 / 状态行等非焦点事件的变更不再触发重建。
class _FocusHistory {
  _FocusHistory(this.items);

  final List<AgentEvent> items;

  @override
  bool operator ==(Object other) {
    if (other is! _FocusHistory || other.items.length != items.length) {
      return false;
    }
    for (var i = 0; i < items.length; i++) {
      if (!identical(items[i], other.items[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items.map(identityHashCode));
}

_FocusHistory _historyOf(List<AgentEvent> events) {
  final out = <AgentEvent>[];
  for (var i = events.length - 1; i >= 0 && out.length < _kFocusHistoryLimit; i--) {
    if (_isFocusable(events[i])) out.add(events[i]);
  }
  return _FocusHistory(out);
}

class _WorkbenchFocusTabState extends ConsumerState<WorkbenchFocusTab> {
  /// 各任务的锁定活动 id（内存级：切 tab / 切回聊天不丢锁定）。
  static final Map<String, String> _lockedByTask = {};

  void _setLocked(String? id) {
    setState(() {
      if (id == null) {
        _lockedByTask.remove(widget.task.id);
      } else {
        _lockedByTask[widget.task.id] = id;
      }
    });
  }

  Future<void> _openHistory(List<AgentEvent> history, String? currentId) async {
    final picked = await showFocusHistorySheet(
      context,
      history: history,
      currentId: currentId,
    );
    if (picked == null || !mounted) return;
    // 选的就是最新一条 = 回到跟随。
    _setLocked(picked == history.firstOrNull?.id ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isLoading = ref.watch(
      agentTaskEventsProvider(
        task.id,
      ).select((a) => a.isLoading && !a.hasValue),
    );
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final latest = ref.watch(
      agentTimelineProvider(task.id).select((v) => v.latestFocus),
    );
    final history = ref
        .watch(
          agentTaskEventsProvider(
            task.id,
          ).select((a) => _historyOf(a.value ?? const [])),
        )
        .items;
    final lockedId = _lockedByTask[task.id];
    final lockedIndex = lockedId == null
        ? -1
        : history.indexWhere((e) => e.id == lockedId);
    // 锁定的活动已滑出历史窗口：静默回到跟随。
    final locked = lockedIndex >= 0 ? history[lockedIndex] : null;
    final focus = locked ?? latest;
    if (focus == null) return const _EmptyFocus();
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FocusTopBar(
            locked: locked != null,
            newer: lockedIndex < 0 ? 0 : lockedIndex,
            historyCount: history.length,
            onHistory: () => _openHistory(history, focus.id),
            onBackToLatest: () => _setLocked(null),
          ),
          Expanded(
            child: _FocusView(
              key: ValueKey(focus.id),
              event: focus,
              taskId: task.id,
              workspaceId: task.workspaceId,
            ),
          ),
          _FocusActionDock(task: task, focus: focus, history: history),
        ],
      ),
    );
  }
}

/// 顶部状态行：跟随中 / 已锁定（N 条更新 + 回到最新），右侧「历史」按钮。
class _FocusTopBar extends StatelessWidget {
  const _FocusTopBar({
    required this.locked,
    required this.newer,
    required this.historyCount,
    required this.onHistory,
    required this.onBackToLatest,
  });

  final bool locked;
  final int newer;
  final int historyCount;
  final VoidCallback onHistory;
  final VoidCallback onBackToLatest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: locked
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.pin, size: 13, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            newer > 0 ? '已锁定 · 有 $newer 条更新' : '已锁定',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onBackToLatest,
                          child: Text(
                            '回到最新',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Icon(LucideIcons.radio, size: 13, color: muted),
                      const SizedBox(width: 6),
                      Text(
                        '跟随最新',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: historyCount == 0 ? null : onHistory,
            icon: const Icon(LucideIcons.history, size: 14),
            label: Text('历史 $historyCount'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

enum _HistoryFilter { all, command, change, failed }

bool _matchesFilter(AgentEvent e, _HistoryFilter f) {
  if (f == _HistoryFilter.all) return true;
  if (e is! ToolCallEvent) return false;
  return switch (f) {
    _HistoryFilter.command => _isTerminalTool(e.toolName),
    _HistoryFilter.change => toolChangedFilePaths(
      e.toolName,
      e.argsDetail ?? '',
      resultText: e.resultDetail,
    ).isNotEmpty,
    _HistoryFilter.failed => e.state == AgentToolCallState.failure,
    _HistoryFilter.all => true,
  };
}

/// 历史条目的图标 + 一行标题。
(IconData, String) _historyLabel(AgentEvent e) => switch (e) {
  final ToolCallEvent t => (
    _toolIcon(t.toolName),
    toolCommandText(t.toolName, t.argsDetail ?? '')?.trim() ??
        (t.argSummary.isEmpty ? t.toolName : '${t.toolName}  ${t.argSummary}'),
  ),
  final ReasoningEvent r => (
    LucideIcons.brain,
    r.streaming ? '思考中…' : '思考 · ${_firstLine(r.text)}',
  ),
  final AssistantTextEvent a => (
    LucideIcons.messageSquareText,
    '汇报 · ${_firstLine(a.text)}',
  ),
  final UserMessageEvent u => (
    LucideIcons.user,
    FinishGuards.isEngineInjected(u.text)
        ? '系统提示'
        : '用户 · ${_firstLine(u.text)}',
  ),
  PlanUpdateEvent() => (LucideIcons.listChecks, '计划更新'),
  _ => (LucideIcons.circle, ''),
};

String _firstLine(String text) {
  final line = text.trim().split('\n').first;
  return line.length > 60 ? '${line.substring(0, 60)}…' : line;
}

bool _isLive(AgentEvent e) => switch (e) {
  final ToolCallEvent t =>
    t.state == AgentToolCallState.running ||
        t.state == AgentToolCallState.waitingApproval,
  final ReasoningEvent r => r.streaming,
  final AssistantTextEvent a => a.streaming,
  _ => false,
};

/// 底部弹出「本轮活动」面板：新→旧列出最近活动，可筛选；返回选中的
/// 活动 id（下拉关闭返回 null）。
Future<String?> showFocusHistorySheet(
  BuildContext context, {
  required List<AgentEvent> history,
  String? currentId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.62,
      child: _FocusHistorySheet(history: history, currentId: currentId),
    ),
  );
}

class _FocusHistorySheet extends StatefulWidget {
  const _FocusHistorySheet({required this.history, this.currentId});

  final List<AgentEvent> history;
  final String? currentId;

  @override
  State<_FocusHistorySheet> createState() => _FocusHistorySheetState();
}

class _FocusHistorySheetState extends State<_FocusHistorySheet> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);
    final items = [
      for (final e in widget.history)
        if (_matchesFilter(e, _filter)) e,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 32,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('本轮活动', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${widget.history.length} 条',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 6,
            children: [
              for (final (f, label) in const [
                (_HistoryFilter.all, '全部'),
                (_HistoryFilter.command, '命令'),
                (_HistoryFilter.change, '改动'),
                (_HistoryFilter.failed, '失败'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _filter == f,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    '没有符合条件的活动',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    final (icon, title) = _historyLabel(e);
                    final live = _isLive(e);
                    final current = e.id == widget.currentId;
                    Widget? trailing;
                    if (e is ToolCallEvent) {
                      final (label, color) = _stateLabel(context, e.state);
                      trailing = Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                        ),
                      );
                    } else if (live) {
                      trailing = Text(
                        '进行中',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.primary,
                        ),
                      );
                    }
                    return ListTile(
                      dense: true,
                      selected: current,
                      selectedTileColor: cs.primary.withValues(alpha: 0.08),
                      tileColor: live
                          ? cs.primary.withValues(alpha: 0.04)
                          : null,
                      leading: Icon(icon, size: 16),
                      minLeadingWidth: 18,
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: e is ToolCallEvent ? 'monospace' : null,
                        ),
                      ),
                      trailing: trailing,
                      onTap: () => Navigator.of(context).pop(e.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyFocus extends StatelessWidget {
  const _EmptyFocus();

  @override
  Widget build(BuildContext context) {
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

/// 工具结果多为 `{success, data}` JSON，直接贴原文不可读；这里提取
/// data 里的正文字段（content/stdout/output/…）还原换行后展示，
/// 解不出时回退原文。
String _readableResult(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return raw;
  }
  if (decoded is! Map) return raw;
  final error = decoded['error'];
  if (error is String && error.isNotEmpty) return error;
  final data = decoded['data'];
  if (data is String) return data;
  if (data is Map) {
    for (final key in const [
      'content',
      'stdout',
      'output',
      'text',
      'message',
    ]) {
      final v = data[key];
      if (v is String && v.isNotEmpty) {
        final stderr = data['stderr'];
        final hint = data['hint'];
        return [
          v,
          if (stderr is String && stderr.trim().isNotEmpty) 'stderr:\n$stderr',
          if (hint is String && hint.isNotEmpty) hint,
        ].join('\n');
      }
    }
    final stderr = data['stderr'];
    if (stderr is String && stderr.trim().isNotEmpty) {
      return 'stderr:\n$stderr';
    }
  }
  return raw;
}

/// 从（可能未闭合的）参数 JSON 里提取 [key] 字符串值的已生成前缀，
/// 用于工具参数仍在流式生成时的实时预览；找不到该字段返回 null。
/// [tailChars] 限定只解码值的尾部窗口：预览只展示尾部几百行，
/// 没必要每个 delta 都从头重解码整个值（那是累计平方级开销）。
String? _partialStringField(String raw, String key, {int? tailChars}) {
  final marker = '"$key"';
  var i = raw.indexOf(marker);
  if (i < 0) return null;
  i = raw.indexOf(':', i + marker.length);
  if (i < 0) return null;
  i = raw.indexOf('"', i + 1);
  if (i < 0) return null;
  final sb = StringBuffer();
  var j = i + 1;
  if (tailChars != null && raw.length - j > tailChars) {
    j = raw.length - tailChars;
    // 窗口起点可能落在转义序列中间：前面连续反斜杠为奇数时后移一位对齐。
    var bs = 0;
    while (j - 1 - bs > i && raw[j - 1 - bs] == r'\') {
      bs++;
    }
    if (bs.isOdd) j++;
  }
  while (j < raw.length) {
    final c = raw[j];
    if (c == r'\') {
      if (j + 1 >= raw.length) break; // 尾部未完成的转义序列
      final n = raw[j + 1];
      switch (n) {
        case 'n':
          sb.write('\n');
        case 't':
          sb.write('\t');
        case 'r':
          sb.write('\r');
        case 'u':
          if (j + 6 <= raw.length) {
            final code = int.tryParse(raw.substring(j + 2, j + 6), radix: 16);
            if (code != null) sb.writeCharCode(code);
            j += 4;
          } else {
            j = raw.length;
          }
        default:
          sb.write(n);
      }
      j += 2;
    } else if (c == '"') {
      break;
    } else {
      sb.write(c);
      j++;
    }
  }
  return sb.toString();
}

/// 从参数 JSON 里解析编辑类工具的 search/replace 对
/// （单对或 edits 数组）；写入类工具的全文内容返回 (null, content)。
/// 参数 JSON 未闭合（仍在流式生成）时按前缀提取，供实时预览。
List<({String? search, String replace})> _editPairsOf(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    final search = _partialStringField(raw, 'search');
    final replace =
        _partialStringField(raw, 'replace', tailChars: _kStreamingTailChars) ??
        _partialStringField(raw, 'content', tailChars: _kStreamingTailChars) ??
        _partialStringField(raw, 'file_text', tailChars: _kStreamingTailChars);
    if (search == null && replace == null) return const [];
    return [(search: search, replace: replace ?? '')];
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
      (
        search: decoded['search'] as String,
        replace: '${decoded['replace'] ?? ''}',
      ),
    ];
  }
  final content = decoded['content'] ?? decoded['file_text'];
  if (content is String && content.isNotEmpty) {
    return [(search: null, replace: content)];
  }
  return const [];
}

/// 流式生成期间 diff 预览只保留的尾部行数（跟随最新内容，控制重建成本）。
const int _kStreamingTailLines = 300;

/// 流式预览解码值的尾部窗口字符数（足够盖住尾部 300 行）。
const int _kStreamingTailChars = 32000;

/// 终端输出展示的尾部行数上限（全量 SelectableText 对百 KB 级输出
/// 每次重建都要全文本 layout）。
const int _kTerminalTailLines = 500;

String _tailLines(String text, int maxLines) {
  var idx = text.length;
  var count = 0;
  while (count < maxLines && idx > 0) {
    final nl = text.lastIndexOf('\n', idx - 1);
    if (nl < 0) return text;
    idx = nl;
    count++;
  }
  if (idx <= 0) return text;
  return '……（前面输出已省略）${text.substring(idx)}';
}

/// 单个 search/replace 对的 diff 行。整文件写入（search 为空）时全部是
/// 新增行，直接构造；[streaming] 期间 search/replace 也不跑 LCS（O(n·m)
/// 且每个 delta 都会重算），直接按删除块 + 新增块展示，完成后才算精确 diff。
List<DiffLine> _diffRowsOf(
  ({String? search, String replace}) p, {
  bool streaming = false,
}) {
  final search = p.search;
  if (search == null || search.isEmpty) {
    final lines = p.replace.split('\n');
    return [
      for (var i = 0; i < lines.length; i++)
        DiffLine(DiffLineKind.added, lines[i], newLine: i + 1),
    ];
  }
  if (streaming) {
    final removed = search.split('\n');
    final added = p.replace.split('\n');
    return [
      for (var i = 0; i < removed.length; i++)
        DiffLine(DiffLineKind.removed, removed[i], oldLine: i + 1),
      for (var i = 0; i < added.length; i++)
        DiffLine(DiffLineKind.added, added[i], newLine: i + 1),
    ];
  }
  return computeLineDiff(search, p.replace);
}

/// 当前活动的单一全屏视图：头部（活动类型/状态）+ 占满余下高度的产物区。
class _FocusView extends StatelessWidget {
  const _FocusView({
    required this.event,
    required this.taskId,
    required this.workspaceId,
    super.key,
  });

  final AgentEvent event;
  final String taskId;
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return switch (e) {
      final ToolCallEvent t => _ToolFocus(
        event: t,
        taskId: taskId,
        workspaceId: workspaceId,
      ),
      final ReasoningEvent r => _TextFocus(
        icon: LucideIcons.brain,
        title: r.streaming
            ? '思考中…'
            : (r.elapsed == null ? '思考' : '思考了 ${r.elapsed!.inSeconds}s'),
        text: r.text,
        muted: true,
        streaming: r.streaming,
      ),
      final AssistantTextEvent a => _TextFocus(
        icon: LucideIcons.messageSquareText,
        title: a.streaming ? '汇报中…' : '汇报',
        text: a.text,
        streaming: a.streaming,
      ),
      final UserMessageEvent u => _TextFocus(
        icon: LucideIcons.user,
        title: FinishGuards.isEngineInjected(u.text)
            ? '系统提示（发给模型）'
            : (u.queued ? '用户指令（排队追加）' : '用户指令'),
        text: u.text,
      ),
      final PlanUpdateEvent p => _PlanFocus(event: p),
      _ => const _EmptyFocus(),
    };
  }
}

/// 头部行：图标 + 标题 + 尾部状态。
class _FocusHeader extends StatelessWidget {
  const _FocusHeader({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
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
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 工具活动：终端→命令+输出、编辑→红绿 diff、其他→输出内容。
/// 参数仍在流式生成时直接消费内存实时通道（每个 delta 都刷新），
/// 不依赖落库节流。点头部打开完整详情抽屉。
class _ToolFocus extends ConsumerWidget {
  const _ToolFocus({
    required this.event,
    required this.taskId,
    required this.workspaceId,
  });

  final ToolCallEvent event;
  final String taskId;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (label, color) = _stateLabel(context, event.state);
    final live = ref.watch(agentToolStreamProvider.select((m) => m[event.id]));
    final args = live?.argsText ?? event.argsDetail;

    Widget body;
    if (_isTerminalTool(event.toolName)) {
      var cmd = event.argSummary;
      if (args != null) {
        final c = _partialStringField(args, 'command');
        if (c != null && c.isNotEmpty) cmd = c;
      }
      if (event.state == AgentToolCallState.running) {
        // 执行中：直接接会话 PTY 看实况（ANSI 颜色原样渲染、自动跟随底部）。
        body = _LiveTerminalPane(
          workspaceId: workspaceId,
          command: cmd,
          sessionRef: terminalToolSessionRef(
            argsDetail: args,
            resultDetail: event.resultDetail,
          ),
        );
      } else {
        final out = _tailLines(
          event.resultDetail == null
              ? event.resultSummary
              : _readableResult(event.resultDetail!),
          _kTerminalTailLines,
        );
        body = _MonoPane(
          text: cleanTerminalText('\$ $cmd\n$out'),
          dark: true,
          startAtEnd: true,
        );
      }
    } else {
      final pairs = _editPairsOf(args);
      if (pairs.isNotEmpty) {
        // IDE 式行级红绿 diff（与 Changes tab 同款 Devin 风格行渲染）；
        // 参数仍在流式生成时随内容增长实时更新。行懒加载 + 流式期间
        // 只保留尾部窗口，避免高频重建整树拖死主线程。
        final streaming =
            live != null || event.state == AgentToolCallState.running;
        var rows = <DiffLine>[
          for (var i = 0; i < pairs.length; i++) ...[
            if (i > 0) const DiffLine(DiffLineKind.skip, ''),
            ..._diffRowsOf(pairs[i], streaming: streaming),
          ],
        ];
        if (streaming && rows.length > _kStreamingTailLines) {
          rows = [
            const DiffLine(DiffLineKind.skip, ''),
            ...rows.sublist(rows.length - _kStreamingTailLines),
          ];
        }
        body = Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: DevinDiffLinesLazy(rows: rows, followTail: streaming),
        );
      } else {
        var detail = _tailLines(
          event.resultDetail == null
              ? event.resultSummary
              : _readableResult(event.resultDetail!),
          _kTerminalTailLines,
        );
        // 非编辑/终端类工具（如 pptx_render 的 deck JSON）参数仍在
        // 流式生成时，直接跟随原始参数文本尾部，保持与其他工具一致
        // 的实时反馈；执行完成后切回结果展示。
        if (detail.isEmpty && args != null && args.isNotEmpty) {
          detail = _tailLines(args, _kStreamingTailLines);
        }
        body = _MonoPane(
          text: detail.isEmpty ? '（暂无输出）' : detail,
          // 参数仍在流式生成时跟随尾部。
          follow: live != null,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FocusHeader(
          icon: _toolIcon(event.toolName),
          title: event.argSummary.isEmpty
              ? event.toolName
              : '${event.toolName}  ${event.argSummary}',
          trailing: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
          onTap: () => showToolDetailSheet(context, event, taskId: taskId),
        ),
        Expanded(child: body),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// 思考/汇报/用户指令：正文占满余下高度滚动。
class _TextFocus extends StatelessWidget {
  const _TextFocus({
    required this.icon,
    required this.title,
    required this.text,
    this.muted = false,
    this.streaming = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool muted;

  /// 流式生成中：停在底部时自动跟随新内容。
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FocusHeader(icon: icon, title: title),
        Expanded(
          child: _FollowScroll(
            content: text,
            follow: streaming,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              text.isEmpty ? '（尚无内容）' : text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: muted ? mutedColor : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 等宽产物面板：占满高度内部滚动；[dark] 为终端风格深底。
class _MonoPane extends StatelessWidget {
  const _MonoPane({
    required this.text,
    this.dark = false,
    this.follow = false,
    this.startAtEnd = false,
  });

  final String text;
  final bool dark;

  /// 内容增长时（用户停在底部才）自动跟随。
  final bool follow;

  /// 首次显示即定位到底部（终端结果：错误通常在尾部）。
  final bool startAtEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = dark
        ? const Color(0xFF14161B)
        : cs.onSurface.withValues(alpha: 0.04);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: _FollowScroll(
        content: text,
        follow: follow,
        startAtEnd: startAtEnd,
        padding: const EdgeInsets.all(10),
        child: SelectableText(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.4,
            color: dark ? Colors.white.withValues(alpha: 0.9) : null,
          ),
        ),
      ),
    );
  }
}

/// 计划快照：三态勾选清单。
class _PlanFocus extends StatelessWidget {
  const _PlanFocus({required this.event});

  final PlanUpdateEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mutedColor = cs.onSurface.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FocusHeader(icon: LucideIcons.listChecks, title: '计划更新'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (event.items.isEmpty)
                Text(
                  '计划已全部完成，清单已清空',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedColor,
                  ),
                ),
              for (final item in event.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        switch (item.status) {
                          AgentPlanItemStatus.completed =>
                            LucideIcons.circleCheck,
                          AgentPlanItemStatus.inProgress =>
                            LucideIcons.circleDot,
                          AgentPlanItemStatus.pending => LucideIcons.circle,
                        },
                        size: 15,
                        color: switch (item.status) {
                          AgentPlanItemStatus.completed => Colors.green,
                          AgentPlanItemStatus.inProgress => cs.primary,
                          AgentPlanItemStatus.pending => mutedColor,
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 带「贴底跟随」的滚动容器：用户停在底部（40px 内）时 [content] 变化即
/// 跳到底；用户往上翻看后不打扰，滚回底部恢复跟随。
class _FollowScroll extends StatefulWidget {
  const _FollowScroll({
    required this.content,
    required this.child,
    this.follow = false,
    this.startAtEnd = false,
    this.padding,
  });

  final Object content;
  final Widget child;
  final bool follow;
  final bool startAtEnd;
  final EdgeInsetsGeometry? padding;

  @override
  State<_FollowScroll> createState() => _FollowScrollState();
}

class _FollowScrollState extends State<_FollowScroll> {
  final ScrollController _controller = ScrollController();
  bool _stick = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      _stick = _controller.position.extentAfter < 40;
    });
    if (widget.startAtEnd || widget.follow) _jumpToEnd();
  }

  @override
  void didUpdateWidget(covariant _FollowScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.follow && _stick && oldWidget.content != widget.content) {
      _jumpToEnd();
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: _controller,
    padding: widget.padding,
    child: widget.child,
  );
}

/// ANSI CSI / OSC / 字符集 / 单字符转义。
final RegExp _ansiSeq = RegExp(
  r'\x1b\[[0-9;?<=>!]*[ -/]*[@-~]'
  r'|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)'
  r'|\x1b[()][0-9A-Za-z]'
  r'|\x1b[=>78DEHMc]',
);

/// 终端结果转纯文本：去掉 ANSI 控制序列；行内 `\r` 回车覆盖（进度条）
/// 只保留最后一段，`\r\n` 视为普通换行。
@visibleForTesting
String cleanTerminalText(String text) {
  final plain = text.replaceAll(_ansiSeq, '');
  return plain
      .split('\n')
      .map((line) {
        final l = line.endsWith('\r')
            ? line.substring(0, line.length - 1)
            : line;
        final i = l.lastIndexOf('\r');
        return i < 0 ? l : l.substring(i + 1);
      })
      .join('\n');
}

/// 执行中的终端命令：找到它所在的会话，直接挂会话 PTY 视图（只读）。
/// 优先按结果 / 参数里的会话 ID / 名称，其次找本工作区里正在跑同一条
/// 命令的 AI 会话；都找不到时显示等待提示。
class _LiveTerminalPane extends ConsumerWidget {
  const _LiveTerminalPane({
    required this.workspaceId,
    required this.command,
    this.sessionRef,
  });

  final String workspaceId;
  final String command;
  final String? sessionRef;

  PooledWorkspaceSession? _resolve(WorkspaceSessionPoolManager manager) {
    final sessions = agentAliveSessions(manager, workspaceId);
    final ref = sessionRef;
    if (ref != null) {
      final hit =
          sessions.where((s) => s.id == ref).firstOrNull ??
          sessions.where((s) => s.name == ref).firstOrNull;
      if (hit != null) return hit;
    }
    final cmd = command.trim();
    return sessions
        .where((s) => s.busy && s.currentCommand?.trim() == cmd)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(agentSessionPoolManagerProvider);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final session = _resolve(manager);
        if (session == null) {
          return _MonoPane(text: '\$ $command\n（等待会话输出…）', dark: true);
        }
        return _SessionLiveView(key: ValueKey(session.id), session: session);
      },
    );
  }
}

class _SessionLiveView extends ConsumerStatefulWidget {
  const _SessionLiveView({required this.session, super.key});

  final PooledWorkspaceSession session;

  @override
  ConsumerState<_SessionLiveView> createState() => _SessionLiveViewState();
}

class _SessionLiveViewState extends ConsumerState<_SessionLiveView> {
  late final SessionTerminalAttachment _view = SessionTerminalAttachment(
    widget.session,
  );

  @override
  void dispose() {
    _view.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(terminalFontSizeProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14161B),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: TerminalView(
          _view.terminal,
          controller: _view.controller,
          focusNode: _view.focusNode,
          readOnly: true,
          textStyle: TerminalStyle(fontSize: fontSize),
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }
}

/// 焦点底部就地操作条，按优先级只显示一种：
/// 1. 有挂起审批 → 批准 / 拒绝 / 更多授权（不管当前看的是哪条，都置顶处理）；
/// 2. 等待回答提问 → 问题 + 建议答案 + 自定义输入；
/// 3. 正在看的是执行中的工具 → 终端：告知在等输入 / 在终端中查看 / 中断；
///    其他工具：中断。
/// 其余情况不占位。
class _FocusActionDock extends ConsumerWidget {
  const _FocusActionDock({
    required this.task,
    required this.focus,
    required this.history,
  });

  final AgentTask task;
  final AgentEvent focus;
  final List<AgentEvent> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(agentApprovalRegistryProvider)[task.id];
    if (pending != null) {
      final waiting = history
          .whereType<ToolCallEvent>()
          .where((e) => e.state == AgentToolCallState.waitingApproval)
          .firstOrNull;
      return _ApprovalDock(
        taskId: task.id,
        title: waiting == null
            ? pending.call.name
            : '${waiting.toolName} ${waiting.argSummary}',
        patterns: pending.alwaysPatterns,
      );
    }
    if (task.status == AgentTaskStatus.waitingInput) {
      final question = ref.watch(
        agentTimelineProvider(task.id).select((v) => v.pendingQuestion),
      );
      if (question != null) return _QuestionDock(task: task, question: question);
    }
    final f = focus;
    if (f is ToolCallEvent && f.state == AgentToolCallState.running) {
      return _RunningToolDock(task: task, event: f);
    }
    return const SizedBox.shrink();
  }
}

/// 操作条外壳：顶部分隔线 + 内边距 + 可选强调底色。
class _DockShell extends StatelessWidget {
  const _DockShell({required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: accent?.withValues(alpha: 0.06) ?? cs.surface,
        border: Border(
          top: BorderSide(
            color: accent?.withValues(alpha: 0.45) ?? Theme.of(context).dividerColor,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: child,
    );
  }
}

class _ApprovalDock extends ConsumerWidget {
  const _ApprovalDock({
    required this.taskId,
    required this.title,
    required this.patterns,
  });

  final String taskId;
  final String title;
  final List<String> patterns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const orange = Colors.orange;
    void respond(AgentApprovalDecision d) =>
        ref.read(agentApprovalRegistryProvider.notifier).respond(taskId, d);
    return _DockShell(
      accent: orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.triangleAlert, size: 14, color: orange),
              const SizedBox(width: 6),
              Text(
                '等待授权',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      respond(const AgentApprovalDecision(approved: true)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('批准'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => respond(
                    const AgentApprovalDecision(
                      approved: false,
                      reason: '用户拒绝',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('拒绝'),
                ),
              ),
              const SizedBox(width: 8),
              ApprovalGrantMenuButton(
                enabled: true,
                patterns: patterns,
                onSelected: respond,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionDock extends ConsumerStatefulWidget {
  const _QuestionDock({required this.task, required this.question});

  final AgentTask task;
  final UserQuestionEvent question;

  @override
  ConsumerState<_QuestionDock> createState() => _QuestionDockState();
}

class _QuestionDockState extends ConsumerState<_QuestionDock> {
  final TextEditingController _input = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit(String answer) async {
    final text = answer.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(agentTaskRunnerProvider.notifier)
          .answerUserQuestion(widget.task, widget.question, text);
      _input.clear();
    } on StateError catch (e) {
      if (mounted) AppToast.error(context, e.message.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final q = widget.question;
    return _DockShell(
      accent: cs.primary,
      child: ConstrainedBox(
        // 长问题 / 多建议时不挤掉上方产物区。
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.38,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.messageCircleQuestion,
                    size: 14,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      q.question,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              for (final s in q.suggestions)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => _submit(s),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(s, textAlign: TextAlign.left),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_submitting,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _submit,
                      style: theme.textTheme.bodySmall,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '自定义回答…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _submitting ? null : () => _submit(_input.text),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.send, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunningToolDock extends ConsumerWidget {
  const _RunningToolDock({required this.task, required this.event});

  final AgentTask task;
  final ToolCallEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminal = _isTerminalTool(event.toolName) &&
        event.toolName != 'run_command';
    final sessionRef = terminal
        ? terminalToolSessionRef(
            argsDetail: ref.watch(
                  agentToolStreamProvider.select((m) => m[event.id]?.argsText),
                ) ??
                event.argsDetail,
            resultDetail: event.resultDetail,
          )
        : null;

    void markWaiting() {
      final count = ref
          .read(agentSessionPoolManagerProvider)
          .markWaitingInputAll(
            sessionRef: sessionRef,
            workspaceId: task.workspaceId.isEmpty ? null : task.workspaceId,
          );
      AppToast.info(
        context,
        count > 0 ? '已告知 AI：命令在等交互输入' : '当前没有正在等结果的命令',
      );
    }

    void interrupt() {
      ref.read(agentTaskRunnerProvider.notifier).interruptTool(task.id);
      AppToast.info(context, '已中断当前操作，AI 会根据结果继续');
    }

    return _DockShell(
      child: Row(
        children: [
          if (terminal) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: markWaiting,
                icon: const Icon(LucideIcons.keyboard, size: 14),
                label: const Text('在等输入'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref
                    .read(agentTerminalFocusProvider.notifier)
                    .request(task.id, sessionRef: sessionRef),
                icon: const Icon(LucideIcons.terminal, size: 14),
                label: const Text('终端'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else
            const Spacer(),
          OutlinedButton.icon(
            onPressed: interrupt,
            icon: const Icon(LucideIcons.octagonX, size: 14),
            label: const Text('中断'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
