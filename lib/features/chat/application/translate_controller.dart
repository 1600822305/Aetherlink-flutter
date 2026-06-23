import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_history.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';

part 'translate_controller.g.dart';

/// Application layer backing the 翻译 page and the message toolbar 翻译 action
/// (functional port of the web `TranslateService` + `TranslatePage` local
/// state). The selected languages / model and the translation history are
/// persisted through the [ChatRepository] key/value settings, the Drift-backed
/// equivalent of the web's `localStorage` (`translate_source_language`,
/// `translate_target_language`, `translate_selected_model`, `translate_history`).

/// Setting keys (ports of the web `localStorage` keys).
const String kTranslateSourceLangKey = 'translate_source_language';
const String kTranslateTargetLangKey = 'translate_target_language';
const String kTranslateModelKey = 'translate_selected_model';
const String kTranslateHistoryKey = 'translate_history';

/// The `auto` sentinel for the source language (web `'auto'`).
const String kTranslateAutoLang = 'auto';

/// Mirrors the web `MAX_HISTORY_COUNT`.
const int kMaxTranslateHistory = 100;

/// Encodes a `(providerId, modelId)` pair into the persisted model key. Matches
/// the model-selector dialog's identity key so highlighting lines up.
String translateModelKeyOf(String providerId, String modelId) =>
    '$providerId\u0000$modelId';

/// The selected source language `langCode`, or [kTranslateAutoLang]. Hydrated
/// from / written through to persisted storage.
@Riverpod(keepAlive: true)
class TranslateSourceLanguage extends _$TranslateSourceLanguage {
  @override
  String build() {
    _hydrate();
    return kTranslateAutoLang;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(chatRepositoryProvider)
        .getSetting(kTranslateSourceLangKey);
    if (stored != null && stored.isNotEmpty) state = stored;
  }

  void set(String langCode) {
    state = langCode;
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kTranslateSourceLangKey, langCode);
  }
}

/// The selected target language `langCode` (defaults to English). Hydrated from
/// / written through to persisted storage.
@Riverpod(keepAlive: true)
class TranslateTargetLanguage extends _$TranslateTargetLanguage {
  @override
  String build() {
    _hydrate();
    return kDefaultTargetLanguage.langCode;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(chatRepositoryProvider)
        .getSetting(kTranslateTargetLangKey);
    if (stored != null && stored.isNotEmpty) state = stored;
  }

  void set(String langCode) {
    state = langCode;
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kTranslateTargetLangKey, langCode);
  }
}

/// The persisted translate model key (`providerId\u0000modelId`), or `null` to
/// fall back to the app's current chat model.
///
/// Single source of truth: [AuxiliaryModelController.translateModelKey].
/// This provider derives its state from the auxiliary controller so that
/// the sidebar translate page, message toolbar, and settings all share the
/// same selection.
@Riverpod(keepAlive: true)
class TranslateModelSelection extends _$TranslateModelSelection {
  @override
  String? build() {
    // Derive from auxiliary model controller — single source of truth.
    final auxiliaryKey = ref.watch(
      auxiliaryModelControllerProvider.select((s) => s.translateModelKey),
    );
    if (auxiliaryKey != null && auxiliaryKey.isNotEmpty) return auxiliaryKey;

    // One-time migration: if user previously configured via translate page
    // (old key), migrate that value to the unified key.
    _migrateOldKey();
    return null;
  }

  Future<void> _migrateOldKey() async {
    final oldStored = await ref
        .read(chatRepositoryProvider)
        .getSetting(kTranslateModelKey);
    if (oldStored != null && oldStored.isNotEmpty) {
      final parts = oldStored.split('\u0000');
      if (parts.length == 2) {
        // Write to the unified key via auxiliary controller.
        ref
            .read(auxiliaryModelControllerProvider.notifier)
            .setTranslateModel(parts[0], parts[1]);
      }
      // Clear the old key to avoid repeated migration.
      ref.read(chatRepositoryProvider).saveSetting(kTranslateModelKey, '');
    }
  }

  void set(String providerId, String modelId) {
    // Delegate to auxiliary controller — the single source of truth.
    ref
        .read(auxiliaryModelControllerProvider.notifier)
        .setTranslateModel(providerId, modelId);
  }
}

/// The model used for translation: the persisted [TranslateModelSelection] when
/// it still resolves to a known model, otherwise the app's current chat model
/// (port of `getTranslateModel`'s "use the configured model or the first
/// available" fallback).
@riverpod
Future<CurrentModel?> translateModel(Ref ref) async {
  final key = ref.watch(translateModelSelectionProvider);
  final providers = await ref.watch(appModelProvidersProvider.future);
  if (key != null && key.isNotEmpty) {
    final parts = key.split('\u0000');
    if (parts.length == 2) {
      final providerId = parts[0];
      final modelId = parts[1];
      for (final provider in providers) {
        if (provider.id != providerId) continue;
        for (final model in provider.models) {
          if (model.id == modelId) {
            return CurrentModel(provider: provider, model: model);
          }
        }
      }
    }
  }
  return findCurrentModel(providers);
}

/// The translation history list, newest first. Drift-backed port of the web
/// `getTranslateHistories` / `saveTranslateHistory` / … `localStorage` helpers.
@Riverpod(keepAlive: true)
class TranslateHistoryStore extends _$TranslateHistoryStore {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<List<TranslateHistory>> build() async {
    final raw = await _repo.getSetting(kTranslateHistoryKey);
    return _decode(raw);
  }

  List<TranslateHistory> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            TranslateHistory.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _persist(List<TranslateHistory> histories) async {
    state = AsyncData(histories);
    await _repo.saveSetting(
      kTranslateHistoryKey,
      jsonEncode([for (final h in histories) h.toJson()]),
    );
  }

  /// Prepends a new record (capped at [kMaxTranslateHistory]). Port of
  /// `saveTranslateHistory`.
  Future<void> add({
    required String sourceText,
    required String targetText,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final current = state.value ?? const [];
    final entry = TranslateHistory(
      id: generateId('tr'),
      sourceText: sourceText,
      targetText: targetText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      createdAt: DateTime.now(),
    );
    final next = [entry, ...current];
    if (next.length > kMaxTranslateHistory) {
      next.removeRange(kMaxTranslateHistory, next.length);
    }
    await _persist(next);
  }

  /// Port of `deleteTranslateHistory`.
  Future<void> remove(String id) async {
    final current = state.value ?? const [];
    await _persist([
      for (final h in current)
        if (h.id != id) h,
    ]);
  }

  /// Port of `toggleHistoryStar`.
  Future<void> toggleStar(String id) async {
    final current = state.value ?? const [];
    await _persist([
      for (final h in current)
        if (h.id == id) h.copyWith(star: !h.star) else h,
    ]);
  }

  /// Port of `clearTranslateHistory`.
  Future<void> clear() async {
    await _persist(const []);
  }
}
