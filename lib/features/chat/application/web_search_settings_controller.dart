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
  WebSearchSettings fromStored(Map<String, dynamic> json) {
    final settings = WebSearchSettings.fromJson(json);
    // Guarantee web search works out of the box: if a previously-stored config
    // has no providers (e.g. an early build that didn't seed one), fall back to
    // the no-key SearXNG default so the active provider always resolves.
    if (settings.providers.isEmpty) {
      return settings.copyWith(providers: const [kDefaultSearchProvider]);
    }
    return settings;
  }

  @override
  Map<String, dynamic> toStored(WebSearchSettings value) => value.toJson();

  @override
  WebSearchSettings build() => hydrate(const WebSearchSettings());

  void setMaxResults(int value) => persist(state.copyWith(maxResults: value));

  void setTimeout(int value) => persist(state.copyWith(timeout: value));

  void setLanguage(String value) => persist(state.copyWith(language: value));

  void setCategories(String value) =>
      persist(state.copyWith(categories: value));

  void setActiveProvider(String id) =>
      persist(state.copyWith(activeProviderId: id));

  /// Adds a provider to the user's list. If a provider with the same id already
  /// exists, it is replaced.
  void addProvider(SearchProviderConfig provider) {
    final list = state.providers.toList()
      ..removeWhere((p) => p.id == provider.id)
      ..add(provider);
    persist(state.copyWith(
      providers: list,
      activeProviderId:
          state.providers.isEmpty ? provider.id : state.activeProviderId,
    ));
  }

  /// Removes a provider by id. If the removed provider was active, resets to
  /// the first remaining provider or 'searxng'.
  void removeProvider(String id) {
    final list = state.providers.where((p) => p.id != id).toList();
    final activeId = state.activeProviderId == id
        ? (list.isNotEmpty ? list.first.id : 'searxng')
        : state.activeProviderId;
    persist(state.copyWith(providers: list, activeProviderId: activeId));
  }

  /// Updates a single provider's config in place.
  void updateProvider(SearchProviderConfig updated) {
    final list = state.providers.map((p) {
      return p.id == updated.id ? updated : p;
    }).toList();
    persist(state.copyWith(providers: list));
  }

  /// Toggles a provider's enabled state.
  void toggleProvider(String id) {
    final list = state.providers.map((p) {
      return p.id == id ? p.copyWith(isEnabled: !p.isEnabled) : p;
    }).toList();
    persist(state.copyWith(providers: list));
  }
}
