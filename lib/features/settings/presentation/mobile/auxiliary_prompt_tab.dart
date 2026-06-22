import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// Tab 2 — 提示词设置: per-feature prompt editors with reset-to-default.
///
/// Extracted as a standalone widget for reuse outside the auxiliary settings
/// page (e.g. embedded in another settings flow).
class AuxiliaryPromptTab extends StatelessWidget {
  const AuxiliaryPromptTab({
    super.key,
    required this.topicPromptController,
    required this.intentPromptController,
    required this.visionPromptController,
    required this.onResetTopicPrompt,
    required this.onResetIntentPrompt,
    required this.onResetVisionPrompt,
  });

  final TextEditingController topicPromptController;
  final TextEditingController intentPromptController;
  final TextEditingController visionPromptController;
  final VoidCallback onResetTopicPrompt;
  final VoidCallback onResetIntentPrompt;
  final VoidCallback onResetVisionPrompt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AuxiliaryPromptCard(
          icon: LucideIcons.type,
          iconColor: const Color(0xFF6366F1),
          title: '话题命名提示词',
          description: '用于指导模型如何生成对话标题',
          controller: topicPromptController,
          onReset: onResetTopicPrompt,
        ),
        const SizedBox(height: 12),
        AuxiliaryPromptCard(
          icon: LucideIcons.lightbulb,
          iconColor: const Color(0xFFF59E0B),
          title: '意图分析提示词',
          description: '用于指导模型如何判断用户意图',
          controller: intentPromptController,
          onReset: onResetIntentPrompt,
        ),
        const SizedBox(height: 12),
        AuxiliaryPromptCard(
          icon: LucideIcons.eye,
          iconColor: const Color(0xFF10B981),
          title: '视觉识别提示词',
          description: '用于指导视觉模型如何描述图片内容',
          controller: visionPromptController,
          onReset: onResetVisionPrompt,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable building block
// ─────────────────────────────────────────────────────────────────────────────

/// A collapsible card with a prompt editor and a reset button.
class AuxiliaryPromptCard extends StatefulWidget {
  const AuxiliaryPromptCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.controller,
    required this.onReset,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final TextEditingController controller;
  final VoidCallback onReset;

  @override
  State<AuxiliaryPromptCard> createState() => _AuxiliaryPromptCardState();
}

class _AuxiliaryPromptCardState extends State<AuxiliaryPromptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(14),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 18, color: widget.iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: widget.controller,
                    maxLines: 8,
                    minLines: 3,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '输入自定义提示词...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ModelTonalButton(
                      label: '恢复默认',
                      icon: LucideIcons.rotateCcw,
                      onPressed: () {
                        widget.onReset();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
