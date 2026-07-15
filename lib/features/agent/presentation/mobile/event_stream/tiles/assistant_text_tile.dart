import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/app/di/markdown_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 助手叙述行：无气泡、贴左正文段落，Markdown 渲染（与聊天页同一套）；
/// 流式中走 [StreamingMarkdownBody]（块级记忆化，每个增量只重解析尾块）
/// 并带闪烁光标占位，定稿后走 [AppMarkdown]。
class AssistantTextTile extends StatelessWidget {
  const AssistantTextTile({required this.event, super.key});

  final AssistantTextEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EventRail(
      node: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(top: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      child: event.streaming
          ? StreamingMarkdownBody(
              content: '${event.text}▍',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            )
          : AppMarkdown(
              content: event.text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
    );
  }
}
