import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_task_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_tool_detail.dart';
import 'package:aetherlink_flutter/features/agent/application/timeline_blocks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tool_detail_sheet.dart';

/// 工具行（方案 C）：命令类工具用深色终端小块显示完整命令（最多 2 行）
/// + 元信息行；其余工具一行「中文动词 · 对象（文件名/关键词）· 右侧结果」。
/// 未识别的工具（MCP 等）动词显示原工具名。点击 → 底部抽屉看完整参数/输出。
class ToolRow extends StatelessWidget {
  const ToolRow({required this.event, required this.taskId, super.key});

  final ToolCallEvent event;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final failed = event.state == AgentToolCallState.failure;
    final running = event.state == AgentToolCallState.running;
    final (icon, iconColor) = switch (event.state) {
      AgentToolCallState.running => (LucideIcons.loaderCircle, cs.primary),
      AgentToolCallState.success => (LucideIcons.circleCheck, Colors.green),
      AgentToolCallState.failure => (LucideIcons.circleX, cs.error),
      AgentToolCallState.denied => (LucideIcons.ban, muted),
      AgentToolCallState.waitingApproval => (
        LucideIcons.circleAlert,
        Colors.orange,
      ),
    };
    final args = _args(event.argsDetail);
    final command = toolCommandText(event.toolName, event.argsDetail ?? '');
    final meta = _meta(event);
    final metaColor = failed ? cs.error : (running ? cs.primary : muted);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');

    final Widget body;
    if (command != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2228),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: r'$ ',
                    style: TextStyle(color: Color(0xFF7FC48D)),
                  ),
                  TextSpan(text: command.trim()),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: mono?.copyWith(
                color: const Color(0xFFE6E1D8),
                height: 1.45,
              ),
            ),
          ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                meta,
                style: theme.textTheme.labelSmall?.copyWith(color: metaColor),
              ),
            ),
        ],
      );
    } else {
      final verb = _verbOf(event.toolName);
      final target = _targetOf(event.toolName, args) ?? event.argSummary;
      final stats = toolLineStats(event);
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            verb,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: failed ? cs.error : null,
              fontFamily: verb == event.toolName ? 'monospace' : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono?.copyWith(color: muted),
            ),
          ),
          const SizedBox(width: 6),
          if (stats.added + stats.removed > 0)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '+${stats.added}',
                    style: const TextStyle(color: Colors.green),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: '−${stats.removed}',
                    style: TextStyle(color: cs.error),
                  ),
                ],
              ),
              style: theme.textTheme.labelSmall,
            )
          else if (meta.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: metaColor),
              ),
            ),
        ],
      );
    }

    return EventRail(
      node: running
          ? SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            )
          : Icon(icon, size: 14, color: iconColor),
      child: InkWell(
        onTap: () => showToolDetailSheet(context, event, taskId: taskId),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              body,
              // 自动检测漏网时的手动兜底：用户看到命令在等交互输入，
              // 点一下让正在等结果的 exec 提前把控制权和已有输出还给模型。
              if (running && event.toolName == 'terminal_execute')
                _WaitingInputButton(
                  argsDetail: event.argsDetail,
                  taskId: taskId,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _args(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final v = jsonDecode(raw);
    return v is Map<String, dynamic> ? v : const {};
  } on FormatException {
    return const {};
  }
}

/// 内置工具 → 中文动词；未识别的返回原工具名。
String _verbOf(String tool) => switch (tool) {
  'read_file' || 'kb_read' || 'pptx_read' || 'pptx_outline' => '读取',
  'write' || 'pptx_draft' => '写入',
  'edit' || 'pptx_edit' || 'pptx_modify' => '编辑',
  'move' => '移动',
  'delete_file' => '删除',
  'create_directory' => '新建目录',
  'list_files' || 'kb_list' => '列出',
  'search_files' || 'kb_search' => '搜索',
  'web_search' || 'searxng_search' || 'metaso_search' => '联网搜索',
  'fetch' || 'searxng_read_url' || 'metaso_reader' || 'browser_read' => '读取网页',
  'browser_open' => '打开网页',
  'browser_click' => '点击',
  'browser_input' => '输入',
  'browser_snapshot' || 'browser_snapshot_dom' || 'pptx_snapshot' => '截图',
  'pptx_render' => '渲染',
  'terminal_execute' || 'terminal_session' || 'run_command' => '运行',
  'read_skill' => '读取技能',
  _ => tool,
};

/// 一行里显示的对象：路径只留文件名，搜索显示关键词，网页显示网址。
String? _targetOf(String tool, Map<String, dynamic> args) {
  String? str(String k) {
    final v = args[k];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  final path = str('path') ?? str('file') ?? str('source_path') ?? str('source');
  final query = str('query') ?? str('pattern') ?? str('keyword') ?? str('regex');
  final url = str('url');
  final name = str('name') ?? str('skill');
  if (tool.contains('search') && query != null) {
    return path == null ? query : '$query · ${_base(path)}';
  }
  if (url != null) return url.replaceFirst(RegExp(r'^https?://'), '');
  if (path != null) return _base(path);
  return query ?? name;
}

String _base(String path) {
  final norm = path.replaceAll('\\', '/');
  final trimmed = norm.endsWith('/') && norm.length > 1
      ? norm.substring(0, norm.length - 1)
      : norm;
  final i = trimmed.lastIndexOf('/');
  return i < 0 ? trimmed : trimmed.substring(i + 1);
}

/// 右侧/命令块下方的元信息：结果摘要（去掉与状态图标重复的 ✓✗ 字样）+ 耗时。
String _meta(ToolCallEvent e) {
  if (e.state == AgentToolCallState.running) return '运行中';
  if (e.state == AgentToolCallState.waitingApproval) return '等待授权';
  if (e.state == AgentToolCallState.denied) return '已拒绝';
  var summary = e.resultSummary
      .replaceAll(RegExp(r'\s*[✓✗]\s*'), ' ')
      .replaceFirst(RegExp(r'^(成功|失败)\s*·?\s*'), '')
      .trim();
  if (e.state == AgentToolCallState.failure && summary.isEmpty) summary = '失败';
  final ms = e.elapsed?.inMilliseconds;
  final time = ms == null || summary.contains(RegExp(r'\d(\.\d)?m?s\b'))
      ? null
      : (ms < 1000 ? '${ms}ms' : '${(ms / 1000).toStringAsFixed(1)}s');
  return [if (summary.isNotEmpty) summary, if (time != null) time].join(' · ');
}

/// 「在等交互输入」手动标记按钮：把本次调用目标会话（能从参数里解析出
/// session 时）或所有正在等命令结果的会话标记为等交互，对应 exec 带
/// 已有输出提前返回，模型随即可写 stdin 回答。
class _WaitingInputButton extends ConsumerWidget {
  const _WaitingInputButton({this.argsDetail, required this.taskId});

  /// 所属任务：标记限定在任务绑定工作区的会话内，不误伤其他工作区同名会话。
  final String taskId;

  /// 工具调用的完整参数 JSON；解析出 session 参数时只标记该会话，
  /// 避免并行任务时把无关的长命令也提前打断。
  final String? argsDetail;

  String? _sessionRef() {
    final raw = argsDetail;
    if (raw == null || raw.isEmpty) return null;
    try {
      final args = jsonDecode(raw);
      if (args is! Map) return null;
      final ref = args['session'] ?? args['session_id'];
      final text = ref?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(LucideIcons.keyboard, size: 13),
        label: Text('在等交互输入？点此告知 AI', style: theme.textTheme.labelSmall),
        onPressed: () {
          final workspaceId = ref
              .read(agentTasksProvider)
              .where((t) => t.id == taskId)
              .firstOrNull
              ?.workspaceId;
          final count = ref
              .read(workspaceSessionPoolManagerProvider)
              .markWaitingInputAll(
                sessionRef: _sessionRef(),
                workspaceId: (workspaceId == null || workspaceId.isEmpty)
                    ? null
                    : workspaceId,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(count > 0 ? '已告知 AI：命令在等交互输入' : '当前没有正在等结果的命令'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
