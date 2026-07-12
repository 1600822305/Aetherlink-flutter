import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

part 'app_main_mode.g.dart';

/// 持久化的主界面模式：退出前在哪个模式，冷启动就回哪个模式
/// （架构稿 §三：`app_main_mode` = `chat` | `agent`）。
const String kAppMainModeKey = 'app_main_mode';

enum AppMainMode { chat, agent }

/// 冷启动前先解析（app 壳等它 resolve 再建路由，避免闪屏），
/// 每次模式切换写穿。
@Riverpod(keepAlive: true)
class AppMainModeController extends _$AppMainModeController {
  @override
  Future<AppMainMode> build() async {
    final stored =
        await ref.read(appSettingsStoreProvider).getSetting(kAppMainModeKey);
    return stored == AppMainMode.agent.name
        ? AppMainMode.agent
        : AppMainMode.chat;
  }

  /// 切换主界面模式并持久化；聊天侧栏「智能体」按钮 / 智能体侧栏
  /// 「回聊天」按钮调用（导航本身由调用方走 go_router）。
  void use(AppMainMode mode) {
    state = AsyncData(mode);
    ref.read(appSettingsStoreProvider).saveSetting(kAppMainModeKey, mode.name);
  }
}
