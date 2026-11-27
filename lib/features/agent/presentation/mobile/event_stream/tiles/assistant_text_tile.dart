import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/app/di/markdown_access.dart';
import 'package:aetherlink_flutter/app/di/message_selection_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';
import 'package:aetherlink_flutter/shared/widgets/deferred_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_live_text.dart';

/// 助手叙述行：无气泡、贴左正文段落，Markdown 渲染（与聊天页同一套）；
/// 流式中走 [StreamingMarkdownBody]（块级记忆化，每个增量只重解析尾块）
/// 并带闪烁光标占位，定稿后走 [AppMarkdown]。
class AssistantTextTile extends StatelessWidget {
  const AssistantTextTile({required this.event, super.key});

  final AssistantTextEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    final lineHeight = (style?.fontSize ?? 14) * 1.5;
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
          // 流式中只订阅本事件的实时文本：增量到达只重建这一行。
          ? Consumer(
              builder: (context, ref, _) {
                final text = liveOrStored(
                  ref.watch(agentLiveTextProvider.select((m) => m[event.id])),
                  event.text,
                  streaming: true,
                );
                return StreamingMarkdownBody(content: '$text▍', style: style);
              },
            )
          : DeferredContent(
              cost: event.text.length,
              estimatedHeight: event.text.length / 22 * lineHeight,
              builder: (_) => SettingAwareMessageSelectionArea(
                child: AppMarkdown(content: event.text, style: style),
              ),
            ),
    );
  }
}
