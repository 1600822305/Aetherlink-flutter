import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'chat_controller.g.dart';

/// Orchestrates the chat send/stream loop (application layer).
///
/// It owns the rendered conversation ([ChatState]) and depends only on ports:
/// the [ChatRepository] for persistence, the cross-feature current model
/// (`appCurrentModelProvider`), and the `LlmGatewayFactory` for the gateway —
/// every concrete implementation is injected via Riverpod (the DI seam in
/// `chat_providers.dart` / `app/di/model_access.dart`), so the boundary tests
/// hold and tests run the whole loop with a fake gateway.
///
/// Send flow: persist the user message (+ `main_text` block) → persist a
/// streaming assistant message → build an [LlmChatRequest] from the current
/// model + history → subscribe to the gateway stream, accumulating text into
/// the assistant's `main_text` and reasoning into its `thinking` while updating
/// state per chunk → on [LlmDone] finalize and persist the blocks; on a stream
/// error mark the message errored and persist an `error` block.
@riverpod
class ChatController extends _$ChatController {
  static const String _defaultAssistantId = 'default-assistant';

  String? _topicId;
  String _assistantId = _defaultAssistantId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<ChatState> build() async {
    // In-place mutations of the current conversation (清空消息) bump this so the
    // view reloads without changing the selected topic id.
    ref.watch(chatRefreshProvider);
    final topic = await ref.watch(currentTopicProvider.future);
    if (topic == null) {
      _topicId = null;
      return ChatState.initial();
    }
    _topicId = topic.id;
    _assistantId = topic.assistantId;

    final messages = await _repo.getMessagesByTopicId(topic.id)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final views = <ChatMessageView>[];
    for (final message in messages) {
      views.add(await _viewOf(message));
    }
    return ChatState(messages: views);
  }

  /// Sends [text] as a user message and streams the assistant reply. A
  /// blank message, a missing current model, or an in-flight stream are no-ops
  /// (the composer also disables the button in those cases).
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final snapshot = state.value ?? ChatState.initial();
    if (snapshot.isStreaming) return;

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    final topicId = await _ensureTopic();
    final now = DateTime.now();

    // 1. User message + main_text block, persisted.
    final userMessageId = generateId('msg');
    final userBlockId = generateId('block');
    final userMessage = Message(
      id: userMessageId,
      role: MessageRole.user,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.success,
      blocks: <String>[userBlockId],
    );
    await _repo.saveMessage(userMessage);
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: userBlockId,
        messageId: userMessageId,
        status: MessageBlockStatus.success,
        createdAt: now,
        content: trimmed,
      ),
    );

    // 2. Assistant message in streaming state, persisted.
    final assistantTime = now.add(const Duration(microseconds: 1));
    final assistantMessageId = generateId('msg');
    final assistantBlockId = generateId('block');
    final effective = effectiveModelFor(current);
    final assistantMessage = Message(
      id: assistantMessageId,
      role: MessageRole.assistant,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: assistantTime,
      status: MessageStatus.streaming,
      model: effective,
      blocks: <String>[assistantBlockId],
    );
    await _repo.saveMessage(assistantMessage);
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: assistantBlockId,
        messageId: assistantMessageId,
        status: MessageBlockStatus.streaming,
        createdAt: assistantTime,
        content: '',
      ),
    );

    final userView = ChatMessageView(
      id: userMessageId,
      role: MessageRole.user,
      status: MessageStatus.success,
      text: trimmed,
      blocks: <MessageBlock>[
        MessageBlock.mainText(
          id: userBlockId,
          messageId: userMessageId,
          status: MessageBlockStatus.success,
          createdAt: now,
          content: trimmed,
        ),
      ],
      createdAt: now,
    );
    final assistantView = ChatMessageView(
      id: assistantMessageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      createdAt: assistantTime,
      modelName: effective.name,
      providerName: current.provider.name,
    );
    final views = [...snapshot.messages, userView, assistantView];
    _emit(views, isStreaming: true);

    // 3. Build the request from the current model + history (the user turn we
    // just added included; the empty assistant placeholder excluded).
    final request = LlmChatRequest(
      model: effective,
      messages: [
        for (final view in views)
          if (view.role != MessageRole.assistant || view.text.isNotEmpty)
            LlmMessage(role: view.role, content: view.text),
      ],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
      assistantMessageId: assistantMessageId,
      assistantBlockId: assistantBlockId,
      assistantTime: assistantTime,
      views: views,
      assistantView: assistantView,
    );
  }

  /// Regenerates the assistant reply [messageId] in place.
  ///
  /// Port of the toolbar 重新生成 action (`regenerateResponse` with
  /// `source: 'assistant'`): the message keeps its id but its old blocks are
  /// dropped, it is reset to a streaming state re-pointed at the current model,
  /// and a fresh reply is streamed from the conversation that preceded it.
  /// Before overwriting, the currently displayed content is archived as a
  /// version via [_prepareForRegenerate] (mirroring `prepareForRegenerate`), so
  /// the previous reply can be restored from 版本历史. A no-op while a reply is
  /// streaming, when the conversation has not loaded, when no model is selected,
  /// or when [messageId] is not a loaded assistant message.
  Future<void> regenerate(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;

    final index = snapshot.messages.indexWhere((view) => view.id == messageId);
    if (index == -1) return;

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    final target = await _repo.getMessage(messageId);
    if (target == null || target.role != MessageRole.assistant) return;

    final now = DateTime.now();
    final effective = effectiveModelFor(current);

    // Archive the currently displayed content as a version, then reset the
    // assistant message: drop its old blocks and attach a single fresh
    // streaming main_text block, re-pointed at the current model, with the
    // freshly streamed reply becoming the new latest (currentVersionId null).
    final prepared = await _prepareForRegenerate(target, now);
    final oldBlocks = await _repo.getMessageBlocksByMessageId(messageId);
    for (final block in oldBlocks) {
      await _repo.deleteMessageBlock(block.id);
    }
    final assistantBlockId = generateId('block');
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: assistantBlockId,
        messageId: messageId,
        status: MessageBlockStatus.streaming,
        createdAt: now,
        content: '',
      ),
    );
    await _repo.saveMessage(
      prepared.copyWith(
        status: MessageStatus.streaming,
        updatedAt: now,
        model: effective,
        blocks: <String>[assistantBlockId],
        currentVersionId: null,
      ),
    );

    // Reset the view to a streaming placeholder; the request history is the
    // conversation up to (excluding) this assistant message.
    final views = List<ChatMessageView>.of(snapshot.messages);
    final assistantView = ChatMessageView(
      id: messageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      createdAt: target.createdAt,
      modelName: effective.name,
      providerName: current.provider.name,
    );
    views[index] = assistantView;
    _emit(views, isStreaming: true);

    final request = LlmChatRequest(
      model: effective,
      messages: [
        for (final view in views.sublist(0, index))
          if (view.role != MessageRole.assistant || view.text.isNotEmpty)
            LlmMessage(role: view.role, content: view.text),
      ],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
      assistantMessageId: messageId,
      assistantBlockId: assistantBlockId,
      assistantTime: now,
      views: views,
      assistantView: assistantView,
    );
  }

  /// Subscribes to the gateway stream for [request], accumulating text into the
  /// assistant's `main_text` and reasoning into its `thinking` while emitting a
  /// streaming view per chunk, then finalizes: on [LlmDone] persists the blocks
  /// and reloads the view; on a stream error marks the message errored and
  /// persists an `error` block. Shared by [send] and [regenerate].
  Future<void> _streamInto({
    required LlmChatRequest request,
    required Model effective,
    required String assistantMessageId,
    required String assistantBlockId,
    required DateTime assistantTime,
    required List<ChatMessageView> views,
    required ChatMessageView assistantView,
  }) async {
    final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);

    final buffer = StringBuffer();
    final thinking = StringBuffer();
    var view = assistantView;

    void update() {
      // Synthesize streaming blocks from the live buffers so the renderer can
      // dispatch them (thinking card + main_text Markdown) exactly as it will
      // once the persisted blocks are reloaded on finalize.
      final liveBlocks = <MessageBlock>[
        if (thinking.isNotEmpty)
          MessageBlock.thinking(
            id: '$assistantMessageId::thinking',
            messageId: assistantMessageId,
            status: MessageBlockStatus.streaming,
            createdAt: assistantTime,
            content: thinking.toString(),
          ),
        MessageBlock.mainText(
          id: assistantBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.streaming,
          createdAt: assistantTime,
          content: buffer.toString(),
        ),
      ];
      view = view.copyWith(
        text: buffer.toString(),
        thinking: thinking.toString(),
        blocks: liveBlocks,
      );
      _replace(views, view);
      _emit(views, isStreaming: true);
    }

    try {
      await for (final chunk in gateway.streamChat(request)) {
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
            update();
          case LlmReasoningDelta(:final text):
            thinking.write(text);
            update();
          case LlmDone():
            break;
        }
      }
      await _finalizeSuccess(
        messageId: assistantMessageId,
        mainBlockId: assistantBlockId,
        createdAt: assistantTime,
        text: buffer.toString(),
        thinking: thinking.toString(),
      );
      view = await _reloadView(assistantMessageId, view);
      _replace(views, view);
      _emit(views, isStreaming: false);
    } on Object catch (error) {
      final messageText = _errorMessage(error);
      await _finalizeError(
        messageId: assistantMessageId,
        createdAt: assistantTime,
        text: buffer.toString(),
        errorText: messageText,
      );
      view = await _reloadView(
        assistantMessageId,
        view.copyWith(status: MessageStatus.error, errorText: messageText),
      );
      _replace(views, view);
      _emit(views, isStreaming: false);
    }
  }

  /// Deletes [messageId] together with its blocks and drops it from the view.
  ///
  /// Port of the toolbar 删除 action (`MessageActions.handleToolbarDeleteClick`
  /// → `onDelete`). The two-click confirmation lives in the UI; this performs
  /// the actual removal once confirmed. A no-op while a reply is streaming or
  /// when the conversation has not loaded.
  Future<void> deleteMessage(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    await _repo.deleteMessage(messageId);
    final views = snapshot.messages
        .where((view) => view.id != messageId)
        .toList();
    _emit(views, isStreaming: false);
  }

  /// Writes [contentByBlockId] back to the message's `main_text` blocks and
  /// persists them, then reloads the affected view.
  ///
  /// Port of the toolbar 编辑 action (`MessageEditor.handleSave`): each edited
  /// `main_text` block is updated in place (content + `updatedAt`), the message
  /// `updatedAt` is bumped, and the rendered view is refreshed from storage.
  /// Blank entries and blocks that are not `main_text` are skipped. A no-op
  /// while a reply is streaming.
  Future<void> editMessageText(
    String messageId,
    Map<String, String> contentByBlockId,
  ) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    if (contentByBlockId.isEmpty) return;

    final now = DateTime.now();
    var changed = false;
    for (final entry in contentByBlockId.entries) {
      final trimmed = entry.value.trim();
      if (trimmed.isEmpty) continue;
      final existing = await _repo.getMessageBlock(entry.key);
      if (existing is MainTextBlock && existing.content != trimmed) {
        await _repo.saveMessageBlock(
          existing.copyWith(content: trimmed, updatedAt: now),
        );
        changed = true;
      }
    }
    if (!changed) return;

    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    await _repo.saveMessage(message.copyWith(updatedAt: now));

    final reloaded = await _viewOf(message);
    final views = List<ChatMessageView>.of(snapshot.messages);
    final index = views.indexWhere((view) => view.id == messageId);
    if (index != -1) {
      views[index] = reloaded;
      _emit(views, isStreaming: false);
    }
  }

  // --- Version history ------------------------------------------------------

  /// Maximum number of saved versions kept per message; older versions (and
  /// their cloned blocks) are pruned once exceeded. Mirrors
  /// `VersionService.MAX_VERSIONS_PER_MESSAGE`.
  static const int _maxVersionsPerMessage = 20;

  static const String _latestSnapshotKey = 'latestSnapshot';

  /// Manually saves the message's current content as a version (the 保存当前
  /// button). Port of `versionService.createManualVersion`. A no-op while a
  /// reply is streaming or when the content is empty.
  Future<void> createManualVersion(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    final updated = await _saveCurrentAsVersion(message, source: 'manual');
    if (updated == null) return;
    await _reloadIntoState(messageId);
  }

  /// Switches the displayed content of [messageId] to version [versionId].
  ///
  /// Port of `versionService.switchToVersion`: when leaving the latest (live)
  /// content for the first time the live blocks are stashed (so they can be
  /// restored later), then the message's blocks are replaced with clones of the
  /// version's blocks and [Message.currentVersionId] is set. A no-op while a
  /// reply is streaming.
  Future<void> switchToVersion(String messageId, String versionId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    var message = await _repo.getMessage(messageId);
    if (message == null) return;
    final version = _findVersion(message, versionId);
    if (version == null) return;

    final now = DateTime.now();
    // Stash the live content the first time we leave the latest view.
    if (message.currentVersionId == null) {
      message = await _stashLatestSnapshot(message, now);
    }

    final previousBlockIds = message.blocks;
    final versionBlocks = await _repo.getMessageBlocksByIds(version.blocks);
    final List<String> newBlockIds;
    if (versionBlocks.isNotEmpty) {
      final clones = _cloneBlocks(versionBlocks, messageId, now);
      await _repo.saveMessageBlocks(clones);
      newBlockIds = [for (final block in clones) block.id];
    } else {
      // No block copies survived: rebuild a single main_text block from the
      // version's content snapshot, like the web fallback.
      final blockId = generateId('block');
      await _repo.saveMessageBlock(
        MessageBlock.mainText(
          id: blockId,
          messageId: messageId,
          status: MessageBlockStatus.success,
          createdAt: now,
          updatedAt: now,
          content: _versionSnapshotText(version),
        ),
      );
      newBlockIds = <String>[blockId];
    }
    await _deleteBlocks(previousBlockIds);
    await _repo.saveMessage(
      message.copyWith(
        blocks: newBlockIds,
        currentVersionId: versionId,
        model: version.model ?? message.model,
        modelId: version.modelId ?? message.modelId,
        updatedAt: now,
      ),
    );
    await _reloadIntoState(messageId);
  }

  /// Switches [messageId] back to the latest (live) content, restoring the
  /// blocks stashed when history was first opened. Port of
  /// `versionService.switchToLatest`. A no-op while streaming or when already
  /// showing the latest content.
  Future<void> switchToLatest(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _repo.getMessage(messageId);
    if (message == null || message.currentVersionId == null) return;

    final now = DateTime.now();
    final snap = _latestSnapshot(message);
    final previousBlockIds = message.blocks;
    var restoredModel = message.model;
    var newBlockIds = previousBlockIds;

    if (snap != null && snap.blockIds.isNotEmpty) {
      final stashed = await _repo.getMessageBlocksByIds(snap.blockIds);
      if (stashed.isNotEmpty) {
        // Re-own the stashed blocks (they keep their ids) and drop the history
        // clones currently on display.
        final reowned = [
          for (final block in stashed)
            block.copyWith(messageId: messageId, updatedAt: now),
        ];
        await _repo.saveMessageBlocks(reowned);
        newBlockIds = [for (final block in reowned) block.id];
        restoredModel = snap.model ?? restoredModel;
        await _deleteBlocks(previousBlockIds);
      }
    }

    await _repo.saveMessage(
      message.copyWith(
        blocks: newBlockIds,
        currentVersionId: null,
        model: restoredModel,
        metadata: _metadataWithoutSnapshot(message),
        updatedAt: now,
      ),
    );
    await _reloadIntoState(messageId);
  }

  /// Deletes version [versionId] from [messageId] (the trash action). Port of
  /// `versionService.deleteVersion`: if the version is currently displayed the
  /// message first switches back to the latest content. A no-op while a reply
  /// is streaming.
  Future<void> deleteVersion(String messageId, String versionId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    var message = await _repo.getMessage(messageId);
    if (message == null) return;

    if (message.currentVersionId == versionId) {
      await switchToLatest(messageId);
      final refreshed = await _repo.getMessage(messageId);
      if (refreshed == null) return;
      message = refreshed;
    }

    final version = _findVersion(message, versionId);
    if (version == null) return;
    await _deleteBlocks(version.blocks);
    final remaining = [
      for (final v in message.versions ?? const <MessageVersion>[])
        if (v.id != versionId) v,
    ];
    await _repo.saveMessage(
      message.copyWith(versions: remaining, updatedAt: DateTime.now()),
    );
    await _reloadIntoState(messageId);
  }

  /// Archives the message's currently displayed content ahead of a regenerate.
  ///
  /// On the latest view it saves the live content as a `regenerate` version; on
  /// a historical view it promotes the stashed latest snapshot to a permanent
  /// version (so it survives) and clears the snapshot. The blocks on display
  /// are dropped by [regenerate] right after. Port of
  /// `versionService.prepareForRegenerate`.
  Future<Message> _prepareForRegenerate(Message message, DateTime now) async {
    if (message.currentVersionId == null) {
      return await _saveCurrentAsVersion(
            message,
            source: 'regenerate',
            timestamp: now,
          ) ??
          message;
    }
    return _promoteLatestSnapshot(message, now);
  }

  /// Clones the message's current blocks into a new [MessageVersion] and
  /// appends it (pruning the oldest beyond [_maxVersionsPerMessage]). Returns
  /// the updated message, or `null` when the content is empty (nothing to
  /// save). Port of `versionService.saveCurrentAsVersion`.
  Future<Message?> _saveCurrentAsVersion(
    Message message, {
    required String source,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final blocks = await _repo.getMessageBlocksByIds(message.blocks);
    final content = _mainTextOf(blocks);
    if (content.trim().isEmpty) return null;

    final versionId = generateId('version');
    final clones = _cloneBlocks(blocks, 'version_$versionId', now);
    await _repo.saveMessageBlocks(clones);
    final version = MessageVersion(
      id: versionId,
      messageId: message.id,
      blocks: [for (final block in clones) block.id],
      createdAt: now,
      modelId: message.modelId,
      model: message.model,
      isActive: false,
      metadata: <String, dynamic>{
        'source': source,
        'timestamp': now.millisecondsSinceEpoch,
        'contentSnapshot': content,
      },
    );
    final versions = await _appendVersion(message.versions, version);
    final updated = message.copyWith(versions: versions);
    await _repo.saveMessage(updated);
    return updated;
  }

  /// Promotes the stashed latest snapshot into a permanent version and clears
  /// the snapshot + [Message.currentVersionId]. Used when regenerating while a
  /// historical version is on display, mirroring the history branch of
  /// `versionService.prepareForRegenerate`.
  Future<Message> _promoteLatestSnapshot(Message message, DateTime now) async {
    final snap = _latestSnapshot(message);
    var versions = message.versions ?? const <MessageVersion>[];
    if (snap != null && snap.blockIds.isNotEmpty) {
      final stashed = await _repo.getMessageBlocksByIds(snap.blockIds);
      final content = _mainTextOf(stashed);
      if (stashed.isNotEmpty && content.trim().isNotEmpty) {
        final versionId = generateId('version');
        final retagged = [
          for (final block in stashed)
            block.copyWith(messageId: 'version_$versionId', updatedAt: now),
        ];
        await _repo.saveMessageBlocks(retagged);
        versions = await _appendVersion(
          versions,
          MessageVersion(
            id: versionId,
            messageId: message.id,
            blocks: [for (final block in retagged) block.id],
            createdAt: now,
            model: snap.model ?? message.model,
            isActive: false,
            metadata: <String, dynamic>{
              'source': 'regenerate',
              'timestamp': now.millisecondsSinceEpoch,
              'contentSnapshot': content,
            },
          ),
        );
      } else {
        await _deleteBlocks(snap.blockIds);
      }
    }
    final updated = message.copyWith(
      versions: versions,
      currentVersionId: null,
      metadata: _metadataWithoutSnapshot(message),
    );
    await _repo.saveMessage(updated);
    return updated;
  }

  /// Clones the message's live blocks into a `latest_<id>` stash and records
  /// their ids + model in [Message.metadata] so the latest content can be
  /// restored after browsing history. Port of the snapshot half of
  /// `versionService.switchToVersion`.
  Future<Message> _stashLatestSnapshot(Message message, DateTime now) async {
    final live = await _repo.getMessageBlocksByIds(message.blocks);
    final stash = _cloneBlocks(live, 'latest_${message.id}', now);
    if (stash.isNotEmpty) await _repo.saveMessageBlocks(stash);
    final model = message.model;
    final metadata = <String, dynamic>{
      ...?message.metadata,
      _latestSnapshotKey: <String, dynamic>{
        'blocks': [for (final block in stash) block.id],
        if (model != null) 'model': model.toJson(),
      },
    };
    final updated = message.copyWith(metadata: metadata);
    await _repo.saveMessage(updated);
    return updated;
  }

  Future<List<MessageVersion>> _appendVersion(
    List<MessageVersion>? existing,
    MessageVersion version,
  ) async {
    final versions = [...?existing, version];
    if (versions.length > _maxVersionsPerMessage) {
      versions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      while (versions.length > _maxVersionsPerMessage) {
        final pruned = versions.removeAt(0);
        await _deleteBlocks(pruned.blocks);
      }
    }
    return versions;
  }

  List<MessageBlock> _cloneBlocks(
    List<MessageBlock> blocks,
    String clonedMessageId,
    DateTime now,
  ) {
    return [
      for (final block in blocks)
        block.copyWith(
          id: generateId('block'),
          messageId: clonedMessageId,
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  Future<void> _deleteBlocks(List<String> ids) async {
    for (final id in ids) {
      await _repo.deleteMessageBlock(id);
    }
  }

  MessageVersion? _findVersion(Message message, String versionId) {
    for (final version in message.versions ?? const <MessageVersion>[]) {
      if (version.id == versionId) return version;
    }
    return null;
  }

  String _mainTextOf(List<MessageBlock> blocks) => blocks
      .whereType<MainTextBlock>()
      .map((block) => block.content)
      .join('\n\n');

  String _versionSnapshotText(MessageVersion version) {
    final snapshot = version.metadata?['contentSnapshot'];
    return snapshot is String ? snapshot : '';
  }

  _LatestSnapshot? _latestSnapshot(Message message) {
    final raw = message.metadata?[_latestSnapshotKey];
    if (raw is! Map) return null;
    final blocks = raw['blocks'];
    final blockIds = blocks is List
        ? <String>[
            for (final id in blocks)
              if (id is String) id,
          ]
        : <String>[];
    final modelJson = raw['model'];
    final model = modelJson is Map
        ? Model.fromJson(Map<String, dynamic>.from(modelJson))
        : null;
    return _LatestSnapshot(blockIds: blockIds, model: model);
  }

  Map<String, dynamic>? _metadataWithoutSnapshot(Message message) {
    final metadata = message.metadata;
    if (metadata == null) return null;
    final next = <String, dynamic>{...metadata}..remove(_latestSnapshotKey);
    return next.isEmpty ? null : next;
  }

  /// Reloads [messageId]'s persisted view into the conversation state without a
  /// full topic reload, after a version mutation.
  Future<void> _reloadIntoState(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null) return;
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    final view = await _viewOf(message);
    final views = List<ChatMessageView>.of(snapshot.messages);
    final index = views.indexWhere((v) => v.id == messageId);
    if (index == -1) return;
    views[index] = view;
    _emit(views, isStreaming: false);
  }

  /// Reloads the persisted view for [messageId] (real blocks in order) after
  /// finalize; falls back to [fallback] if the message can't be read.
  Future<ChatMessageView> _reloadView(
    String messageId,
    ChatMessageView fallback,
  ) async {
    final message = await _repo.getMessage(messageId);
    if (message == null) return fallback;
    return _viewOf(message);
  }

  Future<String> _ensureTopic() async {
    final existing = _topicId;
    if (existing != null) return existing;
    final now = DateTime.now();
    final topicId = generateId('topic');
    await _repo.saveTopic(
      Topic(
        id: topicId,
        assistantId: _assistantId,
        name: '新对话',
        createdAt: now,
        updatedAt: now,
      ),
    );
    _topicId = topicId;
    return topicId;
  }

  Future<void> _finalizeSuccess({
    required String messageId,
    required String mainBlockId,
    required DateTime createdAt,
    required String text,
    required String thinking,
  }) async {
    final now = DateTime.now();
    final blockIds = <String>[];
    if (thinking.isNotEmpty) {
      final thinkingBlockId = generateId('block');
      blockIds.add(thinkingBlockId);
      await _repo.saveMessageBlock(
        MessageBlock.thinking(
          id: thinkingBlockId,
          messageId: messageId,
          status: MessageBlockStatus.success,
          createdAt: createdAt,
          updatedAt: now,
          content: thinking,
        ),
      );
    }
    blockIds.add(mainBlockId);
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: mainBlockId,
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        updatedAt: now,
        content: text,
      ),
    );
    final message = await _repo.getMessage(messageId);
    if (message != null) {
      await _repo.saveMessage(
        message.copyWith(
          status: MessageStatus.success,
          updatedAt: now,
          blocks: blockIds,
        ),
      );
    }
  }

  Future<void> _finalizeError({
    required String messageId,
    required DateTime createdAt,
    required String text,
    required String errorText,
  }) async {
    final now = DateTime.now();
    final errorBlockId = generateId('block');
    await _repo.saveMessageBlock(
      MessageBlock.error(
        id: errorBlockId,
        messageId: messageId,
        status: MessageBlockStatus.error,
        createdAt: createdAt,
        updatedAt: now,
        content: text,
        message: errorText,
      ),
    );
    final message = await _repo.getMessage(messageId);
    if (message != null) {
      await _repo.saveMessage(
        message.copyWith(
          status: MessageStatus.error,
          updatedAt: now,
          blocks: <String>[errorBlockId],
        ),
      );
    }
  }

  Future<ChatMessageView> _viewOf(Message message) async {
    final fetched = await _repo.getMessageBlocksByMessageId(message.id);
    final blocks = _orderBlocks(message.blocks, fetched);
    final text = blocks
        .whereType<MainTextBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final thinking = blocks
        .whereType<ThinkingBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final errors = blocks.whereType<ErrorBlock>();
    final error = errors.isEmpty ? null : errors.first;
    final model = message.model;
    String? providerName;
    if (model != null) {
      final providers = await ref.read(appModelProvidersProvider.future);
      for (final provider in providers) {
        if (provider.id == model.provider) {
          providerName = provider.name;
          break;
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
      versions: message.versions ?? const <MessageVersion>[],
      currentVersionId: message.currentVersionId,
    );
  }

  /// Returns [blocks] sorted by the `message.blocks` id order (the canonical
  /// render order); any block not referenced there is appended at the end.
  List<MessageBlock> _orderBlocks(
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

  void _emit(List<ChatMessageView> views, {required bool isStreaming}) {
    state = AsyncData(
      ChatState(
        messages: List<ChatMessageView>.of(views),
        isStreaming: isStreaming,
      ),
    );
  }

  void _replace(List<ChatMessageView> views, ChatMessageView view) {
    final index = views.indexWhere((v) => v.id == view.id);
    if (index != -1) views[index] = view;
  }

  String _errorMessage(Object error) {
    if (error is Failure) return error.message;
    return error.toString();
  }
}

/// The latest (live) content stashed in [Message.metadata] while a historical
/// version is on display: the ids of the cloned blocks plus the model that
/// produced them, restored by [ChatController.switchToLatest].
class _LatestSnapshot {
  const _LatestSnapshot({required this.blockIds, required this.model});

  final List<String> blockIds;
  final Model? model;
}
