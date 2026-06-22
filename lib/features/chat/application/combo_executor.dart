import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_combo.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'combo_executor.g.dart';

/// Default handoff prompt template for sequential strategy.
const String kDefaultHandoffPrompt = '''
这是用户的原始问题：
{user_message}

以下是推理模型的思考过程：
<thinking>
{thinking}
</thinking>

请基于以上推理过程，结合你的专业知识，直接为用户提供完整、清晰的回答。''';

/// Resolved model references for combo execution.
class ResolvedComboModel {
  const ResolvedComboModel({
    required this.model,
    required this.provider,
    required this.role,
  });

  final Model model;
  final ModelProvider provider;
  final String role;
}

/// Result of resolving a combo's models against the persisted providers.
class ComboResolution {
  const ComboResolution({required this.combo, required this.models});

  final ModelComboConfig combo;
  final List<ResolvedComboModel> models;

  ResolvedComboModel? get thinkingModel =>
      models.where((m) => m.role == 'thinking').firstOrNull;

  ResolvedComboModel? get generatingModel =>
      models.where((m) => m.role == 'generating').firstOrNull;

  List<ResolvedComboModel> get candidateModels =>
      models.where((m) => m.role == 'candidate').toList();
}

/// Extra chunk types used by the combo executor to signal phase transitions
/// to the chat controller.
sealed class ComboStreamEvent {}

class ComboPhaseStart implements ComboStreamEvent {
  const ComboPhaseStart({required this.phase, required this.modelName});

  final String phase;
  final String modelName;
}

class ComboTextDelta implements ComboStreamEvent {
  const ComboTextDelta(this.text);

  final String text;
}

class ComboReasoningDelta implements ComboStreamEvent {
  const ComboReasoningDelta(this.text);

  final String text;
}

class ComboPhaseDone implements ComboStreamEvent {
  const ComboPhaseDone({required this.phase});

  final String phase;
}

class ComboDone implements ComboStreamEvent {
  const ComboDone();
}

/// Resolves a combo configuration's model entries into actual Model+Provider
/// objects from the persisted providers.
@riverpod
Future<ComboResolution?> resolveCombo(Ref ref, String comboId) async {
  final comboState = ref.watch(modelComboControllerProvider);
  final combo = comboState.combos.where((c) => c.id == comboId).firstOrNull;
  if (combo == null) return null;

  final providers = await ref.watch(appModelProvidersProvider.future);
  final resolved = <ResolvedComboModel>[];

  for (final entry in combo.models) {
    final parts = entry.modelId.split('/');
    if (parts.length < 2) continue;
    final providerId = parts[0];
    final modelId = parts.sublist(1).join('/');

    ModelProvider? foundProvider;
    Model? foundModel;
    for (final p in providers) {
      if (p.id == providerId) {
        foundProvider = p;
        for (final m in p.models) {
          if (m.id == modelId) {
            foundModel = m;
            break;
          }
        }
        break;
      }
    }

    if (foundProvider != null && foundModel != null) {
      resolved.add(
        ResolvedComboModel(
          model: effectiveModelFor(
            CurrentModel(provider: foundProvider, model: foundModel),
          ),
          provider: foundProvider,
          role: entry.role,
        ),
      );
    }
  }

  return ComboResolution(combo: combo, models: resolved);
}

/// Executes a sequential combo: thinking model first, then generating model
/// with the reasoning context. Returns a stream of [ComboStreamEvent]s.
Stream<ComboStreamEvent> executeSequentialCombo({
  required ComboResolution resolution,
  required LlmGateway thinkingGateway,
  required LlmGateway generatingGateway,
  required List<LlmMessage> messages,
  required String? system,
  int? maxTokens,
}) async* {
  final thinkingModel = resolution.thinkingModel;
  final generatingModel = resolution.generatingModel;
  if (thinkingModel == null || generatingModel == null) return;

  // Phase 1: Thinking
  yield ComboPhaseStart(phase: 'thinking', modelName: thinkingModel.model.name);

  final thinkingRequest = LlmChatRequest(
    model: thinkingModel.model,
    messages: messages,
    system: system,
    maxTokens: maxTokens,
  );

  final reasoning = StringBuffer();
  await for (final chunk in thinkingGateway.streamChat(thinkingRequest)) {
    switch (chunk) {
      case LlmTextDelta(:final text):
        reasoning.write(text);
        yield ComboReasoningDelta(text);
      case LlmReasoningDelta(:final text):
        reasoning.write(text);
        yield ComboReasoningDelta(text);
      case LlmToolCallChunk():
        break;
      case LlmDone():
        break;
    }
  }
  yield const ComboPhaseDone(phase: 'thinking');

  // Phase 2: Generating with reasoning context
  yield ComboPhaseStart(
    phase: 'generating',
    modelName: generatingModel.model.name,
  );

  final handoffTemplate =
      resolution.combo.handoffPrompt ?? kDefaultHandoffPrompt;

  // Extract the user's latest message text
  final lastUserText = messages.isNotEmpty ? messages.last.content : '';

  final handoffContent = handoffTemplate
      .replaceAll('{user_message}', lastUserText)
      .replaceAll('{thinking}', reasoning.toString());

  // Build generating request: original conversation + handoff as final user msg
  final genMessages = [
    ...messages.take(messages.length > 1 ? messages.length - 1 : 0),
    LlmMessage(role: MessageRole.user, content: handoffContent),
  ];

  final genRequest = LlmChatRequest(
    model: generatingModel.model,
    messages: genMessages,
    system: system,
    maxTokens: maxTokens,
    useResponsesAPI: generatingModel.provider.useResponsesAPI ?? false,
    extraHeaders: generatingModel.model.providerExtraHeaders,
    extraBody: generatingModel.model.providerExtraBody,
  );

  await for (final chunk in generatingGateway.streamChat(genRequest)) {
    switch (chunk) {
      case LlmTextDelta(:final text):
        yield ComboTextDelta(text);
      case LlmReasoningDelta(:final text):
        yield ComboTextDelta(text);
      case LlmToolCallChunk():
        break;
      case LlmDone():
        break;
    }
  }
  yield const ComboPhaseDone(phase: 'generating');
  yield const ComboDone();
}
