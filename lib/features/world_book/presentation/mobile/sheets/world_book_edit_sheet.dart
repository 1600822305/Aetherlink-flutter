// 新建 / 编辑世界书：书名 + 描述。
//
// 顶部预览这本书在列表里的样子（书本图标 + 名称），输入时实时更新，有名字后
// 图标变深色；名称下方显示字数；底部「取消 / 创建（保存）」两个等宽按钮。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// [WorldBookEditSheet] 的结果。
class WorldBookEditResult {
  const WorldBookEditResult({required this.name, required this.description});

  final String name;
  final String description;
}

/// 书名最长字数。
const int kWorldBookNameMaxLength = 40;

class WorldBookEditSheet extends StatefulWidget {
  const WorldBookEditSheet({
    super.key,
    required this.title,
    this.initialName = '',
    this.initialDescription = '',
    this.entryCount,
    this.confirmLabel,
  });

  final String title;
  final String initialName;
  final String initialDescription;

  /// 编辑已有书时的条目数（预览行里显示）；新建时为 null。
  final int? entryCount;

  /// 确认按钮文字；缺省时新建为「创建」，编辑为「保存」。
  final String? confirmLabel;

  @override
  State<WorldBookEditSheet> createState() => _WorldBookEditSheetState();
}

class _WorldBookEditSheetState extends State<WorldBookEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initialDescription,
  );

  bool get _isNew => widget.entryCount == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      WorldBookEditResult(name: name, description: _description.text.trim()),
    );
  }

  InputDecoration _decoration(ThemeData theme, String hint) {
    final cs = theme.colorScheme;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: cs.surface,
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border(theme.dividerColor),
      enabledBorder: border(theme.dividerColor),
      focusedBorder: border(cs.primary, 1.5),
    );
  }

  Widget _label(ThemeData theme, String text, {String? note}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (note != null)
            TextSpan(
              text: '  $note',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _preview(ThemeData theme) {
    final cs = theme.colorScheme;
    final name = _name.text.trim();
    final hasName = name.isNotEmpty;
    final count = widget.entryCount ?? 0;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: hasName
                ? cs.onSurface
                : cs.onSurfaceVariant.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            LucideIcons.bookOpen,
            size: 22,
            color: hasName ? cs.surface : cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasName ? name : (_isNew ? '新世界书' : '未命名世界书'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: hasName ? FontWeight.w700 : FontWeight.w500,
                  color: hasName
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.title} · $count 个条目',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canSubmit = _name.text.trim().isNotEmpty;
    final confirm = widget.confirmLabel ?? (_isNew ? '创建' : '保存');
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _preview(theme),
                const SizedBox(height: 18),
                _label(theme, '名称'),
                TextField(
                  controller: _name,
                  autofocus: _isNew,
                  maxLength: kWorldBookNameMaxLength,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: _decoration(theme, '必填'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(
                    '${_name.text.characters.length} / $kWorldBookNameMaxLength',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                _label(theme, '描述', note: '可选'),
                TextField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _decoration(theme, '这本书写了什么'),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: buttonShape,
                          side: BorderSide(color: theme.dividerColor),
                          foregroundColor: cs.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: buttonShape,
                        ),
                        onPressed: canSubmit ? _submit : null,
                        child: Text(confirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
