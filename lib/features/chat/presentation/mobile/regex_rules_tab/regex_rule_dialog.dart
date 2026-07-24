import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/utils/regex_replacement.dart';

import 'package:aetherlink_flutter/features/chat/presentation/mobile/regex_rules_tab/regex_rule_card.dart';

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
                      for (final entry in kRegexScopeLabels.entries)
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
