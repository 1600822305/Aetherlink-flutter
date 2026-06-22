import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Tab 1 — 模型配置: topic naming, intent analysis, vision recognition model
/// selectors with enable/disable toggles and "use current model" option.
///
/// Extracted as a standalone widget for reuse outside the auxiliary settings
/// page (e.g. embedded in another settings flow).
class AuxiliaryModelTab extends ConsumerWidget {
  const AuxiliaryModelTab({
    super.key,
    required this.enableTopicNaming,
    required this.topicNamingUseCurrentModel,
    this.topicNamingProviderId,
    this.topicNamingModelId,
    required this.enableIntentAnalysis,
    required this.intentAnalysisUseCurrentModel,
    this.intentAnalysisProviderId,
    this.intentAnalysisModelId,
    required this.enableVisionRecognition,
    this.visionProviderId,
    this.visionModelId,
    required this.onToggleTopicNaming,
    required this.onToggleTopicNamingUseCurrentModel,
    required this.onSelectTopicNamingModel,
    required this.onToggleIntentAnalysis,
    required this.onToggleIntentAnalysisUseCurrentModel,
    required this.onSelectIntentAnalysisModel,
    required this.onToggleVisionRecognition,
    required this.onSelectVisionModel,
  });

  final bool enableTopicNaming;
  final bool topicNamingUseCurrentModel;
  final String? topicNamingProviderId;
  final String? topicNamingModelId;
  final bool enableIntentAnalysis;
  final bool intentAnalysisUseCurrentModel;
  final String? intentAnalysisProviderId;
  final String? intentAnalysisModelId;
  final bool enableVisionRecognition;
  final String? visionProviderId;
  final String? visionModelId;
  final ValueChanged<bool> onToggleTopicNaming;
  final ValueChanged<bool> onToggleTopicNamingUseCurrentModel;
  final void Function(ModelProvider, Model) onSelectTopicNamingModel;
  final ValueChanged<bool> onToggleIntentAnalysis;
  final ValueChanged<bool> onToggleIntentAnalysisUseCurrentModel;
  final void Function(ModelProvider, Model) onSelectIntentAnalysisModel;
  final ValueChanged<bool> onToggleVisionRecognition;
  final void Function(ModelProvider, Model) onSelectVisionModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers =
        ref.watch(appModelProvidersProvider).asData?.value ?? const [];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── 话题命名 ──
        AuxiliarySettingCard(
          icon: LucideIcons.type,
          iconColor: const Color(0xFF6366F1),
          title: '话题命名',
          description: '自动为新对话生成简短标题',
          children: [
            AuxiliarySwitchRow(
              title: '自动命名',
              description: '新对话发送第一条消息后自动生成标题',
              value: enableTopicNaming,
              onChanged: onToggleTopicNaming,
            ),
            if (enableTopicNaming) ...[
              const Divider(height: 1),
              AuxiliarySwitchRow(
                title: '使用当前对话模型',
                description: '关闭后可指定专门的命名模型',
                value: topicNamingUseCurrentModel,
                onChanged: onToggleTopicNamingUseCurrentModel,
              ),
              if (!topicNamingUseCurrentModel) ...[
                const Divider(height: 1),
                AuxiliaryModelPickerRow(
                  label: '命名模型',
                  selectedProviderId: topicNamingProviderId,
                  selectedModelId: topicNamingModelId,
                  providers: providers,
                  onSelect: onSelectTopicNamingModel,
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── AI 意图分析 ──
        AuxiliarySettingCard(
          icon: LucideIcons.lightbulb,
          iconColor: const Color(0xFFF59E0B),
          title: 'AI 意图分析',
          description: '分析用户消息意图，判断是否需要联网搜索',
          children: [
            AuxiliarySwitchRow(
              title: '启用意图分析',
              description: '发送消息时自动分析是否需要搜索',
              value: enableIntentAnalysis,
              onChanged: onToggleIntentAnalysis,
            ),
            if (enableIntentAnalysis) ...[
              const Divider(height: 1),
              AuxiliarySwitchRow(
                title: '使用当前对话模型',
                description: '关闭后可指定专门的分析模型',
                value: intentAnalysisUseCurrentModel,
                onChanged: onToggleIntentAnalysisUseCurrentModel,
              ),
              if (!intentAnalysisUseCurrentModel) ...[
                const Divider(height: 1),
                AuxiliaryModelPickerRow(
                  label: '分析模型',
                  selectedProviderId: intentAnalysisProviderId,
                  selectedModelId: intentAnalysisModelId,
                  providers: providers,
                  onSelect: onSelectIntentAnalysisModel,
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── 视觉识别 ──
        AuxiliarySettingCard(
          icon: LucideIcons.eye,
          iconColor: const Color(0xFF10B981),
          title: '视觉识别',
          description: '发送图片给不支持视觉的模型时，自动用视觉模型分析图片内容',
          children: [
            AuxiliarySwitchRow(
              title: '启用视觉识别',
              description: '自动识别并描述图片内容提供给当前模型',
              value: enableVisionRecognition,
              onChanged: onToggleVisionRecognition,
            ),
            if (enableVisionRecognition) ...[
              const Divider(height: 1),
              AuxiliaryModelPickerRow(
                label: '视觉模型',
                selectedProviderId: visionProviderId,
                selectedModelId: visionModelId,
                providers: providers,
                onSelect: onSelectVisionModel,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── 底部说明 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _footnote(context, '话题命名', '新对话的第一条消息后自动调用模型生成标题'),
              const SizedBox(height: 4),
              _footnote(context, '意图分析', '判断用户是否需要联网搜索，仅在搜索功能启用时生效'),
              const SizedBox(height: 4),
              _footnote(
                context,
                '视觉识别',
                '仅当当前对话模型不支持图片时触发；分析结果只注入本次请求，聊天记录仍保留原图',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footnote(BuildContext context, String label, String desc) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label — ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: desc),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable building blocks
// ─────────────────────────────────────────────────────────────────────────────

/// A bordered card with a colored-icon header. Reusable for any settings
/// section that needs an icon + title + description header with child rows.
class AuxiliarySettingCard extends StatelessWidget {
  const AuxiliarySettingCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<Widget> children;

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
          Container(
            padding: const EdgeInsets.all(14),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

/// A row with title + description on the left, a custom switch on the right.
class AuxiliarySwitchRow extends StatelessWidget {
  const AuxiliarySwitchRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CustomSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A row that shows the currently selected model and opens the full-screen
/// model selector dialog on tap.
class AuxiliaryModelPickerRow extends StatelessWidget {
  const AuxiliaryModelPickerRow({
    super.key,
    required this.label,
    this.selectedProviderId,
    this.selectedModelId,
    required this.providers,
    required this.onSelect,
  });

  final String label;
  final String? selectedProviderId;
  final String? selectedModelId;
  final List<ModelProvider> providers;
  final void Function(ModelProvider, Model) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String displayName = '未选择';
    if (selectedProviderId != null && selectedModelId != null) {
      for (final p in providers) {
        if (p.id == selectedProviderId) {
          for (final m in p.models) {
            if (m.id == selectedModelId) {
              displayName = '${p.name} / ${m.name}';
              break;
            }
          }
          break;
        }
      }
    }

    return InkWell(
      onTap: () => showModelSelectorDialog(
        context,
        onSelect: onSelect,
        selectedProviderId: selectedProviderId,
        selectedModelId: selectedModelId,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
