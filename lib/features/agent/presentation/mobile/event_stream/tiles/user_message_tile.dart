import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 用户指令：贴右对称气泡（Devin/IDE 同款，与 agent 侧时间线叙述区分；
/// 已拍板 §九）；排队追加的指令带「已排队」标记。
class UserMessageTile extends StatelessWidget {
  const UserMessageTile({required this.event, super.key});

  final UserMessageEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (event.queued)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    event.interrupt ? '打断中 · 正在中止当前步骤' : '已排队 · 下一轮生效',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ),
              Text(event.text, style: theme.textTheme.bodyMedium),
              if (event.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final a in event.attachments)
                        if (a.kind == AgentAttachmentKind.image &&
                            a.base64Data != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              base64Decode(a.base64Data!),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _chip(theme, a),
                            ),
                          )
                        else
                          _chip(theme, a),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, AgentUserAttachment a) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (a.kind) {
              AgentAttachmentKind.image => LucideIcons.image,
              AgentAttachmentKind.file => LucideIcons.fileText,
              AgentAttachmentKind.snippet => LucideIcons.quote,
            },
            size: 13,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
