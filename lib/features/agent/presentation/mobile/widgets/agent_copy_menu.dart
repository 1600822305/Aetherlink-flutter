// 智能体事件流「长按复制」：命令行、工具行、审批卡、提问、计划、状态等
// 非正文小件统一走这里。只有一项可复制时长按直接复制；多项时弹出底部
// 菜单（每项带一行预览），点哪项复制哪项。
//
// 正文（助手叙述 / 用户消息 / 完成结果 / 展开的思考）已经是可选区的
// SelectionArea，长按走选区复制面板，不在这里处理。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_tool_detail.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 一项可复制内容。
class CopyEntry {
  const CopyEntry(this.label, this.text, {this.icon = LucideIcons.copy});

  final String label;
  final String text;
  final IconData icon;
}

Future<void> _copyText(BuildContext context, CopyEntry entry) async {
  await Clipboard.setData(ClipboardData(text: entry.text));
  if (context.mounted) AppToast.success(context, '已复制${entry.label}');
}

/// 长按入口：过滤空项；一项直接复制，多项弹菜单。
Future<void> showCopyMenu(
  BuildContext context,
  List<CopyEntry> entries, {
  String? title,
}) async {
  final items = [
    for (final e in entries)
      if (e.text.trim().isNotEmpty) e,
  ];
  if (items.isEmpty) return;
  HapticFeedback.mediumImpact();
  if (items.length == 1) {
    await _copyText(context, items.single);
    return;
  }
  FocusManager.instance.primaryFocus?.unfocus();
  final picked = await showModalBottomSheet<CopyEntry>(
    context: context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                title ?? '复制',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final e in items)
              ListTile(
                dense: true,
                leading: Icon(e.icon, size: 18),
                minLeadingWidth: 20,
                title: Text('复制${e.label}'),
                subtitle: Text(
                  _preview(e.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(e),
              ),
            const SizedBox(height: 6),
          ],
        ),
      );
    },
  );
  if (picked != null && context.mounted) await _copyText(context, picked);
}

String _preview(String text) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.length > 80 ? '${t.substring(0, 80)}…' : t;
}

/// 给不带点击手势的小件（审批卡 / 提问卡 / 计划行 / 状态行…）加长按复制。
/// [entries] 惰性求值：只有真的长按才去拼内容。
class LongPressCopy extends StatelessWidget {
  const LongPressCopy({
    required this.entries,
    required this.child,
    this.title,
    super.key,
  });

  final List<CopyEntry> Function() entries;
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onLongPress: () => showCopyMenu(context, entries(), title: title),
    child: child,
  );
}

/// ANSI 控制序列（复制终端输出时去掉颜色 / 光标控制）。
final RegExp _ansi = RegExp(
  r'\x1b\[[0-9;?<=>!]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[()][0-9A-Za-z]',
);

/// 工具结果 `{success, data}` JSON 的可读正文（stdout / content / output…），
/// 解不出时回退原文；去掉 ANSI 控制序列。
String readableToolResult(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  var text = raw;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final error = decoded['error'];
      final data = decoded['data'];
      if (error is String && error.isNotEmpty) {
        text = error;
      } else if (data is String) {
        text = data;
      } else if (data is Map) {
        for (final key in const ['stdout', 'content', 'output', 'text', 'message']) {
          final v = data[key];
          if (v is String && v.isNotEmpty) {
            final stderr = data['stderr'];
            text = (stderr is String && stderr.trim().isNotEmpty)
                ? '$v\n$stderr'
                : v;
            break;
          }
        }
      }
    }
  } catch (_) {}
  return text.replaceAll(_ansi, '');
}

/// 参数 JSON 美化（解不出时原样）。
String prettyArgs(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
  } catch (_) {
    return raw;
  }
}

/// 工具调用的可复制项：命令 / 文件路径 / 输出 / 参数（空项自动过滤）。
List<CopyEntry> toolCopyEntries(ToolCallEvent e) {
  final args = e.argsDetail ?? '';
  final command = toolCommandText(e.toolName, args)?.trim();
  final paths = <String>{
    ...toolChangedFilePaths(e.toolName, args, resultText: e.resultDetail),
  };
  if (paths.isEmpty) {
    try {
      final m = jsonDecode(args);
      if (m is Map) {
        for (final k in const ['path', 'file_path', 'file', 'directory', 'url']) {
          final v = m[k];
          if (v is String && v.trim().isNotEmpty) paths.add(v.trim());
        }
      }
    } catch (_) {}
  }
  final output = readableToolResult(e.resultDetail);
  return [
    if (command != null) CopyEntry('命令', command, icon: LucideIcons.terminal),
    if (paths.isNotEmpty)
      CopyEntry(
        paths.length == 1 ? '路径' : '路径（${paths.length} 个）',
        paths.join('\n'),
        icon: LucideIcons.fileText,
      ),
    CopyEntry(
      '输出',
      output.isNotEmpty ? output : e.resultSummary,
      icon: LucideIcons.copy,
    ),
    CopyEntry('参数', prettyArgs(args), icon: LucideIcons.braces),
  ];
}

/// 计划清单转纯文本（`[x]` 已完成 / `[~]` 进行中 / `[ ]` 待办）。
String planToText(List<AgentPlanItem> items) => [
  for (final i in items)
    '${switch (i.status) {
      AgentPlanItemStatus.completed => '[x]',
      AgentPlanItemStatus.inProgress => '[~]',
      AgentPlanItemStatus.pending => '[ ]',
    }} ${i.content}',
].join('\n');
