import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 引擎注入给模型的系统提示（[系统] 续跑提醒 / [stop hook] 阻止收尾）：
/// 这些内容是给模型看的，事件流里只显示一行弱化提示条，点击展开全文。
class SystemHintTile extends StatefulWidget {
  const SystemHintTile({required this.event, super.key});

  final UserMessageEvent event;

  @override
  State<SystemHintTile> createState() => _SystemHintTileState();
}

class _SystemHintTileState extends State<SystemHintTile> {
  bool _expanded = false;

  /// 提示条标题：去掉 [系统]/[stop hook …] 前缀，取第一句。
  static String summaryOf(String text) {
    var t = text.trim();
    final isHook = t.startsWith('[stop hook');
    t = t.replaceFirst(RegExp(r'^\[[^\]]*\]\s*'), '');
    final firstLine = t.split('\n').first.trim();
    final cut = firstLine.indexOf(RegExp(r'[。！？.!?]'));
    var head = cut > 0 ? firstLine.substring(0, cut) : firstLine;
    if (head.length > 36) head = '${head.substring(0, 36)}…';
    return isHook ? 'stop hook 阻止收尾：$head' : '系统提示：$head';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final style = theme.textTheme.labelSmall?.copyWith(color: muted);
    return EventRail(
      node: Icon(LucideIcons.info, size: 12, color: muted),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      summaryOf(widget.event.text),
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 12,
                    color: muted,
                  ),
                ],
              ),
              if (_expanded)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    widget.event.text,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
