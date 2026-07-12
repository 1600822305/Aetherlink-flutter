import 'package:flutter/widgets.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';

/// 模型选择器的跨 feature 复用 seam：agent 与 chat 互不 import
/// （架构测试 agent↔chat 硬约束，含 presentation），所以聊天的
/// `showModelSelectorDialog` 经 composition root 转发给 agent 侧。
/// 默认行为不变：选中即设为 App 级当前模型，只列聊天类模型。
Future<void> showAppModelSelectorDialog(BuildContext context) =>
    showModelSelectorDialog(context, filter: (m) => !isNonChatModel(m));
