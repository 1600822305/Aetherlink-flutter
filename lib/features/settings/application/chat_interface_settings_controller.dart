import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';

part 'chat_interface_settings_controller.g.dart';

/// Storage key for the persisted chat-interface settings (a single JSON blob,
/// mirroring how the web kept these under the `settings` slice).
const String kChatInterfaceSettingKey = 'chatInterfaceSettings';

/// Holds the 聊天界面设置 configuration (the original `settings.multiModelDisplayStyle`
/// / `showToolDetails` / `showCitationDetails` / `showSystemPromptBubble` /
/// `chatBackground`), so the appearance sub-page stays a pure view.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and
/// (later) the chat view. Hydrated from the Drift key/value store on first
/// build and written through on every change — the port of the web
/// `dexieStorage.saveSetting` — so the configuration survives a full restart.
@Riverpod(keepAlive: true)
class ChatInterfaceSettingsController extends _$ChatInterfaceSettingsController
    with JsonKvNotifier<ChatInterfaceSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kChatInterfaceSettingKey;

  @override
  ChatInterfaceSettings fromStored(Map<String, dynamic> json) =>
      ChatInterfaceSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(ChatInterfaceSettings value) => value.toJson();

  @override
  ChatInterfaceSettings build() => hydrate(const ChatInterfaceSettings());

  /// Sets the 多模型对比显示 layout.
  void setMultiModelDisplayStyle(MultiModelDisplayStyle style) =>
      persist(state.copyWith(multiModelDisplayStyle: style));

  /// Toggles 显示工具调用详情.
  void setShowToolDetails(bool value) =>
      persist(state.copyWith(showToolDetails: value));

  /// Toggles 显示引用详情.
  void setShowCitationDetails(bool value) =>
      persist(state.copyWith(showCitationDetails: value));

  /// Toggles 系统提示词气泡显示.
  void setShowSystemPromptBubble(bool value) =>
      persist(state.copyWith(showSystemPromptBubble: value));

  /// Replaces the whole 聊天背景 block.
  void setBackground(ChatBackgroundSettings background) =>
      persist(state.copyWith(background: background));
}
