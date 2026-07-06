import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/selection_menu_settings.dart';

part 'selection_menu_settings_controller.g.dart';

/// Storage key for the persisted 复制面板 settings (a single JSON blob).
const String kSelectionMenuSettingKey = 'selectionMenuSettings';

/// Holds the 复制面板（选中文本菜单）configuration, shared by the appearance
/// sub-page (editor + live preview) and the chat message selection areas.
///
/// `keepAlive: true`: an app-level preference. Hydrated from the Drift
/// key/value store on first build and written through on every change so the
/// configuration survives a full restart.
@Riverpod(keepAlive: true)
class SelectionMenuSettingsController extends _$SelectionMenuSettingsController
    with JsonKvNotifier<SelectionMenuSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kSelectionMenuSettingKey;

  @override
  SelectionMenuSettings fromStored(Map<String, dynamic> json) =>
      SelectionMenuSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(SelectionMenuSettings value) => value.toJson();

  @override
  SelectionMenuSettings build() => hydrate(const SelectionMenuSettings());

  /// Toggles 使用自定义复制面板 (off ⇒ system selection menu).
  void setUseCustomMenu(bool value) =>
      persist(state.copyWith(useCustomMenu: value));

  /// Replaces the enabled item id list (恢复预设 passes
  /// [kDefaultSelectionMenuItemIds]).
  void setEnabledItemIds(List<String> ids) =>
      persist(state.copyWith(enabledItemIds: ids));
}
