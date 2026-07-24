import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/assistant_presets.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/groups_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_selection_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/topic_defaults.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_chat_background.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/custom_parameter.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/quick_phrase.dart';

part 'assistants_providers.g.dart';

/// All assistants, persisted via Drift. On a truly fresh store (no assistants
/// and no topics) it seeds the two web defaults (默认助手 + 网页分析助手), each with a
/// default topic — the port of `AssistantService.initializeDefaultAssistants()`.
@Riverpod(keepAlive: true)
class Assistants extends _$Assistants {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<List<Assistant>> build() async {
    final existing = await _repo.getAllAssistants();
    if (existing.isNotEmpty) return existing;
    // Only seed a pristine store; never seed over pre-existing topics.
    final topics = await _repo.getAllTopics();
    if (topics.isNotEmpty) return existing;
    return _seed();
  }

  Future<List<Assistant>> _seed() async {
    final now = DateTime.now();
    final defaultId = generateId('assistant');
    final webId = generateId('assistant');
    final defaultTopicId = generateId('topic');
    final webTopicId = generateId('topic');

    final defaultAssistant = Assistant(
      id: defaultId,
      name: '默认助手',
      description: '通用型AI助手，可以回答各种问题',
      systemPrompt: kDefaultAssistantPrompt,
      isSystem: true,
      type: 'assistant',
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[defaultTopicId],
    );
    final webAssistant = Assistant(
      id: webId,
      name: '网页分析助手',
      description: '帮助分析各种网页内容',
      systemPrompt: kWebAnalysisPrompt,
      isSystem: true,
      type: 'assistant',
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[webTopicId],
    );

    await _repo.saveAssistant(defaultAssistant);
    await _repo.saveAssistant(webAssistant);
    await _repo.saveTopic(
      newDefaultTopic(id: defaultTopicId, assistantId: defaultId, now: now),
    );
    await _repo.saveTopic(
      newDefaultTopic(id: webTopicId, assistantId: webId, now: now),
    );

    return <Assistant>[defaultAssistant, webAssistant];
  }

  Future<void> _reload() async {
    state = AsyncData<List<Assistant>>(await _repo.getAllAssistants());
  }

  /// Adds a picker [preset] as a new user assistant (fresh id, `isSystem:false`)
  /// with a default topic, then selects it — the port of `onAddAssistant`.
  Future<void> addPreset(Assistant preset) async {
    final now = DateTime.now();
    final id = generateId('assistant');
    final topicId = generateId('topic');
    final assistant = preset.copyWith(
      id: id,
      isSystem: false,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[topicId],
    );
    await _repo.saveAssistant(assistant);
    await _repo.saveTopic(
      newDefaultTopic(id: topicId, assistantId: id, now: now),
    );
    await _reload();
    ref.read(currentAssistantIdProvider.notifier).set(id);
    ref.read(currentTopicIdProvider.notifier).set(topicId);
  }

  /// Creates a brand-new assistant from user-supplied fields (the 创建助手 flow)
  /// with a default topic, then selects it.
  Future<void> createAssistant({
    required String name,
    required String systemPrompt,
    String? emoji,
    String? avatar,
    bool memoryEnabled = false,
    List<String> skillIds = const <String>[],
    ParameterSettings? paramSettings,
    AssistantChatBackground? chatBackground,
    List<AssistantRegex>? regexRules,
  }) async {
    final now = DateTime.now();
    final id = generateId('assistant');
    final topicId = generateId('topic');
    var assistant = Assistant(
      id: id,
      name: name,
      systemPrompt: systemPrompt,
      emoji: emoji,
      avatar: avatar,
      isSystem: false,
      isDefault: false,
      memoryEnabled: memoryEnabled,
      skillIds: skillIds,
      chatBackground: chatBackground,
      regexRules: regexRules,
      type: 'assistant',
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[topicId],
    );
    if (paramSettings != null) {
      assistant = _applyParamSettings(assistant, paramSettings);
    }
    await _repo.saveAssistant(assistant);
    await _repo.saveTopic(
      newDefaultTopic(id: topicId, assistantId: id, now: now),
    );
    await _reload();
    ref.read(currentAssistantIdProvider.notifier).set(id);
    ref.read(currentTopicIdProvider.notifier).set(topicId);
  }

  /// Duplicates [source] as "名称 (复制)" with its own default topic.
  Future<void> copy(Assistant source) async {
    final now = DateTime.now();
    final id = generateId('assistant');
    final topicId = generateId('topic');
    final assistant = source.copyWith(
      id: id,
      name: '${source.name} (复制)',
      isSystem: false,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[topicId],
    );
    await _repo.saveAssistant(assistant);
    await _repo.saveTopic(
      newDefaultTopic(id: topicId, assistantId: id, now: now),
    );
    await _reload();
  }

  /// Deletes [id] and its topics; if it was current, selects the next remaining
  /// assistant (or `null` when none remain) — the port of `handleDeleteAssistant`.
  Future<void> delete(String id) async {
    final all = await _repo.getAllAssistants();
    final topics = await _repo.getAllTopics();
    for (final topic in topics) {
      if (topic.assistantId == id) {
        await _repo.deleteTopic(topic.id);
      }
    }
    await _repo.deleteAssistant(id);
    await ref.read(groupsProvider.notifier).purgeItem(id, GroupType.assistant);
    await _reload();

    final currentId = ref.read(currentAssistantIdProvider);
    final effectiveCurrent = currentId ?? (all.isEmpty ? null : all.first.id);
    if (effectiveCurrent == id) {
      final remaining = all.where((a) => a.id != id).toList();
      ref
          .read(currentAssistantIdProvider.notifier)
          .set(remaining.isEmpty ? null : remaining.first.id);
      ref.read(currentTopicIdProvider.notifier).set(null);
    }
  }

  /// Saves [prompt] as [assistantId]'s 助手提示词 (`assistant.systemPrompt`) —
  /// the port of `SystemPromptDialog` assistant-mode save
  /// (`dexieStorage.saveAssistant` + the `assistantUpdated` event). [_reload]
  /// refreshes `currentAssistant`, so the bubble re-renders with the new text.
  Future<void> updateSystemPrompt(String assistantId, String prompt) async {
    final assistant = await _repo.getAssistant(assistantId);
    if (assistant == null) {
      throw StateError('没有找到助手信息');
    }
    await _repo.saveAssistant(
      assistant.copyWith(systemPrompt: prompt, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  /// Persists the fields edited in 编辑助手 (`EditAssistantDialog`):
  /// 名称 / 系统提示词 / 记忆开关 / 技能绑定 / 头像 / 模型参数 — the port of the
  /// web `handleSave` (`dexieStorage.saveAssistant` + the `assistantUpdated`
  /// event). [_reload] refreshes `currentAssistant` so dependents re-render.
  Future<void> applyEdits(
    String id, {
    required String name,
    required String systemPrompt,
    required bool memoryEnabled,
    required List<String> skillIds,
    String? emoji,
    String? avatar,
    ParameterSettings? paramSettings,
    AssistantChatBackground? chatBackground,
    List<AssistantRegex>? regexRules,
  }) async {
    final assistant = await _repo.getAssistant(id);
    if (assistant == null) {
      throw StateError('没有找到助手信息');
    }
    var updated = assistant.copyWith(
      name: name,
      systemPrompt: systemPrompt,
      memoryEnabled: memoryEnabled,
      skillIds: skillIds,
      emoji: emoji,
      avatar: avatar,
      chatBackground: chatBackground,
      regexRules: regexRules,
      updatedAt: DateTime.now(),
    );
    if (paramSettings != null) {
      updated = _applyParamSettings(updated, paramSettings);
    }
    await _repo.saveAssistant(updated);
    await _reload();
  }

  /// Converts [ParameterSettings] back to the flat fields on [Assistant].
  static Assistant _applyParamSettings(
    Assistant assistant,
    ParameterSettings ps,
  ) {
    final vals = ps.values;
    final flags = ps.enabledFlags;
    return assistant.copyWith(
      temperature: flags['temperature'] == true
          ? (vals['temperature'] as num?)?.toDouble()
          : null,
      topP: flags['topP'] == true ? (vals['topP'] as num?)?.toDouble() : null,
      maxTokens: flags['maxTokens'] == true
          ? (vals['maxTokens'] as num?)?.toInt()
          : null,
      frequencyPenalty: flags['frequencyPenalty'] == true
          ? (vals['frequencyPenalty'] as num?)?.toDouble()
          : null,
      presencePenalty: flags['presencePenalty'] == true
          ? (vals['presencePenalty'] as num?)?.toDouble()
          : null,
      customParameters: ps.customParameters
          .map(
            (cp) => CustomParameter(
              name: (cp['name'] as String?) ?? '',
              value: cp['value'],
              type: _parseCustomParamType(cp['type']),
            ),
          )
          .toList(),
    );
  }

  static CustomParameterType _parseCustomParamType(Object? raw) {
    if (raw is String) {
      for (final t in CustomParameterType.values) {
        if (t.name == raw) return t;
      }
    }
    return CustomParameterType.string;
  }

  /// Toggles whether [skillId] is bound to [assistantId] — the port of
  /// `useSkillBinding.toggleSkillForAssistant` (add/remove the id on
  /// `assistant.skillIds`, then persist). Used by the 技能管理 page's 绑定助手
  /// dialog. A no-op when the assistant can't be resolved.
  Future<void> toggleSkill(String assistantId, String skillId) async {
    final assistant = await _repo.getAssistant(assistantId);
    if (assistant == null) return;
    final current = assistant.skillIds ?? const <String>[];
    final next = current.contains(skillId)
        ? current.where((id) => id != skillId).toList()
        : <String>[...current, skillId];
    await _repo.saveAssistant(
      assistant.copyWith(skillIds: next, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  /// Appends a 助手快捷短语 to [assistantId]'s `regularPhrases` and persists — the
  /// assistant-scoped counterpart of `GlobalQuickPhrases.add` (the web
  /// `QuickPhraseService.add` for the 助手提示词 location). A no-op when the
  /// assistant can't be resolved.
  Future<void> addRegularPhrase(
    String assistantId, {
    required String title,
    required String content,
  }) async {
    final assistant = await _repo.getAssistant(assistantId);
    if (assistant == null) return;
    final now = DateTime.now();
    final existing = assistant.regularPhrases ?? const <QuickPhrase>[];
    final phrase = QuickPhrase(
      id: generateId('phrase'),
      title: title,
      content: content,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      order: existing.length,
    );
    await _repo.saveAssistant(
      assistant.copyWith(
        regularPhrases: <QuickPhrase>[...existing, phrase],
        updatedAt: now,
      ),
    );
    await _reload();
  }

  /// Removes every topic of [assistantId] — the port of 清空话题.
  Future<void> clearTopics(String assistantId) async {
    final topics = await _repo.getAllTopics();
    for (final topic in topics) {
      if (topic.assistantId == assistantId) {
        await _repo.deleteTopic(topic.id);
      }
    }
    final assistant = await _repo.getAssistant(assistantId);
    if (assistant != null) {
      await _repo.saveAssistant(assistant.copyWith(topicIds: const <String>[]));
    }
    // Resolve "current" via [currentAssistantIdProvider], NOT the derived
    // `currentAssistant` — the latter watches [assistantsProvider], so reading
    // it from this notifier throws a CircularDependencyError that aborts the
    // method before [_reload], leaving the UI stale (the 清空话题 lag bug).
    final selectedId = ref.read(currentAssistantIdProvider);
    await _reload();
    // `Topics` watches [assistantsProvider], so [_reload] above rebuilds it,
    // which refreshes the 话题数 / 话题列表 views.
    final all = state.asData?.value ?? const <Assistant>[];
    final effectiveCurrentId =
        selectedId ?? (all.isEmpty ? null : all.first.id);
    if (effectiveCurrentId == assistantId) {
      ref.read(currentTopicIdProvider.notifier).set(null);
    }
  }
}
