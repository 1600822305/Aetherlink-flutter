import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'auxiliary_model_controller.g.dart';

/// Persisted key/value keys for the 7 default model selections.
const String kChatModelKey = 'auxiliary_chat_model';
const String kFastModelKey = 'auxiliary_fast_model';
const String kTitleModelKey = 'auxiliary_title_model';
const String kSuggestionModelKey = 'auxiliary_suggestion_model';
const String kTranslateModelKey = 'auxiliary_translate_model';
const String kOcrModelKey = 'auxiliary_ocr_model';
const String kCompressModelKey = 'auxiliary_compress_model';

/// Persisted key/value keys for the 5 prompt strings.
const String kTranslatePromptKey = 'auxiliary_translate_prompt';
const String kTitlePromptKey = 'auxiliary_title_prompt';
const String kSuggestionPromptKey = 'auxiliary_suggestion_prompt';
const String kOcrPromptKey = 'auxiliary_ocr_prompt';
const String kCompressPromptKey = 'auxiliary_compress_prompt';

/// Persisted toggle for suggestion feature.
const String kEnableSuggestionKey = 'auxiliary_enable_suggestion';

/// Default prompt templates.
const String kDefaultTranslatePrompt =
    '你是一个翻译助手。请将以下内容翻译为目标语言，只返回翻译结果，不需要解释。\n\n'
    '变量：{{text}} — 要翻译的文本，{{targetLang}} — 目标语言';
const String kDefaultTitlePrompt =
    '你是一个对话标题生成助手。请根据对话内容生成一个简短的标题（不超过20字），不需要解释。\n\n'
    '变量：{{messages}} — 对话内容';
const String kDefaultSuggestionPrompt =
    '你是一个对话建议助手。请根据对话内容生成3-5个用户可能会问的后续问题，以JSON数组格式返回。\n\n'
    '变量：{{messages}} — 对话内容';
const String kDefaultOcrPrompt =
    '请描述这张图片的内容，包括主要对象、场景、颜色和任何文字。'
    '尽可能详细地描述，以便不能看到图片的人也能理解图片内容。';
const String kDefaultCompressPrompt =
    '你是一个对话摘要助手。请将以下对话历史压缩为简短的摘要，保留关键信息和上下文。\n\n'
    '变量：{{messages}} — 对话内容';

/// Encodes a `(providerId, modelId)` pair into a persisted key.
String _encodeModelKey(String providerId, String modelId) =>
    '$providerId\u0000$modelId';

/// Decodes a persisted key back into `(providerId, modelId)`, or `null`.
(String, String)? _decodeModelKey(String? key) {
  if (key == null || key.isEmpty) return null;
  final parts = key.split('\u0000');
  if (parts.length != 2) return null;
  return (parts[0], parts[1]);
}

/// Resolves a stored model key to a [CurrentModel] from the provider list.
CurrentModel? _resolveModel(String? key, List<ModelProvider> providers) {
  final pair = _decodeModelKey(key);
  if (pair == null) return null;
  final (providerId, modelId) = pair;
  for (final provider in providers) {
    if (provider.id != providerId) continue;
    for (final model in provider.models) {
      if (model.id == modelId) {
        return CurrentModel(provider: provider, model: model);
      }
    }
  }
  return null;
}

/// The complete persisted state for the 7 default model selections, the
/// suggestion toggle, and the 5 prompts. Hydrated from the key/value store on
/// first access.
class AuxiliaryModelState {
  const AuxiliaryModelState({
    this.chatModelKey,
    this.fastModelKey,
    this.titleModelKey,
    this.suggestionModelKey,
    this.translateModelKey,
    this.ocrModelKey,
    this.compressModelKey,
    this.enableSuggestion = false,
    this.translatePrompt = kDefaultTranslatePrompt,
    this.titlePrompt = kDefaultTitlePrompt,
    this.suggestionPrompt = kDefaultSuggestionPrompt,
    this.ocrPrompt = kDefaultOcrPrompt,
    this.compressPrompt = kDefaultCompressPrompt,
  });

  final String? chatModelKey;
  final String? fastModelKey;
  final String? titleModelKey;
  final String? suggestionModelKey;
  final String? translateModelKey;
  final String? ocrModelKey;
  final String? compressModelKey;
  final bool enableSuggestion;
  final String translatePrompt;
  final String titlePrompt;
  final String suggestionPrompt;
  final String ocrPrompt;
  final String compressPrompt;

  AuxiliaryModelState copyWith({
    String? Function()? chatModelKey,
    String? Function()? fastModelKey,
    String? Function()? titleModelKey,
    String? Function()? suggestionModelKey,
    String? Function()? translateModelKey,
    String? Function()? ocrModelKey,
    String? Function()? compressModelKey,
    bool? enableSuggestion,
    String? translatePrompt,
    String? titlePrompt,
    String? suggestionPrompt,
    String? ocrPrompt,
    String? compressPrompt,
  }) {
    return AuxiliaryModelState(
      chatModelKey: chatModelKey != null ? chatModelKey() : this.chatModelKey,
      fastModelKey: fastModelKey != null ? fastModelKey() : this.fastModelKey,
      titleModelKey: titleModelKey != null
          ? titleModelKey()
          : this.titleModelKey,
      suggestionModelKey: suggestionModelKey != null
          ? suggestionModelKey()
          : this.suggestionModelKey,
      translateModelKey: translateModelKey != null
          ? translateModelKey()
          : this.translateModelKey,
      ocrModelKey: ocrModelKey != null ? ocrModelKey() : this.ocrModelKey,
      compressModelKey: compressModelKey != null
          ? compressModelKey()
          : this.compressModelKey,
      enableSuggestion: enableSuggestion ?? this.enableSuggestion,
      translatePrompt: translatePrompt ?? this.translatePrompt,
      titlePrompt: titlePrompt ?? this.titlePrompt,
      suggestionPrompt: suggestionPrompt ?? this.suggestionPrompt,
      ocrPrompt: ocrPrompt ?? this.ocrPrompt,
      compressPrompt: compressPrompt ?? this.compressPrompt,
    );
  }
}

/// Controller that reads/writes the 7 default model selections + prompts
/// through the [ChatRepository] key/value store.
@Riverpod(keepAlive: true)
class AuxiliaryModelController extends _$AuxiliaryModelController {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  AuxiliaryModelState build() {
    _hydrate();
    return const AuxiliaryModelState();
  }

  Future<void> _hydrate() async {
    final results = await Future.wait([
      _repo.getSetting(kChatModelKey),
      _repo.getSetting(kFastModelKey),
      _repo.getSetting(kTitleModelKey),
      _repo.getSetting(kSuggestionModelKey),
      _repo.getSetting(kTranslateModelKey),
      _repo.getSetting(kOcrModelKey),
      _repo.getSetting(kCompressModelKey),
      _repo.getSetting(kEnableSuggestionKey),
      _repo.getSetting(kTranslatePromptKey),
      _repo.getSetting(kTitlePromptKey),
      _repo.getSetting(kSuggestionPromptKey),
      _repo.getSetting(kOcrPromptKey),
      _repo.getSetting(kCompressPromptKey),
    ]);
    state = AuxiliaryModelState(
      chatModelKey: results[0],
      fastModelKey: results[1],
      titleModelKey: results[2],
      suggestionModelKey: results[3],
      translateModelKey: results[4],
      ocrModelKey: results[5],
      compressModelKey: results[6],
      enableSuggestion: results[7] == 'true',
      translatePrompt: results[8] ?? kDefaultTranslatePrompt,
      titlePrompt: results[9] ?? kDefaultTitlePrompt,
      suggestionPrompt: results[10] ?? kDefaultSuggestionPrompt,
      ocrPrompt: results[11] ?? kDefaultOcrPrompt,
      compressPrompt: results[12] ?? kDefaultCompressPrompt,
    );
  }

  // ── Model setters ──

  void setChatModel(String providerId, String modelId) {
    final key = _encodeModelKey(providerId, modelId);
    state = state.copyWith(chatModelKey: () => key);
    _repo.saveSetting(kChatModelKey, key);
  }

  void setFastModel(String providerId, String modelId) {
    final key = _encodeModelKey(providerId, modelId);
    state = state.copyWith(fastModelKey: () => key);
    _repo.saveSetting(kFastModelKey, key);
  }

  void setTitleModel(String providerId, String modelId) {
    final key = _encodeModelKey(providerId, modelId);
    state = state.copyWith(titleModelKey: () => key);
    _repo.saveSetting(kTitleModelKey, key);
  }

  void clearTitleModel() {
    state = state.copyWith(titleModelKey: () => null);
    _repo.saveSetting(kTitleModelKey, '');
  }

  void setSuggestionModel(String providerId, String modelId) {
    final key = _encodeModelKey(providerId, modelId);
    state = state.copyWith(suggestionModelKey: () => key);
    _repo.saveSetting(kSuggestionModelKey, key);
  }

  void clearSuggestionModel() {
    state = state.copyWith(suggestionModelKey: () => null);
    _repo.saveSetting(kSuggestionModelKey, '');
  }

  void setEnableSuggestion(bool value) {
    state = state.copyWith(enableSuggestion: value);
    _repo.saveSetting(kEnableSuggestionKey, value.toString());
  }

  void setTranslateModel(String providerId, String modelId) {
    final key = _encodeModelKey(providerId, modelId);
    state = state.copyWith(translateModelKey: () => key);
    _repo.saveSetting(kTranslateModelKey, key);
  }

  void setOcrModel(String providerId, String modelId) {
    final key = _encodeModelKey(providerId, modelId);
    state = state.copyWith(ocrModelKey: () => key);
    _repo.saveSetting(kOcrModelKey, key);
  }

  void setCompressModel(String providerId, String modelId) {
    final key = _encodeModelKey(providerId, modelId);
    state = state.copyWith(compressModelKey: () => key);
    _repo.saveSetting(kCompressModelKey, key);
  }

  // ── Prompt setters ──

  void setTranslatePrompt(String value) {
    state = state.copyWith(translatePrompt: value);
    _repo.saveSetting(kTranslatePromptKey, value);
  }

  void resetTranslatePrompt() {
    state = state.copyWith(translatePrompt: kDefaultTranslatePrompt);
    _repo.saveSetting(kTranslatePromptKey, kDefaultTranslatePrompt);
  }

  void setTitlePrompt(String value) {
    state = state.copyWith(titlePrompt: value);
    _repo.saveSetting(kTitlePromptKey, value);
  }

  void resetTitlePrompt() {
    state = state.copyWith(titlePrompt: kDefaultTitlePrompt);
    _repo.saveSetting(kTitlePromptKey, kDefaultTitlePrompt);
  }

  void setSuggestionPrompt(String value) {
    state = state.copyWith(suggestionPrompt: value);
    _repo.saveSetting(kSuggestionPromptKey, value);
  }

  void resetSuggestionPrompt() {
    state = state.copyWith(suggestionPrompt: kDefaultSuggestionPrompt);
    _repo.saveSetting(kSuggestionPromptKey, kDefaultSuggestionPrompt);
  }

  void setOcrPrompt(String value) {
    state = state.copyWith(ocrPrompt: value);
    _repo.saveSetting(kOcrPromptKey, value);
  }

  void resetOcrPrompt() {
    state = state.copyWith(ocrPrompt: kDefaultOcrPrompt);
    _repo.saveSetting(kOcrPromptKey, kDefaultOcrPrompt);
  }

  void setCompressPrompt(String value) {
    state = state.copyWith(compressPrompt: value);
    _repo.saveSetting(kCompressPromptKey, value);
  }

  void resetCompressPrompt() {
    state = state.copyWith(compressPrompt: kDefaultCompressPrompt);
    _repo.saveSetting(kCompressPromptKey, kDefaultCompressPrompt);
  }
}

/// Resolves a stored model key to a display name like "Provider / Model".
/// Returns `null` if unresolvable.
@riverpod
Future<String?> auxiliaryModelDisplayName(Ref ref, String? modelKey) async {
  if (modelKey == null || modelKey.isEmpty) return null;
  final providers = await ref.watch(appModelProvidersProvider.future);
  final resolved = _resolveModel(modelKey, providers);
  if (resolved == null) return null;
  return '${resolved.provider.name} / ${resolved.model.name}';
}
