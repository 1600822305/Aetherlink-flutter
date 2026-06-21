import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/web_search_settings.dart';

part 'web_search_settings_controller.g.dart';

/// Storage key for the persisted web-search settings JSON blob.
const String kWebSearchSettingsKey = 'webSearchSettings';

/// Holds the web-search configuration (selected provider, max results, timeout).
/// Read by the chat controller to parameterize `builtin_web_search` and by the
/// settings page for the UI.
@Riverpod(keepAlive: true)
class WebSearchSettingsController extends _$WebSearchSettingsController
    with JsonKvNotifier<WebSearchSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kWebSearchSettingsKey;

  @override
  WebSearchSettings fromStored(Map<String, dynamic> json) =>
      WebSearchSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(WebSearchSettings value) => value.toJson();

  @override
  WebSearchSettings build() => hydrate(const WebSearchSettings());

  void setSelectedProvider(int value) =>
      persist(state.copyWith(selectedProvider: value));

  void setMaxResults(int value) =>
      persist(state.copyWith(maxResults: value));

  void setTimeout(int value) =>
      persist(state.copyWith(timeout: value));
}
