import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/shared/domain/quick_phrase.dart';

part 'quick_phrases_controller.g.dart';

/// Storage key for the global quick phrases list (port of the web
/// `QuickPhraseService` global store, persisted in Dexie's `quickPhrases`
/// table). Flutter persists them as a single JSON-list key/value setting.
const String kQuickPhrasesSettingKey = 'quickPhrases';

/// Storage key for the 在输入框显示快捷短语按钮 toggle (port of the web
/// `settings.showQuickPhraseButton`). Persisted as a `'true'` / `'false'`
/// string in the same key/value store, defaulting to shown.
const String kShowQuickPhraseButtonKey = 'showQuickPhraseButton';

/// The global (assistant-independent) 快捷短语, persisted through the app-level
/// key/value store as a JSON list — the port of `QuickPhraseService`'s global
/// store. The 快捷短语管理 settings page owns the full CRUD; the chat composer reads
/// the list (and inserts a phrase) through the `app/di` access seam, mirroring
/// how the input-box config flows settings → chat. Assistant-scoped phrases live
/// separately on `Assistant.regularPhrases`; the in-chat selector shows assistant
/// phrases first, then these.
@Riverpod(keepAlive: true)
class GlobalQuickPhrases extends _$GlobalQuickPhrases {
  @override
  Future<List<QuickPhrase>> build() async {
    final raw = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kQuickPhrasesSettingKey);
    return _decode(raw);
  }

  /// Appends a new global phrase (fresh id / epoch timestamps) and persists —
  /// the port of `QuickPhraseService.add` for the 全局 location.
  Future<void> add({required String title, required String content}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = state.asData?.value ?? const <QuickPhrase>[];
    final phrase = QuickPhrase(
      id: generateId('phrase'),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      order: current.length,
    );
    await _commit(<QuickPhrase>[...current, phrase]);
  }

  /// Replaces an existing phrase's 标题 / 内容 (refreshing `updatedAt`) and
  /// persists — the port of `QuickPhraseService.update`. A no-op when [id] is
  /// unknown. (Named [edit] to avoid `AsyncNotifier`'s built-in `update`.)
  Future<void> edit(
    String id, {
    required String title,
    required String content,
  }) async {
    final current = state.asData?.value ?? const <QuickPhrase>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = current
        .map(
          (p) => p.id == id
              ? p.copyWith(title: title, content: content, updatedAt: now)
              : p,
        )
        .toList();
    await _commit(next);
  }

  /// Removes the phrase with [id] and persists — the port of
  /// `QuickPhraseService.delete`.
  Future<void> delete(String id) async {
    final current = state.asData?.value ?? const <QuickPhrase>[];
    await _commit(current.where((p) => p.id != id).toList());
  }

  Future<void> _commit(List<QuickPhrase> next) async {
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(kQuickPhrasesSettingKey, _encode(next));
    state = AsyncData<List<QuickPhrase>>(next);
  }

  static String _encode(List<QuickPhrase> phrases) =>
      jsonEncode(phrases.map((p) => p.toJson()).toList());

  static List<QuickPhrase> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const <QuickPhrase>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <QuickPhrase>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(QuickPhrase.fromJson)
        .toList();
  }
}

/// Whether the 快捷短语 button shows inside the chat 添加内容 menu (port of the web
/// `settings.showQuickPhraseButton`, gating `UploadMenu`'s quick-phrase row).
/// Toggled from the 快捷短语管理 page, read by the chat composer through the `app/di`
/// seam. Defaults to shown and survives a restart.
@Riverpod(keepAlive: true)
class ShowQuickPhraseButton extends _$ShowQuickPhraseButton {
  @override
  bool build() {
    _hydrate();
    return true;
  }

  Future<void> _hydrate() async {
    final raw = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kShowQuickPhraseButtonKey);
    if (raw == null || raw.isEmpty) return;
    state = raw == 'true';
  }

  /// Persists and applies the toggle.
  void setShown(bool value) {
    state = value;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kShowQuickPhraseButtonKey, value.toString());
  }
}
