import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/thinking_settings.dart';

part 'thinking_settings_controller.g.dart';

/// Storage key for the persisted 思考过程设置 (a single JSON blob, mirroring how
/// the web kept these under the `settings` slice).
const String kThinkingSettingKey = 'thinkingSettings';

/// Holds the 思考过程设置 configuration (the original `settings.thinkingDisplayStyle`
/// / `thoughtAutoCollapse` / `thinkingToolInline`), so the appearance sub-page
/// and the chat thinking block stay pure views.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and the
/// chat view. Hydrated from the Drift key/value store on first build and written
/// through on every change — the port of the web `dexieStorage.saveSetting` — so
/// the configuration survives a full restart.
@Riverpod(keepAlive: true)
class ThinkingSettingsController extends _$ThinkingSettingsController
    with JsonKvNotifier<ThinkingSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kThinkingSettingKey;

  @override
  ThinkingSettings fromStored(Map<String, dynamic> json) =>
      ThinkingSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(ThinkingSettings value) => value.toJson();

  @override
  ThinkingSettings build() => hydrate(const ThinkingSettings());

  /// Sets 思考过程显示样式.
  void setDisplayStyle(ThinkingDisplayStyle style) =>
      persist(state.copyWith(displayStyle: style));

  /// Toggles 思考完成后自动折叠.
  void setThoughtAutoCollapse(bool value) =>
      persist(state.copyWith(thoughtAutoCollapse: value));

  /// Toggles 思考过程内显示工具调用 (saved only — not wired to the chat view yet).
  void setThinkingToolInline(bool value) =>
      persist(state.copyWith(thinkingToolInline: value));
}
