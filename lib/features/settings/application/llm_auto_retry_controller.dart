import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

/// 普通聊天「请求失败自动重试」开关的持久化键（默认关，对齐 kelivo）。
/// 智能体任务始终自动重试（后台连续请求多，断网概率高），不受此开关影响。
const String kChatAutoRetryKey = 'chat_llm_auto_retry';

final chatLlmAutoRetryProvider =
    NotifierProvider<ChatLlmAutoRetryNotifier, bool>(
      ChatLlmAutoRetryNotifier.new,
    );

class ChatLlmAutoRetryNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.read(appSettingsStoreProvider).getSetting(kChatAutoRetryKey).then((
      raw,
    ) {
      final value = raw == 'true';
      if (value != state) state = value;
    });
    return false;
  }

  void set(bool value) {
    state = value;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kChatAutoRetryKey, value.toString());
  }
}
