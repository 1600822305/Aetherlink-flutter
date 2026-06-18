import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/shared/domain/quick_phrase.dart';

part 'quick_phrases_controller.g.dart';

/// Storage key for the global quick phrases list (port of the web
/// `QuickPhraseService` global store, persisted in Dexie's `quickPhrases`
/// table). Flutter persists them as a single JSON-list key/value setting.
const String kQuickPhrasesSettingKey = 'quickPhrases';

/// The global (assistant-independent) 快捷短语, persisted via [ChatRepository]'s
/// key/value settings as a JSON list — the port of `QuickPhraseService`'s global
/// store. Assistant-scoped phrases live separately on `Assistant.regularPhrases`
/// (see [Assistants.addRegularPhrase]); the selector shows assistant phrases
/// first, then these.
@Riverpod(keepAlive: true)
class GlobalQuickPhrases extends _$GlobalQuickPhrases {
  @override
  Future<List<QuickPhrase>> build() async {
    final raw = await ref
        .read(chatRepositoryProvider)
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
    final next = <QuickPhrase>[...current, phrase];
    await ref
        .read(chatRepositoryProvider)
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
