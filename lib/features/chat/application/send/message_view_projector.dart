import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_providers.dart';

/// Returns [blocks] sorted by the `message.blocks` id order (the canonical
/// render order); any block not referenced there is appended at the end.
List<MessageBlock> orderMessageBlocks(
  List<String> order,
  List<MessageBlock> blocks,
) {
  if (order.isEmpty) return blocks;
  final byId = {for (final block in blocks) block.id: block};
  final ordered = <MessageBlock>[];
  for (final id in order) {
    final block = byId.remove(id);
    if (block != null) ordered.add(block);
  }
  ordered.addAll(byId.values);
  return ordered;
}

/// Projects a persisted [Message] (+ its blocks) into the rendered
/// [ChatMessageView]: joins the text/thinking blocks, surfaces the first error
/// block, resolves the provider display name and carries the versioning /
/// multi-model metadata through. Owned by the chat controller; [Ref] and the
/// repository are getter callbacks because they change across provider
/// rebuilds. [debatePhaseOf] stays injected — the 辩论 phase tag lives in the
/// debate flow's metadata convention.
class MessageViewProjector {
  const MessageViewProjector(
    this._refOf, {
    required ChatRepository Function() repo,
    required String? Function(Map<String, dynamic>? metadata) debatePhaseOf,
  }) : _repoOf = repo,
       _debatePhaseOf = debatePhaseOf;

  final Ref Function() _refOf;
  final ChatRepository Function() _repoOf;
  final String? Function(Map<String, dynamic>? metadata) _debatePhaseOf;

  Future<ChatMessageView> viewOf(Message message) async {
    final fetched = await _repoOf().getMessageBlocksByMessageId(message.id);
    final blocks = orderMessageBlocks(message.blocks, fetched);
    final mainText = blocks
        .whereType<MainTextBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final summaryText = blocks
        .whereType<ContextSummaryBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final text = mainText.isNotEmpty ? mainText : summaryText;
    final thinking = blocks
        .whereType<ThinkingBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final errors = blocks.whereType<ErrorBlock>();
    final error = errors.isEmpty ? null : errors.first;
    final model = message.model;
    String? providerName;
    if (model != null) {
      if (model.provider == kModelComboProviderId) {
        providerName = '模型组合';
      } else {
        final providers = await _refOf().read(appModelProvidersProvider.future);
        for (final provider in providers) {
          if (provider.id == model.provider) {
            providerName = provider.name;
            break;
          }
        }
      }
    }
    return ChatMessageView(
      id: message.id,
      role: message.role,
      status: message.status,
      blocks: blocks,
      text: text,
      thinking: thinking,
      errorText: error?.message ?? error?.content,
      createdAt: message.createdAt,
      modelName: model?.name,
      providerName: providerName,
      modelId: model?.id ?? message.modelId,
      providerId: model?.provider,
      askId: message.askId,
      debatePhase: _debatePhaseOf(message.metadata),
      siblingsGroupId: message.siblingsGroupId,
      multiModelMessageStyle: message.multiModelMessageStyle,
      foldSelected: message.foldSelected ?? false,
      versions: message.versions ?? const <MessageVersion>[],
      currentVersionId: message.currentVersionId,
      usage: message.usage,
      metrics: message.metrics,
    );
  }
}
