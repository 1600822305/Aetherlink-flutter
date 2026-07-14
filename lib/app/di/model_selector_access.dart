import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/reasoning_effort_picker.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/widgets/reasoning_effort_icons.dart';

/// 模型选择器的跨 feature 复用 seam：agent 与 chat 互不 import
/// （架构测试 agent↔chat 硬约束，含 presentation），所以聊天的
/// `showModelSelectorDialog` 经 composition root 转发给 agent 侧。
/// 默认行为不变：选中即设为 App 级当前模型，只列聊天类模型。
Future<void> showAppModelSelectorDialog(BuildContext context) =>
    showModelSelectorDialog(context, filter: (m) => !isNonChatModel(m));

/// 思考档位弹层的跨 feature 转发（同上 seam）：与聊天共用
/// 参数设置里的全局 reasoningEffort 档位。
void showAppReasoningEffortPicker(BuildContext context, WidgetRef ref) =>
    showReasoningEffortPicker(context, ref);

/// 当前全局思考档位的图标（agent 输入栏 chip 显示用，单色）。
IconData appReasoningEffortIcon(WidgetRef ref) {
  final ps = ref.watch(parameterSettingsControllerProvider);
  final enabled = ps.isParameterEnabled('reasoningEffort');
  final value = (ps.getParameterValue('reasoningEffort') as String?) ?? '';
  if (!enabled) return reasoningEffortIcon('off');
  return reasoningEffortIcon(value.isEmpty ? 'medium' : value);
}

/// 当前全局思考档位的简短中文标签（agent 输入栏 chip 显示用）。
String appReasoningEffortLabel(WidgetRef ref) {
  final ps = ref.watch(parameterSettingsControllerProvider);
  final enabled = ps.isParameterEnabled('reasoningEffort');
  final value = (ps.getParameterValue('reasoningEffort') as String?) ?? '';
  if (!enabled || value == 'off' || value == 'none') return '关';
  return switch (value) {
    'minimal' => '极低',
    'low' => '低',
    'medium' => '中',
    'high' => '高',
    'auto' => '自动',
    _ => value.isEmpty ? '中' : value,
  };
}
