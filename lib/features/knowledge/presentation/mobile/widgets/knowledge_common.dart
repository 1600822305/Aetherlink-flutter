// 知识库页面通用小部件：分节标题 / 描边卡片 / bottom-sheet 通用外壳 /
// 检索模式选择。
import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';

class KnowledgeSectionHeader extends StatelessWidget {
  const KnowledgeSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class KnowledgeOutlinedCard extends StatelessWidget {
  const KnowledgeOutlinedCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Segmented selector for the three retrieval modes. 向量 / 混合 are disabled
/// (greyed out) until an embedding model is chosen. 建库 / 库设置面板共用。
class KnowledgeSearchModeSelector extends StatelessWidget {
  const KnowledgeSearchModeSelector({
    super.key,
    required this.mode,
    required this.enableSemantic,
    required this.onChanged,
  });

  final KnowledgeSearchMode mode;
  final bool enableSemantic;
  final ValueChanged<KnowledgeSearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(KnowledgeSearchMode value, String label) {
      final enabled = value == KnowledgeSearchMode.keyword || enableSemantic;
      final selected = mode == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: enabled ? (_) => onChanged(value) : null,
          selectedColor: theme.colorScheme.primary,
          disabledColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          labelStyle: TextStyle(
            color: !enabled
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                : selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    return Wrap(
      children: [
        chip(KnowledgeSearchMode.keyword, '关键词'),
        chip(KnowledgeSearchMode.vector, '向量'),
        chip(KnowledgeSearchMode.hybrid, '混合'),
      ],
    );
  }
}

/// Bottom-sheet 通用外壳：键盘避让 + 限高 + 标题 + 底部「取消 / 确认」操作行。
/// 表单控制器由各 State 持有，随退出动画结束后统一 dispose。
class KnowledgeSheetScaffold extends StatelessWidget {
  const KnowledgeSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final List<Widget> children;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...children,
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onConfirm, child: Text(confirmLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
