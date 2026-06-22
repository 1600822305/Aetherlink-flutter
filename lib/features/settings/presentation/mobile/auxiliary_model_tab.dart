import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Tab 1 — 模型配置: 7 default model selectors matching rikkahub's model types,
/// using Aetherlink-flutter's existing card/switch/picker UI style.
class AuxiliaryModelTab extends ConsumerWidget {
  const AuxiliaryModelTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers =
        ref.watch(appModelProvidersProvider).asData?.value ?? const [];
    final state = ref.watch(auxiliaryModelControllerProvider);
    final ctrl = ref.read(auxiliaryModelControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── 聊天模型 ──
        _ModelSettingCard(
          icon: LucideIcons.messageCircle,
          iconColor: const Color(0xFF6366F1),
          title: '聊天模型',
          description: '主要对话使用的模型',
          modelKey: state.chatModelKey,
          providers: providers,
          onSelect: (p, m) => ctrl.setChatModel(p.id, m.id),
        ),
        const SizedBox(height: 12),

        // ── 快速模型 ──
        _ModelSettingCard(
          icon: LucideIcons.zap,
          iconColor: const Color(0xFFF59E0B),
          title: '快速模型',
          description: '用于需要快速响应的场景（如自动补全等）',
          modelKey: state.fastModelKey,
          providers: providers,
          onSelect: (p, m) => ctrl.setFastModel(p.id, m.id),
        ),
        const SizedBox(height: 12),

        // ── 标题模型 ──
        _ModelSettingCard(
          icon: LucideIcons.type,
          iconColor: const Color(0xFF8B5CF6),
          title: '标题模型',
          description: '自动为新对话生成简短标题',
          modelKey: state.titleModelKey,
          providers: providers,
          onSelect: (p, m) => ctrl.setTitleModel(p.id, m.id),
          clearable: true,
          onClear: ctrl.clearTitleModel,
        ),
        const SizedBox(height: 12),

        // ── 建议模型 ──
        _ModelSettingCard(
          icon: LucideIcons.lightbulb,
          iconColor: const Color(0xFF10B981),
          title: '建议模型',
          description: '为用户生成后续问题建议',
          modelKey: state.suggestionModelKey,
          providers: providers,
          onSelect: (p, m) => ctrl.setSuggestionModel(p.id, m.id),
          clearable: true,
          onClear: ctrl.clearSuggestionModel,
          toggleValue: state.enableSuggestion,
          onToggle: ctrl.setEnableSuggestion,
        ),
        const SizedBox(height: 12),

        // ── 翻译模型 ──
        _ModelSettingCard(
          icon: LucideIcons.languages,
          iconColor: const Color(0xFF3B82F6),
          title: '翻译模型',
          description: '用于消息翻译功能',
          modelKey: state.translateModelKey,
          providers: providers,
          onSelect: (p, m) => ctrl.setTranslateModel(p.id, m.id),
        ),
        const SizedBox(height: 12),

        // ── OCR 模型 ──
        _ModelSettingCard(
          icon: LucideIcons.eye,
          iconColor: const Color(0xFFEC4899),
          title: 'OCR 模型',
          description: '视觉识别，图片内容描述与文字提取',
          modelKey: state.ocrModelKey,
          providers: providers,
          onSelect: (p, m) => ctrl.setOcrModel(p.id, m.id),
        ),
        const SizedBox(height: 12),

        // ── 压缩模型 ──
        _ModelSettingCard(
          icon: LucideIcons.foldVertical,
          iconColor: const Color(0xFF14B8A6),
          title: '压缩模型',
          description: '智能压缩对话历史，节省 Token 成本',
          modelKey: state.compressModelKey,
          providers: providers,
          onSelect: (p, m) => ctrl.setCompressModel(p.id, m.id),
        ),
        const SizedBox(height: 12),

        // ── 底部说明 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _footnote(context, '聊天模型', '默认对话使用的主模型'),
              const SizedBox(height: 4),
              _footnote(context, '快速模型', '用于需要快速响应的轻量任务'),
              const SizedBox(height: 4),
              _footnote(context, '标题模型', '未设置时使用聊天模型生成标题'),
              const SizedBox(height: 4),
              _footnote(context, '建议模型', '未设置时不生成后续问题建议'),
              const SizedBox(height: 4),
              _footnote(context, '翻译模型', '未设置时使用聊天模型进行翻译'),
              const SizedBox(height: 4),
              _footnote(context, 'OCR 模型', '未设置时使用聊天模型识别图片'),
              const SizedBox(height: 4),
              _footnote(context, '压缩模型', '未设置时使用聊天模型压缩历史'),
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
// Internal building block
// ─────────────────────────────────────────────────────────────────────────────

/// A card for a single model setting item. Reuses [AuxiliarySettingCard] style
/// with a model picker row and optional toggle/clear actions.
class _ModelSettingCard extends StatelessWidget {
  const _ModelSettingCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.modelKey,
    required this.providers,
    required this.onSelect,
    this.clearable = false,
    this.onClear,
    this.toggleValue,
    this.onToggle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String? modelKey;
  final List<ModelProvider> providers;
  final void Function(ModelProvider, Model) onSelect;
  final bool clearable;
  final VoidCallback? onClear;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Resolve current model display name
    String? selectedProviderId;
    String? selectedModelId;
    String displayName = '未选择';
    if (modelKey != null && modelKey!.isNotEmpty) {
      final parts = modelKey!.split('\u0000');
      if (parts.length == 2) {
        selectedProviderId = parts[0];
        selectedModelId = parts[1];
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
    }

    final children = <Widget>[];

    // Optional toggle row (for suggestion model)
    if (toggleValue != null && onToggle != null) {
      children.add(
        AuxiliarySwitchRow(
          title: '启用$title',
          description: '开启后将使用此模型生成建议',
          value: toggleValue!,
          onChanged: onToggle!,
        ),
      );
      children.add(const Divider(height: 1));
    }

    // Model picker row
    children.add(
      InkWell(
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
                '选择模型',
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
      ),
    );

    // Optional clear button
    if (clearable && modelKey != null && modelKey!.isNotEmpty) {
      children.add(const Divider(height: 1));
      children.add(
        InkWell(
          onTap: onClear,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(LucideIcons.x, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Text(
                  '清除选择',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AuxiliarySettingCard(
      icon: icon,
      iconColor: iconColor,
      title: title,
      description: description,
      children: children,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable building blocks (kept for backward compat / other consumers)
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
