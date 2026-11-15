import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_enricher.dart';

/// A single model row: the model name / id, a read-only capability-icon strip,
/// an optional 测试 button (when the 测试 toggle is on) and delete. Tapping the
/// row itself opens the edit page.
class ModelRow extends StatelessWidget {
  const ModelRow({
    super.key,
    required this.model,
    required this.showTest,
    required this.testing,
    required this.testDisabled,
    required this.onTap,
    required this.onTest,
    required this.onDelete,
  });

  final Model model;
  final bool showTest;
  final bool testing;
  final bool testDisabled;
  final VoidCallback onTap;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                model.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ModelCapabilityIcons(model: model),
            if (showTest)
              MiniIconBtn(
                icon: testing ? null : LucideIcons.circleCheckBig,
                loading: testing,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFF2E7D32),
                tooltip: '测试连接',
                onPressed: testDisabled ? null : onTest,
              ),
            MiniIconBtn(
              icon: LucideIcons.trash2,
              color: theme.colorScheme.error,
              tooltip: '删除',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only strip of Cherry-Studio-style capability badges: a colored icon
/// on a light tint of the same color, rounded. The icon set, colors and order
/// match Cherry's per-row `MODEL_DISPLAY_CAPABILITY_TAGS`
/// (`components/Tags/Model`); flags come from the v2 `is*Model` checks
/// (`capabilities` + `modelTypes`).
class ModelCapabilityIcons extends StatelessWidget {
  const ModelCapabilityIcons({super.key, required this.model});

  final Model model;

  static final List<
    ({bool Function(Model) test, IconData icon, Color color, String label})
  >
  _badges = [
    (
      test: isVisionModel,
      icon: LucideIcons.eye,
      color: const Color(0xFF00B96B),
      label: '视觉',
    ),
    (
      test: isWebSearchModel,
      icon: LucideIcons.globe,
      color: const Color(0xFF1677FF),
      label: '网络搜索',
    ),
    (
      test: isReasoningModel,
      icon: LucideIcons.lightbulb,
      color: const Color(0xFF6372BD),
      label: '推理',
    ),
    (
      test: isFunctionCallingModel,
      icon: LucideIcons.wrench,
      color: const Color(0xFFF18737),
      label: '函数调用',
    ),
    (
      test: isGenerateImageModel,
      icon: LucideIcons.image,
      color: const Color(0xFFA855F7),
      label: '图像生成',
    ),
    (
      test: isGenerateVideoModel,
      icon: LucideIcons.video,
      color: const Color(0xFFEC4899),
      label: '视频生成',
    ),
    (
      test: isEmbeddingModel,
      icon: LucideIcons.code2,
      color: const Color(0xFFFFA500),
      label: '嵌入',
    ),
    (
      test: isRerankModel,
      icon: LucideIcons.rotateCw,
      color: const Color(0xFF6495ED),
      label: '重排序',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Models added/imported/fetched after the v2 enricher carry `capabilities`;
    // older stored models may not. Enrich on the fly (stored data is kept
    // authoritative, otherwise inferred) so icons show regardless — same source
    // the editor uses.
    final m = enrichModelSync(model);
    final active = [
      for (final b in _badges)
        if (b.test(m)) b,
    ];
    if (active.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in active)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Tooltip(
                message: b.label,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: b.color.withValues(alpha: 0.125),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(b.icon, size: 12, color: b.color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 28×28 icon button for model rows — no Material splash padding bloat.
class MiniIconBtn extends StatelessWidget {
  const MiniIconBtn({
    super.key,
    this.icon,
    this.loading = false,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData? icon;
  final bool loading;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
          )
        : Icon(
            icon,
            size: 14,
            color: onPressed != null ? color : color.withValues(alpha: 0.4),
          );
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.all(5), child: child),
      ),
    );
  }
}
