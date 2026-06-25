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

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/utils/regex_replacement.dart';
import 'package:aetherlink_flutter/shared/utils/silly_tavern_regex_import.dart';

const Map<AssistantRegexScope, String> _scopeLabels = {
  AssistantRegexScope.user: '用户消息',
  AssistantRegexScope.assistant: '助手消息',
};

/// The 正则 tab body. [rules] is the current draft; [onChange] reports the new
/// list after any add / edit / delete / toggle / reorder / import.
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
    final messenger = ScaffoldMessenger.maybeOf(context);
    void notify(String message) => messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        notify('无法读取文件');
        return;
      }
      final imported = importSillyTavernRegexScripts(utf8.decode(bytes));
      if (imported.isEmpty) {
        notify('没有找到有效的正则规则');
        return;
      }
      onChange([...rules, ...imported]);
      notify('成功导入 ${imported.length} 条正则规则');
    } on SillyTavernImportException catch (e) {
      notify('导入失败: ${e.message}');
    } catch (e) {
      notify('导入失败: $e');
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
                child: _RegexRuleCard(
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
class _RegexRuleCard extends StatelessWidget {
  const _RegexRuleCard({
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
                        Switch(
                          value: rule.enabled,
                          onChanged: onToggle,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
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
                                  label: _scopeLabels[scope] ?? scope.name,
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
Future<AssistantRegex?> showRegexRuleDialog(
  BuildContext context,
  AssistantRegex? rule,
) {
  return showDialog<AssistantRegex>(
    context: context,
    builder: (_) => _RegexRuleDialog(rule: rule),
  );
}

class _RegexRuleDialog extends StatefulWidget {
  const _RegexRuleDialog({required this.rule});

  final AssistantRegex? rule;

  @override
  State<_RegexRuleDialog> createState() => _RegexRuleDialogState();
}

class _RegexRuleDialogState extends State<_RegexRuleDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.rule?.name ?? '',
  );
  late final TextEditingController _pattern = TextEditingController(
    text: widget.rule?.pattern ?? '',
  );
  late final TextEditingController _replacement = TextEditingController(
    text: widget.rule?.replacement ?? '',
  );
  late final TextEditingController _testInput = TextEditingController();
  late Set<AssistantRegexScope> _scopes = {...?widget.rule?.scopes};
  late bool _visualOnly = widget.rule?.visualOnly ?? false;
  String? _nameError;
  String? _patternError;
  String? _scopeError;

  @override
  void initState() {
    super.initState();
    if (_scopes.isEmpty) _scopes = {AssistantRegexScope.user};
  }

  @override
  void dispose() {
    _name.dispose();
    _pattern.dispose();
    _replacement.dispose();
    _testInput.dispose();
    super.dispose();
  }

  bool _validatePattern() {
    final value = _pattern.text.trim();
    if (value.isEmpty) {
      setState(() => _patternError = '正则表达式不能为空');
      return false;
    }
    try {
      RegExp(value);
      setState(() => _patternError = null);
      return true;
    } catch (e) {
      setState(() => _patternError = '无效的正则表达式');
      return false;
    }
  }

  void _toggleScope(AssistantRegexScope scope) {
    setState(() {
      _scopeError = null;
      if (_scopes.contains(scope)) {
        _scopes.remove(scope);
      } else {
        _scopes.add(scope);
      }
    });
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = '规则名称不能为空');
      return;
    }
    if (!_validatePattern()) return;
    if (_scopes.isEmpty) {
      setState(() => _scopeError = '请至少选择一个作用范围');
      return;
    }
    Navigator.of(context).pop(
      AssistantRegex(
        id: widget.rule?.id ?? generateId('regex'),
        name: _name.text.trim(),
        pattern: _pattern.text.trim(),
        replacement: _replacement.text,
        scopes: _scopes.toList(),
        visualOnly: _visualOnly,
        enabled: widget.rule?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.wand2,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.rule != null ? '编辑正则规则' : '添加正则规则',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  _fieldLabel(theme, '规则名称 *'),
                  TextField(
                    controller: _name,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    decoration: _inputDecoration(
                      hint: '例如：隐藏敏感信息',
                      error: _nameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel(theme, '正则表达式 *'),
                  TextField(
                    controller: _pattern,
                    style: const TextStyle(fontFamily: 'monospace'),
                    onChanged: (_) {
                      if (_patternError != null) _validatePattern();
                    },
                    decoration: _inputDecoration(
                      hint: r'例如：\b\d{11}\b',
                      error: _patternError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel(theme, '替换为'),
                  TextField(
                    controller: _replacement,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _inputDecoration(
                      hint: r'留空则删除匹配内容，支持 $1, $2 等捕获组引用',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel(theme, '作用范围 *'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in _scopeLabels.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: _scopes.contains(entry.key),
                          onSelected: (_) => _toggleScope(entry.key),
                        ),
                    ],
                  ),
                  if (_scopeError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _scopeError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _fieldLabel(theme, '显示模式'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('仅视觉显示'),
                      selected: _visualOnly,
                      onSelected: (v) => setState(() => _visualOnly = v),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '启用后，替换仅在界面显示，不影响实际发送给 AI 的内容',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _preview(theme),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(widget.rule != null ? '保存' : '添加'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔍 实时预览',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _testInput,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration(hint: '输入测试文本...'),
          ),
          const SizedBox(height: 10),
          _previewResult(theme),
        ],
      ),
    );
  }

  Widget _previewResult(ThemeData theme) {
    final input = _testInput.text;
    final pattern = _pattern.text;
    if (input.isEmpty) {
      return Text(
        '输入测试文本查看替换效果',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      );
    }
    if (pattern.isEmpty || _patternError != null) {
      return const SizedBox.shrink();
    }

    final rule = AssistantRegex(
      id: 'preview',
      name: 'preview',
      pattern: pattern,
      replacement: _replacement.text,
      scopes: const [AssistantRegexScope.user],
      visualOnly: false,
      enabled: true,
    );
    String result;
    bool hasMatch;
    try {
      final regex = RegExp(pattern);
      hasMatch = regex.hasMatch(input);
      result = applyRegexRule(input, rule);
    } catch (_) {
      return Text(
        '正则表达式错误',
        style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '替换结果:',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: theme.colorScheme.surface.withValues(alpha: 0.7),
          ),
          child: Text(
            result.isEmpty ? '(空)' : result,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: hasMatch
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (!hasMatch)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '⚠️ 未匹配到任何内容',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.tertiary),
            ),
          ),
      ],
    );
  }

  Widget _fieldLabel(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
    ),
  );

  InputDecoration _inputDecoration({required String hint, String? error}) {
    return InputDecoration(
      hintText: hint,
      errorText: error,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
