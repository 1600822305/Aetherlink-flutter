import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/devin_diff_lines.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tool_detail_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';

/// 工作台「焦点」tab（UI 稿 §4.3）：只显示「当前最新活动」的单一视图，
/// 活动切换时整块跟着变——终端工具→命令+实况输出、文件编辑→
/// search/replace 红绿 diff、读文件→内容片段、思考/汇报/用户消息→
/// 正文。产物区占满余下高度，点头部打开完整详情抽屉。
class WorkbenchFocusTab extends ConsumerWidget {
  const WorkbenchFocusTab({required this.task, super.key});

  final AgentTask task;

  /// 最新的「有产物可看」的活动（跳过检查点/压缩等标记事件）。
  AgentEvent? _latestFocus(List<AgentEvent> events) {
    for (var i = events.length - 1; i >= 0; i--) {
      final e = events[i];
      if (e is ToolCallEvent ||
          e is ReasoningEvent ||
          e is AssistantTextEvent ||
          e is UserMessageEvent ||
          e is PlanUpdateEvent) {
        return e;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(agentTaskEventsProvider(task.id));
    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载事件失败：$e')),
      data: (events) {
        final focus = _latestFocus(events);
        if (focus == null) return const _EmptyFocus();
        return SafeArea(
          top: false,
          child: _FocusView(event: focus, taskId: task.id),
        );
      },
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
          if (stderr is String && stderr.trim().isNotEmpty)
            'stderr:\n$stderr',
          if (hint is String && hint.isNotEmpty) hint,
        ].join('\n');
      }
    }
  }
  return raw;
}

/// 从（可能未闭合的）参数 JSON 里提取 [key] 字符串值的已生成前缀，
/// 用于工具参数仍在流式生成时的实时预览；找不到该字段返回 null。
String? _partialStringField(String raw, String key) {
  final marker = '"$key"';
  var i = raw.indexOf(marker);
  if (i < 0) return null;
  i = raw.indexOf(':', i + marker.length);
  if (i < 0) return null;
  i = raw.indexOf('"', i + 1);
  if (i < 0) return null;
  final sb = StringBuffer();
  var j = i + 1;
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
            final code =
                int.tryParse(raw.substring(j + 2, j + 6), radix: 16);
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
    final replace = _partialStringField(raw, 'replace') ??
        _partialStringField(raw, 'content') ??
        _partialStringField(raw, 'file_text');
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

/// 单个 search/replace 对的 diff 行。整文件写入（search 为空）时全部是
/// 新增行，直接构造，不跑 LCS diff 算法（流式高频重建下省掉无谓开销）。
List<DiffLine> _diffRowsOf(({String? search, String replace}) p) {
  final search = p.search;
  if (search == null || search.isEmpty) {
    final lines = p.replace.split('\n');
    return [
      for (var i = 0; i < lines.length; i++)
        DiffLine(DiffLineKind.added, lines[i], newLine: i + 1),
    ];
  }
  return computeLineDiff(search, p.replace);
}

/// 当前活动的单一全屏视图：头部（活动类型/状态）+ 占满余下高度的产物区。
class _FocusView extends StatelessWidget {
  const _FocusView({required this.event, required this.taskId});

  final AgentEvent event;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return switch (e) {
      final ToolCallEvent t => _ToolFocus(event: t, taskId: taskId),
      final ReasoningEvent r => _TextFocus(
          icon: LucideIcons.brain,
          title: r.streaming
              ? '思考中…'
              : (r.elapsed == null ? '思考' : '思考了 ${r.elapsed!.inSeconds}s'),
          text: r.text,
          muted: true,
        ),
      final AssistantTextEvent a => _TextFocus(
          icon: LucideIcons.messageSquareText,
          title: a.streaming ? '汇报中…' : '汇报',
          text: a.text,
        ),
      final UserMessageEvent u => _TextFocus(
          icon: LucideIcons.user,
          title: u.queued ? '用户指令（排队追加）' : '用户指令',
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
  const _ToolFocus({required this.event, required this.taskId});

  final ToolCallEvent event;
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (label, color) = _stateLabel(context, event.state);
    final live = ref.watch(
      agentToolStreamProvider.select((m) => m[event.id]),
    );
    final args = live?.argsText ?? event.argsDetail;

    Widget body;
    if (_isTerminalTool(event.toolName)) {
      var cmd = event.argSummary;
      if (args != null) {
        final c = _partialStringField(args, 'command');
        if (c != null && c.isNotEmpty) cmd = c;
      }
      final out = event.resultDetail == null
          ? event.resultSummary
          : _readableResult(event.resultDetail!);
      body = _MonoPane(
        text: '\$ $cmd\n$out',
        dark: true,
      );
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
            ..._diffRowsOf(pairs[i]),
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
          child: DevinDiffLinesLazy(rows: rows),
        );
      } else {
        final detail = event.resultDetail == null
            ? event.resultSummary
            : _readableResult(event.resultDetail!);
        body = _MonoPane(text: detail.isEmpty ? '（暂无输出）' : detail);
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
  });

  final IconData icon;
  final String title;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FocusHeader(icon: icon, title: title),
        Expanded(
          child: SingleChildScrollView(
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
  const _MonoPane({required this.text, this.dark = false});

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg =
        dark ? const Color(0xFF14161B) : cs.onSurface.withValues(alpha: 0.04);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
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
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.3),
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
