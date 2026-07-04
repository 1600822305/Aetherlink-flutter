// Message version management, extracted from ChatController: manual save,
// switching between historical versions and the latest (live) content,
// deletion, and the regenerate-time archival. Ports of the web
// `versionService`. Pure repository work — the controller wraps each public
// method with its streaming guard and state reload.

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';

/// Joined text of the message's `main_text` blocks (version snapshot content).
String mainTextOf(List<MessageBlock> blocks) => blocks
    .whereType<MainTextBlock>()
    .map((block) => block.content)
    .join('\n\n');

/// Persists and mutates a message's [MessageVersion] history.
class MessageVersioning {
  const MessageVersioning(this._repo);

  final ChatRepository _repo;

  static const int _maxVersionsPerMessage = 20;

  static const String _latestSnapshotKey = 'latestSnapshot';

  /// Saves [message]'s current content as a `manual` version (the 保存当前
  /// button). Port of `versionService.createManualVersion`. Returns false when
  /// the content is empty (nothing saved).
  Future<bool> createManualVersion(Message message) async {
    final updated = await saveCurrentAsVersion(message, source: 'manual');
    return updated != null;
  }

  /// Switches the displayed content of [message] to version [versionId].
  ///
  /// Port of `versionService.switchToVersion`: when leaving the latest (live)
  /// content for the first time the live blocks are stashed (so they can be
  /// restored later), then the message's blocks are replaced with clones of the
  /// version's blocks and [Message.currentVersionId] is set. Returns false
  /// when [versionId] doesn't exist.
  Future<bool> switchToVersion(Message message, String versionId) async {
    final version = _findVersion(message, versionId);
    if (version == null) return false;

    final now = DateTime.now();
    // Stash the live content the first time we leave the latest view.
    if (message.currentVersionId == null) {
      message = await _stashLatestSnapshot(message, now);
    }

    final messageId = message.id;
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
    return true;
  }

  /// Switches [message] back to the latest (live) content, restoring the
  /// blocks stashed when history was first opened. Port of
  /// `versionService.switchToLatest`. Returns false when already showing the
  /// latest content.
  Future<bool> switchToLatest(Message message) async {
    if (message.currentVersionId == null) return false;

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
            block.copyWith(messageId: message.id, updatedAt: now),
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
    return true;
  }

  /// Deletes version [versionId] from [message] (the trash action). Port of
  /// `versionService.deleteVersion`. The caller must have switched the message
  /// back to the latest content first if this version is on display. Returns
  /// false when [versionId] doesn't exist.
  Future<bool> deleteVersion(Message message, String versionId) async {
    final version = _findVersion(message, versionId);
    if (version == null) return false;
    await _deleteBlocks(version.blocks);
    final remaining = [
      for (final v in message.versions ?? const <MessageVersion>[])
        if (v.id != versionId) v,
    ];
    await _repo.saveMessage(
      message.copyWith(versions: remaining, updatedAt: DateTime.now()),
    );
    return true;
  }

  /// Archives the message's currently displayed content ahead of a regenerate.
  ///
  /// On the latest view it saves the live content as a `regenerate` version; on
  /// a historical view it promotes the stashed latest snapshot to a permanent
  /// version (so it survives) and clears the snapshot. The blocks on display
  /// are dropped by the regenerate right after. Port of
  /// `versionService.prepareForRegenerate`.
  Future<Message> prepareForRegenerate(Message message, DateTime now) async {
    if (message.currentVersionId == null) {
      return await saveCurrentAsVersion(
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
  Future<Message?> saveCurrentAsVersion(
    Message message, {
    required String source,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final blocks = await _repo.getMessageBlocksByIds(message.blocks);
    final content = mainTextOf(blocks);
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
      final content = mainTextOf(stashed);
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
}

/// The latest (live) content stashed in [Message.metadata] while a historical
/// version is on display: the ids of the cloned blocks plus the model that
/// produced them, restored by [MessageVersioning.switchToLatest].
class _LatestSnapshot {
  const _LatestSnapshot({required this.blockIds, required this.model});

  final List<String> blockIds;
  final Model? model;
}
