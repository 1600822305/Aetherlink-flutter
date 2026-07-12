import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 助手叙述行：无气泡、贴左正文段落；流式中带闪烁光标占位。
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
      child: Text(
        event.streaming ? '${event.text}▍' : event.text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }
}
