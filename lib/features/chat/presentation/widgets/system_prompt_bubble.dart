import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/dialogs/system_prompt_dialog.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// 1:1 port of the web `SystemPromptBubble`
/// (`src/components/prompts/SystemPromptBubble.tsx`). Shown at the top of the
/// message list; tapping opens the [showSystemPromptDialog].
class SystemPromptBubble extends ConsumerStatefulWidget {
  const SystemPromptBubble({super.key});

  /// 追加模式 (web `getDisplayPrompt`): 助手提示词, with the 话题提示词 appended when
  /// present; the topic prompt alone otherwise; finally a placeholder.
  static String displayPromptFor(Assistant? assistant, Topic? topic) {
    final assistantPrompt = assistant?.systemPrompt;
    final topicPrompt = topic?.prompt;
    if (assistantPrompt != null && assistantPrompt.isNotEmpty) {
      if (topicPrompt != null && topicPrompt.trim().isNotEmpty) {
        return '$assistantPrompt\n\n[追加] $topicPrompt';
      }
      return assistantPrompt;
    } else if (topicPrompt != null && topicPrompt.trim().isNotEmpty) {
      return topicPrompt;
    }
    return '点击此处编辑系统提示词';
  }

  @override
  ConsumerState<SystemPromptBubble> createState() => _SystemPromptBubbleState();
}

class _SystemPromptBubbleState extends ConsumerState<SystemPromptBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final assistant = ref.watch(currentAssistantProvider);
    final topic = ref.watch(currentTopicProvider).value;
    final text = SystemPromptBubble.displayPromptFor(assistant, topic);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;

    // backgroundColor: dark rgba(30,30,30,.95) / light paper@95%; hover bumps
    // the opacity (paper@98% / rgba(40,40,40,.98)).
    final Color background = isDark
        ? Color.fromRGBO(30, 30, 30, _hovered ? 0.98 : 0.95)
        : surface.withValues(alpha: _hovered ? 0.98 : 0.95);
    final Color borderColor = isDark
        ? Color.fromRGBO(255, 255, 255, _hovered ? 0.25 : 0.15)
        : Color.fromRGBO(0, 0, 0, _hovered ? 0.25 : 0.15);
    final Color brainColor = isDark
        ? const Color(0x99FFFFFF)
        : const Color(0x99000000);
    final Color textColor = isDark
        ? const Color(0xB3FFFFFF)
        : const Color(0xB3000000);
    final Color editColor = isDark
        ? const Color(0x80FFFFFF)
        : const Color(0x80000000);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => showSystemPromptDialog(
            context,
            assistant: assistant,
            topic: topic,
          ),
          // Paper elevation={1}: a subtle drop shadow so the bubble reads as a
          // distinct card above the message surface (the MUI elevation-1 box
          // shadow, ported verbatim). The shadow lives on an outer box so it is
          // not clipped by the rounded-corner ClipRRect below.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 2),
                  blurRadius: 1,
                  spreadRadius: -1,
                ),
                BoxShadow(
                  color: Color(0x24000000),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
                BoxShadow(
                  color: Color(0x1F000000),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            // The background colours are already near-opaque (95%/98%), so the
            // former real-time BackdropFilter blur (sigma 8) added a per-frame
            // saveLayer + GPU blur for almost no visual gain — the dominant
            // raster cost on this always-on bubble. Dropped along with the
            // ClipRRect (the AnimatedContainer rounds its own corners), leaving
            // a plain semi-transparent card.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.ease,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.brain, size: 20, color: brainColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.squarePen, size: 18, color: editColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
