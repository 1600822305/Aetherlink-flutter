import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';

const Map<AssistantRegexScope, String> kRegexScopeLabels = {
  AssistantRegexScope.user: '用户消息',
  AssistantRegexScope.assistant: '助手消息',
};

/// The 正则 tab body. [rules] is the current draft; [onChange] reports the new
/// list after any add / edit / delete / toggle / reorder / import.
class RegexRuleCard extends StatelessWidget {
  const RegexRuleCard({
    super.key,
    required this.rule,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final AssistantRegex rule;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Icon(
                    LucideIcons.gripVertical,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rule.name.isEmpty ? '未命名规则' : rule.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        CustomSwitch(value: rule.enabled, onChanged: onToggle),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: theme.colorScheme.surface.withValues(alpha: 0.6),
                      ),
                      child: Text(
                        rule.pattern.isEmpty ? '(空表达式)' : rule.pattern,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final scope in rule.scopes)
                                _Tag(
                                  label: kRegexScopeLabels[scope] ?? scope.name,
                                  color: theme.colorScheme.primary,
                                ),
                              if (rule.visualOnly)
                                _Tag(
                                  label: '仅视觉',
                                  color: theme.colorScheme.tertiary,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onDelete,
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          color: theme.colorScheme.error,
                          icon: const Icon(LucideIcons.trash2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

/// Opens the add / edit rule dialog. Returns the resulting [AssistantRegex] on
/// 保存, or null on cancel. [rule] null means "添加".
