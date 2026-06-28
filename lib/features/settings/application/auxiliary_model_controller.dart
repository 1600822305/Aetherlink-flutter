import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
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
    '你是专业的图像内容提取助手。请将图片完整、忠实地转写为纯文本，'
    '供无法看到图片的模型使用。要求：\n'
    '1. 文字转写：逐字提取图中所有可见文字，保持原始顺序与分段；'
    '完整保留数字、标点、符号、URL 等；不要翻译、不要改写、不要增删。\n'
    '2. 结构还原：表格用 Markdown 还原其行列；代码用代码块还原；'
    '数学公式用 LaTeX 表示；图表需提取其数据与趋势；'
    '流程图/示意图需说明各节点及其连接关系；界面截图需说明主要元素与布局。\n'
    '3. 视觉描述：在文字之外，客观描述主体对象、场景、人物动作、空间布局与配色等关键信息。\n'
    '4. 忠实原则：只描述确实可见的内容，严禁臆测或编造；'
    '无法辨认处标注为「[无法辨认]」；不要添加图中不存在的解读或评论。\n'
    '5. 输出：先给文字转写、再给视觉描述；使用与图片内容一致的语言；'
    '直接输出提取结果本身，不要寒暄或额外说明。';
const String kDefaultCompressPrompt = '''你是一个对话压缩助手。请将以下对话历史压缩为精简摘要。

要求：
1. 保留关键事实、决策和继续对话所需的重要上下文
2. 使用与原始对话相同的语言
3. 目标约 {target_tokens} tokens
4. 直接输出摘要，不要添加任何额外评论
5. 以「[对话摘要]」开头

{additional_context}

<conversation>
{content}
</conversation>''';

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
CurrentModel? resolveAuxiliaryModel(
  String? key,
  List<ModelProvider> providers,
) {
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

    // Keep chatModelKey in sync with the app-level current model.
    // When the user switches model in the chat composer, the app current model
    // changes and this listener mirrors the change into the auxiliary setting.
    ref.listen(appCurrentModelProvider, (prev, next) {
      final currentModel = next.asData?.value;
      if (currentModel == null) return;
      final key = _encodeModelKey(
        currentModel.provider.id,
        currentModel.model.id,
      );
      if (key != state.chatModelKey) {
        state = state.copyWith(chatModelKey: () => key);
        _repo.saveSetting(kChatModelKey, key);
      }
    });

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

  Future<void> setChatModel(String providerId, String modelId) async {
    final key = _encodeModelKey(providerId, modelId);
    state = state.copyWith(chatModelKey: () => key);
    _repo.saveSetting(kChatModelKey, key);
    // Clear any active combo so the new model takes effect immediately.
    ref.read(modelComboControllerProvider.notifier).clearComboSelection();
    // Sync to the app-level current model so the chat composer uses this model.
    await ref
        .read(modelStoreProvider.notifier)
        .selectCurrentModel(providerId: providerId, modelId: modelId);
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
  final resolved = resolveAuxiliaryModel(modelKey, providers);
  if (resolved == null) return null;
  return '${resolved.provider.name} / ${resolved.model.name}';
}
