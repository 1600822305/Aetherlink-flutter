/// 正则规则管理 tab — the port of the web `RegexTab` / `RegexRuleDialog` /
/// `RegexRuleCard` (`src/components/TopicManagement/AssistantTab/RegexTab/`).
///
/// Replaces the 编辑助手 dialog's 「即将支持」 placeholder with a working surface:
/// add / edit / delete / enable-toggle / reorder（拖拽调整执行顺序）/ 导入酒馆正则
/// (SillyTavern JSON). Edits are kept in memory and persisted by the parent
/// dialog's 保存 (which threads `regexRules` into `Assistants.applyEdits`).
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/utils/silly_tavern_regex_import.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

import 'package:aetherlink_flutter/features/chat/presentation/mobile/regex_rules_tab/regex_rule_card.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/regex_rules_tab/regex_rule_dialog.dart';

class RegexRulesTab extends StatelessWidget {
  const RegexRulesTab({required this.rules, required this.onChange, super.key});

  final List<AssistantRegex> rules;
  final ValueChanged<List<AssistantRegex>> onChange;

  Future<void> _addRule(BuildContext context) async {
    final created = await showRegexRuleDialog(context, null);
    if (created != null) onChange([...rules, created]);
  }

  Future<void> _editRule(BuildContext context, AssistantRegex rule) async {
    final edited = await showRegexRuleDialog(context, rule);
    if (edited != null) {
      onChange([
        for (final r in rules)
          if (r.id == edited.id) edited else r,
      ]);
    }
  }

  void _deleteRule(AssistantRegex rule) =>
      onChange(rules.where((r) => r.id != rule.id).toList());

  void _toggleRule(AssistantRegex rule, bool enabled) {
    onChange([
      for (final r in rules)
        if (r.id == rule.id) r.copyWith(enabled: enabled) else r,
    ]);
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = List<AssistantRegex>.of(rules);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    onChange(next);
  }

  Future<void> _import(BuildContext context) async {
    void notify(String message, {AppToastType type = AppToastType.info}) {
      if (!context.mounted) return;
      AppToast.show(context, message, type: type);
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final file = result?.files.singleOrNull;
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null) {
        notify('无法读取文件', type: AppToastType.warning);
        return;
      }
      final imported = importSillyTavernRegexScripts(utf8.decode(bytes));
      if (imported.isEmpty) {
        notify('没有找到有效的正则规则', type: AppToastType.warning);
        return;
      }
      onChange([...rules, ...imported]);
      notify('成功导入 ${imported.length} 条正则规则', type: AppToastType.success);
    } on SillyTavernImportException catch (e) {
      notify('导入失败: ${e.message}', type: AppToastType.error);
    } catch (e) {
      notify('导入失败: $e', type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) return _empty(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '拖拽调整规则执行顺序',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(LucideIcons.upload, size: 14),
                label: const Text('导入'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: () => _addRule(context),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('添加'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            buildDefaultDragHandles: false,
            itemCount: rules.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Padding(
                key: ValueKey(rule.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: RegexRuleCard(
                  rule: rule,
                  index: index,
                  onEdit: () => _editRule(context, rule),
                  onDelete: () => _deleteRule(rule),
                  onToggle: (v) => _toggleRule(rule, v),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
              child: Icon(
                LucideIcons.wand2,
                size: 28,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                '正则替换可以自动处理消息内容，如隐藏敏感信息、格式化文本等',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addRule(context),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('添加正则规则'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _import(context),
                  icon: const Icon(LucideIcons.upload, size: 18),
                  label: const Text('导入酒馆正则'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single rule row: drag handle, name + enable switch, pattern preview, scope
/// / 仅视觉 chips, delete. Tapping the body opens the edit dialog.
