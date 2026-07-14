import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 思考程度档位 → 图标的唯一映射（单色，不带任何强调色，
/// 由使用方按主题给 onSurface 等中性色）。
/// 档位全集见 reasoning_model_detection.dart 的 `_reasoningEffortLabels`。
IconData reasoningEffortIcon(String value) => switch (value) {
  'none' || 'off' => LucideIcons.lightbulbOff,
  'default' => LucideIcons.lightbulb,
  'minimal' => LucideIcons.zap,
  'low' => LucideIcons.brain,
  'medium' => LucideIcons.brainCircuit,
  'high' => LucideIcons.sparkles,
  'xhigh' => LucideIcons.flame,
  'auto' => LucideIcons.wandSparkles,
  _ => LucideIcons.lightbulb,
};
