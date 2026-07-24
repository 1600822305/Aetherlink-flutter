import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/app/di/system_prompt_variables_access.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/config/skill_prompt_builder.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_prompt.dart';
import 'package:aetherlink_flutter/shared/utils/system_prompt_variables.dart';

/// Assembles the system prompt for a conversation turn (the port of the web
/// `apiPreparation` prompt pipeline): assistant 系统提示词 + 话题提示词 +
/// bound-skill sections, placeholder substitution, 系统提示词变量 injection and
/// the `<user_memories>` memory section. Owned by the chat controller; [Ref],
/// repository and the active assistant/topic are getter callbacks because they
/// change across provider rebuilds and topic switches.
class SystemPromptBuilder {
  const SystemPromptBuilder(
    this._refOf, {
    required ChatRepository Function() repo,
    required String Function() assistantId,
    required String? Function() topicId,
  }) : _repoOf = repo,
       _assistantIdOf = assistantId,
       _topicIdOf = topicId;

  final Ref Function() _refOf;
  final ChatRepository Function() _repoOf;
  final String Function() _assistantIdOf;
  final String? Function() _topicIdOf;

  Ref get _ref => _refOf();
  ChatRepository get _repo => _repoOf();

  /// Assembles the system prompt for a conversation turn: the assistant's
  /// 系统提示词 combined with the 话题提示词 (the port of apiPreparation's
  /// `assistantPrompt [+ '\n\n' + topicPrompt]`), substitutes inline
  /// placeholder variables ([replaceSystemPromptPlaceholders] — `{model_name}`,
  /// `{assistant_name}`, `{cur_date}` …), then appends the enabled 系统提示词变量
  /// (time / location / OS / locale). Returns `null` when the assembled prompt
  /// is empty, so requests with no system prompt stay system-less (the
  /// append-only variables are never injected into an empty prompt, matching the
  /// web `injectSystemPromptVariables`).
  Future<String?> buildSystemPrompt({
    required String modelName,
    required String modelId,
    required String providerName,
  }) async {
    final memorySection = await buildChatMemoryInjection(
      _ref,
      assistantId: _assistantIdOf(),
    );
    return buildSystemPromptWith(
      memorySection,
      modelName: modelName,
      modelId: modelId,
      providerName: providerName,
    );
  }

  /// Like [buildSystemPrompt] but reuses a pre-resolved [memorySection] (from
  /// [collectChatMemoryInjection]) so the memory store is read once per turn.
  Future<String?> buildSystemPromptWith(
    String? memorySection, {
    required String modelName,
    required String modelId,
    required String providerName,
  }) async {
    final assistant = await _repo.getAssistant(_assistantIdOf());
    final assistantPrompt = assistant?.systemPrompt ?? '';
    final topicId = _topicIdOf();
    final topic = topicId == null ? null : await _repo.getTopic(topicId);
    final topicPrompt = (topic?.prompt?.trim().isNotEmpty ?? false)
        ? topic!.prompt!
        : '';

    final enabledSkills = await enabledSkillsFor(assistant?.skillIds);
    final base = enabledSkills.isNotEmpty
        ? assembleSkillSystemPrompt(
            assistantPrompt: assistantPrompt,
            enabledSkills: enabledSkills,
            topicPrompt: topicPrompt,
          )
        : (topicPrompt.isNotEmpty
              ? (assistantPrompt.isNotEmpty
                    ? '$assistantPrompt\n\n$topicPrompt'
                    : topicPrompt)
              : assistantPrompt);

    return _composeSystemPrompt(
      replaceSystemPromptPlaceholders(
        base,
        modelName: modelName,
        modelId: modelId,
        assistantName: assistant?.name ?? '',
        providerName: providerName,
      ),
      memorySection,
    );
  }

  /// Injects prompt variables into [base] and appends the resolved
  /// [memorySection] (the `<user_memories>` block, or null/empty for none),
  /// returning null when the result is empty. Split out so the send path can
  /// reuse the already-resolved memory section instead of querying the store
  /// twice.
  String? _composeSystemPrompt(String base, String? memorySection) {
    final injected = injectSystemPromptVariables(
      base,
      _ref.read(systemPromptVariablesProvider),
    );
    final withMemory = (memorySection == null || memorySection.isEmpty)
        ? injected
        : (injected.isEmpty ? memorySection : '$injected\n\n$memorySection');
    return withMemory.isEmpty ? null : withMemory;
  }

  /// The skills bound to the assistant ([skillIds]) that are currently enabled,
  /// in binding order — the port of `SkillManager.getSkillsForAssistant`.
  Future<List<Skill>> enabledSkillsFor(List<String>? skillIds) async {
    if (skillIds == null || skillIds.isEmpty) return const <Skill>[];
    final skills = await _ref.read(skillsProvider.future);
    final byId = {for (final s in skills) s.id: s};
    return [
      for (final id in skillIds)
        if (byId[id]?.enabled ?? false) byId[id]!,
    ];
  }

  /// The system prompt for a turn: in 提示词注入 mode the tool catalogue is woven
  /// into [base] (web `buildSystemPrompt`); otherwise [base] is used as-is and
  /// tools ride the native `tools` field. When 网络搜索 is active, a hint is
  /// appended encouraging the model to use the search tool.
  String? systemFor(McpSetup mcp, String? base) {
    var prompt = mcp.usePromptInjection
        ? buildMcpSystemPrompt(base, mcp.tools)
        : base;
    if (_ref.read(inputModeControllerProvider) == InputMode.webSearch) {
      const hint =
          '\n\n[网络搜索已启用] '
          '你可以使用 builtin_web_search 工具搜索互联网获取实时信息。'
          '当用户的问题可能需要最新信息时，请主动使用搜索工具。'
          '搜索结果中如果有有用的链接，请在回答中引用。';
      prompt = (prompt ?? '') + hint;
    }
    if (shouldExposeMemorySearchTool(_ref)) {
      const hint =
          '\n\n[长期记忆已启用] '
          '你可以使用 search_memory 工具检索关于用户的长期记忆（偏好、事实、历史）。'
          '当回答可能依赖用户的个人偏好或既往信息时，请先调用该工具确认。';
      prompt = (prompt ?? '') + hint;
    }
    if (mcp.routes.values.any((r) => r is KnowledgeToolRoute)) {
      const hint =
          '\n\n[知识库已启用] '
          '你可以使用 kb_search 工具在用户的知识库中检索资料，用 kb_read 取回条目全文。'
          '当用户的问题可能依赖其知识库内容时，请主动检索，并在回答中引用来源。';
      prompt = (prompt ?? '') + hint;
    }
    final workspaceContext = mcp.workspaceContext;
    if (workspaceContext != null && workspaceContext.isNotEmpty) {
      prompt = '${prompt ?? ''}\n\n$workspaceContext';
    }
    return prompt;
  }
}
