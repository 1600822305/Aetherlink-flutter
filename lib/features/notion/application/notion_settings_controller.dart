import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/notion/domain/notion_settings.dart';

part 'notion_settings_controller.g.dart';

/// Storage key for the Notion 集成 settings JSON blob.
const String kNotionSettingsKey = 'notionSettings';

/// Holds the Notion 集成 configuration. The settings page owns edits; the
/// export service reads the pure [NotionSettings] value.
@Riverpod(keepAlive: true)
class NotionSettingsController extends _$NotionSettingsController
    with JsonKvNotifier<NotionSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kNotionSettingsKey;

  @override
  NotionSettings fromStored(Map<String, dynamic> json) =>
      NotionSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(NotionSettings value) => value.toJson();

  @override
  NotionSettings build() => hydrate(const NotionSettings());

  void setEnabled(bool value) => persist(state.copyWith(enabled: value));

  /// Editing the token invalidates the previously resolved connection.
  void setApiKey(String value) =>
      persist(_clearConnection(state.copyWith(apiKey: value.trim())));

  /// Editing the database ID invalidates the previously resolved connection.
  void setDatabaseId(String value) =>
      persist(_clearConnection(state.copyWith(databaseId: value.trim())));

  /// Stores the resolved connection (data source + detected title property).
  void setConnection({
    required String dataSourceId,
    required String dataSourceName,
    required String titleProperty,
    required String dateProperty,
  }) => persist(
    state.copyWith(
      dataSourceId: dataSourceId,
      dataSourceName: dataSourceName,
      titleProperty: titleProperty,
      dateProperty: dateProperty,
    ),
  );

  void setDateProperty(String value) =>
      persist(state.copyWith(dateProperty: value));

  void setIncludeReasoning(bool value) =>
      persist(state.copyWith(includeReasoning: value));

  NotionSettings _clearConnection(NotionSettings s) => s.copyWith(
    dataSourceId: '',
    dataSourceName: '',
    titleProperty: '',
    dateProperty: '',
  );
}
