// 条目编辑页的表单部件：分段选择 / 关键词输入框 / 紧凑数字行 / 开关行 /
// 位置选择 / 分区标题。规格与世界书列表页、其他设置页一致（标题 14 号 w600、
// 说明 12 号、行内边距 14）。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_entry_row.dart';

/// 分区标题（卡片外）。
class WorldBookFormLabel extends StatelessWidget {
  const WorldBookFormLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 卡片内的字段小标题。
class WorldBookFieldLabel extends StatelessWidget {
  const WorldBookFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 灰色说明 / 警示小字；[warning] 时用 error 色并带图标。
class WorldBookInlineNote extends StatelessWidget {
  const WorldBookInlineNote(this.text, {super.key, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warning
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (warning) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(LucideIcons.circleAlert, size: 13, color: color),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.4,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分段选择（两三个互斥选项），样式与 AppBar 下的设置页一致：浅底 + 选中白块。
class WorldBookSegmented<T> extends StatelessWidget {
  const WorldBookSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.10);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: v == value
                        ? theme.colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: v == value
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: v == value ? FontWeight.w600 : FontWeight.w400,
                      color: v == value
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 关键词输入框：标签与输入框在同一个描边框内，回车 / 逗号 / 点「添加」追加，
/// 退格删除最后一个；正则模式下无效表达式标红。
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
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add([String? raw]) {
    final parts = (raw ?? _input.text)
        .split(RegExp(r'[,，\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final next = [...widget.keywords];
    for (final p in parts) {
      if (!next.contains(p)) next.add(p);
    }
    if (next.length != widget.keywords.length) widget.onChanged(next);
    _input.clear();
  }

  void _onChanged(String v) {
    // 输入逗号即切分成标签（粘贴「a, b, c」也一次拆开）。
    if (v.contains(',') || v.contains('，')) _add(v);
  }

  bool _invalid(String keyword) {
    if (!widget.useRegex) return false;
    try {
      RegExp(keyword);
      return false;
    } on FormatException {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invalidCount = widget.keywords.where(_invalid).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _focus.requestFocus,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final k in widget.keywords) _chip(theme, k),
                SizedBox(
                  width: widget.keywords.isEmpty ? 220 : 120,
                  child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        onChanged: _onChanged,
                        onSubmitted: (_) {
                          _add();
                          _focus.requestFocus();
                        },
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          hintText: widget.keywords.isEmpty
                              ? (widget.useRegex ? '输入正则，回车添加' : '输入关键词，回车或逗号添加')
                              : '添加',
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
        if (invalidCount > 0)
          WorldBookInlineNote('$invalidCount 个正则表达式无效，匹配时会被跳过', warning: true),
      ],
    );
  }

  Widget _chip(ThemeData theme, String k) {
    final bad = _invalid(k);
    final fg = bad ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 2),
      decoration: BoxDecoration(
        color: bad
            ? theme.colorScheme.error.withValues(alpha: 0.10)
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            k,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              color: fg,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => widget.onChanged(
              widget.keywords.where((e) => e != k).toList(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.x,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行「标题 + 说明 + 开关」（卡片内，左右内边距由卡片提供）。
class WorldBookSwitchRow extends StatelessWidget {
  const WorldBookSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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

/// 紧凑数字行：左侧标题 + 一行说明，右侧「− 数值 +」步进器（可直接输入）。
class WorldBookNumberRow extends StatelessWidget {
  const WorldBookNumberRow({
    super.key,
    required this.controller,
    required this.title,
    this.subtitle,
    required this.min,
    required this.max,
    this.onChanged,
  });

  final TextEditingController controller;
  final String title;
  final String? subtitle;
  final int min;
  final int max;
  final VoidCallback? onChanged;

  bool get _allowNegative => min < 0;

  void _step(int delta) {
    final current = int.tryParse(controller.text.trim()) ?? 0;
    final next = (current + delta).clamp(min, max);
    controller.text = '$next';
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget stepButton(IconData icon, int delta) => SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 14,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: muted),
        onPressed: () => _step(delta),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.3,
                      color: muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                stepButton(LucideIcons.minus, -1),
                SizedBox(
                  width: 48,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    onChanged: (_) => onChanged?.call(),
                    keyboardType: TextInputType.numberWithOptions(
                      signed: _allowNegative,
                    ),
                    inputFormatters: [
                      _allowNegative
                          ? FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
                          : FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                stepButton(LucideIcons.plus, 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 五种注入位置：紧凑单选 chips。
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
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in WorldBookInjectionPosition.values)
          GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: p == value
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: p == value
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                worldBookPositionLabel(p),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: p == value ? FontWeight.w600 : FontWeight.w400,
                  color: p == value
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 每个注入位置的一句话说明（位置 chips 下方显示）。
String worldBookPositionHint(WorldBookInjectionPosition p) => switch (p) {
  WorldBookInjectionPosition.beforeSystemPrompt => '拼在系统提示词前面',
  WorldBookInjectionPosition.afterSystemPrompt => '拼在系统提示词后面（最常用）',
  WorldBookInjectionPosition.topOfChat => '作为一条消息插在聊天记录最前面',
  WorldBookInjectionPosition.bottomOfChat => '作为一条消息插在聊天记录最后面',
  WorldBookInjectionPosition.atDepth => '作为一条消息插在倒数第 N 条消息处',
};
