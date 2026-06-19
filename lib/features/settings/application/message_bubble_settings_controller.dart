import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';

part 'message_bubble_settings_controller.g.dart';

/// Storage key for the persisted 信息气泡管理 settings (a single JSON blob,
/// mirroring how the web kept these under the `settings` slice).
const String kMessageBubbleSettingKey = 'messageBubbleSettings';

/// Holds the 信息气泡管理 configuration (the original `settings.messageActionMode`
/// / `showMicroBubbles` / `showTTSButton` / `versionSwitchStyle` / bubble widths
/// / avatar & name toggles / hide-bubble toggles / `customBubbleColors`), so the
/// appearance sub-page and the chat view stay pure views.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and the
/// chat view. Hydrated from the Drift key/value store on first build and written
/// through on every change — the port of the web `dexieStorage.saveSetting` — so
/// the configuration survives a full restart.
@Riverpod(keepAlive: true)
class MessageBubbleSettingsController extends _$MessageBubbleSettingsController
    with JsonKvNotifier<MessageBubbleSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kMessageBubbleSettingKey;

  @override
  MessageBubbleSettings fromStored(Map<String, dynamic> json) =>
      MessageBubbleSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(MessageBubbleSettings value) => value.toJson();

  @override
  MessageBubbleSettings build() => hydrate(const MessageBubbleSettings());

  /// Sets 消息操作显示模式 (bubbles / toolbar).
  void setMessageActionMode(MessageActionMode mode) =>
      persist(state.copyWith(messageActionMode: mode));

  /// Toggles 显示功能气泡.
  void setShowMicroBubbles(bool value) =>
      persist(state.copyWith(showMicroBubbles: value));

  /// Toggles 显示播放按钮 (TTS).
  void setShowTTSButton(bool value) =>
      persist(state.copyWith(showTTSButton: value));

  /// Sets 版本切换样式 (popup / arrows).
  void setVersionSwitchStyle(VersionSwitchStyle style) =>
      persist(state.copyWith(versionSwitchStyle: style));

  /// Sets AI 消息最大宽度（%）.
  void setMessageBubbleMaxWidth(int value) =>
      persist(state.copyWith(messageBubbleMaxWidth: value));

  /// Sets 用户消息最大宽度（%）.
  void setUserMessageMaxWidth(int value) =>
      persist(state.copyWith(userMessageMaxWidth: value));

  /// Sets 消息最小宽度（%）.
  void setMessageBubbleMinWidth(int value) =>
      persist(state.copyWith(messageBubbleMinWidth: value));

  /// Toggles 显示用户头像.
  void setShowUserAvatar(bool value) =>
      persist(state.copyWith(showUserAvatar: value));

  /// Toggles 显示用户名称.
  void setShowUserName(bool value) =>
      persist(state.copyWith(showUserName: value));

  /// Toggles 显示模型头像.
  void setShowModelAvatar(bool value) =>
      persist(state.copyWith(showModelAvatar: value));

  /// Toggles 显示模型名称.
  void setShowModelName(bool value) =>
      persist(state.copyWith(showModelName: value));

  /// Toggles 隐藏用户气泡.
  void setHideUserBubble(bool value) =>
      persist(state.copyWith(hideUserBubble: value));

  /// Toggles 隐藏AI气泡.
  void setHideAIBubble(bool value) =>
      persist(state.copyWith(hideAIBubble: value));

  /// Replaces the whole 自定义气泡颜色 block.
  void setCustomBubbleColors(CustomBubbleColors colors) =>
      persist(state.copyWith(customBubbleColors: colors));

  /// Resets 自定义气泡颜色 back to empty (use the theme defaults).
  void resetCustomBubbleColors() =>
      persist(state.copyWith(customBubbleColors: const CustomBubbleColors()));
}
