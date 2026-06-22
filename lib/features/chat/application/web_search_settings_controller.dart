import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

part 'web_search_settings_controller.g.dart';

/// Persists web-search settings as a single JSON blob (the Flutter port of the
/// web's `webSearchSlice`). Same hydrate-on-build pattern as
/// [SidebarSettingsController].
@Riverpod(keepAlive: true)
class WebSearchSettingsController extends _$WebSearchSettingsController
    with JsonKvNotifier<WebSearchSettings> {
  @override
  ChatRepository get kvStore => ref.read(chatRepositoryProvider);

  @override
  String get storageKey => 'webSearchSettings';

  @override
  WebSearchSettings fromStored(Map<String, dynamic> json) =>
      WebSearchSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(WebSearchSettings value) => value.toJson();

  @override
  WebSearchSettings build() => hydrate(const WebSearchSettings());

  void setMaxResults(int value) => persist(state.copyWith(maxResults: value));

  void setTimeout(int value) => persist(state.copyWith(timeout: value));

  void setLanguage(String value) => persist(state.copyWith(language: value));

  void setCategories(String value) =>
      persist(state.copyWith(categories: value));
}
