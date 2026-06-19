import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

/// Shared persistence behaviour for the `keepAlive` settings notifiers that back
/// a single JSON blob in the Drift key/value store (the port of the web
/// `dexieStorage.getSetting` / `saveSetting`).
///
/// Before this mixin every such controller hand-rolled the same three pieces —
/// a `_hydrate()` (read → `jsonDecode` → `fromJson`, swallowing corrupt values),
/// a `_persist()` (assign `state` → `saveSetting(jsonEncode(toJson))`) and the
/// storage key constant. They differ only in the settings type, the key and the
/// `fromJson` / `toJson` pair, so that boilerplate lives here once.
///
/// The store is reached through an injected [kvStore] getter rather than a
/// hard-coded provider, so both seams work without an import cycle: settings
/// features wire `appSettingsStoreProvider` (the `app/` composition seam) while
/// chat wires its own `chatRepositoryProvider` directly.
///
/// Mixed into a generated `@riverpod` notifier:
///
/// ```dart
/// @Riverpod(keepAlive: true)
/// class FooController extends _$FooController with JsonKvNotifier<Foo> {
///   @override
///   ChatRepository get kvStore => ref.read(appSettingsStoreProvider);
///   @override
///   String get storageKey => 'foo';
///   @override
///   Foo fromStored(Map<String, dynamic> json) => Foo.fromJson(json);
///   @override
///   Map<String, dynamic> toStored(Foo value) => value.toJson();
///
///   @override
///   Foo build() => hydrate(const Foo());
///
///   void setBar(bool value) => persist(state.copyWith(bar: value));
/// }
/// ```
mixin JsonKvNotifier<T> on $Notifier<T> {
  /// The key/value store backing this controller. Each controller wires the
  /// seam it is allowed to reach (settings → `appSettingsStoreProvider`, chat →
  /// `chatRepositoryProvider`).
  ChatRepository get kvStore;

  /// The single Drift key/value entry that stores this controller's JSON blob.
  String get storageKey;

  /// Decodes the stored JSON map back into the typed settings object.
  T fromStored(Map<String, dynamic> json);

  /// Encodes the typed settings object into the JSON map written to storage.
  Map<String, dynamic> toStored(T value);

  /// Returns [fallback] synchronously for `build()` and kicks off the async read
  /// that overwrites [state] once the stored blob is decoded — the hydrate-on-
  /// first-build behaviour shared by every JSON-blob settings notifier.
  T hydrate(T fallback) {
    _load();
    return fallback;
  }

  Future<void> _load() async {
    final stored = await kvStore.getSetting(storageKey);
    if (stored == null || stored.isEmpty) return;
    try {
      state = fromStored(jsonDecode(stored) as Map<String, dynamic>);
    } on FormatException {
      // Corrupt value — keep the defaults.
    }
  }

  /// Sets [next] as the new state and writes it through to [kvStore].
  void persist(T next) {
    state = next;
    kvStore.saveSetting(storageKey, jsonEncode(toStored(next)));
  }
}
