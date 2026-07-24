import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ── 提示词 ────────────────────────────────────────────────────────────────────

class PromptTab extends StatelessWidget {
  const PromptTab({
    super.key,
    required this.controller,
    required this.onPickPreset,
  });

  final TextEditingController controller;
  final VoidCallback onPickPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '系统提示词',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPickPreset,
                icon: const Icon(LucideIcons.sparkles, size: 16),
                label: const Text('选择预设提示词'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: false,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: isMobile ? 16 : 14, height: 1.5),
              decoration: InputDecoration(
                hintText: '请输入系统提示词，定义助手的角色和行为特征...',
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '提示词将作为系统消息发送给 AI，定义助手的角色和行为',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
