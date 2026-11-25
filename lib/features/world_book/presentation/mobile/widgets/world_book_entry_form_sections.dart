// 条目编辑页的表单分区：关键词 chips / 数字输入 / 位置与角色选择。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_entry_row.dart';

/// 关键词编辑：已有关键词为可删除的 chip，输入框回车或点「添加」追加。
class WorldBookKeywordsField extends StatefulWidget {
  const WorldBookKeywordsField({
    super.key,
    required this.keywords,
    required this.onChanged,
    required this.useRegex,
  });

  final List<String> keywords;
  final ValueChanged<List<String>> onChanged;
  final bool useRegex;

  @override
  State<WorldBookKeywordsField> createState() => _WorldBookKeywordsFieldState();
}

class _WorldBookKeywordsFieldState extends State<WorldBookKeywordsField> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final value = _input.text.trim();
    if (value.isEmpty) return;
    if (!widget.keywords.contains(value)) {
      widget.onChanged([...widget.keywords, value]);
    }
    _input.clear();
  }

  String? _regexError(String keyword) {
    if (!widget.useRegex) return null;
    try {
      RegExp(keyword);
      return null;
    } on FormatException {
      return '无效正则';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.keywords.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final keyword in widget.keywords)
                InputChip(
                  label: Text(
                    _regexError(keyword) == null
                        ? keyword
                        : '$keyword（${_regexError(keyword)}）',
                  ),
                  labelStyle: _regexError(keyword) == null
                      ? null
                      : TextStyle(color: theme.colorScheme.error),
                  onDeleted: () => widget.onChanged(
                    widget.keywords.where((k) => k != keyword).toList(),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.useRegex ? '输入正则表达式' : '输入关键词',
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _add, child: const Text('添加')),
          ],
        ),
      ],
    );
  }
}

/// 整数输入框（带取值范围提示）；[allowNegative] 时允许前导负号。
class WorldBookNumberField extends StatelessWidget {
  const WorldBookNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.helper,
    this.allowNegative = false,
  });

  final TextEditingController controller;
  final String label;
  final String helper;
  final bool allowNegative;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
      inputFormatters: [
        allowNegative
            ? FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        helperText: helper,
      ),
    );
  }
}

/// 五种注入位置的单选 chips。
class WorldBookPositionSelector extends StatelessWidget {
  const WorldBookPositionSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WorldBookInjectionPosition value;
  final ValueChanged<WorldBookInjectionPosition> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final position in WorldBookInjectionPosition.values)
          ChoiceChip(
            label: Text(worldBookPositionLabel(position)),
            selected: value == position,
            onSelected: (_) => onChanged(position),
          ),
      ],
    );
  }
}

/// 聊天位注入的角色（user / assistant）。
class WorldBookRoleSelector extends StatelessWidget {
  const WorldBookRoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WorldBookInjectionRole value;
  final ValueChanged<WorldBookInjectionRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('用户'),
          selected: value == WorldBookInjectionRole.user,
          onSelected: (_) => onChanged(WorldBookInjectionRole.user),
        ),
        ChoiceChip(
          label: const Text('助手'),
          selected: value == WorldBookInjectionRole.assistant,
          onSelected: (_) => onChanged(WorldBookInjectionRole.assistant),
        ),
      ],
    );
  }
}

/// 分区小标题。
class WorldBookFormLabel extends StatelessWidget {
  const WorldBookFormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 一行「标题 + 说明 + 开关」。
class WorldBookSwitchRow extends StatelessWidget {
  const WorldBookSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
